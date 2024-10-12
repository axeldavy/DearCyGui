from .core cimport *
from cython.operator cimport dereference
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from dearcygui.wrapper cimport imgui
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        cdef bint condition = False
        condition = self.check_can_bind(item)
        if not(condition):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        cdef bint condition = False
        with gil:
            try:
                condition = self.check_status(item)
            except Exception as e:
                print(f"An error occured running check_status of {self} on {item}", traceback.format_exc())
        return condition

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self._enabled):
            return
        cdef bint condition = False
        with gil:
            if hasattr(self, "run"):
                try:
                    self.run(item)
                except Exception as e:
                    print(f"An error occured running run of {self} on {item}", traceback.format_exc())
            else:
                try:
                    condition = self.check_status(item)
                except Exception as e:
                    print(f"An error occured running check_status of {self} on {item}", traceback.format_exc())
        if condition:
            self.run_callback(item)

cdef bint check_state_from_list(baseHandler start_handler,
                                handlerListOP op,
                                baseItem item,
                                itemState &state) noexcept nogil:
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
        if op == handlerListOP.ALL:
            current_state = True
        while (<baseHandler>child) is not None:
            child_state = (<baseHandler>child).check_state(item, state)
            if not((<baseHandler>child)._enabled):
                child = <PyObject*>((<baseHandler>child)._prev_sibling)
                continue
            if op == handlerListOP.ALL:
                current_state = current_state and child_state
            else:
                current_state = current_state or child_state
            child = <PyObject*>((<baseHandler>child)._prev_sibling)
        if op == handlerListOP.NONE:
            # NONE = not(ANY)
            current_state = not(current_state)
        start_handler.unlock_and_previous_siblings()
        return current_state

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
        self._op = handlerListOP.ALL

    @property
    def op(self):
        """
        handlerListOP that defines which condition
        is required to trigger the callback of this
        handler.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._op

    @op.setter
    def op(self, handlerListOP value):
        if value not in [handlerListOP.ALL, handlerListOP.ANY, handlerListOP.NONE]:
            raise ValueError("Unknown op")
        self._op = value

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if self.last_handler_child is not None:
            (<baseHandler>self.last_handler_child).check_bind(item, state)

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return check_state_from_list(self.last_handler_child, self._op, item, state)

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self._enabled):
            return
        if self.last_handler_child is not None:
            (<baseHandler>self.last_handler_child).run_handler(item, state)
        if self._callback is not None:
            if self.check_state(item, state):
                self.run_callback(item)


cdef class ConditionalHandler(baseHandler):
    """
    A handler that runs the handler of his FIRST handler
    child if the other ones have their condition checked.

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

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if self.last_handler_child is not None:
            (<baseHandler>self.last_handler_child).check_bind(item, state)

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        if self.last_handler_child is None:
            return False
        self.last_handler_child.lock_and_previous_siblings()
        # We use PyObject to avoid refcounting and thus the gil
        cdef PyObject* child = <PyObject*>self.last_handler_child
        cdef bint current_state = True
        cdef bint child_state
        while child is not <PyObject*>None:
            child_state = (<baseHandler>child).check_state(item, state)
            child = <PyObject*>((<baseHandler>child).last_handler_child)
            if not((<baseHandler>child)._enabled):
                continue
            current_state = current_state and child_state
        self.last_handler_child.unlock_and_previous_siblings()
        return current_state

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
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
        while ((<baseHandler>child).last_handler_child) is not None:
            child_state = (<baseHandler>child).check_state(item, state)
            child = <PyObject*>((<baseHandler>child).last_handler_child)
            if not((<baseHandler>child)._enabled):
                continue
            condition_held = condition_held and child_state
        if condition_held:
            (<baseHandler>child).run_handler(item, state)
        self.last_handler_child.unlock_and_previous_siblings()
        if self._callback is not None:
            if self.check_state(item, state):
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
        self._target = None
        cdef bint success = True
        if isinstance(target, uiItem):
            self.target_state = &(<uiItem>target).state
        elif isinstance(target, PlotAxisConfig):
            self.target_state = &(<PlotAxisConfig>target).state
        elif isinstance(target, plotElement):
            self.target_state = &(<plotElement>target).state
        elif isinstance(target, DrawInvisibleButton):
            self.target_state = &(<DrawInvisibleButton>target).state
        else:
            success = False
        if not(success):
            raise TypeError(f"Unsupported target instance {target}")
        self._target = target

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if self.last_handler_child is not None:
            (<baseHandler>self.last_handler_child).check_bind(self._target, dereference(self.target_state))

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return check_state_from_list(self.last_handler_child, self._op, item, dereference(self.target_state))

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self._enabled):
            return
        if self.last_handler_child is not None:
            # Here we use item, and not self._target
            (<baseHandler>self.last_handler_child).run_handler(item, dereference(self.target_state))
        if self._callback is not None:
            if self.check_state(item, state):
                self.run_callback(item)


cdef class ActivatedHandler(baseHandler):
    """
    Handler for when the target item turns from
    the non-active to the active state. For instance
    buttons turn active when the mouse is pressed on them.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.active and not(state.prev.active)

cdef class ActiveHandler(baseHandler):
    """
    Handler for when the target item is active.
    For instance buttons turn active when the mouse
    is pressed on them, and stop being active when
    the mouse is released.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.active

cdef class ClickedHandler(baseHandler):
    """
    Handler for when a hovered item is clicked on.
    The item doesn't have to be interactable,
    it can be Text for example.
    """
    def __cinit__(self):
        self._button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self._button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to ClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = button
        super().configure(**kwargs)
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
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef bint clicked = False
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if state.cur.clicked[i]:
                clicked = True
        return clicked

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if state.cur.clicked[i]:
                self.context.queue_callback_arg1int(self._callback, self, item, i)

cdef class DoubleClickedHandler(baseHandler):
    """
    Handler for when a hovered item is double clicked on.
    """
    def __cinit__(self):
        self._button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self._button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to ClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef bint clicked = False
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if state.cur.double_clicked[i]:
                clicked = True
        return clicked

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if state.cur.double_clicked[i]:
                self.context.queue_callback_arg1int(self._callback, self, item, i)

cdef class DeactivatedHandler(baseHandler):
    """
    Handler for when an active item loses activation.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return not(state.cur.active) and state.prev.active

cdef class DeactivatedAfterEditHandler(baseHandler):
    """
    However for editable items when the item loses
    activation after having been edited.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_deactivated_after_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.deactivated_after_edited

cdef class DraggedHandler(baseHandler):
    """
    Same as DraggingHandler, but only
    triggers the callback when the dragging
    has ended, instead of every frame during
    the dragging.
    """
    def __cinit__(self):
        self._button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self._button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DraggedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_dragged):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef bint dragged = False
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if state.prev.dragging[i] and not(state.cur.dragging[i]):
                dragged = True
        return dragged

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
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
        self._button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self._button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DraggingHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_dragged):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef bint dragging = False
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if state.cur.dragging[i]:
                dragging = True
        return dragging

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.edited

cdef class FocusHandler(baseHandler):
    """
    Handler for windows or sub-windows that is called
    when they have focus, or for items when they
    have focus (for instance keyboard navigation,
    or editing a field).
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.focused

cdef class GotFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows get
    focus.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.focused and not(state.prev.focused)

cdef class LostFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows lose
    focus.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.focused and not(state.prev.focused)

cdef class HoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item is hovered.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.hovered

cdef class GotHoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item has just been hovered.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.hovered and not(state.prev.hovered)

cdef class LostHoverHandler(baseHandler):
    """
    Handler that calls the callback the first
    frame when the target item was hovered, but
    is not anymore.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return not(state.cur.hovered) and state.prev.hovered

cdef class ResizeHandler(baseHandler):
    """
    Handler that triggers the callback
    whenever the item's bounding box changes size.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        return
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.rendered

cdef class GotRenderHandler(baseHandler):
    """
    Same as RenderHandler, but only calls the
    callback when the item switches from a
    non-rendered to a rendered state.
    """
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        return
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        return
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return not(state.cur.rendered) and state.prev.rendered

cdef class KeyDownHandler(KeyDownHandler_):
    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError(f"Invalid key {value} passed to {self}")
        self._key = value

cdef class KeyPressHandler(KeyPressHandler_):
    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError(f"Invalid key {value} passed to {self}")
        self._key = value
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

cdef class KeyReleaseHandler(KeyReleaseHandler_):
    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError(f"Invalid key {value} passed to {self}")
        self._key = value

cdef class MouseClickHandler(MouseClickHandler_):
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
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

cdef class MouseDoubleClickHandler(MouseDoubleClickHandler_):
    def __cinit__(self):
        self._button = -1
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

cdef class MouseDownHandler(MouseDownHandler_):
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

cdef class MouseDragHandler(MouseDragHandler_):
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
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

cdef class MouseReleaseHandler(MouseReleaseHandler_):
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value
