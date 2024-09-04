from dearcygui.wrapper cimport mvViewport, mvGraphics, imgui, ImVec2
from libcpp.string cimport string
from libcpp cimport bool
from dearcygui.wrapper.mutex cimport recursive_mutex
from libcpp.atomic cimport atomic

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
    cdef public object resize_callback
    cdef public object close_callback
    cdef bint initialized
    cdef mvGraphics graphics
    cdef bint graphics_initialized
    # linked list to objects without parents to draw with their children
    # The entry point corresponds to the last item of the list (draw last)
    cdef appItem colormapRoots
    cdef appItem filedialogRoots
    cdef appItem stagingRoots
    cdef appItem viewportMenubarRoots
    cdef appItem windowRoots
    cdef appItem fontRegistryRoots
    cdef appItem handlerRegistryRoots
    cdef appItem itemHandlerRegistryRoots
    cdef appItem textureRegistryRoots
    cdef appItem valueRegistryRoots
    cdef appItem themeRegistryRoots
    cdef appItem itemTemplatesRoots
    cdef appItem viewportDrawlistRoots
    cdef initialize(self, unsigned width, unsigned height)
    cdef void __check_initialized(self)
    cdef void __on_resize(self, int width, int height)
    cdef void __on_close(self)
    cdef void __render(self) noexcept nogil

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
    #cdef dcgGraphics graphics
    cdef bint resetTheme
    #cdef dcgIO IO
    #cdef dcgItemRegistry itemRegistry
    #cdef dcgCallbackRegistry callbackRegistry
    #cdef dcgToolManager toolManager
    #cdef dcgInput input
    #cdef UUID activeWindow
    #cdef UUID focusedItem
    cdef public object on_close_callback
    cdef public object on_frame_callbacks
    cdef object queue

cdef class appItem:
    cdef recursive_mutex mutex
    cdef dcgContext context
    cdef long long uuid
    # mvAppItemInfo
    cdef string internalLabel
    cdef int location
    cdef bint showDebug
    cdef bint focusNextFrame
    cdef bint triggerAlternativeAction
    cdef bint shownLastFrame
    cdef bint hiddenLastFrame
    cdef bint enabledLastFrame
    cdef bint disabledLastFrame
    cdef imgui.ImVec2 previousCursorPos
    cdef bint dirty_size
    cdef bint dirtyPos
    # mvAppItemState
    cdef bint hovered
    cdef bint active
    cdef bint focused
    cdef bint leftclicked
    cdef bint rightclicked
    cdef bint middleclicked
    cdef bint[5] doubleclicked
    cdef bint visible
    cdef bint edited
    cdef bint activated
    cdef bint deactivated
    cdef bint deactivatedAfterEdit
    cdef bint toggledOpen
    cdef bint mvRectSizeResized
    cdef imgui.ImVec2 rectMin
    cdef imgui.ImVec2 rectMax
    cdef imgui.ImVec2 rectSize
    cdef imgui.ImVec2 mvPrevRectSize
    cdef imgui.ImVec2 pos
    cdef imgui.ImVec2 contextRegionAvail
    cdef bint ok
    cdef int lastFrameUpdate
    # mvAppItemConfig
    cdef long long source
    cdef string specifiedLabel
    cdef string filter
    cdef string alias
    cdef string payloadType
    cdef int width
    cdef int height
    cdef float indent
    cdef float trackOffset
    cdef bool show
    cdef bint enabled
    cdef bint useInternalLabel
    cdef bint tracked
    cdef object callback
    cdef object user_data
    cdef object dragCallback
    cdef object dropCallback
    # mvAppItemDrawInfo
    #mvMat4 transform         = mvIdentityMat4();
    #mvMat4 appliedTransform  = mvIdentityMat4(); // only used by nodes
    cdef long cullMode
    cdef bint perspectiveDivide
    cdef bint depthClipping
    cdef float[6] clipViewport
    # Relationships
    cdef bint attached
    cdef appItem parent
    # It is not possible to access an array of children without the gil
    # Thus instead use a list
    # Each element is responsible for calling draw on its sibling
    cdef appItem prev_sibling
    cdef appItem next_sibling
    cdef appItem last_0_child #  mvFileExtension, mvFontRangeHint, mvNodeLink, mvAnnotation, mvAxisTag, mvDragLine, mvDragPoint, mvDragRect, mvLegend, mvTableColumn
    cdef appItem last_widgets_child
    cdef appItem last_drawings_child
    cdef appItem last_payloads_child
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil
    cdef void __lock_parent_and_item_mutex(self) noexcept nogil
    cdef void __unlock_parent_mutex(self) noexcept nogil
    cpdef void attach_item(self, appItem target_parent)
    cdef void __detach_item_and_lock(self)
    cpdef void detach_item(self)
    cpdef void delete_item(self)
    cdef void __delete_and_siblings(self)

cdef class dcgWindow(appItem):
    cdef imgui.ImGuiWindowFlags windowflags
    cdef bint mainWindow
    cdef bint closing
    cdef bint resized
    cdef bint modal
    cdef bint popup
    cdef bint autosize
    cdef bint no_resize
    cdef bint no_title_bar
    cdef bint no_move
    cdef bint no_scrollbar
    cdef bint no_collapse
    cdef bint horizontal_scrollbar
    cdef bint no_focus_on_appearing
    cdef bint no_bring_to_front_on_focus
    cdef bint menubar
    cdef bint no_close
    cdef bint no_background
    cdef bint collapsed
    cdef bint no_open_over_existing_popup
    cdef object on_close
    cdef imgui.ImVec2 min_size
    cdef imgui.ImVec2 max_size
    cdef float scrollX
    cdef float scrollY
    cdef float scrollMaxX
    cdef float scrollMaxY
    cdef bint _collapsedDirty
    cdef bint _scrollXSet
    cdef bint _scrollYSet
    cdef imgui.ImGuiWindowFlags _oldWindowflags
    cdef float _oldxpos
    cdef float _oldypos
    cdef int  _oldWidth
    cdef int  _oldHeight
    cdef void draw(self, imgui.ImDrawList*, float, float) noexcept nogil
