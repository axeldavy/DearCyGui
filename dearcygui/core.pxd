from dearcygui.wrapper cimport imgui, implot, imnodes
from dearcygui.backends.backend cimport platformViewport
from libcpp.string cimport string
from libcpp cimport bool
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock, defer_lock_t
from libcpp.atomic cimport atomic
from libcpp.vector cimport vector
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
cimport numpy as cnp
from .types cimport *

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


cdef inline void clear_obj_vector(vector[PyObject *] &items):
    cdef int i
    cdef object obj
    for i in range(<int>items.size()):
        obj = <object> items[i]
        Py_DECREF(obj)
    items.clear()

cdef inline void append_obj_vector(vector[PyObject *] &items, item_list):
    for item in item_list:
        Py_INCREF(item)
        items.push_back(<PyObject*>item)

cdef inline object IntPairFromVec2(imgui.ImVec2 v):
    return (<int>v.x, <int>v.y)

cdef class Context:
    cdef recursive_mutex mutex
    cdef atomic[long long] next_uuid
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
    cdef object _item_creation_callback
    cdef object _item_unused_configure_args_callback
    cdef object _item_deletion_callback
    cdef object queue
    cdef void queue_callback_noarg(self, Callback, baseItem, baseItem) noexcept nogil
    cdef void queue_callback_arg1obj(self, Callback, baseItem, baseItem, baseItem) noexcept nogil
    cdef void queue_callback_arg1key(self, Callback, baseItem, baseItem, int) noexcept nogil
    cdef void queue_callback_arg1button(self, Callback, baseItem, baseItem, int) noexcept nogil
    cdef void queue_callback_arg1float(self, Callback, baseItem, baseItem, float) noexcept nogil
    cdef void queue_callback_arg1value(self, Callback, baseItem, baseItem, SharedValue) noexcept nogil
    cdef void queue_callback_arg1key1float(self, Callback, baseItem, baseItem, int, float) noexcept nogil
    cdef void queue_callback_arg1button1float(self, Callback, baseItem, baseItem, int, float) noexcept nogil
    cdef void queue_callback_arg2float(self, Callback, baseItem, baseItem, float, float) noexcept nogil
    cdef void queue_callback_arg2double(self, Callback, baseItem, baseItem, double, double) noexcept nogil
    cdef void queue_callback_arg1button2float(self, Callback, baseItem, baseItem, int, float, float) noexcept nogil
    cdef void queue_callback_arg4int(self, Callback, baseItem, baseItem, int, int, int, int) noexcept nogil
    cdef void queue_callback_arg3long1int(self, Callback, baseItem, baseItem, long long, long long, long long, int) noexcept nogil
    cdef void queue_callback_argdoubletriplet(self, Callback, baseItem, baseItem, double, double, double, double, double, double) noexcept nogil
    cdef void queue_callback_arg1int1stringvector(self, Callback, baseItem, baseItem, int, vector[string]) noexcept nogil
    cpdef void push_next_parent(self, baseItem next_parent)
    cpdef void pop_next_parent(self)
    cpdef object fetch_parent_queue_back(self)
    cpdef object fetch_parent_queue_front(self)

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
    cdef bint can_have_plot_element_child
    cdef bint can_have_tab_child
    cdef bint can_have_theme_child
    cdef bint can_have_viewport_drawlist_child
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
    cdef plotElement last_plot_element_child
    cdef uiItem last_tab_child
    cdef baseTheme last_theme_child
    cdef drawingItem last_viewport_drawlist_child
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
    cdef void propagate_hidden_state_to_children_no_handlers(self) noexcept
    cdef void set_hidden_and_propagate_to_siblings_with_handlers(self) noexcept nogil
    cdef void set_hidden_and_propagate_to_siblings_no_handlers(self) noexcept
    cdef void set_hidden_no_handler_and_propagate_to_children_with_handlers(self) noexcept nogil
    cdef void set_hidden_and_propagate_to_children_no_handlers(self) noexcept

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


cdef class Viewport(baseItem):
    cdef recursive_mutex mutex_backend
    cdef platformViewport *platform
    cdef bint initialized
    cdef Callback _resize_callback
    cdef Callback _close_callback
    cdef Font _font
    cdef baseTheme _theme
    cdef bint _disable_close
    cdef bint drop_is_file_type
    cdef vector[string] _drop_data
    cdef itemState state # Unused. Just for compatibility with handlers
    cdef imgui.ImGuiMouseCursor _cursor
    # For timing stats
    cdef long long last_t_before_event_handling
    cdef long long last_t_before_rendering
    cdef long long last_t_after_rendering
    cdef long long last_t_after_swapping
    cdef long long t_first_skip
    cdef double delta_event_handling
    cdef double delta_rendering
    cdef double delta_swapping
    cdef double delta_frame
    cdef int frame_count # frame count
    # Temporary info to be accessed during rendering
    # Shouldn't be accessed outside draw()
    cdef bint redraw_needed
    cdef bint skipped_last_frame
    cdef double[2] scales
    cdef double[2] shifts
    cdef imgui.ImVec2 window_pos
    cdef imgui.ImVec2 parent_pos
    cdef bint in_plot
    cdef bint plot_fit
    cdef float thickness_multiplier
    cdef float size_multiplier # May not be scales[0]
    cdef bint[<int>implot.ImAxis_COUNT] enabled_axes
    cdef int start_pending_theme_actions # managed outside viewport
    cdef vector[theme_action] pending_theme_actions # managed outside viewport
    cdef vector[theme_action] applied_theme_actions # managed by viewport
    cdef vector[int] applied_theme_actions_count # managed by viewport
    cdef ThemeEnablers current_theme_activation_condition_enabled
    cdef ThemeCategories current_theme_activation_condition_category
    cdef float _scale
    cdef float global_scale

    cdef void __check_initialized(self)
    cdef void __check_not_initialized(self)
    cdef void __on_resize(self)
    cdef void __on_close(self)
    cdef void __on_drop(self, int, const char*)
    cdef void __render(self) noexcept nogil
    cdef void apply_current_transform(self, float *dst_p, double[2] src_p) noexcept nogil
    cdef void push_pending_theme_actions(self, ThemeEnablers, ThemeCategories) noexcept nogil
    cdef void push_pending_theme_actions_on_subset(self, int, int) noexcept nogil
    cdef void pop_applied_pending_theme_actions(self) noexcept nogil
    cdef void cwake(self) noexcept nogil


cdef class Callback:
    cdef object callback
    cdef int num_args

# Rendering children

cdef inline void draw_drawing_children(baseItem item,
                                       imgui.ImDrawList* drawlist) noexcept nogil:
    if item.last_drawings_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_drawings_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<drawingItem>child).draw(drawlist)
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef inline void draw_menubar_children(baseItem item) noexcept nogil:
    if item.last_menubar_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_menubar_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef inline void draw_plot_element_children(baseItem item) noexcept nogil:
    if item.last_plot_element_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_plot_element_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<plotElement>child).draw()
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef inline void draw_tab_children(baseItem item) noexcept nogil:
    if item.last_tab_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_tab_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef inline void draw_viewport_drawlist_children(baseItem item) noexcept nogil:
    if item.last_viewport_drawlist_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_viewport_drawlist_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<drawingItem>child).draw(NULL)
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef inline void draw_ui_children(baseItem item) noexcept nogil:
    if item.last_widgets_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_widgets_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child)._next_sibling

cdef inline void draw_window_children(baseItem item) noexcept nogil:
    if item.last_window_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_window_child
    while (<baseItem>child)._prev_sibling is not None:
        child = <PyObject *>(<baseItem>child)._prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child)._next_sibling

"""
Drawing Items
"""

cdef class drawingItem(baseItem):
    cdef bint _show
    cdef void draw(self, imgui.ImDrawList*) noexcept nogil
    pass

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

cdef void update_current_mouse_states(itemState& state) noexcept nogil

cdef class uiItem(baseItem):
    cdef string imgui_label
    cdef str user_label
    cdef bool _show
    cdef Positioning[2] _pos_policy
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
    cdef bint dpi_scaling
    cdef imgui.ImVec2 requested_size
    cdef float _indent
    cdef ThemeEnablers theme_condition_enabled
    cdef ThemeCategories theme_condition_category
    cdef Callback dragCallback
    cdef Callback dropCallback
    cdef Font _font
    cdef baseTheme _theme
    cdef vector[PyObject*] _callbacks # type Callback
    cdef SharedValue _value

    cdef void update_current_state(self) noexcept nogil
    cdef void update_current_state_subset(self) noexcept nogil
    cdef imgui.ImVec2 scaled_requested_size(self) noexcept nogil
    cdef void draw(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

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
    cdef Callback on_drop_callback
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
Plots
"""
cdef class plotElement(baseItem):
    cdef string imgui_label
    cdef str user_label
    cdef int flags
    cdef bint _show
    cdef int[2] _axes
    cdef baseTheme _theme
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
    cdef unsigned _buffer_type
    cdef int filtering_mode
    cdef bint readonly
    cdef void set_content(self, cnp.ndarray content)

cdef class Font(baseItem):
    cdef imgui.ImFont *font
    cdef FontTexture container
    cdef bint dpi_scaling
    cdef float _scale
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
    cdef list fonts_files # content of the font files
    cdef list fonts

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

