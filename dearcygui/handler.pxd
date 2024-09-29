from .core cimport *

cdef class ActivatedHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ActiveHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ClickedHandler(baseHandler):
    cdef int button
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil
    cdef void run_handler(self, baseItem, itemState&) noexcept nogil

cdef class DoubleClickedHandler(baseHandler):
    cdef int button
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil
    cdef void run_handler(self, baseItem, itemState&) noexcept nogil

cdef class DeactivatedHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class DeactivatedAfterEditHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class EditedHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class FocusHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class HoverHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ResizeHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ToggledOpenHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class VisibleHandler(baseHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class KeyDownHandler(KeyDownHandler_):
    pass

cdef class KeyPressHandler(KeyPressHandler_):
    pass

cdef class KeyReleaseHandler(KeyReleaseHandler_):
    pass

cdef class MouseClickHandler(MouseClickHandler_):
    pass

cdef class MouseDoubleClickHandler(MouseDoubleClickHandler_):
    pass

cdef class MouseDownHandler(MouseDownHandler_):
    pass

cdef class MouseDragHandler(MouseDragHandler_):
    pass

cdef class MouseReleaseHandler(MouseReleaseHandler_):
    pass