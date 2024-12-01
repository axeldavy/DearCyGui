cdef extern from * nogil:
    """
    struct float2 {
        float p[2];
    };
    typedef struct float2 float2;
    struct double2 {
        double p[2];
    };
    typedef struct double2 double2;
    """
    ctypedef struct float2:
        float[2] p
    ctypedef struct double2:
        double[2] p