from .core cimport *
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from dearcygui.wrapper cimport imgui

cdef class ActivatedHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_activated):
            raise TypeError("Cannot bind activated item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.activated

cdef class ActiveHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_active):
            raise TypeError("Cannot bind activate item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.active

cdef class ClickedHandler(itemHandler):
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
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_clicked):
            raise TypeError("Cannot bind clicked item handler for this item")

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
            (<itemHandler>self._prev_sibling).run_handler(item, state)
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if state.clicked[i]:
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class DoubleClickedHandler(itemHandler):
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
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_clicked):
            raise TypeError("Cannot bind clicked item handler for this item")

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
            (<itemHandler>self._prev_sibling).run_handler(item, state)
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if state.double_clicked[i]:
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class DeactivatedHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_deactivated):
            raise TypeError("Cannot bind deactivated item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.deactivated

cdef class DeactivatedAfterEditHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_deactivated_after_edited):
            raise TypeError("Cannot bind deactivated (after edit) item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.deactivated_after_edited

cdef class EditedHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_edited):
            raise TypeError("Cannot bind edited item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.edited

cdef class FocusHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_focused):
            raise TypeError("Cannot bind focus item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.focused

cdef class HoverHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_hovered):
            raise TypeError("Cannot bind hover item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.hovered

cdef class ResizeHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.has_rect_size):
            raise TypeError("Cannot bind resize item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.resized

cdef class ToggledOpenHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
        if not(state.can_be_toggled):
            raise TypeError("Cannot bind toggle item handler for this item")
    cdef bint check_state(self, baseItem item, itemState &state) noexcept nogil:
        return state.toggled

cdef class VisibleHandler(itemHandler):
    cdef void check_bind(self, baseItem item, itemState &state):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item, state)
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
