from .core cimport itemHandler, globalHandler, uiItem

cdef class dcgActivatedHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgActiveHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgClickedHandler(itemHandler):
    cdef int button
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgDoubleClickedHandler(itemHandler):
    cdef int button
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgDeactivatedHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgDeactivatedAfterEditHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgEditedHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgFocusHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgHoverHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgResizeHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgToggledOpenHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgVisibleHandler(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class dcgKeyDownHandler(globalHandler):
    cdef int key
    cdef void run_handler(self) noexcept nogil

cdef class dcgKeyPressHandler(globalHandler):
    cdef int key
    cdef bint repeat
    cdef void run_handler(self) noexcept nogil

cdef class dcgKeyReleaseHandler(globalHandler):
    cdef int key
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseClickHandler(globalHandler):
    cdef int button
    cdef bint repeat
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseDoubleClickHandler(globalHandler):
    cdef int button
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseDownHandler(globalHandler):
    cdef int button
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseDragHandler(globalHandler):
    cdef int button
    cdef float threshold
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseMoveHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseReleaseHandler(globalHandler):
    cdef int button
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseWheelHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil