#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#cython: auto_pickle=False
#distutils: language=c++

from .core cimport *
from .types cimport *
from .types import Key
from cython.operator cimport dereference
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from dearcygui.wrapper cimport imgui, implot
import traceback

cdef class CustomHandler(baseHandler):
    """
    A base class to be subclassed in python
    for custom state checking.
    As this is called every frame rendered,
    and locks the GIL, be careful not do perform
    anything heavy.

    The functions that need to be implemented by
    subclasses are:
    -> check_can_bind(self, item)
    = Must return a boolean to indicate
    if this handler can be bound to
    the target item. Use isinstance to check
    the target class of the item.
    Note isinstance can recognize parent classes as
    well as subclasses. You can raise an exception.

    -> check_status(self, item)
    = Must return a boolean to indicate if the
    condition this handler looks at is met.
    Should not perform any action.

    -> run(self, item)
    Optional. If implemented, must perform
    the check this handler is meant to do,
    and take the appropriate actions in response
    (callbacks, etc). returns None.
    Note even if you implement run, check_status
    is still required. But it will not trigger calls
    to the callback. If you don't implement run(),
    returning True in check_status will trigger
    the callback.
    As a good practice try to not perform anything
    heavy to not block rendering.

    Warning: DO NOT change any item's parent, sibling
    or child. Rendering might rely on the tree being
    unchanged.
    You can change item values or status (show, theme, etc),
    except for parents of the target item.
    If you want to do that, delay the changes to when
    you are outside render_frame() or queue the change
    to be executed in another thread (mutexes protect
    states that need to not change during rendering,
    when accessed from a different thread). 

    If you need to access specific DCG internal item states,
    you must use Cython and subclass baseHandler instead.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint condition = False
        condition = self.check_can_bind(item)
        if not(condition):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef bint condition = False
        with gil:
            try:
                condition = self.check_status(item)
            except Exception as e:
                print(f"An error occured running check_status of {self} on {item}", traceback.format_exc())
        return condition

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        cdef bint condition = False
        with gil:
            if hasattr(self, "run"):
                try:
                    self.run(item)
                except Exception as e:
                    print(f"An error occured running run of {self} on {item}", traceback.format_exc())
            elif self._callback is not None:
                try:
                    condition = self.check_status(item)
                except Exception as e:
                    print(f"An error occured running check_status of {self} on {item}", traceback.format_exc())
        if condition:
            self.run_callback(item)


cdef inline void check_bind_children(baseItem item, baseItem target):
    if item.last_handler_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_handler_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<baseHandler>child).check_bind(target)
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef bint check_state_from_list(baseHandler start_handler,
                                HandlerListOP op,
                                baseItem item) noexcept nogil:
        """
        Helper for handler lists
        """
        if start_handler is None:
            return False
        start_handler.lock_and_previous_siblings()
        # We use PyObject to avoid refcounting and thus the gil
        cdef PyObject* child = <PyObject*>start_handler
        cdef bint current_state = False
        cdef bint child_state
        if op == HandlerListOP.ALL:
            current_state = True
        if (<baseHandler>child) is not None:
            while (<baseItem>child)._prev_sibling is not None:
                child = <PyObject *>(<baseItem>child)._prev_sibling
        while (<baseHandler>child) is not None:
            child_state = (<baseHandler>child).check_state(item)
            if not((<baseHandler>child)._enabled):
                child = <PyObject*>((<baseHandler>child)._next_sibling)
                continue
            if op == HandlerListOP.ALL:
                current_state = current_state and child_state
                if not(current_state):
                    # Leave early. Useful to skip expensive check_states,
                    # for instance from custom handlers.
                    # We will return FALSE (not all are conds met)
                    break
            elif op == HandlerListOP.ANY:
                current_state = current_state or child_state
                if current_state:
                    # We will return TRUE (at least one cond is met)
                    break
            else: # NONE:
                current_state = current_state or child_state
                if current_state:
                    # We will return FALSE (at least one cond is met)
                    break
            child = <PyObject*>((<baseHandler>child)._next_sibling)
        if op == HandlerListOP.NONE:
            # NONE = not(ANY)
            current_state = not(current_state)
        start_handler.unlock_and_previous_siblings()
        return current_state

cdef inline void run_handler_children(baseItem item, baseItem target) noexcept nogil:
    if item.last_handler_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_handler_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<baseHandler>child).run_handler(target)
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef class HandlerList(baseHandler):
    """
    A list of handlers in order to attach several
    handlers to an item.
    In addition if you attach a callback to this handler,
    it will be issued if ALL or ANY of the children handler
    states are met. NONE is also possible.
    Note however that the handlers are not checked if an item
    is not rendered. This corresponds to the visible state.
    """
    def __cinit__(self):
        self.can_have_handler_child = True
        self._op = HandlerListOP.ALL

    @property
    def op(self):
        """
        HandlerListOP that defines which condition
        is required to trigger the callback of this
        handler.
        Default is ALL
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._op

    @op.setter
    def op(self, HandlerListOP value):
        if value not in [HandlerListOP.ALL, HandlerListOP.ANY, HandlerListOP.NONE]:
            raise ValueError("Unknown op")
        self._op = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        check_bind_children(self, item)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return check_state_from_list(self.last_handler_child, self._op, item)

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        run_handler_children(self, item)
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


cdef class ConditionalHandler(baseHandler):
    """
    A handler that runs the handler of his FIRST handler
    child if the other ones have their condition checked.
    The other handlers are not run. Just their condition
    is checked.

    For example this is useful to combine conditions. For example
    detecting clicks when a key is pressed. The interest
    of using this handler, rather than handling it yourself, is
    that if the callback queue is laggy the condition might not
    hold true anymore by the time you process the handler.
    In this case this handler enables to test right away
    the intended conditions.

    Note that handlers that get their condition checked do
    not call their callbacks.
    """
    def __cinit__(self):
        self.can_have_handler_child = True

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        check_bind_children(self, item)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if self.last_handler_child is None:
            return False
        self.last_handler_child.lock_and_previous_siblings()
        # We use PyObject to avoid refcounting and thus the gil
        cdef PyObject* child = <PyObject*>self.last_handler_child
        cdef bint current_state = True
        cdef bint child_state
        while child is not <PyObject*>None:
            child_state = (<baseHandler>child).check_state(item)
            child = <PyObject*>((<baseHandler>child)._prev_sibling)
            if not((<baseHandler>child)._enabled):
                continue
            current_state = current_state and child_state
        self.last_handler_child.unlock_and_previous_siblings()
        return current_state

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if self.last_handler_child is None:
            return
        self.last_handler_child.lock_and_previous_siblings()
        # Retrieve the first child and combine the states of the previous ones
        cdef bint condition_held = True
        cdef PyObject* child = <PyObject*>self.last_handler_child
        cdef bint child_state
        # Note: we already have tested there is at least one child
        while ((<baseHandler>child)._prev_sibling) is not None:
            child_state = (<baseHandler>child).check_state(item)
            child = <PyObject*>((<baseHandler>child)._prev_sibling)
            if not((<baseHandler>child)._enabled):
                continue
            condition_held = condition_held and child_state
        if condition_held:
            (<baseHandler>child).run_handler(item)
        self.last_handler_child.unlock_and_previous_siblings()
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


cdef class OtherItemHandler(HandlerList):
    """
    Handler that imports the states from a different
    item than the one is attached to, and runs the
    children handlers using the states of the other
    item. The 'target' field in the callbacks will
    still be the current item and not the other item.

    This is useful when you need to do a AND/OR combination
    of the current item state with another item state, or
    when you need to check the state of an item that might be
    not be rendered.
    """
    def __cinit__(self):
        self._target = None

    @property
    def target(self):
        """
        Target item which state will be used
        for children handlers.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._target

    @target.setter
    def target(self, baseItem target):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._target = target

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        check_bind_children(self, self._target)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return check_state_from_list(self.last_handler_child, self._op, self._target)

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return

        # TODO: reintroduce that feature. Here we use item, and not self._target. Idem above
        run_handler_children(self, self._target)
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


cdef class ActivatedHandler(baseHandler):
    """
    Handler for when the target item turns from
    the non-active to the active state. For instance
    buttons turn active when the mouse is pressed on them.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.active and not(state.prev.active)

cdef class ActiveHandler(baseHandler):
    """
    Handler for when the target item is active.
    For instance buttons turn active when the mouse
    is pressed on them, and stop being active when
    the mouse is released.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.active

cdef class ClickedHandler(baseHandler):
    """
    Handler for when a hovered item is clicked on.
    The item doesn't have to be interactable,
    it can be Text for example.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        """
        Target mouse button
        0: left click
        1: right click
        2: middle click
        3, 4: other buttons
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.cur.clicked[<int>self._button]

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        if not(self._enabled):
            return
        if state.cur.clicked[<int>self._button]:
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)

cdef class DoubleClickedHandler(baseHandler):
    """
    Handler for when a hovered item is double clicked on.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.cur.double_clicked[<int>self._button]

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        if not(self._enabled):
            return
        if state.cur.double_clicked[<int>self._button]:
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)

cdef class DeactivatedHandler(baseHandler):
    """
    Handler for when an active item loses activation.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.active) and state.prev.active

cdef class DeactivatedAfterEditHandler(baseHandler):
    """
    However for editable items when the item loses
    activation after having been edited.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_deactivated_after_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.deactivated_after_edited

cdef class DraggedHandler(baseHandler):
    """
    Same as DraggingHandler, but only
    triggers the callback when the dragging
    has ended, instead of every frame during
    the dragging.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_dragged):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.prev.dragging[<int>self._button] and not(state.cur.dragging[<int>self._button])

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        if not(self._enabled):
            return
        cdef int i = <int>self._button
        if state.prev.dragging[i] and not(state.cur.dragging[i]):
                self.context.queue_callback_arg2float(self._callback,
                                                      self,
                                                      item,
                                                      state.prev.drag_deltas[i].x,
                                                      state.prev.drag_deltas[i].y)

cdef class DraggingHandler(baseHandler):
    """
    Handler to catch when the item is hovered
    and the mouse is dragging (click + motion) ?
    Note that if the item is not a button configured
    to catch the target button, it will not be
    considered being dragged as soon as it is not
    hovered anymore.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_dragged):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.cur.dragging[<int>self._button]

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef itemState *state = item.p_state
        cdef int i = <int>self._button
        if not(self._enabled):
            return
        if state.cur.dragging[i]:
            self.context.queue_callback_arg2float(self._callback,
                                                  self,
                                                  item,
                                                  state.cur.drag_deltas[i].x,
                                                  state.cur.drag_deltas[i].y)

cdef class EditedHandler(baseHandler):
    """
    Handler to catch when a field is edited.
    Only the frames when a field is changed
    triggers the callback.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.edited

cdef class FocusHandler(baseHandler):
    """
    Handler for windows or sub-windows that is called
    when they have focus, or for items when they
    have focus (for instance keyboard navigation,
    or editing a field).
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.focused

cdef class GotFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows get
    focus.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.focused and not(state.prev.focused)

cdef class LostFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows lose
    focus.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.focused and not(state.prev.focused)

cdef class MouseOverHandler(baseHandler):
    """Prefer HoverHandler unless you really need to (see below)

    Handler that calls the callback when
    the mouse is over the item. In most cases,
    this is equivalent to HoverHandler,
    with the difference that a single item
    is considered hovered, while in
    some specific cases, several items could
    have the mouse above them.

    Prefer using HoverHandler for general use,
    and reserve MouseOverHandler for custom
    drag & drop operations.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or \
           not(item.p_state.cap.has_position) or \
           not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if not(imgui.IsMousePosValid()):
            return False
        cdef float x1 = item.p_state.cur.pos_to_viewport.x
        cdef float y1 = item.p_state.cur.pos_to_viewport.y
        cdef float x2 = x1 + item.p_state.cur.rect_size.x
        cdef float y2 = y1 + item.p_state.cur.rect_size.y
        return x1 <= io.MousePos.x and \
               y1 <= io.MousePos.y and \
               x2 > io.MousePos.x and \
               y2 > io.MousePos.y

cdef class GotMouseOverHandler(baseHandler):
    """Prefer GotHoverHandler unless you really need to (see MouseOverHandler)
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or \
           not(item.p_state.cap.has_position) or \
           not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if not(imgui.IsMousePosValid()):
            return False
        # Check the mouse is over the item
        cdef float x1 = item.p_state.cur.pos_to_viewport.x
        cdef float y1 = item.p_state.cur.pos_to_viewport.y
        cdef float x2 = x1 + item.p_state.cur.rect_size.x
        cdef float y2 = y1 + item.p_state.cur.rect_size.y
        if not(x1 <= io.MousePos.x and \
               y1 <= io.MousePos.y and \
               x2 > io.MousePos.x and \
               y2 > io.MousePos.y):
            return False
        # Check the mouse was not over the item
        if io.MousePosPrev.x == -1 or io.MousePosPrev.y == -1: # Invalid pos
            return True
        x1 = item.p_state.prev.pos_to_viewport.x
        y1 = item.p_state.prev.pos_to_viewport.y
        x2 = x1 + item.p_state.prev.rect_size.x
        y2 = y1 + item.p_state.prev.rect_size.y
        return not(x1 <= io.MousePosPrev.x and \
                   y1 <= io.MousePosPrev.y and \
                   x2 > io.MousePosPrev.x and \
                   y2 > io.MousePosPrev.y)

cdef class LostMouseOverHandler(baseHandler):
    """Prefer LostHoverHandler unless you really need to (see MouseOverHandler)
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or \
           not(item.p_state.cap.has_position) or \
           not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        # Check the mouse was over the item
        if io.MousePosPrev.x == -1 or io.MousePosPrev.y == -1: # Invalid pos
            return False
        cdef float x1 = item.p_state.prev.pos_to_viewport.x
        cdef float y1 = item.p_state.prev.pos_to_viewport.y
        cdef float x2 = x1 + item.p_state.prev.rect_size.x
        cdef float y2 = y1 + item.p_state.prev.rect_size.y
        if not(x1 <= io.MousePosPrev.x and \
               y1 <= io.MousePosPrev.y and \
               x2 > io.MousePosPrev.x and \
               y2 > io.MousePosPrev.y):
            return False
        if not(imgui.IsMousePosValid()):
            return True
        # Check the mouse is not over the item
        x1 = item.p_state.cur.pos_to_viewport.x
        y1 = item.p_state.cur.pos_to_viewport.y
        x2 = x1 + item.p_state.cur.rect_size.x
        y2 = y1 + item.p_state.cur.rect_size.y
        return not(x1 <= io.MousePos.x and \
                   y1 <= io.MousePos.y and \
                   x2 > io.MousePos.x and \
                   y2 > io.MousePos.y)

cdef class HoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item is hovered.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.hovered

cdef class GotHoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item has just been hovered.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.hovered and not(state.prev.hovered)

cdef class LostHoverHandler(baseHandler):
    """
    Handler that calls the callback the first
    frame when the target item was hovered, but
    is not anymore.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.hovered) and state.prev.hovered


cdef class MotionHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item is moved relative to
    the positioning reference (by default the parent)
    """
    def __cinit__(self):
        self._positioning[0] = Positioning.REL_PARENT
        self._positioning[1] = Positioning.REL_PARENT

    @property
    def pos_policy(self):
        """positioning policy used as reference for the motion

        REL_PARENT: motion relative to the parent
        REL_WINDOW: motion relative to the window
        REL_VIEWPORT: motion relative to the viewport
        DEFAULT: Disabled motion detection for the axis

        pos_policy is a tuple of Positioning where the
        first element refers to the x axis and the second
        to the y axis

        Defaults to REL_PARENT on both axes.
        """
        (<Positioning>self._positioning[0], <Positioning>self._positioning[1])

    @pos_policy.setter
    def pos_policy(self, Positioning value):
        if hasattr(value, "__len__"):
            (x, y) = value
            if x not in Positioning or y not in Positioning:
                raise ValueError("Invalid Positioning policy")
            self._positioning[0] = x
            self._positioning[1] = y
        else:
            if value not in Positioning:
                raise ValueError("Invalid Positioning policy")
            self._positioning[0] = value
            self._positioning[1] = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.has_position):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        cdef imgui.ImVec2 prev_pos, cur_pos
        if self._positioning[0] == Positioning.REL_PARENT:
            prev_pos.x = state.prev.pos_to_parent.x
            cur_pos.x = state.cur.pos_to_parent.x
        elif self._positioning[0] == Positioning.REL_WINDOW:
            prev_pos.x = state.prev.pos_to_window.x
            cur_pos.x = state.cur.pos_to_window.x
        elif self._positioning[0] == Positioning.REL_VIEWPORT:
            prev_pos.x = state.prev.pos_to_viewport.x
            cur_pos.x = state.cur.pos_to_viewport.x
        elif self._positioning[0] == Positioning.REL_DEFAULT:
            prev_pos.x = state.prev.pos_to_default.x
            cur_pos.x = state.cur.pos_to_default.x
        else:
            prev_pos.x = 0.
            cur_pos.x = 0.
        if self._positioning[1] == Positioning.REL_PARENT:
            prev_pos.y = state.prev.pos_to_parent.y
            cur_pos.y = state.cur.pos_to_parent.y
        elif self._positioning[1] == Positioning.REL_WINDOW:
            prev_pos.y = state.prev.pos_to_window.y
            cur_pos.y = state.cur.pos_to_window.y
        elif self._positioning[1] == Positioning.REL_VIEWPORT:
            prev_pos.y = state.prev.pos_to_viewport.y
            cur_pos.y = state.cur.pos_to_viewport.y
        elif self._positioning[1] == Positioning.REL_DEFAULT:
            prev_pos.y = state.prev.pos_to_default.y
            cur_pos.y = state.cur.pos_to_default.y
        else:
            prev_pos.y = 0.
            cur_pos.y = 0.
        return cur_pos.x != prev_pos.x or cur_pos.y != prev_pos.y


# TODO: Add size as data to the resize callbacks
cdef class ContentResizeHandler(baseHandler):
    """
    Handler for item containers (windows, etc)
    that triggers the callback
    whenever the item's content region box (the
    area available to the children) changes size.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.has_content_region):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.content_region_size.x != state.prev.content_region_size.x or \
               state.cur.content_region_size.y != state.prev.content_region_size.y

cdef class ResizeHandler(baseHandler):
    """
    Handler that triggers the callback
    whenever the item's bounding box changes size.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.rect_size.x != state.prev.rect_size.x or \
               state.cur.rect_size.y != state.prev.rect_size.y

cdef class ToggledOpenHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item switches from an closed state to a opened
    state. Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.open and not(state.prev.open)

cdef class ToggledCloseHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item switches from an opened state to a closed
    state.
    *Warning*: Does not mean an item is un-shown
    by a user interaction (what we usually mean
    by closing a window).
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.open) and state.prev.open

cdef class OpenHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item is in an opened state.
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.open

cdef class CloseHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item is in an closed state.
    *Warning*: Does not mean an item is un-shown
    by a user interaction (what we usually mean
    by closing a window).
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.open)

cdef class RenderHandler(baseHandler):
    """
    Handler that calls the callback
    whenever the item is rendered during
    frame rendering. This doesn't mean
    that the item is visible as it can be
    occluded by an item in front of it.
    Usually rendering skips items that
    are outside the window's clipping region,
    or items that are inside a menu that is
    currently closed.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL:
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.rendered

cdef class GotRenderHandler(baseHandler):
    """
    Same as RenderHandler, but only calls the
    callback when the item switches from a
    non-rendered to a rendered state.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL:
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.rendered and not(state.prev.rendered)

cdef class LostRenderHandler(baseHandler):
    """
    Handler that only calls the
    callback when the item switches from a
    rendered to non-rendered state. Note
    that when an item is not rendered, subsequent
    frames will not run handlers. Only the first time
    an item is non-rendered will trigger the handlers.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL:
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.rendered) and state.prev.rendered

cdef class MouseCursorHandler(baseHandler):
    """
    Since the mouse cursor is reset every frame,
    this handler is used to set the cursor automatically
    the frames where this handler is run.
    Typical usage would be in a ConditionalHandler,
    combined with a HoverHandler.
    """
    def __cinit__(self):
        self._mouse_cursor = MouseCursor.CursorArrow

    @property
    def cursor(self):
        """
        Change the mouse cursor to one of MouseCursor,
        but only for the frames where this handler
        is run.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._mouse_cursor

    @cursor.setter
    def cursor(self, MouseCursor value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if <int>value < imgui.ImGuiMouseCursor_None or \
           <int>value >= imgui.ImGuiMouseCursor_COUNT:
            raise ValueError("Invalid cursor type {value}")
        self._mouse_cursor = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return True

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        # Applies only for this frame. Is reset the next frame
        imgui.SetMouseCursor(<imgui.ImGuiMouseCursor>self._mouse_cursor)
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


"""
Global handlers

A global handler doesn't look at the item states,
but at global states. It is usually attached to the
viewport, but can be attached to items. If attached
to items, the items needs to be visible for the callback
to be executed.
"""

cdef class KeyDownHandler(baseHandler):
    def __cinit__(self):
        self._key = imgui.ImGuiKey_Enter
    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Key(self._key)
    @key.setter
    def key(self, value : Key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or not(isinstance(value, Key)):
            raise TypeError(f"key must be a valid Key, not {value}")
        self._key = <int>value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiKeyData *key_info
        key_info = imgui.GetKeyData(<imgui.ImGuiKey>self._key)
        if key_info.Down:
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiKeyData *key_info
        if not(self._enabled):
            return
        key_info = imgui.GetKeyData(<imgui.ImGuiKey>self._key)
        if key_info.Down:
            self.context.queue_callback_arg1key1float(self._callback, self, item, self._key, key_info.DownDuration)

cdef class KeyPressHandler(baseHandler):
    def __cinit__(self):
        self._key = imgui.ImGuiKey_Enter
        self._repeat = True

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Key(self._key)
    @key.setter
    def key(self, value : Key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or not(isinstance(value, Key)):
            raise TypeError(f"key must be a valid Key, not {value}")
        self._key = <int>value
    @property
    def repeat(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return imgui.IsKeyPressed(<imgui.ImGuiKey>self._key, self._repeat)

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsKeyPressed(<imgui.ImGuiKey>self._key, self._repeat):
            self.context.queue_callback_arg1key(self._callback, self, item, self._key)


cdef class KeyReleaseHandler(baseHandler):
    def __cinit__(self):
        self._key = imgui.ImGuiKey_Enter

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Key(self._key)
    @key.setter
    def key(self, value : Key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or not(isinstance(value, Key)):
            raise TypeError(f"key must be a valid Key, not {value}")
        self._key = <int>value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsKeyReleased(<imgui.ImGuiKey>self._key):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if not(self._enabled):
            return
        if imgui.IsKeyReleased(<imgui.ImGuiKey>self._key):
            self.context.queue_callback_arg1key(self._callback, self, item, self._key)


cdef class MouseClickHandler(baseHandler):
    def __cinit__(self):
        self._button = MouseButton.LEFT
        self._repeat = False
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value
    @property
    def repeat(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseClicked(<int>self._button, self._repeat):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseClicked(<int>self._button, self._repeat):
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)


cdef class MouseDoubleClickHandler(baseHandler):
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseDoubleClicked(<int>self._button):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseDoubleClicked(<int>self._button):
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)


cdef class MouseDownHandler(baseHandler):
    def __cinit__(self):
        self._button = MouseButton.LEFT

    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseDown(<int>self._button):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseDown(<int>self._button):
            self.context.queue_callback_arg1button1float(self._callback, self, item, <int>self._button, imgui.GetIO().MouseDownDuration[<int>self._button])


cdef class MouseDragHandler(baseHandler):
    def __cinit__(self):
        self._button = MouseButton.LEFT
        self._threshold = -1 # < 0. means use default

    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value
    @property
    def threshold(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._threshold
    @threshold.setter
    def threshold(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._threshold = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseDragging(<int>self._button, self._threshold):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImVec2 delta
        if not(self._enabled):
            return
        if imgui.IsMouseDragging(<int>self._button, self._threshold):
            delta = imgui.GetMouseDragDelta(<int>self._button, self._threshold)
            self.context.queue_callback_arg1button2float(self._callback, self, item, <int>self._button, delta.x, delta.y)

cdef class MouseMoveHandler(baseHandler):
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if not(imgui.IsMousePosValid()):
            return False
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if not(imgui.IsMousePosValid()):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            self.context.queue_callback_arg2float(self._callback, self, item, io.MousePos.x, io.MousePos.y)


cdef class MouseReleaseHandler(baseHandler):
    def __cinit__(self):
        self._button = MouseButton.LEFT

    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseReleased(<int>self._button):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseReleased(<int>self._button):
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)

cdef class MouseWheelHandler(baseHandler):
    def __cinit__(self, *args, **kwargs):
        self._horizontal = False

    @property
    def horizontal(self):
        """
        Whether to look at the horizontal wheel
        instead of the vertical wheel.

        NOTE: Shift+ vertical wheel => horizontal wheel
        """
        return self._horizontal

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._horizontal = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if self._horizontal:
            if abs(io.MouseWheelH) > 0.:
                return True
        else:
            if abs(io.MouseWheel) > 0.:
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if self._horizontal:
            if abs(io.MouseWheelH) > 0.:
                self.context.queue_callback_arg1float(self._callback, self, item, io.MouseWheelH)
        else:
            if abs(io.MouseWheel) > 0.:
                self.context.queue_callback_arg1float(self._callback, self, item, io.MouseWheel)

