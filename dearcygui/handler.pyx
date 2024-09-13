from .core cimport itemHandler, uiItem
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from dearcygui.wrapper cimport imgui

cdef class dcgActivatedHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_activated):
            raise TypeError("Cannot bind activated item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.activated:
            self.run_callback(item)

cdef class dcgActiveHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_active):
            raise TypeError("Cannot bind activate item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        if not(uiItem.state.can_be_clicked):
            raise TypeError("Cannot bind clicked item handler for {}", type(item))

    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
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
        if not(uiItem.state.can_be_clicked):
            raise TypeError("Cannot bind clicked item handler for {}", type(item))

    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if item.state.double_clicked[i]:
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgDeactivatedHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_deactivated):
            raise TypeError("Cannot bind deactivated item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.deactivated:
            self.run_callback(item)

cdef class dcgDeactivatedAfterEditHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_deactivated_after_edited):
            raise TypeError("Cannot bind deactivated (after edit) item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.deactivated_after_edited:
            self.run_callback(item)

cdef class dcgEditedHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_edited):
            raise TypeError("Cannot bind edited item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.edited:
            self.run_callback(item)

cdef class dcgFocusHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_focused):
            raise TypeError("Cannot bind focus item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.focused:
            self.run_callback(item)

cdef class dcgHoverHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_hovered):
            raise TypeError("Cannot bind hover item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.hovered:
            self.run_callback(item)

cdef class dcgResizeHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.has_rect_size):
            raise TypeError("Cannot bind resize item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.resized:
            self.run_callback(item)

cdef class dcgToggledOpenHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(uiItem.state.can_be_toggled):
            raise TypeError("Cannot bind toggle item handler for {}", type(item))
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.toggled:
            self.run_callback(item)

cdef class dcgVisibleHandler(itemHandler):
    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return
    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if item.state.visible:
            self.run_callback(item)

cdef class dcgKeyDownHandler(globalHandler):
    def __cinit__(self):
        self.key = imgui.ImGuiKey_None

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

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiKeyData *key_info
        cdef int i
        if self.key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                key_info = imgui.GetKeyData(<imgui.ImGuiKey>i)
                if key_info.Down:
                    self.context.queue_callback_arg1int1float(self.callback, self, i, key_info.DownDuration)
        else:
            key_info = imgui.GetKeyData(<imgui.ImGuiKey>self.key)
            if key_info.Down:
                self.context.queue_callback_arg1int1float(self.callback, self, self.key, key_info.DownDuration)

cdef class dcgKeyPressHandler(globalHandler):
    def __cinit__(self):
        self.key = imgui.ImGuiKey_None
        self.repeat = True

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

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self.key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyPressed(<imgui.ImGuiKey>i, self.repeat):
                    self.context.queue_callback_arg1int(self.callback, self, i)
        else:
            if imgui.IsKeyPressed(<imgui.ImGuiKey>self.key, self.repeat):
                self.context.queue_callback_arg1int(self.callback, self, self.key)

cdef class dcgKeyReleaseHandler(globalHandler):
    def __cinit__(self):
        self.key = imgui.ImGuiKey_None

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

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self.key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyReleased(<imgui.ImGuiKey>i):
                    self.context.queue_callback_arg1int(self.callback, self, i)
        else:
            if imgui.IsKeyReleased(<imgui.ImGuiKey>self.key):
                self.context.queue_callback_arg1int(self.callback, self, self.key)


cdef class dcgMouseClickHandler(globalHandler):
    def __cinit__(self):
        self.button = -1
        self.repeat = False
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

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseClicked(i, self.repeat):
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgMouseDoubleClickHandler(globalHandler):
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

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseDoubleClicked(i):
                self.context.queue_callback_arg1int(self.callback, self, i)


cdef class dcgMouseDownHandler(globalHandler):
    def __cinit__(self):
        self.button = -1
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

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseDown(i):
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgMouseDragHandler(globalHandler):
    def __cinit__(self):
        self.button = -1
        self.threshold = -1 # < 0. means use default
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
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseMoveHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            self.context.queue_callback_arg2float(self.callback, self, io.MousePos.x, io.MousePos.y)
            

cdef class dcgMouseReleaseHandler(globalHandler):
    def __cinit__(self):
        self.button = -1
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

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseReleased(i):
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgMouseWheelHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if abs(io.MouseWheel) > 0.:
            self.context.queue_callback_arg1float(self.callback, self, io.MouseWheel)
