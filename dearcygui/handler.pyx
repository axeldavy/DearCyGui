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
                with gil:
                    self.context.queue.submit(self.on_close,
                                              self,
                                              (i, item),
                                              self.user_data)


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
                with gil:
                    self.context.queue.submit(self.on_close,
                                              self,
                                              (i, item),
                                              self.user_data)

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
