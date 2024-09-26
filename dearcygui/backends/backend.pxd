from libcpp.string cimport string

cdef extern from "backend.h" nogil:
    ctypedef struct mvColor:
        float r,g,b,a
        #mvColor()
        #mvColor(float r, float g, float b, float a)
        #mvColor(int r, int g, int b, int a)
        #mvColor(math.ImVec4 color)
        #const math.ImVec4 toVec4()
    #unsigned int ConvertToUnsignedInt(const mvColor& color)

    cdef struct mvViewport:
        char running
        char shown
        char resized

        string title
        string small_icon
        string large_icon
        mvColor clearColor

        char titleDirty
        char modesDirty
        char vsync
        char resizable
        char alwaysOnTop
        char decorated
        char fullScreen
        char disableClose
        char waitForEvents

        char sizeDirty
        char posDirty
        unsigned width
        unsigned height
        unsigned minwidth
        unsigned minheight
        unsigned maxwidth
        unsigned maxheight
        int actualWidth
        int actualHeight
        int clientWidth
        int clientHeight
        int xpos
        int ypos
    ctypedef void (*on_resize_fun)(void*, int, int)
    ctypedef void (*on_close_fun)(void*)
    ctypedef void (*render_fun)(void*)

    struct mvGraphics:
        bint ok
        void* backendSpecifics

    mvGraphics setup_graphics(mvViewport&)
    void resize_swapchain(mvGraphics&, int, int)
    void cleanup_graphics(mvGraphics&)
    void present(mvGraphics&, mvColor&, bint)

    mvViewport* mvCreateViewport  (unsigned width,
                                   unsigned height,
                                   render_fun,
                                   on_resize_fun,
                                   on_close_fun,
                                   void *)
    void        mvCleanupViewport (mvViewport& viewport)
    void        mvShowViewport    (mvViewport& viewport,
                                   char minimized,
                                   char maximized)
    void        mvMaximizeViewport(mvViewport& viewport)
    void        mvMinimizeViewport(mvViewport& viewport)
    void        mvRestoreViewport (mvViewport& viewport)
    void        mvProcessEvents(mvViewport* viewport)
    void        mvRenderFrame(mvViewport& viewport,
                              mvGraphics& graphics)
    void        mvPresent(mvViewport* viewport)
    void        mvToggleFullScreen(mvViewport& viewport)
    void        mvWakeRendering(mvViewport& viewport)
    void        mvMakeRenderingContextCurrent(mvViewport& viewport)
    void        mvReleaseRenderingContext(mvViewport& viewport)

    void* mvAllocateTexture(unsigned width,
                            unsigned height,
                            unsigned num_chans,
                            unsigned dynamic,
                            unsigned type,
                            unsigned filtering_mode)
    void mvFreeTexture(void* texture)

    void mvUpdateDynamicTexture(void* texture,
                                unsigned width,
                                unsigned height,
                                unsigned num_chans,
                                unsigned type,
                                void* data)
    void mvUpdateStaticTexture(void* texture,
                               unsigned width,
                               unsigned height,
                               unsigned num_chans,
                               unsigned type,
                               void* data)

cdef inline mvColor colorFromInts(int r, int g, int b, int a):
    cdef mvColor color
    color.r = r/255.
    color.g = g/255.
    color.b = b/255.
    color.a = a/255.
    return color