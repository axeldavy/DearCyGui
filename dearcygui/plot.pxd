from dearcygui.wrapper cimport imgui, implot
from .core cimport baseItem, Font, itemState, \
    plotElement, uiItem, Callback, baseHandler

from libcpp.string cimport string
from libcpp.vector cimport vector

cimport numpy as cnp

cpdef enum AxisScale:
    linear=implot.ImPlotScale_Linear
    time=implot.ImPlotScale_Time
    log10=implot.ImPlotScale_Log10
    symlog=implot.ImPlotScale_SymLog

cpdef enum Axis:
    X1=implot.ImAxis_X1
    X2=implot.ImAxis_X2
    X3=implot.ImAxis_X3
    Y1=implot.ImAxis_Y1
    Y2=implot.ImAxis_Y2
    Y3=implot.ImAxis_Y3

cpdef enum LegendLocation:
    center=implot.ImPlotLocation_Center
    north=implot.ImPlotLocation_Center
    south=implot.ImPlotLocation_Center
    west=implot.ImPlotLocation_Center
    east=implot.ImPlotLocation_Center
    northwest=implot.ImPlotLocation_NorthWest
    northeast=implot.ImPlotLocation_NorthEast
    southwest=implot.ImPlotLocation_SouthWest
    southeast=implot.ImPlotLocation_SouthEast


cdef class AxesResizeHandler(baseHandler):
    cdef int[2] _axes
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil


cdef class PlotAxisConfig(baseItem):
    cdef bint _enabled
    cdef AxisScale _scale
    cdef string _tick_format
    cdef implot.ImPlotAxisFlags flags
    cdef double _min
    cdef double _max
    cdef double prev_min
    cdef double prev_max
    cdef bint dirty_minmax
    cdef double _constraint_min
    cdef double _constraint_max
    cdef double _zoom_min
    cdef double _zoom_max
    cdef double _mouse_coord
    cdef bint to_fit
    cdef itemState state
    cdef Callback _resize_callback
    cdef string _label
    cdef string _format
    cdef vector[string] _labels
    cdef vector[const char*] _labels_cstr
    cdef vector[double] _labels_coord
    cdef void setup(self, implot.ImAxis) noexcept nogil
    cdef void after_setup(self, implot.ImAxis) noexcept nogil
    cdef void after_plot(self, implot.ImAxis) noexcept nogil
    cdef void set_hidden(self) noexcept nogil

cdef class PlotLegendConfig(baseItem):
    cdef bint _show
    cdef LegendLocation _location
    cdef implot.ImPlotLegendFlags flags
    cdef void setup(self) noexcept nogil
    cdef void after_setup(self) noexcept nogil

cdef class Plot(uiItem):
    cdef PlotAxisConfig _X1
    cdef PlotAxisConfig _X2
    cdef PlotAxisConfig _X3
    cdef PlotAxisConfig _Y1
    cdef PlotAxisConfig _Y2
    cdef PlotAxisConfig _Y3
    cdef PlotLegendConfig _legend
    cdef imgui.ImVec2 _content_pos
    cdef int _pan_button
    cdef imgui.ImGuiKeyChord _pan_modifier
    cdef int _fit_button
    cdef int _menu_button
    cdef imgui.ImGuiKeyChord _override_mod
    cdef imgui.ImGuiKeyChord _zoom_mod
    cdef float _zoom_rate
    cdef bint _use_local_time
    cdef bint _use_ISO8601
    cdef bint _use_24hour_clock
    cdef implot.ImPlotFlags flags
    cdef bint draw_item(self) noexcept nogil

cdef class plotElementWithLegend(plotElement):
    cdef itemState state
    cdef bint _legend
    cdef int _legend_button
    cdef Font _font
    cdef bint _enabled
    cdef bint enabled_dirty
    cdef void draw(self) noexcept nogil
    cdef void draw_element(self) noexcept nogil

cdef class plotElementXY(plotElementWithLegend):
    cdef cnp.ndarray _X
    cdef cnp.ndarray _Y
    cdef void check_arrays(self) noexcept nogil

cdef class PlotLine(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class plotElementXYY(plotElementWithLegend):
    cdef cnp.ndarray _X
    cdef cnp.ndarray _Y1
    cdef cnp.ndarray _Y2
    cdef void check_arrays(self) noexcept nogil

cdef class PlotShadedLine(plotElementXYY):
    cdef void draw_element(self) noexcept nogil

cdef class PlotStems(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class PlotBars(plotElementXY):
    cdef double _weight
    cdef void draw_element(self) noexcept nogil

cdef class PlotStairs(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class plotElementX(plotElementWithLegend):
    cdef cnp.ndarray _X
    cdef void check_arrays(self) noexcept nogil

cdef class PlotInfLines(plotElementX):
    cdef void draw_element(self) noexcept nogil

cdef class PlotScatter(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class DrawInPlot(plotElementWithLegend):
    cdef bint _ignore_fit
    cdef void draw(self) noexcept nogil

"""
cdef class PlotHistogram2D(plotElementXY):
    cdef void draw_element(self) noexcept nogil
"""