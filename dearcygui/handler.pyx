from .core cimport *
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from dearcygui.wrapper cimport imgui

cdef class dcgActivatedHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_activated):
            raise TypeError("Cannot bind activated item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.activated:
            self.run_callback(item)

cdef class dcgActiveHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_active):
            raise TypeError("Cannot bind activate item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.active:
            self.run_callback(item)

cdef class dcgClickedHandler(itemHandler):
    def __cinit__(self):
        self.button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_clicked):
            raise TypeError("Cannot bind clicked item handler for {}", type(item))

    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if item.state.clicked[i]:
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgDoubleClickedHandler(itemHandler):
    def __cinit__(self):
        self.button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_clicked):
            raise TypeError("Cannot bind clicked item handler for {}", type(item))

    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if item.state.double_clicked[i]:
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgDeactivatedHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_deactivated):
            raise TypeError("Cannot bind deactivated item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.deactivated:
            self.run_callback(item)

cdef class dcgDeactivatedAfterEditHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_deactivated_after_edited):
            raise TypeError("Cannot bind deactivated (after edit) item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.deactivated_after_edited:
            self.run_callback(item)

cdef class dcgEditedHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_edited):
            raise TypeError("Cannot bind edited item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.edited:
            self.run_callback(item)

cdef class dcgFocusHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_focused):
            raise TypeError("Cannot bind focus item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.focused:
            self.run_callback(item)

cdef class dcgHoverHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_hovered):
            raise TypeError("Cannot bind hover item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.hovered:
            self.run_callback(item)

cdef class dcgResizeHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.has_rect_size):
            raise TypeError("Cannot bind resize item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.resized:
            self.run_callback(item)

cdef class dcgToggledOpenHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if not(uiItem.state.can_be_toggled):
            raise TypeError("Cannot bind toggle item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.toggled:
            self.run_callback(item)

cdef class dcgVisibleHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        return
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if not(self.enabled):
            return
        if item.state.visible:
            self.run_callback(item)

cdef class dcgKeyDownHandler(dcgKeyDownHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        key = self.key
        if len(args) == 1:
            key = args[0]
        elif len(key) != 0:
            raise ValueError("Invalid arguments passed to dcgKeyDownHandler. Expected key")
        key = kwargs.pop("key", key)
        if key < 0 or key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = key
        super().configure(**kwargs)

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = value

cdef class dcgKeyPressHandler(dcgKeyPressHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        key = self.key
        if len(args) == 1:
            key = args[0]
        elif len(key) != 0:
            raise ValueError("Invalid arguments passed to dcgKeyPresHandler. Expected key")
        key = kwargs.pop("key", key)
        if key < 0 or key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = key
        self.repeat = kwargs.pop("repeat", self.repeat)
        super().configure(**kwargs)

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = value
    @property
    def repeat(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.repeat = value

cdef class dcgKeyReleaseHandler(dcgKeyReleaseHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        key = self.key
        if len(args) == 1:
            key = args[0]
        elif len(key) != 0:
            raise ValueError("Invalid arguments passed to dcgKeyReleaseHandler. Expected key")
        key = kwargs.pop("key", key)
        if key < 0 or key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = key
        super().configure(**kwargs)

    @property
    def key(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.key
    @key.setter
    def key(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < 0 or value >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        self.key = value

cdef class dcgMouseClickHandler(dcgMouseClickHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgMouseClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        self.repeat = kwargs.pop("repeat", self.repeat)
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value
    @property
    def repeat(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.repeat = value

cdef class dcgMouseDoubleClickHandler(dcgMouseDoubleClickHandler_):
    def __cinit__(self):
        self.button = -1
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgMouseDoubleClickedHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

cdef class dcgMouseDownHandler(dcgMouseDownHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgMouseDownHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

cdef class dcgMouseDragHandler(dcgMouseDragHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) == 2:
            button = args[0]
            threshold = args[1]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgMouseDragHandler. Expected button")
        button = kwargs.pop("button", button)
        threshold = kwargs.pop("threshold", threshold)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        self.threshold = threshold
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value

cdef class dcgMouseReleaseHandler(dcgMouseReleaseHandler_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        button = self.button
        if len(args) == 1:
            button = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgMouseReleaseHandler. Expected button")
        button = kwargs.pop("button", button)
        if button < -1 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = button
        super().configure(**kwargs)
    @property
    def button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.button
    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if value < -1 or value >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self.button = value
