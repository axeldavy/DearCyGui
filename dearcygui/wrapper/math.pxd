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
    struct double4 {
        double p[4];
    };
    typedef struct double4 double4;
    """
    ctypedef struct float4:
        float[4] p
    ctypedef struct double4:
        double[4] p