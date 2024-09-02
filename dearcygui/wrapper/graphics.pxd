from dearcygui.wrapper.core cimport mvColor
from dearcygui.wrapper.viewport cimport mvViewport


cdef extern from "mvGraphics.h":
    mvGraphics setup_graphics(mvViewport&)
    void resize_swapchain(mvGraphics&, int, int)
    void cleanup_graphics(mvGraphics&)
    void present(mvGraphics&, mvColor&, bint)
    struct mvGraphics:
        bint ok
        void* backendSpecifics
