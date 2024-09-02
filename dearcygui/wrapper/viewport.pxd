from dearcygui.wrapper.core cimport mvColor
from libcpp.string cimport string
from dearcygui.wrapper.graphics cimport mvGraphics

cdef extern from "mvViewport.h" nogil:
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

    mvViewport* mvCreateViewport  (unsigned width, unsigned height)
    void        mvCleanupViewport (mvViewport& viewport)
    void        mvShowViewport    (mvViewport& viewport,
                                   char minimized,
                                   char maximized,
                                   on_resize_fun,
                                   void *,
                                   on_close_fun,
                                   void *)
    void        mvMaximizeViewport(mvViewport& viewport)
    void        mvMinimizeViewport(mvViewport& viewport)
    void        mvRestoreViewport (mvViewport& viewport)
    void        mvRenderFrame(mvViewport& viewport,
						      render_fun render,
						      mvGraphics& graphics)
    void        mvToggleFullScreen(mvViewport& viewport)