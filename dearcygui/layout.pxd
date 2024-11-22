from dearcygui.wrapper cimport imgui
from .core cimport uiItem
from .types cimport Alignment

from cpython.ref cimport PyObject
from libcpp.vector cimport vector

cdef class Layout(uiItem):
    cdef bint force_update
    cdef PyObject* previous_last_child
    cdef imgui.ImVec2 prev_content_area
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class HorizontalLayout(Layout):
    cdef Alignment _alignment_mode
    cdef float _spacing
    cdef vector[float] _positions
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class VerticalLayout(Layout):
    cdef Alignment _alignment_mode
    cdef float _spacing
    cdef vector[float] _positions
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil