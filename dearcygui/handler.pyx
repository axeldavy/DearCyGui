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
        if not(self.enabled):
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
        if not(state.can_be_activated):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.activated

cdef class ActiveHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.active

cdef class ClickedHandler(baseHandler):
    def __cinit__(self):
        self.button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to ClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef bint clicked = False
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if state.clicked[i]:
                clicked = True
        return clicked

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if state.clicked[i]:
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class DoubleClickedHandler(baseHandler):
    def __cinit__(self):
        self.button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to ClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef bint clicked = False
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if state.double_clicked[i]:
                clicked = True
        return clicked

    cdef void run_handler(self, baseItem item, itemState &state) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item, state)
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if state.double_clicked[i]:
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class DeactivatedHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_deactivated):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.deactivated

cdef class DeactivatedAfterEditHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_deactivated_after_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.deactivated_after_edited

cdef class EditedHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.edited

cdef class FocusHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.focused

cdef class HoverHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.hovered

cdef class ResizeHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.resized

cdef class ToggledOpenHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.toggled

cdef class VisibleHandler(baseHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item, state)
        return
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.visible

cdef class KeyDownHandler(KeyDownHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        key = self.key
        if len(args) == 1:
            key = args[0]
        elif len(key) != 0:
            raise ValueError("Invalid arguments passed to KeyDownHandler. Expected key")
        key = kwargs.pop("key", key)
        if key < 0 or key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = key
        super().configure(**kwargs)

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = value

cdef class KeyPressHandler(KeyPressHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        key = self.key
        if len(args) == 1:
            key = args[0]
        elif len(key) != 0:
            raise ValueError("Invalid arguments passed to KeyPresHandler. Expected key")
        key = kwargs.pop("key", key)
        if key < 0 or key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = key
        self.repeat = kwargs.pop("repeat", self.repeat)
        super().configure(**kwargs)

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = value
    @property
    def repeat(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.repeat = value

cdef class KeyReleaseHandler(KeyReleaseHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        key = self.key
        if len(args) == 1:
            key = args[0]
        elif len(key) != 0:
            raise ValueError("Invalid arguments passed to KeyReleaseHandler. Expected key")
        key = kwargs.pop("key", key)
        if key < 0 or key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = key
        super().configure(**kwargs)

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = value

cdef class MouseClickHandler(MouseClickHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to MouseClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        self.repeat = kwargs.pop("repeat", self.repeat)
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value
    @property
    def repeat(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.repeat = value

cdef class MouseDoubleClickHandler(MouseDoubleClickHandler_):
    def __cinit__(self):
        self.button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to MouseDoubleClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

cdef class MouseDownHandler(MouseDownHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to MouseDownHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

cdef class MouseDragHandler(MouseDragHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) == 2:
            button = args[0]
            threshold = args[1]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to MouseDragHandler. Expected button")
        button = kwargs.pop("button", button)
        threshold = kwargs.pop("threshold", threshold)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        self.threshold = threshold
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

cdef class MouseReleaseHandler(MouseReleaseHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to MouseReleaseHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value
