from dearcygui.wrapper.core cimport mvColor
from libcpp.string cimport string

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

    mvViewport* mvCreateViewport  (unsigned width, unsigned height)
    void        mvCleanupViewport (mvViewport& viewport)
    void        mvShowViewport    (mvViewport& viewport, char minimized, char maximized)
    void        mvMaximizeViewport(mvViewport& viewport)
    void        mvMinimizeViewport(mvViewport& viewport)
    void        mvRestoreViewport (mvViewport& viewport)
    void        mvRenderFrame()
    void        mvToggleFullScreen(mvViewport& viewport)