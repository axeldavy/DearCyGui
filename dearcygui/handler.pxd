from .core cimport *

cdef class CustomHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cpdef enum handlerListOP:
    ALL,
    ANY,
    NONE

cdef class HandlerList(baseHandler):
    cdef handlerListOP _op
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class ConditionalHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class OtherItemHandler(HandlerList):
    cdef baseItem _target
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class ActivatedHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ActiveHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ClickedHandler(baseHandler):
    cdef int _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class DoubleClickedHandler(baseHandler):
    cdef int _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class DeactivatedHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class DeactivatedAfterEditHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class DraggedHandler(baseHandler):
    cdef int _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class DraggingHandler(baseHandler):
    cdef int _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class EditedHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class FocusHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class GotFocusHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class LostFocusHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class HoverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class GotHoverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class LostHoverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ResizeHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ToggledOpenHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ToggledCloseHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class OpenHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class CloseHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class RenderHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class GotRenderHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class LostRenderHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class MouseCursorHandler(baseHandler):
    cdef int _mouse_cursor
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AxesResizeHandler(baseHandler):
    cdef int[2] _axes
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyDownHandler(baseHandler):
    cdef int _key
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyPressHandler(baseHandler):
    cdef int _key
    cdef bint _repeat
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyReleaseHandler(baseHandler):
    cdef int _key
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseClickHandler(baseHandler):
    cdef int _button
    cdef bint _repeat
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDoubleClickHandler(baseHandler):
    cdef int _button
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDownHandler(baseHandler):
    cdef int _button
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDragHandler(baseHandler):
    cdef int _button
    cdef float _threshold
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseMoveHandler(baseHandler):
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseReleaseHandler(baseHandler):
    cdef int _button
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseWheelHandler(baseHandler):
    cdef bint _horizontal
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil