from dearcygui.wrapper cimport imgui, implot

cdef enum child_type:
    cat_drawing
    cat_handler
    cat_menubar
    cat_plot_element
    cat_tab
    cat_theme
    cat_viewport_drawlist
    cat_widget
    cat_window

cpdef enum class HandlerListOP:
    ALL,
    ANY,
    NONE

cpdef enum class MouseButton:
    LEFT = 0,
    RIGHT = 1,
    MIDDLE = 2,
    X1 = 3,
    X2 = 4

cpdef enum class MouseButtonMask:
    NOBUTTON = 0,
    LEFT = 1,
    RIGHT = 2,
    LEFTRIGHT = 3,
    MIDDLE = 4,
    LEFTMIDDLE = 5,
    MIDDLERIGHT = 6,
    ANY = 7
#    X1 = 8
#    X2 = 16,
#    ANY = 31


cpdef enum class MouseCursor:
    CursorNone = -1,
    CursorArrow = 0,
    CursorTextInput,         # When hovering over InputText, etc.
    ResizeAll,         # (Unused by Dear ImGui functions)
    ResizeNS,          # When hovering over a horizontal border
    ResizeEW,          # When hovering over a vertical border or a column
    ResizeNESW,        # When hovering over the bottom-left corner of a window
    ResizeNWSE,        # When hovering over the bottom-right corner of a window
    Hand,              # (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
    NotAllowed

cpdef enum class Positioning:
    DEFAULT,
    REL_DEFAULT,
    REL_PARENT,
    REL_WINDOW,
    REL_VIEWPORT

cpdef enum class Alignment:
    LEFT=0,
    TOP=0,
    RIGHT=1,
    BOTTOM=1,
    CENTER=2,
    JUSTIFIED=3,
    MANUAL=4

cpdef enum class ButtonDirection:
    NONE = imgui.ImGuiDir_None,
    LEFT = imgui.ImGuiDir_Left,
    RIGHT = imgui.ImGuiDir_Right,
    UP = imgui.ImGuiDir_Up,
    DOWN = imgui.ImGuiDir_Down

cdef enum theme_types:
    t_color,
    t_style

cdef enum theme_backends:
    t_imgui,
    t_implot,
    t_imnodes

cpdef enum class ThemeEnablers:
    ANY,
    FALSE,
    TRUE,
    DISCARDED

cpdef enum class ThemeCategories:
    t_any,
    t_simpleplot,
    t_button,
    t_combo,
    t_checkbox,
    t_slider,
    t_listbox,
    t_radiobutton,
    t_inputtext,
    t_inputvalue,
    t_text,
    t_selectable,
    t_tab,
    t_tabbar,
    t_tabbutton,
    t_menuitem,
    t_progressbar,
    t_image,
    t_imagebutton,
    t_menubar,
    t_menu,
    t_tooltip,
    t_layout,
    t_treenode,
    t_collapsingheader,
    t_child,
    t_colorbutton,
    t_coloredit,
    t_colorpicker,
    t_window,
    t_plot

cdef enum theme_value_float2_mask:
    t_full,
    t_left,
    t_right

cdef enum theme_value_types:
    t_int,
    t_float,
    t_float2,
    t_u32

ctypedef union theme_value:
    int value_int
    float value_float
    float[2] value_float2
    unsigned value_u32

ctypedef struct theme_action:
    ThemeEnablers activation_condition_enabled
    ThemeCategories activation_condition_category
    theme_types type
    theme_backends backend
    int theme_index
    theme_value_types value_type
    theme_value value
    theme_value_float2_mask float2_mask

ctypedef fused point_type:
    int
    float
    double

cpdef enum class AxisScale:
    LINEAR=implot.ImPlotScale_Linear
    TIME=implot.ImPlotScale_Time
    LOG10=implot.ImPlotScale_Log10
    SYMLOG=implot.ImPlotScale_SymLog

cpdef enum class Axis:
    X1=implot.ImAxis_X1
    X2=implot.ImAxis_X2
    X3=implot.ImAxis_X3
    Y1=implot.ImAxis_Y1
    Y2=implot.ImAxis_Y2
    Y3=implot.ImAxis_Y3

cpdef enum class LegendLocation:
    CENTER=implot.ImPlotLocation_Center
    NORTH=implot.ImPlotLocation_Center
    SOUTH=implot.ImPlotLocation_Center
    WEST=implot.ImPlotLocation_Center
    EAST=implot.ImPlotLocation_Center
    NORTHWEST=implot.ImPlotLocation_NorthWest
    NORTHEAST=implot.ImPlotLocation_NorthEast
    SOUTHWEST=implot.ImPlotLocation_SouthWest
    SOUTHEAST=implot.ImPlotLocation_SouthEast

cdef imgui.ImU32 imgui_ColorConvertFloat4ToU32(imgui.ImVec4) noexcept nogil
cdef imgui.ImVec4 imgui_ColorConvertU32ToFloat4(imgui.ImU32) noexcept nogil

cdef class Coord:
    cdef double _x
    cdef double _y
    @staticmethod
    cdef Coord build(double[2] &coord)
    @staticmethod
    cdef Coord build_v(imgui.ImVec2 &coord)

cdef class Rect:
    cdef double _x1
    cdef double _y1
    cdef double _x2
    cdef double _y2
    @staticmethod
    cdef Rect build(double[4] &rect)

cdef inline void read_point(point_type* dst, src):
    if not(hasattr(src, '__len__')):
        raise TypeError("Point data must be an array of up to 2 coordinates")
    cdef int src_size = len(src)
    if src_size > 2:
        raise TypeError("Point data must be an array of up to 2 coordinates")
    dst[0] = <point_type>0.
    dst[1] = <point_type>0.
    if src_size > 0:
        dst[0] = <point_type>src[0]
    if src_size > 1:
        dst[1] = <point_type>src[1]

cdef inline void read_coord(double* dst, src):
    if isinstance(src, Coord):
        dst[0] = (<Coord>src)._x
        dst[1] = (<Coord>src)._y
    else:
        read_point[double](dst, src)

cdef inline void read_rect(double* dst, src):
    if isinstance(src, Rect):
        dst[0] = (<Rect>src)._x1
        dst[1] = (<Rect>src)._y1
        dst[2] = (<Rect>src)._x2
        dst[3] = (<Rect>src)._y2
        return
    try:
        if isinstance(src, tuple) and len(src) == 2 and \
            hasattr(src[0], "__len__") and hasattr(src[1], "__len__"):
            read_coord(dst, src[0])
            read_coord(dst + 2, src[1])
        else:
            read_vec4[double](dst, src)
    except TypeError:
        raise TypeError("Rect data must be a tuple of two points or an array of up to 4 coordinates")

cdef inline void read_vec4(point_type* dst, src):
    if not(hasattr(src, '__len__')):
        raise TypeError("Point data must be an array of up to 4 coordinates")
    cdef int src_size = len(src)
    if src_size > 4:
        raise TypeError("Point data must be an array of up to 4 coordinates")
    dst[0] = <point_type>0.
    dst[1] = <point_type>0.
    dst[2] = <point_type>0.
    dst[3] = <point_type>0.
    if src_size > 0:
        dst[0] = <point_type>src[0]
    if src_size > 1:
        dst[1] = <point_type>src[1]
    if src_size > 2:
        dst[2] = <point_type>src[2]
    if src_size > 3:
        dst[3] = <point_type>src[3]

cdef inline imgui.ImU32 parse_color(src):
    if isinstance(src, int):
        # RGBA, little endian
        return <imgui.ImU32>(<long long>src)
    cdef int src_size = 5 # to trigger error by default
    if hasattr(src, '__len__'):
        src_size = len(src)
    if src_size == 0 or src_size > 4:
        raise TypeError("Color data must either an int32 (rgba, little endian),\n" \
                        "or an array of int (r, g, b, a) or float (r, g, b, a) normalized")
    cdef imgui.ImVec4 color_float4
    cdef imgui.ImU32 color_u32
    cdef bint contains_nonints = False
    cdef int i
    cdef float[4] values
    cdef int[4] values_int

    for i in range(src_size):
        element = src[i]
        if not(isinstance(element, int)):
            contains_nonints = True
            values[i] = element
            values_int[i] = <int>values[i]
        else:
            values_int[i] = element
            values[i] = <float>values_int[i]
    for i in range(src_size, 4):
        values[i] = 1.
        values_int[i] = 255

    if not(contains_nonints):
        for i in range(4):
            if values_int[i] < 0 or values_int[i] > 255:
                raise ValueError("Color value component outside bounds (0...255)")
        color_u32 = <imgui.ImU32>values_int[0]
        color_u32 |= (<imgui.ImU32>values_int[1]) << 8
        color_u32 |= (<imgui.ImU32>values_int[2]) << 16
        color_u32 |= (<imgui.ImU32>values_int[3]) << 24
        return color_u32

    for i in range(4):
        if values[i] < 0. or values[i] > 1.:
            raise ValueError("Color value component outside bounds (0...1)")

    color_float4.x = values[0]
    color_float4.y = values[1]
    color_float4.z = values[2]
    color_float4.w = values[3]
    return imgui_ColorConvertFloat4ToU32(color_float4)

cdef inline void unparse_color(float *dst, imgui.ImU32 color_uint) noexcept nogil:
    cdef imgui.ImVec4 color_float4 = imgui_ColorConvertU32ToFloat4(color_uint)
    dst[0] = color_float4.x
    dst[1] = color_float4.y
    dst[2] = color_float4.z
    dst[3] = color_float4.w