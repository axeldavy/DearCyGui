from libcpp.atomic cimport atomic
from libcpp.string cimport string

cdef extern from "backend.h" nogil:

    cdef struct mvViewport:
        bint running
        bint shown
        bint resized

        string title
        string small_icon
        string large_icon
        float[4] clear_color

        bint titleDirty
        bint modesDirty
        bint vsync
        bint resizable
        bint alwaysOnTop
        bint decorated
        bint fullScreen
        bint disableClose
        bint waitForEvents
        bint shouldSkipPresenting
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

    mvViewport* mvCreateViewport  (render_fun,
                                   on_resize_fun,
                                   on_close_fun,
                                   void *)
    void        mvCleanupViewport (mvViewport& viewport)
    bint        InitializeViewportWindow    (mvViewport& viewport,
                                   char start_minimized,
                                   char start_maximized)
    void        mvMaximizeViewport(mvViewport& viewport)
    void        mvMinimizeViewport(mvViewport& viewport)
    void        mvRestoreViewport (mvViewport& viewport)
    void        mvProcessEvents(mvViewport* viewport)
    bint        mvRenderFrame(mvViewport& viewport,
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
                                void* data,
                                unsigned src_stride)
    bint mvUpdateStaticTexture(void* texture,
                               unsigned width,
                               unsigned height,
                               unsigned num_chans,
                               unsigned type,
                               void* data,
                               unsigned src_stride)
