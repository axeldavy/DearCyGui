from dearcygui.wrapper cimport imgui, double4
from .core cimport baseItem, drawingItem, Texture, Font

from libcpp.string cimport string
from libcpp.vector cimport vector

cdef class ViewportDrawList(baseItem):
    cdef bint _front
    cdef bint _show
    cdef void draw(self) noexcept nogil

cdef class DrawingList(drawingItem):
    pass

cdef class DrawingListScale(drawingItem):
    cdef double[2] _scales
    cdef double[2] _shifts
    cdef bint _no_parent_scale
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawArrow(drawingItem):
    cdef double[2] start
    cdef double[2] end
    cdef double[2] corner1
    cdef double[2] corner2
    cdef imgui.ImU32 color
    cdef float thickness
    cdef float size
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil
    cdef void __compute_tip(self)

cdef class DrawBezierCubic(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef double[2] p4
    cdef imgui.ImU32 color
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawBezierQuadratic(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef imgui.ImU32 color
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawCircle(drawingItem):
    cdef double[2] center
    cdef float radius
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawEllipse(drawingItem):
    cdef double[2] pmin
    cdef double[2] pmax
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int segments
    cdef vector[double4] points
    cdef void __fill_points(self)
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawImage(drawingItem):
    cdef double[2] pmin
    cdef double[2] pmax
    cdef float[4] uv
    cdef imgui.ImU32 color_multiplier
    cdef Texture texture
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawImageQuad(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef double[2] p4
    cdef float[2] uv1
    cdef float[2] uv2
    cdef float[2] uv3
    cdef float[2] uv4
    cdef imgui.ImU32 color_multiplier
    cdef Texture texture
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawLine(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef imgui.ImU32 color
    cdef float thickness
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawPolyline(drawingItem):
    cdef imgui.ImU32 color
    cdef float thickness
    cdef bint closed
    cdef vector[double4] points
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawPolygon(drawingItem):
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef vector[double4] points
    cdef int[:,:] triangulation_indices
    cdef void __triangulate(self)
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawQuad(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef double[2] p4
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawRect(drawingItem):
    cdef double[2] pmin
    cdef double[2] pmax
    cdef imgui.ImU32 color
    cdef imgui.ImU32 color_upper_left
    cdef imgui.ImU32 color_upper_right
    cdef imgui.ImU32 color_bottom_left
    cdef imgui.ImU32 color_bottom_right
    cdef imgui.ImU32 fill
    cdef float rounding
    cdef float thickness
    cdef bint multicolor
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawText(drawingItem):
    cdef double[2] pos
    cdef string text
    cdef imgui.ImU32 color
    cdef float size
    cdef Font _font
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawTriangle(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int cull_mode
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

