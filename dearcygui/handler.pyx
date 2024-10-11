from .core cimport *
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

cdef class ActivatedHandler(baseHandler):
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.focused

cdef class HoverHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.hovered

cdef class ResizeHandler(baseHandler):
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
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.open and not(state.prev.open)

cdef class RenderedHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        return
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.cur.rendered

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
