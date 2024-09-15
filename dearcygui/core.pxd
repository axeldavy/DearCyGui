from dearcygui.wrapper cimport imgui, implot, imnodes, float4
from dearcygui.backends.backend cimport mvViewport, mvGraphics
from libc.time cimport tm
from libcpp.string cimport string
from libcpp cimport bool
from dearcygui.wrapper.mutex cimport recursive_mutex
from libcpp.atomic cimport atomic
from libcpp.vector cimport vector
cimport numpy as cnp

"""
Thread safety:
. The gil must be held whenever a cdef class or Python object
  is allocated/deallocated or assigned. The Cython compiler will
  ensure this. Note that Python might free the gil while we are
  executing to let other threads use it.
. All items are organized in a tree structure. All items are assigned
  a mutex. Whenever the tree structure is going to be edited,
  the parent node must have the mutex lock first and foremost.
  Then the item mutex (unless the item is being inserted, in which
  case the item mutex is held first)
. Whenever access to item fields need to be done atomically, the item
  mutex must be held. Similarly field edition must hold the mutex.

During rendering of an item, the mutex of all its parent is held.
Thus we can safely edit the tree structure in another thread (if we have
managed to lock the relevant mutexes) while rendering is performed.

. As imgui is not thread-safe, all imgui calls are protected by a mutex.
  To prevent dead-locks, the imgui mutex must be locked first before any
  item/parent mutex. Alternatively, one can release its mutexes before
  locking the imgui mutex, to then lock again its previous mutexes.
"""

cdef class dcgViewport:
    cdef recursive_mutex mutex
    cdef mvViewport *viewport
    cdef dcgContext context
    cdef public dcgCallback resize_callback
    cdef public dcgCallback close_callback
    cdef bint initialized
    cdef mvGraphics graphics
    cdef bint graphics_initialized
    # linked list to objects without parents to draw with their children
    # The entry point corresponds to the last item of the list (draw last)
    cdef baseItem colormapRoots
    cdef baseItem filedialogRoots
    cdef baseItem viewportMenubarRoots
    cdef dcgWindow_ last_window_child
    cdef baseTheme bound_theme
    cdef globalHandler last_global_handler_child
    cdef dcgViewportDrawList_ last_viewport_drawlist_child
    # Temporary info to be accessed during rendering
    # Shouldn't be accessed outside draw()
    cdef bint perspectiveDivide
    cdef bint depthClipping
    cdef float[6] clipViewport
    cdef bint has_matrix_transform
    cdef float[4][4] transform
    cdef bint in_plot
    cdef float thickness_multiplier # in plots
    cdef int start_pending_theme_actions # managed outside viewport
    cdef vector[theme_action] pending_theme_actions # managed outside viewport
    cdef vector[theme_action] applied_theme_actions # managed by viewport
    cdef vector[int] applied_theme_actions_count # managed by viewport
    cdef int current_theme_activation_condition_enabled
    cdef int current_theme_activation_condition_category

    cdef initialize(self, unsigned width, unsigned height)
    cdef void __check_initialized(self)
    cdef void __on_resize(self, int width, int height)
    cdef void __on_close(self)
    cdef void __render(self) noexcept nogil
    cdef void apply_current_transform(self, float *dst_p, float[4] src_p, float dx, float dy) noexcept nogil
    cdef void push_pending_theme_actions(self, int, int) noexcept nogil
    cdef void push_pending_theme_actions_on_subset(self, int, int) noexcept nogil
    cdef void pop_applied_pending_theme_actions(self) noexcept nogil


cdef class dcgCallback:
    cdef object callback
    cdef int num_args
    cdef object user_data

cdef class dcgContext:
    cdef recursive_mutex mutex
    cdef atomic[long long] next_uuid
    cdef bint waitOneFrame
    cdef bint started
    # Mutex that must be held for any
    # call to imgui, glfw, etc
    cdef recursive_mutex imgui_mutex
    cdef float deltaTime # time since last frame
    cdef double time # total time since starting
    cdef int frame # frame count
    cdef int framerate # frame rate
    cdef public dcgViewport viewport
    cdef imgui.ImGuiContext* imgui_context
    cdef implot.ImPlotContext* implot_context
    cdef imnodes.ImNodesContext* imnodes_context
    #cdef dcgGraphics graphics
    cdef bint resetTheme
    #cdef dcgIO IO
    #cdef dcgItemRegistry itemRegistry
    #cdef dcgCallbackRegistry callbackRegistry
    #cdef dcgToolManager toolManager
    #cdef dcgInput input
    #cdef UUID activeWindow
    #cdef UUID focusedItem
    cdef dcgCallback on_close_callback
    cdef public object on_frame_callbacks
    cdef object queue
    cdef void queue_callback_noarg(self, dcgCallback, object) noexcept nogil
    cdef void queue_callback_arg1int(self, dcgCallback, object, int) noexcept nogil
    cdef void queue_callback_arg1float(self, dcgCallback, object, float) noexcept nogil
    cdef void queue_callback_arg1int1float(self, dcgCallback, object, int, float) noexcept nogil
    cdef void queue_callback_arg2float(self, dcgCallback, object, float, float) noexcept nogil
    cdef void queue_callback_arg1int2float(self, dcgCallback, object, int, float, float) noexcept nogil

"""
Each .so has its own current context. To be able to work
with various .so and contexts, we must ensure the correct
context is current. The call is almost free as it's just
a pointer that is set.
If you create your own custom rendering objects, you must ensure
that you link to the same version of ImGui (ImPlot/ImNodes if
applicable) and you must call ensure_correct_* at the start
of your draw() overrides
"""
cdef inline void ensure_correct_imgui_context(dcgContext context):
    imgui.SetCurrentContext(context.imgui_context)

cdef inline void ensure_correct_implot_context(dcgContext context):
    implot.SetCurrentContext(context.implot_context)

cdef inline void ensure_correct_imnodes_context(dcgContext context):
    imnodes.SetCurrentContext(context.imnodes_context)

cdef inline void ensure_correct_im_context(dcgContext context):
    ensure_correct_imgui_context(context)
    ensure_correct_implot_context(context)
    ensure_correct_imnodes_context(context)

"""
Main item types
"""

"""
baseItem:
An item that can be inserted in a tree structure.
It is inserted in a tree, attached with be set to True
In the case the parent is either another baseItem or the viewport (top of the tree)

A parent only points to the last children of the list of its children,
for the four main children categories.

A child then points to its previous and next sibling of its category
"""
cdef class baseItem:
    cdef recursive_mutex mutex
    cdef dcgContext context
    cdef long long uuid
    cdef string internalLabel
    # Attributes set by subclasses
    # to indicate what kind of parent
    # and children they can have.
    # Allowed children:
    cdef bint can_have_0_child
    cdef bint can_have_widget_child
    cdef bint can_have_drawing_child
    cdef bint can_have_payload_child
    # DOES NOT mean "bound" to an item
    cdef bint can_have_global_handler_child
    cdef bint can_have_item_handler_child
    cdef bint can_have_theme_child
    # Allowed siblings:
    cdef bint can_have_sibling
    # Allowed parents
    cdef bint can_have_viewport_parent
    cdef bint can_have_nonviewport_parent
    # Type of child for the parent
    cdef int element_child_category
    cdef int element_toplevel_category

    # Relationships
    cdef bint attached
    cdef baseItem parent
    # It is not possible to access an array of children without the gil
    # Thus instead use a list
    # Each element is responsible for calling draw on its sibling
    cdef baseItem prev_sibling
    cdef baseItem next_sibling
    cdef drawableItem last_0_child #  mvFileExtension, mvFontRangeHint, mvNodeLink, mvAnnotation, mvAxisTag, mvDragLine, mvDragPoint, mvDragRect, mvLegend, mvTableColumn
    cdef uiItem last_widgets_child
    cdef drawableItem last_drawings_child
    cdef baseItem last_payloads_child
    cdef globalHandler last_global_handler_child
    cdef itemHandler last_item_handler_child
    cdef baseTheme last_theme_child
    cdef void lock_parent_and_item_mutex(self) noexcept nogil
    cdef void unlock_parent_mutex(self) noexcept nogil
    cpdef void attach_to_parent(self, baseItem target_parent)
    cpdef void attach_before(self, baseItem target_before)
    cdef void __detach_item_and_lock(self)
    cpdef void detach_item(self)
    cpdef void delete_item(self)
    cdef void __delete_and_siblings(self)

"""
drawable item:
A baseItem which can be drawn and has a show state
"""

cdef class drawableItem(baseItem):
    cdef bool show
    cdef void draw_prev_siblings(self, imgui.ImDrawList*, float, float) noexcept nogil
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

"""
Drawing Items
"""

cdef class drawingItem(drawableItem):
    pass

cdef class dcgDrawList_(drawingItem):
    cdef float clip_width
    cdef float clip_height
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgViewportDrawList_(drawingItem):
    cdef bool front
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawLayer_(drawingItem):
    # mvAppItemDrawInfo
    cdef long cullMode
    cdef bint perspectiveDivide
    cdef bint depthClipping
    cdef float[6] clipViewport
    cdef bint has_matrix_transform
    cdef float[4][4] transform
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

# Draw Node ? Seems to be exactly like Drawlayer, but with only
# the matrix settable (via apply_transform). -> merge to drawlayer

cdef class dcgDrawArrow_(drawingItem):
    cdef float[4] start
    cdef float[4] end
    cdef float[4] corner1
    cdef float[4] corner2
    cdef imgui.ImU32 color
    cdef float thickness
    cdef float size
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil
    cdef void __compute_tip(self)

cdef class dcgDrawBezierCubic_(drawingItem):
    cdef float[4] p1
    cdef float[4] p2
    cdef float[4] p3
    cdef float[4] p4
    cdef imgui.ImU32 color
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawBezierQuadratic_(drawingItem):
    cdef float[4] p1
    cdef float[4] p2
    cdef float[4] p3
    cdef imgui.ImU32 color
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawCircle_(drawingItem):
    cdef float[4] center
    cdef float radius
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawEllipse_(drawingItem):
    cdef float[4] pmin
    cdef float[4] pmax
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int segments
    cdef vector[float4] points
    cdef void __fill_points(self)
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawImage_(drawingItem):
    cdef float[4] pmin
    cdef float[4] pmax
    cdef float[4] uv
    cdef imgui.ImU32 color_multiplier
    cdef dcgTexture_ texture
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawImageQuad_(drawingItem):
    cdef float[4] p1
    cdef float[4] p2
    cdef float[4] p3
    cdef float[4] p4
    cdef float[4] pmax
    cdef float[4] uv1
    cdef float[4] uv2
    cdef float[4] uv3
    cdef float[4] uv4
    cdef imgui.ImU32 color_multiplier
    cdef dcgTexture_ texture
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawLine_(drawingItem):
    cdef float[4] p1
    cdef float[4] p2
    cdef imgui.ImU32 color
    cdef float thickness
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawPolyline_(drawingItem):
    cdef imgui.ImU32 color
    cdef float thickness
    cdef bint closed
    cdef vector[float4] points
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawPolygon_(drawingItem):
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef vector[float4] points
    cdef int[:,:] triangulation_indices
    cdef void __triangulate(self)
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawQuad_(drawingItem):
    cdef float[4] p1
    cdef float[4] p2
    cdef float[4] p3
    cdef float[4] p4
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawRect_(drawingItem):
    cdef float[4] pmin
    cdef float[4] pmax
    cdef imgui.ImU32 color
    cdef imgui.ImU32 color_upper_left
    cdef imgui.ImU32 color_upper_right
    cdef imgui.ImU32 color_bottom_left
    cdef imgui.ImU32 color_bottom_right
    cdef imgui.ImU32 fill
    cdef float rounding
    cdef float thickness
    cdef bint multicolor
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dgcDrawText_(drawingItem):
    cdef float[4] pos
    cdef string text
    cdef imgui.ImU32 color
    cdef float size
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

cdef class dcgDrawTriangle_(drawingItem):
    cdef float[4] p1
    cdef float[4] p2
    cdef float[4] p3
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int cull_mode
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil


cdef class globalHandler(baseItem):
    cdef bint enabled
    cdef dcgCallback callback
    cdef void run_handler(self) noexcept nogil
    cdef void run_callback(self) noexcept nogil

cdef class dcgGlobalHandlerList(globalHandler):
    cdef void run_handler(self) noexcept nogil

cdef class dcgKeyDownHandler_(globalHandler):
    cdef int key
    cdef void run_handler(self) noexcept nogil

cdef class dcgKeyPressHandler_(globalHandler):
    cdef int key
    cdef bint repeat
    cdef void run_handler(self) noexcept nogil

cdef class dcgKeyReleaseHandler_(globalHandler):
    cdef int key
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseClickHandler_(globalHandler):
    cdef int button
    cdef bint repeat
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseDoubleClickHandler_(globalHandler):
    cdef int button
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseDownHandler_(globalHandler):
    cdef int button
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseDragHandler_(globalHandler):
    cdef int button
    cdef float threshold
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseMoveHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseReleaseHandler_(globalHandler):
    cdef int button
    cdef void run_handler(self) noexcept nogil

cdef class dcgMouseWheelHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil

"""
Shared values (sources)

Should we use cdef recursive_mutex mutex ?
"""
cdef class shared_bool:
    cdef bint _value
    # Internal functions.
    # python uses get_value and set_value
    cdef bint get(self) noexcept nogil
    cdef void set(self, bint) noexcept nogil

cdef class shared_float:
    cdef float _value
    cdef float get(self) noexcept nogil
    cdef void set(self, float) noexcept nogil

cdef class shared_int:
    cdef int _value
    cdef int get(self) noexcept nogil
    cdef void set(self, int) noexcept nogil

cdef class shared_color:
    cdef imgui.ImU32 _value
    cdef imgui.ImVec4 _value_asfloat4
    cdef imgui.ImU32 getU32(self) noexcept nogil
    cdef imgui.ImVec4 getF4(self) noexcept nogil
    cdef void setU32(self, imgui.ImU32) noexcept nogil
    cdef void setF4(self, imgui.ImVec4) noexcept nogil

cdef class shared_double:
    cdef double _value
    cdef double get(self) noexcept nogil
    cdef void set(self, double) noexcept nogil

cdef class shared_str:
    cdef string _value
    cdef string get(self) noexcept nogil
    cdef void set(self, string) noexcept nogil

cdef class shared_float4:
    cdef float[4] _value
    cdef void get(self, float *) noexcept nogil# cython does support float[4] as return value
    cdef void set(self, float[4]) noexcept nogil

cdef class shared_int4:
    cdef int[4] _value
    cdef void get(self, int *) noexcept nogil
    cdef void set(self, int[4]) noexcept nogil

cdef class shared_double4:
    cdef double[4] _value
    cdef void get(self, double *) noexcept nogil
    cdef void set(self, double[4]) noexcept nogil

"""
cdef class shared_floatvect:
    cdef float[:] _value
    cdef float[:] get(self) noexcept nogil
    cdef void set(self, float[:]) noexcept nogil

cdef class shared_doublevect:
    cdef double[:] _value
    cdef double[:] get(self) noexcept nogil
    cdef void set(self, double[:]) noexcept nogil

cdef class shared_time:
    cdef tm _value
    cdef tm get(self) noexcept nogil
    cdef void set(self, tm) noexcept nogil
"""

# TODO: uuid

"""
UI item
A drawable item with various UI states
"""

cdef struct itemState:
    bint can_be_active
    bint can_be_activated
    bint can_be_clicked
    bint can_be_deactivated
    bint can_be_deactivated_after_edited
    bint can_be_edited
    bint can_be_focused
    bint can_be_hovered
    bint can_be_toggled
    bint has_rect_min
    bint has_rect_max
    bint has_rect_size
    bint has_content_region
    bint hovered
    bint active
    bint focused
    bint[<int>imgui.ImGuiMouseButton_COUNT] clicked
    bint[<int>imgui.ImGuiMouseButton_COUNT] double_clicked
    bint edited
    bint activated
    bint deactivated
    bint deactivated_after_edited
    bint toggled
    bint resized
    imgui.ImVec2 rect_min
    imgui.ImVec2 rect_max
    imgui.ImVec2 rect_size
    imgui.ImVec2 content_region
    # Item: indicates if the item was in the clipped region of the window
    # Window: indicates if the window was rendered
    bint visible
    # relative position to the parent window or the viewport if a window
    imgui.ImVec2 relative_position

cdef class itemHandler(baseItem):
    cdef bint enabled
    cdef dcgCallback callback
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil
    cdef void run_callback(self, uiItem) noexcept nogil

cdef class dcgItemHandlerList(itemHandler):
    cdef void check_bind(self, uiItem)
    cdef void run_handler(self, uiItem) noexcept nogil

cdef class uiItem(drawableItem):
    # mvAppItemInfo
    #cdef int location -> for table
    #cdef bint enabled -> 
    #cdef bint enabled_update_requested -> for editable fields
    # mvAppItemState
    cdef itemState state
    cdef bint focus_update_requested
    cdef bint show_update_requested
    cdef bint size_update_requested
    cdef bint pos_update_requested
    cdef int last_frame_update
    # mvAppItemConfig
    #cdef long long source -> data source. To move
    #cdef string specifiedLabel
    #cdef string filter -> to move
    cdef string alias
    cdef string payloadType
    cdef int width
    cdef int height
    cdef float indent
    #cdef float trackOffset
    cdef bint useInternalLabel
    #cdef bint tracked
    #cdef object callback
    #cdef object user_data
    cdef dcgCallback dragCallback
    cdef dcgCallback dropCallback
    cdef itemHandler handlers

    cdef void propagate_hidden_state_to_children(self) noexcept nogil
    cdef void set_hidden_and_propagate(self) noexcept nogil
    cdef object output_current_item_state(self)
    cdef void update_current_state(self) noexcept nogil
    cdef void update_current_state_as_hidden(self) noexcept nogil

cdef class dcgWindow_(uiItem):
    cdef imgui.ImGuiWindowFlags window_flags
    cdef bint main_window
    cdef bint resized
    cdef bint modal
    cdef bint popup
    #cdef bint autosize
    cdef bint no_resize
    cdef bint no_title_bar
    cdef bint no_move
    cdef bint no_scrollbar
    cdef bint no_collapse
    cdef bint horizontal_scrollbar
    cdef bint no_focus_on_appearing
    cdef bint no_bring_to_front_on_focus
    cdef bint menubar
    cdef bint has_close_button
    cdef bint no_background
    cdef bint collapsed
    cdef bint no_open_over_existing_popup
    cdef dcgCallback on_close_callback
    cdef imgui.ImVec2 min_size
    cdef imgui.ImVec2 max_size
    cdef float scroll_x
    cdef float scroll_y
    cdef float scroll_max_x
    cdef float scroll_max_y
    cdef bint collapse_update_requested
    cdef bint scroll_x_update_requested
    cdef bint scroll_y_update_requested
    cdef imgui.ImGuiWindowFlags backup_window_flags
    cdef imgui.ImVec2 backup_pos
    cdef imgui.ImVec2 backup_rect_size
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil

"""
Bindable elements
"""

cdef class dcgTexture_(baseItem):
    cdef recursive_mutex write_mutex
    cdef bint hint_dynamic
    cdef bint dynamic
    cdef void* allocated_texture
    cdef int width
    cdef int height
    cdef int num_chans
    cdef int filtering_mode
    cdef void set_content(self, cnp.ndarray content)

cdef int theme_type_color = 0
cdef int theme_type_style = 1
cdef int theme_category_imgui = 0
cdef int theme_category_implot = 1
cdef int theme_category_imnodes = 2

cdef int theme_activation_condition_enabled_any = 0
cdef int theme_activation_condition_enabled_False = 1
cdef int theme_activation_condition_enabled_True = 2
cdef int theme_activation_condition_category_any = 0
cdef int theme_activation_condition_category_window = 1

cdef int theme_value_type_int = 0
cdef int theme_value_type_float = 1
cdef int theme_value_type_float2 = 2
cdef int theme_value_type_u32 = 3

ctypedef union theme_value:
    int value_int
    float value_float
    float[2] value_float2
    unsigned value_u32

ctypedef struct theme_action:
    int theme_activation_condition_enabled
    int theme_activation_condition_category
    int theme_type
    int theme_category
    int theme_index
    int theme_value_type
    theme_value value

"""
Theme base class:
push: push the item components of the theme
pop: pop the item components of the theme
last_push_size is used internally during rendering
to know the size of what we pushed.
Indeed the user might add/remove elements while
we render.
push_to_list: Used to prepare in advance a push.
In that case the caller handles the pops
"""

cdef class baseTheme(baseItem):
    cdef bint enabled
    cdef vector[int] last_push_size
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

"""
Utils that the other pyx may use
"""
cdef imgui.ImU32 imgui_ColorConvertFloat4ToU32(imgui.ImVec4) noexcept nogil
cdef imgui.ImVec4 imgui_ColorConvertU32ToFloat4(imgui.ImU32) noexcept nogil
cdef const char* imgui_GetStyleColorName(int) noexcept nogil
cdef void imgui_PushStyleColor(int, imgui.ImU32) noexcept nogil
cdef void imgui_PopStyleColor(int) noexcept nogil
cdef void imnodes_PushStyleColor(int, imgui.ImU32) noexcept nogil
cdef void imnodes_PopStyleColor(int) noexcept nogil
cdef const char* implot_GetStyleColorName(int) noexcept nogil
cdef void implot_PushStyleColor(int, imgui.ImU32) noexcept nogil
cdef void implot_PopStyleColor(int) noexcept nogil
cdef void imgui_PushStyleVar1(int i, float val) noexcept nogil
cdef void imgui_PushStyleVar2(int i, imgui.ImVec2 val) noexcept nogil
cdef void imgui_PopStyleVar(int count) noexcept nogil
cdef void implot_PushStyleVar0(int i, int val) noexcept nogil
cdef void implot_PushStyleVar1(int i, float val) noexcept nogil
cdef void implot_PushStyleVar2(int i, imgui.ImVec2 val) noexcept nogil
cdef void implot_PopStyleVar(int count) noexcept nogil
cdef void imnodes_PushStyleVar1(int i, float val) noexcept nogil
cdef void imnodes_PushStyleVar2(int i, imgui.ImVec2 val) noexcept nogil
cdef void imnodes_PopStyleVar(int count) noexcept nogil

ctypedef fused point_type:
    int
    float
    double

cdef inline void read_point(point_type* dst, src):
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