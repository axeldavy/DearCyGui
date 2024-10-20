from libcpp.atomic cimport atomic
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
        bint running
        bint shown
        bint resized

        string title
        string small_icon
        string large_icon
        mvColor clearColor

        bint titleDirty
        bint modesDirty
        bint vsync
        bint resizable
        bint alwaysOnTop
        bint decorated
        bint fullScreen
        bint disableClose
        bint waitForEvents
        atomic[bint] activity
        atomic[bint] needs_refresh

        bint sizeDirty
        bint posDirty
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
        float dpi
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

    mvViewport* mvCreateViewport  (render_fun,
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
    bint        mvRenderFrame(mvViewport& viewport,
                              mvGraphics& graphics,
                              bint can_skip_presenting)
    void        mvPresent(mvViewport* viewport)
    void        mvToggleFullScreen(mvViewport& viewport)
    void        mvWakeRendering(mvViewport& viewport)
    void        mvMakeUploadContextCurrent(mvViewport& viewport)
    void        mvReleaseUploadContext(mvViewport& viewport)

    void* mvAllocateTexture(unsigned width,
                            unsigned height,
                            unsigned num_chans,
                            unsigned dynamic,
                            unsigned type,
                            unsigned filtering_mode)
    void mvFreeTexture(void* texture)

    bint mvUpdateDynamicTexture(void* texture,
                                unsigned width,
                                unsigned height,
                                unsigned num_chans,
                                unsigned type,
                                void* data)
    bint mvUpdateStaticTexture(void* texture,
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