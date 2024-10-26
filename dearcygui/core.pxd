from dearcygui.wrapper cimport imgui, implot, imnodes, double4
from dearcygui.backends.backend cimport mvViewport, mvGraphics
from libc.time cimport tm
from libcpp.string cimport string
from libcpp cimport bool
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock, defer_lock_t
from libcpp.atomic cimport atomic
from libcpp.map cimport map
from libcpp.vector cimport vector
from cpython.ref cimport PyObject
cimport numpy as cnp

"""
Thread safety:
. The gil must be held whenever a cdef class or Python object
  is allocated/deallocated or assigned. The Cython compiler will
  ensure this. Note that Python might free the gil while we are
  executing to let other threads use it.
. All items are organized in a tree structure. All items are assigned
  a mutex.
. Whenever access to item fields need to be done atomically, the item
  mutex must be held. Item edition must always hold the mutex.
. Whenever the tree structure is going to be edited,
  the parent node must have the mutex lock first and foremost.
  Then the item mutex (unless the item is being inserted, in which
  case the item mutex is held first). As a result when a parent
  mutex is held, the children are fixed (but not their individual
  states).
. During rendering of an item, the mutex of all its parent is held.
  Thus we can safely edit the tree structure in another thread (if we have
  managed to lock the relevant mutexes) while rendering is performed.
. An item cannot hold the lock of its neighboring children unless
  the parent mutex is already held. If there is no parent, the viewport
  mutex is held.
. As imgui is not thread-safe, all imgui calls are protected by a mutex.
  To prevent dead-locks, the imgui mutex must be locked first before any
  item/parent mutex. During rendering, the mutex is held.
"""

cdef void lock_gil_friendly_block(unique_lock[recursive_mutex] &m) noexcept

cdef inline void lock_gil_friendly(unique_lock[recursive_mutex] &m,
                                   recursive_mutex &mutex) noexcept:
    """
    Must be called to lock our mutexes whenever we hold the gil
    """
    m = unique_lock[recursive_mutex](mutex, defer_lock_t())
    # Fast path which will be hit almost always
    if m.try_lock():
        return
    # Slow path
    lock_gil_friendly_block(m)

cdef class Context:
    cdef recursive_mutex mutex
    cdef atomic[long long] next_uuid
    cdef object items # weakref.WeakValueDictionary
    cdef dict[str, long long] tag_to_uuid
    cdef dict[long long, str] uuid_to_tag
    cdef object threadlocal_data
    cdef bint waitOneFrame
    cdef bint started
    # Mutex that must be held for any
    # call to imgui, glfw, etc
    cdef recursive_mutex imgui_mutex
    cdef Viewport _viewport
    cdef imgui.ImGuiContext* imgui_context
    cdef implot.ImPlotContext* implot_context
    cdef imnodes.ImNodesContext* imnodes_context
    #cdef Graphics graphics
    cdef bint resetTheme
    #cdef IO IO
    #cdef ItemRegistry itemRegistry
    #cdef CallbackRegistry callbackRegistry
    #cdef ToolManager toolManager
    #cdef Input input
    #cdef UUID activeWindow
    #cdef UUID focusedItem
    cdef Callback on_close_callback
    cdef object queue
    cdef void queue_callback_noarg(self, Callback, baseItem, baseItem) noexcept nogil
    cdef void queue_callback_arg1obj(self, Callback, baseItem, baseItem, baseItem) noexcept nogil
    cdef void queue_callback_arg1int(self, Callback, baseItem, baseItem, int) noexcept nogil
    cdef void queue_callback_arg1float(self, Callback, baseItem, baseItem, float) noexcept nogil
    cdef void queue_callback_arg1value(self, Callback, baseItem, baseItem, SharedValue) noexcept nogil
    cdef void queue_callback_arg1int1float(self, Callback, baseItem, baseItem, int, float) noexcept nogil
    cdef void queue_callback_arg2float(self, Callback, baseItem, baseItem, float, float) noexcept nogil
    cdef void queue_callback_arg2double(self, Callback, baseItem, baseItem, double, double) noexcept nogil
    cdef void queue_callback_arg1int2float(self, Callback, baseItem, baseItem, int, float, float) noexcept nogil
    cdef void queue_callback_arg4int(self, Callback, baseItem, baseItem, int, int, int, int) noexcept nogil
    cdef void queue_callback_arg3long1int(self, Callback, baseItem, baseItem, long long, long long, long long, int) noexcept nogil
    cdef void queue_callback_argdoubletriplet(self, Callback, baseItem, baseItem, double, double, double, double, double, double) noexcept nogil
    cdef void register_item(self, baseItem o, long long uuid)
    cdef void update_registered_item_tag(self, baseItem o, long long uuid, str tag)
    cdef void unregister_item(self, long long uuid)
    cdef baseItem get_registered_item_from_uuid(self, long long uuid)
    cdef baseItem get_registered_item_from_tag(self, str tag)
    cpdef void push_next_parent(self, baseItem next_parent)
    cpdef void pop_next_parent(self)
    cpdef object fetch_parent_queue_back(self)
    cpdef object fetch_parent_queue_front(self)
    cpdef object fetch_last_created_item(self)
    cpdef object fetch_last_created_container(self)

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
cdef inline void ensure_correct_imgui_context(Context context) noexcept nogil:
    imgui.SetCurrentContext(context.imgui_context)

cdef inline void ensure_correct_implot_context(Context context) noexcept nogil:
    implot.SetCurrentContext(context.implot_context)

cdef inline void ensure_correct_imnodes_context(Context context) noexcept nogil:
    imnodes.SetCurrentContext(context.imnodes_context)

cdef inline void ensure_correct_im_context(Context context) noexcept nogil:
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
    cdef int external_lock
    cdef Context context
    cdef long long uuid
    cdef object __weakref__
    cdef object _user_data
    # Attributes set by subclasses
    # to indicate what kind of parent
    # and children they can have.
    # Allowed children:
    cdef bint can_have_drawing_child
    # DOES NOT mean "bound" to an item
    cdef bint can_have_handler_child
    cdef bint can_have_menubar_child
    cdef bint can_have_payload_child
    cdef bint can_have_plot_element_child
    cdef bint can_have_tab_child
    cdef bint can_have_theme_child
    cdef bint can_have_widget_child
    cdef bint can_have_window_child
    # Allowed siblings:
    cdef bint can_have_sibling
    # Type of child for the parent
    cdef int element_child_category

    # States
    # p_state: pointer to the itemState inside
    # the item structure for fast access if needed.
    # Set to NULL if the item doesn't have
    # an itemState field
    cdef itemState* p_state
    # Always empty if p_state is NULL.
    cdef vector[PyObject*] _handlers # type baseHandler

    # Relationships
    cdef baseItem _parent
    # It is not possible to access an array of children without the gil
    # Thus instead use a list
    # Each element is responsible for calling draw on its sibling
    cdef baseItem _prev_sibling
    cdef baseItem _next_sibling
    cdef drawingItem last_drawings_child
    cdef baseHandler last_handler_child
    cdef uiItem last_menubar_child
    cdef baseItem last_payloads_child
    cdef plotElement last_plot_element_child
    cdef uiItem last_tab_child
    cdef baseTheme last_theme_child
    cdef uiItem last_widgets_child
    cdef Window last_window_child
    cdef void lock_parent_and_item_mutex(self, unique_lock[recursive_mutex]&, unique_lock[recursive_mutex]&)
    cdef void lock_and_previous_siblings(self) noexcept nogil
    cdef void unlock_and_previous_siblings(self) noexcept nogil
    cdef bint __check_rendered(self)
    cpdef void attach_to_parent(self, target_parent)
    cpdef void attach_before(self, target_before)
    cdef void __detach_item_and_lock(self, unique_lock[recursive_mutex]&)
    cpdef void detach_item(self)
    cpdef void delete_item(self)
    cdef void __delete_and_siblings(self)
    cdef void set_previous_states(self) noexcept nogil
    cdef void run_handlers(self) noexcept nogil
    cdef void update_current_state_as_hidden(self) noexcept nogil
    cdef void propagate_hidden_state_to_children_with_handlers(self) noexcept nogil
    cdef void propagate_hidden_state_to_children_no_handlers(self) noexcept nogil
    cdef void set_hidden_and_propagate_to_siblings_with_handlers(self) noexcept nogil
    cdef void set_hidden_and_propagate_to_siblings_no_handlers(self) noexcept nogil
    cdef void set_hidden_no_handler_and_propagate_to_children_with_handlers(self) noexcept nogil

cdef enum child_type:
    cat_drawing
    cat_viewport_drawlist
    cat_handler
    cat_menubar
    cat_payload
    cat_plot_element
    cat_tab
    cat_theme
    cat_widget
    cat_window

cdef struct itemStateCapabilities:
    bint can_be_active
    bint can_be_clicked
    bint can_be_deactivated_after_edited
    bint can_be_dragged
    bint can_be_edited
    bint can_be_focused
    bint can_be_hovered
    bint can_be_toggled
    bint has_position
    bint has_rect_size
    bint has_content_region

cdef struct itemStateValues:
    bint hovered  # Mouse is over the item + overlap rules of mouse ownership
    bint active # Item is 'active': mouse pressed, editing field, etc.
    bint focused # Item has focus
    bint[<int>imgui.ImGuiMouseButton_COUNT] clicked
    bint[<int>imgui.ImGuiMouseButton_COUNT] double_clicked
    bint[<int>imgui.ImGuiMouseButton_COUNT] dragging
    imgui.ImVec2[<int>imgui.ImGuiMouseButton_COUNT] drag_deltas # only valid when dragging
    bint edited
    bint deactivated_after_edited
    bint open
    imgui.ImVec2 pos_to_viewport
    imgui.ImVec2 pos_to_window
    imgui.ImVec2 pos_to_parent
    imgui.ImVec2 pos_to_default
    imgui.ImVec2 rect_size
    imgui.ImVec2 content_region_size
    # No optimization due to parent menu not open or clipped
    bint rendered

cdef struct itemState:
    itemStateCapabilities cap
    itemStateValues prev
    itemStateValues cur

cdef void update_current_mouse_states(itemState&) noexcept nogil


cpdef enum mouse_cursor:
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

cdef class Viewport(baseItem):
    cdef recursive_mutex mutex_backend
    cdef mvViewport *viewport
    cdef mvGraphics graphics
    cdef bint initialized
    cdef Callback _resize_callback
    cdef Callback _close_callback
    cdef Font _font
    cdef baseTheme _theme
    cdef itemState state # Unused. Just for compatibility with handlers
    cdef imgui.ImGuiMouseCursor _cursor
    # For timing stats
    cdef long long last_t_before_event_handling
    cdef long long last_t_before_rendering
    cdef long long last_t_after_rendering
    cdef long long last_t_after_swapping
    cdef double delta_event_handling
    cdef double delta_rendering
    cdef double delta_swapping
    cdef double delta_frame
    cdef int frame_count # frame count
    # Temporary info to be accessed during rendering
    # Shouldn't be accessed outside draw()
    cdef double[2] scales
    cdef double[2] shifts
    cdef imgui.ImVec2 window_pos
    cdef imgui.ImVec2 parent_pos
    cdef bint in_plot
    cdef bint plot_fit
    cdef float thickness_multiplier # in plots
    cdef float size_multiplier # in plots
    cdef bint[<int>implot.ImAxis_COUNT] enabled_axes
    cdef int start_pending_theme_actions # managed outside viewport
    cdef vector[theme_action] pending_theme_actions # managed outside viewport
    cdef vector[theme_action] applied_theme_actions # managed by viewport
    cdef vector[int] applied_theme_actions_count # managed by viewport
    cdef theme_enablers current_theme_activation_condition_enabled
    cdef theme_categories current_theme_activation_condition_category

    cdef void __check_initialized(self)
    cdef void __check_not_initialized(self)
    cdef void __on_resize(self, int width, int height)
    cdef void __on_close(self)
    cdef void __render(self) noexcept nogil
    cdef void apply_current_transform(self, float *dst_p, double[2] src_p) noexcept nogil
    cdef void push_pending_theme_actions(self, theme_enablers, theme_categories) noexcept nogil
    cdef void push_pending_theme_actions_on_subset(self, int, int) noexcept nogil
    cdef void pop_applied_pending_theme_actions(self) noexcept nogil
    cdef void cwake(self) noexcept nogil


cdef class Callback:
    cdef object callback
    cdef int num_args

"""
Drawing Items
"""

cdef class drawingItem(baseItem):
    cdef bint _show
    cdef void draw_prev_siblings(self, imgui.ImDrawList*) noexcept nogil
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil
    pass

cdef class DrawingList(drawingItem):
    pass

cdef class DrawingListScale(drawingItem):
    cdef double[2] _scales
    cdef double[2] _shifts
    cdef bint _no_parent_scale
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawArrow_(drawingItem):
    cdef double[2] start
    cdef double[2] end
    cdef double[2] corner1
    cdef double[2] corner2
    cdef imgui.ImU32 color
    cdef float thickness
    cdef float size
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil
    cdef void __compute_tip(self)

cdef class DrawBezierCubic_(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef double[2] p4
    cdef imgui.ImU32 color
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawBezierQuadratic_(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef imgui.ImU32 color
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawCircle_(drawingItem):
    cdef double[2] center
    cdef float radius
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int segments
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawEllipse_(drawingItem):
    cdef double[2] pmin
    cdef double[2] pmax
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int segments
    cdef vector[double4] points
    cdef void __fill_points(self)
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawImage_(drawingItem):
    cdef double[2] pmin
    cdef double[2] pmax
    cdef float[4] uv
    cdef imgui.ImU32 color_multiplier
    cdef Texture texture
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawImageQuad_(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef double[2] p4
    cdef float[2] uv1
    cdef float[2] uv2
    cdef float[2] uv3
    cdef float[2] uv4
    cdef imgui.ImU32 color_multiplier
    cdef Texture texture
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawLine_(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef imgui.ImU32 color
    cdef float thickness
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawPolyline_(drawingItem):
    cdef imgui.ImU32 color
    cdef float thickness
    cdef bint closed
    cdef vector[double4] points
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawPolygon_(drawingItem):
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef vector[double4] points
    cdef int[:,:] triangulation_indices
    cdef void __triangulate(self)
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawQuad_(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef double[2] p4
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawRect_(drawingItem):
    cdef double[2] pmin
    cdef double[2] pmax
    cdef imgui.ImU32 color
    cdef imgui.ImU32 color_upper_left
    cdef imgui.ImU32 color_upper_right
    cdef imgui.ImU32 color_bottom_left
    cdef imgui.ImU32 color_bottom_right
    cdef imgui.ImU32 fill
    cdef float rounding
    cdef float thickness
    cdef bint multicolor
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawText_(drawingItem):
    cdef double[2] pos
    cdef string text
    cdef imgui.ImU32 color
    cdef float size
    cdef Font _font
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawTriangle_(drawingItem):
    cdef double[2] p1
    cdef double[2] p2
    cdef double[2] p3
    cdef imgui.ImU32 color
    cdef imgui.ImU32 fill
    cdef float thickness
    cdef int cull_mode
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil

cdef class DrawInvisibleButton(drawingItem):
    cdef itemState state
    cdef imgui.ImGuiButtonFlags _button
    cdef float _min_side
    cdef float _max_side
    cdef bint _no_input
    cdef bint _capture_mouse
    cdef double[2] _p1
    cdef double[2] _p2
    cdef imgui.ImVec2 initial_mouse_position

cdef class ViewportDrawList_(baseItem):
    cdef bint _front
    cdef bint _show
    cdef void draw(self) noexcept nogil


"""
Shared values (sources)

Should we use cdef recursive_mutex mutex ?
"""
cdef class SharedValue:
    cdef recursive_mutex mutex
    cdef Context context
    cdef int _num_attached # number of items the value is attached to
    cdef int _last_frame_update
    cdef int _last_frame_change
    cdef void on_update(self, bint) noexcept nogil
    cdef void inc_num_attached(self) noexcept nogil
    cdef void dec_num_attached(self) noexcept nogil

cdef class SharedBool(SharedValue):
    cdef bint _value
    # Internal functions.
    # python uses get_value and set_value
    cdef bint get(self) noexcept nogil
    cdef void set(self, bint) noexcept nogil

cdef class SharedFloat(SharedValue):
    cdef float _value
    cdef float get(self) noexcept nogil
    cdef void set(self, float) noexcept nogil

cdef class SharedInt(SharedValue):
    cdef int _value
    cdef int get(self) noexcept nogil
    cdef void set(self, int) noexcept nogil

cdef class SharedColor(SharedValue):
    cdef imgui.ImU32 _value
    cdef imgui.ImVec4 _value_asfloat4
    cdef imgui.ImU32 getU32(self) noexcept nogil
    cdef imgui.ImVec4 getF4(self) noexcept nogil
    cdef void setU32(self, imgui.ImU32) noexcept nogil
    cdef void setF4(self, imgui.ImVec4) noexcept nogil

cdef class SharedDouble(SharedValue):
    cdef double _value
    cdef double get(self) noexcept nogil
    cdef void set(self, double) noexcept nogil

cdef class SharedStr(SharedValue):
    cdef string _value
    cdef void get(self, string&) noexcept nogil
    cdef void set(self, string) noexcept nogil

cdef class SharedFloat4(SharedValue):
    cdef float[4] _value
    cdef void get(self, float *) noexcept nogil# cython does support float[4] as return value
    cdef void set(self, float[4]) noexcept nogil

cdef class SharedInt4(SharedValue):
    cdef int[4] _value
    cdef void get(self, int *) noexcept nogil
    cdef void set(self, int[4]) noexcept nogil

cdef class SharedDouble4(SharedValue):
    cdef double[4] _value
    cdef void get(self, double *) noexcept nogil
    cdef void set(self, double[4]) noexcept nogil

cdef class SharedFloatVect(SharedValue):
    cdef cnp.ndarray _value_np
    cdef float[:] _value
    cdef float[:] get(self) noexcept nogil
    cdef void set(self, float[:]) noexcept nogil
"""
cdef class SharedDoubleVect:
    cdef double[:] _value
    cdef double[:] get(self) noexcept nogil
    cdef void set(self, double[:]) noexcept nogil


cdef class SharedTime:
    cdef tm _value
    cdef tm get(self) noexcept nogil
    cdef void set(self, tm) noexcept nogil
"""

# TODO: uuid

"""
UI item
A drawable item with various UI states
"""

cdef class baseHandler(baseItem):
    cdef bint _enabled
    cdef Callback _callback
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil
    cdef void run_callback(self, baseItem) noexcept nogil

cdef class KeyDownHandler_(baseHandler):
    cdef int _key
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyPressHandler_(baseHandler):
    cdef int _key
    cdef bint _repeat
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyReleaseHandler_(baseHandler):
    cdef int _key
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseClickHandler_(baseHandler):
    cdef int _button
    cdef bint _repeat
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDoubleClickHandler_(baseHandler):
    cdef int _button
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDownHandler_(baseHandler):
    cdef int _button
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDragHandler_(baseHandler):
    cdef int _button
    cdef float _threshold
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseMoveHandler(baseHandler):
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseReleaseHandler_(baseHandler):
    cdef int _button
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseWheelHandler(baseHandler):
    cdef bint _horizontal
    cdef void run_handler(self, baseItem) noexcept nogil

cpdef enum positioning:
    DEFAULT,
    REL_DEFAULT,
    REL_PARENT,
    REL_WINDOW,
    REL_VIEWPORT

cdef class uiItem(baseItem):
    cdef string imgui_label
    cdef str user_label
    cdef bool _show
    cdef positioning[2] _pos_policy
    # mvAppItemInfo
    #cdef int location -> for table
    # mvAppItemState
    cdef itemState state
    cdef bint can_be_disabled
    cdef bint _enabled
    cdef bint focus_update_requested
    cdef bint show_update_requested
    cdef bint size_update_requested
    cdef bint pos_update_requested
    cdef bint _no_newline
    cdef bint enabled_update_requested
    cdef int last_frame_update
    # mvAppItemConfig
    #cdef string filter -> to move
    #cdef string alias
    cdef string payloadType
    cdef imgui.ImVec2 requested_size
    cdef float _indent
    cdef theme_enablers theme_condition_enabled
    cdef theme_categories theme_condition_category
    #cdef float trackOffset
    #cdef bint tracked
    cdef Callback dragCallback
    cdef Callback dropCallback
    cdef Font _font
    cdef baseTheme _theme
    cdef vector[PyObject*] _callbacks # type Callback
    cdef SharedValue _value

    cdef void update_current_state(self) noexcept nogil
    cdef void update_current_state_subset(self) noexcept nogil
    cdef void draw(self) noexcept nogil
    #cdef void draw_children(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class DrawInWindow(uiItem):
    cdef bint draw_item(self) noexcept nogil

"""
Simple UI elements
"""
cdef class SimplePlot(uiItem):
    cdef string _overlay
    cdef float _scale_min
    cdef float _scale_max
    cdef bint _histogram
    cdef bint _autoscale
    cdef int last_frame_autoscale_update
    cdef bint draw_item(self) noexcept nogil


cdef class Button(uiItem):
    cdef imgui.ImGuiDir _direction
    cdef bint _small
    cdef bint _arrow
    cdef bint _repeat
    cdef bint draw_item(self) noexcept nogil


cdef class Combo(uiItem):
    cdef imgui.ImGuiComboFlags flags
    cdef vector[string] _items
    cdef string disabled_value
    cdef bint draw_item(self) noexcept nogil


cdef class Checkbox(uiItem):
    cdef bint draw_item(self) noexcept nogil


cdef class Slider(uiItem):
    cdef int _size
    cdef int _format
    cdef bint _drag
    cdef float _drag_speed
    cdef double _min
    cdef double _max
    cdef string _print_format
    cdef bint _vertical
    cdef imgui.ImGuiSliderFlags flags
    cdef bint draw_item(self) noexcept nogil


cdef class ListBox(uiItem):
    cdef vector[string] _items
    cdef int _num_items_shown_when_open
    cdef bint draw_item(self) noexcept nogil


cdef class RadioButton(uiItem):
    cdef vector[string] _items
    cdef bint _horizontal
    cdef bint draw_item(self) noexcept nogil


cdef class InputText(uiItem):
    cdef string _hint
    cdef bint _multiline
    cdef int _max_characters
    cdef imgui.ImGuiInputTextFlags flags
    cdef bint draw_item(self) noexcept nogil


cdef class InputValue(uiItem):
    cdef int _size
    cdef int _format
    cdef double _step
    cdef double _step_fast
    cdef double _min
    cdef double _max
    cdef string _print_format
    cdef imgui.ImGuiInputTextFlags flags
    cdef bint draw_item(self) noexcept nogil


cdef class Text(uiItem):
    cdef imgui.ImU32 _color
    cdef int _wrap
    cdef bint _bullet
    cdef bint _show_label
    cdef bint draw_item(self) noexcept nogil


cdef class Selectable(uiItem):
    cdef imgui.ImGuiSelectableFlags flags
    cdef bint draw_item(self) noexcept nogil

cdef class MenuItem(uiItem):
    cdef string _shortcut
    cdef bint _check
    cdef bint draw_item(self) noexcept nogil


cdef class ProgressBar(uiItem):
    cdef string _overlay
    cdef bint draw_item(self) noexcept nogil


cdef class Image(uiItem):
    cdef float[4] _uv
    cdef imgui.ImU32 _color_multiplier
    cdef imgui.ImU32 _border_color
    cdef Texture _texture
    cdef bint draw_item(self) noexcept nogil


cdef class ImageButton(uiItem):
    cdef float[4] _uv
    cdef imgui.ImU32 _color_multiplier
    cdef imgui.ImU32 _background_color
    cdef Texture _texture
    cdef int _frame_padding
    cdef bint draw_item(self) noexcept nogil

cdef class Separator(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class Spacer(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class MenuBar(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class Menu(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class Tooltip(uiItem):
    cdef float _delay
    cdef bint _hide_on_activity
    cdef bint _only_if_previous_item_hovered
    cdef bint _only_if_
    cdef baseItem _target
    cdef baseHandler secondary_handler
    cdef bint draw_item(self) noexcept nogil

cdef class TabButton(uiItem):
    cdef imgui.ImGuiTabBarFlags flags
    cdef bint draw_item(self) noexcept nogil

cdef class Tab(uiItem):
    cdef bint _closable
    cdef imgui.ImGuiTabItemFlags flags

cdef class TabBar(uiItem):
    cdef imgui.ImGuiTabBarFlags flags

cdef class Layout(uiItem):
    cdef bint force_update
    cdef PyObject* previous_last_child
    cdef imgui.ImVec2 prev_content_area
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cpdef enum alignment:
    LEFT=0,
    TOP=0,
    RIGHT=1,
    BOTTOM=1,
    CENTER=2,
    JUSTIFIED=3,
    MANUAL=4

cdef class HorizontalLayout(Layout):
    cdef alignment _alignment_mode
    cdef float _spacing
    cdef vector[float] _positions
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class VerticalLayout(Layout):
    cdef alignment _alignment_mode
    cdef float _spacing
    cdef vector[float] _positions
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class TreeNode(uiItem):
    cdef imgui.ImGuiTreeNodeFlags flags
    cdef bint _selectable
    cdef bint draw_item(self) noexcept nogil

cdef class CollapsingHeader(uiItem):
    cdef imgui.ImGuiTreeNodeFlags flags
    cdef bint _closable
    cdef bint draw_item(self) noexcept nogil

cdef class ChildWindow(uiItem):
    cdef imgui.ImGuiWindowFlags window_flags
    cdef imgui.ImGuiChildFlags child_flags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorButton(uiItem):
    cdef imgui.ImGuiColorEditFlags flags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorEdit(uiItem):
    cdef imgui.ImGuiColorEditFlags flags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorPicker(uiItem):
    cdef imgui.ImGuiColorEditFlags flags
    cdef bint draw_item(self) noexcept nogil

"""
Complex UI elements
"""

cdef class TimeWatcher(uiItem):
    pass

cdef class Window(uiItem):
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
    cdef bint has_close_button
    cdef bint no_background
    cdef bint no_open_over_existing_popup
    cdef Callback on_close_callback
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
    cdef void draw(self) noexcept nogil

"""
Bindable elements
"""

cdef class Texture(baseItem):
    cdef recursive_mutex write_mutex
    cdef bint _hint_dynamic
    cdef bint dynamic
    cdef void* allocated_texture
    cdef int _width
    cdef int _height
    cdef int _num_chans
    cdef int filtering_mode
    cdef bint readonly
    cdef void set_content(self, cnp.ndarray content)

cdef class Font(baseItem):
    cdef imgui.ImFont *font
    cdef FontTexture container
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class FontTexture(baseItem):
    """
    Packs one or several fonts into
    a texture for internal use by ImGui.
    """
    cdef imgui.ImFontAtlas atlas
    cdef Texture _texture
    cdef bint _built
    cdef list fonts

cdef enum theme_types:
    t_color,
    t_style

cdef enum theme_backends:
    t_imgui,
    t_implot,
    t_imnodes

cpdef enum theme_enablers:
    t_enabled_any,
    t_enabled_False,
    t_enabled_True,
    t_discarded

cpdef enum theme_categories:
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
    theme_enablers activation_condition_enabled
    theme_categories activation_condition_category
    theme_types type
    theme_backends backend
    int theme_index
    theme_value_types value_type
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
Plots
"""

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

cdef class plotElement(baseItem):
    cdef string imgui_label
    cdef str user_label
    cdef int flags
    cdef bint _show
    cdef int[2] _axes
    cdef baseTheme _theme
    cdef void draw(self) noexcept nogil

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
cdef void imgui_SetMouseCursor(int) noexcept nogil

ctypedef fused point_type:
    int
    float
    double

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
