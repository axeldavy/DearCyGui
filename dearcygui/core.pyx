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
from dearcygui.backends.backend cimport *
# We use unique_lock rather than lock_guard as
# the latter doesn't support nullary constructor
# which causes trouble to cython
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock

from concurrent.futures import ThreadPoolExecutor
from libc.stdlib cimport malloc, free
from libcpp.algorithm cimport swap
from libcpp.cmath cimport atan, sin, cos
from libcpp.vector cimport vector
from libc.math cimport M_PI

import numpy as np
cimport numpy as cnp

import scipy
import scipy.spatial
from .constants import constants

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

# The no gc clear flag enforces that in case
# of no-reference cycle detected, the dcgContext is freed last.
# The cycle is due to dcgContext referencing dcgViewport
# and vice-versa

@cython.final
@cython.no_gc_clear
cdef class dcgViewport:
    def __cinit__(self, context):
        if not(isinstance(context, dcgContext)):
            raise ValueError("Provided context is not a valid dcgContext instance")
        self.context = context
        self.resize_callback = None
        self.initialized = False
        self.viewport = NULL
        self.graphics_initialized = False

    def __dealloc__(self):
        # NOTE: Called BEFORE the context is released.
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        ensure_correct_im_context(self.context)
        if self.graphics_initialized:
            cleanup_graphics(self.graphics)
        if self.viewport != NULL:
            mvCleanupViewport(dereference(self.viewport))
            #self.viewport is freed by mvCleanupViewport
            self.viewport = NULL

    cdef initialize(self, unsigned width, unsigned height):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        ensure_correct_im_context(self.context)
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
    def clear_color(self, value):
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
        ensure_correct_im_context(self.context)
        if value and not(self.viewport.fullScreen):
            mvToggleFullScreen(dereference(self.viewport))
        elif not(value) and (self.viewport.fullScreen):
            print("TODO: fullscreen(false)")

    @property
    def waitForInputs(self):
        return self.viewport.waitForEvents

    @waitForInputs.setter
    def waitForInputs(self, bint value):
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        self.viewport.waitForEvents = value

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
        # TODO: queue
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
        #self.cullMode = 0
        self.perspectiveDivide = False
        self.depthClipping = False
        self.has_matrix_transform = False
        self.in_plot = False
        #if self.fontRegistryRoots is not None:
        #    self.fontRegistryRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        #if self.handlerRegistryRoots is not None:
        #    self.handlerRegistryRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        #if self.textureRegistryRoots is not None:
        #    self.textureRegistryRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        #if self.filedialogRoots is not None:
        #    self.filedialogRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        #if self.colormapRoots is not None:
        #    self.colormapRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.windowRoots is not None:
            self.windowRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        #if self.viewportMenubarRoots is not None:
        #    self.viewportMenubarRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.viewportDrawlistRoots is not None:
            self.viewportDrawlistRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        return

    cdef void apply_current_transform(self, float *dst_p, float[4] src_p, float dx, float dy) noexcept nogil:
        """
        Used during rendering as helper to convert drawing coordinates to pixel coordinates
        """
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
        else:
            # Unsure why the original code doesn't do it in the in_plot path
            transformed_p[0] += dx
            transformed_p[1] += dy
        dst_p[0] = transformed_p[0]
        dst_p[1] = transformed_p[1]
        dst_p[2] = transformed_p[2]
        dst_p[3] = transformed_p[3]


    def render_frame(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        self.__check_initialized()
        # Note: imgui calls are only allowed during the frame rendering, thus we can
        # make this call only here. In addition we could only lock the imgui_mutex
        # here for this reason.
        ensure_correct_im_context(self.context)
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
        ensure_correct_im_context(self.context)
        mvShowViewport(dereference(self.viewport),
                       minimized,
                       maximized)
        if not(self.graphics_initialized):
            self.graphics = setup_graphics(dereference(self.viewport))
            """
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
            """
            self.graphics_initialized = True
        self.viewport.shown = 1

    def wake(self):
        """
        In case rendering is waiting for an input (waitForInputs),
        generate a fake input to force rendering.

        This is useful if you have updated the content asynchronously
        and want to show the update
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        mvWakeRendering(dereference(self.viewport))


cdef class dcgCallback:
    def __cinit__(self, callback):
        if not(callable(callback)):
            raise TypeError("dcgCallback requires a callable object")
        self.callback = callback
        self.num_args = callback.__code__.co_argcount
        if self.num_args > 3:
            raise ValueError("Callback function takes too many arguments")

    def __call__(self, item, call_info, user_data):
        if self.num_args == 3:
            self.callback(item, call_info, user_data)
        elif self.num_args == 2:
            self.callback(item, call_info)
        elif self.num_args == 1:
            self.callback(item)
        else:
            self.callback()

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
        self.imgui_context = imgui.CreateContext()
        self.implot_context = implot.CreateContext()
        self.imnodes_context = imnodes.CreateContext()
        #mvToolManager::GetFontManager()._dirty = true;

    def __dealloc__(self):
        self.started = True
        imnodes.DestroyContext(self.imnodes_context)
        implot.DestroyContext(self.implot_context)
        imgui.DestroyContext(self.imgui_context)

    def __del__(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.on_close_callback is not None:
            self.started = True
            self.queue_callback_noarg(self.on_close_callback, self)
            self.started = False

        #mvToolManager::Reset()
        #ClearItemRegistry(*GContext->itemRegistry)

        self.queue.shutdown(wait=True)

    cdef void queue_callback_noarg(self, dcgCallback callback, object parent_item) noexcept nogil:
        if callback is None:
            return
        with gil:
            self.queue.submit(callback, parent_item, None, None)

    cdef void queue_callback_arg1int(self, dcgCallback callback, object parent_item, int arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            self.queue.submit(callback, parent_item, arg1, None)

    cdef void queue_callback_arg1float(self, dcgCallback callback, object parent_item, float arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            self.queue.submit(callback, parent_item, arg1, None)

    cdef void queue_callback_arg1int1float(self, dcgCallback callback, object parent_item, int arg1, float arg2) noexcept nogil:
        if callback is None:
            return
        with gil:
            self.queue.submit(callback, parent_item, (arg1, arg2), None)

    cdef void queue_callback_arg2float(self, dcgCallback callback, object parent_item, float arg1, float arg2) noexcept nogil:
        if callback is None:
            return
        with gil:
            self.queue.submit(callback, parent_item, (arg1, arg2), None)

    cdef void queue_callback_arg1int2float(self, dcgCallback callback, object parent_item, int arg1, float arg2, float arg3) noexcept nogil:
        if callback is None:
            return
        with gil:
            self.queue.submit(callback, parent_item, (arg1, arg2, arg3), None)

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

cdef class baseItem:
    def __cinit__(self, context):
        if not(isinstance(context, dcgContext)):
            raise ValueError("Provided context is not a valid dcgContext instance")
        self.context = context
        self.uuid = self.context.next_uuid.fetch_add(1)
        self.can_have_0_child = False
        self.can_have_widget_child = False
        self.can_have_drawing_child = False
        self.can_have_payload_child = False
        self.can_have_sibling = False
        self.can_have_nonviewport_parent = False
        self.element_child_category = -1
        self.can_have_nonviewport_parent = False
        self.element_toplevel_category = -1

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        # TODO
        if len(kwargs) > 0:
            print("Unused configure parameters: ", kwargs)
        return

    cdef void lock_parent_and_item_mutex(self) noexcept nogil:
        # We must make sure we lock the correct parent mutex, and for that
        # we must access self.parent and thus hold the item mutex
        cdef bint locked = False
        while not(locked):
            self.mutex.lock()
            # If we have no baseItem parent, either we
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


    cpdef void attach_to_parent(self, baseItem target_parent):
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
            if self.element_toplevel_category == 4:
                assert(isinstance(self, dcgWindow_))
                if self.context.viewport.windowRoots is not None:
                    m3 = unique_lock[recursive_mutex](self.context.viewport.windowRoots.mutex)
                    self.context.viewport.windowRoots.next_sibling = self
                    self.prev_sibling = self.context.viewport.windowRoots
                self.context.viewport.windowRoots = <dcgWindow_>self
            else:
                raise ValueError("Instance of type {} cannot be attached to viewport".format(type(self)))
        else:
            if self.can_have_nonviewport_parent and \
               self.element_child_category == 2 and \
               target_parent.can_have_drawing_child:
                if target_parent.last_drawings_child is not None:
                    m3 = unique_lock[recursive_mutex](target_parent.last_drawings_child.mutex)
                    target_parent.last_drawings_child.next_sibling = self
                self.prev_sibling = target_parent.last_drawings_child
                self.parent = target_parent
                target_parent.last_drawings_child = <drawableItem>self
            else:
                raise ValueError("Instance of type {} cannot be attached to {}".format(type(self), type(target_parent)))
        self.attached = True

    cpdef void attach_before(self, baseItem target_before):
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

        if target_before is None:
            raise ValueError("target before cannot be None")

        # Lock target mutex and its parent mutex
        target_before.lock_parent_and_item_mutex()

        if not(target_before.attached):
            target_before.unlock_parent_mutex()
            target_before.mutex.unlock()
            # We can bind to an unattached parent, but not
            # to unattached siblings. Could be implemented, but not trivial
            raise ValueError("Trying to attach to an un-attached sibling. Not yet supported")

        if (target_before.parent is None) and (target_before.attached):
            m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        else:
            m2 = unique_lock[recursive_mutex](target_before.parent.mutex)
        m3 = unique_lock[recursive_mutex](target_before.mutex)
        target_before.unlock_parent_mutex()
        target_before.mutex.unlock()

        # Check the elements can indeed be siblings
        if not(self.can_have_sibling):
            raise ValueError("Instance of type {} cannot have a sibling".format(type(self)))
        if not(target_before.can_have_sibling):
            raise ValueError("Instance of type {} cannot have a sibling".format(type(target_before)))
        if self.element_child_category != target_before.element_child_category:
            raise ValueError("Instance of type {} cannot be sibling to {}".format(type(self), type(target_before)))

        # Attach to sibling
        cdef baseItem prev_sibling = target_before.prev_sibling
        # Potential deadlocks are avoided by the fact that we hold the parent
        # mutex and any lock of a next sibling must hold the parent
        # mutex.
        if prev_sibling is not None:
            prev_sibling.mutex.lock()
            prev_sibling.next_sibling = self
        self.prev_sibling = prev_sibling
        self.next_sibling = target_before
        target_before.prev_sibling = self
        if prev_sibling is not None:
            prev_sibling.mutex.unlock()
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


cdef class drawableItem(baseItem):
    def __cinit__(self):
        self.show = True
        self.can_have_sibling = True

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.show = kwargs.pop("show", self.show)
        super().configure(**kwargs)

    @property
    def show(self):
        """
        Writable attribute: Should the object be drawn/shown ?
        In case show is set to False, this disables any
        callback (for example the close callback won't be called
        if a window is hidden with show = False).
        In the case of items that can be closed,
        show is set to False automatically on close.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return <bint>self.show
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if isinstance(self, uiItem):
            # TODO: try to overwrite the method instead
            (<uiItem>self).show_update_requested = True
        self.show = value

    cdef void draw_prev_siblings(self, imgui.ImDrawList* l, float x, float y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.prev_sibling is not None:
            (<drawableItem>self.prev_sibling).draw(l, x, y)

    cdef void draw(self, imgui.ImDrawList* l, float x, float y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(l, x, y)

"""
Drawing items
"""


cdef class drawingItem(drawableItem):
    def __cinit__(self):
        self.can_have_nonviewport_parent = True
        self.element_child_category = 2

cdef class dcgDrawList_(drawingItem):
    def __cinit__(self):
        self.clip_width = 0
        self.clip_height = 0
        self.can_have_drawing_child = True

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.last_drawings_child is None:
            return
        if self.clip_width <= 0 or self.clip_height <= 0:
            # Wasn't done in the original code, but seems a sensible thing to do
            return
        cdef imgui.ImDrawList* internal_drawlist = imgui.GetWindowDrawList()

        # Reset current drawInfo
        #self.context.viewport.cullMode = 0 # mvCullMode_None
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

        imgui.PopClipRect()

        if imgui.InvisibleButton(self.internalLabel.c_str(),
                                 imgui.ImVec2(self.clip_width,
                                              self.clip_height),
                                 imgui.ImGuiButtonFlags_MouseButtonLeft | \
                                 imgui.ImGuiButtonFlags_MouseButtonRight | \
                                 imgui.ImGuiButtonFlags_MouseButtonMiddle):
            self.context.queue_callback_noarg(None, self)#self.callback

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
        

cdef class dcgViewportDrawList_(drawingItem):
    def __cinit__(self):
        self.front = True
        self.can_have_drawing_child = True

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.last_drawings_child is None:
            return

        # Reset current drawInfo
        #self.context.viewport.cullMode = 0 # mvCullMode_None
        self.context.viewport.perspectiveDivide = False
        self.context.viewport.depthClipping = False
        self.context.viewport.has_matrix_transform = False
        self.context.viewport.in_plot = False

        cdef imgui.ImDrawList* internal_drawlist = \
            imgui.GetForegroundDrawList() if self.front else \
            imgui.GetBackgroundDrawList()
        self.last_drawings_child.draw(internal_drawlist, 0., 0.)

cdef class dcgDrawLayer_(drawingItem):
    def __cinit__(self):
        self.cullMode = 0 # mvCullMode_None == 0
        self.perspectiveDivide = False
        self.depthClipping = False
        self.clipViewport = [0.0, 0.0, 1.0, 1.0, -1.0, 1.0]
        self.has_matrix_transform = False
        self.can_have_drawing_child = True

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return
        if self.last_drawings_child is None:
            return

        # Reset current drawInfo - except in_plot as we keep parent_drawlist
        #self.context.viewport.cullMode = self.cullMode
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

cdef class dcgDrawArrow_(drawingItem):
    def __cinit__(self):
        # p1, p2, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.
        self.size = 4.

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

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] tstart
        cdef float[4] tend
        cdef float[4] tcorner1
        cdef float[4] tcorner2
        self.context.viewport.apply_current_transform(tstart, self.start, parent_x, parent_y)
        self.context.viewport.apply_current_transform(tend, self.end, parent_x, parent_y)
        self.context.viewport.apply_current_transform(tcorner1, self.corner1, parent_x, parent_y)
        self.context.viewport.apply_current_transform(tcorner2, self.corner2, parent_x, parent_y)
        cdef imgui.ImVec2 itstart = imgui.ImVec2(tstart[0], tstart[1])
        cdef imgui.ImVec2 itend  = imgui.ImVec2(tend[0], tend[1])
        cdef imgui.ImVec2 itcorner1 = imgui.ImVec2(tcorner1[0], tcorner1[1])
        cdef imgui.ImVec2 itcorner2 = imgui.ImVec2(tcorner2[0], tcorner2[1])
        parent_drawlist.AddTriangleFilled(itend, itcorner1, itcorner2, self.color)
        parent_drawlist.AddLine(itend, itstart, self.color, thickness)
        parent_drawlist.AddTriangle(itend, itcorner1, itcorner2, self.color, thickness)


cdef class dcgDrawBezierCubic_(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 0.
        self.segments = 0

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] p1
        cdef float[4] p2
        cdef float[4] p3
        cdef float[4] p4
        self.context.viewport.apply_current_transform(p1, self.p1, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p2, self.p2, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p3, self.p3, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p4, self.p4, parent_x, parent_y)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        cdef imgui.ImVec2 ip4 = imgui.ImVec2(p4[0], p4[1])
        parent_drawlist.AddBezierCubic(ip1, ip2, ip3, ip4, self.color, self.thickness, self.segments)

cdef class dcgDrawBezierQuadratic_(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 0.
        self.segments = 0

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] p1
        cdef float[4] p2
        cdef float[4] p3
        self.context.viewport.apply_current_transform(p1, self.p1, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p2, self.p2, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p3, self.p3, parent_x, parent_y)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        parent_drawlist.AddBezierQuadratic(ip1, ip2, ip3, self.color, self.thickness, self.segments)


cdef class dcgDrawCircle_(drawingItem):
    def __cinit__(self):
        # center is zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.radius = 1.
        self.thickness = 1.
        self.segments = 0

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        cdef float radius = self.radius
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier
            radius *= self.context.viewport.thickness_multiplier

        cdef float[4] center
        self.context.viewport.apply_current_transform(center, self.center, parent_x, parent_y)
        cdef imgui.ImVec2 icenter = imgui.ImVec2(center[0], center[1])
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            parent_drawlist.AddCircleFilled(icenter, radius, self.fill, self.segments)
        parent_drawlist.AddCircle(icenter, radius, self.color, self.segments, thickness)


cdef class dcgDrawEllipse_(drawingItem):
    # TODO: I adapted the original code,
    # But these deserves rewrite: call the imgui Ellipse functions instead
    # and add rotation parameter
    def __cinit__(self):
        # pmin/pmax is zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.
        self.segments = 0

    cdef void __fill_points(self):
        cdef int segments = max(self.segments, 3)
        cdef float width = self.pmax[0] - self.pmin[0]
        cdef float height = self.pmax[1] - self.pmin[1]
        cdef float cx = width / 2. + self.pmin[0]
        cdef float cy = height / 2. + self.pmin[1]
        cdef float radian_inc = (M_PI * 2.) / <float>segments
        self.points.clear()
        self.points.reserve(segments+1)
        cdef int i
        # vector needs float4 rather than float[4]
        cdef float4 p
        p.p[2] = self.pmax[2]
        p.p[3] = self.pmax[3]
        width = abs(width)
        height = abs(height)
        for i in range(segments):
            p.p[0] = cx + cos(<float>i * radian_inc) * width / 2.
            p.p[1] = cy - sin(<float>i * radian_inc) * height / 2.
            self.points.push_back(p)
        self.points.push_back(self.points[0])

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show) or self.points.size() < 3:
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef vector[imgui.ImVec2] transformed_points
        transformed_points.reserve(self.points.size())
        cdef int i
        cdef float[4] p
        for i in range(<int>self.points.size()):
            self.context.viewport.apply_current_transform(p, self.points[i].p, parent_x, parent_y)
            transformed_points.push_back(imgui.ImVec2(p[0], p[1]))
        # TODO imgui requires clockwise order for correct AA
        # Reverse order if needed
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            parent_drawlist.AddConvexPolyFilled(transformed_points.data(),
                                                <int>transformed_points.size(),
                                                self.fill)
        parent_drawlist.AddPolyline(transformed_points.data(),
                                    <int>transformed_points.size(),
                                    self.color,
                                    0,
                                    thickness)


cdef class dcgDrawImage_(drawingItem):
    def __cinit__(self):
        self.uv = [0., 0., 1., 1.]
        self.color_multiplier = 4294967295 # 0xffffffff

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show) or self.texture is None:
            return

        cdef unique_lock[recursive_mutex] m4 = unique_lock[recursive_mutex](self.texture.mutex)

        cdef float[4] pmin
        cdef float[4] pmax
        self.context.viewport.apply_current_transform(pmin, self.pmin, parent_x, parent_y)
        self.context.viewport.apply_current_transform(pmax, self.pmax, parent_x, parent_y)
        cdef imgui.ImVec2 ipmin = imgui.ImVec2(pmin[0], pmin[1])
        cdef imgui.ImVec2 ipmax = imgui.ImVec2(pmax[0], pmax[1])
        cdef imgui.ImVec2 uvmin = imgui.ImVec2(self.uv[0], self.uv[1])
        cdef imgui.ImVec2 uvmax = imgui.ImVec2(self.uv[2], self.uv[3])
        parent_drawlist.AddImage(self.texture.allocated_texture, ipmin, ipmax, uvmin, uvmax, self.color_multiplier)


cdef class dcgDrawImageQuad_(drawingItem):
    def __cinit__(self):
        # last two fields are unused
        self.uv1 = [0., 0., 0., 0.]
        self.uv2 = [0., 0., 0., 0.]
        self.uv3 = [0., 0., 0., 0.]
        self.uv4 = [0., 0., 0., 0.]
        self.color_multiplier = 4294967295 # 0xffffffff

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show) or self.texture is None:
            return

        cdef unique_lock[recursive_mutex] m4 = unique_lock[recursive_mutex](self.texture.mutex)

        cdef float[4] p1
        cdef float[4] p2
        cdef float[4] p3
        cdef float[4] p4
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4

        self.context.viewport.apply_current_transform(p1, self.p1, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p2, self.p2, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p3, self.p3, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p4, self.p4, parent_x, parent_y)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])
        cdef imgui.ImVec2 iuv1 = imgui.ImVec2(self.uv1[0], self.uv1[1])
        cdef imgui.ImVec2 iuv2 = imgui.ImVec2(self.uv2[0], self.uv2[1])
        cdef imgui.ImVec2 iuv3 = imgui.ImVec2(self.uv3[0], self.uv3[1])
        cdef imgui.ImVec2 iuv4 = imgui.ImVec2(self.uv4[0], self.uv4[1])
        parent_drawlist.AddImageQuad(self.texture.allocated_texture, \
            ip1, ip2, ip3, ip4, iuv1, iuv2, iuv3, iuv4, self.color_multiplier)



cdef class dcgDrawLine_(drawingItem):
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] p1
        cdef float[4] p2
        self.context.viewport.apply_current_transform(p1, self.p1, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p2, self.p2, parent_x, parent_y)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        parent_drawlist.AddLine(ip1, ip2, self.color, thickness)

cdef class dcgDrawPolyline_(drawingItem):
    def __cinit__(self):
        # points is empty init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.
        self.closed = False

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show) or self.points.size() < 2:
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] p
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip1_
        cdef imgui.ImVec2 ip2
        self.context.viewport.apply_current_transform(p, self.points[0].p, parent_x, parent_y)
        ip1 = imgui.ImVec2(p[0], p[1])
        ip1_ = ip1
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        cdef int i
        for i in range(1, <int>self.points.size()):
            self.context.viewport.apply_current_transform(p, self.points[i].p, parent_x, parent_y)
            ip2 = imgui.ImVec2(p[0], p[1])
            parent_drawlist.AddLine(ip1, ip2, self.color, thickness)
        if self.closed and self.points.size() > 2:
            parent_drawlist.AddLine(ip1_, ip2, self.color, thickness)

cdef inline bint is_counter_clockwise(imgui.ImVec2 p1,
                                      imgui.ImVec2 p2,
                                      imgui.ImVec2 p3) noexcept nogil:
    cdef float det = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    return det > 0.

cdef class dcgDrawPolygon_(drawingItem):
    def __cinit__(self):
        # points is empty init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.

    # ImGui Polygon fill requires clockwise order and convex polygon.
    # We want to be more lenient -> triangulate
    cdef void __triangulate(self):
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            return
        # TODO: optimize with arrays
        points = []
        cdef int i
        for i in range(<int>self.points.size()):
            # For now perform only in 2D
            points.append([self.points[i].p[0], self.points[i].p[1]])
        # order is counter clock-wise
        self.triangulation_indices = scipy.spatial.Delaunay(points).simplices

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show) or self.points.size() < 2:
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] p
        cdef imgui.ImVec2 ip
        cdef vector[imgui.ImVec2] ipoints
        cdef int i
        cdef bint ccw
        ipoints.reserve(self.points.size())
        for i in range(<int>self.points.size()):
            self.context.viewport.apply_current_transform(p, self.points[i].p, parent_x, parent_y)
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        # Draw interior
        if self.fill & imgui.IM_COL32_A_MASK != 0 and self.triangulation_indices.shape[0] > 0:
            # imgui requires clockwise order + convexity for correct AA
            # The triangulation always returns counter-clockwise
            # but the matrix can change the order.
            # The order should be the same for all triangles, except in plot with log
            # scale.
            for i in range(self.triangulation_indices.shape[0]):
                ccw = is_counter_clockwise(ipoints[self.triangulation_indices[i, 0]],
                                           ipoints[self.triangulation_indices[i, 1]],
                                           ipoints[self.triangulation_indices[i, 2]])
                if ccw:
                    parent_drawlist.AddTriangleFilled(ipoints[self.triangulation_indices[i, 0]],
                                                      ipoints[self.triangulation_indices[i, 2]],
                                                      ipoints[self.triangulation_indices[i, 1]],
                                                      self.fill)
                else:
                    parent_drawlist.AddTriangleFilled(ipoints[self.triangulation_indices[i, 0]],
                                                      ipoints[self.triangulation_indices[i, 1]],
                                                      ipoints[self.triangulation_indices[i, 2]],
                                                      self.fill)

        # Draw closed boundary
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        for i in range(1, <int>self.points.size()):
            parent_drawlist.AddLine(ipoints[i-1], ipoints[i], self.color, thickness)
        if self.points.size() > 2:
            parent_drawlist.AddLine(ipoints[0], ipoints[<int>self.points.size()-1], self.color, thickness)


cdef class dcgDrawQuad_(drawingItem):
    def __cinit__(self):
        # p1, p2, p3, p4 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] p1
        cdef float[4] p2
        cdef float[4] p3
        cdef float[4] p4
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4
        cdef bint ccw

        self.context.viewport.apply_current_transform(p1, self.p1, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p2, self.p2, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p3, self.p3, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p4, self.p4, parent_x, parent_y)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])

        # imgui requires clockwise order + convex for correct AA
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            ccw = is_counter_clockwise(ip1,
                                       ip2,
                                       ip3)
            if ccw:
                parent_drawlist.AddTriangleFilled(ip1, ip3, ip2, self.fill)
            else:
                parent_drawlist.AddTriangleFilled(ip1, ip2, ip3, self.fill)
            ccw = is_counter_clockwise(ip1,
                                       ip4,
                                       ip3)
            if ccw:
                parent_drawlist.AddTriangleFilled(ip1, ip3, ip4, self.fill)
            else:
                parent_drawlist.AddTriangleFilled(ip1, ip4, ip3, self.fill)

        parent_drawlist.AddLine(ip1, ip2, self.color, thickness)
        parent_drawlist.AddLine(ip2, ip3, self.color, thickness)
        parent_drawlist.AddLine(ip3, ip4, self.color, thickness)
        parent_drawlist.AddLine(ip4, ip1, self.color, thickness)


cdef class dcgDrawRect_(drawingItem):
    def __cinit__(self):
        self.pmin = [0., 0., 0., 0.]
        self.pmax = [1., 1., 0., 0.]
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.color_upper_left = 0
        self.color_upper_right = 0
        self.color_bottom_left = 0
        self.color_bottom_right = 0
        self.rounding = 0.
        self.thickness = 1.
        self.multicolor = False

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] pmin
        cdef float[4] pmax
        cdef imgui.ImVec2 ipmin
        cdef imgui.ImVec2 ipmax
        cdef imgui.ImU32 col_up_left = self.color_upper_left
        cdef imgui.ImU32 col_up_right = self.color_upper_right
        cdef imgui.ImU32 col_bot_left = self.color_bottom_left
        cdef imgui.ImU32 col_bot_right = self.color_bottom_right

        self.context.viewport.apply_current_transform(pmin, self.pmin, parent_x, parent_y)
        self.context.viewport.apply_current_transform(pmax, self.pmax, parent_x, parent_y)
        ipmin = imgui.ImVec2(pmin[0], pmin[1])
        ipmax = imgui.ImVec2(pmax[0], pmax[1])

        # The transform might invert the order
        if ipmin.x > ipmax.x:
            swap(ipmin.x, ipmax.x)
            swap(col_up_left, col_up_right)
            swap(col_bot_left, col_bot_right)
        if ipmin.y > ipmax.y:
            swap(ipmin.y, ipmax.y)
            swap(col_up_left, col_bot_left)
            swap(col_up_right, col_bot_right)

        # imgui requires clockwise order + convex for correct AA
        if self.multicolor:
            if (col_up_left|col_up_right|col_bot_left|col_up_right) & imgui.IM_COL32_A_MASK != 0:
                parent_drawlist.AddRectFilledMultiColor(ipmin,
                                                        ipmax,
                                                        col_up_left,
                                                        col_up_right,
                                                        col_bot_left,
                                                        col_bot_right)
        else:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                parent_drawlist.AddRectFilled(ipmin,
                                              ipmax,
                                              self.fill,
                                              self.rounding,
                                              imgui.ImDrawFlags_RoundCornersAll)

        parent_drawlist.AddRect(ipmin,
                                ipmax,
                                self.color,
                                self.rounding,
                                imgui.ImDrawFlags_RoundCornersAll,
                                thickness)

cdef class dgcDrawText_(drawingItem):
    def __cinit__(self):
        self.color = 4294967295 # 0xffffffff
        self.size = 1.

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float[4] p

        self.context.viewport.apply_current_transform(p, self.pos, parent_x, parent_y)
        cdef imgui.ImVec2 ip = imgui.ImVec2(p[0], p[1])

        # TODO fontptr

        #parent_drawlist.AddText(fontptr, self.size, ip, self.color, self.text.c_str())
        parent_drawlist.AddText(NULL, 0., ip, self.color, self.text.c_str())


cdef class dcgDrawTriangle_(drawingItem):
    def __cinit__(self):
        # p1, p2, p3 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.
        self.cull_mode = 0

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.context.viewport.mutex)
        cdef unique_lock[recursive_mutex] m3 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)
        if not(self.show):
            return

        cdef float thickness = self.thickness
        if self.context.viewport.in_plot:
            thickness *= self.context.viewport.thickness_multiplier

        cdef float[4] p1
        cdef float[4] p2
        cdef float[4] p3
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef bint ccw

        self.context.viewport.apply_current_transform(p1, self.p1, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p2, self.p2, parent_x, parent_y)
        self.context.viewport.apply_current_transform(p3, self.p3, parent_x, parent_y)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ccw = is_counter_clockwise(ip1,
                                   ip2,
                                   ip3)

        if self.cull_mode == 1 and ccw:
            return
        if self.cull_mode == 2 and not(ccw):
            return

        # imgui requires clockwise order + convex for correct AA
        if ccw:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                parent_drawlist.AddTriangleFilled(ip1, ip3, ip2, self.fill)
            parent_drawlist.AddTriangle(ip1, ip3, ip2, self.color, thickness)
        else:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                parent_drawlist.AddTriangleFilled(ip1, ip2, ip3, self.fill)
            parent_drawlist.AddTriangle(ip1, ip2, ip3, self.color, thickness)

"""
Global handlers
"""
cdef class globalHandler(baseItem):
    def __cinit__(self):
        self.enabled = True
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.enabled = kwargs.pop("enabled", self.enabled)
        self.enabled = kwargs.pop("show", self.enabled)
        callback = kwargs.pop("callback", self.callback)
        self.callback = callback if isinstance(callback, dcgCallback) else dcgCallback(callback)
        return super().configure(**kwargs)
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.enabled = value
    @property
    def callback(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.callback
    @callback.setter
    def callback(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.callback = value if isinstance(value, dcgCallback) or value is None else dcgCallback(value)
    cdef void run_handler(self) noexcept nogil:
        return
    cdef void run_callback(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.queue_callback_noarg(self.callback, self)

cdef class dcgGlobalHandlerRegistry(baseItem):
    cdef void run_handlers(self) noexcept nogil:
        return

cdef class dcgKeyDownHandler_(globalHandler):
    def __cinit__(self):
        self.key = imgui.ImGuiKey_None

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiKeyData *key_info
        cdef int i
        if self.key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                key_info = imgui.GetKeyData(<imgui.ImGuiKey>i)
                if key_info.Down:
                    self.context.queue_callback_arg1int1float(self.callback, self, i, key_info.DownDuration)
        else:
            key_info = imgui.GetKeyData(<imgui.ImGuiKey>self.key)
            if key_info.Down:
                self.context.queue_callback_arg1int1float(self.callback, self, self.key, key_info.DownDuration)

cdef class dcgKeyPressHandler_(globalHandler):
    def __cinit__(self):
        self.key = imgui.ImGuiKey_None
        self.repeat = True

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self.key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyPressed(<imgui.ImGuiKey>i, self.repeat):
                    self.context.queue_callback_arg1int(self.callback, self, i)
        else:
            if imgui.IsKeyPressed(<imgui.ImGuiKey>self.key, self.repeat):
                self.context.queue_callback_arg1int(self.callback, self, self.key)

cdef class dcgKeyReleaseHandler_(globalHandler):
    def __cinit__(self):
        self.key = imgui.ImGuiKey_None

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self.key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyReleased(<imgui.ImGuiKey>i):
                    self.context.queue_callback_arg1int(self.callback, self, i)
        else:
            if imgui.IsKeyReleased(<imgui.ImGuiKey>self.key):
                self.context.queue_callback_arg1int(self.callback, self, self.key)


cdef class dcgMouseClickHandler_(globalHandler):
    def __cinit__(self):
        self.button = -1
        self.repeat = False

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseClicked(i, self.repeat):
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgMouseDoubleClickHandler_(globalHandler):
    def __cinit__(self):
        self.button = -1

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseDoubleClicked(i):
                self.context.queue_callback_arg1int(self.callback, self, i)


cdef class dcgMouseDownHandler_(globalHandler):
    def __cinit__(self):
        self.button = -1

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseDown(i):
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgMouseDragHandler_(globalHandler):
    def __cinit__(self):
        self.button = -1
        self.threshold = -1 # < 0. means use default
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef imgui.ImVec2 delta
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseDragging(i, self.threshold):
                delta = imgui.GetMouseDragDelta(i, self.threshold)
                self.context.queue_callback_arg1int2float(self.callback, self, i, delta.x, delta.y)


cdef class dcgMouseMoveHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            self.context.queue_callback_arg2float(self.callback, self, io.MousePos.x, io.MousePos.y)
            

cdef class dcgMouseReleaseHandler_(globalHandler):
    def __cinit__(self):
        self.button = -1

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseReleased(i):
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgMouseWheelHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if abs(io.MouseWheel) > 0.:
            self.context.queue_callback_arg1float(self.callback, self, io.MouseWheel)


"""
Sources
"""

cdef class shared_bool:
    def __init__(self, bint value):
        self._value = value
    @property
    def value(self):
        return self._value
    @value.setter
    def value(self, bint value):
        self._value = value
    cdef bint get(self) noexcept nogil:
        return self._value
    cdef void set(self, bint value) noexcept nogil:
        self._value = value

cdef class shared_float:
    def __init__(self, float value):
        self._value = value
    @property
    def value(self):
        return self._value
    @value.setter
    def value(self, float value):
        self._value = value
    cdef float get(self) noexcept nogil:
        return self._value
    cdef void set(self, float value) noexcept nogil:
        self._value = value

cdef class shared_int:
    def __init__(self, int value):
        self._value = value
    @property
    def value(self):
        return self._value
    @value.setter
    def value(self, int value):
        self._value = value
    cdef int get(self) noexcept nogil:
        return self._value
    cdef void set(self, int value) noexcept nogil:
        self._value = value

cdef class shared_color:
    def __init__(self, value):
        self._value = parse_color(value)
        self._value_asfloat4 = imgui.ColorConvertU32ToFloat4(self._value)
    @property
    def value(self):
        "Color data is an int32 (rgba, little endian),\n" \
        "If you pass an array of int (r, g, b, a), or float\n" \
        "(r, g, b, a) normalized it will get converted automatically"
        return <int>self._value
    @value.setter
    def value(self, value):
        self._value = parse_color(value)
        self._value_asfloat4 = imgui.ColorConvertU32ToFloat4(self._value)
    cdef imgui.ImU32 getU32(self) noexcept nogil:
        return self._value
    cdef imgui.ImVec4 getF4(self) noexcept nogil:
        return self._value_asfloat4
    cdef void setU32(self, imgui.ImU32 value) noexcept nogil:
        self._value = value
        self._value_asfloat4 = imgui.ColorConvertU32ToFloat4(self._value)
    cdef void setF4(self, imgui.ImVec4 value) noexcept nogil:
        self._value_asfloat4 = value
        self._value = imgui.ColorConvertFloat4ToU32(self._value_asfloat4)

cdef class shared_double:
    def __init__(self, double value):
        self._value = value
    @property
    def value(self):
        return self._value
    @value.setter
    def value(self, double value):
        self._value = value
    cdef double get(self) noexcept nogil:
        return self._value
    cdef void set(self, double value) noexcept nogil:
        self._value = value

cdef class shared_str:
    def __init__(self, str value):
        self._value = bytes(str(value), 'utf-8')
    @property
    def value(self):
        return str(self._value)
    @value.setter
    def value(self, str value):
        self._value = bytes(str(value), 'utf-8')
    cdef string get(self) noexcept nogil:
        return self._value
    cdef void set(self, string value) noexcept nogil:
        self._value = value

cdef class shared_float4:
    def __init__(self, value):
        read_point[float](self._value, value)
    @property
    def value(self):
        return list(self._value)
    @value.setter
    def value(self, value):
        read_point[float](self._value, value)
    cdef void get(self, float *dst) noexcept nogil:
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, float[4] value) noexcept nogil:
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]

cdef class shared_int4:
    def __init__(self, value):
        read_point[int](self._value, value)
    @property
    def value(self):
        return list(self._value)
    @value.setter
    def value(self, value):
        read_point[int](self._value, value)
    cdef void get(self, int *dst) noexcept nogil:
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, int[4] value) noexcept nogil:
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]

cdef class shared_double4:
    def __init__(self, value):
        read_point[double](self._value, value)
    @property
    def value(self):
        return list(self._value)
    @value.setter
    def value(self, value):
        read_point[double](self._value, value)
    cdef void get(self, double *dst) noexcept nogil:
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, double[4] value) noexcept nogil:
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]

"""
cdef class shared_floatvect:
    def __init__(self, value):
        read_point[double](self._value, value)
    cdef float[:] get(self) noexcept nogil
    cdef void set(self, float[:]) noexcept nogil

cdef class shared_doublevect:
    cdef double[:] value
    cdef double[:] get(self) noexcept nogil
    cdef void set(self, double[:]) noexcept nogil

cdef class shared_time:
    cdef tm value
    cdef tm get(self) noexcept nogil
    cdef void set(self, tm) noexcept nogil
"""

"""
UI elements
"""

"""
UI styles
"""


"""
UI input event handlers
"""

cdef class itemHandler(baseItem):
    def __cinit__(self):
        self.enabled = True
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.enabled = kwargs.pop("enabled", self.enabled)
        self.enabled = kwargs.pop("show", self.enabled)
        return super().configure(**kwargs)
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.enabled = value
    cdef void check_bind(self, uiItem item):
        return
    cdef void run_handler(self, uiItem item) noexcept nogil:
        return
    cdef void run_callback(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.queue_callback_noarg(self.callback, self)

cdef class dcgItemHandlerRegistry(baseItem):
    cdef void check_bind(self, uiItem item):
        pass
    cdef void run_handlers(self, uiItem item) noexcept nogil:
        pass

cdef inline object IntPairFromVec2(imgui.ImVec2 v):
    return (<int>v.x, <int>v.y)

cdef class uiItem(drawableItem):
    def __cinit__(self):
        # mvAppItemInfo
        self.internalLabel = bytes(str(self.uuid), 'utf-8') # TODO
        #self.location = -1
        # next frame triggers
        self.focus_update_requested = False
        self.show_update_requested = False
        self.size_update_requested = True
        self.pos_update_requested = False
        self.last_frame_update = 0 # last frame update occured
        # mvAppItemConfig
        #self.source = 0
        #self.specifiedLabel = b""
        #self.filter = b""
        self.alias = b""
        self.payloadType = b"$$DPG_PAYLOAD"
        self.width = 0
        self.height = 0
        self.indent = -1.
        #self.trackOffset = 0.5 # 0.0f:top, 0.5f:center, 1.0f:bottom
        #self.enabled = True
        self.useInternalLabel = True #when false, will use specificed label
        #self.tracked = False
        #self.callback = None
        #self.user_data = None
        self.dragCallback = None
        self.dropCallback = None

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        remaining = {}
        for (key, value) in kwargs.items():
            if hasattr(self, key):
                setattr(self, key, value)
            # Convert old names to new attributes
            elif key == "min_size":
                self.rect_min = value
            elif key == "max_size":
                self.rect_max = value
            else:
                remaining[key] = value
        super().configure(**remaining)

    cdef void update_current_state(self) noexcept nogil:
        """
        Updates the state of the last imgui object.
        """
        if self.state.can_be_hovered:
            self.state.hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
        if self.state.can_be_active:
            self.state.active = imgui.IsItemActive()
        if self.state.can_be_activated:
            self.state.activated = imgui.IsItemActivated()
        cdef int i
        if self.state.can_be_clicked:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.clicked[i] = self.state.hovered and imgui.IsItemClicked(i)
                self.state.double_clicked[i] = self.state.hovered and imgui.IsMouseDoubleClicked(i)
        if self.state.can_be_deactivated:
            self.state.deactivated = imgui.IsItemDeactivated()
        if self.state.can_be_deactivated_after_edited:
            self.state.deactivated_after_edited = imgui.IsItemDeactivatedAfterEdit()
        if self.state.can_be_edited:
            self.state.edited = imgui.IsItemEdited()
        if self.state.can_be_focused:
            self.state.focused = imgui.IsItemFocused()
        if self.state.can_be_toggled:
            self.state.toggled = imgui.IsItemToggledOpen()
        if self.state.has_rect_min:
            self.state.rect_min = imgui.GetItemRectMin()
        if self.state.has_rect_max:
            self.state.rect_max = imgui.GetItemRectMax()
        cdef imgui.ImVec2 rect_size
        if self.state.has_rect_size:
            rect_size = imgui.GetItemRectSize()
            self.state.resized = rect_size.x != self.state.rect_size.x or \
                                 rect_size.y != self.state.rect_size.y
            self.state.rect_size = rect_size
        if self.state.has_content_region:
            self.state.content_region = imgui.GetContentRegionAvail()
        self.state.visible = imgui.IsItemVisible()
        self.state.relative_position = imgui.GetCursorPos()

    cdef void update_current_state_as_hidden(self) noexcept nogil:
        """
        Indicates the object is hidden
        """
        self.state.hovered = False
        self.state.active = False
        self.state.activated = False
        cdef int i
        if self.state.can_be_clicked:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.clicked[i] = False
                self.state.double_clicked[i] = False
        self.state.deactivated = False
        self.state.deactivated_after_edited = False
        self.state.edited = False
        self.state.focused = False
        self.state.toggled = False
        self.state.resized = False
        self.state.visible = False

    cdef object output_current_item_state(self):
        """
        Helper function to return the current dict of item state
        """
        output = {}
        if self.state.can_be_hovered:
            output["hovered"] = self.state.hovered
        if self.state.can_be_active:
            output["active"] = self.state.active
        if self.state.can_be_activated:
            output["activated"] = self.state.activated
        if self.state.can_be_clicked:
            output["clicked"] = max(self.state.clicked)
            output["left_clicked"] = self.state.clicked[0]
            output["middle_clicked"] = self.state.clicked[2]
            output["right_clicked"] = self.state.clicked[1]
        if self.state.can_be_deactivated:
            output["deactivated"] = self.state.deactivated
        if self.state.can_be_deactivated_after_edited:
            output["deactivated_after_edit"] = self.state.deactivated_after_edited
        if self.state.can_be_edited:
            output["edited"] = self.state.edited
        if self.state.can_be_focused:
            output["focused"] = self.state.focused
        if self.state.can_be_toggled:
            output["toggle_open"] = self.state.toggled
        if self.state.has_rect_min:
            output["rect_min"] = IntPairFromVec2(self.state.rect_min)
        if self.state.has_rect_max:
            output["rect_max"] = IntPairFromVec2(self.state.rect_max)
        if self.state.has_rect_size:
            output["rect_size"] = IntPairFromVec2(self.state.rect_size)
            output["resized"] = self.state.resized
        if self.state.has_content_region:
            output["content_region_avail"] = IntPairFromVec2(self.state.content_region)
        output["ok"] = True # Original code only set this to False on missing texture or invalid style
        output["visible"] = self.state.visible
        output["pos"] = (self.state.relative_position.x, self.state.relative_position.y)
        return output

    cdef void propagate_hidden_state_to_children(self) noexcept nogil:
        """
        The item is hidden (closed window, etc).
        Propagate the hidden state to children
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.last_widgets_child is not None:
            self.last_widgets_child.set_hidden_and_propagate()

    cdef void set_hidden_and_propagate(self) noexcept nogil:
        """
        A parent item is hidden. Propagate to children and siblings
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.last_widgets_child is not None:
            self.last_widgets_child.set_hidden_and_propagate()
        if self.prev_sibling is not None:
            (<uiItem>self.prev_sibling).set_hidden_and_propagate()
        self.update_current_state_as_hidden()

    def bind_handlers(self, dcgItemHandlerRegistry handlers):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        # Check the list of handlers can use our states. Else raise error
        handlers.check_bind(self)
        # yes: bind
        self.handlers = handlers

    # TODO: Find a better way to share all this attributes while avoiding AttributeError

    @property
    def active(self):
        """
        Readonly attribute: is the item active
        """
        if not(self.state.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.active

    @property
    def activated(self):
        """
        Readonly attribute: has the item just turned active
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.can_be_activated):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.activated

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return tuple(self.state.clicked)

    @property
    def double_clicked(self):
        """
        Readonly attribute: has the item just been double-clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.double_clicked

    @property
    def deactivated(self):
        """
        Readonly attribute: has the item just turned un-active
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.can_be_deactivated):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.deactivated

    @property
    def deactivated_after_edited(self):
        """
        Readonly attribute: has the item just turned un-active after having
        been edited.
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.can_be_deactivated_after_edited):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.deactivated_after_edited

    @property
    def edited(self):
        """
        Readonly attribute: has the item just been edited
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.can_be_edited):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.edited

    @property
    def focused(self):
        """
        Writable attribute: Is the item focused ?
        For windows it means the window is at the top,
        while for items it could mean the keyboard inputs are redirected to it.
        """
        if not(self.state.can_be_focused):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.focused

    @focused.setter
    def focused(self, bint value):
        """
        Writable attribute: Is the item focused ?
        For windows it means the window is at the top,
        while for items it could mean the keyboard inputs are redirected to it.
        """
        if not(self.state.can_be_focused):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.state.focused = value
        self.focus_update_requested = True

    @property
    def hovered(self):
        """
        Readonly attribute: Is the mouse inside the region of the item.
        Only one element is hovered at a time, thus
        subitems/subwindows take priority over their parent.
        """
        if not(self.state.can_be_hovered):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.hovered

    @property
    def resized(self):
        """
        Readonly attribute: has the item size just changed
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.has_rect_size):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.resized

    @property
    def toggled(self):
        """
        Has a menu/bar trigger been hit for the item
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.can_be_toggled):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.toggled

    @property
    def visible(self):
        """
        True if the item was rendered (inside the rendering region + show = True
        for the item and its ancestors). Not impacted by occlusion.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.state.visible

    @property
    def content_region_avail(self):
        """
        Region available for the current element size if scrolling was disallowed
        """
        if not(self.state.has_content_region):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return IntPairFromVec2(self.state.content_region)

    @property
    def rect_min(self):
        """
        Requested minimum size (width, height) allowed for the item.
        Writable attribute
        """
        if not(self.state.has_rect_min):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return IntPairFromVec2(self.state.rect_min)

    @rect_min.setter
    def rect_min(self, value):
        if not(self.state.has_rect_min):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        if len(value) != 2:
            raise ValueError("Expected tuple for rect_min: (width, height)")
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.state.rect_min.x = value[0]
        self.state.rect_min.y = value[1]

    @property
    def rect_max(self):
        """
        Requested minimum size (width, height) allowed for the item.
        Writable attribute
        """
        if not(self.state.has_rect_max):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return IntPairFromVec2(self.state.rect_max)

    @rect_max.setter
    def rect_max(self, value):
        if not(self.state.has_rect_max):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        if len(value) != 2:
            raise ValueError("Expected tuple for rect_max: (width, height)")
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.state.rect_max.x = value[0]
        self.state.rect_max.y = value[1]

    @property
    def width(self):
        """
        Writable attribute: requested width of the item.
        When it is written, it is set to a 'requested value' that is not
        entirely guaranteed to be enforced
        Specific values:
            . Windows: 0 means fit to take the maximum size available
            . Some Items: <0. means align of ... pixels to the right of the window
            . Some Items: 0 can mean use remaining space or fit to content 
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.width

    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.width = value
        self.state.rect_size.x = value
        self.size_update_requested = True

    @property
    def height(self):
        """
        Writable attribute: requested height of the item.
        When it is written, it is set to a 'requested value' that is not
        entirely guaranteed to be enforced.
        Specific values:
            . Windows: 0 means fit to take the maximum size available
            . Some Items: <0. means align of ... pixels to the right of the window
            . Some Items: 0 can mean use remaining space or fit to content 
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.height

    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.height = value
        self.state.rect_size.y = value
        self.size_update_requested = True

    @property
    def rect_size(self):
        """
        Readonly attribute: actual (width, height) of the element
        """
        if not(self.state.has_rect_size):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return IntPairFromVec2(self.state.rect_size)

    @property
    def pos(self):
        """
        Writable attribute: Relative position (x, y) of the element inside
        the drawable region of the parent
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return IntPairFromVec2(self.state.relative_position)

    @pos.setter
    def pos(self, value):
        if len(value) == 0:
            # Used to indicate "keep default value" during init
            return
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.state.relative_position.x = value[0]
        self.state.relative_position.y = value[1]
        self.pos_update_requested = True



cdef class dcgWindow_(uiItem):
    def __cinit__(self):
        self.window_flags = imgui.ImGuiWindowFlags_None
        self.main_window = False
        self.modal = False
        self.popup = False
        self.has_close_button = True
        self.collapsed = False
        self.collapse_update_requested = False
        self.no_open_over_existing_popup = True
        self.on_close_callback = None
        self.state.rect_min = imgui.ImVec2(100., 100.) # tODO state ?
        self.state.rect_max = imgui.ImVec2(30000., 30000.)
        self.scroll_x = 0.
        self.scroll_y = 0.
        self.scroll_x_update_requested = False
        self.scroll_y_update_requested = False
        # Read-only states
        self.scroll_max_x = 0.
        self.scroll_max_y = 0.

        # backup states when we set/unset primary
        #self.backup_window_flags = imgui.ImGuiWindowFlags_None
        #self.backup_pos = self.state.relative_position
        #self.backup_rect_size = self.state.rect_size
        # Type info
        self.can_have_0_child = True
        self.can_have_widget_child = True
        self.can_have_drawing_child = True
        self.can_have_payload_child = True
        self.can_have_nonviewport_parent = True
        self.element_toplevel_category = 4
        self.state.can_be_hovered = True
        self.state.can_be_focused = True
        self.state.has_rect_size = True
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_content_region = True

    cdef void draw(self, imgui.ImDrawList* parent_drawlist, float parent_x, float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(parent_drawlist, parent_x, parent_y)

        if not(self.show):
            if self.show_update_requested:
                self.set_hidden_and_propagate()
                self.show_update_requested = True
            return

        if self.focus_update_requested:
            if self.state.focused:
                imgui.SetNextWindowFocus()
            self.focus_update_requested = False

        if self.pos_update_requested:
            imgui.SetNextWindowPos(self.state.relative_position, <imgui.ImGuiCond>0)
            self.pos_update_requested = False

        if self.size_update_requested:
            imgui.SetNextWindowSize(imgui.ImVec2(<float>self.width,
                                                 <float>self.height),
                                    <imgui.ImGuiCond>0)
            self.size_update_requested = False

        if self.collapse_update_requested:
            imgui.SetNextWindowCollapsed(self.collapsed, <imgui.ImGuiCond>0)
            self.collapse_update_requested = False

        imgui.SetNextWindowSizeConstraints(self.state.rect_min, self.state.rect_max)

        cdef imgui.ImVec2 scroll_requested
        if self.scroll_x_update_requested or self.scroll_y_update_requested:
            scroll_requested = imgui.ImVec2(-1., -1.) # -1 means no effect
            if self.scroll_x_update_requested:
                if self.scroll_x < 0.:
                    scroll_requested.x = 1. # from previous code. Not sure why
                else:
                    scroll_requested.x = self.scroll_x
                self.scroll_x_update_requested = False

            if self.scroll_y_update_requested:
                if self.scroll_y < 0.:
                    scroll_requested.y = 1.
                else:
                    scroll_requested.y = self.scroll_y
                self.scroll_y_update_requested = False
            imgui.SetNextWindowScroll(scroll_requested)

        if self.main_window:
            imgui.SetNextWindowBgAlpha(1.0)
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowRounding, 0.0) #to prevent main window corners from showing
            imgui.SetNextWindowPos(imgui.ImVec2(0.0, 0.0), <imgui.ImGuiCond>0)
            imgui.SetNextWindowSize(imgui.ImVec2(<float>self.context.viewport.viewport.clientWidth,
                                           <float>self.context.viewport.viewport.clientHeight),
                                    <imgui.ImGuiCond>0)

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

        cdef bint visible = True
        # Modal/Popup windows must be manually opened
        if self.modal or self.popup:
            if self.show_update_requested and self.show:
                self.show_update_requested = False
                imgui.OpenPopup(self.internalLabel.c_str(),
                                imgui.ImGuiPopupFlags_NoOpenOverExistingPopup if self.no_open_over_existing_popup else imgui.ImGuiPopupFlags_None)

        # Begin drawing the window
        if self.modal:
            visible = imgui.BeginPopupModal(self.internalLabel.c_str(), &self.show if self.has_close_button else <bool*>NULL, self.window_flags)
        elif self.popup:
            visible = imgui.BeginPopup(self.internalLabel.c_str(), self.window_flags)
        else:
            visible = imgui.Begin(self.internalLabel.c_str(),
                                  &self.show if self.has_close_button else <bool*>NULL,
                                  self.window_flags)

        # not(visible) means either closed or clipped
        # if has_close_button, show can be switched from True to False if closed

        cdef imgui.ImDrawList* this_drawlist
        cdef float startx, starty

        if visible:
            # Draw the window content
            this_drawlist = imgui.GetWindowDrawList()
            startx = <float>imgui.GetCursorScreenPos().x
            starty = <float>imgui.GetCursorScreenPos().y

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

        cdef imgui.ImVec2 rect_size
        if visible:
            # Set current states
            self.state.visible = True
            self.state.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            rect_size = imgui.GetWindowSize()
            self.state.resized = rect_size.x != self.state.rect_size.x or \
                                 rect_size.y != self.state.rect_size.y
            # TODO: investigate why width and height could be != state.rect_size
            if (rect_size.x != <float>self.width or rect_size.y != <float>self.height):
                self.width = <int>rect_size.x
                self.height = <int>rect_size.y
                self.resized = True
            self.state.rect_size = rect_size
            self.last_frame_update = self.context.frame
            self.state.relative_position = imgui.GetWindowPos()
        else:
            # Window is hidden or closed
            if not(self.state.visible): # This is not new
                # Propagate the info
                self.set_hidden_and_propagate()

        self.collapsed = imgui.IsWindowCollapsed()
        self.state.toggled = imgui.IsWindowAppearing() # Original code used Collapsed
        self.scroll_x = imgui.GetScrollX()
        self.scroll_y = imgui.GetScrollY()


        # Post draw
        """
        // pop font from stack
        if (item.font)
            ImGui::PopFont();
        """

        #// handle popping themes
        #cleanup_local_theming(&item);
        """
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
        """

        if (self.modal or self.popup):
            if visible:
                # End() is called automatically for modal and popup windows if not visible
                imgui.EndPopup()
        else:
            imgui.End()

        if self.main_window:
            imgui.PopStyleVar(1)

        cdef bint closed = not(self.show) or (not(visible) and (self.modal or self.popup))
        if closed:
            self.show = False
            self.context.queue_callback_noarg(self.on_close_callback,
                                              self)
        self.show_update_requested = False

        #if (self..handlerRegistry)
        #    item.handlerRegistry->checkEvents(&item.state);
        imgui.PopID()


"""
Textures
"""



cdef class dcgTexture_(baseItem):
    def __cinit__(self):
        self.hint_dynamic = False
        self.dynamic = False
        self.allocated_texture = NULL
        self.width = 0
        self.height = 0
        self.num_chans = 0
        self.filtering_mode = 0

    def __delalloc__(self):
        # Note: textures might be referenced during imgui rendering.
        # Thus we must wait there is no rendering to free a texture.
        if self.allocated_texture != NULL:
            if not(self.context.imgui_mutex.try_lock()):
                with nogil: # rendering can take some time so avoid holding the gil
                    self.context.imgui_mutex.lock()
            mvMakeRenderingContextCurrent(dereference(self.context.viewport.viewport))
            mvFreeTexture(self.allocated_texture)
            mvReleaseRenderingContext(dereference(self.context.viewport.viewport))
            self.context.imgui_mutex.unlock()

    cdef void set_content(self, cnp.ndarray content):
        # The write mutex is to ensure order of processing of set_content
        # as we might release the item mutex to wait for imgui to render
        cdef unique_lock[recursive_mutex] m
        with nogil:
            # The mutex might be held for a long time, see below.
            # Thus we release the gil before trying to lock
            m = unique_lock[recursive_mutex](self.write_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        if content.ndim > 3 or content.ndim == 0:
            raise ValueError("Invalid number of texture dimensions")
        cdef int height = 1
        cdef int width = 1
        cdef int num_chans = 1
        assert(content.flags['C_CONTIGUOUS'])
        if content.ndim >= 1:
            height = content.shape[0]
        if content.ndim >= 2:
            width = content.shape[1]
        if content.ndim >= 3:
            num_chans = content.shape[2]
        if width * height * num_chans == 0:
            raise ValueError("Cannot set empty texture")

        # TODO: there must be a faster test
        if not(content.dtype == np.float32 or content.dtype == np.uint8):
            content = np.ascontiguousarray(content, dtype=np.float32)

        cdef bint reuse = self.allocated_texture != NULL
        reuse = reuse and (self.width != width or self.height != height or self.num_chans != num_chans)
        cdef unsigned buffer_type = 1 if content.dtype == np.uint8 else 0
        with nogil:
            if self.allocated_texture != NULL and not(reuse):
                # We must wait there is no rendering since the current rendering might reference the texture
                # Release current lock to not block rendering
                # Wait we can prevent rendering
                if not(self.context.imgui_mutex.try_lock()):
                    m2.unlock()
                    # rendering can take some time, fortunately we avoid holding the gil
                    self.context.imgui_mutex.lock()
                    m2.lock()
                mvMakeRenderingContextCurrent(dereference(self.context.viewport.viewport))
                mvFreeTexture(self.allocated_texture)
                self.context.imgui_mutex.unlock()
                self.allocated_texture = NULL
            else:
                mvMakeRenderingContextCurrent(dereference(self.context.viewport.viewport))

            # Note we don't need the imgui mutex to create or upload textures.
            # In the case of GL, as only one thread can access GL data at a single
            # time, MakeRenderingContextCurrent and ReleaseRenderingContext enable
            # to upload/create textures from various threads. They hold a mutex.
            # That mutex is held in the relevant parts of frame rendering.

            self.width = width
            self.height = height
            self.num_chans = num_chans

            if not(reuse):
                self.dynamic = self.hint_dynamic
                self.allocated_texture = mvAllocateTexture(width, height, num_chans, self.dynamic, buffer_type, self.filtering_mode)

            if self.dynamic:
                mvUpdateDynamicTexture(self.allocated_texture, width, height, num_chans, buffer_type, <void*>content.data)
            else:
                mvUpdateStaticTexture(self.allocated_texture, width, height, num_chans, buffer_type, <void*>content.data)
            mvReleaseRenderingContext(dereference(self.context.viewport.viewport))


cdef class theme:
    cdef void push(self) noexcept nogil:
        return
    cdef void pop(self) noexcept nogil:
        return

cdef imgui.ImU32 imgui_ColorConvertFloat4ToU32(imgui.ImVec4 color_float4) noexcept nogil:
    return imgui.ColorConvertFloat4ToU32(color_float4)

cdef imgui.ImVec4 imgui_ColorConvertU32ToFloat4(imgui.ImU32 color_uint) noexcept nogil:
    return imgui.ColorConvertU32ToFloat4(color_uint)

cdef const char* imgui_GetStyleColorName(int i) noexcept nogil:
    return imgui.GetStyleColorName(<imgui.ImGuiCol>i)

cdef void imgui_PushStyleColor(int i, imgui.ImU32 val) noexcept nogil:
    imgui.PushStyleColor(<imgui.ImGuiCol>i, val)

cdef void imgui_PopStyleColor(int count) noexcept nogil:
    imgui.PopStyleColor(count)

cdef void imnodes_PushStyleColor(int i, imgui.ImU32 val) noexcept nogil:
    imnodes.PushColorStyle(<imnodes.ImNodesCol>i, val)

cdef void imnodes_PopStyleColor(int count) noexcept nogil:
    cdef int i
    for i in range(count):
        imnodes.PopColorStyle()

cdef const char* implot_GetStyleColorName(int i) noexcept nogil:
    return implot.GetStyleColorName(<implot.ImPlotCol>i)

cdef void implot_PushStyleColor(int i, imgui.ImU32 val) noexcept nogil:
    implot.PushStyleColor(<implot.ImPlotCol>i, val)

cdef void implot_PopStyleColor(int count) noexcept nogil:
    implot.PopStyleColor(count)

def color_as_int(val):
    cdef imgui.ImU32 color = parse_color(val)
    return int(color)

def color_as_ints(val):
    cdef imgui.ImU32 color = parse_color(val)
    cdef imgui.ImVec4 color_vec = imgui.ColorConvertU32ToFloat4(color)
    return (int(255. * color_vec.x),
            int(255. * color_vec.y),
            int(255. * color_vec.z),
            int(255. * color_vec.w))

def color_as_floats(val):
    cdef imgui.ImU32 color = parse_color(val)
    cdef imgui.ImVec4 color_vec = imgui.ColorConvertU32ToFloat4(color)
    return (color_vec.x, color_vec.y, color_vec.z, color_vec.w)