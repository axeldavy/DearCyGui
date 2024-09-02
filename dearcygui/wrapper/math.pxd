cdef extern from "mvMath.h" nogil:
    ctypedef struct ImVec2:
        float r, g
    ctypedef struct ImVec3:
        float r, g, b
    ctypedef struct ImVec4:
        float r, g, b, a