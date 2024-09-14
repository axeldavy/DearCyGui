from libcpp.unordered_map cimport unordered_map
from libcpp.string cimport string
from dearcygui.wrapper cimport imgui
from .core cimport *

cdef class dcgThemeColorImGui(theme):
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImU32] index_to_value
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class dcgThemeColorImPlot(theme):
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImU32] index_to_value
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class dcgThemeColorImNodes(theme):
    cdef list names
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImU32] index_to_value
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil