#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#distutils: language = c++

from libcpp cimport bool
import traceback

cimport cython
from cython.operator cimport dereference

# This file is the only one that is linked to the C++ code
# Thus it is the only one allowed to make calls to it

from dearcygui.wrapper cimport *
# We use unique_lock rather than lock_guard as
# the latter doesn't support nullary constructor
# which causes trouble to cython
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock

from concurrent.futures import ThreadPoolExecutor
from libc.stdlib cimport malloc, free
from .constants import constants

cdef extern from "../src/mvContext.h" nogil:
    cdef void initializeImGui()

cdef mvColor MV_BASE_COL_bgColor = mvColor(37, 37, 38, 255)
cdef mvColor MV_BASE_COL_lightBgColor = mvColor(82, 82, 85, 255)
cdef mvColor MV_BASE_COL_veryLightBgColor = mvColor(90, 90, 95, 255)
cdef mvColor MV_BASE_COL_panelColor = mvColor(51, 51, 55, 255)
cdef mvColor MV_BASE_COL_panelHoverColor = mvColor(29, 151, 236, 103)
cdef mvColor MV_BASE_COL_panelActiveColor = mvColor(0, 119, 200, 153)
cdef mvColor MV_BASE_COL_textColor = mvColor(255, 255, 255, 255)
cdef mvColor MV_BASE_COL_textDisabledColor = mvColor(151, 151, 151, 255)
cdef mvColor MV_BASE_COL_borderColor = mvColor(78, 78, 78, 255)
cdef mvColor mvImGuiCol_Text = MV_BASE_COL_textColor
cdef mvColor mvImGuiCol_TextSelectedBg = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_WindowBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_ChildBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_PopupBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_Border = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_BorderShadow = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_FrameBg = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_FrameBgHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_FrameBgActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_TitleBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_TitleBgActive = mvColor(15, 86, 135, 255)
cdef mvColor mvImGuiCol_TitleBgCollapsed = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_MenuBarBg = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_ScrollbarBg = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_ScrollbarGrab = MV_BASE_COL_lightBgColor
cdef mvColor mvImGuiCol_ScrollbarGrabHovered = MV_BASE_COL_veryLightBgColor
cdef mvColor mvImGuiCol_ScrollbarGrabActive = MV_BASE_COL_veryLightBgColor
cdef mvColor mvImGuiCol_CheckMark = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_SliderGrab = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_SliderGrabActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_Button = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_ButtonHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_ButtonActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_Header = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_HeaderHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_HeaderActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_Separator = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_SeparatorHovered = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_SeparatorActive = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_ResizeGrip = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_ResizeGripHovered = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_Tab = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_TabHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_TabActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_TabUnfocused = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_TabUnfocusedActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_DockingPreview = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_DockingEmptyBg = mvColor(51, 51, 51, 255)
cdef mvColor mvImGuiCol_PlotLines = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_PlotLinesHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_PlotHistogram = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_PlotHistogramHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_DragDropTarget = mvColor(255, 255, 0, 179)
cdef mvColor mvImGuiCol_NavHighlight = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_NavWindowingHighlight = mvColor(255, 255, 255, 179)
cdef mvColor mvImGuiCol_NavWindowingDimBg = mvColor(204, 204, 204, 51)
cdef mvColor mvImGuiCol_ModalWindowDimBg = mvColor(37, 37, 38, 150)
cdef mvColor mvImGuiCol_TableHeaderBg = mvColor(48, 48, 51, 255)
cdef mvColor mvImGuiCol_TableBorderStrong = mvColor(79, 79, 89, 255)
cdef mvColor mvImGuiCol_TableBorderLight = mvColor(59, 59, 64, 255)
cdef mvColor mvImGuiCol_TableRowBg = mvColor(0, 0, 0, 0)
cdef mvColor mvImGuiCol_TableRowBgAlt = mvColor(255, 255, 255, 15)


cdef unsigned int ConvertToUnsignedInt(const mvColor color):
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(color.r, color.g, color.b, color.a))

cdef void internal_resize_callback(void *object, int a, int b) noexcept nogil:
    with gil:
        try:
            (<dcgViewport>object).__on_resize(a, b)
        except Exception as e:
            print("An error occured in the viewport resize callback", traceback.format_exc())

cdef void internal_close_callback(void *object) noexcept nogil:
    with gil:
        try:
            (<dcgViewport>object).__on_close()
        except Exception as e:
            print("An error occured in the viewport close callback", traceback.format_exc())

cdef void internal_render_callback(void *object) noexcept nogil:
    (<dcgViewport>object).__render()

@cython.final
cdef class dcgViewport:
    def __init__(self, context):
        self.context = context
        self.resize_callback = None
        self.initialized = False

    def __cinit__(self):
        self.viewport = NULL
        self.graphics_initialized = False

    def __dealloc__(self):
        if self.graphics_initialized:
            cleanup_graphics(self.graphics)
        if self.viewport != NULL:
            mvCleanupViewport(dereference(self.viewport))
            #free(self.viewport) deleted by mvCleanupViewport
            self.viewport = NULL

    cdef initialize(self, unsigned width, unsigned height):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        self.viewport = mvCreateViewport(width,
                                         height,
                                         internal_render_callback,
                                         internal_resize_callback,
                                         internal_close_callback,
                                         <void*>self)
        self.initialized = True

    cdef void __check_initialized(self):
        if not(self.initialized):
            raise RuntimeError("The viewport must be initialized before being used")

    @property
    def clear_color(self):
        self.__check_initialized()
        return (self.viewport.clearColor.r,
                self.viewport.clearColor.g,
                self.viewport.clearColor.b,
                self.viewport.clearColor.a)

    @clear_color.setter
    def clear_color(self, tuple value):
        cdef int r, g, b, a
        self.__check_initialized()
        (r, g, b, a) = value
        self.viewport.clearColor = colorFromInts(r, g, b, a)

    @property
    def small_icon(self):
        self.__check_initialized()
        return str(self.viewport.small_icon)

    @small_icon.setter
    def small_icon(self, str value):
        self.__check_initialized()
        self.viewport.small_icon = value.encode("utf-8")

    @property
    def large_icon(self):
        self.__check_initialized()
        return str(self.viewport.large_icon)

    @large_icon.setter
    def large_icon(self, str value):
        self.__check_initialized()
        self.viewport.large_icon = value.encode("utf-8")

    @property
    def x_pos(self):
        self.__check_initialized()
        return self.viewport.xpos

    @x_pos.setter
    def x_pos(self, int value):
        self.__check_initialized()
        self.viewport.xpos = value
        self.viewport.posDirty = 1

    @property
    def y_pos(self):
        self.__check_initialized()
        return self.viewport.ypos

    @y_pos.setter
    def y_pos(self, int value):
        self.__check_initialized()
        self.viewport.ypos = value
        self.viewport.posDirty = 1

    @property
    def width(self):
        self.__check_initialized()
        return self.viewport.actualWidth

    @width.setter
    def width(self, int value):
        self.__check_initialized()
        self.viewport.actualWidth = value
        self.viewport.sizeDirty = 1

    @property
    def height(self):
        self.__check_initialized()
        return self.viewport.actualHeight

    @height.setter
    def height(self, int value):
        self.__check_initialized()
        self.viewport.actualHeight = value
        self.viewport.sizeDirty = 1

    @property
    def resizable(self) -> bint:
        self.__check_initialized()
        return self.viewport.resizable

    @resizable.setter
    def resizable(self, bint value):
        self.__check_initialized()
        self.viewport.resizable = value
        self.viewport.modesDirty = 1

    @property
    def vsync(self) -> bint:
        self.__check_initialized()
        return self.viewport.vsync

    @vsync.setter
    def vsync(self, bint value):
        self.__check_initialized()
        self.viewport.vsync = value

    @property
    def min_width(self):
        self.__check_initialized()
        return self.viewport.minwidth

    @min_width.setter
    def min_width(self, unsigned value):
        self.__check_initialized()
        self.viewport.minwidth = value

    @property
    def max_width(self):
        self.__check_initialized()
        return self.viewport.maxwidth

    @max_width.setter
    def max_width(self, unsigned value):
        self.__check_initialized()
        self.viewport.maxwidth = value

    @property
    def min_height(self):
        self.__check_initialized()
        return self.viewport.minheight

    @min_height.setter
    def min_height(self, unsigned value):
        self.__check_initialized()
        self.viewport.minheight = value

    @property
    def max_height(self):
        self.__check_initialized()
        return self.viewport.maxheight

    @max_height.setter
    def max_height(self, unsigned value):
        self.__check_initialized()
        self.viewport.maxheight = value

    @property
    def always_on_top(self) -> bint:
        self.__check_initialized()
        return self.viewport.alwaysOnTop

    @always_on_top.setter
    def always_on_top(self, bint value):
        self.__check_initialized()
        self.viewport.alwaysOnTop = value
        self.viewport.modesDirty = 1

    @property
    def decorated(self) -> bint:
        self.__check_initialized()
        return self.viewport.decorated

    @decorated.setter
    def decorated(self, bint value):
        self.__check_initialized()
        self.viewport.decorated = value
        self.viewport.modesDirty = 1

    @property
    def title(self):
        self.__check_initialized()
        return str(self.viewport.title)

    @title.setter
    def title(self, str value):
        self.__check_initialized()
        self.viewport.title = value.encode("utf-8")
        self.viewport.titleDirty = 1

    @property
    def disable_close(self) -> bint:
        self.__check_initialized()
        return self.viewport.disableClose

    @disable_close.setter
    def disable_close(self, bint value):
        self.__check_initialized()
        self.viewport.disableClose = value
        self.viewport.modesDirty = 1

    @property
    def fullscreen(self):
        return self.viewport.fullScreen

    @fullscreen.setter
    def fullscreen(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        if value and not(self.viewport.fullScreen):
            mvToggleFullScreen(dereference(self.viewport))
        elif not(value) and (self.viewport.fullScreen):
            print("TODO: fullscreen(false)")

    @property
    def shown(self) -> bint:
        self.__check_initialized()
        return self.viewport.shown

    def configure(self, **kwargs):
        for (key, value) in kwargs.items():
            setattr(self, key, value)

    cdef void __on_resize(self, int width, int height):
        self.__check_initialized()
        self.viewport.actualHeight = height
        self.viewport.clientHeight = height
        self.viewport.actualWidth = width
        self.viewport.clientWidth = width
        self.viewport.resized = True
        if self.resize_callback is None:
            return
        dimensions = (self.viewport.actualWidth,
                      self.viewport.actualHeight,
                      self.viewport.clientWidth,
                      self.viewport.clientHeight)
        self.context.queue.submit(self.resize_callback, constants.MV_APP_UUID, dimensions)

    cdef void __on_close(self):
        self.__check_initialized()
        if not(<bint>self.viewport.disableClose):
            self.context.started = False
        if self.close_callback is None:
            return
        self.context.queue.submit(self.close_callback, constants.MV_APP_UUID, None)

    cdef void __render(self) noexcept nogil:
        if self.fontRegistryRoots is not None:
            self.fontRegistryRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.handlerRegistryRoots is not None:
            self.handlerRegistryRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.textureRegistryRoots is not None:
            self.textureRegistryRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.filedialogRoots is not None:
            self.filedialogRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.colormapRoots is not None:
            self.colormapRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.windowRoots is not None:
            self.windowRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.viewportMenubarRoots is not None:
            self.viewportMenubarRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.viewportDrawlistRoots is not None:
            self.viewportDrawlistRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.windowRoots is not None:
            self.windowRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        return

    def render_frame(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        self.__check_initialized()
        assert(self.graphics_initialized)
        with nogil:
            mvRenderFrame(dereference(self.viewport),
			    		  self.graphics)
        if self.viewport.resized:
            if self.resize_callback is not None:
                dimensions = (self.viewport.actualWidth,
                              self.viewport.actualHeight,
                              self.viewport.clientWidth,
                              self.viewport.clientHeight)
                self.context.queue.submit(self.resize_callback, constants.MV_APP_UUID, dimensions)
            self.viewport.resized = False

    def show(self, minimized=False, maximized=False):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef imgui.ImGuiStyle* style
        cdef mvColor* colors
        self.__check_initialized()
        mvShowViewport(dereference(self.viewport),
                       minimized,
                       maximized)
        if not(self.graphics_initialized):
            self.graphics = setup_graphics(dereference(self.viewport))
            imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = True
            # TODO if (GContext->IO.autoSaveIniFile). if (!GContext->IO.iniFile.empty())
			# io.IniFilename = GContext->IO.iniFile.c_str();

            # TODO if(GContext->IO.kbdNavigation)
		    # io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;  // Enable Keyboard Controls
            #if(GContext->IO.docking)
            # io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
            # io.ConfigDockingWithShift = GContext->IO.dockingShiftOnly;

            # Setup Dear ImGui style
            imgui.StyleColorsDark()
            style = &imgui.GetStyle()
            colors = <mvColor*>style.Colors

            colors[<int>imgui.ImGuiCol_Text] = MV_BASE_COL_textColor
            colors[<int>imgui.ImGuiCol_TextDisabled] = MV_BASE_COL_textDisabledColor
            colors[<int>imgui.ImGuiCol_WindowBg] = mvImGuiCol_WindowBg
            colors[<int>imgui.ImGuiCol_ChildBg] = mvImGuiCol_ChildBg
            colors[<int>imgui.ImGuiCol_PopupBg] = mvImGuiCol_PopupBg
            colors[<int>imgui.ImGuiCol_Border] = mvImGuiCol_Border
            colors[<int>imgui.ImGuiCol_BorderShadow] = mvImGuiCol_BorderShadow
            colors[<int>imgui.ImGuiCol_FrameBg] = mvImGuiCol_FrameBg
            colors[<int>imgui.ImGuiCol_FrameBgHovered] = mvImGuiCol_FrameBgHovered
            colors[<int>imgui.ImGuiCol_FrameBgActive] = mvImGuiCol_FrameBgActive
            colors[<int>imgui.ImGuiCol_TitleBg] = mvImGuiCol_TitleBg
            colors[<int>imgui.ImGuiCol_TitleBgActive] = mvImGuiCol_TitleBgActive
            colors[<int>imgui.ImGuiCol_TitleBgCollapsed] = mvImGuiCol_TitleBgCollapsed
            colors[<int>imgui.ImGuiCol_MenuBarBg] = mvImGuiCol_MenuBarBg
            colors[<int>imgui.ImGuiCol_ScrollbarBg] = mvImGuiCol_ScrollbarBg
            colors[<int>imgui.ImGuiCol_ScrollbarGrab] = mvImGuiCol_ScrollbarGrab
            colors[<int>imgui.ImGuiCol_ScrollbarGrabHovered] = mvImGuiCol_ScrollbarGrabHovered
            colors[<int>imgui.ImGuiCol_ScrollbarGrabActive] = mvImGuiCol_ScrollbarGrabActive
            colors[<int>imgui.ImGuiCol_CheckMark] = mvImGuiCol_CheckMark
            colors[<int>imgui.ImGuiCol_SliderGrab] = mvImGuiCol_SliderGrab
            colors[<int>imgui.ImGuiCol_SliderGrabActive] = mvImGuiCol_SliderGrabActive
            colors[<int>imgui.ImGuiCol_Button] = mvImGuiCol_Button
            colors[<int>imgui.ImGuiCol_ButtonHovered] = mvImGuiCol_ButtonHovered
            colors[<int>imgui.ImGuiCol_ButtonActive] = mvImGuiCol_ButtonActive
            colors[<int>imgui.ImGuiCol_Header] = mvImGuiCol_Header
            colors[<int>imgui.ImGuiCol_HeaderHovered] = mvImGuiCol_HeaderHovered
            colors[<int>imgui.ImGuiCol_HeaderActive] = mvImGuiCol_HeaderActive
            colors[<int>imgui.ImGuiCol_Separator] = mvImGuiCol_Separator
            colors[<int>imgui.ImGuiCol_SeparatorHovered] = mvImGuiCol_SeparatorHovered
            colors[<int>imgui.ImGuiCol_SeparatorActive] = mvImGuiCol_SeparatorActive
            colors[<int>imgui.ImGuiCol_ResizeGrip] = mvImGuiCol_ResizeGrip
            colors[<int>imgui.ImGuiCol_ResizeGripHovered] = mvImGuiCol_ResizeGripHovered
            colors[<int>imgui.ImGuiCol_ResizeGripActive] = mvImGuiCol_ResizeGripHovered
            colors[<int>imgui.ImGuiCol_Tab] = mvImGuiCol_Tab
            colors[<int>imgui.ImGuiCol_TabHovered] = mvImGuiCol_TabHovered
            colors[<int>imgui.ImGuiCol_TabActive] = mvImGuiCol_TabActive
            colors[<int>imgui.ImGuiCol_TabUnfocused] = mvImGuiCol_TabUnfocused
            colors[<int>imgui.ImGuiCol_TabUnfocusedActive] = mvImGuiCol_TabUnfocusedActive
            colors[<int>imgui.ImGuiCol_DockingPreview] = mvImGuiCol_DockingPreview
            colors[<int>imgui.ImGuiCol_DockingEmptyBg] = mvImGuiCol_DockingEmptyBg
            colors[<int>imgui.ImGuiCol_PlotLines] = mvImGuiCol_PlotLines
            colors[<int>imgui.ImGuiCol_PlotLinesHovered] = mvImGuiCol_PlotLinesHovered
            colors[<int>imgui.ImGuiCol_PlotHistogram] = mvImGuiCol_PlotHistogram
            colors[<int>imgui.ImGuiCol_PlotHistogramHovered] = mvImGuiCol_PlotHistogramHovered
            colors[<int>imgui.ImGuiCol_TableHeaderBg] = mvImGuiCol_TableHeaderBg
            colors[<int>imgui.ImGuiCol_TableBorderStrong] = mvImGuiCol_TableBorderStrong   # Prefer using Alpha=1.0 here
            colors[<int>imgui.ImGuiCol_TableBorderLight] = mvImGuiCol_TableBorderLight   # Prefer using Alpha=1.0 here
            colors[<int>imgui.ImGuiCol_TableRowBg] = mvImGuiCol_TableRowBg
            colors[<int>imgui.ImGuiCol_TableRowBgAlt] = mvImGuiCol_TableRowBgAlt
            colors[<int>imgui.ImGuiCol_TextSelectedBg] = mvImGuiCol_TextSelectedBg
            colors[<int>imgui.ImGuiCol_DragDropTarget] = mvImGuiCol_DragDropTarget
            colors[<int>imgui.ImGuiCol_NavHighlight] = mvImGuiCol_NavHighlight
            colors[<int>imgui.ImGuiCol_NavWindowingHighlight] = mvImGuiCol_NavWindowingHighlight
            colors[<int>imgui.ImGuiCol_NavWindowingDimBg] = mvImGuiCol_NavWindowingDimBg
            colors[<int>imgui.ImGuiCol_ModalWindowDimBg] = mvImGuiCol_ModalWindowDimBg

            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeBackground] = ConvertToUnsignedInt(mvColor(62, 62, 62, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeBackgroundHovered] = ConvertToUnsignedInt(mvColor(75, 75, 75, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeBackgroundSelected] = ConvertToUnsignedInt(mvColor(75, 75, 75, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeOutline] = ConvertToUnsignedInt(mvColor(100, 100, 100, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_TitleBar] = ConvertToUnsignedInt(mvImGuiCol_TitleBg)
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_TitleBarHovered] = ConvertToUnsignedInt(mvImGuiCol_TitleBgActive)
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_TitleBarSelected] = ConvertToUnsignedInt(mvImGuiCol_FrameBgActive)
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_Link] = ConvertToUnsignedInt(mvColor(255, 255, 255, 200))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_LinkHovered] = ConvertToUnsignedInt(mvColor(66, 150, 250, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_LinkSelected] = ConvertToUnsignedInt(mvColor(66, 150, 250, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_Pin] = ConvertToUnsignedInt(mvColor(199, 199, 41, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_PinHovered] = ConvertToUnsignedInt(mvColor(255, 255, 50, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_BoxSelector] = ConvertToUnsignedInt(mvColor(61, 133, 224, 30))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_BoxSelectorOutline] = ConvertToUnsignedInt(mvColor(61, 133, 224, 150))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_GridBackground] = ConvertToUnsignedInt(mvColor(35, 35, 35, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_GridLine] = ConvertToUnsignedInt(mvColor(0, 0, 0, 255))

            self.graphics_initialized = True
        self.viewport.shown = 1


cdef class dcgContext:
    def __init__(self):
        self.on_close_callback = None
        self.on_frame_callbacks = None
        self.queue = ThreadPoolExecutor(max_workers=1)

    def __cinit__(self):
        self.waitOneFrame = False
        self.started = False
        self.deltaTime = 0.
        self.time = 0.
        self.frame = 0
        self.framerate = 0
        self.viewport = dcgViewport(self)
        self.resetTheme = False
        imgui.IMGUI_CHECKVERSION()
        imgui.CreateContext()
        implot.CreateContext()
        imnodes.CreateContext()
        #mvToolManager::GetFontManager()._dirty = true;

    def __dealloc__(self):
        self.started = True

    def __del__(self):
        if self.on_close_callback is not None:
            self.started = True
            self.queue.submit(self.on_close_callback)
            self.started = False

        imnodes.DestroyContext()
        implot.DestroyContext()
        imgui.DestroyContext()

        #mvToolManager::Reset()
        #ClearItemRegistry(*GContext->itemRegistry)

        self.queue.shutdown(wait=True)

    def initialize_viewport(self, **kwargs):
        self.viewport.initialize(width=kwargs["width"],
                                 height=kwargs["height"])
        self.viewport.configure(**kwargs)

    def start(self):
        if self.started:
            raise ValueError("Cannot call \"setup_dearpygui\" while a Dear PyGUI app is already running.")
        self.started = True

    @property
    def running(self):
        return self.started

cdef class appItem:
    def __init__(self, context):
        self.context = context

    def __cinit__(self):
        self.uuid = 0
        # mvAppItemInfo
        self.internalLabel = b""
        self.location = -1
        self.showDebug = False
        # next frame triggers
        self.focusNextFrame = False
        self.triggerAlternativeAction = False
        self.shownLastFrame = False
        self.hiddenLastFrame = False
        self.enabledLastFrame = False
        self.disabledLastFrame = False
        # previous frame cache
        self.previousCursorPos = imgui.ImVec2(0., 0.)
        # dirty flags
        self.dirty_size = True
        self.dirtyPos = False
        # mvAppItemState
        self.hovered = False
        self.active = False
        self.focused = False
        self.leftclicked = False
        self.rightclicked = False
        self.middleclicked = False
        self.doubleclicked = [False, False, False, False, False]
        self.visible = False
        self.edited = False
        self.activated = False
        self.deactivated = False
        self.deactivatedAfterEdit = False
        self.toggledOpen = False
        self.mvRectSizeResized = False
        self.rectMin = imgui.ImVec2(0., 0.)
        self.rectMax = imgui.ImVec2(0., 0.)
        self.rectSize = imgui.ImVec2(0., 0.)
        self.mvPrevRectSize = imgui.ImVec2(0., 0.)
        self.pos = imgui.ImVec2(0., 0.)
        self.contextRegionAvail = imgui.ImVec2(0., 0.)
        self.ok = True
        self.lastFrameUpdate = 0 # last frame update occured
        self.parent = None
        # mvAppItemConfig
        self.source = 0
        self.parent = 0
        self.specifiedLabel = b""
        self.filter = b""
        self.alias = b""
        self.payloadType = b"$$DPG_PAYLOAD"
        self.width = 0
        self.height = 0
        self.indent = -1.
        self.trackOffset = 0.5 # 0.0f:top, 0.5f:center, 1.0f:bottom
        self.show = True
        self.enabled = True
        self.useInternalLabel = True #when false, will use specificed label
        self.tracked = False
        self.callback = None
        self.user_data = None
        self.dragCallback = None
        self.dropCallback = None
        # mvAppItemDrawInfo

        #mvMat4 transform         = mvIdentityMat4();
        #mvMat4 appliedTransform  = mvIdentityMat4(); // only used by nodes
        self.cullMode = 0 # mvCullMode_None
        self.perspectiveDivide = False
        self.depthClipping = False
        self.clipViewport = [0.0, 0.0, 1.0, 1.0, -1.0, 1.0 ] # top leftx, top lefty, width, height, min depth, maxdepth

    cdef void draw(self, imgui.ImDrawList* l, float x, float y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            self.prev_sibling.draw(l, x, y)
        return

    #cpdef void delete(self):
    def delete(self):
        # We are going to change the tree structure, we must lock the global mutex first and foremost
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.edition_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        # Remove this item from the list of elements
        if self.prev_sibling is not None:
            self.prev_sibling.next_sibling = self.next_sibling
        if self.next_sibling is not None:
            self.next_sibling.prev_sibling = self.prev_sibling
        # delete all its children recursively
        if self.last_0_child is not None:
            self.last_0_child.__delete_and_siblings()
        if self.last_widgets_child is not None:
            self.last_widgets_child.__delete_and_siblings()
        if self.last_drawings_child is not None:
            self.last_drawings_child.__delete_and_siblings()
        if self.last_payloads_child is not None:
            self.last_payloads_child.__delete_and_siblings()
        # Free references
        self.context = None
        self.parent = None
        self.prev_sibling = None
        self.next_sibling = None
        self.last_0_child = None
        self.last_widgets_child = None
        self.last_drawings_child = None
        self.last_payloads_child = None

    cdef void __delete_and_siblings(self):
        # We are going to change the tree structure, we must lock the global mutex first and foremost
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.edition_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        # delete all its children recursively
        if self.last_0_child is not None:
            self.last_0_child.__delete_and_siblings()
        if self.last_widgets_child is not None:
            self.last_widgets_child.__delete_and_siblings()
        if self.last_drawings_child is not None:
            self.last_drawings_child.__delete_and_siblings()
        if self.last_payloads_child is not None:
            self.last_payloads_child.__delete_and_siblings()
        # delete previous sibling
        if self.prev_sibling is not None:
            self.prev_sibling.__delete_and_siblings()
        # Free references
        self.context = None
        self.parent = None
        self.prev_sibling = None
        self.next_sibling = None
        self.last_0_child = None
        self.last_widgets_child = None
        self.last_drawings_child = None
        self.last_payloads_child = None
        

cdef class dcgWindow(appItem):
    def __cinit__(self):
        self.windowflags = imgui.ImGuiWindowFlags_None
        self.mainWindow = False
        self.closing = True
        self.resized = False
        self.modal = False
        self.popup = False
        self.autosize = False
        self.no_resize = False
        self.no_title_bar = False
        self.no_move = False
        self.no_scrollbar = False
        self.no_collapse = False
        self.horizontal_scrollbar = False
        self.no_focus_on_appearing = False
        self.no_bring_to_front_on_focus = False
        self.menubar = False
        self.no_close = False
        self.no_background = False
        self.collapsed = False
        self.no_open_over_existing_popup = True
        self.on_close = None
        self.min_size = imgui.ImVec2(100., 100.)
        self.max_size = imgui.ImVec2(30000., 30000.)
        self.scrollX = 0.
        self.scrollY = 0.
        self.scrollMaxX = 0.
        self.scrollMaxY = 0.
        self._collapsedDirty = True
        self._scrollXSet = False
        self._scrollYSet = False
        self._oldWindowflags = imgui.ImGuiWindowFlags_None
        self._oldxpos = 200
        self._oldypos = 200
        self._oldWidth = 200
        self._oldHeight = 200

    cdef void draw(self, imgui.ImDrawList* parent_drawlist, float parent_x, float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            self.prev_sibling.draw(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.context.frame == 1:
            # TODO && !GContext->IO.iniFile.empty() && !(config.windowflags & ImGuiWindowFlags_NoSavedSettings)
            self.dirtyPos = False
            self.dirty_size = False
            self._collapsedDirty = False

        if self.focusNextFrame:
            imgui.SetNextWindowFocus()
            self.focusNextFrame = False

        # handle fonts
        """
        if self.font:
            ImFont* fontptr = static_cast<mvFont*>(item.font.get())->getFontPtr();
            ImGui::PushFont(fontptr);
        """

        # themes
        #apply_local_theming(&item);

        # Draw the window
        imgui.PushID(self.uuid)

        if self.mainWindow:
            imgui.SetNextWindowBgAlpha(1.0)
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowRounding, 0.0) #to prevent main window corners from showing
            imgui.SetNextWindowPos(imgui.ImVec2(0.0, 0.0), <imgui.ImGuiCond>0)
            imgui.SetNextWindowSize(imgui.ImVec2(<float>self.context.viewport.viewport.clientWidth,
                                           <float>self.context.viewport.viewport.clientHeight),
                                    <imgui.ImGuiCond>0)

        if self.dirtyPos:
            imgui.SetNextWindowPos(self.pos, <imgui.ImGuiCond>0)
            self.dirtyPos = False

        if self.dirty_size:
            imgui.SetNextWindowSize(imgui.ImVec2(<float>self.width,
                                           <float>self.height),
                                    <imgui.ImGuiCond>0)
            self.dirty_size = False

        if self._collapsedDirty:
            imgui.SetNextWindowCollapsed(self.collapsed, <imgui.ImGuiCond>0)
            self._collapsedDirty = False

        imgui.SetNextWindowSizeConstraints(self.min_size, self.max_size)

        cdef bint opened = True
        if self.modal or self.popup:
            if self.shownLastFrame:
                self.shownLastFrame = False;
                imgui.OpenPopup(self.internalLabel.c_str(),
                                imgui.ImGuiPopupFlags_NoOpenOverExistingPopup if self.no_open_over_existing_popup else imgui.ImGuiPopupFlags_None)

            if self.modal:
                opened = imgui.BeginPopupModal(self.internalLabel.c_str(), <bool*>NULL if self.no_close else &self.show, self.windowflags)
            else:
                opened = imgui.BeginPopup(self.internalLabel.c_str(), self.windowflags)
            if not(opened):
                if self.mainWindow:
                    imgui.PopStyleVar(1)
                    self.show = False
                    self.lastFrameUpdate = self.context.frame
                    self.hovered = False
                    self.focused = False
                    self.toggledOpen = False
                    self.visible = False

                with gil:
                    if self.on_close is not None:
                        self.context.queue.submit(self.on_close,
                                                  self.uuid if self.alias.empty() else None,
                                                  None,
                                                  self.user_data)
                #// handle popping themes
                #cleanup_local_theming(&item);

                imgui.PopID()
                return
        else:
            opened = imgui.Begin(self.internalLabel.c_str(),
                                 <bool*>NULL if self.no_close else &self.show,
                                 self.windowflags)
            if not(opened):
                if self.mainWindow:
                    imgui.PopStyleVar(1)

                imgui.End()

                #// handle popping themes
                #cleanup_local_theming(&item);

                imgui.PopID()
                return
        if self.mainWindow:
            imgui.PopStyleVar(1)

        # Draw the window content
        cdef imgui.ImDrawList* this_drawlist = imgui.GetWindowDrawList()

        cdef float startx = <float>imgui.GetCursorScreenPos().x
        cdef float starty = <float>imgui.GetCursorScreenPos().y

        # Each child calls draw for a sibling
        if self.last_0_child is not None:
            self.last_0_child.draw(this_drawlist, startx, starty)

        startx = <float>imgui.GetCursorPosX()
        starty = <float>imgui.GetCursorPosY()
        if self.last_widgets_child is not None:
            self.last_widgets_child.draw(this_drawlist, startx, starty)
            # TODO if self.children_widgets[i].tracked and show:
            #    imgui.SetScrollHereY(self.children_widgets[i].trackOffset)

        startx = <float>imgui.GetCursorScreenPos().x
        starty = <float>imgui.GetCursorScreenPos().y
        if self.last_drawings_child is not None:
            self.last_drawings_child.draw(this_drawlist, startx, starty)
            # TODO UpdateAppItemState(child->state) if show

        # Post draw
        """
        // pop font from stack
        if (item.font)
            ImGui::PopFont();
        """

        #// handle popping themes
        #cleanup_local_theming(&item);

        if self._scrollXSet:
            if self.scrollX < 0.0:
                imgui.SetScrollHereX(1.0)
            else:
                imgui.SetScrollX(self.scrollX)
            self._scrollXSet = False

        if self._scrollYSet:
            if self.scrollY < 0.0:
                imgui.SetScrollHereY(1.0)
            else:
                imgui.SetScrollY(self.scrollY)
            self._scrollYSet = False
        self.scrollX = imgui.GetScrollX()
        self.scrollY = imgui.GetScrollY()
        self.scrollMaxX = imgui.GetScrollMaxX()
        self.scrollMaxY = imgui.GetScrollMaxY()

        self.lastFrameUpdate = self.context.frame
        self.visible = True
        self.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
        self.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
        self.rectSize.x = imgui.GetWindowSize().x
        self.rectSize.y = imgui.GetWindowSize().y
        self.toggledOpen = imgui.IsWindowCollapsed()
        if (self.mvPrevRectSize.x != self.rectSize.x or self.mvPrevRectSize.y != self.rectSize.y):
            self.mvRectSizeResized = True
            self.mvPrevRectSize.x = self.rectSize.x
            self.mvPrevRectSize.y = self.rectSize.y
        else:
            self.mvRectSizeResized = False

        if (imgui.GetWindowWidth() != <float>self.width or imgui.GetWindowHeight() != <float>self.height):
            self.width = <int>imgui.GetWindowWidth()
            self.height = <int>imgui.GetWindowHeight()
            self.resized = True

        cdef bint focused = self.focused
        if self.lastFrameUpdate != self.context.frame:
            focused = False

        self.pos.x = imgui.GetWindowPos().x
        self.pos.y = imgui.GetWindowPos().y

        cdef float titleBarHeight
        cdef float x, y
        cdef imgui.ImVec2 mousePos
        if focused:
            titleBarHeight = imgui.GetStyle().FramePadding.y * 2 + imgui.GetFontSize()

            # update mouse
            mousePos = imgui.GetMousePos()
            x = mousePos.x - self.pos.x
            y = mousePos.y - self.pos.y - titleBarHeight
            #GContext->input.mousePos.x = (int)x;
            #GContext->input.mousePos.y = (int)y;
            #GContext->activeWindow = item

        if (self.modal or self.popup):
            imgui.EndPopup()
        else:
            imgui.End()

        self.collapsed = imgui.IsWindowCollapsed()

        # we switched from a show to a no show state
        if not(self.show):
            self.lastFrameUpdate = self.context.frame
            self.hovered = False
            self.focused = False
            self.toggledOpen = False
            self.visible = False

            with gil:
                 if self.on_close is not None:
                    self.context.queue.submit(self.on_close,
                                              self.uuid if self.alias.empty() else None,
                                              None,
                                              self.user_data)

        #if (self..handlerRegistry)
        #    item.handlerRegistry->checkEvents(&item.state);
        imgui.PopID()
