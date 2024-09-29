from .core cimport *

cdef class ActivatedHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ActiveHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ClickedHandler(itemHandler):
    cdef int button
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil
    cdef void run_handler(self, baseItem, itemState&) noexcept nogil

cdef class DoubleClickedHandler(itemHandler):
    cdef int button
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil
    cdef void run_handler(self, baseItem, itemState&) noexcept nogil

cdef class DeactivatedHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class DeactivatedAfterEditHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class EditedHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class FocusHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class HoverHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ResizeHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class ToggledOpenHandler(itemHandler):
    cdef void check_bind(self, baseItem, itemState&)
    cdef bint check_state(self, baseItem, itemState&) noexcept nogil

cdef class VisibleHandler(itemHandler):
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