"""
This file is a collection of wrappers around a subset of ImGui that
are useful to do custom items in DearCyGui.

It doesn't need the user to compile or link against ImGui.

THESE FUNCTIONS SHOULD ONLY BE CALLED FROM draw() METHODS OF CUSTOM ITEMS.

Viewport Rendering Fields
-----------------------
When implementing custom drawing items, several fields from the Viewport class 
affect how coordinates and sizes are transformed:

global_scale (float):
    Current global DPI scaling factor that affects all rendering.
    Should be applied to any pixel coordinate values.
    This is already integrated automatically in the coordinate
    transform.

scales/shifts (double[2]):
    Current coordinate space transform (when not in a plot, else
    implot handles the transform).
    The helpers already include this transform.
    To apply the transform, call viewport.coordinate_to_screen.
    To reverse the transform, call viewport.screen_to_coordinate.

thickness_multiplier (float):
    Factor to apply to line thicknesses. Already includes global_scale.
    Multiply any thickness values by this. The helpers DO NOT include
    this transform.

size_multiplier (float): 
    Factor to apply to object sizes drawn in coordinate space.
    For coordinate space sizes, multiply radius by this.
    For screen space sizes, multiply radius by global_scale instead.
    The helpers DO NOT include this transform.

window_pos (Vec2):
    Position of parent window in viewport screen coordinates.

parent_pos (Vec2):
    Position of direct parent in viewport screen coordinates.
    Note the coordinate transform already takes that into account,
    and the coordinates passed are relative to the parent, and
    its transform.
"""

from .core cimport Context
from .c_types cimport Vec2, Vec4

# Drawing helpers
cdef void draw_line(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    unsigned int color, float thickness) noexcept nogil
"""
    Draw a line segment between two points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1, y1: Starting point coordinates in coordinate space
        x2, y2: Ending point coordinates in coordinate space  
        color: Line color as 32-bit RGBA value
        thickness: Line thickness in pixels
"""

cdef void draw_rect(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    unsigned int color, unsigned int fill_color,
                    float thickness, float rounding) noexcept nogil
"""
    Draw a rectangle defined by two corner points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1, y1: First corner coordinates in coordinate space
        x2, y2: Opposite corner coordinates in coordinate space
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
        rounding: Corner rounding radius in pixels
"""

cdef void draw_rect_multicolor(Context context, void* drawlist,
                              double x1, double y1, double x2, double y2,
                              unsigned int col_up_left, unsigned int col_up_right,
                              unsigned int col_bot_right, unsigned int col_bot_left) noexcept nogil
"""
    Draw a rectangle with different colors at each corner.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into  
        x1, y1: Top-left corner coordinates in coordinate space
        x2, y2: Bottom-right corner coordinates in coordinate space
        col_up_left: Color for top-left corner as 32-bit RGBA
        col_up_right: Color for top-right corner as 32-bit RGBA
        col_bot_right: Color for bottom-right corner as 32-bit RGBA
        col_bot_left: Color for bottom-left corner as 32-bit RGBA

    The colors are linearly interpolated between the corners.
"""

cdef void draw_triangle(Context context, void* drawlist,
                       double x1, double y1, double x2, double y2, double x3, double y3,
                       unsigned int color, unsigned int fill_color,
                       float thickness) noexcept nogil
"""
    Draw a triangle defined by three points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1, y1: First point coordinates in coordinate space
        x2, y2: Second point coordinates in coordinate space  
        x3, y3: Third point coordinates in coordinate space
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
"""

cdef void draw_quad(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    double x3, double y3, double x4, double y4,
                    unsigned int color, unsigned int fill_color,
                    float thickness) noexcept nogil
"""
    Draw a quadrilateral defined by four points.

    Args:
        context: The DearCyGui context 
        drawlist: ImDrawList to render into
        x1, y1: First point coordinates in coordinate space
        x2, y2: Second point coordinates in coordinate space
        x3, y3: Third point coordinates in coordinate space
        x4, y4: Fourth point coordinates in coordinate space
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels

    Points should be specified in counter-clockwise order for proper antialiasing.
"""

cdef void draw_circle(Context context, void* drawlist,
                      double x, double y, double radius,
                      unsigned int color, unsigned int fill_color,
                      float thickness, int num_segments) noexcept nogil
"""
    Draw a circle.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x, y: Center coordinates in coordinate space
        radius: Circle radius in coordinate space units
        color: Outline color as 32-bit RGBA value 
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
        num_segments: Number of segments used to approximate the circle,
                     0 for auto-calculated based on radius
"""

# When subclassing drawingItem and Draw* items, the drawlist
# is passed to the draw method. This is a helper to get the
# drawlist for the current window if subclassing uiItem.
cdef void* get_window_drawlist() noexcept nogil
"""
    Get the ImDrawList for the current window.
    
    Used by draw items that want to render into the current window.
    
    Returns:
        ImDrawList* for the current window
"""

cdef Vec2 get_cursor_pos() noexcept nogil
"""
    Get the current cursor position in the current window.
    Useful when drawing on top of subclassed UI items.
    To properly transform the coordinates, swap this
    with viewports's parent_pos before drawing,
    and restore parent_pos afterward.
"""

cdef void draw_image_quad(Context context, void* drawlist,
                         void* texture,
                         double x1, double y1, double x2, double y2,
                         double x3, double y3, double x4, double y4,
                         float u1, float v1, float u2, float v2,
                         float u3, float v3, float u4, float v4,
                         unsigned int tint_color) noexcept nogil
"""
    Draw a textured quad with custom UV coordinates.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        texture: ImTextureID to sample from
        x1,y1: First point coordinates in coordinate space 
        x2,y2: Second point coordinates in coordinate space
        x3,y3: Third point coordinates in coordinate space
        x4,y4: Fourth point coordinates in coordinate space
        u1,v1: Texture coordinates for first point (0-1 range)
        u2,v2: Texture coordinates for second point
        u3,v3: Texture coordinates for third point  
        u4,v4: Texture coordinates for fourth point
        tint_color: Color to multiply texture samples with (32-bit RGBA)
"""


cdef void draw_regular_polygon(Context context, void* drawlist,
                               double centerx, double centery,
                               double radius, double direction,  
                               int num_points,
                               unsigned int color, unsigned int fill_color,
                               float thickness) noexcept nogil
"""
    Draw a regular polygon with n points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        centerx,centery: Center coordinates in coordinate space
        radius: Circle radius that contains the points. Negative for screen space.
        direction: Angle of first point from horizontal axis
        num_points: Number of points. If 0 or 1, draws a circle.
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
"""

cdef void draw_star(Context context, void* drawlist,
                    double centerx, double centery, 
                    double radius, double inner_radius,
                    double direction, int num_points,
                    unsigned int color, unsigned int fill_color,
                    float thickness) noexcept nogil
"""
    Draw a star shaped polygon.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        centerx,centery: Center coordinates in coordinate space
        radius: Outer circle radius.
        inner_radius: Inner circle radius
        direction: Angle of first point from horizontal axis
        num_points: Number of outer points
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
"""
    
cdef void draw_text(Context context, void* drawlist,
                    double x, double y,
                    const char* text,
                    unsigned int color,
                    void* font, float size) noexcept nogil
"""
    Draw text at a position.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into  
        x,y: Text position in coordinate space
        text: Text string to draw
        color: Text color as 32-bit RGBA value
        font: ImFont* to use, NULL for default
        size: Text size. Negative is screen space, 0 for default
"""

cdef void draw_text_quad(Context context, void* drawlist,
                         double x1, double y1, double x2, double y2,  
                         double x3, double y3, double x4, double y4,
                         const char* text, unsigned int color,
                         void* font, bint preserve_ratio) noexcept nogil
"""
    Draw text deformed to fit inside a quad shape.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1,y1: top-left coordinates in coordinate space 
        x2,y2: Top-right coordinates in coordinate space
        x3,y3: bottom right coordinates in coordinate space
        x4,y4: bottom left coordinates in coordinate space
        text: Text string to draw
        color: Text color as 32-bit RGBA value. Alpha=0 to use style color.
        font: ImFont* to use, NULL for default
        preserve_ratio: Whether to maintain text aspect ratio when fitting
        
    The text is rendered as if it was an image filling a quad shape.
    The quad vertices control the deformation/orientation of the text.
"""

# Theme color indices
cdef enum ThemeCol:
    Text = 0
    TextDisabled = 1  
    WindowBg = 2
    ChildBg = 3
    PopupBg = 4
    Border = 5
    BorderShadow = 6
    FrameBg = 7
    FrameBgHovered = 8
    FrameBgActive = 9
    TitleBg = 10
    TitleBgActive = 11
    TitleBgCollapsed = 12
    MenuBarBg = 13
    ScrollbarBg = 14
    ScrollbarGrab = 15
    ScrollbarGrabHovered = 16 
    ScrollbarGrabActive = 17
    CheckMark = 18
    SliderGrab = 19
    SliderGrabActive = 20
    Button = 21
    ButtonHovered = 22
    ButtonActive = 23
    Header = 24
    HeaderHovered = 25
    HeaderActive = 26
    Separator = 27
    SeparatorHovered = 28
    SeparatorActive = 29
    ResizeGrip = 30
    ResizeGripHovered = 31
    ResizeGripActive = 32
    Tab = 33
    TabHovered = 34
    TabActive = 35
    TabUnfocused = 36
    TabUnfocusedActive = 37
    PlotLines = 38
    PlotLinesHovered = 39
    PlotHistogram = 40
    PlotHistogramHovered = 41
    TableHeaderBg = 42
    TableBorderStrong = 43
    TableBorderLight = 44
    TableRowBg = 45
    TableRowBgAlt = 46
    TextSelectedBg = 47
    DragDropTarget = 48
    NavHighlight = 49
    NavWindowingHighlight = 50
    
# Style variable indices
cdef enum StyleVar:
    Alpha = 0
    DisabledAlpha = 1
    WindowPadding = 2  
    WindowRounding = 3
    WindowBorderSize = 4
    WindowMinSize = 5
    WindowTitleAlign = 6
    ChildRounding = 7
    ChildBorderSize = 8
    PopupRounding = 9
    PopupBorderSize = 10
    FramePadding = 11
    FrameRounding = 12
    FrameBorderSize = 13
    ItemSpacing = 14
    ItemInnerSpacing = 15
    IndentSpacing = 16
    CellPadding = 17
    ScrollbarSize = 18
    ScrollbarRounding = 19
    GrabMinSize = 20
    GrabRounding = 21
    TabRounding = 22
    ButtonTextAlign = 23
    SelectableTextAlign = 24
    
# Theme functions
cdef void push_theme_color(ThemeCol idx, float r, float g, float b, float a) noexcept nogil
"""Push a theme color onto the stack (use at start of drawing code)"""

cdef void pop_theme_color() noexcept nogil
"""Pop a theme color from the stack (use at end of drawing code)"""

cdef void push_theme_style_float(StyleVar idx, float val) noexcept nogil
"""Push a float style value onto the stack"""

cdef void push_theme_style_vec2(StyleVar idx, float x, float y) noexcept nogil  
"""Push a Vec2 style value onto the stack"""

cdef void pop_theme_style() noexcept nogil
"""Pop a style value from the stack"""

cdef Vec4 get_theme_color(ThemeCol idx) noexcept nogil
"""
Retrieve the current theme color for a target idx.

Args:
    idx: ThemeCol index to query

Returns:
    Vec4 containing RGBA color values
"""

# Text measurement functions
cdef Vec2 calc_text_size(const char* text, void* font, float size, float wrap_width) noexcept nogil
"""
Calculate text size in screen coordinates.

Args:
    text: Text string to measure
    font: ImFont* to use, NULL for default 
    size: Text size, 0 for default, negative for screen space
    wrap_width: Width to wrap text at, 0 for no wrap

Returns:
    Vec2 containing width and height in pixels
"""

cdef struct GlyphInfo:
    float advance_x     # Distance to advance cursor after rendering (in pixels)
    float size_x       # Glyph width in pixels 
    float size_y       # Glyph height in pixels
    float u0, v0       # Texture coordinates for top-left
    float u1, v1       # Texture coordinates for bottom-right
    float offset_x     # Horizontal offset from cursor position
    float offset_y     # Vertical offset from cursor position
    bint visible       # True if glyph has a visible bitmap
    
cdef GlyphInfo get_glyph_info(void* font, unsigned int codepoint) noexcept nogil
"""
Get rendering information for a Unicode codepoint.

Args:
    codepoint: Unicode codepoint value
    font: ImFont* to query, NULL for default font

Returns:  
    GlyphInfo struct containing metrics and texture coords
"""

