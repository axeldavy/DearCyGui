from .core cimport itemHandler, uiItem

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