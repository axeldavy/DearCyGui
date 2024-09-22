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
from cpython.ref cimport PyObject

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
from libcpp.cmath cimport atan, sin, cos, trunc
from libcpp.vector cimport vector
from libc.math cimport M_PI, INFINITY

import numpy as np
cimport numpy as cnp

import scipy
import scipy.spatial
import threading
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

cdef int child_cat_window = 0
cdef int child_cat_ui = 1
cdef int child_cat_drawing = 2
cdef int child_cat_payload = 3
cdef int child_cat_global_handler = 4
cdef int child_cat_item_handler = 5
cdef int child_cat_theme = 6

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
        self.uuid_to_tag = dict()
        self.tag_to_uuid = dict()
        self._parent_context_queue = threading.local()
        self.viewport = dcgViewport(self)
        self.resetTheme = False
        imgui.IMGUI_CHECKVERSION()
        self.imgui_context = imgui.CreateContext()
        self.implot_context = implot.CreateContext()
        self.imnodes_context = imnodes.CreateContext()
        #mvToolManager::GetFontManager()._dirty = true;

    def __dealloc__(self):
        self.started = True
        if self.imnodes_context != NULL:
            imnodes.DestroyContext(self.imnodes_context)
        if self.implot_context != NULL:
            implot.DestroyContext(self.implot_context)
        if self.imgui_context != NULL:
            imgui.DestroyContext(self.imgui_context)

    def __del__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.on_close_callback is not None:
            self.started = True
            self.queue_callback_noarg(self.on_close_callback, self)
            self.started = False

        #mvToolManager::Reset()
        #ClearItemRegistry(*GContext->itemRegistry)
        if self.queue is not None:
            self.queue.shutdown(wait=True)

    cdef void queue_callback_noarg(self, dcgCallback callback, object parent_item) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, None, None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1int(self, dcgCallback callback, object parent_item, int arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, arg1, None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1float(self, dcgCallback callback, object parent_item, float arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, arg1, None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1value(self, dcgCallback callback, object parent_item, shared_value arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, arg1.value, None)
            except Exception as e:
                print(traceback.format_exc())


    cdef void queue_callback_arg1int1float(self, dcgCallback callback, object parent_item, int arg1, float arg2) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, (arg1, arg2), None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg2float(self, dcgCallback callback, object parent_item, float arg1, float arg2) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, (arg1, arg2), None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1int2float(self, dcgCallback callback, object parent_item, int arg1, float arg2, float arg3) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, (arg1, arg2, arg3), None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void register_item(self, baseItem o, long long uuid):
        """ Stores weak references to objects.
        
        Each object holds a reference on the context, and thus will be
        freed after calling unregister_item. If gc makes it so the context
        is collected first, that's ok as we don't use the content of the
        map anymore.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.items[uuid] = <PyObject*>o

    cdef void register_item_with_tag(self, baseItem o, long long uuid, str tag):
        """ Stores weak references to objects.
        
        Each object holds a reference on the context, and thus will be
        freed after calling unregister_item. If gc makes it so the context
        is collected first, that's ok as we don't use the content of the
        map anymore.

        Using a tag enables the user to name his objects and reference them by
        names.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if tag in self.tag_to_uuid:
            raise KeyError(f"Tag {tag} already in use")
        self.items[uuid] = <PyObject*>o
        self.uuid_to_tag[uuid] = tag
        self.tag_to_uuid[tag] = uuid

    cdef void unregister_item(self, long long uuid):
        """ Free weak reference """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.items.erase(uuid)
        if self.uuid_to_tag is None:
            # Can occur during gc collect at
            # the end of the program
            return
        if uuid in self.uuid_to_tag:
            tag = self.uuid_to_tag[uuid]
            del self.uuid_to_tag[uuid]
            del self.tag_to_uuid[tag]

    cdef baseItem get_registered_item_from_uuid(self, long long uuid):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef map[long long, PyObject *].iterator item = self.items.find(uuid)
        if item == self.items.end():
            return None
        cdef PyObject *o = dereference(item).second
        # Cython inserts a strong object reference when we convert
        # the pointer to an object
        return <baseItem>o

    cdef baseItem get_registered_item_from_tag(self, str tag):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef long long uuid = self.tag_to_uuid.get(tag, -1)
        if uuid == -1:
            # not found
            return None
        return self.get_registered_item_from_uuid(uuid)

    cdef void update_registered_item_tag(self, baseItem o, long long uuid, str tag):
        old_tag = self.uuid_to_tag.get(uuid, None)
        if old_tag == tag:
            return
        if tag in self.tag_to_uuid:
            raise KeyError(f"Tag {tag} already in use")
        if old_tag is not None:
            del self.tag_to_uuid[old_tag]
            del self.uuid_to_tag[uuid]
        if tag is not None:
            self.uuid_to_tag[uuid] = tag
            self.tag_to_uuid[tag] = uuid

    def __getitem__(self, key):
        """
        Retrieves the object associated to
        a tag or an uuid
        """
        if isinstance(key, baseItem):
            # Useful for legacy call wrappers
            return key
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef long long uuid
        if isinstance(key, str):
            if key not in self.tag_to_uuid:
                raise KeyError(f"Item not found with index {key}.")
            uuid = self.tag_to_uuid[key]
        elif isinstance(key, int):
            uuid = key
        else:
            raise TypeError(f"{type(key)} is an invalid index type")
        item = self.get_registered_item_from_uuid(uuid)
        if item is None:
            raise KeyError(f"Item not found with index {key}.")
        return item

    cpdef void push_next_parent(self, baseItem next_parent):
        # Use thread local storage such that multiple threads
        # can build items trees without conflicts.
        # Mutexes are not needed due to the thread locality
        cdef list parent_queue = getattr(self._parent_context_queue, 'parent_queue', [])
        parent_queue.append(next_parent)
        self._parent_context_queue.parent_queue = parent_queue

    cpdef void pop_next_parent(self):
        cdef list parent_queue = getattr(self._parent_context_queue, 'parent_queue', [])
        if len(parent_queue) > 0:
            parent_queue.pop()

    cpdef object fetch_next_parent(self):
        cdef list parent_queue = getattr(self._parent_context_queue, 'parent_queue', [])
        if len(parent_queue) == 0:
            return None
        return parent_queue[len(parent_queue)-1]

    def initialize_viewport(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.initialize(width=kwargs["width"],
                                 height=kwargs["height"])
        self.viewport.configure(**kwargs)

    def start(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.started:
            raise ValueError("Cannot call \"setup_dearpygui\" while a Dear PyGUI app is already running.")
        self.started = True

    @property
    def running(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.started



cdef class baseItem:
    def __init__(self, context, *args, **kwargs):
        if len(kwargs) > 0 or len(args) > 0:
            self.configure(*args, **kwargs)

    def __cinit__(self, context, *args, **kwargs):
        if not(isinstance(context, dcgContext)):
            raise ValueError("Provided context is not a valid dcgContext instance")
        self.context = context
        self.external_lock = False
        self.uuid = self.context.next_uuid.fetch_add(1)
        self.context.register_item(self, self.uuid)
        self.can_have_widget_child = False
        self.can_have_drawing_child = False
        self.can_have_payload_child = False
        self.can_have_sibling = False
        self.element_child_category = -1

    def __dealloc__(self):
        if self.context is not None:
            self.context.unregister_item(self.uuid)

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._user_data = kwargs.pop("user_data", self._user_data)
        before = kwargs.pop("before", None)
        parent = kwargs.pop("parent", None)
        if before is not None:
            self.attach_before(before)
        else:
            if parent is None:
                parent = self.context.fetch_next_parent()
            if parent is not None:
                self.attach_to_parent(parent)
        if "tag" in kwargs:
            tag = kwargs.pop("tag")
            self.context.update_registered_item_tag(self, self.uuid, tag)
        #if len(kwargs) > 0:
        #    print("Unused configure parameters: ", kwargs)
        return

    @property
    def user_data(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_data

    @user_data.setter
    def user_data(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._user_data = value

    @property
    def uuid(self):
        """
        Readonly attribute: uuid is an unique identifier created
        by the context for the item.
        uuid can be used to access the object by name for parent=,
        before=, after= arguments, but it is preferred to pass
        the objects directly. 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return int(self.uuid)

    @property
    def tag(self):
        """
        Writable attribute: tag is an optional string that uniquely
        defines the object.

        If set (else it is set to None), tag can be used to access
        the object by name for parent=, before=, after= arguments 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.context.get_registered_item_from_uuid(self.uuid)

    @tag.setter
    def tag(self, str tag):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.context.update_registered_item_tag(self, self.uuid, tag)

    @property
    def parent(self):
        """
        Writable attribute: parent of the item in the rendering tree.

        Rendering starts from the viewport. Then recursively each child
        is rendered from the first to the last, and each child renders
        their subtree.

        Only an item inserted in the rendering tree is rendered.
        An item that is not in the rendering tree can have children.
        Thus it is possible to build and configure various items, and
        attach them to the tree in a second phase.

        The children hold a reference to their parent, and the parent
        holds a reference to its children. Thus to be release memory
        held by an item, two options are possible:
        . Remove the item from the tree, remove all your references.
          If the item has children or siblings, the item will not be
          released until Python's garbage collection detects a
          circular reference.
        . Use delete_item to remove the item from the tree, and remove
          all the internal references inside the item structure and
          the item's children, thus allowing them to be removed from
          memory as soon as the user doesn't hold a reference on them.

        Note the viewport is referenced by the context.

        If you set this attribute, the item will be inserted at the last
        position of the children of the parent (regardless whether this
        item is already a child of the parent).
        If you set None, the item will be removed from its parent's children
        list.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._parent

    @parent.setter
    def parent(self, value):
        # It is important to not lock the mutex before the call
        if value is None:
            self.detach_item()
            return
        self.attach_to_parent(value)

    @property
    def previous_sibling(self):
        """
        Writable attribute: child of the parent of the item that
        is rendered just before this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just after the target item.
        In case of failure, the item remains in a detached state.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._prev_sibling

    @previous_sibling.setter
    def previous_sibling(self, baseItem target not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, target.mutex)
        # Convert into an attach_before or attach_to_parent
        next_sibling = target._next_sibling
        target_parent = target._parent
        m.unlock()
        # It is important to not lock the mutex before the call
        if next_sibling is None:
            if target_parent is not None:
                self.attach_to_parent(target_parent)
            else:
                raise ValueError("Cannot bind sibling if no parent")
        self.attach_before(next_sibling)

    @property
    def next_sibling(self):
        """
        Writable attribute: child of the parent of the item that
        is rendered just after this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just before the target item.
        In case of failure, the item remains in a detached state.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._next_sibling

    @next_sibling.setter
    def next_sibling(self, baseItem target not None):
        # It is important to not lock the mutex before the call
        self.attach_before(target)

    @property
    def children(self):
        """
        Readable attribute: List of all the children of the item,
        from first rendered, to last rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        # Note: the children structure is not allowed
        # to change when the parent mutex is held
        cdef baseItem item = self.last_theme_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        item = self.last_item_handler_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        item = self.last_global_handler_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        item = self.last_payloads_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        item = self.last_drawings_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        item = self.last_widgets_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        item = self.last_window_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        result.reverse()
        return result

    def __enter__(self):
        # Mutexes not needed
        self.context.push_next_parent(self)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.context.pop_next_parent()
        return False # Do not catch exceptions

    cdef void lock_parent_and_item_mutex(self,
                                         unique_lock[recursive_mutex] &parent_m,
                                         unique_lock[recursive_mutex] &item_m):
        # We must make sure we lock the correct parent mutex, and for that
        # we must access self._parent and thus hold the item mutex
        cdef bint locked = False
        while not(locked):
            lock_gil_friendly(item_m, self.mutex)
            if self._parent is not None:
                # Manipulate the lock directly
                # as we don't want unique lock to point
                # to a mutex which might be freed (if the
                # parent of the item is changed by another
                # thread and the parent freed)
                locked = self._parent.mutex.try_lock()
            else:
                locked = True
            if locked:
                if self._parent is not None:
                    # Transfert the lock
                    parent_m = unique_lock[recursive_mutex](self._parent.mutex)
                    self._parent.mutex.unlock()
                return
            item_m.unlock()
            if not(locked) and self.external_lock:
                raise RuntimeError(
                    "Trying to lock parent mutex while holding a lock. "
                    "If you get this error, this means you are attempting "
                    "to edit the children list of a parent of nodes you "
                    "hold a mutex to, but you are not holding a mutex of the "
                    "parent. As a result deadlock occured."
                    "To fix this issue:\n "
                    "If the item you are inserting in the parent's children "
                    "list is outside the rendering tree, (you didn't really "
                    " need a mutex) -> release your mutexes.\n "
                    "If the item is in the rendering tree you should lock first "
                    "the parent.")


    cdef void lock_and_previous_siblings(self) noexcept nogil:
        """
        Used when the parent needs to prevent any change to its
        children.
        Note when the parent mutex is held, it can rely that
        its list of children is fixed. However this is used
        when the parent needs to read the individual state
        of its children and needs these state to not change
        for some operations.
        """
        self.mutex.lock()
        if self._prev_sibling is not None:
            self._prev_sibling.lock_and_previous_siblings()

    cdef void unlock_and_previous_siblings(self) noexcept nogil:
        if self._prev_sibling is not None:
            self._prev_sibling.unlock_and_previous_siblings()
        self.mutex.unlock()

    cpdef void attach_to_parent(self, target):
        cdef baseItem target_parent
        if not(isinstance(target, baseItem)):
            target_parent = self.context[target]
        else:
            target_parent = <baseItem>target
        # We must ensure a single thread attaches at a given time.
        # __detach_item_and_lock will lock both the item lock
        # and the parent lock.
        cdef unique_lock[recursive_mutex] m0
        # In the case of manipulating the theme tree,
        # block all rendering. This is because with the
        # push/pop system, removing/adding items during
        # rendering cannot work
        if self.element_child_category == child_cat_theme:
            lock_gil_friendly(m0, self.context.viewport.mutex)

        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        self.__detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        if self.context is None:
            raise ValueError("Trying to attach a deleted item")
        if target_parent is None:
            # Shouldn't occur as should be caught by self.context[target]
            raise RuntimeError("Trying to attach to None")

        # Lock target parent mutex
        lock_gil_friendly(m2, target_parent.mutex)

        cdef bint attached = False

        # Attach to parent
        if self.element_child_category == child_cat_window and \
            target_parent.can_have_window_child:
            if target_parent.last_window_child is not None:
                lock_gil_friendly(m3, target_parent.last_window_child.mutex)
                target_parent.last_window_child._next_sibling = self
            self._prev_sibling = target_parent.last_window_child
            self._parent = target_parent
            target_parent.last_window_child = <dcgWindow_>self
            attached = True
        elif self.element_child_category == child_cat_ui and \
            target_parent.can_have_widget_child:
            if target_parent.last_widgets_child is not None:
                lock_gil_friendly(m3, target_parent.last_widgets_child.mutex)
                target_parent.last_widgets_child._next_sibling = self
            self._prev_sibling = target_parent.last_widgets_child
            self._parent = target_parent
            target_parent.last_widgets_child = <uiItem>self
            attached = True
        elif self.element_child_category == child_cat_drawing and \
            target_parent.can_have_drawing_child:
            if target_parent.last_drawings_child is not None:
                lock_gil_friendly(m3, target_parent.last_drawings_child.mutex)
                target_parent.last_drawings_child._next_sibling = self
            self._prev_sibling = target_parent.last_drawings_child
            self._parent = target_parent
            target_parent.last_drawings_child = <drawableItem>self
            attached = True
        elif self.element_child_category == child_cat_global_handler and \
            target_parent.can_have_global_handler_child:
            if target_parent.last_global_handler_child is not None:
                lock_gil_friendly(m3, target_parent.last_global_handler_child.mutex)
                target_parent.last_global_handler_child._next_sibling = self
            self._prev_sibling = target_parent.last_global_handler_child
            self._parent = target_parent
            target_parent.last_global_handler_child = <globalHandler>self
            attached = True
        elif self.element_child_category == child_cat_item_handler and \
            target_parent.can_have_item_handler_child:
            if target_parent.last_item_handler_child is not None:
                lock_gil_friendly(m3, target_parent.last_item_handler_child.mutex)
                target_parent.last_item_handler_child._next_sibling = self
            self._prev_sibling = target_parent.last_item_handler_child
            self._parent = target_parent
            target_parent.last_item_handler_child = <itemHandler>self
            attached = True
        elif self.element_child_category == child_cat_theme and \
            target_parent.can_have_theme_child:
            if target_parent.last_theme_child is not None:
                lock_gil_friendly(m3, target_parent.last_theme_child.mutex)
                target_parent.last_theme_child._next_sibling = self
            self._prev_sibling = target_parent.last_theme_child
            self._parent = target_parent
            target_parent.last_theme_child = <baseTheme>self
            attached = True
        if not(attached):
            raise ValueError("Instance of type {} cannot be attached to {}".format(type(self), type(target_parent)))

    cpdef void attach_before(self, target):
        cdef baseItem target_before
        if not(isinstance(target, baseItem)):
            target_before = self.context[target]
        else:
            target_before = <baseItem>target
        # We must ensure a single thread attaches at a given time.
        # __detach_item_and_lock will lock both the item lock
        # and the parent lock.
        cdef unique_lock[recursive_mutex] m0
        # In the case of manipulating the theme tree,
        # block all rendering. This is because with the
        # push/pop system, removing/adding items during
        # rendering cannot work
        if self.element_child_category == child_cat_theme:
            lock_gil_friendly(m0, self.context.viewport.mutex)

        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] target_before_m
        cdef unique_lock[recursive_mutex] target_parent_m
        self.__detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        if self.context is None:
            raise ValueError("Trying to attach a deleted item")

        if target_before is None:
            raise ValueError("target before cannot be None")

        # Lock target mutex and its parent mutex
        target_before.lock_parent_and_item_mutex(target_parent_m,
                                                 target_before_m)

        if target_before._parent is None:
            # We can bind to an unattached parent, but not
            # to unattached siblings. Could be implemented, but not trivial
            raise ValueError("Trying to attach to an un-attached sibling. Not yet supported")

        # Check the elements can indeed be siblings
        if not(self.can_have_sibling):
            raise ValueError("Instance of type {} cannot have a sibling".format(type(self)))
        if not(target_before.can_have_sibling):
            raise ValueError("Instance of type {} cannot have a sibling".format(type(target_before)))
        if self.element_child_category != target_before.element_child_category:
            raise ValueError("Instance of type {} cannot be sibling to {}".format(type(self), type(target_before)))

        # Attach to sibling
        cdef baseItem _prev_sibling = target_before._prev_sibling
        self._parent = target_before._parent
        # Potential deadlocks are avoided by the fact that we hold the parent
        # mutex and any lock of a next sibling must hold the parent
        # mutex.
        cdef unique_lock[recursive_mutex] prev_m
        if _prev_sibling is not None:
            lock_gil_friendly(prev_m, _prev_sibling.mutex)
            _prev_sibling._next_sibling = self
        self._prev_sibling = _prev_sibling
        self._next_sibling = target_before
        target_before._prev_sibling = self

    cdef void __detach_item_and_lock(self, unique_lock[recursive_mutex]& m):
        # NOTE: the mutex is not locked if we raise an exception.
        # Detach the item from its parent and siblings
        # We are going to change the tree structure, we must lock
        # the parent mutex first and foremost
        cdef unique_lock[recursive_mutex] parent_m
        self.lock_parent_and_item_mutex(parent_m, m)
        # Use unique lock for the mutexes to
        # simplify handling (parent will change)

        if self.parent is None:
            return # nothing to do

        # Remove this item from the list of siblings
        if self._prev_sibling is not None:
            with nogil:
                self._prev_sibling.mutex.lock()
            self._prev_sibling._next_sibling = self._next_sibling
            self._prev_sibling.mutex.unlock()
        if self._next_sibling is not None:
            with nogil:
                self._next_sibling.mutex.lock()
            self._next_sibling._prev_sibling = self._prev_sibling
            self._next_sibling.mutex.unlock()
        else:
            # No next sibling. We might be referenced in the
            # parent
            if self._parent is not None:
                if self._parent.last_window_child is self:
                    self._parent.last_window_child = self._prev_sibling
                elif self._parent.last_widgets_child is self:
                    self._parent.last_widgets_child = self._prev_sibling
                elif self._parent.last_drawings_child is self:
                    self._parent.last_drawings_child = self._prev_sibling
                elif self._parent.last_payloads_child is self:
                    self._parent.last_payloads_child = self._prev_sibling
                elif self._parent.last_global_handler_child is self:
                    self._parent.last_global_handler_child = self._prev_sibling
                elif self._parent.last_item_handler_child is self:
                    self._parent.last_item_handler_child = self._prev_sibling
                elif self._parent.last_theme_child is self:
                    self._parent.last_theme_child = self._prev_sibling
        # Free references
        self._parent = None
        self._prev_sibling = None
        self._next_sibling = None

    cpdef void detach_item(self):
        cdef unique_lock[recursive_mutex] m0
        cdef unique_lock[recursive_mutex] m
        # In the case of manipulating the theme tree,
        # block all rendering. This is because with the
        # push/pop system, removing/adding items during
        # rendering cannot work
        if self.element_child_category == child_cat_theme:
            lock_gil_friendly(m0, self.context.viewport.mutex)
        self.__detach_item_and_lock(m)

    cpdef void delete_item(self):
        cdef unique_lock[recursive_mutex] m0
        # In the case of manipulating the theme tree,
        # block all rendering. This is because with the
        # push/pop system, removing/adding items during
        # rendering cannot work
        if self.element_child_category == child_cat_theme:
            lock_gil_friendly(m0, self.context.viewport.mutex)

        cdef unique_lock[recursive_mutex] m
        self.__detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        if self.context is None:
            raise ValueError("Trying to delete a deleted item")

        # Remove this item from the list of elements
        if self._prev_sibling is not None:
            with nogil:
                self._prev_sibling.mutex.lock()
            self._prev_sibling._next_sibling = self._next_sibling
            self._prev_sibling.mutex.unlock()
        if self._next_sibling is not None:
            with nogil:
                self._next_sibling.mutex.lock()
            self._next_sibling._prev_sibling = self._prev_sibling
            self._next_sibling.mutex.unlock()
        else:
            # No next sibling. We might be referenced in the
            # parent
            if self._parent is not None:
                if self._parent.last_window_child is self:
                    self._parent.last_window_child = self._prev_sibling
                elif self._parent.last_widgets_child is self:
                    self._parent.last_widgets_child = self._prev_sibling
                elif self._parent.last_drawings_child is self:
                    self._parent.last_drawings_child = self._prev_sibling
                elif self._parent.last_payloads_child is self:
                    self._parent.last_payloads_child = self._prev_sibling
                elif self._parent.last_global_handler_child is self:
                    self._parent.last_global_handler_child = self._prev_sibling
                elif self._parent.last_item_handler_child is self:
                    self._parent.last_item_handler_child = self._prev_sibling
                elif self._parent.last_theme_child is self:
                    self._parent.last_theme_child = self._prev_sibling

        # delete all children recursively
        if self.last_window_child is not None:
            self.last_window_child.__delete_and_siblings()
        if self.last_widgets_child is not None:
            self.last_widgets_child.__delete_and_siblings()
        if self.last_drawings_child is not None:
            self.last_drawings_child.__delete_and_siblings()
        if self.last_payloads_child is not None:
            self.last_payloads_child.__delete_and_siblings()
        if self.last_global_handler_child is not None:
            self.last_global_handler_child.__delete_and_siblings()
        if self.last_item_handler_child is not None:
            self.last_item_handler_child.__delete_and_siblings()
        if self.last_theme_child is not None:
            self.last_theme_child.__delete_and_siblings()
        # Free references
        self.context = None
        self.last_window_child = None
        self.last_widgets_child = None
        self.last_drawings_child = None
        self.last_payloads_child = None
        self.last_global_handler_child = None
        self.last_item_handler_child = None
        self.last_theme_child = None

    cdef void __delete_and_siblings(self):
        # Must only be called from delete_item or itself.
        # Assumes the parent mutex is already held
        # and that we don't need to edit the parent last_*_child fields
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # delete all its children recursively
        if self.last_window_child is not None:
            self.last_window_child.__delete_and_siblings()
        if self.last_widgets_child is not None:
            self.last_widgets_child.__delete_and_siblings()
        if self.last_drawings_child is not None:
            self.last_drawings_child.__delete_and_siblings()
        if self.last_payloads_child is not None:
            self.last_payloads_child.__delete_and_siblings()
        if self.last_global_handler_child is not None:
            self.last_global_handler_child.__delete_and_siblings()
        if self.last_item_handler_child is not None:
            self.last_item_handler_child.__delete_and_siblings()
        if self.last_theme_child is not None:
            self.last_theme_child.__delete_and_siblings()
        # delete previous sibling
        if self._prev_sibling is not None:
            self._prev_sibling.__delete_and_siblings()
        # Free references
        self.context = None
        self._parent = None
        self._prev_sibling = None
        self._next_sibling = None
        self.last_window_child = None
        self.last_widgets_child = None
        self.last_drawings_child = None
        self.last_payloads_child = None
        self.last_global_handler_child = None
        self.last_item_handler_child = None
        self.last_theme_child = None

    def lock_mutex(self, wait=False):
        """
        Lock the internal item mutex.
        **Know what you are doing**
        Locking the mutex will prevent:
        . Other threads from reading/writing
          attributes or calling methods with this item,
          editing the children/parent of the item
        . Any rendering of this item and its children
          If the viewport attemps to render this item,
          it will be blocked until the mutex is released.
          (if the rendering thread is holding the mutex,
           no blocking occurs)
        This is useful if you want to edit several attributes
        in several commands of an item or its subtree,
        and prevent rendering or other threads from accessing
        the item until you have finished.
        If you plan on moving the item position in the rendering
        tree, to avoid deadlock you must hold the mutex of a
        parent of all the items involved in the motion (a common
        parent of the source and target parent). This mutex has to
        be locked before you lock any mutex of your child item
        if this item is already in the rendering tree (to avoid
        deadlock with the rendering thread).
        If you are unsure and plans to move an item already
        in the rendering tree, it is thus best to lock the viewport
        mutex first.

        Input argument:
        . wait (default = False): if locking the mutex fails (mutex
          held by another thread), wait it is released

        Returns: True if the mutex is held, False else.

        The mutex is a recursive mutex, thus you can lock it several
        times in the same thread. Each lock has to be matched to an unlock.
        """
        cdef bint locked = False
        locked = self.mutex.try_lock()
        if not(locked) and not(wait):
            return False
        if not(locked) and wait:
            with nogil:
                self.mutex.lock()
        self.external_lock += 1
        return True

    def unlock_mutex(self):
        """
        Unlock a previously held mutex on this object by this thread.
        Returns True on success, False if no lock was held by this thread.
        """
        cdef bint locked = False
        locked = self.mutex.try_lock()
        if locked and self.external_lock > 0:
            # We managed to lock and an external lock is held
            # thus we are indeed the owning thread
            self.mutex.unlock()
            self.external_lock -= 1
            self.mutex.unlock()
            return True
        return False




@cython.final
@cython.no_gc_clear
cdef class dcgViewport(baseItem):
    def __cinit__(self, context):
        self.resize_callback = None
        self.initialized = False
        self.viewport = NULL
        self.graphics_initialized = False
        self.can_have_window_child = True
        self.can_have_global_handler_child = True
        self.can_have_sibling = False

    def __dealloc__(self):
        # NOTE: Called BEFORE the context is released.
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.context.imgui_mutex)
        ensure_correct_im_context(self.context)
        if self.graphics_initialized:
            cleanup_graphics(self.graphics)
        if self.viewport != NULL:
            mvCleanupViewport(dereference(self.viewport))
            #self.viewport is freed by mvCleanupViewport
            self.viewport = NULL

    cdef initialize(self, unsigned width, unsigned height):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return (self.viewport.clearColor.r,
                self.viewport.clearColor.g,
                self.viewport.clearColor.b,
                self.viewport.clearColor.a)

    @clear_color.setter
    def clear_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int r, g, b, a
        self.__check_initialized()
        (r, g, b, a) = value
        self.viewport.clearColor = colorFromInts(r, g, b, a)

    @property
    def small_icon(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return str(self.viewport.small_icon)

    @small_icon.setter
    def small_icon(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.small_icon = value.encode("utf-8")

    @property
    def large_icon(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return str(self.viewport.large_icon)

    @large_icon.setter
    def large_icon(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.large_icon = value.encode("utf-8")

    @property
    def x_pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.xpos

    @x_pos.setter
    def x_pos(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.xpos = value
        self.viewport.posDirty = 1

    @property
    def y_pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.ypos

    @y_pos.setter
    def y_pos(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.ypos = value
        self.viewport.posDirty = 1

    @property
    def width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.actualWidth

    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.actualWidth = value
        self.viewport.sizeDirty = 1

    @property
    def height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.actualHeight

    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.actualHeight = value
        self.viewport.sizeDirty = 1

    @property
    def resizable(self) -> bint:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.resizable

    @resizable.setter
    def resizable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.resizable = value
        self.viewport.modesDirty = 1

    @property
    def vsync(self) -> bint:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.vsync

    @vsync.setter
    def vsync(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.vsync = value

    @property
    def min_width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.minwidth

    @min_width.setter
    def min_width(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.minwidth = value

    @property
    def max_width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.maxwidth

    @max_width.setter
    def max_width(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.maxwidth = value

    @property
    def min_height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.minheight

    @min_height.setter
    def min_height(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.minheight = value

    @property
    def max_height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.maxheight

    @max_height.setter
    def max_height(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.maxheight = value

    @property
    def always_on_top(self) -> bint:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.alwaysOnTop

    @always_on_top.setter
    def always_on_top(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.alwaysOnTop = value
        self.viewport.modesDirty = 1

    @property
    def decorated(self) -> bint:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.decorated

    @decorated.setter
    def decorated(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.decorated = value
        self.viewport.modesDirty = 1

    @property
    def theme(self):
        """
        Writable attribute: global theme
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    @property
    def title(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return str(self.viewport.title)

    @title.setter
    def title(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.title = value.encode("utf-8")
        self.viewport.titleDirty = 1

    @property
    def disable_close(self) -> bint:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.disableClose

    @disable_close.setter
    def disable_close(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        self.viewport.disableClose = value
        self.viewport.modesDirty = 1

    @property
    def fullscreen(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.fullScreen

    @fullscreen.setter
    def fullscreen(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        ensure_correct_im_context(self.context)
        if value and not(self.viewport.fullScreen):
            mvToggleFullScreen(dereference(self.viewport))
        elif not(value) and (self.viewport.fullScreen):
            print("TODO: fullscreen(false)")

    @property
    def minimized(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return None #TODO

    @minimized.setter
    def minimized(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        ensure_correct_im_context(self.context)
        if value:
            mvMinimizeViewport(dereference(self.viewport))
        else:
            mvRestoreViewport(dereference(self.viewport))

    @property
    def maximized(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return None #TODO

    @maximized.setter
    def maximized(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        ensure_correct_im_context(self.context)
        if value:
            mvMaximizeViewport(dereference(self.viewport))
        else:
            mvRestoreViewport(dereference(self.viewport))

    @property
    def waitForInputs(self):
        return self.viewport.waitForEvents

    @waitForInputs.setter
    def waitForInputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.waitForEvents = value

    @property
    def shown(self) -> bint:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_initialized()
        return self.viewport.shown

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        for (key, value) in kwargs.items():
            setattr(self, key, value)

    cdef void __on_resize(self, int width, int height):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        if self._theme is not None: # maybe apply in render_frame instead ?
            self._theme.push()
        #self.cullMode = 0
        self.perspectiveDivide = False
        self.depthClipping = False
        self.has_matrix_transform = False
        self.in_plot = False
        self.start_pending_theme_actions = 0
        #if self.filedialogRoots is not None:
        #    self.filedialogRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        #if self.colormapRoots is not None:
        #    self.colormapRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.last_window_child is not None:
            self.last_window_child.draw()
        #if self.viewportMenubarRoots is not None:
        #    self.viewportMenubarRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        #if self.last_viewport_drawlist_child is not None:
        #    self.last_viewport_drawlist_child.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        if self.last_global_handler_child is not None:
            self.last_global_handler_child.run_handler()
        if self._theme is not None:
            self._theme.pop()
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

    cdef void push_pending_theme_actions(self,
                                         theme_enablers theme_activation_condition_enabled,
                                         theme_categories theme_activation_condition_category) noexcept nogil:
        """
        Used during rendering to apply themes defined by items
        parents and that should activate based on specific conditions
        Returns the number of theme actions applied. This number
        should be returned to pop_applied_pending_theme_actions
        """
        self.current_theme_activation_condition_enabled = theme_activation_condition_enabled
        self.current_theme_activation_condition_category = theme_activation_condition_category
        self.push_pending_theme_actions_on_subset(self.start_pending_theme_actions,
                                                  <int>self.pending_theme_actions.size())

    cdef void push_pending_theme_actions_on_subset(self,
                                                   int start,
                                                   int end) noexcept nogil:
        cdef int i
        cdef int size_init = self.applied_theme_actions.size()
        cdef theme_action action
        cdef imgui.ImVec2 value_float2
        cdef theme_enablers theme_activation_condition_enabled = self.current_theme_activation_condition_enabled
        cdef theme_categories theme_activation_condition_category = self.current_theme_activation_condition_category

        cdef bool apply
        for i in range(start, end):
            apply = True
            if self.pending_theme_actions[i].activation_condition_enabled != theme_enablers.t_enabled_any and \
               theme_activation_condition_enabled != theme_enablers.t_enabled_any and \
               self.pending_theme_actions[i].activation_condition_enabled != theme_activation_condition_enabled:
                apply = False
            if self.pending_theme_actions[i].activation_condition_category != theme_activation_condition_category and \
               self.pending_theme_actions[i].activation_condition_category != theme_categories.t_any:
                apply = False
            if apply:
                action = self.pending_theme_actions[i]
                self.applied_theme_actions.push_back(action)
                if action.backend == theme_backends.t_imgui:
                    if action.type == theme_types.t_color:
                        # can only be theme_value_types.t_u32
                        imgui.PushStyleColor(<imgui.ImGuiCol>action.theme_index,
                                             action.value.value_u32)
                    elif action.type == theme_types.t_style:
                        if action.value_type == theme_value_types.t_float:
                            imgui.PushStyleVar(<imgui.ImGuiStyleVar>action.theme_index,
                                               action.value.value_float)
                        elif action.value_type == theme_value_types.t_float2:
                            value_float2 = imgui.ImVec2(action.value.value_float2[0],
                                                        action.value.value_float2[1])
                            imgui.PushStyleVar(<imgui.ImGuiStyleVar>action.theme_index,
                                               value_float2)
                elif action.backend == theme_backends.t_implot:
                    if action.type == theme_types.t_color:
                        # can only be theme_value_types.t_u32
                        implot.PushStyleColor(<implot.ImPlotCol>action.theme_index,
                                             action.value.value_u32)
                    elif action.type == theme_types.t_style:
                        if action.value_type == theme_value_types.t_float:
                            implot.PushStyleVar(<implot.ImPlotStyleVar>action.theme_index,
                                               action.value.value_float)
                        elif action.value_type == theme_value_types.t_int:
                            implot.PushStyleVar(<implot.ImPlotStyleVar>action.theme_index,
                                               action.value.value_int)
                        elif action.value_type == theme_value_types.t_float2:
                            value_float2 = imgui.ImVec2(action.value.value_float2[0],
                                                        action.value.value_float2[1])
                            implot.PushStyleVar(<implot.ImPlotStyleVar>action.theme_index,
                                               value_float2)
                elif action.backend == theme_backends.t_imnodes:
                    if action.type == theme_types.t_color:
                        # can only be theme_value_types.t_u32
                        imnodes.PushColorStyle(<imnodes.ImNodesCol>action.theme_index,
                                             action.value.value_u32)
                    elif action.type == theme_types.t_style:
                        if action.value_type == theme_value_types.t_float:
                            imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>action.theme_index,
                                               action.value.value_float)
                        elif action.value_type == theme_value_types.t_float2:
                            value_float2 = imnodes.ImVec2(action.value.value_float2[0],
                                                        action.value.value_float2[1])
                            imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>action.theme_index,
                                               value_float2)
        self.applied_theme_actions_count.push_back(self.applied_theme_actions.size() - size_init)

    cdef void pop_applied_pending_theme_actions(self) noexcept nogil:
        """
        Used during rendering to pop what push_pending_theme_actions did
        """
        cdef int count = self.applied_theme_actions_count.back()
        self.applied_theme_actions_count.pop_back()
        if count == 0:
            return
        cdef int i
        cdef int size = self.applied_theme_actions.size()
        cdef theme_action action
        for i in range(count):
            action = self.applied_theme_actions[size-i-1]
            if action.backend == theme_backends.t_imgui:
                if action.type == theme_types.t_color:
                    imgui.PopStyleColor(1)
                elif action.type == theme_types.t_style:
                    imgui.PopStyleVar(1)
            elif action.backend == theme_backends.t_implot:
                if action.type == theme_types.t_color:
                    implot.PopStyleColor(1)
                elif action.type == theme_types.t_style:
                    implot.PopStyleVar(1)
            elif action.backend == theme_backends.t_imnodes:
                if action.type == theme_types.t_color:
                    imnodes.PopColorStyle()
                elif action.type == theme_types.t_style:
                    imnodes.PopStyleVar(1)
        for i in range(count):
            self.applied_theme_actions.pop_back()


    def render_frame(self):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        self.__check_initialized()
        # Note: imgui calls are only allowed during the frame rendering, thus we can
        # make this call only here. In addition we could only lock the imgui_mutex
        # here for this reason.
        ensure_correct_im_context(self.context)
        assert(self.graphics_initialized)
        with nogil:
            m.unlock()
            mvRenderFrame(dereference(self.viewport),
			    		  self.graphics)
            m.lock()
        if self.viewport.resized:
            if self.resize_callback is not None:
                dimensions = (self.viewport.actualWidth,
                              self.viewport.actualHeight,
                              self.viewport.clientWidth,
                              self.viewport.clientHeight)
                self.context.queue.submit(self.resize_callback, constants.MV_APP_UUID, dimensions)
            self.viewport.resized = False
        assert(self.pending_theme_actions.empty())
        assert(self.applied_theme_actions.empty())
        assert(self.start_pending_theme_actions == 0)

    def show(self, minimized=False, maximized=False):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
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


cdef class drawableItem(baseItem):
    def __cinit__(self):
        self.show = True
        self.can_have_sibling = True

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <bint>self.show
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.show = value

    cdef void draw_prev_siblings(self, imgui.ImDrawList* l, float x, float y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<drawableItem>self._prev_sibling).draw(l, x, y)

    cdef void draw(self, imgui.ImDrawList* l, float x, float y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(l, x, y)

"""
PlaceHolder parent
To store items outside the rendering tree
Can be parent to anything.
Cannot have any parent. Thus cannot render.
"""
cdef class dcgPlaceHolderParent(baseItem):
    def __cinit__(self):
        self.can_have_window_child = True
        self.can_have_widget_child = True
        self.can_have_drawing_child = True
        self.can_have_payload_child = True
        self.can_have_theme_child = True
        self.can_have_global_handler_child = True
        self.can_have_item_handler_child = True

"""
Drawing items
"""


cdef class drawingItem(drawableItem):
    def __cinit__(self):
        self.element_child_category = child_cat_drawing

cdef class dcgDrawList_(drawingItem):
    def __cinit__(self):
        self.imgui_label = b'###%ld'% self.uuid
        self.clip_width = 0
        self.clip_height = 0
        self.can_have_drawing_child = True

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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

        if imgui.InvisibleButton(self.imgui_label.c_str(),
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
        # TODO: create child category to attach to viewport

    cdef void draw(self,
                   imgui.ImDrawList* parent_drawlist,
                   float parent_x,
                   float parent_y) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        self.can_have_sibling = True
        self.element_child_category = child_cat_global_handler
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.enabled = kwargs.pop("enabled", self.enabled)
        self.enabled = kwargs.pop("show", self.enabled)
        callback = kwargs.pop("callback", self.callback)
        self.callback = callback if isinstance(callback, dcgCallback) else dcgCallback(callback)
        return super().configure(**kwargs)
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.enabled = value
    @property
    def callback(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.callback
    @callback.setter
    def callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.callback = value if isinstance(value, dcgCallback) or value is None else dcgCallback(value)
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        return
    cdef void run_callback(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.queue_callback_noarg(self.callback, self)

cdef class dcgGlobalHandlerList(globalHandler):
    def __cinit__(self):
        self.can_have_global_handler_child = True
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
        if self.last_global_handler_child is not None:
            (<globalHandler>self.last_global_handler_child).run_handler()
        return

cdef class dcgKeyDownHandler_(globalHandler):
    def __cinit__(self):
        self.key = imgui.ImGuiKey_None

    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiKeyData *key_info
        cdef int i
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
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
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
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
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
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
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
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
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
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
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
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
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseDragging(i, self.threshold):
                delta = imgui.GetMouseDragDelta(i, self.threshold)
                self.context.queue_callback_arg1int2float(self.callback, self, i, delta.x, delta.y)


cdef class dcgMouseMoveHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
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
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self.button >= 0 and self.button != i:
                continue
            if imgui.IsMouseReleased(i):
                self.context.queue_callback_arg1int(self.callback, self, i)

cdef class dcgMouseWheelHandler(globalHandler):
    cdef void run_handler(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<globalHandler>self._prev_sibling).run_handler()
        if not(self.enabled):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if abs(io.MouseWheel) > 0.:
            self.context.queue_callback_arg1float(self.callback, self, io.MouseWheel)

"""
Sources
"""

cdef class shared_value:
    def __init__(self, *args, **kwargs):
        # We create all shared objects using __new__, thus
        # bypassing __init__. If __init__ is called, it's
        # from the user.
        # __init__ is called after __cinit__
        self._num_attached = 0
    def __cinit__(self, dcgContext context, *args, **kwargs):
        self.context = context
        self._last_frame_change = context.frame
        self._last_frame_update = context.frame
        self._num_attached = 1
    @property
    def value(self):
        return None
    @value.setter
    def value(self, value):
        if value is None:
            # In case of automated backup of
            # the value of all items
            return
        raise ValueError("Shared value is empty. Cannot set.")

    @property
    def last_frame_update(self):
        """
        Readable attribute: last frame index when the value
        was updated (can be identical value).
        """
        return self._last_frame_update

    @property
    def last_frame_change(self):
        """
        Readable attribute: last frame index when the value
        was changed (different value).
        For non-scalar data (color, point, vector), equals to
        last_frame_update to avoid heavy comparisons.
        """
        return self._last_frame_change

    @property
    def num_attached(self):
        """
        Readable attribute: Number of items sharing this value
        """
        return self._num_attached

    cdef void on_update(self, bint changed) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        # TODO: figure out if not using mutex is ok
        self._last_frame_update = self.context.frame
        if changed:
            self._last_frame_change = self.context.frame

    cdef void inc_num_attached(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._num_attached += 1

    cdef void dec_num_attached(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._num_attached -= 1


cdef class shared_bool(shared_value):
    def __init__(self, dcgContext context, bint value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef bint get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, bint value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class shared_float(shared_value):
    def __init__(self, dcgContext context, float value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef float get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, float value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class shared_int(shared_value):
    def __init__(self, dcgContext context, int value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef int get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, int value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class shared_color(shared_value):
    def __init__(self, dcgContext context, value):
        self._value = parse_color(value)
        self._value_asfloat4 = imgui.ColorConvertU32ToFloat4(self._value)
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        "Color data is an int32 (rgba, little endian),\n" \
        "If you pass an array of int (r, g, b, a), or float\n" \
        "(r, g, b, a) normalized it will get converted automatically"
        return <int>self._value
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value = parse_color(value)
        self._value_asfloat4 = imgui.ColorConvertU32ToFloat4(self._value)
        self.on_update(True)
    cdef imgui.ImU32 getU32(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef imgui.ImVec4 getF4(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value_asfloat4
    cdef void setU32(self, imgui.ImU32 value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value = value
        self._value_asfloat4 = imgui.ColorConvertU32ToFloat4(self._value)
        self.on_update(True)
    cdef void setF4(self, imgui.ImVec4 value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value_asfloat4 = value
        self._value = imgui.ColorConvertFloat4ToU32(self._value_asfloat4)
        self.on_update(True)

cdef class shared_double(shared_value):
    def __init__(self, dcgContext context, double value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef double get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, double value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class shared_str(shared_value):
    def __init__(self, dcgContext context, str value):
        self._value = bytes(str(value), 'utf-8')
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._value)
    @value.setter
    def value(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value = bytes(str(value), 'utf-8')
        self.on_update(True)
    cdef void get(self, string& out) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        out = self._value
    cdef void set(self, string value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value = value
        self.on_update(True)

cdef class shared_float4(shared_value):
    def __init__(self, dcgContext context, value):
        read_point[float](self._value, value)
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._value, value)
        self.on_update(True)
    cdef void get(self, float *dst) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, float[4] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]
        self.on_update(True)

cdef class shared_int4(shared_value):
    def __init__(self, dcgContext context, value):
        read_point[int](self._value, value)
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[int](self._value, value)
        self.on_update(True)
    cdef void get(self, int *dst) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, int[4] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]
        self.on_update(True)

cdef class shared_double4(shared_value):
    def __init__(self, dcgContext context, value):
        read_point[double](self._value, value)
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self._value, value)
        self.on_update(True)
    cdef void get(self, double *dst) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, double[4] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]
        self.on_update(True)

cdef class shared_floatvect(shared_value):
    def __init__(self, dcgContext context, value):
        self._value = value
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return np.copy(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value = np.copy(value)
        self.on_update(True)
    cdef float[:] get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, float[:] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value = value
        self.on_update(True)

"""
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
        self.can_have_sibling = True
        self.element_child_category = child_cat_item_handler
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.enabled = kwargs.pop("enabled", self.enabled)
        self.enabled = kwargs.pop("show", self.enabled)
        return super().configure(**kwargs)
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.enabled = value

    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)

    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)

    cdef void run_callback(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.queue_callback_noarg(self.callback, self)

cdef class dcgItemHandlerList(itemHandler):
    def __cinit__(self):
        self.can_have_item_handler_child = True

    cdef void check_bind(self, uiItem item):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).check_bind(item)
        if self.last_item_handler_child is not None:
            (<itemHandler>self.last_item_handler_child).check_bind(item)

    cdef void run_handler(self, uiItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<itemHandler>self._prev_sibling).run_handler(item)
        if self.last_item_handler_child is not None:
            (<itemHandler>self.last_item_handler_child).run_handler(item)

cdef inline object IntPairFromVec2(imgui.ImVec2 v):
    return (<int>v.x, <int>v.y)

cdef class uiItem(baseItem):
    def __cinit__(self):
        # mvAppItemInfo
        self.imgui_label = b'###%ld'% self.uuid
        self.user_label = ""
        self.show = True
        self._enabled = True
        self.can_be_disabled = False
        #self.location = -1
        # next frame triggers
        self.focus_update_requested = False
        self.show_update_requested = False
        self.size_update_requested = True
        self.pos_update_requested = False
        self.enabled_update_requested = False
        self.last_frame_update = 0 # last frame update occured
        # mvAppItemConfig
        #self.filter = b""
        #self.alias = b""
        self.payloadType = b"$$DPG_PAYLOAD"
        self.requested_size = imgui.ImVec2(0., 0.)
        self._indent = 0.
        self.theme_condition_enabled = theme_enablers.t_enabled_any
        self.theme_condition_category = theme_categories.t_any
        self.can_have_sibling = True
        self.element_child_category = child_cat_ui
        #self.trackOffset = 0.5 # 0.0f:top, 0.5f:center, 1.0f:bottom
        #self.tracked = False
        self.dragCallback = None
        self.dropCallback = None
        self._value = shared_value(self.context) # To be changed by class

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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

    cpdef object output_current_item_state(self):
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
        if self._prev_sibling is not None:
            (<uiItem>self._prev_sibling).set_hidden_and_propagate()
        self.update_current_state_as_hidden()

    def bind_handlers(self, itemHandler handlers):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # Check the list of handlers can use our states. Else raise error
        handlers.check_bind(self)
        # yes: bind
        self.handlers = handlers

    # TODO: Find a better way to share all these attributes while avoiding AttributeError

    @property
    def active(self):
        """
        Readonly attribute: is the item active
        """
        if not(self.state.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.toggled

    @property
    def visible(self):
        """
        True if the item was rendered (inside the rendering region + show = True
        for the item and its ancestors). Not impacted by occlusion.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.visible

    @property
    def content_region_avail(self):
        """
        Region available for the current element size if scrolling was disallowed
        """
        if not(self.state.has_content_region):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.content_region)

    @property
    def rect_min(self):
        """
        Requested minimum size (width, height) allowed for the item.
        Writable attribute
        """
        if not(self.state.has_rect_min):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.rect_min)

    @rect_min.setter
    def rect_min(self, value):
        if not(self.state.has_rect_min):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        if len(value) != 2:
            raise ValueError("Expected tuple for rect_min: (width, height)")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.rect_max)

    @rect_max.setter
    def rect_max(self, value):
        if not(self.state.has_rect_max):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        if len(value) != 2:
            raise ValueError("Expected tuple for rect_max: (width, height)")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.rect_max.x = value[0]
        self.state.rect_max.y = value[1]

    @property
    def rect_size(self):
        """
        Readonly attribute: actual (width, height) of the element
        """
        if not(self.state.has_rect_size):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.rect_size)

    @property
    def callback(self):
        """
        Writable attribute: callback object which is called when the value
        of the item is changed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._callback

    @callback.setter
    def callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._callback = value if isinstance(value, dcgCallback) or value is None else dcgCallback(value)

    @property
    def enabled(self):
        """
        Writable attribute: Should the object be displayed as enabled ?
        the enabled state can be used to prevent edition of editable fields,
        or to use a specific disabled element theme.
        Note a disabled item is still rendered. Use show=False to hide
        an object.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self.can_be_disabled) and value != True:
            raise AttributeError(f"Objects of type {type(self)} cannot be disabled")
        self.theme_condition_enabled = theme_enablers.t_enabled_True if value else theme_enablers.t_enabled_False
        self.enabled_update_requested = True
        self._enabled = value

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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self.requested_size.y

    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.y = <float>value
        self.state.rect_size.y = <float>value
        self.size_update_requested = True

    @property
    def indent(self):
        """
        Writable attribute: requested indentation relative to the parent of the item.
        (No effect on top-level windows)
        0 means no indentation.
        Negative value means use an indentation of the default width.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._indent

    @indent.setter
    def indent(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._indent = value

    @property
    def label(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        """
        Writable attribute: label assigned to the item.
        Used for text fields, window titles, etc
        """
        return self.user_label
    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self.user_label = ""
        else:
            self.user_label = value
        # Using ### means that imgui will ignore the user_label for
        # its internal ID of the object. Indeed else the ID would change
        # when the user label would change
        self.imgui_label = bytes(self.user_label, 'utf-8') + b'###%ld'% self.uuid

    @property
    def pos(self):
        """
        Writable attribute: Relative position (x, y) of the element inside
        the drawable region of the parent.
        Setting a value will override the default position, while
        setting an empty value will reset to the default position next
        time the object is drawn.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.relative_position)

    @pos.setter
    def pos(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or len(value) == 0:
            # Used to indicate "keep default value" during init
            self.pos_update_requested = False # Reset to default position for items
            return
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        self.state.relative_position.x = value[0]
        self.state.relative_position.y = value[1]
        self.pos_update_requested = True

    @property
    def value(self):
        """
        Writable attribute: main internal value for the object.
        For buttons, it is set when pressed; For text it is the
        text itself; For selectable whether it is selected, etc.
        Reading the value attribute returns a copy, while writing
        to the value attribute will edit the field of the value.
        In case the value is shared among items, setting the value
        attribute will change it for all the sharing items.
        To share a value attribute among objects, one should use
        the shareable_value attribute
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value.value

    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value.value = value

    @property
    def shareable_value(self):
        """
        Same as the value field, but rather than a copy of the internal value
        of the object, return a python object that holds a value field that
        is in sync with the internal value of the object. This python object
        can be passed to other items using an internal value of the same
        type to share it.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value

    @shareable_value.setter
    def shareable_value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._value is value:
            return
        if type(self._value) is not type(value):
            raise ValueError(f"Expected a shareable value of type {type(self._value)}. Received {type(value)}")
        self._value.dec_num_attached()
        self._value = value
        self._value.inc_num_attached()

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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <bint>self._show
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.show_update_requested = True
        self._show = value

    @property
    def theme(self):
        """
        Writable attribute: bound theme for the item
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self.requested_size.x

    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.x = <float>value
        self.state.rect_size.x = <float>value
        self.size_update_requested = True

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<uiItem>self._prev_sibling).draw()

        if not(self._show):
            if self.show_update_requested:
                self.set_hidden_and_propagate()
                self.show_update_requested = False
            return

        if self.focus_update_requested:
            if self.state.focused:
                imgui.SetKeyboardFocusHere(0)
            self.focus_update_requested = False

        # Does not affect all items, but is cheap to set
        if self.requested_size.x != 0:
            imgui.SetNextItemWidth(self.requested_size.x)

        # If the position is user set, it would probably
        # make more sense to apply indent after (else it will
        # have not effect, and thus is likely not the expected behaviour).
        # However this will shift relative_position, updated by
        # update_current_state. If needed we could restore relative_position ?
        # For now make the indent have no effect when the position is set
        if self._indent != 0.:
            imgui.Indent(self._indent)

        cdef ImVec2 cursor_pos_backup
        if self.pos_update_requested:
            cursor_pos_backup = imgui.GetCursorPos()
            imgui.SetCursorPos(self.state.relative_position)
            # Never reset self.pos_update_requested as we always
            # need to set at the requested position 

        # handle fonts
        """
        if self.font:
            ImFont* fontptr = static_cast<mvFont*>(item.font.get())->getFontPtr();
            ImGui::PushFont(fontptr);
        """

        # themes
        self.context.viewport.push_pending_theme_actions(
            self.theme_condition_enabled,
            self.theme_condition_category
        )
        if self._theme is not None:
            self._theme.push()

        cdef bint action = self.draw_item()
        if action:
            self.context.queue_callback_arg1value(self._callback, self, self._value)

        if self._theme is not None:
            self._theme.pop()
        self.context.viewport.pop_applied_pending_theme_actions()

        if self.handlers is not None:
            self.handlers.run_handler(self)

        if self.pos_update_requested:
            imgui.SetCursorPos(cursor_pos_backup)

        if self._indent != 0.:
            imgui.Unindent(self._indent)


    cdef bint draw_item(self) noexcept nogil:
        """
        Function to override for the core rendering of the item.
        What is already handled outside draw_item (see draw()):
        . The mutex is held (as is the mutex of the following siblings,
          and the mutex of the parents, including the viewport and imgui
          mutexes)
        . The previous siblings are already rendered
        . Current themes, fonts
        . Widget starting position (GetCursorPos to get it)
        . Focus

        What remains to be done by draw_item:
        . Rendering the item. Set its width, its height, etc
        . Calling update_current_state or manage itself the state
        . Render children if any

        The return value indicates if the main callback should be triggered.
        """
        return False

"""
Simple ui items
"""

cdef class dcgSimplePlot(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_simpleplot
        self._value = <shared_value>(shared_floatvect.__new__(shared_floatvect, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True
        self._scale_min = 0.
        self._scale_max = 0.
        self.histogram = False
        self._autoscale = True
        self.last_frame_autoscale_update = -1

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # Map old attribute names (the new names are handled in uiItem)
        self._scale_min = kwargs.pop("scaleMin", self._scale_min)
        self._scale_max = kwargs.pop("scaleMax", self._scale_max)
        self._autoscale = kwargs.pop("autosize", self._autoscale)
        return super().configure(**kwargs)

    @property
    def scale_min(self):
        """
        Writable attribute: value corresponding to the minimum value of plot scale
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_min

    @scale_min.setter
    def scale_min(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_min = value

    @property
    def scale_max(self):
        """
        Writable attribute: value corresponding to the maximum value of plot scale
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_max

    @scale_max.setter
    def scale_max(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_max = value

    @property
    def histogram(self):
        """
        Writable attribute: Whether the data should be plotted as an histogram
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._histogram

    @histogram.setter
    def histogram(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._histogram = value

    @property
    def autoscale(self):
        """
        Writable attribute: Whether scale_min and scale_max should be deduced
        from the data
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._autoscale

    @autoscale.setter
    def autoscale(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._autoscale = value

    @property
    def overlay(self):
        """
        Writable attribute: Overlay text
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._overlay

    @overlay.setter
    def overlay(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._overlay = bytes(str(value), 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        cdef float[:] data = shared_floatvect.get(<shared_floatvect>self._value)
        cdef int i
        if self._autoscale and data.shape[0] > 0:
            if self._value._last_frame_change != self.last_frame_autoscale_update:
                self.last_frame_autoscale_update = self._value._last_frame_change
                self._scale_min = data[0]
                self._scale_max = data[0]
                for i in range(1, data.shape[0]):
                    if self._scale_min > data[i]:
                        self._scale_min = data[i]
                    if self._scale_max < data[i]:
                        self._scale_max = data[i]

        if self._histogram:
            imgui.PlotHistogram(self.imgui_label.c_str(),
                                &data[0],
                                <int>data.shape[0],
                                0,
                                self._overlay.c_str(),
                                self._scale_min,
                                self._scale_max,
                                self.requested_size,
                                sizeof(float))
        else:
            imgui.PlotLines(self.imgui_label.c_str(),
                            &data[0],
                            <int>data.shape[0],
                            0,
                            self._overlay.c_str(),
                            self._scale_min,
                            self._scale_max,
                            self.requested_size,
                            sizeof(float))
        self.update_current_state()
        return False

cdef class dcgButton(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_button
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True
        self._direction = imgui.ImGuiDir_Up
        self._small = False
        self._arrow = False
        self._repeat = False

    @property
    def direction(self):
        """
        Writable attribute: Direction of the arrow if any
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._direction

    @direction.setter
    def direction(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < imgui.ImGuiDir_None or value >= imgui.ImGuiDir_COUNT:
            raise ValueError("Invalid direction {value}")
        self._direction = <imgui.ImGuiDir>value

    @property
    def small(self):
        """
        Writable attribute: Whether to display a small button
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._small

    @small.setter
    def small(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._small = value

    @property
    def arrow(self):
        """
        Writable attribute: Whether to display an arrow.
        Not compatible with small
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._arrow

    @arrow.setter
    def arrow(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._arrow = value

    @property
    def repeat(self):
        """
        Writable attribute: Whether to generate many clicked events
        when the button is held repeatedly, instead of a single.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat

    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value

    cdef bint draw_item(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint activated
        imgui.PushItemFlag(imgui.ImGuiItemFlags_ButtonRepeat, self._repeat)
        if self._small:
            activated = imgui.SmallButton(self.imgui_label.c_str())
        elif self._arrow:
            activated = imgui.ArrowButton(self.imgui_label.c_str(), self._direction)
        else:
            activated = imgui.Button(self.imgui_label.c_str(),
                                     self.requested_size)
        imgui.PopItemFlag()
        self.update_current_state()
        shared_bool.set(<shared_bool>self._value, self.state.active) # Unsure. Not in original
        return activated


cdef class dcgCombo(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_combo
        self._value = <shared_value>(shared_str.__new__(shared_str, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        # Frankly unsure why these. Should it include popup ?:
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True
        self.flags = imgui.ImGuiComboFlags_HeightRegular

    @property
    def items(self):
        """
        Writable attribute: List of text values to select
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [str(v, encoding='utf-8') for v in self._items]

    @items.setter
    def items(self, value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(bytes(value, 'utf-8'))
        elif hasattr(value, '__len__'):
            for v in value:
                self._items.push_back(bytes(v, 'utf-8'))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")
        lock_gil_friendly(value_m, self._value.mutex)
        if self._value.num_attached == 1 and \
           self._value._last_frame_update == -1 and \
           self._items.size() > 0:
            # initialize the value with the first element
            shared_str.set(<shared_str>self._value, self._items[0])

    @property
    def height_mode(self):
        """
        Writable attribute: height mode of the combo.
        0: small
        1: regular
        2: large
        3: largest
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (self.flags & imgui.ImGuiComboFlags_HeightSmall) != 0:
            return 0
        elif (self.flags & imgui.ImGuiComboFlags_HeightLargest) != 0:
            return 3
        elif (self.flags & imgui.ImGuiComboFlags_HeightLarge) != 0:
            return 2
        return 1

    @height_mode.setter
    def height_mode(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value >= 4:
            raise ValueError("Invalid height mode {value}")
        self.flags &= ~(imgui.ImGuiComboFlags_HeightSmall |
                        imgui.ImGuiComboFlags_HeightRegular |
                        imgui.ImGuiComboFlags_HeightLarge |
                        imgui.ImGuiComboFlags_HeightLargest)
        if value == 0:
            self.flags |= imgui.ImGuiComboFlags_HeightSmall
        elif value == 1:
            self.flags |= imgui.ImGuiComboFlags_HeightRegular
        elif value == 2:
            self.flags |= imgui.ImGuiComboFlags_HeightLarge
        else:
            self.flags |= imgui.ImGuiComboFlags_HeightLargest

    @property
    def popup_align_left(self):
        """
        Writable attribute: Whether to align left
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiComboFlags_PopupAlignLeft) != 0

    @popup_align_left.setter
    def popup_align_left(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiComboFlags_PopupAlignLeft
        if value:
            self.flags |= imgui.ImGuiComboFlags_PopupAlignLeft

    @property
    def no_arrow_button(self):
        """
        Writable attribute: Whether the combo should not display an arrow on top
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiComboFlags_NoArrowButton) != 0

    @no_arrow_button.setter
    def no_arrow_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiComboFlags_NoArrowButton
        if value:
            self.flags |= imgui.ImGuiComboFlags_NoArrowButton

    @property
    def no_preview(self):
        """
        Writable attribute: Whether the preview should be disabled
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiComboFlags_NoPreview) != 0

    @no_preview.setter
    def no_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiComboFlags_NoPreview
        if value:
            self.flags |= imgui.ImGuiComboFlags_NoPreview

    @property
    def fit_width(self):
        """
        Writable attribute: Whether the combo should fit available width
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiComboFlags_WidthFitPreview) != 0

    @fit_width.setter
    def fit_width(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiComboFlags_WidthFitPreview
        if value:
            self.flags |= imgui.ImGuiComboFlags_WidthFitPreview

    cdef bint draw_item(self) noexcept nogil:
        cdef bint open
        cdef int i
        cdef string current_value
        shared_str.get(<shared_str>self._value, current_value)
        open = imgui.BeginCombo(self.imgui_label.c_str(),
                                current_value.c_str(),
                                self.flags)
        # Old code called update_current_state now, and updated edited state
        # later. Looking at ImGui code there seems to be two items. One
        # for the combo, and one for the popup that opens. The edited flag
        # is not set, looking at imgui demo so we have to handle it manually.
        self.state.activated = not(self.state.active) and open
        self.state.deactivated = self.state.active and not(open)
        self.state.active = open
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.focused = imgui.IsItemFocused()
        self.state.hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.clicked[i] = self.state.hovered and imgui.IsItemClicked(i)
            self.state.double_clicked[i] = self.state.hovered and imgui.IsMouseDoubleClicked(i)


        cdef bool pressed = False
        cdef bint changed = False
        cdef bool selected
        cdef bool selected_backup
        # we push an ID because we didn't append ###uuid to the items
        
        # TODO: there are nice ImGuiSelectableFlags to add in the future
        if open:
            imgui.PushID(self.uuid)
            if self._enabled:
                for i in range(<int>self._items.size()):
                    selected = self._items[i] == current_value
                    selected_backup = selected
                    pressed |= imgui.Selectable(self._items[i].c_str(),
                                                &selected,
                                                imgui.ImGuiSelectableFlags_None,
                                                self.requested_size)
                    if selected:
                        imgui.SetItemDefaultFocus()
                    if selected and selected != selected_backup:
                        changed = True
                        shared_str.set(<shared_str>self._value, self._items[i])
            else:
                # TODO: test
                selected = True
                imgui.Selectable(current_value.c_str(),
                                 &selected,
                                 imgui.ImGuiSelectableFlags_Disabled,
                                 self.requested_size)
            imgui.PopID()
            imgui.EndCombo()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.edited = changed
        self.state.deactivated_after_edited = self.state.deactivated and changed
        return pressed


cdef class dcgCheckbox(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_checkbox
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.state.can_be_activated = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.can_be_disabled = True
        self.theme_condition_enabled = theme_enablers.t_enabled_True
        

    cdef bint draw_item(self) noexcept nogil:
        cdef bool checked = shared_bool.get(<shared_bool>self._value)
        cdef bint pressed = imgui.Checkbox(self.imgui_label.c_str(),
                                             &checked)
        if self._enabled:
            shared_bool.set(<shared_bool>self._value, checked)
        self.update_current_state()
        return pressed

cdef class dcgSlider(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_slider
        self._format = 1
        self._size = 1
        self._drag = False
        self._drag_speed = 1.
        self._print_format = b"%.3f"
        self.flags = 0
        self._min = 0.
        self._max = 100.
        self._vertical = False
        self._value = <shared_value>(shared_float.__new__(shared_float, self.context))
        self.state.can_be_active = True # unsure
        self.state.can_be_clicked = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.can_be_disabled = True
        self.theme_condition_enabled = theme_enablers.t_enabled_True

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # Since some options cancel each other, one
        # must enable them in a specific order
        if "format" in kwargs:
            self.format = kwargs.pop("format")
        if "size" in kwargs:
            self.size = kwargs.pop("size")
        if "logarithmic" in kwargs:
            self.logarithmic = kwargs.pop("logarithmic")
        # baseItem configure will configure the rest.
        return super().configure(**kwargs)

    @property
    def format(self):
        """
        Writable attribute: Format of the slider.
        Must be "int", "float" or "double".
        Note that float here means the 32 bits version.
        The python float corresponds to a double.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._format == 1:
            return "float"
        elif self._format == 0:
            return "int"
        return "double"

    @format.setter
    def format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int target_format
        if value == "int":
            target_format = 0
        elif value == "float":
            target_format = 1
        elif value == "double":
            target_format = 2
        else:
            raise ValueError(f"Expected 'int', 'float' or 'double'. Got {value}")
        if target_format == self._format:
            return
        self._format = target_format
        # Allocate a new value of the right type
        previous_value = self.value # Pass though the property to do the conversion for us
        if self._size == 1:
            if target_format == 0:
                self._value = <shared_value>(shared_int.__new__(shared_int, self.context))
            elif target_format == 0:
                self._value = <shared_value>(shared_float.__new__(shared_float, self.context))
            else:
                self._value = <shared_value>(shared_double.__new__(shared_double, self.context))
        else:
            if target_format == 0:
                self._value = <shared_value>(shared_int4.__new__(shared_int4, self.context))
                self.value = previous_value
            elif target_format == 0:
                self._value = <shared_value>(shared_float4.__new__(shared_float4, self.context))
            else:
                self._value = <shared_value>(shared_double4.__new__(shared_double4, self.context))
        self.value = previous_value # Use property to pass through python for the conversion
        self._print_format = b"%d" if target_format == 0 else b"%.3f"

    @property
    def size(self):
        """
        Writable attribute: Size of the slider.
        Can be 1, 2, 3 or 4.
        When 1 the item's value is held with
        a scalar shared value, else it is held
        with a vector of 4 elements (even for
        size 2 and 3)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
        

    @size.setter
    def size(self, int target_size):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if target_size < 0 or target_size > 4:
            raise ValueError(f"Expected 1, 2, 3, or 4 for size. Got {target_size}")
        if self._size == target_size:
            return
        if (self._size > 1 and target_size > 1):
            self._size = target_size
            return
        # Reallocate the internal vector
        previous_value = self.value # Pass though the property to do the conversion for us
        if target_size == 1:
            if self._format == 0:
                self._value = <shared_value>(shared_int.__new__(shared_int, self.context))
            elif self._format == 1:
                self._value = <shared_value>(shared_float.__new__(shared_float, self.context))
            else:
                self._value = <shared_value>(shared_double.__new__(shared_double, self.context))
            self.value = previous_value[0]
        else:
            if self._format == 0:
                self._value = <shared_value>(shared_int4.__new__(shared_int4, self.context))
                self.value = previous_value
            elif self._format == 1:
                self._value = <shared_value>(shared_float4.__new__(shared_float4, self.context))
            else:
                self._value = <shared_value>(shared_double4.__new__(shared_double4, self.context))
            self.value = (previous_value, 0, 0, 0)
        self._size = target_size

    @property
    def clamped(self):
        """
        Writable attribute: Whether the slider value should be clamped even when keyboard set
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSliderFlags_AlwaysClamp) != 0

    @clamped.setter
    def clamped(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiSliderFlags_AlwaysClamp
        if value:
            self.flags |= imgui.ImGuiSliderFlags_AlwaysClamp

    @property
    def drag(self):
        """
        Writable attribute: Whether the use a 'drag'
        slider rather than a regular one.
        Incompatible with 'vertical'.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._drag

    @drag.setter
    def drag(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._drag = value
        if value:
            self._vertical = False

    @property
    def logarithmic(self):
        """
        Writable attribute: Make the slider logarithmic.
        Disables round_to_format if enabled
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSliderFlags_Logarithmic) != 0

    @logarithmic.setter
    def logarithmic(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~(imgui.ImGuiSliderFlags_Logarithmic | imgui.ImGuiSliderFlags_NoRoundToFormat)
        if value:
            self.flags |= (imgui.ImGuiSliderFlags_Logarithmic | imgui.ImGuiSliderFlags_NoRoundToFormat)

    @property
    def min_value(self):
        """
        Writable attribute: Minimum value the slider
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min_value.setter
    def min_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value

    @property
    def max_value(self):
        """
        Writable attribute: Maximum value the slider
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max_value.setter
    def max_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value

    @property
    def no_input(self):
        """
        Writable attribute: Disable Ctrl+Click and Enter key to
        manually set the value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSliderFlags_NoInput) != 0

    @no_input.setter
    def no_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiSliderFlags_NoInput
        if value:
            self.flags |= imgui.ImGuiSliderFlags_NoInput

    @property
    def print_format(self):
        """
        Writable attribute: format string
        for the value -> string conversion
        for display. If round_to_format is
        enabled, the value is converted
        back and thus appears rounded.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(bytes(self._print_format), encoding="utf-8")

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = bytes(value, 'utf-8')

    @property
    def round_to_format(self):
        """
        Writable attribute: If set (default),
        the value will not have more digits precision
        than the requested format string for display.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSliderFlags_NoRoundToFormat) == 0

    @round_to_format.setter
    def round_to_format(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value and (self.flags & imgui.ImGuiSliderFlags_Logarithmic) != 0:
            # Note this is not a limitation from imgui, but they strongly
            # advise not to combine both, and thus we let the user do his
            # own rounding if he really wants to.
            raise ValueError("round_to_format cannot be enabled with logarithmic set")
        self.flags &= ~imgui.ImGuiSliderFlags_NoRoundToFormat
        if not(value):
            self.flags |= imgui.ImGuiSliderFlags_NoRoundToFormat

    @property
    def speed(self):
        """
        Writable attribute: When drag is true,
        this attributes sets the drag speed.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._drag_speed

    @speed.setter
    def speed(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._drag_speed = value

    @property
    def vertical(self):
        """
        Writable attribute: Whether the use a vertical
        slider. Only sliders of size 1 and drag False
        are supported.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._vertical

    @vertical.setter
    def vertical(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._size != 1:
            return
        self._drag = False
        self._vertical = value
        if value:
            self._drag = False

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiSliderFlags flags = self.flags
        if not(self._enabled):
            flags |= imgui.ImGuiSliderFlags_NoInput
        cdef imgui.ImGuiDataType type
        cdef int value_int
        cdef float value_float
        cdef double value_double
        cdef int[4] value_int4
        cdef float[4] value_float4
        cdef double[4] value_double4
        cdef void *data
        cdef void *data_min
        cdef void *data_max
        cdef bint modified
        cdef int imin, imax
        cdef float fmin, fmax
        cdef double dmin, dmax
        # Prepare data type
        if self._format == 0:
            type = imgui.ImGuiDataType_S32
            imin = <int>self._min
            imax = <int>self._max
            data_min = &imin
            data_max = &imax
        elif self._format == 1:
            type = imgui.ImGuiDataType_Float
            fmin = <float>self._min
            fmax = <float>self._max
            data_min = &fmin
            data_max = &fmax
        else:
            type = imgui.ImGuiDataType_Double
            dmin = <double>self._min
            dmax = <double>self._max
            data_min = &dmin
            data_max = &dmax

        # Read the value
        if self._format == 0:
            if self._size == 1:
                value_int = shared_int.get(<shared_int>self._value)
                data = &value_int
            else:
                shared_int4.get(<shared_int4>self._value, value_int4)
                data = &value_int4
        elif self._format == 1:
            if self._size == 1:
                value_float = shared_float.get(<shared_float>self._value)
                data = &value_float
            else:
                shared_float4.get(<shared_float4>self._value, value_float4)
                data = &value_float4
        else:
            if self._size == 1:
                value_double = shared_double.get(<shared_double>self._value)
                data = &value_double
            else:
                shared_double4.get(<shared_double4>self._value, value_double4)
                data = &value_double4

        # Draw
        if self._drag:
            if self._size == 1:
                modified = imgui.DragScalar(self.imgui_label.c_str(),
                                            type,
                                            data,
                                            self._drag_speed,
                                            data_min,
                                            data_max,
                                            self._print_format.c_str(),
                                            flags)
            else:
                modified = imgui.DragScalarN(self.imgui_label.c_str(),
                                             type,
                                             data,
                                             self._size,
                                             self._drag_speed,
                                             data_min,
                                             data_max,
                                             self._print_format.c_str(),
                                             flags)
        else:
            if self._size == 1:
                if self._vertical:
                    modified = imgui.VSliderScalar(self.imgui_label.c_str(),
                                                   self.requested_size,
                                                   type,
                                                   data,
                                                   data_min,
                                                   data_max,
                                                   self._print_format.c_str(),
                                                   flags)
                else:
                    modified = imgui.SliderScalar(self.imgui_label.c_str(),
                                                  type,
                                                  data,
                                                  data_min,
                                                  data_max,
                                                  self._print_format.c_str(),
                                                  flags)
            else:
                modified = imgui.SliderScalarN(self.imgui_label.c_str(),
                                               type,
                                               data,
                                               self._size,
                                               data_min,
                                               data_max,
                                               self._print_format.c_str(),
                                               flags)
		
        # Write the value
        if self._enabled:
            if self._format == 0:
                if self._size == 1:
                    shared_int.set(<shared_int>self._value, value_int)
                else:
                    shared_int4.set(<shared_int4>self._value, value_int4)
            elif self._format == 1:
                if self._size == 1:
                    shared_float.set(<shared_float>self._value, value_float)
                else:
                    shared_float4.set(<shared_float4>self._value, value_float4)
            else:
                if self._size == 1:
                    shared_double.set(<shared_double>self._value, value_double)
                else:
                    shared_double4.set(<shared_double4>self._value, value_double4)
        self.update_current_state()
        return modified


cdef class dcgListBox(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_listbox
        self._value = <shared_value>(shared_str.__new__(shared_str, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self._num_items_shown_when_open = -1
        # Frankly unsure why these. Should it include popup ?:
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # Support for old args
        self._num_items_shown_when_open = kwargs.pop("num_items", self._num_items_shown_when_open)
        # baseItem configure will configure the rest.
        return super().configure(**kwargs)

    @property
    def items(self):
        """
        Writable attribute: List of text values to select
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [str(v, encoding='utf-8') for v in self._items]

    @items.setter
    def items(self, value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(bytes(value, 'utf-8'))
        elif hasattr(value, '__len__'):
            for v in value:
                self._items.push_back(bytes(v, 'utf-8'))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")
        lock_gil_friendly(value_m, self._value.mutex)
        if self._value.num_attached == 1 and \
           self._value._last_frame_update == -1 and \
           self._items.size() > 0:
            # initialize the value with the first element
            shared_str.set(<shared_str>self._value, self._items[0])

    @property
    def num_items_shown_when_open(self):
        """
        Writable attribute: Number of items
        shown when the menu is opened
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_items_shown_when_open

    @num_items_shown_when_open.setter
    def num_items_shown_when_open(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_items_shown_when_open = value

    cdef bint draw_item(self) noexcept nogil:
        # TODO: Merge with ComboBox
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint open
        cdef int i
        cdef string current_value
        shared_str.get(<shared_str>self._value, current_value)
        cdef imgui.ImVec2 popup_size = imgui.ImVec2(0., 0.)
        cdef float text_height = imgui.GetTextLineHeightWithSpacing()
        cdef int num_items = min(7, <int>self._items.size())
        if self._num_items_shown_when_open > 0:
            num_items = self._num_items_shown_when_open
        # Computation from imgui
        popup_size.y = trunc(<float>0.25 + <float>num_items) * text_height
        popup_size.y += 2. * imgui.GetStyle().FramePadding.y
        open = imgui.BeginListBox(self.imgui_label.c_str(),
                                  popup_size)

        # Old code called update_current_state now, and updated edited state
        # later. Looking at ImGui code there seems to be two items. One
        # for the combo, and one for the popup that opens. The edited flag
        # is not set, looking at imgui demo so we have to handle it manually.
        self.state.activated = not(self.state.active) and open
        self.state.deactivated = self.state.active and not(open)
        self.state.active = open
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.focused = imgui.IsItemFocused()
        self.state.hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.clicked[i] = self.state.hovered and imgui.IsItemClicked(i)
            self.state.double_clicked[i] = self.state.hovered and imgui.IsMouseDoubleClicked(i)


        cdef bool pressed = False
        cdef bint changed = False
        cdef bool selected
        cdef bool selected_backup
        # we push an ID because we didn't append ###uuid to the items
        
        # TODO: there are nice ImGuiSelectableFlags to add in the future
        # TODO: use clipper
        if open:
            imgui.PushID(self.uuid)
            if self._enabled:
                for i in range(<int>self._items.size()):
                    imgui.PushID(i)
                    selected = self._items[i] == current_value
                    selected_backup = selected
                    pressed |= imgui.Selectable(self._items[i].c_str(),
                                                &selected,
                                                imgui.ImGuiSelectableFlags_None,
                                                self.requested_size)
                    if selected:
                        imgui.SetItemDefaultFocus()
                    if selected and selected != selected_backup:
                        changed = True
                        shared_str.set(<shared_str>self._value, self._items[i])
                    imgui.PopID()
            else:
                # TODO: test
                selected = True
                imgui.Selectable(current_value.c_str(),
                                 &selected,
                                 imgui.ImGuiSelectableFlags_Disabled,
                                 self.requested_size)
            imgui.PopID()
            imgui.EndListBox()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.edited = changed
        self.state.deactivated_after_edited = self.state.deactivated and changed
        return pressed


cdef class dcgRadioButton(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_radiobutton
        self._value = <shared_value>(shared_str.__new__(shared_str, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self._horizontal = False
        # Frankly unsure why these. Should it include popup ?:
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True

    @property
    def items(self):
        """
        Writable attribute: List of text values to select
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [str(v, encoding='utf-8') for v in self._items]

    @items.setter
    def items(self, value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(bytes(value, 'utf-8'))
        elif hasattr(value, '__len__'):
            for v in value:
                self._items.push_back(bytes(v, 'utf-8'))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")
        lock_gil_friendly(value_m, self._value.mutex)
        if self._value.num_attached == 1 and \
           self._value._last_frame_update == -1 and \
           self._items.size() > 0:
            # initialize the value with the first element
            shared_str.set(<shared_str>self._value, self._items[0])

    @property
    def horizontal(self):
        """
        Writable attribute: Horizontal vs vertical placement
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._horizontal

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._horizontal = value

    cdef bint draw_item(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint open
        cdef int i
        cdef string current_value
        shared_str.get(<shared_str>self._value, current_value)
        imgui.PushID(self.uuid)
        imgui.BeginGroup()

        cdef bint changed = False
        cdef bool selected
        cdef bool selected_backup
        # we push an ID because we didn't append ###uuid to the items
        
        imgui.PushID(self.uuid)
        for i in range(<int>self._items.size()):
            imgui.PushID(i)
            if (self._horizontal and i != 0):
                imgui.SameLine(0., -1.)
            selected_backup = self._items[i] == current_value
            selected = imgui.RadioButton(self._items[i].c_str(),
                                         selected_backup)
            if self._enabled and selected and selected != selected_backup:
                changed = True
                shared_str.set(<shared_str>self._value, self._items[i])
            imgui.PopID()
        imgui.EndGroup()
        imgui.PopID()
        self.update_current_state()
        return changed


cdef class dcgInputText(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_inputtext
        self._value = <shared_value>(shared_str.__new__(shared_str, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        # Frankly unsure why these. Should it include popup ?:
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True
        self._multiline = False
        self._max_characters = 1024
        self.flags = imgui.ImGuiInputTextFlags_None

    @property
    def hint(self):
        """
        Writable attribute: text hint.
        Doesn't work with multiline.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._hint, encoding='utf-8')

    @hint.setter
    def hint(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._hint = bytes(value, 'utf-8')
        if len(value) > 0:
            self.multiline = False

    @property
    def multiline(self):
        """
        Writable attribute: multiline text input.
        Doesn't work with non-empty hint.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._multiline

    @multiline.setter
    def multiline(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._multiline = value
        if value:
            self._hint = b""

    @property
    def max_characters(self):
        """
        Writable attribute: Maximal number of characters that can be written
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max_characters

    @max_characters.setter
    def max_characters(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 1:
            raise ValueError("There must be at least space for one character")
        self._max_characters = value

    @property
    def decimal(self):
        """
        Writable attribute: Allow 0123456789.+-
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsDecimal) != 0

    @decimal.setter
    def decimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsDecimal
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsDecimal

    @property
    def hexadecimal(self):
        """
        Writable attribute:  Allow 0123456789ABCDEFabcdef
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsHexadecimal) != 0

    @hexadecimal.setter
    def hexadecimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsHexadecimal
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsHexadecimal

    @property
    def scientific(self):
        """
        Writable attribute: Allow 0123456789.+-*/eE
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsScientific) != 0

    @scientific.setter
    def scientific(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsScientific
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsScientific

    @property
    def uppercase(self):
        """
        Writable attribute: Turn a..z into A..Z
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsUppercase) != 0

    @uppercase.setter
    def uppercase(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsUppercase
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsUppercase

    @property
    def no_spaces(self):
        """
        Writable attribute: Filter out spaces, tabs
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsNoBlank) != 0

    @no_spaces.setter
    def no_spaces(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsNoBlank
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsNoBlank

    @property
    def tab_input(self):
        """
        Writable attribute: Pressing TAB input a '\t' character into the text field
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_AllowTabInput) != 0

    @tab_input.setter
    def tab_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_AllowTabInput
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_AllowTabInput

    @property
    def on_enter(self):
        """
        Writable attribute: Callback called everytime Enter is pressed,
        not just when the value is modified.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_EnterReturnsTrue) != 0

    @on_enter.setter
    def on_enter(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_EnterReturnsTrue
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_EnterReturnsTrue

    @property
    def escape_clears_all(self):
        """
        Writable attribute: Escape key clears content if not empty,
        and deactivate otherwise
        (contrast to default behavior of Escape to revert)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_EscapeClearsAll) != 0

    @escape_clears_all.setter
    def escape_clears_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_EscapeClearsAll
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_EscapeClearsAll

    @property
    def ctrl_enter_for_new_line(self):
        """
        Writable attribute: In multi-line mode, validate with Enter,
        add new line with Ctrl+Enter
        (default is opposite: validate with Ctrl+Enter, add line with Enter).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CtrlEnterForNewLine) != 0

    @ctrl_enter_for_new_line.setter
    def ctrl_enter_for_new_line(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CtrlEnterForNewLine
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CtrlEnterForNewLine

    @property
    def readonly(self):
        """
        Writable attribute: Read-only mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_ReadOnly) != 0

    @readonly.setter
    def readonly(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_ReadOnly
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_ReadOnly

    @property
    def password(self):
        """
        Writable attribute: Password mode, display all characters as '*', disable copy
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_Password) != 0

    @password.setter
    def password(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_Password
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_Password

    @property
    def always_overwrite(self):
        """
        Writable attribute: Overwrite mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_AlwaysOverwrite) != 0

    @always_overwrite.setter
    def always_overwrite(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_AlwaysOverwrite
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_AlwaysOverwrite

    @property
    def auto_select_all(self):
        """
        Writable attribute: Select entire text when first taking mouse focus
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_AutoSelectAll) != 0

    @auto_select_all.setter
    def auto_select_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_AutoSelectAll
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_AutoSelectAll

    @property
    def no_horizontal_scroll(self):
        """
        Writable attribute: Disable following the scroll horizontally
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_NoHorizontalScroll) != 0

    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_NoHorizontalScroll
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_NoHorizontalScroll

    @property
    def no_undo_redo(self):
        """
        Writable attribute: Disable undo/redo.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_NoUndoRedo) != 0

    @no_undo_redo.setter
    def no_undo_redo(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_NoUndoRedo
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_NoUndoRedo

    cdef bint draw_item(self) noexcept nogil:
        cdef string current_value
        cdef imgui.ImGuiInputTextFlags flags = self.flags
        shared_str.get(<shared_str>self._value, current_value)
        cdef char* data = current_value.data()

        cdef bint changed = False
        if not(self._enabled):
            flags |= imgui.ImGuiInputTextFlags_ReadOnly
        if current_value.size() != (self._max_characters+1):
            # In theory the +1 is not needed here
            current_value.resize(self._max_characters+1)
        if self._multiline:
            changed = imgui.InputTextMultiline(self.imgui_label.c_str(),
                                               data,
                                               self._max_characters+1,
                                               self.requested_size,
                                               self.flags,
                                               NULL, NULL)
        elif self._hint.empty():
            changed = imgui.InputText(self.imgui_label.c_str(),
                                      data,
                                      self._max_characters+1,
                                      self.flags,
                                      NULL, NULL)
        else:
            changed = imgui.InputTextWithHint(self.imgui_label.c_str(),
                                              self._hint.c_str(),
                                              data,
                                              self._max_characters+1,
                                              self.flags,
                                              NULL, NULL)
        self.update_current_state()
        if not(self._enabled):
            changed = False
            self.state.edited = False
            self.state.deactivated_after_edited = False
            self.state.activated = False
            self.state.active = False
            self.state.deactivated = False
        return changed

ctypedef fused clamp_types:
    int
    float
    double

cdef inline void clamp1(clamp_types &value, double lower, double upper) noexcept nogil:
    if lower != -INFINITY:
        value = <clamp_types>max(<double>value, lower)
    if upper != INFINITY:
        value = <clamp_types>min(<double>value, upper)

cdef inline void clamp4(clamp_types[4] &value, double lower, double upper) noexcept nogil:
    if lower != -INFINITY:
        value[0] = <clamp_types>max(<double>value[0], lower)
        value[1] = <clamp_types>max(<double>value[1], lower)
        value[2] = <clamp_types>max(<double>value[2], lower)
        value[3] = <clamp_types>max(<double>value[3], lower)
    if upper != INFINITY:
        value[0] = <clamp_types>min(<double>value[0], upper)
        value[1] = <clamp_types>min(<double>value[1], upper)
        value[2] = <clamp_types>min(<double>value[2], upper)
        value[3] = <clamp_types>min(<double>value[3], upper)

cdef class dcgInputValue(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_inputvalue
        self._format = 1
        self._size = 1
        self._print_format = b"%.3f"
        self.flags = 0
        self._min = -INFINITY
        self._max = INFINITY
        self._step = 0.1
        self._step_fast = 1.
        self.flags = imgui.ImGuiInputTextFlags_None
        self._value = <shared_value>(shared_float.__new__(shared_float, self.context))
        self.state.can_be_active = True # unsure
        self.state.can_be_clicked = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.can_be_disabled = True
        self.theme_condition_enabled = theme_enablers.t_enabled_True

    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # Since some options cancel each other, one
        # must enable them in a specific order
        if "format" in kwargs:
            self.format = kwargs.pop("format")
        if "size" in kwargs:
            self.size = kwargs.pop("size")
        # legacy support
        if "min_clamped" in kwargs:
            if kwargs.pop("min_clamped"):
                self._min = kwargs.pop("minv", 0.)
        if "max_clamped" in kwargs:
            if kwargs.pop("max_clamped"):
                self._max = kwargs.pop("maxv", 100.)
        if "minv" in kwargs:
            del kwargs["minv"]
        if "maxv" in kwargs:
            del kwargs["maxv"]
        # baseItem configure will configure the rest.
        return super().configure(**kwargs)

    @property
    def format(self):
        """
        Writable attribute: Format of the slider.
        Must be "int", "float" or "double".
        Note that float here means the 32 bits version.
        The python float corresponds to a double.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._format == 1:
            return "float"
        elif self._format == 0:
            return "int"
        return "double"

    @format.setter
    def format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int target_format
        if value == "int":
            target_format = 0
        elif value == "float":
            target_format = 1
        elif value == "double":
            target_format = 2
        else:
            raise ValueError(f"Expected 'int', 'float' or 'double'. Got {value}")
        if target_format == self._format:
            return
        self._format = target_format
        # Allocate a new value of the right type
        previous_value = self.value # Pass though the property to do the conversion for us
        if self._size == 1:
            if target_format == 0:
                self._value = <shared_value>(shared_int.__new__(shared_int, self.context))
            elif target_format == 0:
                self._value = <shared_value>(shared_float.__new__(shared_float, self.context))
            else:
                self._value = <shared_value>(shared_double.__new__(shared_double, self.context))
        else:
            if target_format == 0:
                self._value = <shared_value>(shared_int4.__new__(shared_int4, self.context))
                self.value = previous_value
            elif target_format == 0:
                self._value = <shared_value>(shared_float4.__new__(shared_float4, self.context))
            else:
                self._value = <shared_value>(shared_double4.__new__(shared_double4, self.context))
        self.value = previous_value # Use property to pass through python for the conversion
        self._print_format = b"%d" if target_format == 0 else b"%.3f"

    @property
    def size(self):
        """
        Writable attribute: Size of the slider.
        Can be 1, 2, 3 or 4.
        When 1 the item's value is held with
        a scalar shared value, else it is held
        with a vector of 4 elements (even for
        size 2 and 3)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
        

    @size.setter
    def size(self, int target_size):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if target_size < 0 or target_size > 4:
            raise ValueError(f"Expected 1, 2, 3, or 4 for size. Got {target_size}")
        if self._size == target_size:
            return
        if (self._size > 1 and target_size > 1):
            self._size = target_size
            return
        # Reallocate the internal vector
        previous_value = self.value # Pass though the property to do the conversion for us
        if target_size == 1:
            if self._format == 0:
                self._value = <shared_value>(shared_int.__new__(shared_int, self.context))
            elif self._format == 1:
                self._value = <shared_value>(shared_float.__new__(shared_float, self.context))
            else:
                self._value = <shared_value>(shared_double.__new__(shared_double, self.context))
            self.value = previous_value[0]
        else:
            if self._format == 0:
                self._value = <shared_value>(shared_int4.__new__(shared_int4, self.context))
                self.value = previous_value
            elif self._format == 1:
                self._value = <shared_value>(shared_float4.__new__(shared_float4, self.context))
            else:
                self._value = <shared_value>(shared_double4.__new__(shared_double4, self.context))
            self.value = (previous_value, 0, 0, 0)
        self._size = target_size

    @property
    def step(self):
        """
        Writable attribute: 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._step

    @step.setter
    def step(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._step = value

    @property
    def step_fast(self):
        """
        Writable attribute: 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._step_fast

    @step_fast.setter
    def step_fast(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._step_fast = value

    @property
    def min_value(self):
        """
        Writable attribute: Minimum value the input
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min_value.setter
    def min_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value

    @property
    def max_value(self):
        """
        Writable attribute: Maximum value the input
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max_value.setter
    def max_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value

    @property
    def print_format(self):
        """
        Writable attribute: format string
        for the value -> string conversion
        for display. If round_to_format is
        enabled, the value is converted
        back and thus appears rounded.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(bytes(self._print_format), encoding="utf-8")

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = bytes(value, 'utf-8')

    @property
    def decimal(self):
        """
        Writable attribute: Allow 0123456789.+-
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsDecimal) != 0

    @decimal.setter
    def decimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsDecimal
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsDecimal

    @property
    def hexadecimal(self):
        """
        Writable attribute:  Allow 0123456789ABCDEFabcdef
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsHexadecimal) != 0

    @hexadecimal.setter
    def hexadecimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsHexadecimal
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsHexadecimal

    @property
    def scientific(self):
        """
        Writable attribute: Allow 0123456789.+-*/eE
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_CharsScientific) != 0

    @scientific.setter
    def scientific(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_CharsScientific
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_CharsScientific

    @property
    def on_enter(self):
        """
        Writable attribute: Callback called everytime Enter is pressed,
        not just when the value is modified.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_EnterReturnsTrue) != 0

    @on_enter.setter
    def on_enter(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_EnterReturnsTrue
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_EnterReturnsTrue

    @property
    def escape_clears_all(self):
        """
        Writable attribute: Escape key clears content if not empty,
        and deactivate otherwise
        (contrast to default behavior of Escape to revert)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_EscapeClearsAll) != 0

    @escape_clears_all.setter
    def escape_clears_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_EscapeClearsAll
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_EscapeClearsAll

    @property
    def readonly(self):
        """
        Writable attribute: Read-only mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_ReadOnly) != 0

    @readonly.setter
    def readonly(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_ReadOnly
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_ReadOnly

    @property
    def password(self):
        """
        Writable attribute: Password mode, display all characters as '*', disable copy
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_Password) != 0

    @password.setter
    def password(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_Password
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_Password

    @property
    def always_overwrite(self):
        """
        Writable attribute: Overwrite mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_AlwaysOverwrite) != 0

    @always_overwrite.setter
    def always_overwrite(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_AlwaysOverwrite
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_AlwaysOverwrite

    @property
    def auto_select_all(self):
        """
        Writable attribute: Select entire text when first taking mouse focus
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_AutoSelectAll) != 0

    @auto_select_all.setter
    def auto_select_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_AutoSelectAll
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_AutoSelectAll

    @property
    def empty_as_zero(self):
        """
        Writable attribute: parse empty string as zero value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_ParseEmptyRefVal) != 0

    @empty_as_zero.setter
    def empty_as_zero(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_ParseEmptyRefVal
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_ParseEmptyRefVal

    @property
    def empty_if_zero(self):
        """
        Writable attribute: when value is zero, do not display it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_DisplayEmptyRefVal) != 0

    @empty_if_zero.setter
    def empty_if_zero(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_DisplayEmptyRefVal
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_DisplayEmptyRefVal

    @property
    def no_horizontal_scroll(self):
        """
        Writable attribute: Disable following the scroll horizontally
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_NoHorizontalScroll) != 0

    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_NoHorizontalScroll
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_NoHorizontalScroll

    @property
    def no_undo_redo(self):
        """
        Writable attribute: Disable undo/redo.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiInputTextFlags_NoUndoRedo) != 0

    @no_undo_redo.setter
    def no_undo_redo(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiInputTextFlags_NoUndoRedo
        if value:
            self.flags |= imgui.ImGuiInputTextFlags_NoUndoRedo

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiInputTextFlags flags = self.flags
        if not(self._enabled):
            flags |= imgui.ImGuiInputTextFlags_ReadOnly
        cdef imgui.ImGuiDataType type
        cdef int value_int
        cdef float value_float
        cdef double value_double
        cdef int[4] value_int4
        cdef float[4] value_float4
        cdef double[4] value_double4
        cdef void *data
        cdef void *data_step
        cdef void *data_step_fast
        cdef bint modified
        cdef int istep, istep_fast
        cdef float fstep, fstep_fast
        cdef double dstep, dstep_fast
        # Prepare data type
        if self._format == 0:
            type = imgui.ImGuiDataType_S32
            istep = <int>self._step
            istep_fast = <int>self._step_fast
            data_step = &istep
            data_step_fast = &istep_fast
        elif self._format == 1:
            type = imgui.ImGuiDataType_Float
            fstep = <float>self._step
            fstep_fast = <float>self._step_fast
            data_step = &fstep
            data_step_fast = &fstep_fast
        else:
            type = imgui.ImGuiDataType_Double
            dstep = <double>self._step
            dstep_fast = <double>self._step_fast
            data_step = &dstep
            data_step_fast = &dstep_fast

        # Read the value
        if self._format == 0:
            if self._size == 1:
                value_int = shared_int.get(<shared_int>self._value)
                data = &value_int
            else:
                shared_int4.get(<shared_int4>self._value, value_int4)
                data = &value_int4
        elif self._format == 1:
            if self._size == 1:
                value_float = shared_float.get(<shared_float>self._value)
                data = &value_float
            else:
                shared_float4.get(<shared_float4>self._value, value_float4)
                data = &value_float4
        else:
            if self._size == 1:
                value_double = shared_double.get(<shared_double>self._value)
                data = &value_double
            else:
                shared_double4.get(<shared_double4>self._value, value_double4)
                data = &value_double4

        # Draw
        if self._size == 1:
            modified = imgui.InputScalar(self.imgui_label.c_str(),
                                         type,
                                         data,
                                         data_step,
                                         data_step_fast,
                                         self._print_format.c_str(),
                                         flags)
        else:
            modified = imgui.InputScalarN(self.imgui_label.c_str(),
                                          type,
                                          data,
                                          self._size,
                                          data_step,
                                          data_step_fast,
                                          self._print_format.c_str(),
                                          flags)

        # Clamp and write the value
        if self._enabled:
            if self._format == 0:
                if self._size == 1:
                    if modified:
                        clamp1[int](value_int, self._min, self._max)
                    shared_int.set(<shared_int>self._value, value_int)
                else:
                    if modified:
                        clamp4[int](value_int4, self._min, self._max)
                    shared_int4.set(<shared_int4>self._value, value_int4)
            elif self._format == 1:
                if self._size == 1:
                    if modified:
                        clamp1[float](value_float, self._min, self._max)
                    shared_float.set(<shared_float>self._value, value_float)
                else:
                    if modified:
                        clamp4[float](value_float4, self._min, self._max)
                    shared_float4.set(<shared_float4>self._value, value_float4)
            else:
                if self._size == 1:
                    if modified:
                        clamp1[double](value_double, self._min, self._max)
                    shared_double.set(<shared_double>self._value, value_double)
                else:
                    if modified:
                        clamp4[double](value_double4, self._min, self._max)
                    shared_double4.set(<shared_double4>self._value, value_double4)
            modified = modified and (self._value._last_frame_update == self._value._last_frame_change)
        self.update_current_state()
        return modified


cdef class dcgText(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_text
        self._color = 0 # invisible
        self._wrap = -1
        self._bullet = False
        self._show_label = False
        self._value = <shared_value>(shared_str.__new__(shared_str, self.context))
        self.state.can_be_active = True # unsure
        self.state.can_be_clicked = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True
        self.theme_condition_enabled = theme_enablers.t_enabled_True

    @property
    def color(self):
        """
        Writable attribute: text color.
        If set to 0 (default), that is
        full transparent text, use the
        default value given by the style
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._color

    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def label(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        """
        Writable attribute: label assigned to the item.
        Used for text fields, window titles, etc
        """
        return self.user_label
    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self.user_label = ""
        else:
            self.user_label = value
        # uuid is not used for text, and we don't want to
        # add it when we show the label, thus why we override
        # the label property here.
        self.imgui_label = bytes(self.user_label, 'utf-8')

    @property
    def wrap(self):
        """
        Writable attribute: wrap width
        -1 for no wrapping
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._wrap

    @wrap.setter
    def wrap(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._wrap = value

    @property
    def bullet(self):
        """
        Writable attribute: Whether to add a bullet
        before the text
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._bullet

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._bullet = value

    @property
    def show_label(self):
        """
        Writable attribute: Whether to display the
        label next to the text stored in value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show_label

    @show_label.setter
    def show_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._show_label = value

    cdef bint draw_item(self) noexcept nogil:
        imgui.AlignTextToFramePadding()
        if self._color > 0:
            imgui.PushStyleColor(imgui.ImGuiCol_Text, self._color)
        if self._wrap == 0:
            imgui.PushTextWrapPos(0.)
        elif self._wrap > 0:
            imgui.PushTextWrapPos(imgui.GetCursorPosX() + <float>self._wrap)
        if self._show_label or self._bullet:
            imgui.BeginGroup()
        if self._bullet:
            imgui.Bullet()

        cdef string current_value
        shared_str.get(<shared_str>self._value, current_value)

        imgui.TextUnformatted(current_value.c_str(), current_value.c_str()+current_value.size())

        if self._wrap >= 0:
            imgui.PopTextWrapPos()
        if self._color > 0:
            imgui.PopStyleColor(1)

        if self._show_label:
            imgui.SameLine(0., -1.)
            imgui.TextUnformatted(self.imgui_label.c_str(), NULL)
        if self._show_label or self._bullet:
            # Group enables to share the states for all items
            imgui.EndGroup()

        self.update_current_state()
        return False


cdef class dcgSelectable(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_selectable
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        # Frankly unsure why these. Should it include popup ?:
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True
        self.flags = imgui.ImGuiSelectableFlags_None

    @property
    def disable_popup_close(self):
        """
        Writable attribute: Clicking this doesn't close parent popup window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSelectableFlags_NoAutoClosePopups) != 0

    @disable_popup_close.setter
    def disable_popup_close(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiSelectableFlags_NoAutoClosePopups
        if value:
            self.flags |= imgui.ImGuiSelectableFlags_NoAutoClosePopups

    @property
    def span_columns(self):
        """
        Writable attribute: Frame will span all columns of its container table (text will still fit in current column)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSelectableFlags_SpanAllColumns) != 0

    @span_columns.setter
    def span_columns(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiSelectableFlags_SpanAllColumns
        if value:
            self.flags |= imgui.ImGuiSelectableFlags_SpanAllColumns

    @property
    def on_double_click(self):
        """
        Writable attribute: call callbacks on double clicks too
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSelectableFlags_AllowDoubleClick) != 0

    @on_double_click.setter
    def on_double_click(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiSelectableFlags_AllowDoubleClick
        if value:
            self.flags |= imgui.ImGuiSelectableFlags_AllowDoubleClick

    @property
    def highlighted(self):
        """
        Writable attribute: highlighted as if hovered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiSelectableFlags_Highlight) != 0

    @highlighted.setter
    def highlighted(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiSelectableFlags_Highlight
        if value:
            self.flags |= imgui.ImGuiSelectableFlags_Highlight

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiSelectableFlags flags = self.flags
        if not(self._enabled):
            flags |= imgui.ImGuiSelectableFlags_Disabled

        cdef bool checked = shared_bool.get(<shared_bool>self._value)
        cdef bint changed = imgui.Selectable(self.imgui_label.c_str(),
                                             &checked,
                                             flags,
                                             self.requested_size)
        if self._enabled:
            shared_bool.set(<shared_bool>self._value, checked)
        self.update_current_state()
        return changed


cdef class dcgTabButton(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_tabbutton
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        # Frankly unsure why these. Should it include popup ?:
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True
        self.flags = imgui.ImGuiTabItemFlags_None

    @property
    def no_reorder(self):
        """
        Writable attribute: Disable reordering this tab or
        having another tab cross over this tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_NoReorder
        if value:
            self.flags |= imgui.ImGuiTabItemFlags_NoReorder

    @property
    def leading(self):
        """
        Writable attribute: Enforce the tab position to the
        left of the tab bar (after the tab list popup button)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_Leading) != 0

    @leading.setter
    def leading(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_Leading
        if value:
            self.flags &= ~imgui.ImGuiTabItemFlags_Trailing
            self.flags |= imgui.ImGuiTabItemFlags_Leading

    @property
    def trailing(self):
        """
        Writable attribute: Enforce the tab position to the
        right of the tab bar (before the scrolling buttons)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_Trailing) != 0

    @trailing.setter
    def trailing(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_Trailing
        if value:
            self.flags &= ~imgui.ImGuiTabItemFlags_Leading
            self.flags |= imgui.ImGuiTabItemFlags_Trailing

    @property
    def no_tooltip(self):
        """
        Writable attribute: Disable tooltip for the given tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_NoTooltip
        if value:
            self.flags |= imgui.ImGuiTabItemFlags_NoTooltip

    cdef bint draw_item(self) noexcept nogil:
        cdef bint pressed = imgui.TabItemButton(self.imgui_label.c_str(),
                                                self.flags)
        self.update_current_state()
        shared_bool.set(<shared_bool>self._value, self.state.active) # Unsure. Not in original
        return pressed


cdef class dcgMenuItem(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_menuitem
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        # Frankly unsure why these. Should it include popup ?:
        #self.state.has_rect_min = True
        #self.state.has_rect_max = True
        #self.state.has_rect_size = True
        #self.state.has_content_region = True
        self._check = False

    @property
    def check(self):
        """
        Writable attribute:
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._check

    @check.setter
    def check(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._check = value

    @property
    def shortcut(self):
        """
        Writable attribute:
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._shortcut, encoding='utf-8')

    @shortcut.setter
    def shortcut(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._shortcut = bytes(value, 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        # TODO dpg does overwrite textdisabled...
        cdef bool current_value = shared_bool.get(<shared_bool>self._value)
        cdef bint activated = imgui.MenuItem(self.imgui_label.c_str(),
                                             self._shortcut.c_str(),
                                             NULL if self._check else &current_value,
                                             self._enabled)
        self.update_current_state()
        shared_bool.set(<shared_bool>self._value, current_value)
        return activated

cdef class dcgProgressBar(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_progressbar
        self._value = <shared_value>(shared_float.__new__(shared_float, self.context))
        self.state.can_be_clicked = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        # Frankly unsure why these. Should it include popup ?:
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True

    @property
    def overlay(self):
        """
        Writable attribute:
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._overlay, encoding='utf-8')

    @overlay.setter
    def overlay(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._overlay = bytes(value, 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        cdef float current_value = shared_float.get(<shared_float>self._value)
        cdef const char *overlay_text = self._overlay.c_str()
        imgui.PushID(self.uuid)
        imgui.ProgressBar(current_value,
                          self.requested_size,
                          <const char *>NULL if self._overlay.size() == 0 else overlay_text)
        imgui.PopID()
        self.update_current_state()
        return False

cdef class dcgImage(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_image
        self.state.can_be_clicked = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        # Frankly unsure why these. Should it include popup ?:
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True
        self._border_color = 0
        self._color_multiplier = 4294967295

    @property
    def texture(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, dcgTexture)):
            raise TypeError("texture must be a dcgTexture")
        # TODO: MV_ATLAS_UUID
        self._texture = value
    @property
    def uv(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv)
    @uv.setter
    def uv(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv, value)
    @property
    def color_multiplier(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_multiplier
        unparse_color(color_multiplier, self._color_multiplier)
        return list(color_multiplier)
    @color_multiplier.setter
    def color_multiplier(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_multiplier = parse_color(value)
    @property
    def border_color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] border_color
        unparse_color(border_color, self._border_color)
        return list(border_color)
    @border_color.setter
    def border_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._border_color = parse_color(value)

    cdef bint draw_item(self) noexcept nogil:
        if self._texture is None:
            return False
        cdef imgui.ImVec2 size = self.requested_size
        if size.x == 0.:
            size.x = self._texture._width
        if size.y == 0.:
            size.y = self._texture._height

        imgui.PushID(self.uuid)
        imgui.Image(self._texture.allocated_texture,
                    size,
                    imgui.ImVec2(self._uv[0], self._uv[1]),
                    imgui.ImVec2(self._uv[2], self._uv[3]),
                    imgui.ColorConvertU32ToFloat4(self._color_multiplier),
                    imgui.ColorConvertU32ToFloat4(self._border_color))
        imgui.PopID()
        self.update_current_state()
        return False


cdef class dcgImageButton(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_imagebutton
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.state.can_be_clicked = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.state.can_be_activated = True
        # Frankly unsure why these. Should it include popup ?:
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True
        self._background_color = 0
        self._color_multiplier = 4294967295
        self._frame_padding = -1

    @property
    def texture(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, dcgTexture)):
            raise TypeError("texture must be a dcgTexture")
        # TODO: MV_ATLAS_UUID
        self._texture = value
    @property
    def frame_padding(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._frame_padding
    @frame_padding.setter
    def frame_padding(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._frame_padding = value
    @property
    def uv(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv)
    @uv.setter
    def uv(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv, value)
    @property
    def color_multiplier(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_multiplier
        unparse_color(color_multiplier, self._color_multiplier)
        return list(color_multiplier)
    @color_multiplier.setter
    def color_multiplier(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_multiplier = parse_color(value)
    @property
    def background_color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] background_color
        unparse_color(background_color, self._background_color)
        return list(background_color)
    @background_color.setter
    def background_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._background_color = parse_color(value)

    cdef bint draw_item(self) noexcept nogil:
        if self._texture is None:
            return False
        cdef imgui.ImVec2 size = self.requested_size
        if size.x == 0.:
            size.x = self._texture._width
        if size.y == 0.:
            size.y = self._texture._height

        imgui.PushID(self.uuid)
        if self._frame_padding >= 0:
            imgui.PushStyleVar(imgui.ImGuiStyleVar_FramePadding,
                               imgui.ImVec2(<float>self._frame_padding,
                                            <float>self._frame_padding))
        cdef bint activated
        activated = imgui.ImageButton(self.imgui_label.c_str(),
                                      self._texture.allocated_texture,
                                      size,
                                      imgui.ImVec2(self._uv[0], self._uv[1]),
                                      imgui.ImVec2(self._uv[2], self._uv[3]),
                                      imgui.ColorConvertU32ToFloat4(self._color_multiplier),
                                      imgui.ColorConvertU32ToFloat4(self._background_color))
        if self._frame_padding >= 0:
            imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        return activated

cdef class dcgSeparator(uiItem):
    # TODO: is label override really needed ?
    @property
    def label(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        """
        Writable attribute: label assigned to the item.
        Used for text fields, window titles, etc
        """
        return self.user_label
    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self.user_label = ""
        else:
            self.user_label = value
        # uuid is not used for text, and we don't want to
        # add it when we show the label, thus why we override
        # the label property here.
        self.imgui_label = bytes(self.user_label, 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        if self.user_label is None:
            imgui.Separator()
        else:
            imgui.SeparatorText(self.imgui_label.c_str())
        return False

cdef class dcgSpacer(uiItem):
    cdef bint draw_item(self) noexcept nogil:
        if self.requested_size.x == 0 and \
           self.requested_size.y == 0:
            imgui.Spacing()
        else:
            imgui.Dummy(self.requested_size)
        return False

cdef class dcgMenuBar(uiItem):
    # TODO: must be allowed as viewport child
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self.can_have_widget_child = True
        self.theme_condition_category = theme_categories.t_menubar
        self.state.can_be_clicked = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.state.can_be_activated = True
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True

    cdef bint draw_item(self) noexcept nogil:
        cdef bint menu_allowed
        cdef bint parent_viewport = self._parent is self.context.viewport
        if parent_viewport:
            menu_allowed = imgui.BeginMainMenuBar()
        else:
            menu_allowed = imgui.BeginMenuBar()
        if menu_allowed:
            if self.last_widgets_child is not None:
                self.last_widgets_child.draw()
            if parent_viewport:
                imgui.EndMainMenuBar()
            else:
                imgui.EndMenuBar()
            self.update_current_state()
        else:
            # We should hit this only if window is invisible
            # or has no menu bar
            self.set_hidden_and_propagate()
        return self.state.activated


cdef class dcgMenu(uiItem):
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.can_have_widget_child = True
        self.theme_condition_category = theme_categories.t_menu
        self.state.can_be_clicked = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_deactivated = True
        self.state.has_rect_size = True
        self.state.has_content_region = True

    cdef bint draw_item(self) noexcept nogil:
        cdef bint menu_open = imgui.BeginMenu(self.imgui_label.c_str(),
                                              self._enabled)
        self.update_current_state()
        if menu_open:
            self.state.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            self.state.rect_size.x = imgui.GetWindowWidth()
            self.state.rect_size.y = imgui.GetWindowHeight()
            if self.last_widgets_child is not None:
                self.last_widgets_child.draw()
            imgui.EndMenu()
        else:
            self.propagate_hidden_state_to_children()
        shared_bool.set(<shared_bool>self._value, menu_open)
        return self.state.activated

cdef class dcgTooltip(uiItem):
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self.can_have_widget_child = True
        self.theme_condition_category = theme_categories.t_tooltip
        self.state.can_be_active = True
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True
        self._delay = 0.
        self._hide_on_activity = False

    @property
    def delay(self):
        """
        Delay in seconds with no motion before showing the tooltip
        -1: Use imgui defaults
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._delay

    @delay.setter
    def delay(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._delay = value

    @property
    def hide_on_activity(self):
        """
        Hide the tooltip when the mouse moves
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._delay

    @hide_on_activity.setter
    def hide_on_activity(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._delay = value

    cdef bint draw_item(self) noexcept nogil:
        cdef float hoverDelay_backup
        cdef bint target_hovered
        if self._delay > 0.:
            hoverDelay_backup = imgui.GetStyle().HoverStationaryDelay
            imgui.GetStyle().HoverStationaryDelay = self._delay
            target_hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_Stationary)
            imgui.GetStyle().HoverStationaryDelay = hoverDelay_backup
        elif self._delay == 0:
            target_hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
        else:
            target_hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_ForTooltip)

        if self._hide_on_activity and imgui.GetIO().MouseDelta.x != 0. and \
           imgui.GetIO().MouseDelta.y != 0.:
            target_hovered = False

        cdef bint was_visible = self.state.visible
        if target_hovered and imgui.BeginTooltip():
            if self.last_widgets_child is not None:
                self.last_widgets_child.draw()
            imgui.EndTooltip()
            self.update_current_state()
        else:
            self.set_hidden_and_propagate()
            # NOTE: we could also set the rects. DPG does it.
        return self.state.visible and not(was_visible)


'''
cdef class dcgTab(uiItem):
    def __cinit__(self):
        self._value = <shared_value>(shared_bool.__new__(shared_bool, self.context))
        self.can_have_widget_child = True
        self.theme_condition_category = theme_categories.t_tab
        self.state.can_be_clicked = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.state.can_be_activated = True
        self.state.can_be_active = True
        self.state.can_be_deactivated = True
        self.state.has_rect_size = True
        self.state.has_content_region = True
        self._closable = False
        self.flags = imgui.ImGuiTabItemFlags_None

    @property
    def closable(self):
        """
        Writable attribute: Can the tab be closed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closable 

    @closable.setter
    def closable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._closable = value

    @property
    def no_reorder(self):
        """
        Writable attribute: Disable reordering this tab or
        having another tab cross over this tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_NoReorder
        if value:
            self.flags |= imgui.ImGuiTabItemFlags_NoReorder

    @property
    def leading(self):
        """
        Writable attribute: Enforce the tab position to the
        left of the tab bar (after the tab list popup button)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_Leading) != 0

    @leading.setter
    def leading(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_Leading
        if value:
            self.flags &= ~imgui.ImGuiTabItemFlags_Trailing
            self.flags |= imgui.ImGuiTabItemFlags_Leading

    @property
    def trailing(self):
        """
        Writable attribute: Enforce the tab position to the
        right of the tab bar (before the scrolling buttons)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_Trailing) != 0

    @trailing.setter
    def trailing(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_Trailing
        if value:
            self.flags &= ~imgui.ImGuiTabItemFlags_Leading
            self.flags |= imgui.ImGuiTabItemFlags_Trailing

    @property
    def no_tooltip(self):
        """
        Writable attribute: Disable tooltip for the given tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabItemFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabItemFlags_NoTooltip
        if value:
            self.flags |= imgui.ImGuiTabItemFlags_NoTooltip

    cdef bint draw_item(self) noexcept nogil:
        cdef bint menu_open = imgui.BeginMenu(self.imgui_label.c_str(),
                                              self._enabled)
        self.update_current_state()
        if menu_open:
            self.state.focused = imgui.IsWindowFocused()
            self.state.hovered = imgui.IsWindowHovered()
            self.state.rect_size.x = imgui.GetWindowWidth()
            self.state.rect_size.y = imgui.GetWindowHeight()
            if self.last_widgets_child is not None:
                self.last_widgets_child.draw()
            imgui.EndMenu()
        else:
            self.propagate_hidden_state_to_children()
        shared_bool.set(<shared_bool>self._value, menu_open)
        return self.state.activated
'''

cdef class dcgGroup(uiItem):
    """
    A group enables two things:
    . Share the same indentation for the children
    . The group states correspond to an OR of all
      the item states within
    """
    def __cinit__(self):
        self.can_have_widget_child = True
        self.state.can_be_active = True
        self.state.can_be_activated = True
        self.state.can_be_clicked = True
        self.state.can_be_deactivated = True
        self.state.can_be_deactivated_after_edited = True
        self.state.can_be_edited = True
        self.state.can_be_focused = True
        self.state.can_be_hovered = True
        self.state.can_be_toggled = True
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_rect_size = True
        self.state.has_content_region = True
        self.theme_condition_category = theme_categories.t_group

    cdef bint draw_item(self) noexcept nogil:
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        if self.last_widgets_child is not None:
            self.last_widgets_child.draw()
        imgui.EndGroup()
        imgui.PopID()
        self.update_current_state()

"""
Complex ui items
"""

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
        self.theme_condition_enabled = theme_enablers.t_enabled_any
        self.theme_condition_category = theme_categories.t_window
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
        self.can_have_widget_child = True
        self.can_have_drawing_child = True
        self.can_have_payload_child = True
        self.element_child_category = child_cat_window
        self.state.can_be_hovered = True
        self.state.can_be_focused = True
        self.state.has_rect_size = True
        self.state.has_rect_min = True
        self.state.has_rect_max = True
        self.state.has_content_region = True

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<uiItem>self._prev_sibling).draw()

        if not(self._show):
            if self.show_update_requested:
                self.set_hidden_and_propagate()
                self.show_update_requested = False
            return

        if self.focus_update_requested:
            if self.state.focused:
                imgui.SetNextWindowFocus()
            self.focus_update_requested = False

        if self.pos_update_requested:
            imgui.SetNextWindowPos(self.state.relative_position, <imgui.ImGuiCond>0)
            self.pos_update_requested = False

        if self.size_update_requested:
            imgui.SetNextWindowSize(self.requested_size,
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
        self.context.viewport.push_pending_theme_actions(
            theme_enablers.t_enabled_any,
            theme_categories.t_window
        )
        if self._theme is not None:
            self._theme.push()

        cdef bint visible = True
        # Modal/Popup windows must be manually opened
        if self.modal or self.popup:
            if self.show_update_requested and self._show:
                self.show_update_requested = False
                imgui.OpenPopup(self.imgui_label.c_str(),
                                imgui.ImGuiPopupFlags_NoOpenOverExistingPopup if self.no_open_over_existing_popup else imgui.ImGuiPopupFlags_None)

        # Begin drawing the window
        if self.modal:
            visible = imgui.BeginPopupModal(self.imgui_label.c_str(), &self._show if self.has_close_button else <bool*>NULL, self.window_flags)
        elif self.popup:
            visible = imgui.BeginPopup(self.imgui_label.c_str(), self.window_flags)
        else:
            visible = imgui.Begin(self.imgui_label.c_str(),
                                  &self._show if self.has_close_button else <bool*>NULL,
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

            #if self.last_0_child is not None:
            #    self.last_0_child.draw(this_drawlist, startx, starty)

            if self.last_widgets_child is not None:
                self.last_widgets_child.draw()
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
            if (rect_size.x != self.requested_size.x or rect_size.y != self.requested_size.y):
                self.requested_size = rect_size
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

        if self._theme is not None:
            self._theme.pop()
        self.context.viewport.pop_applied_pending_theme_actions()

        cdef bint closed = not(self._show) or (not(visible) and (self.modal or self.popup))
        if closed:
            self._show = False
            self.context.queue_callback_noarg(self.on_close_callback,
                                              self)
        self.show_update_requested = False

        if self.handlers is not None:
            self.handlers.run_handler(self)


"""
Textures
"""



cdef class dcgTexture(baseItem):
    def __cinit__(self):
        self.hint_dynamic = False
        self.dynamic = False
        self.allocated_texture = NULL
        self._width = 0
        self._height = 0
        self._num_chans = 0
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

    def configure(self, *args, **kwargs):
        if len(args) == 1:
            self.set_content(np.ascontiguousarray(args[0]))
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to dcgTexture. Expected content")
        self.filtering_mode = 1 if kwargs.pop("nearest_neighbor_upsampling", False) else 0
        return super().configure(**kwargs)

    @property
    def hint_dynamic(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._hint_dynamic
    @hint_dynamic.setter
    def hint_dynamic(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._hint_dynamic = value
    @property
    def nearest_neighbor_upsampling(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if self.filtering_mode == 1 else 0
    @nearest_neighbor_upsampling.setter
    def nearest_neighbor_upsampling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.filtering_mode = 1 if value else 0
    @property
    def width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._width
    @property
    def height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._height
    @property
    def num_chans(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_chans

    def set_value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.set_content(np.ascontiguousarray(value))

    cdef void set_content(self, cnp.ndarray content):
        # The write mutex is to ensure order of processing of set_content
        # as we might release the item mutex to wait for imgui to render
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.write_mutex)
        lock_gil_friendly(m2, self.mutex)
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
        reuse = reuse and (self._width != width or self._height != height or self._num_chans != num_chans)
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

            self._width = width
            self._height = height
            self._num_chans = num_chans

            if not(reuse):
                self.dynamic = self._hint_dynamic
                self.allocated_texture = mvAllocateTexture(width, height, num_chans, self.dynamic, buffer_type, self.filtering_mode)

            if self.dynamic:
                mvUpdateDynamicTexture(self.allocated_texture, width, height, num_chans, buffer_type, <void*>content.data)
            else:
                mvUpdateStaticTexture(self.allocated_texture, width, height, num_chans, buffer_type, <void*>content.data)
            mvReleaseRenderingContext(dereference(self.context.viewport.viewport))


cdef class baseTheme(baseItem):
    """
    Base theme element. Contains a set of theme elements
    to apply for a given category (color, style)/(imgui/implot/imnode)
    """
    def __cinit__(self):
        self.element_child_category = child_cat_theme
        self.can_have_sibling = True
        self.enabled = True
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.enabled = kwargs.pop("enabled", self.enabled)
        self.enabled = kwargs.pop("show", self.enabled)
        return super().configure(**kwargs)
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.enabled = value
    # should be always defined by subclass
    cdef void push(self) noexcept nogil:
        return
    cdef void pop(self) noexcept nogil:
        return
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
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

cdef void imgui_PushStyleVar1(int i, float val) noexcept nogil:
    imgui.PushStyleVar(<imgui.ImGuiStyleVar>i, val)

cdef void imgui_PushStyleVar2(int i, imgui.ImVec2 val) noexcept nogil:
    imgui.PushStyleVar(<imgui.ImGuiStyleVar>i, val)

cdef void imgui_PopStyleVar(int count) noexcept nogil:
    imgui.PopStyleVar(count)

cdef void implot_PushStyleVar0(int i, int val) noexcept nogil:
    implot.PushStyleVar(<implot.ImPlotStyleVar>i, val)

cdef void implot_PushStyleVar1(int i, float val) noexcept nogil:
    implot.PushStyleVar(<implot.ImPlotStyleVar>i, val)

cdef void implot_PushStyleVar2(int i, imgui.ImVec2 val) noexcept nogil:
    implot.PushStyleVar(<implot.ImPlotStyleVar>i, val)

cdef void implot_PopStyleVar(int count) noexcept nogil:
    implot.PopStyleVar(count)

cdef void imnodes_PushStyleVar1(int i, float val) noexcept nogil:
    imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>i, val)

cdef void imnodes_PushStyleVar2(int i, imgui.ImVec2 val) noexcept nogil:
    imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>i, val)

cdef void imnodes_PopStyleVar(int count) noexcept nogil:
    imnodes.PopStyleVar(count)

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
