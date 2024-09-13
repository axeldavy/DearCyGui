from dearcygui.wrapper cimport imgui, implot, imnodes, float4
from dearcygui.backends.backend cimport mvViewport, mvGraphics
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
    cdef baseItem stagingRoots
    cdef baseItem viewportMenubarRoots
    cdef dcgWindow_ windowRoots
    cdef baseItem fontRegistryRoots
    cdef baseItem handlerRegistryRoots
    cdef baseItem itemHandlerRegistryRoots
    cdef baseItem textureRegistryRoots
    cdef baseItem valueRegistryRoots
    cdef baseItem themeRegistryRoots
    cdef baseItem itemTemplatesRoots
    cdef dcgViewportDrawList_ viewportDrawlistRoots
    # Temporary info to be accessed during rendering
    # Shouldn't be accessed outside draw()
    #mvMat4 transform         = mvIdentityMat4();
    #mvMat4 appliedTransform  = mvIdentityMat4(); // only used by nodes
    #cdef long cullMode -> unused
    cdef bint perspectiveDivide
    cdef bint depthClipping
    cdef float[6] clipViewport
    cdef bint has_matrix_transform
    cdef float[4][4] transform
    cdef bint in_plot
    cdef float thickness_multiplier # in plots


    cdef initialize(self, unsigned width, unsigned height)
    cdef void __check_initialized(self)
    cdef void __on_resize(self, int width, int height)
    cdef void __on_close(self)
    cdef void __render(self) noexcept nogil
    cdef void apply_current_transform(self, float *dst_p, float[4] src_p, float dx, float dy) noexcept nogil


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

# Each .so has its own current context. To be able to work
# with various .so and contexts, we must ensure the correct
# context is current. The call is almost free as it's just
# a pointer that is set.
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
    # and children they can have
    cdef bint can_have_0_child
    cdef bint can_have_widget_child
    cdef bint can_have_drawing_child
    cdef bint can_have_payload_child
    cdef bint can_have_sibling
    cdef bint can_have_nonviewport_parent
    cdef int element_child_category
    cdef bint can_have_viewport_parent
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

cdef class dcgGlobalHandlerRegistry(baseItem):
    #cdef dcgContext context
    cdef globalHandler last_handler
    cdef bint enabled
    cdef void run_handlers(self) noexcept nogil

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

cdef class dcgItemHandlerRegistry(baseItem):
    #cdef dcgContext context
    cdef itemHandler last_item_handler
    cdef bint enabled
    cdef void check_bind(self, uiItem)
    cdef void run_handlers(self, uiItem) noexcept nogil

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
    cdef dcgItemHandlerRegistry handlers

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


"""
Utils that the other pyx may use
"""
cdef imgui.ImU32 imgui_ColorConvertFloat4ToU32(imgui.ImVec4) noexcept nogil
cdef imgui.ImVec4 imgui_ColorConvertU32ToFloat4(imgui.ImU32) noexcept nogil