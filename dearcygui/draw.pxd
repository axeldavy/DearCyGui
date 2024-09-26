from .core cimport *

cdef class dcgViewportDrawList(dcgViewportDrawList_):
    pass

cdef class dcgDrawLayer(dcgDrawLayer_):
    pass

# Draw Node ? Seems to be exactly like Drawlayer, but with only
# the matrix settable (via apply_transform). -> merge to drawlayer

cdef class dcgDrawArrow(dcgDrawArrow_):
    pass

cdef class dcgDrawBezierCubic(dcgDrawBezierCubic_):
    pass

cdef class dcgDrawBezierQuadratic(dcgDrawBezierQuadratic_):
    pass

cdef class dcgDrawCircle(dcgDrawCircle_):
    pass

cdef class dcgDrawEllipse(dcgDrawEllipse_):
    pass

cdef class dcgDrawImage(dcgDrawImage_):
    pass

cdef class dcgDrawImageQuad(dcgDrawImageQuad_):
    pass

cdef class dcgDrawLine(dcgDrawLine_):
    pass

cdef class dcgDrawPolyline(dcgDrawPolyline_):
    pass

cdef class dcgDrawPolygon(dcgDrawPolygon_):
    pass

cdef class dcgDrawQuad(dcgDrawQuad_):
    pass

cdef class dcgDrawRect(dcgDrawRect_):
    pass

cdef class dgcDrawText(dgcDrawText_):
    pass

cdef class dcgDrawTriangle(dcgDrawTriangle_):
    pass

