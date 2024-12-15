from dearcygui.wrapper cimport imgui
from .core cimport uiItem
from .types cimport Alignment

from cpython.ref cimport PyObject
from libcpp.vector cimport vector

cdef class Layout(uiItem):
    cdef bint force_update
    cdef imgui.ImVec2 spacing
    cdef PyObject* previous_last_child
    cdef imgui.ImVec2 prev_content_area
    cdef imgui.ImVec2 get_content_area(self) noexcept nogil
    cdef void draw_child(self, uiItem child) noexcept nogil
    cdef void draw_children(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class HorizontalLayout(Layout):
    cdef Alignment _alignment_mode
    cdef vector[float] _positions
    cdef bint _no_wrap
    cdef float _wrap_x
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class VerticalLayout(Layout):
    cdef Alignment _alignment_mode
    cdef float _spacing
    cdef vector[float] _positions
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class WindowLayout(uiItem):
    cdef bint force_update
    cdef imgui.ImVec2 spacing
    cdef PyObject* previous_last_child
    cdef imgui.ImVec2 prev_content_area
    cdef imgui.ImVec2 get_content_area(self) noexcept nogil
    cdef void draw_child(self, uiItem child) noexcept nogil
    cdef void draw_children(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef void draw(self) noexcept nogil

cdef class WindowHorizontalLayout(WindowLayout):
    cdef Alignment _alignment_mode
    cdef vector[float] _positions 
    cdef float __compute_items_size(self, int &n_items) noexcept nogil
    cdef void __update_layout(self) noexcept nogil

cdef class WindowVerticalLayout(WindowLayout):
    cdef Alignment _alignment_mode
    cdef vector[float] _positions 
    cdef float __compute_items_size(self, int &n_items) noexcept nogil
    cdef void __update_layout(self) noexcept nogil