cdef extern from "mvMath.h" nogil:
    ctypedef struct ImVec2:
        float r, g
    ctypedef struct ImVec3:
        float r, g, b
    ctypedef struct ImVec4:
        float r, g, b, a

cdef extern from * nogil:
    """
    struct float4 {
        float p[4];
    };
    typedef struct float4 float4;
    """
    ctypedef struct float4:
        float[4] p