from .core cimport *

cdef class ViewportDrawList(ViewportDrawList_):
    pass

cdef class DrawArrow(DrawArrow_):
    pass

cdef class DrawBezierCubic(DrawBezierCubic_):
    pass

cdef class DrawBezierQuadratic(DrawBezierQuadratic_):
    pass

cdef class DrawCircle(DrawCircle_):
    pass

cdef class DrawEllipse(DrawEllipse_):
    pass

cdef class DrawImage(DrawImage_):
    pass

cdef class DrawImageQuad(DrawImageQuad_):
    pass

cdef class DrawLine(DrawLine_):
    pass

cdef class DrawPolyline(DrawPolyline_):
    pass

cdef class DrawPolygon(DrawPolygon_):
    pass

cdef class DrawQuad(DrawQuad_):
    pass

cdef class DrawRect(DrawRect_):
    pass

cdef class DrawText(DrawText_):
    pass

cdef class DrawTriangle(DrawTriangle_):
    pass

