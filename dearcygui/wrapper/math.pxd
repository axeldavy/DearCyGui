cdef extern from * nogil:
    """
    struct float4 {
        float p[4];
    };
    typedef struct float4 float4;
    struct double2 {
        double p[2];
    };
    typedef struct double2 double2;
    """
    ctypedef struct float4:
        float[4] p
    ctypedef struct double2:
        double[2] p