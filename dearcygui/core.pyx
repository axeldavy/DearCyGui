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
from libcpp.cmath cimport atan, sin, cos
from libc.math cimport M_PI
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
    def __cinit__(self, context):
        if not(isinstance(context, dcgContext)):
            raise ValueError("Provided context is not a valid dcgContext instance")
        self.context = context
        self.resize_callback = None
        self.initialized = False
        self.viewport = NULL
        self.graphics_initialized = False
        #mvMat4 transform         = mvIdentityMat4();

    def __dealloc__(self):
        # TODO: at this point self.context might be NULL
        # but we should lock imgui_mutex...
        # Maybe make imgui_mutex a global
        # and move imgui init/exit outside of dcgContext
        if self.graphics_initialized:
            cleanup_graphics(self.graphics)
        if self.viewport != NULL:
            mvCleanupViewport(dereference(self.viewport))
            #free(self.viewport) deleted by mvCleanupViewport
            self.viewport = NULL

    cdef initialize(self, unsigned width, unsigned height):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return (self.viewport.clearColor.r,
                self.viewport.clearColor.g,
                self.viewport.clearColor.b,
                self.viewport.clearColor.a)

    @clear_color.setter
    def clear_color(self, tuple value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int r, g, b, a
        self.__check_initialized()
        (r, g, b, a) = value
        self.viewport.clearColor = colorFromInts(r, g, b, a)

    @property
    def small_icon(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return str(self.viewport.small_icon)

    @small_icon.setter
    def small_icon(self, str value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.small_icon = value.encode("utf-8")

    @property
    def large_icon(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return str(self.viewport.large_icon)

    @large_icon.setter
    def large_icon(self, str value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.large_icon = value.encode("utf-8")

    @property
    def x_pos(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.xpos

    @x_pos.setter
    def x_pos(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.xpos = value
        self.viewport.posDirty = 1

    @property
    def y_pos(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.ypos

    @y_pos.setter
    def y_pos(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.ypos = value
        self.viewport.posDirty = 1

    @property
    def width(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.actualWidth

    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.actualWidth = value
        self.viewport.sizeDirty = 1

    @property
    def height(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.actualHeight

    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.actualHeight = value
        self.viewport.sizeDirty = 1

    @property
    def resizable(self) -> bint:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.resizable

    @resizable.setter
    def resizable(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.resizable = value
        self.viewport.modesDirty = 1

    @property
    def vsync(self) -> bint:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.vsync

    @vsync.setter
    def vsync(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.vsync = value

    @property
    def min_width(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.minwidth

    @min_width.setter
    def min_width(self, unsigned value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.minwidth = value

    @property
    def max_width(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.maxwidth

    @max_width.setter
    def max_width(self, unsigned value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.maxwidth = value

    @property
    def min_height(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.minheight

    @min_height.setter
    def min_height(self, unsigned value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.minheight = value

    @property
    def max_height(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.maxheight

    @max_height.setter
    def max_height(self, unsigned value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.maxheight = value

    @property
    def always_on_top(self) -> bint:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.alwaysOnTop

    @always_on_top.setter
    def always_on_top(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.alwaysOnTop = value
        self.viewport.modesDirty = 1

    @property
    def decorated(self) -> bint:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.decorated

    @decorated.setter
    def decorated(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.decorated = value
        self.viewport.modesDirty = 1

    @property
    def title(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return str(self.viewport.title)

    @title.setter
    def title(self, str value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.title = value.encode("utf-8")
        self.viewport.titleDirty = 1

    @property
    def disable_close(self) -> bint:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.disableClose

    @disable_close.setter
    def disable_close(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        self.viewport.disableClose = value
        self.viewport.modesDirty = 1

    @property
    def fullscreen(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.viewport.fullScreen

    @fullscreen.setter
    def fullscreen(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        if value and not(self.viewport.fullScreen):
            mvToggleFullScreen(dereference(self.viewport))
        elif not(value) and (self.viewport.fullScreen):
            print("TODO: fullscreen(false)")

    @property
    def shown(self) -> bint:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        return self.viewport.shown

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        for (key, value) in kwargs.items():
            setattr(self, key, value)

    cdef void __on_resize(self, int width, int height):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        if not(<bint>self.viewport.disableClose):
            self.context.started = False
        if self.close_callback is None:
            return
        self.context.queue.submit(self.close_callback, constants.MV_APP_UUID, None)

    cdef void __render(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        # Initialize drawing state
        self.cullMode = 0
        self.perspectiveDivide = False
        self.depthClipping = False
        self.has_matrix_transform = False
        self.in_plot = False
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

    cdef void apply_current_transform(self, float *dst_p, float[4] src_p) noexcept nogil:
        # assumes imgui + viewport mutex are held
        cdef float[4] transformed_p
        if self.has_matrix_transform:
            transformed_p[0] = self.transform[0][0] * src_p[0] + \
                               self.transform[0][1] * src_p[1] + \
                               self.transform[0][2] * src_p[2] + \
                               self.transform[0][3] * src_p[3]
            transformed_p[1] = self.transform[1][0] * src_p[0] + \
                               self.transform[1][1] * src_p[1] + \
                               self.transform[1][2] * src_p[2] + \
                               self.transform[1][3] * src_p[3]
            transformed_p[2] = self.transform[2][0] * src_p[0] + \
                               self.transform[2][1] * src_p[1] + \
                               self.transform[2][2] * src_p[2] + \
                               self.transform[2][3] * src_p[3]
            transformed_p[3] = self.transform[3][0] * src_p[0] + \
                               self.transform[3][1] * src_p[1] + \
                               self.transform[3][2] * src_p[2] + \
                               self.transform[3][3] * src_p[3]
        else:
            transformed_p = src_p

        if self.perspectiveDivide:
            if transformed_p[3] != 0.:
                transformed_p[0] /= transformed_p[3]
                transformed_p[1] /= transformed_p[3]
                transformed_p[2] /= transformed_p[3]
            transformed_p[3] = 1.

        # TODO clipViewport

        cdef imgui.ImVec2 plot_transformed
        if self.in_plot:
            plot_transformed = \
                implot.PlotToPixels(<double>transformed_p[0],
                                    <double>transformed_p[1],
                                    -1,
                                    -1)
            transformed_p[0] = plot_transformed.x
            transformed_p[1] = plot_transformed.y
        dst_p[0] = transformed_p[0]
        dst_p[1] = transformed_p[1]
        dst_p[2] = transformed_p[2]
        dst_p[3] = transformed_p[3]


    def render_frame(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
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
        self.next_uuid.store(21)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.viewport.initialize(width=kwargs["width"],
                                 height=kwargs["height"])
        self.viewport.configure(**kwargs)

    def start(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.started:
            raise ValueError("Cannot call \"setup_dearpygui\" while a Dear PyGUI app is already running.")
        self.started = True

    @property
    def running(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.started

cdef class appItem:
    def __cinit__(self, context, *args, **kwargs):
        if not(isinstance(context, dcgContext)):
            raise ValueError("Provided context is not a valid dcgContext instance")
        self.context = context
        self.uuid = self.context.next_uuid.fetch_add(1)
        # mvAppItemInfo
        self.internalLabel = bytes(str(self.uuid), 'utf-8') # TODO
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
        self.attached = False

    cdef void draw(self, imgui.ImDrawList* l, float x, float y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            self.prev_sibling.draw(l, x, y)
        return

    cdef void lock_parent_and_item_mutex(self) noexcept nogil:
        # We must make sure we lock the correct parent mutex, and for that
        # we must access self.parent and thus hold the item mutex
        cdef bint locked = False
        while not(locked):
            self.mutex.lock()
            # If we have no appItem parent, either we
            # are root (viewport is parent) or have no parent
            if self.parent is not None:
                locked = self.parent.mutex.try_lock()
            elif self.attached:
                locked = self.context.viewport.mutex.try_lock()
            else:
                locked = True
            if locked:
                return
            self.mutex.unlock()

    cdef void unlock_parent_mutex(self) noexcept nogil:
        # Assumes the item mutex is held
        if self.parent is not None:
            self.parent.mutex.unlock()
        elif self.attached:
            self.context.viewport.mutex.unlock()


    cpdef void attach_item(self, appItem target_parent):
        # We must ensure a single thread attaches at a given time.
        # __detach_item_and_lock will lock both the item lock
        # and the parent lock.
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        self.__detach_item_and_lock()
        # retaining the lock enables to ensure the item is
        # still detached
        m = unique_lock[recursive_mutex](self.mutex)
        self.mutex.unlock()

        if self.context is None:
            raise ValueError("Trying to attach a deleted item")

        # Lock target parent mutex
        if target_parent is None:
            m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        else:
            m2 = unique_lock[recursive_mutex](target_parent.mutex)

        # Attach to parent
        if target_parent is None:
            if isinstance(self, dcgWindow):
                if self.context.viewport.windowRoots is not None:
                    m3 = unique_lock[recursive_mutex](self.context.viewport.windowRoots.mutex)
                    self.context.viewport.windowRoots.next_sibling = self
                    self.prev_sibling = self.context.viewport.windowRoots
                self.context.viewport.windowRoots = <dcgWindow>self
            else:
                raise ValueError("Instance of type {} cannot be attached to viewport".format(type(self)))
        else:
            raise ValueError("Instance of type {} cannot be attached to {}".format(type(self), type(target_parent)))
        self.attached = True

    cdef void __detach_item_and_lock(self):
        # NOTE: the mutex is not locked if we raise an exception.
        # Detach the item from its parent and siblings
        # We are going to change the tree structure, we must lock
        # the parent mutex first and foremost
        cdef unique_lock[recursive_mutex] m
        self.lock_parent_and_item_mutex()
        # Use unique lock for the mutexes to
        # simplify handling (parent will change)
        if self.parent is not(None):
            m = unique_lock[recursive_mutex](self.parent.mutex)
        elif self.attached:
            m = unique_lock[recursive_mutex](self.context.viewport.mutex)
        self.unlock_parent_mutex()
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)

        if not(self.attached):
            return # nothing to do
        # Unlock now in order to not retain lock on exceptions
        self.mutex.unlock()

        # Remove this item from the list of siblings
        if self.prev_sibling is not None:
            self.prev_sibling.mutex.lock()
            self.prev_sibling.next_sibling = self.next_sibling
            self.prev_sibling.mutex.unlock()
        if self.next_sibling is not None:
            self.next_sibling.mutex.lock()
            self.next_sibling.prev_sibling = self.prev_sibling
            self.next_sibling.mutex.unlock()
        else:
            # No next sibling. We might be referenced in the
            # parent
            if self.parent is None:
                # viewport is the parent, or no parent
                if self.context.viewport.colormapRoots is self:
                    self.context.viewport.colormapRoots = self.prev_sibling
                elif self.context.viewport.filedialogRoots is self:
                    self.context.viewport.filedialogRoots = self.prev_sibling
                elif self.context.viewport.stagingRoots is self:
                    self.context.viewport.stagingRoots = self.prev_sibling
                elif self.context.viewport.viewportMenubarRoots is self:
                    self.context.viewport.viewportMenubarRoots = self.prev_sibling
                elif self.context.viewport.windowRoots is self:
                    self.context.viewport.windowRoots = self.prev_sibling
                elif self.context.viewport.fontRegistryRoots is self:
                    self.context.viewport.fontRegistryRoots = self.prev_sibling
                elif self.context.viewport.handlerRegistryRoots is self:
                    self.context.viewport.handlerRegistryRoots = self.prev_sibling
                elif self.context.viewport.itemHandlerRegistryRoots is self:
                    self.context.viewport.itemHandlerRegistryRoots = self.prev_sibling
                elif self.context.viewport.textureRegistryRoots is self:
                    self.context.viewport.textureRegistryRoots = self.prev_sibling
                elif self.context.viewport.valueRegistryRoots is self:
                    self.context.viewport.valueRegistryRoots = self.prev_sibling
                elif self.context.viewport.themeRegistryRoots is self:
                    self.context.viewport.themeRegistryRoots = self.prev_sibling
                elif self.context.viewport.itemTemplatesRoots is self:
                    self.context.viewport.itemTemplatesRoots = self.prev_sibling
                elif self.context.viewport.viewportDrawlistRoots is self:
                    self.context.viewport.viewportDrawlistRoots = self.prev_sibling
            else:
                if self.parent.last_0_child is self:
                    self.parent.last_0_child = self.prev_sibling
                elif self.parent.last_widgets_child is self:
                    self.parent.last_widgets_child = self.prev_sibling
                elif self.parent.last_drawings_child is self:
                    self.parent.last_drawings_child = self.prev_sibling
                elif self.parent.last_payloads_child is self:
                    self.parent.last_payloads_child = self.prev_sibling
        # Free references
        self.parent = None
        self.prev_sibling = None
        self.next_sibling = None
        self.attached = False
        # Lock again before we release the lock from unique_lock
        self.mutex.lock()

    cpdef void detach_item(self):
        self.__detach_item_and_lock()
        self.mutex.unlock()

    cpdef void delete_item(self):
        cdef unique_lock[recursive_mutex] m
        self.__detach_item_and_lock()
        # retaining the lock enables to ensure the item is
        # still detached
        m = unique_lock[recursive_mutex](self.mutex)
        self.mutex.unlock()

        if self.context is None:
            raise ValueError("Trying to delete a deleted item")

        # Remove this item from the list of elements
        if self.prev_sibling is not None:
            self.prev_sibling.mutex.lock()
            self.prev_sibling.next_sibling = self.next_sibling
            self.prev_sibling.mutex.unlock()
        if self.next_sibling is not None:
            self.next_sibling.mutex.lock()
            self.next_sibling.prev_sibling = self.prev_sibling
            self.next_sibling.mutex.unlock()
        else:
            # No next sibling. We might be referenced in the
            # parent
            if self.parent is None:
                # viewport is the parent, or no parent
                if self.context.viewport.colormapRoots is self:
                    self.context.viewport.colormapRoots = self.prev_sibling
                elif self.context.viewport.filedialogRoots is self:
                    self.context.viewport.filedialogRoots = self.prev_sibling
                elif self.context.viewport.stagingRoots is self:
                    self.context.viewport.stagingRoots = self.prev_sibling
                elif self.context.viewport.viewportMenubarRoots is self:
                    self.context.viewport.viewportMenubarRoots = self.prev_sibling
                elif self.context.viewport.windowRoots is self:
                    self.context.viewport.windowRoots = self.prev_sibling
                elif self.context.viewport.fontRegistryRoots is self:
                    self.context.viewport.fontRegistryRoots = self.prev_sibling
                elif self.context.viewport.handlerRegistryRoots is self:
                    self.context.viewport.handlerRegistryRoots = self.prev_sibling
                elif self.context.viewport.itemHandlerRegistryRoots is self:
                    self.context.viewport.itemHandlerRegistryRoots = self.prev_sibling
                elif self.context.viewport.textureRegistryRoots is self:
                    self.context.viewport.textureRegistryRoots = self.prev_sibling
                elif self.context.viewport.valueRegistryRoots is self:
                    self.context.viewport.valueRegistryRoots = self.prev_sibling
                elif self.context.viewport.themeRegistryRoots is self:
                    self.context.viewport.themeRegistryRoots = self.prev_sibling
                elif self.context.viewport.itemTemplatesRoots is self:
                    self.context.viewport.itemTemplatesRoots = self.prev_sibling
                elif self.context.viewport.viewportDrawlistRoots is self:
                    self.context.viewport.viewportDrawlistRoots = self.prev_sibling
            else:
                if self.parent.last_0_child is self:
                    self.parent.last_0_child = self.prev_sibling
                elif self.parent.last_widgets_child is self:
                    self.parent.last_widgets_child = self.prev_sibling
                elif self.parent.last_drawings_child is self:
                    self.parent.last_drawings_child = self.prev_sibling
                elif self.parent.last_payloads_child is self:
                    self.parent.last_payloads_child = self.prev_sibling

        # delete all children recursively
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
        self.last_0_child = None
        self.last_widgets_child = None
        self.last_drawings_child = None
        self.last_payloads_child = None

    cdef void __delete_and_siblings(self):
        # Must only be called from delete_item or itself.
        # Assumes the parent mutex is already held
        # and that we don't need to edit the parent last_*_child fields
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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

cdef class dcgDrawList(appItem):
    def __cinit__(self, context, int width, int height, *args, **kwargs):
        self.clip_width = <float>width
        self.clip_height = <float>height
    @property
    def width(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return <int>self.clip_width
    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.clip_width = <float>value
    @property
    def height(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return <int>self.clip_height
    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.clip_height = <float>value

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            self.prev_sibling.draw(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.last_drawings_child is None:
            return
        if self.clip_width <= 0 or self.clip_height <= 0:
            # Wasn't done in the original code, but seems a sensible thing to do
            return
        cdef imgui.ImDrawList* internal_drawlist = imgui.GetWindowDrawList()

        # Reset current drawInfo
        self.context.viewport.cullMode = 0 # mvCullMode_None
        self.context.viewport.perspectiveDivide = False
        self.context.viewport.depthClipping = False
        self.context.viewport.has_matrix_transform = False
        self.context.viewport.in_plot = False

        cdef float startx = <float>imgui.GetCursorScreenPos().x
        cdef float starty = <float>imgui.GetCursorScreenPos().y

        imgui.PushClipRect(imgui.ImVec2(startx, starty),
                           imgui.ImVec2(startx + self.clip_width,
                                        starty + self.clip_height),
                           True)

        self.last_drawings_child.draw(internal_drawlist, startx, starty)
        # Child UpdateAppItemState(item->state); ?

        imgui.PopClipRect()

        if imgui.InvisibleButton(self.internalLabel.c_str(),
                                 imgui.ImVec2(self.clip_width,
                                              self.clip_height),
                                 imgui.ImGuiButtonFlags_MouseButtonLeft | \
                                 imgui.ImGuiButtonFlags_MouseButtonRight | \
                                 imgui.ImGuiButtonFlags_MouseButtonMiddle):
            with gil:
                self.context.queue.submit(self.callback,
                                          self.uuid if self.alias.empty() else None,
                                          None,
                                          self.user_data)

        # UpdateAppItemState(state); ?

        # TODO:
        """
        if (handlerRegistry)
		handlerRegistry->checkEvents(&state);

	    if (ImGui::IsItemHovered())
	    {
		    ImVec2 mousepos = ImGui::GetMousePos();
	    	GContext->input.mouseDrawingPos.x = (int)(mousepos.x - _startx);
    		GContext->input.mouseDrawingPos.y = (int)(mousepos.y - _starty);
	    }
        -> This is very weird. Seems to be used by get_drawing_mouse_pos and
        set only here. But it is not set for the other drawlist
        elements when they are hovered...
        """
        

cdef class dcgViewportDrawList(appItem):
    def __cinit__(self, *args, **kwargs):
        self.front = kwargs.get("front", True)
    @property
    def front(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.front
    @front.setter
    def front(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.front = value

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            self.prev_sibling.draw(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.last_drawings_child is None:
            return

        # Reset current drawInfo
        self.context.viewport.cullMode = 0 # mvCullMode_None
        self.context.viewport.perspectiveDivide = False
        self.context.viewport.depthClipping = False
        self.context.viewport.has_matrix_transform = False
        self.context.viewport.in_plot = False

        cdef imgui.ImDrawList* internal_drawlist = \
            imgui.GetForegroundDrawList() if self.front else \
            imgui.GetBackgroundDrawList()
        self.last_drawings_child.draw(internal_drawlist, 0., 0.)
        # Child UpdateAppItemState(item->state); ?

cdef class dcgDrawLayer(appItem):
    def __cinit__(self, *args, **kwargs):
        self.cullMode = kwargs.get("cull_mode", 0) # mvCullMode_None == 0
        self.perspectiveDivide = kwargs.get("perspective_divide", False)
        self.depthClipping = kwargs.get("depth_clipping", False)
        self.clipViewport = [0.0, 0.0, 1.0, 1.0, -1.0, 1.0]
        self.has_matrix_transform = False

    @property
    def perspective_divide(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.perspectiveDivide
    @perspective_divide.setter
    def perspective_divide(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.perspectiveDivide = value
    @property
    def depth_clipping(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.depthClipping
    @depth_clipping.setter
    def depth_clipping(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.depthClipping = value
    @property
    def cull_mode(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.cullMode
    @cull_mode.setter
    def cull_mode(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.cullMode = value

    def clip_space(self,
                   float topleftx,
                   float toplefty,
                   float width,
                   float height,
                   float mindepth,
                   float maxdepth):
        self.clipViewport[0] = topleftx
        self.clipViewport[1] = toplefty + height
        self.clipViewport[2] = width
        self.clipViewport[3] = height
        self.clipViewport[4] = mindepth
        self.clipViewport[5] = maxdepth
        self.transform[0] = [width, 0., 0., topleftx + (width / 2.)]
        self.transform[0] = [0., -height, 0., toplefty + (height / 2.)]
        self.transform[0] = [0., 0., 0.25, 0.5]
        self.transform[1] = [0., 0., 0., 1.]
        self.has_matrix_transform = True

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            self.prev_sibling.draw(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.last_drawings_child is None:
            return

        # Reset current drawInfo - except in_plot as we keep parent_drawlist
        self.context.viewport.cullMode = self.cullMode
        self.context.viewport.perspectiveDivide = self.perspectiveDivide
        self.context.viewport.depthClipping = self.depthClipping
        if self.depthClipping:
            self.context.viewport.clipViewport = self.clipViewport
        #if self.has_matrix_transform and self.context.viewport.has_matrix_transform:
        #    TODO
        #    matrix_fourfour_mul(self.context.viewport.transform, self.transform)
        #elif
        if self.has_matrix_transform:
            self.context.viewport.has_matrix_transform = True
            self.context.viewport.transform = self.transform
        # As we inherit from parent_drawlist
        # We don't change self.in_plot

        # draw children
        self.last_drawings_child.draw(parent_drawlist, parent_x, parent_y)
        # Child UpdateAppItemState(item->state); ?

cdef inline void read_point(float* dst, src):
    cdef int src_size = len(src)
    dst[0] = 0.
    dst[1] = 0.
    dst[2] = 0.
    dst[3] = 0.
    if src_size > 0:
        dst[0] = src[0]
    if src_size > 1:
        dst[1] = src[1]
    if src_size > 2:
        dst[2] = src[2]
    if src_size > 3:
        dst[3] = src[3]

cdef inline imgui.ImU32 parse_color(src):
    cdef int src_size = len(src)
    cdef imgui.ImVec4 color_float4
    color_float4.x = 1.
    color_float4.y = 1.
    color_float4.z = 1.
    color_float4.w = 1.
    if src_size > 0:
        color_float4.x = src[0]
    if src_size > 1:
        color_float4.y = src[1]
    if src_size > 2:
        color_float4.z = src[2]
    if src_size > 3:
        color_float4.w = src[3]
    return  imgui.ColorConvertFloat4ToU32(color_float4)

cdef void unparse_color(float[::1] dst, imgui.ImU32 color_uint):
    cdef imgui.ImVec4 color_float4 = imgui.ColorConvertU32ToFloat4(color_uint)
    dst[0] = color_float4.x
    dst[1] = color_float4.y
    dst[2] = color_float4.z
    dst[3] = color_float4.w

cdef class dcgDrawArrow(appItem):
    def __cinit__(self, context, p1, p2, *args, **kwargs):
        read_point(self.end, p1)
        read_point(self.start, p2)
        self.color = 4294967295 # 0xffffffff
        if hasattr(kwargs, "color"):
            self.color = parse_color(kwargs["color"])
        self.thickness = kwargs.get("thickness", 1.)
        self.size = kwargs.get("thickness", 4.)
        self.__compute_tip()

    cdef void __compute_tip(self):
        # Copy paste from original code

        cdef float xsi = self.end[0]
        cdef float xfi = self.start[0]
        cdef float ysi = self.end[1]
        cdef float yfi = self.start[1]

        # length of arrow head
        cdef double xoffset = self.size
        cdef double yoffset = self.size

        # get pointer angle w.r.t +X (in radians)
        cdef double angle = 0.0
        if xsi >= xfi and ysi >= yfi:
            angle = atan((ysi - yfi) / (xsi - xfi))
        elif xsi < xfi and ysi >= yfi:
            angle = M_PI + atan((ysi - yfi) / (xsi - xfi))
        elif xsi < xfi and ysi < yfi:
            angle = -M_PI + atan((ysi - yfi) / (xsi - xfi))
        elif xsi >= xfi and ysi < yfi:
            angle = atan((ysi - yfi) / (xsi - xfi))

        cdef float x1 = <float>(xsi - xoffset * cos(angle))
        cdef float y1 = <float>(ysi - yoffset * sin(angle))
        self.corner1 = [x1 - 0.5 * self.size * sin(angle),
                        y1 + 0.5 * self.size * cos(angle),
                        0.,
                        1.]
        self.corner2 = [x1 + 0.5 * self.size * cos((M_PI / 2.0) - angle),
                        y1 - 0.5 * self.size * sin((M_PI / 2.0) - angle),
                        0.,
                        1.]

    @property
    def end(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return list(self.end)
    @end.setter
    def end(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        read_point(self.end, value)
        self.__compute_tip()
    @property
    def start(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return list(self.start)
    @start.setter
    def start(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        read_point(self.start, value)
        self.__compute_tip()
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.thickness = value
        self.__compute_tip()
    @property
    def size(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.size = value
        self.__compute_tip()

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            self.prev_sibling.draw(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.last_drawings_child is None:
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] tstart
        cdef float[4] tend
        cdef float[4] tcorner1
        cdef float[4] tcorner2
        self.context.viewport.apply_current_transform(tstart, self.start)
        self.context.viewport.apply_current_transform(tend, self.end)
        self.context.viewport.apply_current_transform(tcorner1, self.corner1)
        self.context.viewport.apply_current_transform(tcorner2, self.corner2)
        # TODO: original code doesn't shift when plot. Why ?
        if not(self.context.viewport.in_plot):
            tstart[0] += parent_x
            tstart[1] += parent_y
            tend[0] += parent_x
            tend[1] += parent_y
            tcorner1[0] += parent_x
            tcorner1[1] += parent_y
            tcorner2[0] += parent_x
            tcorner2[1] += parent_y
        cdef imgui.ImVec2 itstart = imgui.ImVec2(tstart[0], tstart[1])
        cdef imgui.ImVec2 itend  = imgui.ImVec2(tend[0], tend[1])
        cdef imgui.ImVec2 itcorner1 = imgui.ImVec2(tcorner1[0], tcorner1[1])
        cdef imgui.ImVec2 itcorner2 = imgui.ImVec2(tcorner2[0], tcorner2[1])
        parent_drawlist.AddTriangleFilled(itend, itcorner1, itcorner2, self.color)
        parent_drawlist.AddLine(itend, itstart, self.color, thickness)
        parent_drawlist.AddTriangle(itend, itcorner1, itcorner2, self.color, thickness)


cdef class dcgWindow(appItem):
    def __cinit__(self, *args, **kwargs):
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

    @property
    def primary(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.mainWindow

    @primary.setter
    def primary(self, bint value):
        self.lock_parent_and_item_mutex()
        if self.attached and self.parent is not None:
            # Non-root window. Cannot make primary
            self.unlock_parent_mutex()
            self.mutex.unlock()
            raise ValueError("Cannot make sub-window primary")
        if not(self.attached):
            self.unlock_parent_mutex() # should have no effect
            self.mutex.unlock()
            raise ValueError("Window must be attached before becoming primary")
        # window is in viewport children
        # Move the mutexes to unique_lock for easier exception handling
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.viewport.mutex)
        self.unlock_parent_mutex()
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        if self.mainWindow == value:
            return # Nothing to do
        self.mainWindow = value
        if value:
            # backup previous state
            self._oldWindowflags = self.windowflags
            self._oldxpos = self.pos.x
            self._oldypos = self.pos.y
            self._oldWidth = self.width
            self._oldHeight = self.height
            # Make primary
            self.windowflags = \
                imgui.ImGuiWindowFlags_NoBringToFrontOnFocus | \
                imgui.ImGuiWindowFlags_NoSavedSettings | \
			    imgui.ImGuiWindowFlags_NoResize | \
                imgui.ImGuiWindowFlags_NoCollapse | \
                imgui.ImGuiWindowFlags_NoTitleBar
        else:
            # Propagate menubar to previous state
            if (self.windowflags & imgui.ImGuiWindowFlags_MenuBar) != 0:
                self._oldWindowflags |= imgui.ImGuiWindowFlags_MenuBar
            # Restore previous state
            self.windowflags = self._oldWindowflags
            self.pos.x = self._oldxpos
            self.pos.y = self._oldypos
            self.width = self._oldWidth
            self.height = self._oldHeight
            # Tell imgui to update the window shape
            self.dirtyPos = True
            self.dirty_size = True

        # Re-tell imgui the window hierarchy
        cdef dcgWindow w = self.context.viewport.windowRoots
        cdef dcgWindow next = None
        while w is not None:
            w.mutex.lock()
            w.focusNextFrame = True
            next = w.prev_sibling
            w.mutex.unlock()
            # TODO: previous code did restore previous states on each window. Figure out why
            w = next

