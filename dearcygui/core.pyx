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
#distutils: language=c++

from libcpp cimport bool
import traceback

cimport cython
cimport cython.view
from cython.operator cimport dereference
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libc.string cimport memset, memcpy

# This file is the only one that is linked to the C++ code
# Thus it is the only one allowed to make calls to it

from dearcygui.wrapper cimport *
from dearcygui.backends.backend cimport *
# We use unique_lock rather than lock_guard as
# the latter doesn't support nullary constructor
# which causes trouble to cython
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock, defer_lock_t

from concurrent.futures import Executor, ThreadPoolExecutor
from libcpp.algorithm cimport swap
from libcpp.cmath cimport atan, sin, cos, trunc, floor, round as cround
from libcpp.set cimport set as cpp_set
from libcpp.vector cimport vector
from libc.math cimport M_PI, INFINITY
cimport dearcygui.backends.time as ctime

import os
import numpy as np
cimport numpy as cnp
cnp.import_array()

import scipy
import scipy.spatial
import time as python_time
import threading
import weakref

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

cdef void lock_gil_friendly_block(unique_lock[recursive_mutex] &m) noexcept:
    """
    Same as lock_gil_friendly, but blocks until the job is done.
    We inline the fast path, but not this one as it generates
    more code.
    """
    # Release the gil to enable python processes eventually
    # holding the lock to run and release it.
    # Block until we get the lock
    cdef bint locked = False
    while not(locked):
        with nogil:
            # Block until the mutex is released
            m.lock()
            # Unlock to prevent deadlock if another
            # thread holding the gil requires m
            # somehow
            m.unlock()
        locked = m.try_lock()


cdef void internal_resize_callback(void *object, int a, int b) noexcept nogil:
    with gil:
        try:
            (<Viewport>object).__on_resize(a, b)
        except Exception as e:
            print("An error occured in the viewport resize callback", traceback.format_exc())

cdef void internal_close_callback(void *object) noexcept nogil:
    with gil:
        try:
            (<Viewport>object).__on_close()
        except Exception as e:
            print("An error occured in the viewport close callback", traceback.format_exc())

cdef void internal_render_callback(void *object) noexcept nogil:
    (<Viewport>object).__render()

# Placeholder global where the last created Context is stored.
C : Context = None

# The no gc clear flag enforces that in case
# of no-reference cycle detected, the Context is freed last.
# The cycle is due to Context referencing Viewport
# and vice-versa

cdef class Context:
    """
    Main class managing the DearCyGui items and imgui context.
    There is exactly one viewport per context.

    Items are assigned an uuid and eventually a user tag.
    indexing the context with the uuid or the tag returns
    the object associated.

    The last created context can be accessed as deacygui.C
    """
    def __init__(self, queue=None):
        """
        Parameters:
            queue (optional, defaults to ThreadPoolExecutor(max_workers=1)):
                Subclass of concurrent.futures.Executor used to submit
                callbacks during the frame.
        """
        global C
        self.on_close_callback = None
        if queue is None:
            self.queue = ThreadPoolExecutor(max_workers=1)
        else:
            if not(isinstance(queue, Executor)):
                raise TypeError("queue must be a subclass of concurrent.futures.Executor")
            self.queue = queue
        C = self

    def __cinit__(self):
        self.next_uuid.store(21)
        self.waitOneFrame = False
        self.started = True
        self.uuid_to_tag = dict()
        self.tag_to_uuid = dict()
        self.items = weakref.WeakValueDictionary()
        self.threadlocal_data = threading.local()
        self._viewport = Viewport(self)
        self.resetTheme = False
        imgui.IMGUI_CHECKVERSION()
        self.imgui_context = imgui.CreateContext()
        self.implot_context = implot.CreateContext()
        self.imnodes_context = imnodes.CreateContext()

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
            self.queue_callback_noarg(self.on_close_callback, self, self)
            self.started = False

        #mvToolManager::Reset()
        #ClearItemRegistry(*GContext->itemRegistry)
        if self.queue is not None:
            self.queue.shutdown(wait=True)

    @property
    def viewport(self) -> Viewport:
        """Readonly attribute: root item from where rendering starts"""
        return self._viewport

    cdef void queue_callback_noarg(self, Callback callback, baseItem parent_item, baseItem target_item) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1obj(self, Callback callback, baseItem parent_item, baseItem target_item, baseItem arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, arg1)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1int(self, Callback callback, baseItem parent_item, baseItem target_item, int arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, arg1)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1float(self, Callback callback, baseItem parent_item, baseItem target_item, float arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, arg1)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1value(self, Callback callback, baseItem parent_item, baseItem target_item, SharedValue arg1) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, arg1.value)
            except Exception as e:
                print(traceback.format_exc())


    cdef void queue_callback_arg1int1float(self, Callback callback, baseItem parent_item, baseItem target_item, int arg1, float arg2) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, (arg1, arg2))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg2float(self, Callback callback, baseItem parent_item, baseItem target_item, float arg1, float arg2) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, (arg1, arg2))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg2double(self, Callback callback, baseItem parent_item, baseItem target_item, double arg1, double arg2) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, (arg1, arg2))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1int2float(self, Callback callback, baseItem parent_item, baseItem target_item, int arg1, float arg2, float arg3) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, (arg1, arg2, arg3))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg4int(self, Callback callback, baseItem parent_item, baseItem target_item, int arg1, int arg2, int arg3, int arg4) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, (arg1, arg2, arg3, arg4))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg3long1int(self, Callback callback, baseItem parent_item, baseItem target_item, long long arg1, long long arg2, long long arg3, int arg4) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item, (arg1, arg2, arg3, arg4))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_argdoubletriplet(self, Callback callback, baseItem parent_item, baseItem target_item,
                                              double arg1_1, double arg1_2, double arg1_3,
                                              double arg2_1, double arg2_2, double arg2_3) noexcept nogil:
        if callback is None:
            return
        with gil:
            try:
                self.queue.submit(callback, parent_item, target_item,
                                  ((arg1_1, arg1_2, arg1_3), (arg2_1, arg2_2, arg2_3)))
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
        self.items[uuid] = o
        self.threadlocal_data.last_item_uuid = uuid
        if o.can_have_drawing_child or \
           o.can_have_handler_child or \
           o.can_have_menubar_child or \
           o.can_have_plot_element_child or \
           o.can_have_payload_child or \
           o.can_have_tab_child or \
           o.can_have_theme_child or \
           o.can_have_widget_child or \
           o.can_have_window_child:
            self.threadlocal_data.last_container_uuid = uuid

    cdef void unregister_item(self, long long uuid):
        """ Free weak reference """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        try:
            del self.items[uuid]
        except Exception:
            pass
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
        return self.items.get(uuid, None)

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
        if isinstance(key, baseItem) or isinstance(key, SharedValue):
            # TODO: register shared values
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
        """
        Each time 'with' is used on an item, it is pushed
        to the list of potentialy parents to use if
        no parent (or before) is set when an item is created.
        If the list is empty, items are left unattached and
        can be attached later.

        In order to enable multiple threads from using
        the 'with' syntax, thread local storage is used,
        such that each thread has its own list.
        """
        # Use thread local storage such that multiple threads
        # can build items trees without conflicts.
        # Mutexes are not needed due to the thread locality
        cdef list parent_queue = getattr(self.threadlocal_data, 'parent_queue', [])
        parent_queue.append(next_parent)
        self.threadlocal_data.parent_queue = parent_queue

    cpdef void pop_next_parent(self):
        """
        Remove an item from the potential parent list.
        """
        cdef list parent_queue = getattr(self.threadlocal_data, 'parent_queue', [])
        if len(parent_queue) > 0:
            parent_queue.pop()

    cpdef object fetch_parent_queue_back(self):
        """
        Retrieve the last item from the potential parent list
        """
        cdef list parent_queue = getattr(self.threadlocal_data, 'parent_queue', [])
        if len(parent_queue) == 0:
            return None
        return parent_queue[len(parent_queue)-1]

    cpdef object fetch_parent_queue_front(self):
        """
        Retrieve the top item from the potential parent list
        """
        cdef list parent_queue = getattr(self.threadlocal_data, 'parent_queue', [])
        if len(parent_queue) == 0:
            return None
        return parent_queue[0]

    cpdef object fetch_last_created_item(self):
        """
        Return the last item created in this thread.
        Returns None if the last item created has been
        deleted.
        """
        cdef long long last_uuid = getattr(self.threadlocal_data, 'last_item_uuid', -1)
        return self.get_registered_item_from_uuid(last_uuid)

    cpdef object fetch_last_created_container(self):
        """
        Return the last item which can have children
        created in this thread.
        Returns None if the last such item has been
        deleted.
        """
        cdef long long last_uuid = getattr(self.threadlocal_data, 'last_container_uuid', -1)
        return self.get_registered_item_from_uuid(last_uuid)

    def is_key_down(self, int key, int keymod=-1):
        """
        Is key being held.

        key is a key constant (see constants)
        keymod is a mask if keymod constants (ctrl, shift, alt, super)
        if keymod is negative, ignores any key modifiers.
        If non-negative, returns True only if the modifiers
        correspond as well as the key.
        """
        cdef unique_lock[recursive_mutex] m
        if key < 0 or <imgui.ImGuiKey>key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod >= 0 and (keymod & imgui.ImGuiMod_Mask_) != imgui.GetIO().KeyMods:
            return False
        return imgui.IsKeyDown(<imgui.ImGuiKey>key)

    def is_key_pressed(self, int key, int keymod=-1, bint repeat=True):
        """
        Was key pressed (went from !Down to Down)?
        
        if repeat=true, the pressed state is repeated
        if the user continue pressing the key.
        If keymod is non-negative, returns True only if the modifiers
        correspond as well as the key.

        """
        cdef unique_lock[recursive_mutex] m
        if key < 0 or <imgui.ImGuiKey>key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod >= 0 and (keymod & imgui.ImGuiMod_Mask_) != imgui.GetIO().KeyMods:
            return False
        return imgui.IsKeyPressed(<imgui.ImGuiKey>key, repeat)

    def is_key_released(self, int key, int keymod=-1):
        """
        Was key released (went from Down to !Down)?
        
        If keymod is non-negative, returns True also if the
        required modifiers are not pressed.
        """
        cdef unique_lock[recursive_mutex] m
        if key < 0 or <imgui.ImGuiKey>key >= imgui.ImGuiKey_NamedKey_END:
            raise ValueError("Invalid key")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod >= 0 and (keymod & imgui.GetIO().KeyMods) != keymod:
            return True
        return imgui.IsKeyReleased(<imgui.ImGuiKey>key)

    def is_mouse_down(self, int button):
        """is mouse button held?"""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDown(button)

    def is_mouse_clicked(self, int button, bint repeat=False):
        """did mouse button clicked? (went from !Down to Down). Same as get_mouse_clicked_count() >= 1."""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseClicked(button, repeat)

    def is_mouse_double_clicked(self, int button):
        """did mouse button double-clicked?. Same as get_mouse_clicked_count() == 2."""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDoubleClicked(button)

    def get_mouse_clicked_count(self, int button):
        """how many times a mouse button is clicked in a row"""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.GetMouseClickedCount(button)

    def is_mouse_released(self, int button):
        """did mouse button released? (went from Down to !Down)"""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseReleased(button)

    def get_mouse_position(self):
        """Retrieves the mouse position (x, y). Raises KeyError if there is no mouse"""
        cdef unique_lock[recursive_mutex] m
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        cdef imgui.ImVec2 pos = imgui.GetMousePos()
        if not(imgui.IsMousePosValid(&pos)):
            raise KeyError("Cannot get mouse position: no mouse found")
        return (pos.x, pos.y)

    def is_mouse_dragging(self, int button, float lock_threshold=-1.):
        """is mouse dragging? (uses default distance threshold if lock_threshold < 0.0f"""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDragging(button, lock_threshold)

    def get_mouse_drag_delta(self, int button, float lock_threshold=-1.):
        """
        Return the delta (dx, dy) from the initial clicking position while the mouse button is pressed or was just released.
        
        This is locked and return 0.0f until the mouse moves past a distance threshold at least once
        (uses default distance if lock_threshold < 0.0f)"""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        cdef imgui.ImVec2 delta =  imgui.GetMouseDragDelta(button, lock_threshold)
        return (delta.x, delta.y)

    def reset_mouse_drag_delta(self, int button):
        """Reset to 0 the drag delta for the target button"""
        cdef unique_lock[recursive_mutex] m
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.ResetMouseDragDelta(button)

    @property
    def running(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.started

    @running.setter
    def running(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.started = value

    @property
    def clipboard(self):
        """Writable attribute: content of the clipboard"""
        cdef unique_lock[recursive_mutex] m
        if not(self._viewport.initialized):
            return ""
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return str(imgui.GetClipboardText())

    @clipboard.setter
    def clipboard(self, str value):
        cdef string value_str = bytes(value, 'utf-8')
        cdef unique_lock[recursive_mutex] m
        if not(self._viewport.initialized):
            return
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.SetClipboardText(value_str.c_str())

'''
cdef class renderer:
    """
    Base class for renderer backends.

    The texture functions must be thread safe
    and can be called during other calls.
    """

    cdef void initialize(self) noexcept nogil:
        """
        Create the rendering context. After this call
        all the other calls are allowed. Texture can
        be created and uploaded.
        """
        return

    cdef void process_events(self, bint wait) noexcept nogil:
        """
        Update imgui with the latest events.

        wait: Wait for any keyboard/mouse events or activity
        """
        return

    cdef void render(self) noexcept nogil:
        """
        Retrieve the current ImGui draw calls
        and issue them
        """
        return

    cdef void present(self) noexcept nogil:
        """
        Present to the screen the changes
        """
        return

    cdef void minimize(self) noexcept nogil:
        """
        Minimize the window
        """
        return

    cdef void un_minimize(self) noexcept nogil:
        """
        Restore a minimized window
        """
        return

    cdef bint is_minimized(self) noexcept nogil:
        """
        Check if the window is minimized
        """
        return False

    cdef void maximize(self) noexcept nogil:
        """
        Maximize a window
        """
        return

    cdef void un_maximize(self) noexcept nogil:
        """
        Restore a maximized window
        """
        return

    cdef bint is_maximized(self) noexcept nogil:
        """
        Check if the window is maximized
        """
        return

    cdef void show(self) noexcept nogil:
        """
        Show a hidden window
        """
        return

    cdef void hide(self) noexcept nogil:
        """
        Hide a visible window
        """
        return

    cdef bint is_visible(self) noexcept nogil:
        """
        Check if the window is hidden or visible
        """
        return

    cdef void fullscreen(self) noexcept nogil:
        """
        Make a window fullscreen
        """
        return

    cdef void un_fullscreen(self) noexcept nogil:
        """
        Leave fullscreen mode
        """
        return

    cdef bint is_fullscreen(self) noexcept nogil:
        """
        Check if a window is fullscreen
        """
        return

    cdef void wake_event_queue(self) noexcept nogil:
        """
        Wakes a thread waiting on process_events
        """
        return

    cdef void* create_texture(self) noexcept nogil:
        """
        Create a texture
        """
        return

    cdef void* release_texture(self) noexcept nogil:
        """
        Destroy a texture
        """
        return

    cdef void upload_texture(self, void*, void*) noexcept nogil:
        return


cdef class GLFWrenderer:
    """
    GLFW backend
    """
    def __cinit__(self):
        mvCreateViewport

    def __dealloc__(self):
        mvCleanupViewport

    cdef void initialize(self):
        mvRenderFrame

    cdef void process_events(self):
        mvProcessEvents

'''

cdef class baseItem:
    """
    Base class for all items (except shared values)

    To be rendered, an item must be in the child tree
    of the viewport (context.viewport).

    The parent of an item can be set with various ways:
    1) Using the parent attribute. item.parent = target_item
    2) Passing (parent=target_item) during item creation
    3) If the context manager is not empty ('with' on an item),
       and no parent is set (parent = None passed or nothing),
       the last item in 'with' is taken as parent. The context
       manager can be managed directly with context.push_next_parent()
       and context.pop_next_parent()
    4) if you set the previous_sibling or next_sibling attribute,
       the item will be inserted respectively after and before the
       respective items in the parent item children list. For legacy
       support, the 'before=target_item' attribute can be used during item creation,
       and is equivalent to item.next_sibling = target_item

    parent, previous_sibling and next_sibling are baseItem attributes
    and can be read at any time.
    It is possible to get the list of children of an item as well
    with the 'children' attribute: item.children.

    For ease of use, the items can be named for easy retrieval.
    The tag attribute is a user string that can be set at any
    moment and can be passed for parent/previous_sibling/next_sibling.
    The item associated with a tag can be retrieved with context[tag].
    Note that having a tag doesn't mean the item is referenced by the context.
    If an item is not in the subtree of the viewport, and is not referenced,
    it might get deleted.

    During rendering the children of each item are rendered in
    order from the first one to the last one.
    When an item is attached to a parent, it is by default inserted
    last, unless previous_sibling or next_sibling is used.

    previous_sibling and next_sibling enable to insert an item
    between elements.

    When parent, previous_sibling or next_sibling are set, the item
    is detached from any parent or sibling it had previously.

    An item can be manually detached from a parent
    by setting parent = None.

    Most items have restrictions for the parents and children it can
    have. In addition some items can have several children lists
    of incompatible types. These children list will be concatenated
    when reading item.children. In a given list are items of a similar
    type.

    Finally some items cannot be children of any item in the rendering
    tree. One such item is PlaceHolderParent, which can be parent
    of any item which can have a parent. PlaceHolderParent cannot
    be inserted in the rendering tree, but can be used to store items
    before their insertion in the rendering tree.
    Other such items are textures, themes, colormaps and fonts. Those
    items cannot be made children of items of the rendering tree, but
    can be bound to them. For example item.theme = theme_item will
    bind theme_item to item. It is possible to bind such an item to
    several items, and as long as one item reference them, they will
    not be deleted by the garbage collector.
    """
    def __init__(self, context, *args, **kwargs):
        self.configure(*args, **kwargs)

    def __cinit__(self, context, *args, **kwargs):
        if not(isinstance(context, Context)):
            raise ValueError("Provided context is not a valid Context instance")
        self.context = context
        self.external_lock = False
        self.uuid = self.context.next_uuid.fetch_add(1)
        self.context.register_item(self, self.uuid)
        self.can_have_widget_child = False
        self.can_have_drawing_child = False
        self.can_have_payload_child = False
        self.can_have_sibling = False
        self.element_child_category = -1

    def configure(self, **kwargs):
        # Legacy DPG support: automatic attachement
        should_attach = kwargs.pop("attach", None)
        cdef bint ignore_if_fail = False
        if should_attach is None:
            # None: default to False for items which
            # cannot be attached, True else
            if self.element_child_category == -1:
                should_attach = False
            else:
                should_attach = True
                # To avoid failing on items which cannot
                # be attached to the rendering tree but
                # can be attached to other items
                ignore_if_fail = True
        if self._parent is None and should_attach:
            before = kwargs.pop("before", None)
            parent = kwargs.pop("parent", None)
            if before is not None:
                # parent manually set. Do not ignore failure
                ignore_if_fail = False
                self.attach_before(before)
            else:
                if parent is None:
                    parent = self.context.fetch_parent_queue_back()
                    if parent is None:
                        parent = self.context._viewport
                else:
                    # parent manually set. Do not ignore failure
                    ignore_if_fail = False
                try:
                    if parent is not None:
                        self.attach_to_parent(parent)
                except TypeError as e:
                    if not(ignore_if_fail):
                        raise(e)
        else:
            if "before" in kwargs:
                del kwargs["before"]
            if "parent" in kwargs:
                del kwargs["parent"]
        remaining = {}
        for (key, value) in kwargs.items():
            try:
                setattr(self, key, value)
            except AttributeError as e:
                remaining[key] = value
        if len(remaining) > 0:
            print("Unused configure parameters: ", remaining)
        return

    def __dealloc__(self):
        clear_obj_vector(self._handlers)

    @property
    def context(self):
        """
        Read-only attribute: Context in which the item resides
        """
        return self.context

    @property
    def user_data(self):
        """
        User data of any type.
        """
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
        previous_sibling=, next_sibling= arguments, but it is
        preferred to pass the objects directly. 
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
        the object by name for parent=,
        previous_sibling=, next_sibling= arguments.

        The tag can be set at any time, but it must be unique.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.context.get_registered_item_from_uuid(self.uuid) # TODO

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

        Note that a parent can have several child queues, and thus
        child elements are not guaranteed to be siblings of each other.
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
        Writable attribute: List of all the children of the item,
        from first rendered, to last rendered.

        When written to, an error is raised if the children already
        have other parents. This error is meant to prevent programming
        mistakes, as users might not realize the children were
        unattached from their former parents.
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
        item = self.last_handler_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        item = self.last_plot_element_child
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
        item = self.last_menubar_child
        while item is not None:
            result.append(item)
            item = item._prev_sibling
        result.reverse()
        return result

    @children.setter
    def children(self, value):
        if not(hasattr(value, "__len__")):
            raise TypeError("children must be a array of child items")
        cdef unique_lock[recursive_mutex] item_m
        cdef unique_lock[recursive_mutex] child_m
        lock_gil_friendly(item_m, self.mutex)
        cdef long long uuid, prev_uuid
        cdef cpp_set[long long] already_attached
        cdef baseItem sibling
        for child in value:
            if not(isinstance(child, baseItem)):
                raise TypeError(f"{child} is not a compatible item instance")
            # Find children that are already attached
            # and in the right order
            uuid = (<baseItem>child).uuid
            if (<baseItem>child)._parent is self:
                if (<baseItem>child)._prev_sibling is None:
                    already_attached.insert(uuid)
                    continue
                prev_uuid = (<baseItem>child)._prev_sibling.uuid
                if already_attached.find(prev_uuid) != already_attached.end():
                    already_attached.insert(uuid)
                    continue

            # Note: it is fine here to hold the mutex to item_m
            # and call attach_parent, as item_m is the target
            # parent.
            # It is also fine to retain the lock to child_m
            # as it has no parent
            lock_gil_friendly(child_m, (<baseItem>child).mutex)
            if (<baseItem>child)._parent is not None and \
               (<baseItem>child)._parent is not self:
                # Probable programming mistake and potential deadlock
                raise ValueError(f"{child} already has a parent")
            (<baseItem>child).attach_to_parent(self)

            # Detach any previous sibling that are not in the
            # already_attached list, and thus should either
            # be removed, or their order changed.
            while (<baseItem>child)._prev_sibling is not None and \
                already_attached.find((<baseItem>child)._prev_sibling.uuid) == already_attached.end():
                # Setting sibling here rather than calling detach_item directly avoids
                # crash due to refcounting bug.
                sibling = (<baseItem>child)._prev_sibling
                sibling.detach_item()
            already_attached.insert(uuid)

        # if no children were attached, the previous code to
        # remove outdated children didn't execute.
        # Same for child lists where we didn't append
        # new items. Clean now.
        child = self.last_theme_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_theme_child
        child = self.last_handler_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_handler_child
        child = self.last_plot_element_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_plot_element_child
        child = self.last_payloads_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_payloads_child
        child = self.last_drawings_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_drawings_child
        child = self.last_widgets_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_widgets_child
        child = self.last_window_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_window_child
        child = self.last_menubar_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_menubar_child

    def __enter__(self):
        # Mutexes not needed
        if not(self.can_have_drawing_child or \
           self.can_have_handler_child or \
           self.can_have_menubar_child or \
           self.can_have_plot_element_child or \
           self.can_have_payload_child or \
           self.can_have_tab_child or \
           self.can_have_theme_child or \
           self.can_have_widget_child or \
           self.can_have_window_child):
            print("Warning: {self} cannot have children but is pushed as container")
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
            # Release the gil and give priority to other threads that might
            # hold the lock we want
            os.sched_yield()
            if not(locked) and self.external_lock > 0:
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

    cdef bint __check_rendered(self):
        """
        Returns if an item is rendered
        """
        cdef baseItem item = self
        # Find a parent with state
        # Not perfect because we do not hold the mutexes,
        # but should be ok enough to fail in a few cases.
        while item is not None and item.p_state == NULL:
            item = item._parent
        if item is None or item.p_state == NULL:
            return False
        return item.p_state.cur.rendered


    cpdef void attach_to_parent(self, target):
        """
        Same as item.parent = target, but
        target must not be None
        """
        cdef baseItem target_parent
        if self.context is None:
            raise ValueError("Trying to attach a deleted item")

        if not(isinstance(target, baseItem)):
            target_parent = self.context[target]
        else:
            target_parent = <baseItem>target
            if target_parent.context is not self.context:
                raise ValueError(f"Cannot attach {self} to {target} as it was not created in the same context")

        if target_parent is None:
            raise ValueError("Trying to attach to None")
        if target_parent.context is None:
            raise ValueError("Trying to attach to a deleted item")

        if self.external_lock > 0:
            # Deadlock potential. We would need to unlock the user held mutex,
            # which could be a solution, but raises its own issues.
            if target_parent.external_lock == 0:
                raise PermissionError(f"Cannot attach {self} to {target} as the user holds a lock on {self}, but not {target}")
            if not(target_parent.mutex.try_lock()):
                raise PermissionError(f"Cannot attach {self} to {target} as the user holds a lock on {self} and {target}, but not in the same threads")
            target_parent.mutex.unlock()

        # Check compatibility with the parent before locking the mutex
        # We do this optimization to avoid locking uselessly when
        # creating items due to the automated attach feature.
        cdef bint compatible = False
        if self.element_child_category == child_type.cat_drawing:
            if target_parent.can_have_drawing_child:
                compatible = True
        elif self.element_child_category == child_type.cat_handler:
            if target_parent.can_have_handler_child:
                compatible = True
        elif self.element_child_category == child_type.cat_menubar:
            if target_parent.can_have_menubar_child:
                compatible = True
        elif self.element_child_category == child_type.cat_plot_element:
            if target_parent.can_have_plot_element_child:
                compatible = True
        elif self.element_child_category == child_type.cat_tab:
            if target_parent.can_have_tab_child:
                compatible = True
        elif self.element_child_category == child_type.cat_theme:
            if target_parent.can_have_theme_child:
                compatible = True
        elif self.element_child_category == child_type.cat_widget:
            if target_parent.can_have_widget_child:
                compatible = True
        elif self.element_child_category == child_type.cat_window:
            if target_parent.can_have_window_child:
                compatible = True
        if not(compatible):
            raise TypeError("Instance of type {} cannot be attached to {}".format(type(self), type(target_parent)))

        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        # We must ensure a single thread attaches at a given time.
        # __detach_item_and_lock will lock both the item lock
        # and the parent lock.
        self.__detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        # Lock target parent mutex
        lock_gil_friendly(m2, target_parent.mutex)

        cdef bint attached = False

        # Attach to parent in the correct category
        # Note that Cython converts this into a switch().
        if self.element_child_category == child_type.cat_drawing:
            if target_parent.can_have_drawing_child:
                if target_parent.last_drawings_child is not None:
                    lock_gil_friendly(m3, target_parent.last_drawings_child.mutex)
                    target_parent.last_drawings_child._next_sibling = self
                self._prev_sibling = target_parent.last_drawings_child
                self._parent = target_parent
                target_parent.last_drawings_child = <drawingItem>self
                attached = True
        elif self.element_child_category == child_type.cat_handler:
            if target_parent.can_have_handler_child:
                if target_parent.last_handler_child is not None:
                    lock_gil_friendly(m3, target_parent.last_handler_child.mutex)
                    target_parent.last_handler_child._next_sibling = self
                self._prev_sibling = target_parent.last_handler_child
                self._parent = target_parent
                target_parent.last_handler_child = <baseHandler>self
                attached = True
        elif self.element_child_category == child_type.cat_menubar:
            if target_parent.can_have_menubar_child:
                if target_parent.last_menubar_child is not None:
                    lock_gil_friendly(m3, target_parent.last_menubar_child.mutex)
                    target_parent.last_menubar_child._next_sibling = self
                self._prev_sibling = target_parent.last_menubar_child
                self._parent = target_parent
                target_parent.last_menubar_child = <uiItem>self
                attached = True
        elif self.element_child_category == child_type.cat_plot_element:
            if target_parent.can_have_plot_element_child:
                if target_parent.last_plot_element_child is not None:
                    lock_gil_friendly(m3, target_parent.last_plot_element_child.mutex)
                    target_parent.last_plot_element_child._next_sibling = self
                self._prev_sibling = target_parent.last_plot_element_child
                self._parent = target_parent
                target_parent.last_plot_element_child = <plotElement>self
                attached = True
        elif self.element_child_category == child_type.cat_tab:
            if target_parent.can_have_tab_child:
                if target_parent.last_tab_child is not None:
                    lock_gil_friendly(m3, target_parent.last_tab_child.mutex)
                    target_parent.last_tab_child._next_sibling = self
                self._prev_sibling = target_parent.last_tab_child
                self._parent = target_parent
                target_parent.last_tab_child = <uiItem>self
                attached = True
        elif self.element_child_category == child_type.cat_theme:
            if target_parent.can_have_theme_child:
                if target_parent.last_theme_child is not None:
                    lock_gil_friendly(m3, target_parent.last_theme_child.mutex)
                    target_parent.last_theme_child._next_sibling = self
                self._prev_sibling = target_parent.last_theme_child
                self._parent = target_parent
                target_parent.last_theme_child = <baseTheme>self
                attached = True
        elif self.element_child_category == child_type.cat_widget:
            if target_parent.can_have_widget_child:
                if target_parent.last_widgets_child is not None:
                    lock_gil_friendly(m3, target_parent.last_widgets_child.mutex)
                    target_parent.last_widgets_child._next_sibling = self
                self._prev_sibling = target_parent.last_widgets_child
                self._parent = target_parent
                target_parent.last_widgets_child = <uiItem>self
                attached = True
        elif self.element_child_category == child_type.cat_window:
            if target_parent.can_have_window_child:
                if target_parent.last_window_child is not None:
                    lock_gil_friendly(m3, target_parent.last_window_child.mutex)
                    target_parent.last_window_child._next_sibling = self
                self._prev_sibling = target_parent.last_window_child
                self._parent = target_parent
                target_parent.last_window_child = <Window>self
                attached = True
        assert(attached) # because we checked before compatibility
        if not(self._parent.__check_rendered()): # TODO: could be optimized. Also not totally correct (attaching to a menu for instance)
            self.set_hidden_and_propagate_to_siblings_no_handlers()

    cpdef void attach_before(self, target):
        """
        Same as item.next_sibling = target,
        but target must not be None
        """
        cdef baseItem target_before
        if self.context is None:
            raise ValueError("Trying to attach a deleted item")

        if not(isinstance(target, baseItem)):
            target_before = self.context[target]
        else:
            target_before = <baseItem>target
            if target_before.context is not self.context:
                raise ValueError(f"Cannot attach {self} to {target} as it was not created in the same context")

        if target_before is None:
            raise ValueError("target before cannot be None")

        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] target_before_m
        cdef unique_lock[recursive_mutex] target_parent_m
         # We must ensure a single thread attaches at a given time.
        # __detach_item_and_lock will lock both the item lock
        # and the parent lock.
        self.__detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        # Lock target mutex and its parent mutex
        target_before.lock_parent_and_item_mutex(target_parent_m,
                                                 target_before_m)

        if target_before._parent is None:
            # We can bind to an unattached parent, but not
            # to unattached siblings. Could be implemented, but not trivial.
            # Maybe we could use the viewport mutex instead,
            # but that defeats the purpose of building items
            # outside the rendering tree.
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
        if not(self._parent.__check_rendered()):
            self.set_hidden_and_propagate_to_siblings_no_handlers()

    cdef void __detach_item_and_lock(self, unique_lock[recursive_mutex]& m):
        # NOTE: the mutex is not locked if we raise an exception.
        # Detach the item from its parent and siblings
        # We are going to change the tree structure, we must lock
        # the parent mutex first and foremost
        cdef unique_lock[recursive_mutex] parent_m
        cdef unique_lock[recursive_mutex] sibling_m
        self.lock_parent_and_item_mutex(parent_m, m)
        # Use unique lock for the mutexes to
        # simplify handling (parent will change)

        if self.parent is None:
            return # nothing to do

        # Remove this item from the list of siblings
        if self._prev_sibling is not None:
            lock_gil_friendly(sibling_m, self._prev_sibling.mutex)
            self._prev_sibling._next_sibling = self._next_sibling
            sibling_m.unlock()
        if self._next_sibling is not None:
            lock_gil_friendly(sibling_m, self._next_sibling.mutex)
            self._next_sibling._prev_sibling = self._prev_sibling
            sibling_m.unlock()
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
                elif self._parent.last_plot_element_child is self:
                    self._parent.last_plot_element_child = self._prev_sibling
                elif self._parent.last_handler_child is self:
                    self._parent.last_handler_child = self._prev_sibling
                elif self._parent.last_theme_child is self:
                    self._parent.last_theme_child = self._prev_sibling
        # Free references
        self._parent = None
        self._prev_sibling = None
        self._next_sibling = None

    cpdef void detach_item(self):
        """
        Same as item.parent = None

        The item states (if any) are updated
        to indicate it is not rendered anymore,
        and the information propagated to the
        children.
        """
        cdef unique_lock[recursive_mutex] m0
        cdef unique_lock[recursive_mutex] m
        self.__detach_item_and_lock(m)
        # Mark as hidden. Useful for OtherItemHandler
        # when we want to detect loss of hover, render, etc
        self.set_hidden_and_propagate_to_siblings_no_handlers()

    cpdef void delete_item(self):
        """
        When an item is not referenced anywhere, it might
        not get deleted immediately, due to circular references.
        The Python garbage collector will eventually catch
        the circular references, but to speedup the process,
        delete_item will recursively detach the item
        and all elements in its subtree, as well as bound
        items. As a result, items with no more references
        will be freed immediately.
        """
        cdef unique_lock[recursive_mutex] sibling_m

        cdef unique_lock[recursive_mutex] m
        self.__detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        # Remove this item from the list of elements
        if self._prev_sibling is not None:
            lock_gil_friendly(sibling_m, self._prev_sibling.mutex)
            self._prev_sibling._next_sibling = self._next_sibling
            sibling_m.unlock()
        if self._next_sibling is not None:
            lock_gil_friendly(sibling_m, self._next_sibling.mutex)
            self._next_sibling._prev_sibling = self._prev_sibling
            sibling_m.unlock()
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
                elif self._parent.last_plot_element_child is self:
                    self._parent.last_plot_element_child = self._prev_sibling
                elif self._parent.last_handler_child is self:
                    self._parent.last_handler_child = self._prev_sibling
                elif self._parent.last_theme_child is self:
                    self._parent.last_theme_child = self._prev_sibling

        # delete all children recursively
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).__delete_and_siblings()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).__delete_and_siblings()
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).__delete_and_siblings()
        if self.last_payloads_child is not None:
            (<baseItem>self.last_payloads_child).__delete_and_siblings()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).__delete_and_siblings()
        if self.last_handler_child is not None:
            (<baseItem>self.last_handler_child).__delete_and_siblings()
        if self.last_theme_child is not None:
            (<baseItem>self.last_theme_child).__delete_and_siblings()
        # TODO: free item specific references (themes, font, etc)
        self.last_window_child = None
        self.last_widgets_child = None
        self.last_drawings_child = None
        self.last_payloads_child = None
        self.last_plot_element_child = None
        self.last_handler_child = None
        self.last_theme_child = None
        # Note we don't free self.context, nor
        # destroy anything else: the item might
        # still be referenced for instance in handlers,
        # and thus should be valid.

    cdef void __delete_and_siblings(self):
        # Must only be called from delete_item or itself.
        # Assumes the parent mutex is already held
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # delete all its children recursively
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).__delete_and_siblings()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).__delete_and_siblings()
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).__delete_and_siblings()
        if self.last_payloads_child is not None:
            (<baseItem>self.last_payloads_child).__delete_and_siblings()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).__delete_and_siblings()
        if self.last_handler_child is not None:
            (<baseItem>self.last_handler_child).__delete_and_siblings()
        if self.last_theme_child is not None:
            (<baseItem>self.last_theme_child).__delete_and_siblings()
        # delete previous sibling
        if self._prev_sibling is not None:
            (<baseItem>self._prev_sibling).__delete_and_siblings()
        # Free references
        self._parent = None
        self._prev_sibling = None
        self._next_sibling = None
        self.last_window_child = None
        self.last_widgets_child = None
        self.last_drawings_child = None
        self.last_payloads_child = None
        self.last_plot_element_child = None
        self.last_handler_child = None
        self.last_theme_child = None

    @cython.final # The final is for performance, to avoid a virtual function and thus allow inlining
    cdef void set_previous_states(self) noexcept nogil:
        # Move current state to previous state
        if self.p_state != NULL:
            memcpy(<void*>&self.p_state.prev, <void*>&self.p_state.cur, sizeof(self.p_state.cur))

    @cython.final
    cdef void run_handlers(self) noexcept nogil:
        cdef int i
        if not(self._handlers.empty()):
            for i in range(<int>self._handlers.size()):
                (<baseHandler>(self._handlers[i])).run_handler(self)

    @cython.final
    cdef void update_current_state_as_hidden(self) noexcept nogil:
        """
        Indicates the object is hidden
        """
        if (self.p_state == NULL):
            # No state
            return
        cdef bint open = self.p_state.cur.open
        memset(<void*>&self.p_state.cur, 0, sizeof(self.p_state.cur))
        # being open/closed is unaffected by being hidden
        self.p_state.cur.open = open

    @cython.final
    cdef void propagate_hidden_state_to_children_with_handlers(self) noexcept nogil:
        """
        Called during rendering only.
        The item has children, but will not render them
        (closed window, etc). The item itself might, or
        might not be rendered.
        Propagate the hidden state to children and call
        their handlers.

        Used also to avoid duplication in the functions below.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).set_hidden_and_propagate_to_siblings_with_handlers()
        # handlers, themes, payloads, have no states and no children that can have some.
        # TODO: plotAxis

    @cython.final
    cdef void propagate_hidden_state_to_children_no_handlers(self) noexcept nogil:
        """
        Same as above, but will not call any handlers. Used as helper for functions below
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).set_hidden_and_propagate_to_siblings_no_handlers()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).set_hidden_and_propagate_to_siblings_no_handlers()
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).set_hidden_and_propagate_to_siblings_no_handlers()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).set_hidden_and_propagate_to_siblings_no_handlers()

    @cython.final
    cdef void set_hidden_and_propagate_to_siblings_with_handlers(self) noexcept nogil:
        """
        A parent item is hidden and this item is not going to be rendered.
        Propagate to children and siblings.
        Called during rendering, thus we call the handlers, in order to help
        users catch an item getting hidden.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.set_previous_states()
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_with_handlers()
            self.run_handlers()
        if self._prev_sibling is not None:
            self._prev_sibling.set_hidden_and_propagate_to_siblings_with_handlers()

    @cython.final
    cdef void set_hidden_and_propagate_to_siblings_no_handlers(self) noexcept nogil:
        """
        Same as above, version without calling handlers:
        Item is programmatically made hidden, but outside rendering,
        for instance by detaching it.

        The item might still be shown the next frame, and have been
        shown the frame before.

        What this function does is set the current state of item and
        its children to a hidden state, but not running any handler.
        This has these effects:
        TODO . If item was shown the frame before and is still shown,
          there will be no jump in the item status (for example
          it won't go from rendered, to not rendered, to rendered),
          as the current state will be overwritten when frame is rendered.
        . Possibly undesired effect, but with limited implications:
          when the item states will be read by the user before the frame
          is rendered, it will show the default hidden values.
        . The main reason we are doing this: if the item is not rendered,
          the states are correct (else they would remain as rendered forever),
          and thus we can have handlers attached to other items using
          OtherItemHandler to catch this item being not rendered. This is
          required for instance for items that should destroy when
          an item is not rendered anymore. 
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_no_handlers()
        if self._prev_sibling is not None:
            self._prev_sibling.set_hidden_and_propagate_to_siblings_no_handlers()

    @cython.final
    cdef void set_hidden_no_handler_and_propagate_to_children_with_handlers(self) noexcept nogil:
        """
        The item is hidden, wants its state to be set to hidden, but
        manages itself his previous state and his handlers.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_with_handlers()

    def lock_mutex(self, wait=False):
        """
        Lock the internal item mutex.
        **Know what you are doing**
        Locking the mutex will prevent:
        . Other threads from reading/writing
          attributes or calling methods with this item,
          editing the children/parent of the item
        . Any rendering of this item and its children.
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
            while not(locked):
                with nogil:
                    # Wait the one holding the lock is done
                    # with it
                    self.mutex.lock()
                    # Unlock because we do not want to
                    # deadlock when acquiring the gil
                    self.mutex.unlock()
                locked = self.mutex.try_lock()
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

    @property
    def mutex(self):
        """
        Context manager instance for the item mutex

        Locking the mutex will prevent:
        . Other threads from reading/writing
          attributes or calling methods with this item,
          editing the children/parent of the item
        . Any rendering of this item and its children.
          If the viewport attemps to render this item,
          it will be blocked until the mutex is released.
          (if the rendering thread is holding the mutex,
           no blocking occurs)

        In general, you don't need to use any mutex in your code,
        unless you are writing a library and cannot make assumptions
        on what the users will do, or if you know your code manipulates
        the same objects with multiple threads.

        All attribute accesses are mutex protected.

        If you want to subclass and add attributes, you
        can use this mutex to protect your new attributes.
        Be careful not to hold the mutex if your thread
        intends to access the attributes of a parent item.
        In case of doubt use parents_mutex instead.
        """
        return wrap_mutex(self)

    @property
    def parents_mutex(self):
        """Context manager instance for the item mutex and all its parents
        
        Similar to mutex but locks not only this item, but also all
        its current parents.
        If you want to access parent fields, or if you are unsure,
        lock this mutex rather than self.mutex.
        This mutex will lock the item and all its parent in a safe
        way that does not deadlock.
        """
        return wrap_this_and_parents_mutex(self)

class wrap_mutex:
    def __init__(self, target):
        self.target = target
    def __enter__(self):
        self.target.lock_mutex(wait=True)
    def __exit__(self, exc_type, exc_value, traceback):
        self.target.unlock_mutex()
        return False # Do not catch exceptions

class wrap_this_and_parents_mutex:
    def __init__(self, target):
        self.target = target
        self.locked = []
        self.nlocked = []
        # TODO: Should we use thread-local here ?
    def __enter__(self):
        while True:
            locked = []
            # try_lock recursively all parents
            item = self.target
            success = True
            while item is not None:
                success = item.lock_mutex(wait=False)
                if not(success):
                    break
                locked.append(item)
                # we have a mutex on item, we can
                # access its parent field without
                # worrying it could change
                item = item.parent
            if success:
                self.locked += locked
                self.nlocked.append(len(locked))
                return
            # We failed to lock one of the parent.
            # We must release our locks and retry
            for item in locked:
                item.unlock_mutex()
            # release gil and give a chance to the
            # thread retaining the lock to run
            os.sched_yield()
    def __exit__(self, exc_type, exc_value, traceback):
        cdef int N = self.nlocked.pop()
        cdef int i
        for i in range(N):
            self.locked.pop().unlock_mutex()
        return False # Do not catch exceptions


@cython.final
@cython.no_gc_clear
cdef class Viewport(baseItem):
    """
    The viewport corresponds to the main item containing
    all the visuals. It is decorated by the operating system,
    and can be minimized/maximized/made fullscreen.

    Rendering starts from the viewports and recursively
    every item renders itself and its children.
    """
    def __cinit__(self, context):
        self.resize_callback = None
        self.can_have_window_child = True
        self.can_have_menubar_child = True
        self.can_have_sibling = False
        self.last_t_before_event_handling = ctime.monotonic_ns()
        self.last_t_before_rendering = self.last_t_before_event_handling
        self.last_t_after_rendering = self.last_t_before_event_handling
        self.last_t_after_swapping = self.last_t_before_event_handling
        self.frame_count = 0
        self.state.cur.rendered = True # For compatibility with RenderHandlers
        self.p_state = &self.state
        self._cursor = imgui.ImGuiMouseCursor_Arrow
        self._scale = 1.
        self.viewport = mvCreateViewport(internal_render_callback,
                                         internal_resize_callback,
                                         internal_close_callback,
                                         <void*>self)
        if self.viewport == NULL:
            raise RuntimeError("Failed to create the viewport")

    def __dealloc__(self):
        # NOTE: Called BEFORE the context is released.
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex_backend) # To not release while we render a frame
        ensure_correct_im_context(self.context)
        if self.initialized:
            cleanup_graphics(self.graphics)
        if self.viewport != NULL:
            mvCleanupViewport(dereference(self.viewport))
            #self.viewport is freed by mvCleanupViewport
            self.viewport = NULL

    def initialize(self, minimized=False, maximized=False, **kwargs):
        """
        Initialize the viewport for rendering and show it.
        Items can already be created and attached to the viewport
        before this call.
        Creates the default font and attaches it to the viewport
        if None is set already. This font is scaled by
        the current value of viewport.dpi.
        In addition all the default style spaces are scaled by
        the current viewport.dpi.
        The viewport.dpi content is not read after that, and
        so changes will have no effect.
        """
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        self.configure(**kwargs)
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self.mutex_backend)
        ensure_correct_im_context(self.context)
        if self.initialized:
            raise RuntimeError("Viewport already initialized")
        ensure_correct_im_context(self.context)
        mvShowViewport(dereference(self.viewport),
                       minimized,
                       maximized)
        self.graphics = setup_graphics(dereference(self.viewport))
        imgui.StyleColorsDark()
        imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = True
        imgui.GetStyle().ScaleAllSizes(self.viewport.dpi)
        cdef FontTexture default_font_texture
        if self._font is None:
            default_font_texture = FontTexture(self.context)
            # latin modern roman fonts look nice and behave well
            # when scaled
            default_font_path = os.path.dirname(__file__)
            path = os.path.join(default_font_path, 'lmsans17-regular.otf')
            default_font_texture.add_font_file(path, size=int(round(17 * self.viewport.dpi)), density_scale=2.)
            default_font_texture.build()
            self._font = default_font_texture[0]
        self.initialized = True
        """
            # TODO if (GContext->IO.autoSaveIniFile). if (!GContext->IO.iniFile.empty())
			# io.IniFilename = GContext->IO.iniFile.c_str();

            # TODO if(GContext->IO.kbdNavigation)
		    # io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;  // Enable Keyboard Controls
            #if(GContext->IO.docking)
            # io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
            # io.ConfigDockingWithShift = GContext->IO.dockingShiftOnly;
        """

    cdef void __check_initialized(self):
        if not(self.initialized):
            raise RuntimeError("The viewport must be initialized before being used")

    cdef void __check_not_initialized(self):
        if self.initialized:
            raise RuntimeError("The viewport must be not be initialized to set this field")

    @property
    def clear_color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.viewport.clearColor.r,
                self.viewport.clearColor.g,
                self.viewport.clearColor.b,
                self.viewport.clearColor.a)

    @clear_color.setter
    def clear_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int r, g, b, a
        (r, g, b, a) = value
        self.viewport.clearColor = colorFromInts(r, g, b, a)

    @property
    def small_icon(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self.viewport.small_icon)

    @small_icon.setter
    def small_icon(self, str value):
        cdef unique_lock[recursive_mutex] m
        self.__check_not_initialized()
        self.viewport.small_icon = value.encode("utf-8")

    @property
    def large_icon(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self.viewport.large_icon)

    @large_icon.setter
    def large_icon(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_not_initialized()
        self.viewport.large_icon = value.encode("utf-8")

    @property
    def x_pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.xpos

    @x_pos.setter
    def x_pos(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.xpos = value
        self.viewport.posDirty = 1

    @property
    def y_pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.ypos

    @y_pos.setter
    def y_pos(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.ypos = value
        self.viewport.posDirty = 1

    @property
    def width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.actualWidth

    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.actualWidth = value
        self.viewport.sizeDirty = 1

    @property
    def height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.actualHeight

    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.actualHeight = value
        self.viewport.sizeDirty = 1

    @property
    def resizable(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.resizable

    @resizable.setter
    def resizable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.resizable = value
        self.viewport.modesDirty = 1

    @property
    def vsync(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.vsync

    @vsync.setter
    def vsync(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.vsync = value

    @property
    def dpi(self) -> float:
        """
        Requested scaling (DPI) from the OS for
        this window. The value is valid after
        initialize() and might change over time,
        for instance if the window is moved to another
        monitor.

        The DPI is used to scale all items automatically.
        From the developper point of view, everything behaves
        as if the DPI is 1. This behaviour can be disabled
        using the related scaling settings.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.dpi

    @property
    def scale(self) -> float:
        """
        Multiplicative scale that, multiplied by
        the value of dpi, is used to scale
        automatically all items.

        Defaults to 1.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale

    @scale.setter
    def scale(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale = value

    @property
    def min_width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.minwidth

    @min_width.setter
    def min_width(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.minwidth = value
        self.viewport.sizeDirty = True

    @property
    def max_width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.maxwidth

    @max_width.setter
    def max_width(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.maxwidth = value
        self.viewport.sizeDirty = True

    @property
    def min_height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.minheight

    @min_height.setter
    def min_height(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.minheight = value
        self.viewport.sizeDirty = True

    @property
    def max_height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.maxheight

    @max_height.setter
    def max_height(self, unsigned value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.maxheight = value
        self.viewport.sizeDirty = True

    @property
    def always_on_top(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.alwaysOnTop

    @always_on_top.setter
    def always_on_top(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.alwaysOnTop = value
        self.viewport.modesDirty = 1

    @property
    def decorated(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.decorated

    @decorated.setter
    def decorated(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.decorated = value
        self.viewport.modesDirty = 1

    @property
    def handlers(self):
        """
        Writable attribute: bound handler (or handlerList)
        for the viewport.
        Only Key and Mouse handlers are compatible.
        Handlers that check item states won't work.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @handlers.setter
    def handlers(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

    @property
    def cursor(self):
        """
        Change the mouse cursor to one of mouse_cursor.
        The mouse cursor is reset every frame.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <mouse_cursor>self._cursor

    @cursor.setter
    def cursor(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < imgui.ImGuiMouseCursor_None or \
           value >= imgui.ImGuiMouseCursor_COUNT:
            raise ValueError("Invalid cursor type {value}")
        self._cursor = value

    @property
    def font(self):
        """
        Writable attribute: global font
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, Font value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

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
        return str(self.viewport.title)

    @title.setter
    def title(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.title = value.encode("utf-8")
        self.viewport.titleDirty = 1

    @property
    def disable_close(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.viewport.disableClose

    @disable_close.setter
    def disable_close(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        cdef unique_lock[recursive_mutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self.mutex_backend)
        ensure_correct_im_context(self.context)
        if value and not(self.viewport.fullScreen):
            mvToggleFullScreen(dereference(self.viewport))
        elif not(value) and (self.viewport.fullScreen):
            # Same call
            mvToggleFullScreen(dereference(self.viewport))
    @property
    def minimized(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return None #TODO

    @minimized.setter
    def minimized(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self.mutex_backend)
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
        cdef unique_lock[recursive_mutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self.mutex_backend)
        ensure_correct_im_context(self.context)
        if value:
            mvMaximizeViewport(dereference(self.viewport))
        else:
            mvRestoreViewport(dereference(self.viewport))

    @property
    def wait_for_input(self):
        """
        Writable attribute: When the app doesn't need to be
        refreshed, one can save power comsumption by not
        rendering. wait_for_input will pause rendering until
        a mouse or keyboard event is received.
        wake() can also be used to restart rendering
        for one frame.
        """
        return self.viewport.waitForEvents

    @wait_for_input.setter
    def wait_for_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.waitForEvents = value

    @property
    def shown(self) -> bool:
        """
        Whether the viewport window has been created by the
        operating system.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.initialized

    @property
    def resize_callback(self):
        """
        Callback to be issued when the viewport is resized.

        The data returned is a tuple containing:
        . The width in pixels
        . The height in pixels
        . The width according to the OS (OS dependent)
        . The height according to the OS (OS dependent)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._resize_callback

    @resize_callback.setter
    def resize_callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._resize_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def close_callback(self):
        """
        Callback to be issued when the viewport is closed.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._close_callback

    @close_callback.setter
    def close_callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._close_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def metrics(self):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)

        """
        Return rendering related metrics relative to the last
        frame.
        times are returned in ns and use the monotonic clock
        delta of times are return in float as seconds.

        Render frames does in the folowing order:
        event handling (wait_for_input has effect there)
        rendering (going through all objects and calling imgui)
        presenting to the os (send to the OS the rendered frame)

        No average is performed. To get FPS, one can
        average delta_whole_frame and invert it.

        frame_count corresponds to the frame number to which
        the data refers to.
        """
        return {
            "last_time_before_event_handling" : self.last_t_before_event_handling,
            "last_time_before_rendering" : self.last_t_before_rendering,
            "last_time_after_rendering" : self.last_t_after_rendering,
            "last_time_after_swapping": self.last_t_after_swapping,
            "delta_event_handling": self.delta_event_handling,
            "delta_rendering": self.delta_rendering,
            "delta_presenting": self.delta_swapping,
            "delta_whole_frame": self.delta_frame,
            "rendered_vertices": imgui.GetIO().MetricsRenderVertices,
            "rendered_indices": imgui.GetIO().MetricsRenderIndices,
            "rendered_windows": imgui.GetIO().MetricsRenderWindows,
            "active_windows": imgui.GetIO().MetricsActiveWindows,
            "frame_count" : self.frame_count-1,
        }

    def configure(self, **kwargs):
        for (key, value) in kwargs.items():
            setattr(self, key, value)

    cdef void __on_resize(self, int width, int height):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.viewport.actualHeight = height
        self.viewport.clientHeight = height
        self.viewport.actualWidth = width
        self.viewport.clientWidth = width
        self.viewport.resized = True
        self.context.queue_callback_arg4int(self._resize_callback,
                                            self,
                                            self,
                                            self.viewport.actualWidth,
                                            self.viewport.actualHeight,
                                            self.viewport.clientWidth,
                                            self.viewport.clientHeight)

    cdef void __on_close(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(<bint>self.viewport.disableClose):
            self.context.started = False
        self.context.queue_callback_noarg(self._close_callback, self, self)

    cdef void __render(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint any_change = False
        self.last_t_before_rendering = ctime.monotonic_ns()
        # Initialize drawing state
        imgui.SetMouseCursor(self._cursor)
        self._cursor = imgui.ImGuiMouseCursor_Arrow
        self.set_previous_states()
        if self._font is not None:
            self._font.push()
        if self._theme is not None: # maybe apply in render_frame instead ?
            self._theme.push()
        self.shifts = [0., 0.]
        self.scales = [1., 1.]
        self.in_plot = False
        self.start_pending_theme_actions = 0
        #if self.filedialogRoots is not None:
        #    self.filedialogRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        self.parent_pos = imgui.ImVec2(0., 0.)
        self.window_pos = imgui.ImVec2(0., 0.)
        imgui.PushID(self.uuid)
        if self.last_menubar_child is not None:
            self.last_menubar_child.draw()
        if self.last_window_child is not None:
            self.last_window_child.draw()
        #if self.last_viewport_drawlist_child is not None:
        #    self.last_viewport_drawlist_child.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        imgui.PopID()
        if self._theme is not None:
            self._theme.pop()
        if self._font is not None:
            self._font.pop()
        self.run_handlers()
        self.last_t_after_rendering = ctime.monotonic_ns()
        return

    cdef void apply_current_transform(self, float *dst_p, double[2] src_p) noexcept nogil:
        """
        Used during rendering as helper to convert drawing coordinates to pixel coordinates
        """
        # assumes imgui + viewport mutex are held

        cdef imgui.ImVec2 plot_transformed
        cdef double[2] p
        p[0] = src_p[0] * self.scales[0] + self.shifts[0]
        p[1] = src_p[1] * self.scales[1] + self.shifts[1]
        if self.in_plot:
            if self.plot_fit:
                implot.FitPointX(src_p[0])
                implot.FitPointY(src_p[1])
            plot_transformed = \
                implot.PlotToPixels(src_p[0],
                                    src_p[1],
                                    -1,
                                    -1)
            dst_p[0] = plot_transformed.x
            dst_p[1] = plot_transformed.y
        else:
            # When in a plot, PlotToPixel already handles that.
            dst_p[0] = <float>p[0]
            dst_p[1] = <float>p[1]

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


    def render_frame(self, bint can_skip_presenting=False):
        """
        Render one frame.

        Rendering occurs in several separated steps:
        . Mouse/Keyboard events are processed. it's there
          that wait_for_input has an effect.
        . The viewport item, and then all the rendering tree are
          walked through to query their state and prepare the rendering
          commands using ImGui, ImPlot and ImNodes
        . The rendering commands are submitted to the GPU.
        . The submission is passed to the operating system to handle the
          window update. It's usually at this step that the system will
          apply vsync by making the application wait if it rendered faster
          than the screen refresh rate.

        can_skip_presenting: rendering will occur (handlers checked, etc),
            but the backend might decide, if this flag is set, to not
            submit the rendering commands to the GPU and refresh the
            window. Can be used to avoid using the GPU in response
            to a simple mouse motion.
            Fast checks are used to determine if presenting should occur
            or not. Thus set this only if you haven't updated any content
            on the screen.
            Note wake() will automatically force a redraw the next frame.

        Returns True if the frame was presented to the screen,
            False else (can_skip_presenting)
        """
        # to lock in this order
        cdef unique_lock[recursive_mutex] imgui_m = unique_lock[recursive_mutex](self.context.imgui_mutex, defer_lock_t())
        cdef unique_lock[recursive_mutex] self_m
        cdef unique_lock[recursive_mutex] backend_m = unique_lock[recursive_mutex](self.mutex_backend, defer_lock_t())
        lock_gil_friendly(self_m, self.mutex)
        self.__check_initialized()
        self.last_t_before_event_handling = ctime.monotonic_ns()
        cdef bint should_present
        cdef float gs = self.global_scale
        self.global_scale = self.viewport.dpi * self._scale
        cdef imgui.ImGuiStyle *style = &imgui.GetStyle()
        cdef implot.ImPlotStyle *style_p = &implot.GetStyle()
        # Handle scaling
        if gs != self.global_scale:
            gs = self.global_scale
            style.WindowPadding = imgui.ImVec2(cround(gs*8), cround(gs*8))
            #style.WindowRounding = cround(gs*0.)
            style.WindowMinSize = imgui.ImVec2(cround(gs*32), cround(gs*32))
            #style.ChildRounding = cround(gs*0.)
            #style.PopupRounding = cround(gs*0.)
            style.FramePadding = imgui.ImVec2(cround(gs*4.), cround(gs*3.))
            #style.FrameRounding = cround(gs*0.)
            style.ItemSpacing = imgui.ImVec2(cround(gs*8.), cround(gs*4.))
            style.ItemInnerSpacing = imgui.ImVec2(cround(gs*4.), cround(gs*4.))
            style.CellPadding = imgui.ImVec2(cround(gs*4.), cround(gs*2.))
            #style.TouchExtraPadding = imgui.ImVec2(cround(gs*0.), cround(gs*0.))
            style.IndentSpacing = cround(gs*21.)
            style.ColumnsMinSpacing = cround(gs*6.)
            style.ScrollbarSize = cround(gs*14.)
            style.ScrollbarRounding = cround(gs*9.)
            style.GrabMinSize = cround(gs*12.)
            #style.GrabRounding = cround(gs*0.)
            style.LogSliderDeadzone = cround(gs*4.)
            style.TabRounding = cround(gs*4.)
            #style.TabMinWidthForCloseButton = cround(gs*0.)
            style.TabBarOverlineSize = cround(gs*2.)
            style.SeparatorTextPadding = imgui.ImVec2(cround(gs*20.), cround(gs*3.))
            style.DisplayWindowPadding = imgui.ImVec2(cround(gs*19.), cround(gs*19.))
            style.DisplaySafeAreaPadding = imgui.ImVec2(cround(gs*3.), cround(gs*3.))
            style.MouseCursorScale = gs*1.
            style_p.LineWeight = gs*1.
            style_p.MarkerSize = gs*4.
            style_p.MarkerWeight = gs*1
            style_p.ErrorBarSize = cround(gs*5.)
            style_p.ErrorBarWeight = gs * 1.5
            style_p.DigitalBitHeight = cround(gs * 8.)
            style_p.DigitalBitGap = cround(gs * 4.)
            style_p.MajorTickLen = imgui.ImVec2(gs*10, gs*10)
            style_p.MinorTickLen = imgui.ImVec2(gs*5, gs*5)
            style_p.MajorTickSize = imgui.ImVec2(gs*1, gs*1)
            style_p.MinorTickSize = imgui.ImVec2(gs*1, gs*1)
            style_p.MajorGridSize = imgui.ImVec2(gs*1, gs*1)
            style_p.MinorGridSize = imgui.ImVec2(gs*1, gs*1)
            style_p.PlotPadding = imgui.ImVec2(cround(gs*10), cround(gs*10))
            style_p.LabelPadding = imgui.ImVec2(cround(gs*5), cround(gs*5))
            style_p.LegendPadding = imgui.ImVec2(cround(gs*10), cround(gs*10))
            style_p.LegendInnerPadding = imgui.ImVec2(cround(gs*5), cround(gs*5))
            style_p.LegendSpacing = imgui.ImVec2(cround(gs*5), cround(gs*0))
            style_p.MousePosPadding = imgui.ImVec2(cround(gs*10), cround(gs*10))
            style_p.AnnotationPadding = imgui.ImVec2(cround(gs*2), cround(gs*2))
            style_p.PlotDefaultSize = imgui.ImVec2(cround(gs*400), cround(gs*300))
            style_p.PlotMinSize = imgui.ImVec2(cround(gs*200), cround(gs*150))
        with nogil:
            backend_m.lock()
            self_m.unlock()
            # Process input events.
            # Doesn't need imgui mutex.
            # if wait_for_input is set, can take a long time
            mvProcessEvents(self.viewport)
            backend_m.unlock() # important to respect lock order
            # Core rendering - uses imgui and viewport
            imgui_m.lock()
            self_m.lock()
            backend_m.lock()
            #self.last_t_before_rendering = ctime.monotonic_ns()
            ensure_correct_im_context(self.context)
            #imgui.GetMainViewport().DpiScale = self.viewport.dpi
            #imgui.GetIO().FontGlobalScale = self.viewport.dpi
            should_present = \
                mvRenderFrame(dereference(self.viewport),
                              self.graphics,
                              can_skip_presenting)
            #self.last_t_after_rendering = ctime.monotonic_ns()
            backend_m.unlock()
            self_m.unlock()
            imgui_m.unlock()
            # Present doesn't use imgui but can take time (vsync)
            backend_m.lock()
            if should_present:
                mvPresent(self.viewport)
            backend_m.unlock()
        if not(should_present) and self.viewport.vsync:
            # cap 'cpu' framerate when not presenting
            python_time.sleep(0.005)
        lock_gil_friendly(self_m, self.mutex)
        cdef long long current_time = ctime.monotonic_ns()
        self.delta_frame = 1e-9 * <float>(current_time - self.last_t_after_swapping)
        self.last_t_after_swapping = current_time
        self.delta_swapping = 1e-9 * <float>(current_time - self.last_t_after_rendering)
        self.delta_rendering = 1e-9 * <float>(self.last_t_after_rendering - self.last_t_before_rendering)
        self.delta_event_handling = 1e-9 * <float>(self.last_t_before_rendering - self.last_t_before_event_handling)
        if self.viewport.resized:
            self.context.queue_callback_arg4int(self._resize_callback,
                                                self,
                                                self,
                                                self.viewport.actualWidth,
                                                self.viewport.actualHeight,
                                                self.viewport.clientWidth,
                                                self.viewport.clientHeight)
            self.viewport.resized = False
        self.frame_count += 1
        assert(self.pending_theme_actions.empty())
        assert(self.applied_theme_actions.empty())
        assert(self.start_pending_theme_actions == 0)
        return should_present

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

    cdef void cwake(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        mvWakeRendering(dereference(self.viewport))


cdef class Callback:
    """
    Wrapper class that automatically encapsulate
    callbacks.

    Callbacks in DCG mode can take up to 3 arguments:
    . source_item: the item to which the callback was attached
    . target_item: the item for which the callback was raised.
        Is only different to source_item for handlers' callback.
    . call_info: If applicable information about the call (key button, etc)
    """
    def __init__(self, *args, **kwargs):
        if self.num_args > 3:
            raise ValueError("Callback function takes too many arguments")
    def __cinit__(self, callback, *args, **kwargs):
        if not(callable(callback)):
            raise TypeError("Callback requires a callable object")
        self.callback = callback
        cdef int num_defaults = 0
        if callback.__defaults__ is not None:
            num_defaults = len(callback.__defaults__)
        self.num_args = callback.__code__.co_argcount - num_defaults
        if hasattr(callback, '__self__'):
            self.num_args -= 1

    def __call__(self, source_item, target_item, call_info):
        try:
            if self.num_args == 3:
                self.callback(source_item, target_item, call_info)
            elif self.num_args == 2:
                self.callback(source_item, target_item)
            elif self.num_args == 1:
                self.callback(source_item)
            else:
                self.callback()
        except Exception as e:
            print(f"Callback {self.callback} raised exception {e}")
            if self.num_args == 3:
                print(f"Callback arguments were: {source_item}, {target_item}, {call_info}")
            if self.num_args == 2:
                print(f"Callback arguments were: {source_item}, {target_item}")
            if self.num_args == 1:
                print(f"Callback argument was: {source_item}")
            else:
                print("Callback called without arguments")
            print(traceback.format_exc())

cdef class DPGCallback(Callback):
    """
    Used to run callbacks created for DPG
    """
    def __call__(self, source_item, target_item, call_info):
        try:
            if source_item is not target_item:
                if isinstance(call_info, tuple):
                    call_info = tuple(list(call_info) + [target_item])
            if self.num_args == 3:
                self.callback(source_item.uuid, call_info, source_item.user_data)
            elif self.num_args == 2:
                self.callback(source_item.uuid, call_info)
            elif self.num_args == 1:
                self.callback(source_item.uuid)
            else:
                self.callback()
        except Exception as e:
            print(f"Callback {self.callback} raised exception {e}")
            if self.num_args == 3:
                print(f"Callback arguments were: {source_item.uuid} (for {source_item}), {call_info}, {source_item.user_data}")
            if self.num_args == 2:
                print(f"Callback arguments were: {source_item.uuid} (for {source_item}), {call_info}")
            if self.num_args == 1:
                print(f"Callback argument was: {source_item.uuid} (for {source_item})")
            else:
                print("Callback called without arguments")
            print(traceback.format_exc())

"""
PlaceHolder parent
To store items outside the rendering tree
Can be parent to anything.
Cannot have any parent. Thus cannot render.
"""
cdef class PlaceHolderParent(baseItem):
    def __cinit__(self):
        self.can_have_drawing_child = True
        self.can_have_handler_child = True
        self.can_have_menubar_child = True
        self.can_have_payload_child = True
        self.can_have_tab_child = True
        self.can_have_theme_child = True
        self.can_have_widget_child = True
        self.can_have_window_child = True


"""
States used by many items
"""

cdef void update_current_mouse_states(itemState& state) noexcept nogil:
    """
    Helper to fill common states. Must be called after the hovered state is updated
    """
    cdef int i
    if state.cap.can_be_clicked:
        if state.cur.hovered:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                state.cur.clicked[i] = imgui.IsMouseClicked(i, False)
                state.cur.double_clicked[i] = imgui.IsMouseDoubleClicked(i)
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                state.cur.clicked[i] = False
                state.cur.double_clicked[i] = False
    cdef bint dragging
    if state.cap.can_be_dragged:
        if state.cur.hovered:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                dragging = imgui.IsMouseDragging(i, -1.)
                state.cur.dragging[i] = dragging
                if dragging:
                    state.cur.drag_deltas[i] = imgui.GetMouseDragDelta(i, -1.)
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                state.cur.dragging[i] = False

"""
Drawing items
"""


cdef class drawingItem(baseItem):
    """
    A simple item with no UI state,
    that inherit from the drawing area of its
    parent
    """
    def __cinit__(self):
        self._show = True
        self.element_child_category = child_type.cat_drawing
        self.can_have_sibling = True

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
        return self._show
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_siblings_no_handlers()
        self._show = value

    cdef void draw_prev_siblings(self, imgui.ImDrawList* l) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<drawingItem>self._prev_sibling).draw(l)

    cdef void draw(self, imgui.ImDrawList* l) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(l)

cdef class DrawingList(drawingItem):
    """
    A simple drawing item that renders its children.
    Useful to arrange your items and quickly
    hide/show/delete them by manipulating the list.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # draw children
        self.last_drawings_child.draw(drawlist)

cdef class DrawingListScale(drawingItem):
    """
    Similar to a DrawingList, but
    can apply shift and scale to the data
    """
    def __cinit__(self):
        self._scales = [1., 1.]
        self._shifts = [0., 0.]
        self._no_parent_scale = False
        self.can_have_drawing_child = True

    @property
    def scales(self):
        """
        Scales applied to the x and y axes
        Default is (1., 1.).
        The scales multiply any previous scales
        already set (including plot scales).
        Use no_parent_scale to remove that behaviour.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scales

    @scales.setter
    def scales(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scales[0] = values[0]
        self._scales[1] = values[1]

    @property
    def shifts(self):
        """
        Shifts applied to the x and y axes.
        Default is (0., 0.)
        The shifts are applied any previous
        shift and scale.
        For instance on x, the transformation to
        screen space is:
        parent_x_transform(x * scales[0] + shifts[0])
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._shifts

    @shifts.setter
    def shifts(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._shifts[0] = values[0]
        self._shifts[1] = values[1]

    @property
    def no_parent_scale(self):
        """
        Resets any previous scaling to screen space.
        shifts are transformed to screen space using
        the parent transform and serves as origin (0, 0)
        for the child coordinates.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_parent_scale

    @no_parent_scale.setter
    def no_parent_scale(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_parent_scale = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # save states
        cdef double[2] cur_scales = self.context._viewport.scales
        cdef double[2] cur_shifts = self.context._viewport.shifts
        cdef bint cur_in_plot = self.context._viewport.in_plot

        cdef float[2] p
        if self._no_parent_scale:
            self.context._viewport.apply_current_transform(p, self._shifts)
            self.context._viewport.scales = self._scales
            self.context._viewport.shifts[0] = <double>p[0]
            self.context._viewport.shifts[1] = <double>p[1]
            self.context._viewport.in_plot = False
        else:
            self.context._viewport.scales[0] = cur_scales[0] * self._scales[0]
            self.context._viewport.scales[1] = cur_scales[1] * self._scales[1]
            self.context._viewport.shifts[0] = self.context._viewport.shifts[0] + cur_scales[0] * self._shifts[0]
            self.context._viewport.shifts[1] = self.context._viewport.shifts[1] + cur_scales[1] * self._shifts[1]
            # TODO investigate if it'd be better if we do or not:
            # maybe instead have the multipliers as params
            #if cur_in_plot:
            #    self.thickness_multiplier *= cur_scales[0]
            #    self.size_multiplier *= cur_scales[0]

        # draw children
        self.last_drawings_child.draw(drawlist)

        # restore states
        self.context._viewport.scales = cur_scales
        self.context._viewport.shifts = cur_shifts
        self.context._viewport.in_plot = cur_in_plot

cdef class DrawArrow_(drawingItem):
    def __cinit__(self):
        # p1, p2, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.
        self.size = 4.

    cdef void __compute_tip(self):
        # Copy paste from original code

        cdef double xsi = self.end[0]
        cdef double xfi = self.start[0]
        cdef double ysi = self.end[1]
        cdef double yfi = self.start[1]

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

        cdef double x1 = <double>(xsi - xoffset * cos(angle))
        cdef double y1 = <double>(ysi - yoffset * sin(angle))
        self.corner1 = [x1 - 0.5 * self.size * sin(angle),
                        y1 + 0.5 * self.size * cos(angle)]
        self.corner2 = [x1 + 0.5 * self.size * cos((M_PI / 2.0) - angle),
                        y1 - 0.5 * self.size * sin((M_PI / 2.0) - angle)]

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] tstart
        cdef float[2] tend
        cdef float[2] tcorner1
        cdef float[2] tcorner2
        self.context._viewport.apply_current_transform(tstart, self.start)
        self.context._viewport.apply_current_transform(tend, self.end)
        self.context._viewport.apply_current_transform(tcorner1, self.corner1)
        self.context._viewport.apply_current_transform(tcorner2, self.corner2)
        cdef imgui.ImVec2 itstart = imgui.ImVec2(tstart[0], tstart[1])
        cdef imgui.ImVec2 itend  = imgui.ImVec2(tend[0], tend[1])
        cdef imgui.ImVec2 itcorner1 = imgui.ImVec2(tcorner1[0], tcorner1[1])
        cdef imgui.ImVec2 itcorner2 = imgui.ImVec2(tcorner2[0], tcorner2[1])
        drawlist.AddTriangleFilled(itend, itcorner1, itcorner2, self.color)
        drawlist.AddLine(itend, itstart, self.color, thickness)
        drawlist.AddTriangle(itend, itcorner1, itcorner2, self.color, thickness)


cdef class DrawBezierCubic_(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 0.
        self.segments = 0

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        self.context._viewport.apply_current_transform(p4, self.p4)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        cdef imgui.ImVec2 ip4 = imgui.ImVec2(p4[0], p4[1])
        drawlist.AddBezierCubic(ip1, ip2, ip3, ip4, self.color, self.thickness, self.segments)

cdef class DrawBezierQuadratic_(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 0.
        self.segments = 0

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        drawlist.AddBezierQuadratic(ip1, ip2, ip3, self.color, self.thickness, self.segments)


cdef class DrawCircle_(drawingItem):
    def __cinit__(self):
        # center is zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.radius = 1.
        self.thickness = 1.
        self.segments = 0

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        cdef float radius = self.radius
        if self.context._viewport.in_plot:
            if thickness > 0:
                thickness *= self.context._viewport.thickness_multiplier
            if radius > 0:
                radius *= self.context._viewport.size_multiplier
        thickness = abs(thickness)
        radius = abs(radius)

        cdef float[2] center
        self.context._viewport.apply_current_transform(center, self.center)
        cdef imgui.ImVec2 icenter = imgui.ImVec2(center[0], center[1])
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            drawlist.AddCircleFilled(icenter, radius, self.fill, self.segments)
        drawlist.AddCircle(icenter, radius, self.color, self.segments, thickness)


cdef class DrawEllipse_(drawingItem):
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
        cdef double width = self.pmax[0] - self.pmin[0]
        cdef double height = self.pmax[1] - self.pmin[1]
        cdef double cx = width / 2. + self.pmin[0]
        cdef double cy = height / 2. + self.pmin[1]
        cdef double radian_inc = (M_PI * 2.) / <double>segments
        self.points.clear()
        self.points.reserve(segments+1)
        cdef int i
        # vector needs double4 rather than double[4]
        cdef double4 p
        width = abs(width)
        height = abs(height)
        for i in range(segments):
            p.p[0] = cx + cos(<double>i * radian_inc) * width / 2.
            p.p[1] = cy - sin(<double>i * radian_inc) * height / 2.
            self.points.push_back(p)
        self.points.push_back(self.points[0])

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show) or self.points.size() < 3:
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef vector[imgui.ImVec2] transformed_points
        transformed_points.reserve(self.points.size())
        cdef int i
        cdef float[2] p
        for i in range(<int>self.points.size()):
            self.context._viewport.apply_current_transform(p, self.points[i].p)
            transformed_points.push_back(imgui.ImVec2(p[0], p[1]))
        # TODO imgui requires clockwise order for correct AA
        # Reverse order if needed
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            drawlist.AddConvexPolyFilled(transformed_points.data(),
                                                <int>transformed_points.size(),
                                                self.fill)
        drawlist.AddPolyline(transformed_points.data(),
                                    <int>transformed_points.size(),
                                    self.color,
                                    0,
                                    thickness)


cdef class DrawImage_(drawingItem):
    def __cinit__(self):
        self.uv = [0., 0., 1., 1.]
        self.color_multiplier = 4294967295 # 0xffffffff

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return
        if self.texture is None:
            return
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.texture.mutex)
        if self.texture.allocated_texture == NULL:
            return

        cdef float[2] pmin
        cdef float[2] pmax
        self.context._viewport.apply_current_transform(pmin, self.pmin)
        self.context._viewport.apply_current_transform(pmax, self.pmax)
        cdef imgui.ImVec2 ipmin = imgui.ImVec2(pmin[0], pmin[1])
        cdef imgui.ImVec2 ipmax = imgui.ImVec2(pmax[0], pmax[1])
        cdef imgui.ImVec2 uvmin = imgui.ImVec2(self.uv[0], self.uv[1])
        cdef imgui.ImVec2 uvmax = imgui.ImVec2(self.uv[2], self.uv[3])
        drawlist.AddImage(<imgui.ImTextureID>self.texture.allocated_texture, ipmin, ipmax, uvmin, uvmax, self.color_multiplier)


cdef class DrawImageQuad_(drawingItem):
    def __cinit__(self):
        self.uv1 = [0., 0.]
        self.uv2 = [0., 0.]
        self.uv3 = [0., 0.]
        self.uv4 = [0., 0.]
        self.color_multiplier = 4294967295 # 0xffffffff

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return
        if self.texture is None:
            return
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.texture.mutex)
        if self.texture.allocated_texture == NULL:
            return

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4

        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        self.context._viewport.apply_current_transform(p4, self.p4)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])
        cdef imgui.ImVec2 iuv1 = imgui.ImVec2(self.uv1[0], self.uv1[1])
        cdef imgui.ImVec2 iuv2 = imgui.ImVec2(self.uv2[0], self.uv2[1])
        cdef imgui.ImVec2 iuv3 = imgui.ImVec2(self.uv3[0], self.uv3[1])
        cdef imgui.ImVec2 iuv4 = imgui.ImVec2(self.uv4[0], self.uv4[1])
        drawlist.AddImageQuad(<imgui.ImTextureID>self.texture.allocated_texture, \
            ip1, ip2, ip3, ip4, iuv1, iuv2, iuv3, iuv4, self.color_multiplier)



cdef class DrawLine_(drawingItem):
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        drawlist.AddLine(ip1, ip2, self.color, thickness)

cdef class DrawPolyline_(drawingItem):
    def __cinit__(self):
        # points is empty init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.
        self.closed = False

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show) or self.points.size() < 2:
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip1_
        cdef imgui.ImVec2 ip2
        self.context._viewport.apply_current_transform(p, self.points[0].p)
        ip1 = imgui.ImVec2(p[0], p[1])
        ip1_ = ip1
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        cdef int i
        for i in range(1, <int>self.points.size()):
            self.context._viewport.apply_current_transform(p, self.points[i].p)
            ip2 = imgui.ImVec2(p[0], p[1])
            drawlist.AddLine(ip1, ip2, self.color, thickness)
            ip1 = ip2
        if self.closed and self.points.size() > 2:
            drawlist.AddLine(ip1_, ip2, self.color, thickness)

cdef inline bint is_counter_clockwise(imgui.ImVec2 p1,
                                      imgui.ImVec2 p2,
                                      imgui.ImVec2 p3) noexcept nogil:
    cdef float det = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    return det > 0.

cdef class DrawPolygon_(drawingItem):
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
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show) or self.points.size() < 2:
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip
        cdef vector[imgui.ImVec2] ipoints
        cdef int i
        cdef bint ccw
        ipoints.reserve(self.points.size())
        for i in range(<int>self.points.size()):
            self.context._viewport.apply_current_transform(p, self.points[i].p)
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
                    drawlist.AddTriangleFilled(ipoints[self.triangulation_indices[i, 0]],
                                                      ipoints[self.triangulation_indices[i, 2]],
                                                      ipoints[self.triangulation_indices[i, 1]],
                                                      self.fill)
                else:
                    drawlist.AddTriangleFilled(ipoints[self.triangulation_indices[i, 0]],
                                                      ipoints[self.triangulation_indices[i, 1]],
                                                      ipoints[self.triangulation_indices[i, 2]],
                                                      self.fill)

        # Draw closed boundary
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        for i in range(1, <int>self.points.size()):
            drawlist.AddLine(ipoints[i-1], ipoints[i], self.color, thickness)
        if self.points.size() > 2:
            drawlist.AddLine(ipoints[0], ipoints[<int>self.points.size()-1], self.color, thickness)


cdef class DrawQuad_(drawingItem):
    def __cinit__(self):
        # p1, p2, p3, p4 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4
        cdef bint ccw

        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        self.context._viewport.apply_current_transform(p4, self.p4)
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
                drawlist.AddTriangleFilled(ip1, ip3, ip2, self.fill)
            else:
                drawlist.AddTriangleFilled(ip1, ip2, ip3, self.fill)
            ccw = is_counter_clockwise(ip1,
                                       ip4,
                                       ip3)
            if ccw:
                drawlist.AddTriangleFilled(ip1, ip3, ip4, self.fill)
            else:
                drawlist.AddTriangleFilled(ip1, ip4, ip3, self.fill)

        drawlist.AddLine(ip1, ip2, self.color, thickness)
        drawlist.AddLine(ip2, ip3, self.color, thickness)
        drawlist.AddLine(ip3, ip4, self.color, thickness)
        drawlist.AddLine(ip4, ip1, self.color, thickness)


cdef class DrawRect_(drawingItem):
    def __cinit__(self):
        self.pmin = [0., 0.]
        self.pmax = [1., 1.]
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
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] pmin
        cdef float[2] pmax
        cdef imgui.ImVec2 ipmin
        cdef imgui.ImVec2 ipmax
        cdef imgui.ImU32 col_up_left = self.color_upper_left
        cdef imgui.ImU32 col_up_right = self.color_upper_right
        cdef imgui.ImU32 col_bot_left = self.color_bottom_left
        cdef imgui.ImU32 col_bot_right = self.color_bottom_right

        self.context._viewport.apply_current_transform(pmin, self.pmin)
        self.context._viewport.apply_current_transform(pmax, self.pmax)
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
                drawlist.AddRectFilledMultiColor(ipmin,
                                                        ipmax,
                                                        col_up_left,
                                                        col_up_right,
                                                        col_bot_left,
                                                        col_bot_right)
        else:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddRectFilled(ipmin,
                                              ipmax,
                                              self.fill,
                                              self.rounding,
                                              imgui.ImDrawFlags_RoundCornersAll)

        drawlist.AddRect(ipmin,
                                ipmax,
                                self.color,
                                self.rounding,
                                imgui.ImDrawFlags_RoundCornersAll,
                                thickness)

cdef class DrawText_(drawingItem):
    def __cinit__(self):
        self.color = 4294967295 # 0xffffffff
        self.size = 0. # 0: default size. DearPyGui uses 1. internally, then 10. in the wrapper.

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float[2] p

        self.context._viewport.apply_current_transform(p, self.pos)
        cdef imgui.ImVec2 ip = imgui.ImVec2(p[0], p[1])
        cdef float size = self.size
        if size > 0 and self.context._viewport.in_plot:
            size *= self.context._viewport.size_multiplier
        size = abs(size)
        drawlist.AddText(self._font.font if self._font is not None else NULL, size, ip, self.color, self.text.c_str())


cdef class DrawTriangle_(drawingItem):
    def __cinit__(self):
        # p1, p2, p3 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.
        self.cull_mode = 0

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef bint ccw

        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
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
                drawlist.AddTriangleFilled(ip1, ip3, ip2, self.fill)
            drawlist.AddTriangle(ip1, ip3, ip2, self.color, thickness)
        else:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddTriangleFilled(ip1, ip2, ip3, self.fill)
            drawlist.AddTriangle(ip1, ip2, ip3, self.color, thickness)

"""
InvisibleDrawButton: main difference with InvisibleButton
is that it doesn't use the cursor and doesn't change
the window maximum content area. In addition it allows
overlap of InvisibleDrawButtons and considers itself
in a pressed state as soon as the mouse is down.
"""

cdef extern from * nogil:
    """
    bool InvisibleDrawButton(int uuid, const ImVec2& pos, const ImVec2& size,
                                           ImGuiButtonFlags flags,
                                           bool catch_if_hovered,
                                           bool *out_hovered, bool *out_held)
    {
        ImGuiContext& g = *GImGui;
        ImGuiWindow* window = ImGui::GetCurrentWindow();
        const ImRect bb(pos, pos + size);

        const ImGuiID id = window->GetID(uuid);
        ImGui::KeepAliveID(id);

        // Catch mouse if we are just in front of it
        if (catch_if_hovered && ImGui::IsMouseHoveringRect(bb.Min, bb.Max)) {
            // If we are in front of a window, and the button is not
            // made inside the window (for example viewport front drawlist),
            // the will catch hovering and prevent activation. This is why we
            // need to set HoveredWindow.
            // After we have activation, or if the click initiated outside of any
            // window, this is not needed anymore.
            g.HoveredWindow = window;
            // Replace any item that thought was hovered
            ImGui::SetHoveredID(id);
            // Enable ourselves to catch activation if clicked.
            ImGui::ClearActiveID();
            // Ignore if another item had registered the click for
            // themselves
            flags |= ImGuiButtonFlags_NoTestKeyOwner;
        }

        flags |= ImGuiButtonFlags_AllowOverlap | ImGuiButtonFlags_PressedOnClick;

        bool pressed = ImGui::ButtonBehavior(bb, id, out_hovered, out_held, flags);

        return pressed;
    }
    """
    bint InvisibleDrawButton(int, ImVec2&, ImVec2&, imgui.ImGuiButtonFlags, bint, bint *, bint *)



cdef class DrawInvisibleButton(drawingItem):
    """
    Invisible rectangular area, parallel to axes, behaving
    like a button (using imgui default handling of buttons).

    Unlike other Draw items, this item accepts handlers and callbacks.

    DrawInvisibleButton can be overlapped on top of each other. In that
    case only one will be considered hovered. This one corresponds to the
    last one of the rendering tree that is hovered. If the button is
    considered active (see below), it retains the hover status to itself.
    Thus if you drag an invisible button on top of items later in the
    rendering tree, they will not be considered hovered.

    Note that only the mouse button(s) that trigger activation will
    have the above described behaviour for hover tests. If the mouse
    doesn't hover anymore the item, it will remain active as long
    as the configured buttons are pressed.

    When inside a plot, drag deltas are returned in plot coordinates,
    that is the deltas correspond to the deltas you must apply
    to your drawing coordinates compared to their original position
    to apply the dragging. When not in a plot, the drag deltas are
    in screen coordinates, and you must convert yourself to drawing
    coordinates if you are applying matrix transforms to your data.
    Generally matrix transforms are not well supported by
    DrawInvisibleButtons, and the shifted position that is updated
    during dragging might be invalid.

    Dragging handlers will not be triggered if the item is not active
    (unlike normal imgui items).

    If you create a DrawInvisibleButton in front of the mouse while
    the mouse is clicked with one of the activation buttons, it will
    steal hovering and activation tests. This is not the case of other
    gui items (except modal windows).

    If your Draw Button is not part of a window (ViewportDrawList),
    the hovering test might not be reliable (except specific case above).

    DrawInvisibleButton accepts children. In that case, the children
    are drawn relative to the coordinates of the DrawInvisibleButton,
    where top left is (0, 0) and bottom right is (1, 1).
    """
    def __cinit__(self):
        self._button = 1
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_rect_size = True
        self.state.cap.has_position = True
        self.p_state = &self.state
        self.can_have_drawing_child = True
        self._min_side = 0
        self._max_side = INFINITY
        self._capture_mouse = True
        self._no_input = False

    @property
    def button(self):
        """
        Mouse button mask that makes the invisible button
        active and triggers the item's callback.

        Default is left-click.

        The mask is an (OR) combination of
        1: left button
        2: right button
        4: middle button
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button

    @button.setter
    def button(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value > 7:
            raise ValueError(f"Invalid button mask {value} passed to {self}")
        self._button = value

    @property
    def p1(self):
        """
        Corner of the invisible button in plot/drawing
        space
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._p1)

    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self._p1, value)

    @property
    def p2(self):
        """
        Opposite corner of the invisible button in plot/drawing
        space
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._p2)

    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self._p2, value)

    @property
    def min_side(self):
        """
        If the rectangle width or height after
        coordinate transform is lower than this,
        resize the screen space transformed coordinates
        such that the width/height are at least min_side.
        Retains original ratio.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min_side

    @min_side.setter
    def min_side(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            value = 0
        self._min_side = value

    @property
    def max_side(self):
        """
        If the rectangle width or height after
        coordinate transform is higher than this,
        resize the screen space transformed coordinates
        such that the width/height are at max max_side.
        Retains original ratio.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max_side

    @max_side.setter
    def max_side(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            value = 0
        self._max_side = value

    @property
    def handlers(self):
        """
        Writable attribute: bound handlers for the item.
        If read returns a list of handlers. Accept
        a handler or a list of handlers as input.
        This enables to do item.handlers += [new_handler].
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @handlers.setter
    def handlers(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

    @property
    def activated(self):
        """
        Readonly attribute: has the button just been pressed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active and not(self.state.prev.active)

    @property
    def active(self):
        """
        Readonly attribute: is the button held
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return tuple(self.state.cur.clicked)

    @property
    def double_clicked(self):
        """
        Readonly attribute: has the item just been double-clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.double_clicked

    @property
    def deactivated(self):
        """
        Readonly attribute: has the button just been unpressed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.prev.active and not(self.state.cur.active)

    @property
    def hovered(self):
        """
        Readonly attribute: Is the mouse inside area
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    @property
    def pos_to_viewport(self):
        """
        Readonly attribute:
        Current screen-space position of the top left
        of the item's rectangle. Basically the coordinate relative
        to the top left of the viewport.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.pos_to_viewport)

    @property
    def pos_to_window(self):
        """
        Readonly attribute:
        Relative position to the window's starting inner
        content area.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.pos_to_window)

    @property
    def pos_to_parent(self):
        """
        Readonly attribute:
        Relative position to latest non-drawing parent
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.pos_to_parent)

    @property
    def rect_size(self):
        """
        Readonly attribute: actual (width, height) in pixels of the item on screen
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.rect_size)

    @property
    def resized(self):
        """
        Readonly attribute: has the item size just changed
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
               self.state.cur.rect_size.y != self.state.prev.rect_size.y

    @property
    def no_input(self):
        """
        Writable attribute: If enabled, this item will not
        detect hovering or activation, thus letting other
        items taking the inputs.

        This is useful to use no_input - rather than show=False,
        if you want to still have handlers run if the item
        is in the visible region.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_input

    @no_input.setter
    def no_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_input = value

    @property
    def capture_mouse(self):
        """
        Writable attribute: If set, the item will
        capture the mouse if hovered even if another
        item was already active.

        As it is not in general a good behaviour (and
        will not behave well if several items with this
        state are overlapping),
        this is reset to False every frame.

        Default is True on creation. Thus creating an item
        in front of the mouse will capture it.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._capture_mouse = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.draw_prev_siblings(drawlist)
        if not(self._show):
            return

        self.set_previous_states()

        # Get button position in screen space
        cdef float[2] p1
        cdef float[2] p2
        self.context._viewport.apply_current_transform(p1, self._p1)
        self.context._viewport.apply_current_transform(p2, self._p2)
        cdef imgui.ImVec2 top_left
        cdef imgui.ImVec2 bottom_right
        cdef imgui.ImVec2 center
        cdef imgui.ImVec2 size
        top_left.x = min(p1[0], p2[0])
        top_left.y = min(p1[1], p2[1])
        bottom_right.x = max(p1[0], p2[0])
        bottom_right.y = max(p1[1], p2[1])
        center.x = (top_left.x + bottom_right.x) / 2.
        center.y = (top_left.y + bottom_right.y) / 2.
        size.x = bottom_right.x - top_left.x
        size.y = bottom_right.y - top_left.y
        cdef float ratio = 1e30
        if size.y != 0.:
            ratio = size.x/size.y
        elif size.x == 0:
            ratio = 1.

        if size.x < self._min_side:
            #size.y += (self._min_side - size.x) / ratio
            size.x = self._min_side
        if size.y < self._min_side:
            #size.x += (self._min_side - size.y) * ratio
            size.y = self._min_side
        if size.x > self._max_side:
            #size.y = max(0., size.y - (size.x - self._max_side) / ratio)
            size.x = self._max_side
        if size.y > self._max_side:
            #size.x += max(0., size.x - (size.y - self._max_side) * ratio)
            size.y = self._max_side
        top_left.x = center.x - size.x * 0.5
        bottom_right.x = top_left.x + size.x * 0.5
        top_left.y = center.y - size.y * 0.5
        bottom_right.y = top_left.y + size.y
        # Update rect and position size
        self.state.cur.rect_size = size
        self.state.cur.pos_to_viewport = top_left
        self.state.cur.pos_to_window.x = self.state.cur.pos_to_viewport.x - self.context._viewport.window_pos.x
        self.state.cur.pos_to_window.y = self.state.cur.pos_to_viewport.y - self.context._viewport.window_pos.y
        self.state.cur.pos_to_parent.x = self.state.cur.pos_to_viewport.x - self.context._viewport.parent_pos.x
        self.state.cur.pos_to_parent.y = self.state.cur.pos_to_viewport.y - self.context._viewport.parent_pos.y
        cdef bint was_visible = self.state.cur.rendered
        self.state.cur.rendered = imgui.IsRectVisible(top_left, bottom_right) or self.state.cur.active
        if not(was_visible) and not(self.state.cur.rendered):
            # Item is entirely clipped.
            # Do not skip the first time it is clipped,
            # in order to update the relevant states to False.
            # If the button is active, do not skip anything.
            return

        # Render children if any
        cdef double[2] cur_scales = self.context._viewport.scales
        cdef double[2] cur_shifts = self.context._viewport.shifts
        cdef bint cur_in_plot = self.context._viewport.in_plot

        # draw children
        if self.last_drawings_child is not None:
            self.context._viewport.shifts[0] = <double>top_left.x
            self.context._viewport.shifts[1] = <double>top_left.y
            self.context._viewport.scales = [<double>size.x, <double>size.y]
            self.context._viewport.in_plot = False
            self.last_drawings_child.draw(drawlist)

        # restore states
        self.context._viewport.scales = cur_scales
        self.context._viewport.shifts = cur_shifts
        self.context._viewport.in_plot = cur_in_plot

        cdef bint mouse_down = False
        if (self._button & 1) != 0 and imgui.IsMouseDown(imgui.ImGuiMouseButton_Left):
            mouse_down = True
        if (self._button & 2) != 0 and imgui.IsMouseDown(imgui.ImGuiMouseButton_Right):
            mouse_down = True
        if (self._button & 4) != 0 and imgui.IsMouseDown(imgui.ImGuiMouseButton_Middle):
            mouse_down = True


        cdef imgui.ImVec2 cur_mouse_pos
        cdef implot.ImPlotPoint cur_mouse_pos_plot

        cdef bool hovered = False
        cdef bool held = False
        cdef bint activated
        if not(self._no_input):
            activated = InvisibleDrawButton(self.uuid,
                                            top_left,
                                            size,
                                            self._button,
                                            self._capture_mouse,
                                            &hovered,
                                            &held)
        else:
            activated = False
        self._capture_mouse = False
        self.state.cur.active = activated or held
        self.state.cur.hovered = hovered
        if activated:
            if self.context._viewport.in_plot:
                # IMPLOT_AUTO uses current axes
                cur_mouse_pos_plot = \
                    implot.GetPlotMousePos(implot.IMPLOT_AUTO,
                                           implot.IMPLOT_AUTO)
                cur_mouse_pos.x = <float>cur_mouse_pos_plot.x
                cur_mouse_pos.y = <float>cur_mouse_pos_plot.y
                self.initial_mouse_position = cur_mouse_pos
            else:
                self.initial_mouse_position = imgui.GetMousePos()
        cdef bint dragging = False
        cdef int i
        if self.state.cur.active:
            if self.context._viewport.in_plot:
                cur_mouse_pos_plot = implot.GetPlotMousePos(implot.IMPLOT_AUTO,
                                                            implot.IMPLOT_AUTO)
                cur_mouse_pos.x = <float>cur_mouse_pos_plot.x
                cur_mouse_pos.y = <float>cur_mouse_pos_plot.y
            else:
                cur_mouse_pos = imgui.GetMousePos()
            dragging = cur_mouse_pos.x != self.initial_mouse_position.x or \
                       cur_mouse_pos.y != self.initial_mouse_position.y
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.dragging[i] = dragging and imgui.IsMouseDown(i)
                if dragging:
                    self.state.cur.drag_deltas[i].x = cur_mouse_pos.x - self.initial_mouse_position.x
                    self.state.cur.drag_deltas[i].y = cur_mouse_pos.y - self.initial_mouse_position.y
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.dragging[i] = False

        if self.state.cur.hovered:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.clicked[i] = imgui.IsMouseClicked(i, False)
                self.state.cur.double_clicked[i] = imgui.IsMouseDoubleClicked(i)
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.clicked[i] = False
                self.state.cur.double_clicked[i] = False

        self.run_handlers()


"""
Items that enable to insert drawings in other elements
"""

cdef class DrawInWindow(uiItem):
    """
    An UI item that contains a region for Draw* elements.
    Enables to insert Draw* Elements inside a window.

    Inside a DrawInWindow elements, the (0, 0) coordinate
    starts at the top left of the DrawWindow and y increases
    when going down.
    The drawing region is clipped by the available width/height
    of the item (set manually, or deduced).

    An invisible button is created to span the entire drawing
    area, which is used to retrieve button states on the area
    (hovering, active, etc). If set, the callback is called when
    the mouse is pressed inside the area with any of the left,
    middle or right button.
    In addition, the use of an invisible button enables the drag
    and drop behaviour proposed by imgui.

    If you intend on dragging elements inside the drawing area,
    you can either implement yourself a hovering test for your
    specific items and use the context's is_mouse_dragging, or
    add invisible buttons on top of the elements you want to
    interact with, and combine the active and mouse dragging
    handlers. Note if you intend to make an element draggable
    that way, you must not make the element source of a Drag
    and Drop, as it impacts the hovering tests.

    Note that Drawing items do not have any hovering/clicked/
    visible/etc tests maintained and thus do not have a callback.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.has_rect_size = True

    cdef bint draw_item(self) noexcept nogil:
        # negative width is used to indicate UI alignment
        cdef imgui.ImVec2 requested_size = self.scaled_requested_size()
        cdef float clip_width = abs(requested_size.x)
        if clip_width == 0:
            clip_width = imgui.CalcItemWidth()
        cdef float clip_height = requested_size.y
        if clip_height <= 0 or clip_width == 0:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers() # won't propagate though
            return False
        cdef imgui.ImDrawList* drawlist = imgui.GetWindowDrawList()

        cdef float startx = <float>imgui.GetCursorScreenPos().x
        cdef float starty = <float>imgui.GetCursorScreenPos().y

        # Reset current drawInfo
        self.context._viewport.in_plot = False
        self.context._viewport.parent_pos = imgui.GetCursorScreenPos()
        self.context._viewport.shifts[0] = <double>startx
        self.context._viewport.shifts[1] = <double>starty
        cdef double scale = <double>self.context._viewport.global_scale if self.dpi_scaling else 1.
        self.context._viewport.scales = [scale, scale]

        imgui.PushClipRect(imgui.ImVec2(startx, starty),
                           imgui.ImVec2(startx + clip_width,
                                        starty + clip_height),
                           True)

        if self.last_drawings_child is not None:
            self.last_drawings_child.draw(drawlist)

        imgui.PopClipRect()

        # Indicate the item might be overlapped by over UI,
        # for correct hovering tests. Indeed the user might want
        # to insert some UI on top of the draw elements.
        imgui.SetNextItemAllowOverlap()
        cdef bint active = imgui.InvisibleButton(self.imgui_label.c_str(),
                                 imgui.ImVec2(clip_width,
                                              clip_height),
                                 imgui.ImGuiButtonFlags_MouseButtonLeft | \
                                 imgui.ImGuiButtonFlags_MouseButtonRight | \
                                 imgui.ImGuiButtonFlags_MouseButtonMiddle)
        self.update_current_state()
        return active


cdef class ViewportDrawList_(baseItem):
    def __cinit__(self):
        self.element_child_category = child_type.cat_viewport_drawlist
        self.can_have_drawing_child = True
        self._show = True
        self._front = True

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # Reset current drawInfo
        self.context._viewport.in_plot = False
        self.context._viewport.window_pos = imgui.ImVec2(0., 0.)
        self.context._viewport.parent_pos = imgui.ImVec2(0., 0.)
        self.context._viewport.shifts = [0., 0.]
        self.context._viewport.scales = [1., 1.]

        cdef imgui.ImDrawList* internal_drawlist = \
            imgui.GetForegroundDrawList() if self._front else \
            imgui.GetBackgroundDrawList()
        self.last_drawings_child.draw(internal_drawlist)

"""
Global handlers

A global handler doesn't look at the item states,
but at global states. It is usually attached to the
viewport, but can be attached to items. If attached
to items, the items needs to be visible for the callback
to be executed.
"""


cdef class KeyDownHandler_(baseHandler):
    def __cinit__(self):
        self._key = imgui.ImGuiKey_None

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        cdef imgui.ImGuiKeyData *key_info
        if self._key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                key_info = imgui.GetKeyData(<imgui.ImGuiKey>i)
                if key_info.Down:
                    return True
        else:
            key_info = imgui.GetKeyData(<imgui.ImGuiKey>self._key)
            if key_info.Down:
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef imgui.ImGuiKeyData *key_info
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        if self._key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                key_info = imgui.GetKeyData(<imgui.ImGuiKey>i)
                if key_info.Down:
                    self.context.queue_callback_arg1int1float(self._callback, self, item, i, key_info.DownDuration)
        else:
            key_info = imgui.GetKeyData(<imgui.ImGuiKey>self._key)
            if key_info.Down:
                self.context.queue_callback_arg1int1float(self._callback, self, item, self._key, key_info.DownDuration)

cdef class KeyPressHandler_(baseHandler):
    def __cinit__(self):
        self._key = imgui.ImGuiKey_None
        self._repeat = True

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        if self._key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyPressed(<imgui.ImGuiKey>i, self._repeat):
                    return True
        else:
            if imgui.IsKeyPressed(<imgui.ImGuiKey>self._key, self._repeat):
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        if self._key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyPressed(<imgui.ImGuiKey>i, self._repeat):
                    self.context.queue_callback_arg1int(self._callback, self, item, i)
        else:
            if imgui.IsKeyPressed(<imgui.ImGuiKey>self._key, self._repeat):
                self.context.queue_callback_arg1int(self._callback, self, item, self._key)

cdef class KeyReleaseHandler_(baseHandler):
    def __cinit__(self):
        self._key = imgui.ImGuiKey_None

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        if self._key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyReleased(<imgui.ImGuiKey>i):
                    return True
        else:
            if imgui.IsKeyReleased(<imgui.ImGuiKey>self._key):
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        if self._key == 0:
            for i in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_AppForward):
                if imgui.IsKeyReleased(<imgui.ImGuiKey>i):
                    self.context.queue_callback_arg1int(self._callback, self, item, i)
        else:
            if imgui.IsKeyReleased(<imgui.ImGuiKey>self._key):
                self.context.queue_callback_arg1int(self._callback, self, item, self._key)


cdef class MouseClickHandler_(baseHandler):
    def __cinit__(self):
        self._button = -1
        self._repeat = False

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseClicked(i, self._repeat):
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseClicked(i, self._repeat):
                self.context.queue_callback_arg1int(self._callback, self, item, i)

cdef class MouseDoubleClickHandler_(baseHandler):
    def __cinit__(self):
        self._button = -1

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseDoubleClicked(i):
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseDoubleClicked(i):
                self.context.queue_callback_arg1int(self._callback, self, item, i)


cdef class MouseDownHandler_(baseHandler):
    def __cinit__(self):
        self._button = -1

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseDown(i):
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseDown(i):
                self.context.queue_callback_arg1int1float(self._callback, self, item, i, imgui.GetIO().MouseDownDuration[i])

cdef class MouseDragHandler_(baseHandler):
    def __cinit__(self):
        self._button = -1
        self._threshold = -1 # < 0. means use default

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseDragging(i, self._threshold):
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        cdef imgui.ImVec2 delta
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseDragging(i, self._threshold):
                delta = imgui.GetMouseDragDelta(i, self._threshold)
                self.context.queue_callback_arg1int2float(self._callback, self, item, i, delta.x, delta.y)


cdef class MouseMoveHandler(baseHandler):
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            self.context.queue_callback_arg2float(self._callback, self, item, io.MousePos.x, io.MousePos.y)
            

cdef class MouseReleaseHandler_(baseHandler):
    def __cinit__(self):
        self._button = -1

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int i
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseReleased(i):
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int i
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        for i in range(imgui.ImGuiMouseButton_COUNT):
            if self._button >= 0 and self._button != i:
                continue
            if imgui.IsMouseReleased(i):
                self.context.queue_callback_arg1int(self._callback, self, item, i)

cdef class MouseWheelHandler(baseHandler):
    def __cinit__(self, *args, **kwargs):
        self._horizontal = False

    @property
    def horizontal(self):
        """
        Whether to look at the horizontal wheel
        instead of the vertical wheel.

        NOTE: Shift+ vertical wheel => horizontal wheel
        """
        return self._horizontal

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._horizontal = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if self._horizontal:
            if abs(io.MouseWheelH) > 0.:
                return True
        else:
            if abs(io.MouseWheel) > 0.:
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if self._horizontal:
            if abs(io.MouseWheelH) > 0.:
                self.context.queue_callback_arg1float(self._callback, self, item, io.MouseWheelH)
        else:
            if abs(io.MouseWheel) > 0.:
                self.context.queue_callback_arg1float(self._callback, self, item, io.MouseWheel)


"""
Sources
"""

cdef class SharedValue:
    def __init__(self, *args, **kwargs):
        # We create all shared objects using __new__, thus
        # bypassing __init__. If __init__ is called, it's
        # from the user.
        # __init__ is called after __cinit__
        self._num_attached = 0
    def __cinit__(self, Context context, *args, **kwargs):
        self.context = context
        self._last_frame_change = context._viewport.frame_count
        self._last_frame_update = context._viewport.frame_count
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
    def shareable_value(self):
        return self

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
        self._last_frame_update = self.context._viewport.frame_count
        if changed:
            self._last_frame_change = self.context._viewport.frame_count

    cdef void inc_num_attached(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._num_attached += 1

    cdef void dec_num_attached(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._num_attached -= 1


cdef class SharedBool(SharedValue):
    def __init__(self, Context context, bint value):
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

cdef class SharedFloat(SharedValue):
    def __init__(self, Context context, float value):
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

cdef class SharedInt(SharedValue):
    def __init__(self, Context context, int value):
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

cdef class SharedColor(SharedValue):
    def __init__(self, Context context, value):
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

cdef class SharedDouble(SharedValue):
    def __init__(self, Context context, double value):
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

cdef class SharedStr(SharedValue):
    def __init__(self, Context context, str value):
        self._value = bytes(str(value), 'utf-8')
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._value, encoding='utf-8')
    @value.setter
    def value(self, value):
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

cdef class SharedFloat4(SharedValue):
    def __init__(self, Context context, value):
        read_vec4[float](self._value, value)
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
        read_vec4[float](self._value, value)
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

cdef class SharedInt4(SharedValue):
    def __init__(self, Context context, value):
        read_vec4[int](self._value, value)
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
        read_vec4[int](self._value, value)
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

cdef class SharedDouble4(SharedValue):
    def __init__(self, Context context, value):
        read_vec4[double](self._value, value)
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_vec4[double](self._value, value)
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

cdef class SharedFloatVect(SharedValue):
    def __init__(self, Context context, value):
        self._value = value
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._value_np is None:
            return None
        return np.copy(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value_np = np.array(value, dtype=np.float32)
        self._value = self._value_np
        self.on_update(True)
    cdef float[:] get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, float[:] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value = value
        self.on_update(True)

"""
cdef class SharedDoubleVect:
    cdef double[:] value
    cdef double[:] get(self) noexcept nogil
    cdef void set(self, double[:]) noexcept nogil

cdef class SharedTime:
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

cdef class baseHandler(baseItem):
    def __cinit__(self):
        self._enabled = True
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_handler
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value
    # for backward compatibility
    @property
    def show(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value

    @property
    def callback(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._callback
    @callback.setter
    def callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._callback = value if isinstance(value, Callback) or value is None else Callback(value)

    cdef void check_bind(self, baseItem item):
        """
        Must raise en error if the handler cannot be bound for the
        target item.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).check_bind(item)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        """
        Returns whether the target state it True.
        Is called by the default implementation of run_handler,
        which will call the default callback in this case.
        Classes that might issue non-standard callbacks should
        override run_handler in addition to check_state.
        """
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseHandler>self._prev_sibling).run_handler(item)
        if not(self._enabled):
            return
        if self.check_state(item):
            self.run_callback(item)

    cdef void run_callback(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.queue_callback_arg1obj(self._callback, self, item, item)


cdef inline object IntPairFromVec2(imgui.ImVec2 v):
    return (<int>v.x, <int>v.y)

cdef extern from * nogil:
    """
    ImVec2 GetDefaultItemSize(ImVec2 requested_size)
    {
        return ImTrunc(ImGui::CalcItemSize(requested_size, ImGui::CalcItemWidth(), ImGui::GetTextLineHeightWithSpacing() * 7.25f + ImGui::GetStyle().FramePadding.y * 2.0f));
    }
    """
    imgui.ImVec2 GetDefaultItemSize(imgui.ImVec2)

cdef class uiItem(baseItem):
    def __cinit__(self):
        # mvAppItemInfo
        self.imgui_label = b'###%ld'% self.uuid
        self.user_label = ""
        self._show = True
        self._enabled = True
        self.can_be_disabled = True
        #self.location = -1
        # next frame triggers
        self.focus_update_requested = False
        self.show_update_requested = True
        self.size_update_requested = True
        self.pos_update_requested = False
        self.enabled_update_requested = False
        self.last_frame_update = 0 # last frame update occured. TODO remove ?
        # mvAppItemConfig
        #self.filter = b""
        #self.alias = b""
        self.payloadType = b"$$DPG_PAYLOAD"
        self.requested_size = imgui.ImVec2(0., 0.)
        self.dpi_scaling = True
        self._indent = 0.
        self.theme_condition_enabled = theme_enablers.t_enabled_True
        self.theme_condition_category = theme_categories.t_any
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_widget
        self.state.cap.has_position = True # ALL widgets have position
        self.state.cap.has_rect_size = True # ALL items have a rectangle size
        self.p_state = &self.state
        self._pos_policy = [positioning.DEFAULT, positioning.DEFAULT]
        #self.trackOffset = 0.5 # 0.0f:top, 0.5f:center, 1.0f:bottom
        #self.tracked = False
        self.dragCallback = None
        self.dropCallback = None
        self._value = SharedValue(self.context) # To be changed by class

    def __dealloc__(self):
        clear_obj_vector(self._callbacks)

    def configure(self, **kwargs):
        # Map old attribute names (the new names are handled in uiItem)
        if 'pos' in kwargs:
            pos = kwargs.pop("pos")
            if pos is not None and len(pos) == 2:
                self.pos_to_window = pos
                self.state.cur.pos_to_viewport = self.state.cur.pos_to_window # for windows TODO move to own configure
        if 'callback' in kwargs:
            self.callbacks = kwargs.pop("callback")
        if 'source' in kwargs:
            source = kwargs.pop("source")
            if source is not None and (not(isinstance(source, int)) or (source > 0)):
                self.shareable_value = self.context[source].shareable_value
        return super().configure(**kwargs)

    cdef void update_current_state(self) noexcept nogil:
        """
        Updates the state of the last imgui object.
        """
        if self.state.cap.can_be_hovered:
            self.state.cur.hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
        if self.state.cap.can_be_active:
            self.state.cur.active = imgui.IsItemActive()
        if self.state.cap.can_be_clicked or self.state.cap.can_be_dragged:
            update_current_mouse_states(self.state)
        if self.state.cap.can_be_deactivated_after_edited:
            self.state.cur.deactivated_after_edited = imgui.IsItemDeactivatedAfterEdit()
        if self.state.cap.can_be_edited:
            self.state.cur.edited = imgui.IsItemEdited()
        if self.state.cap.can_be_focused:
            self.state.cur.focused = imgui.IsItemFocused()
        if self.state.cap.can_be_toggled:
            if imgui.IsItemToggledOpen():
                self.state.cur.open = True
        if self.state.cap.has_rect_size:
            self.state.cur.rect_size = imgui.GetItemRectSize()
        self.state.cur.rendered = imgui.IsItemVisible()
        #if not(self.state.cur.rendered):
        #    self.propagate_hidden_state_to_children_with_handlers()

    cdef void update_current_state_subset(self) noexcept nogil:
        """
        Helper for items that manage themselves the active,
        edited, etc states
        """
        if self.state.cap.can_be_hovered:
            self.state.cur.hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
        if self.state.cap.can_be_focused:
            self.state.cur.focused = imgui.IsItemFocused()
        if self.state.cap.can_be_clicked or self.state.cap.can_be_dragged:
            update_current_mouse_states(self.state)
        if self.state.cap.has_rect_size:
            self.state.cur.rect_size = imgui.GetItemRectSize()
        self.state.cur.rendered = imgui.IsItemVisible()
        #if not(self.state.cur.rendered):
        #    self.propagate_hidden_state_to_children_with_handlers()

    # TODO: Find a better way to share all these attributes while avoiding AttributeError
    def __dir__(self):
        default_dir = dir(type(self))
        if hasattr(self, '__dict__'): # Can happen with python subclassing
            default_dir + list(self.__dict__.keys())
        # Remove invalid ones
        results = []
        for e in default_dir:
            if hasattr(self, e):
                results.append(e)
        return list(set(results))

    @property
    def active(self):
        """
        Readonly attribute: is the item active.
        For example for a button, it is when pressed. For tabs
        it is when selected, etc.
        """
        if not(self.state.cap.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active

    @property
    def activated(self):
        """
        Readonly attribute: has the item just turned active
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active and not(self.state.prev.active)

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return tuple(self.state.cur.clicked)

    @property
    def double_clicked(self):
        """
        Readonly attribute: has the item just been double-clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.double_clicked

    @property
    def deactivated(self):
        """
        Readonly attribute: has the item just turned un-active
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.state.cur.active) and self.state.prev.active

    @property
    def deactivated_after_edited(self):
        """
        Readonly attribute: has the item just turned un-active after having
        been edited.
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_deactivated_after_edited):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.deactivated_after_edited

    @property
    def edited(self):
        """
        Readonly attribute: has the item just been edited ?
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_edited):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.edited

    @property
    def focused(self):
        """
        Writable attribute: Is the item focused ?
        For windows it means the window is at the top,
        while for items it could mean the keyboard inputs are redirected to it.
        """
        if not(self.state.cap.can_be_focused):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.focused

    @focused.setter
    def focused(self, bint value):
        """
        Writable attribute: Is the item focused ?
        For windows it means the window is at the top,
        while for items it could mean the keyboard inputs are redirected to it.
        """
        if not(self.state.cap.can_be_focused):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.cur.focused = value
        self.focus_update_requested = True

    @property
    def hovered(self):
        """
        Readonly attribute: Is the mouse inside the region of the item.
        Only one element is hovered at a time, thus
        subitems/subwindows take priority over their parent.
        """
        if not(self.state.cap.can_be_hovered):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    @property
    def resized(self):
        """
        Readonly attribute: has the item size just changed
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.has_rect_size):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
               self.state.cur.rect_size.y != self.state.prev.rect_size.y

    @property
    def toggled(self):
        """
        Has a menu/bar trigger been hit for the item
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_toggled):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.open and not(self.state.prev.open)

    @property
    def visible(self):
        """
        True if the item was rendered (inside the rendering region + show = True
        for the item and its ancestors). Note when an item is not visible,
        rendering is skipped (as well as running their handlers, etc).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.rendered

    @property
    def callbacks(self):
        """
        Writable attribute: callback object or list of callback objects
        which is called when the value of the item is changed.
        If read, always returns a list of callbacks. This enables
        to do item.callbacks += [new_callback]
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        cdef Callback callback
        for i in range(<int>self._callbacks.size()):
            callback = <Callback>self._callbacks[i]
            result.append(callback)
        return result

    @callbacks.setter
    def callbacks(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int i
        if value is None:
            clear_obj_vector(self._callbacks)
            return
        if not hasattr(value, "__len__"):
            value = [value]
        # Convert to callbacks
        for i in range(len(value)):
            items.append(value[i] if isinstance(value[i], Callback) else Callback(value[i]))
        clear_obj_vector(self._callbacks)
        append_obj_vector(self._callbacks, items)

    @property
    def enabled(self):
        """
        Writable attribute: Should the object be displayed as enabled ?
        the enabled state can be used to prevent edition of editable fields,
        or to use a specific disabled element theme.
        Note a disabled item is still rendered. Use show=False to hide
        an object.
        A disabled item does not react to hovering or clicking.
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
    def font(self):
        """
        Writable attribute: font used for the text rendered
        of this item and its subitems
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, Font value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def label(self):
        """
        Writable attribute: label assigned to the item.
        Used for text fields, window titles, etc
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
        if self._show == value:
            return
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_siblings_no_handlers() # TODO: already handled in draw() ?
        self.show_update_requested = True
        self._show = value

    @property
    def handlers(self):
        """
        Writable attribute: bound handlers for the item.
        If read returns a list of handlers. Accept
        a handler or a list of handlers as input.
        This enables to do item.handlers += [new_handler].
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @handlers.setter
    def handlers(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

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
    def no_scaling(self):
        """
        boolean. Defaults to False.
        By default, the requested width and
        height are multiplied internally by the global
        scale which is defined by the dpi and the
        viewport/window scale.
        If set, disables this automated scaling.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.dpi_scaling = not(value)

    ### Positioning - layouts

    ### Current position states

    @property
    def pos_to_viewport(self):
        """
        Writable attribute:
        Current screen-space position of the top left
        of the item's rectangle. Basically the coordinate relative
        to the top left of the viewport.

        User writing this attribute automatically switches
        the positioning mode to REL_VIEWPORT position.

        Note that item is still clipped from the parent's clipping
        region, and thus the item will not be visible if placed
        outside.

        Setting None to one of component will ignore the update
        of this component.
        For example item.pos_to_viewport = (x, None) will only
        set the horizontal component of the pos_to_viewport position,
        and update the positioning policy for this component
        only.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.pos_to_viewport)

    @property
    def pos_to_window(self):
        """
        Writable attribute:
        Relative position to the window's starting inner
        content area.

        The position corresponds to the top left of the item's
        rectangle

        User writing this attribute automatically switches
        the positioning policy to relative position to the
        window.

        Note that the position may place the item outside the
        parent's content region, in which case the item is not
        visible.

        Setting None to one of component will ignore the update
        of this component.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.pos_to_window)

    @property
    def pos_to_parent(self):
        """
        Writable attribute:
        Relative position to the parent's position, or to
        its starting inner content area if any.

        The position corresponds to the top left of the item's
        rectangle

        User writing this attribute automatically switches
        the positioning policy to relative position to the
        parent.

        Note that the position may place the item outside the
        parent's content region, in which case the item is not
        visible.

        Setting None to one of component will ignore the update
        of this component.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.pos_to_parent)

    @property
    def pos_to_default(self):
        """
        Writable attribute:
        Relative position to the item's default position.

        User set attribute to offset the object relative to
        the position it would be drawn by default given the other
        items drawn. The position corresponds to the top left of
        the item's rectangle.

        User writing this attribute automatically switches the 
        positioning policy to relative to the default position.

        Setting None to one of component will ignore the update
        of this component.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.pos_to_default)

    @property
    def rect_size(self):
        """
        Readonly attribute: actual (width, height) of the element,
        including margins.

        The space taken by the item corresponds to a rectangle
        of size rect_size with top left coordinate
        the position given by the position fields.

        Not the rect_size refers to the size within the parent
        window. If a popup menu is opened, it is not included.
        """
        if not(self.state.cap.has_rect_size):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.rect_size)

    @property
    def content_region_avail(self):
        """
        Readonly attribute: For windows, child windows,
        table cells, etc: Available region.

        Only defined for elements that contain other items.
        Corresponds to the size inside the item to display
        other items (regions not shown which can
        be scrolled are not accounted). Basically the item size
        minus the margins and borders.
        """
        if not(self.state.cap.has_content_region):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.state.cur.content_region_size)

    ### Positioning and size requests

    @property
    def pos_policy(self):
        """
        Writable attribute: Positioning policy

        Changing the policy enables the user to
        change the position of the item relative to
        its default position.

        - DEFAULT: The item is drawn at the position
          given by ImGUI's cursor position, which by
          default is incremented vertically after each item is
          rendered.
        - REL_DEFAULT: The item is drawn at the same position
          as default, but after adding as offset the value
          contained in the pos_to_default field.
        - REL_PARENT: The item is rendered at the position
          contained in the pos_to_parent's field,
          which is respective to the top left of the content
          area of the parent.
        - REL_WINDOW: The item is rendered at the position
          contained in the pos_to_window's field,
          which is respective to the top left of the containing
          window or child window content area.
        - REL_VIEWPORT: The item is rendered in viewport
          coordinates, at the position pos_to_viewport.

        Items rendered with the DEFAULT or REL_DEFAULT policy do
        increment the cursor position, while REL_PARENT, REL_WINDOW
        and REL_VIEWPORT do not.

        Each axis has it's own positioning policy.
        pos_policy = DEFAULT will update both policies, why
        pos_policy = (None, DEFAULT) will only update the vertical
        axis policy.

        Regardless of the policy, all position fields are updated
        when the item is rendered. Only the position corresponding to
        the positioning policy can be expected to remain fixed, with no
        strong guarantees.

        Since some items react dynamically to the size of their contents,
        while items react dynamically to the size of their parent, a few
        frames may be needed for positions to stabilize.
        """
        return self._pos_policy

    @property
    def height(self):
        """
        Writable attribute: Requested height of the item.
        When it is written, it is set to a 'requested value' that is not
        entirely guaranteed to be enforced.
        Specific values:
            . 0 is meant to define the default size. For some items,
              such as windows, it triggers a fit to the content size.
              For other items, there is a default size deduced from the
              style policy. And for some items (such as child windows),
              it triggers a fit to the full size available within the
              parent window.
            . > 0 values is meant as a hint for rect_size.
            . < 0 values to be interpreted as 'take remaining space
              of the parent's content region from the current position,
              and subtract this value'. For example -1 will stretch to the
              remaining area minus one pixel.

        Note that for some items, the actual rect_size of the element cannot
        be changed to the requested values (for example Text). In that case, the
        item is not resized, but it behaves as if it has the requested size in terms
        of impact on the layout (default position of other items).

        In addition the real height may change if the object is resizable.
        In this case, the height may be changed back by setting again the value
        of this field.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self.requested_size.y

    @property
    def width(self):
        """
        Writable attribute: Requested width of the item.
        When it is written, it is set to a 'requested value' that is not
        entirely guaranteed to be enforced.
        Specific values:
            . 0 is meant to define the default size. For some items,
              such as windows, it triggers a fit to the content size.
              For other items, there is a default size deduced from the
              style policy. And for some items (such as child windows),
              it triggers a fit to the full size available within the
              parent window.
            . > 0 values is meant as a hint for rect_size.
            . < 0 values to be interpreted as 'take remaining space
              of the parent's content region from the current position,
              and subtract this value'. For example -1 will stretch to the
              remaining area minus one pixel.

        Note that for some items, the actual rect_size of the element cannot
        be changed to the requested values (for example Text). In that case, the
        item is not resized, but it behaves as if it has the requested size in terms
        of impact on the layout (default position of other items).

        In addition the real width may change if the object is resizable.
        In this case, the width may be changed back by setting again the value
        of this field.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self.requested_size.x

    @property
    def indent(self):
        """
        Writable attribute: Shifts horizontally the DEFAULT
        position of the item by the requested amount of pixels.

        A value < 0 indicates an indentation of the default size
        according to the style policy.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._indent

    @property
    def no_newline(self):
        """
        Writable attribute: Disables moving the
        cursor (DEFAULT position) by one line
        after this item.

        Might be modified by the layout
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._indent

    ## setters

    @pos_to_viewport.setter
    def pos_to_viewport(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_viewport.x = x
            self._pos_policy[0] = positioning.REL_VIEWPORT
        if y is not None:
            self.state.cur.pos_to_viewport.y = y
            self._pos_policy[1] = positioning.REL_VIEWPORT
        self.pos_update_requested = True # TODO remove ?

    @pos_to_window.setter
    def pos_to_window(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_window.x = x
            self._pos_policy[0] = positioning.REL_WINDOW
        if y is not None:
            self.state.cur.pos_to_window.y = y
            self._pos_policy[1] = positioning.REL_WINDOW
        self.pos_update_requested = True

    @pos_to_parent.setter
    def pos_to_parent(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_parent.x = x
            self._pos_policy[0] = positioning.REL_PARENT
        if y is not None:
            self.state.cur.pos_to_parent.y = y
            self._pos_policy[1] = positioning.REL_PARENT
        self.pos_update_requested = True

    @pos_to_default.setter
    def pos_to_default(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_default.x = x
            self._pos_policy[0] = positioning.REL_DEFAULT
        if y is not None:
            self.state.cur.pos_to_default.y = y
            self._pos_policy[1] = positioning.REL_DEFAULT
        self.pos_update_requested = True

    @pos_policy.setter
    def pos_policy(self, positioning value):
        policies = [
            positioning.DEFAULT,
            positioning.REL_DEFAULT,
            positioning.REL_PARENT,
            positioning.REL_WINDOW,
            positioning.REL_VIEWPORT
        ]
        if hasattr(value, "__len__"):
            (x, y) = value
            if x not in policies or y not in policies:
                raise ValueError("Invalid positioning policy")
            self._pos_policy[0] = x
            self._pos_policy[1] = y
            self.pos_update_requested = True
        else:
            if value not in policies:
                raise ValueError("Invalid positioning policy")
            self._pos_policy[0] = value
            self._pos_policy[1] = value
            self.pos_update_requested = True

    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.y = <float>value
        if value <= 0:
            self.state.cur.rect_size.y = 0.
        else:
            self.state.cur.rect_size.y = <float>value
        self.size_update_requested = True

    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.x = <float>value
        if value <= 0:
            self.state.cur.rect_size.x = 0.
        else:
            self.state.cur.rect_size.x = <float>value
        self.size_update_requested = True

    @indent.setter
    def indent(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._indent = value

    @no_newline.setter
    def no_newline(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_newline = value

    @cython.final
    cdef imgui.ImVec2 scaled_requested_size(self) noexcept nogil:
        cdef imgui.ImVec2 requested_size = self.requested_size
        if self.dpi_scaling:
            requested_size.x *= self.context._viewport.global_scale
            requested_size.y *= self.context._viewport.global_scale
        return requested_size

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<uiItem>self._prev_sibling).draw()

        if not(self._show):
            if self.show_update_requested:
                self.set_previous_states()
                self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
                self.run_handlers()
                self.show_update_requested = False
            return

        self.set_previous_states()

        if self.focus_update_requested:
            if self.state.cur.focused:
                imgui.SetKeyboardFocusHere(0)
            self.focus_update_requested = False

        # Does not affect all items, but is cheap to set
        if self.requested_size.x != 0:
            imgui.SetNextItemWidth(self.requested_size.x * \
                                       (self.context._viewport.global_scale if self.dpi_scaling else 1.))

        cdef float indent = self._indent
        if indent > 0.:
            imgui.Indent(indent)
        # We use 0 to mean no indentation,
        # while imgui uses 0 for default indentation
        elif indent < 0:
            imgui.Indent(0)

        cdef imgui.ImVec2 cursor_pos_backup = imgui.GetCursorScreenPos()

        cdef positioning[2] policy = self._pos_policy
        cdef imgui.ImVec2 pos = cursor_pos_backup

        if policy[0] == positioning.REL_DEFAULT:
            pos.x += self.state.cur.pos_to_default.x
        elif policy[0] == positioning.REL_PARENT:
            pos.x = self.context._viewport.parent_pos.x + self.state.cur.pos_to_parent.x
        elif policy[0] == positioning.REL_WINDOW:
            pos.x = self.context._viewport.window_pos.x + self.state.cur.pos_to_window.x
        elif policy[0] == positioning.REL_VIEWPORT:
            pos.x = self.state.cur.pos_to_viewport.x
        # else: DEFAULT

        if policy[1] == positioning.REL_DEFAULT:
            pos.y += self.state.cur.pos_to_default.y
        elif policy[1] == positioning.REL_PARENT:
            pos.y = self.context._viewport.parent_pos.y + self.state.cur.pos_to_parent.y
        elif policy[1] == positioning.REL_WINDOW:
            pos.y = self.context._viewport.window_pos.y + self.state.cur.pos_to_window.y
        elif policy[1] == positioning.REL_VIEWPORT:
            pos.y = self.state.cur.pos_to_viewport.y
        # else: DEFAULT

        imgui.SetCursorScreenPos(pos)

        # Retrieve current positions
        self.state.cur.pos_to_viewport = imgui.GetCursorScreenPos()
        self.state.cur.pos_to_window.x = self.state.cur.pos_to_viewport.x - self.context._viewport.window_pos.x
        self.state.cur.pos_to_window.y = self.state.cur.pos_to_viewport.y - self.context._viewport.window_pos.y
        self.state.cur.pos_to_parent.x = self.state.cur.pos_to_viewport.x - self.context._viewport.parent_pos.x
        self.state.cur.pos_to_parent.y = self.state.cur.pos_to_viewport.y - self.context._viewport.parent_pos.y
        self.state.cur.pos_to_default.x = self.state.cur.pos_to_viewport.x - cursor_pos_backup.x
        self.state.cur.pos_to_default.y = self.state.cur.pos_to_viewport.y - cursor_pos_backup.y

        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        self.context._viewport.push_pending_theme_actions(
            self.theme_condition_enabled,
            self.theme_condition_category
        )
        if self._theme is not None:
            self._theme.push()

        cdef bint enabled = self._enabled
        if not(enabled):
            imgui.PushItemFlag(1 << 10, True) #ImGuiItemFlags_Disabled

        cdef bint action = self.draw_item()
        cdef int i
        if action and not(self._callbacks.empty()):
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

        if not(enabled):
            imgui.PopItemFlag()

        if self._theme is not None:
            self._theme.pop()
        self.context._viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        # Advance the cursor only for DEFAULT and REL_DEFAULT
        pos = cursor_pos_backup
        if policy[0] == positioning.REL_DEFAULT or \
           policy[0] == positioning.DEFAULT:
            pos.x = imgui.GetCursorScreenPos().x

        if policy[1] == positioning.REL_DEFAULT or \
           policy[1] == positioning.DEFAULT:
            pos.y = imgui.GetCursorScreenPos().y

        imgui.SetCursorScreenPos(pos)

        if indent > 0.:
            imgui.Unindent(indent)
        elif indent < 0:
            imgui.Unindent(0)

        # Note: not affected by the Unindent.
        if self._no_newline and \
           (policy[1] == positioning.REL_DEFAULT or \
            policy[1] == positioning.DEFAULT):
            imgui.SameLine(0., -1.)

        self.run_handlers()


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

cdef class SimplePlot(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_simpleplot
        self._value = <SharedValue>(SharedFloatVect.__new__(SharedFloatVect, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._scale_min = 0.
        self._scale_max = 0.
        self.histogram = False
        self._autoscale = True
        self.last_frame_autoscale_update = -1

    def configure(self, **kwargs):
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
        cdef float[:] data = SharedFloatVect.get(<SharedFloatVect>self._value)
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
                                self.scaled_requested_size(),
                                sizeof(float))
        else:
            imgui.PlotLines(self.imgui_label.c_str(),
                            &data[0],
                            <int>data.shape[0],
                            0,
                            self._overlay.c_str(),
                            self._scale_min,
                            self._scale_max,
                            self.scaled_requested_size(),
                            sizeof(float))
        self.update_current_state()
        return False

cdef class Button(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_button
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
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
        cdef bint activated
        imgui.PushItemFlag(imgui.ImGuiItemFlags_ButtonRepeat, self._repeat)
        if self._small:
            activated = imgui.SmallButton(self.imgui_label.c_str())
        elif self._arrow:
            activated = imgui.ArrowButton(self.imgui_label.c_str(), self._direction)
        else:
            activated = imgui.Button(self.imgui_label.c_str(),
                                     self.scaled_requested_size())
        imgui.PopItemFlag()
        self.update_current_state()
        SharedBool.set(<SharedBool>self._value, self.state.cur.active) # Unsure. Not in original
        return activated


cdef class Combo(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_combo
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
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
            SharedStr.set(<SharedStr>self._value, self._items[0])

    @property
    def height_mode(self):
        """
        Writable attribute: height mode of the combo.
        Supported values are
        "small"
        "regular"
        "large"
        "largest"
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (self.flags & imgui.ImGuiComboFlags_HeightSmall) != 0:
            return "small"
        elif (self.flags & imgui.ImGuiComboFlags_HeightLargest) != 0:
            return "largest"
        elif (self.flags & imgui.ImGuiComboFlags_HeightLarge) != 0:
            return "large"
        return "regular"

    @height_mode.setter
    def height_mode(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~(imgui.ImGuiComboFlags_HeightSmall |
                        imgui.ImGuiComboFlags_HeightRegular |
                        imgui.ImGuiComboFlags_HeightLarge |
                        imgui.ImGuiComboFlags_HeightLargest)
        if value == "small":
            self.flags |= imgui.ImGuiComboFlags_HeightSmall
        elif value == "regular":
            self.flags |= imgui.ImGuiComboFlags_HeightRegular
        elif value == "large":
            self.flags |= imgui.ImGuiComboFlags_HeightLarge
        elif value == "largest":
            self.flags |= imgui.ImGuiComboFlags_HeightLargest
        else:
            self.flags |= imgui.ImGuiComboFlags_HeightRegular
            raise ValueError("Invalid height mode {value}")

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
        SharedStr.get(<SharedStr>self._value, current_value)
        open = imgui.BeginCombo(self.imgui_label.c_str(),
                                current_value.c_str(),
                                self.flags)
        # Old code called update_current_state now, and updated edited state
        # later. Looking at ImGui code there seems to be two items. One
        # for the combo, and one for the popup that opens. The edited flag
        # is not set, looking at imgui demo so we have to handle it manually.
        self.state.cur.open = open
        self.update_current_state_subset()

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
                                                self.scaled_requested_size())
                    if selected:
                        imgui.SetItemDefaultFocus()
                    if selected and selected != selected_backup:
                        changed = True
                        SharedStr.set(<SharedStr>self._value, self._items[i])
            else:
                # TODO: test
                selected = True
                imgui.Selectable(current_value.c_str(),
                                 &selected,
                                 imgui.ImGuiSelectableFlags_Disabled,
                                 self.scaled_requested_size())
            imgui.PopID()
            imgui.EndCombo()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.cur.edited = changed
        self.state.cur.deactivated_after_edited = self.state.prev.active and changed and not(self.state.cur.active)
        return pressed


cdef class Checkbox(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_checkbox
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    cdef bint draw_item(self) noexcept nogil:
        cdef bool checked = SharedBool.get(<SharedBool>self._value)
        cdef bint pressed = imgui.Checkbox(self.imgui_label.c_str(),
                                             &checked)
        if self._enabled:
            SharedBool.set(<SharedBool>self._value, checked)
        self.update_current_state()
        return pressed

cdef class Slider(uiItem):
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
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self.state.cap.can_be_active = True # unsure
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    def configure(self, **kwargs):
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
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif target_format == 0:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
        else:
            if target_format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif target_format == 0:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
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
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
            self.value = previous_value[0]
        else:
            if self._format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
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
                value_int = SharedInt.get(<SharedInt>self._value)
                data = &value_int
            else:
                SharedInt4.get(<SharedInt4>self._value, value_int4)
                data = &value_int4
        elif self._format == 1:
            if self._size == 1:
                value_float = SharedFloat.get(<SharedFloat>self._value)
                data = &value_float
            else:
                SharedFloat4.get(<SharedFloat4>self._value, value_float4)
                data = &value_float4
        else:
            if self._size == 1:
                value_double = SharedDouble.get(<SharedDouble>self._value)
                data = &value_double
            else:
                SharedDouble4.get(<SharedDouble4>self._value, value_double4)
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
                                                   GetDefaultItemSize(self.scaled_requested_size()),
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
                    SharedInt.set(<SharedInt>self._value, value_int)
                else:
                    SharedInt4.set(<SharedInt4>self._value, value_int4)
            elif self._format == 1:
                if self._size == 1:
                    SharedFloat.set(<SharedFloat>self._value, value_float)
                else:
                    SharedFloat4.set(<SharedFloat4>self._value, value_float4)
            else:
                if self._size == 1:
                    SharedDouble.set(<SharedDouble>self._value, value_double)
                else:
                    SharedDouble4.set(<SharedDouble4>self._value, value_double4)
        self.update_current_state()
        return modified


cdef class ListBox(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_listbox
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._num_items_shown_when_open = -1

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
            SharedStr.set(<SharedStr>self._value, self._items[0])

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
        SharedStr.get(<SharedStr>self._value, current_value)
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
        self.state.cur.active = open # TODO move to toggled ?
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_edited = True
        self.update_current_state_subset()

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
                                                self.scaled_requested_size())
                    if selected:
                        imgui.SetItemDefaultFocus()
                    if selected and selected != selected_backup:
                        changed = True
                        SharedStr.set(<SharedStr>self._value, self._items[i])
                    imgui.PopID()
            else:
                # TODO: test
                selected = True
                imgui.Selectable(current_value.c_str(),
                                 &selected,
                                 imgui.ImGuiSelectableFlags_Disabled,
                                 self.scaled_requested_size())
            imgui.PopID()
            imgui.EndListBox()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.cur.edited = changed
        #self.state.cur.deactivated_after_edited = self.state.cur.deactivated and changed -> TODO Unsure. Isn't it rather focus loss ?
        return pressed


cdef class RadioButton(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_radiobutton
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._horizontal = False

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
            SharedStr.set(<SharedStr>self._value, self._items[0])

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
        SharedStr.get(<SharedStr>self._value, current_value)
        imgui.PushID(self.uuid)
        imgui.BeginGroup()

        cdef bint changed = False
        cdef bool selected
        cdef bool selected_backup
        # we push an ID because we didn't append ###uuid to the items
        
        for i in range(<int>self._items.size()):
            imgui.PushID(i)
            if (self._horizontal and i != 0):
                imgui.SameLine(0., -1.)
            selected_backup = self._items[i] == current_value
            selected = imgui.RadioButton(self._items[i].c_str(),
                                         selected_backup)
            if self._enabled and selected and selected != selected_backup:
                changed = True
                SharedStr.set(<SharedStr>self._value, self._items[i])
            imgui.PopID()
        imgui.EndGroup()
        imgui.PopID()
        self.update_current_state()
        return changed


cdef class InputText(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_inputtext
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
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
        SharedStr.get(<SharedStr>self._value, current_value)

        cdef bint changed = False
        if not(self._enabled):
            flags |= imgui.ImGuiInputTextFlags_ReadOnly
        if <int>current_value.size() != (self._max_characters+1):
            # TODO: avoid the copies that occur
            # In theory the +1 is not needed here
            current_value.resize(self._max_characters+1)
        cdef char* data = current_value.data()
        if self._multiline:
            changed = imgui.InputTextMultiline(self.imgui_label.c_str(),
                                               data,
                                               self._max_characters+1,
                                               self.scaled_requested_size(),
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
        if changed:
            SharedStr.set(<SharedStr>self._value, current_value)
        if not(self._enabled):
            changed = False
            self.state.cur.edited = False
            self.state.cur.deactivated_after_edited = False
            self.state.cur.active = False
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

cdef class InputValue(uiItem):
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
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self.state.cap.can_be_active = True # unsure
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    def configure(self, **kwargs):
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
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif target_format == 0:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
        else:
            if target_format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif target_format == 0:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
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
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
            self.value = previous_value[0]
        else:
            if self._format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
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
        cdef void *data_step = NULL
        cdef void *data_step_fast = NULL
        cdef bint modified
        cdef int istep, istep_fast
        cdef float fstep, fstep_fast
        cdef double dstep, dstep_fast
        # Prepare data type
        if self._format == 0:
            type = imgui.ImGuiDataType_S32
            istep = <int>self._step
            istep_fast = <int>self._step_fast
            if istep > 0:
                data_step = &istep
            if istep_fast > 0:
                data_step_fast = &istep_fast
        elif self._format == 1:
            type = imgui.ImGuiDataType_Float
            fstep = <float>self._step
            fstep_fast = <float>self._step_fast
            if fstep > 0:
                data_step = &fstep
            if fstep_fast > 0:
                data_step_fast = &fstep_fast
        else:
            type = imgui.ImGuiDataType_Double
            dstep = <double>self._step
            dstep_fast = <double>self._step_fast
            if dstep > 0:
                data_step = &dstep
            if dstep_fast > 0:
                data_step_fast = &dstep_fast

        # Read the value
        if self._format == 0:
            if self._size == 1:
                value_int = SharedInt.get(<SharedInt>self._value)
                data = &value_int
            else:
                SharedInt4.get(<SharedInt4>self._value, value_int4)
                data = &value_int4
        elif self._format == 1:
            if self._size == 1:
                value_float = SharedFloat.get(<SharedFloat>self._value)
                data = &value_float
            else:
                SharedFloat4.get(<SharedFloat4>self._value, value_float4)
                data = &value_float4
        else:
            if self._size == 1:
                value_double = SharedDouble.get(<SharedDouble>self._value)
                data = &value_double
            else:
                SharedDouble4.get(<SharedDouble4>self._value, value_double4)
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
                    SharedInt.set(<SharedInt>self._value, value_int)
                else:
                    if modified:
                        clamp4[int](value_int4, self._min, self._max)
                    SharedInt4.set(<SharedInt4>self._value, value_int4)
            elif self._format == 1:
                if self._size == 1:
                    if modified:
                        clamp1[float](value_float, self._min, self._max)
                    SharedFloat.set(<SharedFloat>self._value, value_float)
                else:
                    if modified:
                        clamp4[float](value_float4, self._min, self._max)
                    SharedFloat4.set(<SharedFloat4>self._value, value_float4)
            else:
                if self._size == 1:
                    if modified:
                        clamp1[double](value_double, self._min, self._max)
                    SharedDouble.set(<SharedDouble>self._value, value_double)
                else:
                    if modified:
                        clamp4[double](value_double4, self._min, self._max)
                    SharedDouble4.set(<SharedDouble4>self._value, value_double4)
            modified = modified and (self._value._last_frame_update == self._value._last_frame_change)
        self.update_current_state()
        return modified


cdef class Text(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_text
        self._color = 0 # invisible
        self._wrap = -1
        self._bullet = False
        self._show_label = False
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True # unsure
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

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
        Writable attribute: wrap width in pixels
        -1 for no wrapping
        The width is multiplied by the global scale
        unless the no_scaling option is set.
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
            imgui.PushTextWrapPos(imgui.GetCursorPosX() + <float>self._wrap * (self.context._viewport.global_scale if self.dpi_scaling else 1.))
        if self._show_label or self._bullet:
            imgui.BeginGroup()
        if self._bullet:
            imgui.Bullet()

        cdef string current_value
        SharedStr.get(<SharedStr>self._value, current_value)

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
            # And have correct rect_size
            imgui.EndGroup()

        self.update_current_state()
        return False


cdef class Selectable(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_selectable
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
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

        cdef bool checked = SharedBool.get(<SharedBool>self._value)
        cdef bint changed = imgui.Selectable(self.imgui_label.c_str(),
                                             &checked,
                                             flags,
                                             self.scaled_requested_size())
        if self._enabled:
            SharedBool.set(<SharedBool>self._value, checked)
        self.update_current_state()
        return changed


cdef class MenuItem(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_menuitem
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
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
        cdef bool current_value = SharedBool.get(<SharedBool>self._value)
        cdef bint activated = imgui.MenuItem(self.imgui_label.c_str(),
                                             self._shortcut.c_str(),
                                             &current_value if self._check else NULL,
                                             self._enabled)
        self.update_current_state()
        SharedBool.set(<SharedBool>self._value, current_value)
        return activated

cdef class ProgressBar(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_progressbar
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

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
        cdef float current_value = SharedFloat.get(<SharedFloat>self._value)
        cdef const char *overlay_text = self._overlay.c_str()
        imgui.PushID(self.uuid)
        imgui.ProgressBar(current_value,
                          self.scaled_requested_size(),
                          <const char *>NULL if self._overlay.size() == 0 else overlay_text)
        imgui.PopID()
        self.update_current_state()
        return False

cdef class Image(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_image
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._uv = [0., 0., 1., 1.]
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
        if not(isinstance(value, Texture)):
            raise TypeError("texture must be a Texture")
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
        read_vec4[float](self._uv, value)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self._texture.mutex)
        if self._texture.allocated_texture == NULL:
            return False
        cdef imgui.ImVec2 size = self.scaled_requested_size()
        if size.x == 0.:
            size.x = self._texture._width * (self.context._viewport.global_scale if self.dpi_scaling else 1.)
        if size.y == 0.:
            size.y = self._texture._height * (self.context._viewport.global_scale if self.dpi_scaling else 1.)

        imgui.PushID(self.uuid)
        imgui.Image(<imgui.ImTextureID>self._texture.allocated_texture,
                    size,
                    imgui.ImVec2(self._uv[0], self._uv[1]),
                    imgui.ImVec2(self._uv[2], self._uv[3]),
                    imgui.ColorConvertU32ToFloat4(self._color_multiplier),
                    imgui.ColorConvertU32ToFloat4(self._border_color))
        imgui.PopID()
        self.update_current_state()
        return False


cdef class ImageButton(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_imagebutton
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
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
        if not(isinstance(value, Texture)):
            raise TypeError("texture must be a Texture")
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
        read_vec4[float](self._uv, value)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self._texture.mutex)
        if self._texture.allocated_texture == NULL:
            return False
        cdef imgui.ImVec2 size = self.scaled_requested_size()
        if size.x == 0.:
            size.x = self._texture._width * (self.context._viewport.global_scale if self.dpi_scaling else 1.)
        if size.y == 0.:
            size.y = self._texture._height * (self.context._viewport.global_scale if self.dpi_scaling else 1.)

        imgui.PushID(self.uuid)
        if self._frame_padding >= 0:
            imgui.PushStyleVar(imgui.ImGuiStyleVar_FramePadding,
                               imgui.ImVec2(<float>self._frame_padding,
                                            <float>self._frame_padding))
        cdef bint activated
        activated = imgui.ImageButton(self.imgui_label.c_str(),
                                      <imgui.ImTextureID>self._texture.allocated_texture,
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

cdef class Separator(uiItem):
    def __cinit__(self):
        self.state.cap.has_rect_size = False
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

cdef class Spacer(uiItem):
    def __cinit__(self):
        self.state.cap.has_rect_size = False
        self.can_be_disabled = False
    cdef bint draw_item(self) noexcept nogil:
        if self.requested_size.x == 0 and \
           self.requested_size.y == 0:
            imgui.Spacing()
        else:
            imgui.Dummy(self.scaled_requested_size())
        return False

cdef class MenuBar(uiItem):
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self.can_have_widget_child = True
        self.element_child_category = child_type.cat_menubar
        self.theme_condition_category = theme_categories.t_menubar
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_content_region = True # TODO

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<uiItem>self._prev_sibling).draw()

        if not(self._show):
            if self.show_update_requested:
                self.set_previous_states()
                self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
                self.run_handlers()
                self.show_update_requested = False
            return

        self.set_previous_states()
        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        self.context._viewport.push_pending_theme_actions(
            self.theme_condition_enabled,
            self.theme_condition_category
        )
        if self._theme is not None:
            self._theme.push()

        cdef bint enabled = self._enabled
        if not(enabled):
            imgui.PushItemFlag(1 << 10, True) #ImGuiItemFlags_Disabled

        cdef bint menu_allowed
        cdef bint parent_viewport = self._parent is self.context._viewport
        if parent_viewport:
            menu_allowed = imgui.BeginMainMenuBar()
        else:
            menu_allowed = imgui.BeginMenuBar()
        cdef imgui.ImVec2 pos_w, pos_p
        if menu_allowed:
            self.update_current_state()
            if self.last_widgets_child is not None:
                # We are at the top of the window, but behave as if popup
                pos_w = imgui.GetCursorScreenPos()
                pos_p = pos_w
                swap(pos_w, self.context._viewport.window_pos)
                swap(pos_p, self.context._viewport.parent_pos)
                self.last_widgets_child.draw()
                self.context._viewport.window_pos = pos_w
                self.context._viewport.parent_pos = pos_p
            if parent_viewport:
                imgui.EndMainMenuBar()
            else:
                imgui.EndMenuBar()
        else:
            # We should hit this only if window is invisible
            # or has no menu bar
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
        cdef bint activated = self.state.cur.active and not(self.state.prev.active)
        cdef int i
        if activated and not(self._callbacks.empty()):
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

        if not(enabled):
            imgui.PopItemFlag()

        if self._theme is not None:
            self._theme.pop()
        self.context._viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        self.run_handlers()


cdef class Menu(uiItem):
    # TODO: MUST be inside a menubar
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.theme_condition_category = theme_categories.t_menu
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.has_rect_size = True

    cdef bint draw_item(self) noexcept nogil:
        cdef bint menu_open = imgui.BeginMenu(self.imgui_label.c_str(),
                                              self._enabled)
        self.update_current_state()
        cdef imgui.ImVec2 pos_w, pos_p
        if menu_open:
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            self.state.cur.rect_size.x = imgui.GetWindowWidth()
            self.state.cur.rect_size.y = imgui.GetWindowHeight()
            if self.last_widgets_child is not None:
                # We are in a separate window
                pos_w = imgui.GetCursorScreenPos()
                pos_p = pos_w
                swap(pos_w, self.context._viewport.window_pos)
                swap(pos_p, self.context._viewport.parent_pos)
                self.last_widgets_child.draw()
                self.context._viewport.window_pos = pos_w
                self.context._viewport.parent_pos = pos_p
            imgui.EndMenu()
        else:
            self.propagate_hidden_state_to_children_with_handlers()
        SharedBool.set(<SharedBool>self._value, menu_open)
        return self.state.cur.active and not(self.state.prev.active)

cdef class Tooltip(uiItem):
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self.can_have_widget_child = True
        self.theme_condition_category = theme_categories.t_tooltip
        self.state.cap.can_be_active = True # TODO unsure. Maybe use open instead ?
        self.state.cap.has_position = False
        self.state.cap.has_rect_size = False
        self._delay = 0.
        self._hide_on_activity = False
        self._target = None


    @property
    def target(self):
        """
        Target item which state will be checked
        to trigger the tooltip.
        Note if the item is after this tooltip
        in the rendering tree, there will be
        a frame delay.
        If no target is set, the previous sibling
        is the target.
        If the target is not the previous sibling,
        delay will have no effect.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._target

    @target.setter
    def target(self, baseItem target):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._target = None
        if target is None:
            return
        if self.secondary_handler is not None:
            self.secondary_handler.check_bind(target)
        # TODO: Raise a warning ?
        #elif target.p_state == NULL or not(target.p_state.cap.can_be_hovered):
        #    raise TypeError(f"Unsupported target instance {target}")
        self._target = target

    @property
    def condition_from_handler(self):
        """
        When set, the handler referenced in
        this field will be used to replace
        the target hovering check. It will
        apply to target, which must be set.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.secondary_handler

    @condition_from_handler.setter
    def condition_from_handler(self, baseHandler handler):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._target is not None:
            handler.check_bind(self._target)
        self.secondary_handler = handler

    @property
    def delay(self):
        """
        Delay in seconds with no motion before showing the tooltip
        -1: Use imgui defaults
        Has no effect if the target is not the previous sibling,
        or if condition_from_handler is set.
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
        cdef bint display_condition = False
        if self.secondary_handler is None:
            if self._target is None or self._target is self._prev_sibling:
                if self._delay > 0.:
                    hoverDelay_backup = imgui.GetStyle().HoverStationaryDelay
                    imgui.GetStyle().HoverStationaryDelay = self._delay
                    display_condition = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_Stationary)
                    imgui.GetStyle().HoverStationaryDelay = hoverDelay_backup
                elif self._delay == 0:
                    display_condition = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
                else:
                    display_condition = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_ForTooltip)
            elif self._target.p_state != NULL:
                display_condition = self._target.p_state.cur.hovered
        elif self._target is not None:
            display_condition = self.secondary_handler.check_state(self._target)

        if self._hide_on_activity and imgui.GetIO().MouseDelta.x != 0. and \
           imgui.GetIO().MouseDelta.y != 0.:
            display_condition = False

        cdef bint was_visible = self.state.cur.rendered
        cdef imgui.ImVec2 pos_w, pos_p
        if display_condition and imgui.BeginTooltip():
            if self.last_widgets_child is not None:
                # We are in a popup window
                pos_w = imgui.GetCursorScreenPos()
                pos_p = pos_w
                swap(pos_w, self.context._viewport.window_pos)
                swap(pos_p, self.context._viewport.parent_pos)
                self.last_widgets_child.draw()
                self.context._viewport.window_pos = pos_w
                self.context._viewport.parent_pos = pos_p
            imgui.EndTooltip()
            self.update_current_state()
        else:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            # NOTE: we could also set the rects. DPG does it.
        if self.state.cur.rendered != was_visible:
            self.context._viewport.viewport.needs_refresh.store(True)
        return self.state.cur.rendered and not(was_visible)

cdef class TabButton(uiItem):
    def __cinit__(self):
        self.theme_condition_category = theme_categories.t_tabbutton
        self.element_child_category = child_type.cat_tab
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
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
        #SharedBool.set(<SharedBool>self._value, self.state.cur.active) # Unsure. Not in original
        return pressed


cdef class Tab(uiItem):
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.element_child_category = child_type.cat_tab
        self.theme_condition_category = theme_categories.t_tab
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.has_rect_size = True
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
        cdef imgui.ImGuiTabItemFlags flags = self.flags
        if (<SharedBool>self._value)._last_frame_change == self.context._viewport.frame_count:
            # The value was changed after the last time we drew
            # TODO: will have no effect if we switch from show to no show.
            # maybe have a counter here.
            if SharedBool.get(<SharedBool>self._value):
                flags |= imgui.ImGuiTabItemFlags_SetSelected
        cdef bint menu_open = imgui.BeginTabItem(self.imgui_label.c_str(),
                                                 &self._show if self._closable else NULL,
                                                 flags)
        if not(self._show):
            self.show_update_requested = True
        self.update_current_state()
        cdef imgui.ImVec2 pos_p
        if menu_open:
            if self.last_widgets_child is not None:
                pos_p = imgui.GetCursorScreenPos()
                swap(pos_p, self.context._viewport.parent_pos)
                self.last_widgets_child.draw()
                self.context._viewport.parent_pos = pos_p
            imgui.EndTabItem()
        else:
            self.propagate_hidden_state_to_children_with_handlers()
        SharedBool.set(<SharedBool>self._value, menu_open)
        return self.state.cur.active and not(self.state.prev.active)


cdef class TabBar(uiItem):
    def __cinit__(self):
        #self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_tab_child = True
        self.theme_condition_category = theme_categories.t_tabbar
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.has_rect_size = True
        self.flags = imgui.ImGuiTabBarFlags_None

    @property
    def reorderable(self):
        """
        Writable attribute: Allow manually dragging tabs
        to re-order them + New tabs are appended at the end of list
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_Reorderable) != 0

    @reorderable.setter
    def reorderable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_Reorderable
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_Reorderable

    @property
    def autoselect_new_tabs(self):
        """
        Writable attribute: Automatically select new
        tabs when they appear
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_AutoSelectNewTabs) != 0

    @autoselect_new_tabs.setter
    def autoselect_new_tabs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_AutoSelectNewTabs
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_AutoSelectNewTabs

    @property
    def no_tab_list_popup_button(self):
        """
        Writable attribute: Disable buttons to open the tab list popup
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_TabListPopupButton) != 0

    @no_tab_list_popup_button.setter
    def no_tab_list_popup_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_TabListPopupButton
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_TabListPopupButton

    @property
    def no_close_with_middle_mouse_button(self):
        """
        Writable attribute: Disable behavior of closing tabs with middle mouse button.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) != 0

    @no_close_with_middle_mouse_button.setter
    def no_close_with_middle_mouse_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton

    @property
    def no_scrolling_button(self):
        """
        Writable attribute: Disable scrolling buttons
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_NoTabListScrollingButtons) != 0

    @no_scrolling_button.setter
    def no_scrolling_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_NoTabListScrollingButtons
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_NoTabListScrollingButtons

    @property
    def no_tooltip(self):
        """
        Writable attribute: Disable tooltip for all tabs
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_NoTooltip
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_NoTooltip

    @property
    def selected_overline(self):
        """
        Writable attribute: Draw selected overline markers over selected tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_DrawSelectedOverline) != 0

    @selected_overline.setter
    def selected_overline(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_DrawSelectedOverline
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_DrawSelectedOverline

    @property
    def resize_to_fit(self):
        """
        Writable attribute: Resize tabs when they don't fit
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_FittingPolicyResizeDown) != 0

    @resize_to_fit.setter
    def resize_to_fit(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_FittingPolicyResizeDown
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_FittingPolicyResizeDown

    @property
    def allow_tab_scroll(self):
        """
        Writable attribute: Add scroll buttons when tabs don't fit
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTabBarFlags_FittingPolicyScroll) != 0

    @allow_tab_scroll.setter
    def allow_tab_scroll(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTabBarFlags_FittingPolicyScroll
        if value:
            self.flags |= imgui.ImGuiTabBarFlags_FittingPolicyScroll

    cdef bint draw_item(self) noexcept nogil:
        imgui.PushID(self.uuid)
        imgui.BeginGroup() # from original. Unsure if needed
        cdef bint visible = imgui.BeginTabBar(self.imgui_label.c_str(),
                                              self.flags)
        self.update_current_state()
        cdef imgui.ImVec2 pos_p
        if visible:
            if self.last_tab_child is not None:
                pos_p = imgui.GetCursorScreenPos()
                swap(pos_p, self.context._viewport.parent_pos)
                self.last_tab_child.draw()
                self.context._viewport.parent_pos = pos_p
            imgui.EndTabBar()
        else:
            self.propagate_hidden_state_to_children_with_handlers()
        imgui.EndGroup()
        imgui.PopID()
        return self.state.cur.active and not(self.state.prev.active)


cdef class Layout(uiItem):
    """
    A layout is a group of elements organized
    together.
    The layout states correspond to the OR
    of all the item states, and the rect size
    corresponds to the minimum rect containing
    all the items. The position of the layout
    is used to initialize the default position
    for the first item.
    For example setting indent will shift all
    the items of the Layout.

    Subclassing Layout:
    For custom layouts, you can use Layout with
    a callback. The callback is called whenever
    the layout should be updated.

    If the automated update detection is not
    sufficient, update_layout() can be called
    to force a recomputation of the layout.

    Currently the update detection detects a change in
    the size of the remaining content area available
    locally within the window, or if the last item has changed.

    The layout item works by changing the positioning
    policy and the target position of its children, and
    thus there is no guarantee that the user set
    positioning and position states of the children are
    preserved.
    """
    def __cinit__(self):
        self.can_have_widget_child = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self.theme_condition_category = theme_categories.t_layout
        self.prev_content_area.x = 0
        self.prev_content_area.y = 0
        self.previous_last_child = NULL

    def update_layout(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.context.queue_callback_arg1value(self._callback, self, self, self._value) # TODO: callbacks ?

    cdef bint check_change(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        cdef bint changed = False
        if cur_content_area.x != self.prev_content_area.x or \
           cur_content_area.y != self.prev_content_area.y or \
           self.previous_last_child != <PyObject*>self.last_widgets_child or \
           self.size_update_requested or \
           self.force_update:
            changed = True
            self.prev_content_area = cur_content_area
            self.previous_last_child = <PyObject*>self.last_widgets_child
            self.force_update = False
            self.size_update_requested = False
        return changed

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail() # TODO: pass to the callback ? Or set as state ?
        if self.last_widgets_child is None:# or \
            #cur_content_area.x <= 0 or \
            #cur_content_area.y <= 0: # <= 0 occurs when not visible
            #self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            return False
        cdef bint changed = self.check_change()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef imgui.ImVec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = imgui.GetCursorScreenPos()
            swap(pos_p, self.context._viewport.parent_pos)
            self.last_widgets_child.draw()
            self.context._viewport.parent_pos = pos_p
        imgui.EndGroup()
        imgui.PopID()
        self.update_current_state()
        return changed

cdef class HorizontalLayout(Layout):
    """
    A basic layout to organize the items
    horizontally.
    """
    def __cinit__(self):
        self._alignment_mode = alignment.LEFT

    @property
    def alignment_mode(self):
        """
        Horizontal alignment mode of the items.
        LEFT: items are appended from the left
        RIGHT: items are appended from the right
        CENTER: items are centered
        JUSTIFIED: spacing is organized such
        that items start at the left and end
        at the right.
        MANUAL: items are positionned at the requested
        positions

        FOR LEFT/RIGHT/CENTER, spacing can be used
        to add additional spacing between the items.
        Default is LEFT.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @alignment_mode.setter
    def alignment_mode(self, alignment value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value > alignment.MANUAL:
            raise ValueError("Invalid alignment value")
        self._alignment_mode = value

    @property
    def spacing(self):
        """
        Additional space to add between items.
        Doesn't have effect with JUSTIFIED or MANUAL.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @spacing.setter
    def spacing(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._spacing = value

    @property
    def positions(self):
        """
        When in MANUAL mode, the x position starting
        from the top left of this item at which to
        place the children items.

        If the positions are between 0 and 1, they are
        interpreted as percentages relative to the
        size of the Layout width.
        If the positions are negatives, they are interpreted
        as in reference to the right of the layout rather
        than the left. Items are still left aligned to
        the target position though.

        Setting this field sets the alignment mode to
        MANUAL.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._positions

    @positions.setter
    def positions(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._alignment_mode = alignment.MANUAL
        # TODO: checks
        self._positions.clear()
        for v in value:
            self._positions.push_back(v)

    def update_layout(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.last_widgets_child is None:
            return
        self.last_widgets_child.lock_and_previous_siblings()
        self.__update_layout() # Maybe instead queue an update ?
        self.last_widgets_child.unlock_and_previous_siblings()

    cdef float __compute_items_size(self, int &n_items) noexcept nogil:
        cdef float size = 0.
        n_items = 0
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child) is not None:
            size += (<uiItem>child).state.cur.rect_size.x
            n_items += 1
            child = <PyObject*>((<uiItem>child)._prev_sibling)
            if (<uiItem>child).requested_size.x == 0 and not(self.state.prev.rendered):
                # Will need to recompute layout after the size is computed
                self.force_update = True
        return size

    cdef void __update_layout(self) noexcept nogil: # assumes children are locked and > 0
        # Set all items on the same row
        # and relative positioning mode
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child) is not None:
            (<uiItem>child)._pos_policy[0] = positioning.REL_PARENT
            (<uiItem>child)._no_newline = True
            child = <PyObject*>((<uiItem>child)._prev_sibling)
        self.last_widgets_child._no_newline = False

        cdef float available_width = self.scaled_requested_size().x
        if available_width == 0:
            available_width = self.prev_content_area.x
        elif available_width < 0:
            available_width = available_width + self.prev_content_area.x


        cdef float pos_end, pos_start, target_pos, size, spacing, rem
        cdef int n_items = 0
        if self._alignment_mode == alignment.LEFT:
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                (<uiItem>child)._pos_policy[0] = positioning.REL_DEFAULT
                if ((<uiItem>child)._prev_sibling) is not None:
                    (<uiItem>child).state.cur.pos_to_default.x = self._spacing
                else:
                    (<uiItem>child).state.cur.pos_to_default.x = 0.
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == alignment.RIGHT:
            pos_end = available_width
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                # Position at which to render to end at pos_end
                target_pos = pos_end - (<uiItem>child).state.cur.rect_size.x
                (<uiItem>child).state.cur.pos_to_parent.x = target_pos
                pos_end = target_pos - self._spacing
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == alignment.CENTER:
            size = self.__compute_items_size(n_items)
            size += max(0, (n_items - 1)) * self._spacing
            pos_start = available_width // 2 - \
                        size // 2 # integer rounding to avoid blurring
            pos_end = pos_start + size
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                # Position at which to render to end at size
                target_pos = pos_end - (<uiItem>child).state.cur.rect_size.x
                (<uiItem>child).state.cur.pos_to_parent.x = target_pos
                pos_end = target_pos - self._spacing
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == alignment.JUSTIFIED:
            size = self.__compute_items_size(n_items)
            if n_items == 1:
                # prefer to revert to align left
                self.last_widgets_child._pos_policy[0] = positioning.DEFAULT
            else:
                pos_end = available_width
                spacing = floor((available_width - size) / (n_items-1))
                # remaining pixels to completly end at the right
                rem = (available_width - size) - spacing * (n_items-1)
                rem += spacing
                child = <PyObject*>self.last_widgets_child
                while (<uiItem>child) is not None:
                    target_pos = pos_end - (<uiItem>child).state.cur.rect_size.x
                    (<uiItem>child).state.cur.pos_to_parent.x = target_pos
                    pos_end = target_pos
                    pos_end -= rem
                    # Use rem for the last item, then spacing
                    if rem != spacing:
                        rem = spacing
                    child = <PyObject*>((<uiItem>child)._prev_sibling)
        else: #MANUAL
            n_items = 1
            pos_start = 0.
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                if not(self._positions.empty()):
                    pos_start = self._positions[max(0, <int>self._positions.size()-n_items)]
                if pos_start > 0.:
                    if pos_start < 1.:
                        pos_start *= available_width
                        pos_start = floor(pos_start)
                elif pos_start < 0:
                    if pos_start > -1.:
                        pos_start *= available_width
                        pos_start += available_width
                        pos_start = floor(pos_start)
                    else:
                        pos_start += available_width

                (<uiItem>child).state.cur.pos_to_parent.x = pos_start
                child = <PyObject*>((<uiItem>child)._prev_sibling)
                n_items += 1

        if self.force_update:
            # Prevent not refreshing
            self.context._viewport.cwake()

    cdef bint check_change(self) noexcept nogil:
        # Same as Layout check_change but only looks
        # horizontally content area changes
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        cdef bint changed = False
        if cur_content_area.x != self.prev_content_area.x or \
           self.previous_last_child != <PyObject*>self.last_widgets_child or \
           self.size_update_requested or \
           self.force_update:
            changed = True
            self.prev_content_area = cur_content_area
            self.previous_last_child = <PyObject*>self.last_widgets_child
            self.force_update = False
            self.size_update_requested = False
        return changed

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        if self.last_widgets_child is None:# or \
            #cur_content_area.x <= 0 or \
            #cur_content_area.y <= 0: # <= 0 occurs when not visible
            # self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            return False
        cdef bint changed = self.check_change()
        changed = True
        if changed:
            self.last_widgets_child.lock_and_previous_siblings()
            self.__update_layout()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef imgui.ImVec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = imgui.GetCursorScreenPos()
            swap(pos_p, self.context._viewport.parent_pos)
            self.last_widgets_child.draw()
            self.context._viewport.parent_pos = pos_p
        if changed:
            # We maintain the lock during the rendering
            # just to be sure the user doesn't change the
            # positioning we took care to manage :-)
            self.last_widgets_child.unlock_and_previous_siblings()
        imgui.EndGroup()
        imgui.PopID()
        self.update_current_state()
        return changed


cdef class VerticalLayout(Layout):
    """
    Same as HorizontalLayout but vertically
    """
    def __cinit__(self):
        self._alignment_mode = alignment.TOP

    @property
    def alignment_mode(self):
        """
        Vertical alignment mode of the items.
        TOP: items are appended from the top
        BOTTOM: items are appended from the BOTTOM
        CENTER: items are centered
        JUSTIFIED: spacing is organized such
        that items start at the TOP and end
        at the BOTTOM.
        MANUAL: items are positionned at the requested
        positions

        FOR TOP/BOTTOM/CENTER, spacing can be used
        to add additional spacing between the items.
        Default is TOP.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @alignment_mode.setter
    def alignment_mode(self, alignment value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0 or value > alignment.MANUAL:
            raise ValueError("Invalid alignment value")
        self._alignment_mode = value

    @property
    def spacing(self):
        """
        Additional space to add between items.
        Doesn't have effect with JUSTIFIED or MANUAL.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @spacing.setter
    def spacing(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._spacing = value

    @property
    def positions(self):
        """
        When in MANUAL mode, the y position starting
        from the top left of this item at which to
        place the children items.

        If the positions are between 0 and 1, they are
        interpreted as percentages relative to the
        size of the Layout height.
        If the positions are negatives, they are interpreted
        as in reference to the bottom of the layout rather
        than the top. Items are still top aligned to
        the target position though.

        Setting this field sets the alignment mode to
        MANUAL.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._positions

    @positions.setter
    def positions(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._alignment_mode = alignment.MANUAL
        # TODO: checks
        self._positions.clear()
        for v in value:
            self._positions.push_back(v)

    def update_layout(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.last_widgets_child is None:
            return
        self.last_widgets_child.lock_and_previous_siblings()
        self.__update_layout() # Maybe instead queue an update ?
        self.last_widgets_child.unlock_and_previous_siblings()

    cdef float __compute_items_size(self, int &n_items) noexcept nogil:
        cdef float size = 0.
        n_items = 0
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child) is not None:
            size += (<uiItem>child).state.cur.rect_size.y
            n_items += 1
            child = <PyObject*>((<uiItem>child)._prev_sibling)
            if (<uiItem>child).requested_size.y == 0 and not(self.state.prev.rendered):
                # Will need to recompute layout after the size is computed
                self.force_update = True
        return size

    cdef void __update_layout(self) noexcept nogil:
        # assumes children are locked and > 0
        # Set all items on the same row
        # and relative positioning mode
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child) is not None:
            (<uiItem>child)._pos_policy[1] = positioning.REL_PARENT
            (<uiItem>child)._no_newline = False
            child = <PyObject*>((<uiItem>child)._prev_sibling)
        self.last_widgets_child._no_newline = False

        cdef float available_height = self.scaled_requested_size().y
        if available_height == 0:
            available_height = self.prev_content_area.y
        elif available_height < 0:
            available_height = available_height + self.prev_content_area.y


        cdef float pos_end, pos_start, target_pos, size, spacing, rem
        cdef int n_items = 0
        if self._alignment_mode == alignment.TOP:
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                (<uiItem>child)._pos_policy[1] = positioning.REL_DEFAULT
                if ((<uiItem>child)._prev_sibling) is not None:
                    (<uiItem>child).state.cur.pos_to_default.y = self._spacing
                else:
                    (<uiItem>child).state.cur.pos_to_default.y = 0.
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == alignment.RIGHT:
            pos_end = available_height
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                # Position at which to render to end at pos_end
                target_pos = pos_end - (<uiItem>child).state.cur.rect_size.y
                (<uiItem>child).state.cur.pos_to_parent.y = target_pos
                pos_end = target_pos - self._spacing
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == alignment.CENTER:
            size = self.__compute_items_size(n_items)
            size += max(0, (n_items - 1)) * self._spacing
            pos_start = available_height // 2 - \
                        size // 2 # integer rounding to avoid blurring
            pos_end = pos_start + size
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                # Position at which to render to end at size
                target_pos = pos_end - (<uiItem>child).state.cur.rect_size.y
                (<uiItem>child).state.cur.pos_to_parent.y = target_pos
                pos_end = target_pos - self._spacing
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == alignment.JUSTIFIED:
            size = self.__compute_items_size(n_items)
            if n_items == 1:
                # prefer to revert to align top
                self.last_widgets_child._pos_policy[1] = positioning.DEFAULT
            else:
                pos_end = available_height
                spacing = floor((available_height - size) / (n_items-1))
                # remaining pixels to completly end at the right
                rem = (available_height - size) - spacing * (n_items-1)
                rem += spacing
                child = <PyObject*>self.last_widgets_child
                while (<uiItem>child) is not None:
                    target_pos = pos_end - (<uiItem>child).state.cur.rect_size.y
                    (<uiItem>child).state.cur.pos_to_parent.y = target_pos
                    pos_end = target_pos
                    pos_end -= rem
                    # Use rem for the last item, then spacing
                    if rem != spacing:
                        rem = spacing
                    child = <PyObject*>((<uiItem>child)._prev_sibling)
        else: #MANUAL
            n_items = 1
            pos_start = 0.
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                if not(self._positions.empty()):
                    pos_start = self._positions[max(0, <int>self._positions.size()-n_items)]
                if pos_start > 0.:
                    if pos_start < 1.:
                        pos_start *= available_height
                        pos_start = floor(pos_start)
                elif pos_start < 0:
                    if pos_start > -1.:
                        pos_start *= available_height
                        pos_start += available_height
                        pos_start = floor(pos_start)
                    else:
                        pos_start += available_height

                (<uiItem>child).state.cur.pos_to_parent.y = pos_start
                child = <PyObject*>((<uiItem>child)._prev_sibling)
                n_items += 1

        if self.force_update:
            # Prevent not refreshing
            self.context._viewport.cwake()

    cdef bint check_change(self) noexcept nogil:
        # Same as Layout check_change but ignores horizontal content
        # area changes
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        cdef bint changed = False
        if cur_content_area.y != self.prev_content_area.y or \
           self.previous_last_child != <PyObject*>self.last_widgets_child or \
           self.size_update_requested or \
           self.force_update:
            changed = True
            self.prev_content_area = cur_content_area
            self.previous_last_child = <PyObject*>self.last_widgets_child
            self.force_update = False
            self.size_update_requested = False
        return changed

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        if self.last_widgets_child is None:# or \
            #cur_content_area.x <= 0 or \
            #cur_content_area.y <= 0: # <= 0 occurs when not visible
            # self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            return False
        cdef bint changed = self.check_change()
        changed = True
        if changed:
            self.last_widgets_child.lock_and_previous_siblings()
            self.__update_layout()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef imgui.ImVec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = imgui.GetCursorScreenPos()
            swap(pos_p, self.context._viewport.parent_pos)
            self.last_widgets_child.draw()
            self.context._viewport.parent_pos = pos_p
        if changed:
            # We maintain the lock during the rendering
            # just to be sure the user doesn't change the
            # positioning we took care to manage :-)
            self.last_widgets_child.unlock_and_previous_siblings()
        imgui.EndGroup()
        imgui.PopID()
        self.update_current_state()
        return changed

cdef class TreeNode(uiItem):
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self._selectable = False
        self.flags = imgui.ImGuiTreeNodeFlags_None
        self.theme_condition_category = theme_categories.t_treenode

    @property
    def selectable(self):
        """
        Writable attribute: Draw the TreeNode as selected when opened
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._selectable

    @selectable.setter
    def selectable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._selectable = value

    @property
    def default_open(self):
        """
        Writable attribute: Default node to be open
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_DefaultOpen) != 0

    @default_open.setter
    def default_open(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_DefaultOpen
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_DefaultOpen

    @property
    def open_on_double_click(self):
        """
        Writable attribute: Need double-click to open node
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick) != 0

    @open_on_double_click.setter
    def open_on_double_click(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick

    @property
    def open_on_arrow(self):
        """
        Writable attribute:  Only open when clicking on the arrow part.
        If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set,
        single-click arrow or double-click all box to open.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_OpenOnArrow) != 0

    @open_on_arrow.setter
    def open_on_arrow(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnArrow
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_OpenOnArrow

    @property
    def leaf(self):
        """
        Writable attribute: No collapsing, no arrow (use as a convenience for leaf nodes).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_Leaf) != 0

    @leaf.setter
    def leaf(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_Leaf
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_Leaf

    @property
    def bullet(self):
        """
        Writable attribute: Display a bullet instead of arrow.
        IMPORTANT: node can still be marked open/close if
        you don't set the _Leaf flag!
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_Bullet) != 0

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_Bullet
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_Bullet

    @property
    def span_text_width(self):
        """
        Writable attribute: Narrow hit box + narrow hovering
        highlight, will only cover the label text.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_SpanTextWidth) != 0

    @span_text_width.setter
    def span_text_width(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_SpanTextWidth
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_SpanTextWidth

    @property
    def span_full_width(self):
        """
        Writable attribute: Extend hit box to the left-most
        and right-most edges (cover the indent area).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_SpanFullWidth) != 0

    @span_full_width.setter
    def span_full_width(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_SpanFullWidth
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_SpanFullWidth

    cdef bint draw_item(self) noexcept nogil:
        cdef bint was_open = SharedBool.get(<SharedBool>self._value)
        cdef bint closed = False
        cdef imgui.ImGuiTreeNodeFlags flags = self.flags
        imgui.PushID(self.uuid)
        # Unsure group is needed
        imgui.BeginGroup()
        if was_open and self._selectable:
            flags |= imgui.ImGuiTreeNodeFlags_Selected

        imgui.SetNextItemOpen(was_open, imgui.ImGuiCond_Always)
        self.state.cur.open = was_open
        cdef bint open_and_visible = imgui.TreeNodeEx(self.imgui_label.c_str(),
                                                      flags)
        self.update_current_state()
        if self.state.cur.open and not(was_open):
            SharedBool.set(<SharedBool>self._value, True)
        elif self.state.cur.rendered and was_open and not(open_and_visible): # TODO: unsure
            SharedBool.set(<SharedBool>self._value, False)
            self.state.cur.open = False
            self.propagate_hidden_state_to_children_with_handlers()
        cdef imgui.ImVec2 pos_p
        if open_and_visible:
            if self.last_widgets_child is not None:
                pos_p = imgui.GetCursorScreenPos()
                swap(pos_p, self.context._viewport.parent_pos)
                self.last_widgets_child.draw()
                self.context._viewport.parent_pos = pos_p
            imgui.TreePop()

        imgui.EndGroup()
        # TODO; rect size from group ?
        imgui.PopID()

cdef class CollapsingHeader(uiItem):
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self._closable = False
        self.flags = imgui.ImGuiTreeNodeFlags_None
        self.theme_condition_category = theme_categories.t_collapsingheader

    @property
    def closable(self):
        """
        Writable attribute: Display a close button
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
    def open_on_double_click(self):
        """
        Writable attribute: Need double-click to open node
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick) != 0

    @open_on_double_click.setter
    def open_on_double_click(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick

    @property
    def open_on_arrow(self):
        """
        Writable attribute:  Only open when clicking on the arrow part.
        If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set,
        single-click arrow or double-click all box to open.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_OpenOnArrow) != 0

    @open_on_arrow.setter
    def open_on_arrow(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnArrow
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_OpenOnArrow

    @property
    def leaf(self):
        """
        Writable attribute: No collapsing, no arrow (use as a convenience for leaf nodes).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_Leaf) != 0

    @leaf.setter
    def leaf(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_Leaf
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_Leaf

    @property
    def bullet(self):
        """
        Writable attribute: Display a bullet instead of arrow.
        IMPORTANT: node can still be marked open/close if
        you don't set the _Leaf flag!
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiTreeNodeFlags_Bullet) != 0

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiTreeNodeFlags_Bullet
        if value:
            self.flags |= imgui.ImGuiTreeNodeFlags_Bullet

    cdef bint draw_item(self) noexcept nogil:
        cdef bint was_open = SharedBool.get(<SharedBool>self._value)
        cdef bint closed = False
        cdef imgui.ImGuiTreeNodeFlags flags = self.flags
        if self._closable:
            flags |= imgui.ImGuiTreeNodeFlags_Selected

        imgui.SetNextItemOpen(was_open, imgui.ImGuiCond_Always)
        self.state.cur.open = was_open
        cdef bint open_and_visible = \
            imgui.CollapsingHeader(self.imgui_label.c_str(),
                                   &self._show if self._closable else NULL,
                                   flags)
        if not(self._show):
            self.show_update_requested = True
        self.update_current_state()
        if self.state.cur.open and not(was_open):
            SharedBool.set(<SharedBool>self._value, True)
        elif self.state.cur.rendered and was_open and not(open_and_visible): # TODO: unsure
            SharedBool.set(<SharedBool>self._value, False)
            self.state.cur.open = False
            self.propagate_hidden_state_to_children_with_handlers()
        cdef imgui.ImVec2 pos_p
        if open_and_visible:
            if self.last_widgets_child is not None:
                pos_p = imgui.GetCursorScreenPos()
                swap(pos_p, self.context._viewport.parent_pos)
                self.last_widgets_child.draw()
                self.context._viewport.parent_pos = pos_p
        # TODO: rect_size from group ?
        return not(was_open) and self.state.cur.open

cdef class ChildWindow(uiItem):
    def __cinit__(self):
        self.child_flags = imgui.ImGuiChildFlags_Borders | imgui.ImGuiChildFlags_NavFlattened
        self.window_flags = imgui.ImGuiWindowFlags_NoSavedSettings
        # TODO scrolling
        self.can_have_widget_child = True
        self.can_have_menubar_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_content_region = True
        #self.state.cap.can_be_toggled = True # maybe ?
        self.theme_condition_category = theme_categories.t_child

    @property
    def always_show_vertical_scrollvar(self):
        """
        Writable attribute to tell to always show a vertical scrollbar
        even when the size does not require it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar) else False

    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar

    @property
    def always_show_horizontal_scrollvar(self):
        """
        Writable attribute to tell to always show a horizontal scrollbar
        even when the size does not require it (only if horizontal scrollbar
        are enabled)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar) else False

    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar

    @property
    def no_scrollbar(self):
        """Writable attribute to indicate the window should have no scrollbar
           Does not disable scrolling via mouse or keyboard
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoScrollbar) else False

    @no_scrollbar.setter
    def no_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoScrollbar

    @property
    def horizontal_scrollbar(self):
        """
        Writable attribute to enable having an horizontal scrollbar
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_HorizontalScrollbar) else False

    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_HorizontalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_HorizontalScrollbar

    @property
    def menubar(self):
        """
        Writable attribute to indicate whether the window has a menu bar.

        There will be menubar if either the user has asked for it,
        or there is a menubar child.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.last_menubar_child is not None) or (self.window_flags & imgui.ImGuiWindowFlags_MenuBar) != 0

    @menubar.setter
    def menubar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_MenuBar

    @property
    def no_scroll_with_mouse(self):
        """
        Writable attribute: mouse wheel will be forwarded to the parent
        unless NoScrollbar is also set.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.window_flags & imgui.ImGuiWindowFlags_NavFlattened) != 0

    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoScrollWithMouse
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoScrollWithMouse

    @property
    def flattened_navigation(self):
        """
        Writable attribute: share focus scope, allow gamepad/keyboard
        navigation to cross over parent border to this child or
        between sibling child windows.
        Defaults to True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_NavFlattened) != 0

    @flattened_navigation.setter
    def flattened_navigation(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_NavFlattened
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_NavFlattened

    @property
    def border(self):
        """
        Writable attribute: show an outer border and enable WindowPadding.
        Defaults to True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_Borders) != 0

    @border.setter
    def border(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_Borders
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_Borders

    @property
    def always_auto_resize(self):
        """
        Writable attribute: combined with AutoResizeX/AutoResizeY.
        Always measure size even when child is hidden,
        Note the item will render its children even if hidden.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_AlwaysAutoResize) != 0

    @always_auto_resize.setter
    def always_auto_resize(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_AlwaysAutoResize
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_AlwaysAutoResize

    @property
    def always_use_window_padding(self):
        """
        Writable attribute: pad with style WindowPadding even if
        no border are drawn (no padding by default for non-bordered
        child windows)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_AlwaysUseWindowPadding) != 0

    @always_use_window_padding.setter
    def always_use_window_padding(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_AlwaysUseWindowPadding
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_AlwaysUseWindowPadding

    @property
    def auto_resize_x(self):
        """
        Writable attribute: enable auto-resizing width based on the content
        Set instead width to 0 to use the remaining size of the parent
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_AutoResizeX) != 0

    @auto_resize_x.setter
    def auto_resize_x(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_AutoResizeX
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_AutoResizeX

    @property
    def auto_resize_y(self):
        """
        Writable attribute: enable auto-resizing height based on the content
        Set instead height to 0 to use the remaining size of the parent
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_AutoResizeY) != 0

    @auto_resize_y.setter
    def auto_resize_y(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_AutoResizeY
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_AutoResizeY

    @property
    def frame_style(self):
        """
        Writable attribute: if set, style the child window like a framed item.
        That is: use FrameBg, FrameRounding, FrameBorderSize, FramePadding
        instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_FrameStyle) != 0

    @frame_style.setter
    def frame_style(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_FrameStyle
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_FrameStyle

    @property
    def resizable_x(self):
        """
        Writable attribute: allow resize from right border (layout direction).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_ResizeX) != 0

    @resizable_x.setter
    def resizable_x(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_ResizeX
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_ResizeX

    @property
    def resizable_y(self):
        """
        Writable attribute: allow resize from bottom border (layout direction).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.child_flags & imgui.ImGuiChildFlags_ResizeY) != 0

    @resizable_y.setter
    def resizable_y(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.child_flags &= ~imgui.ImGuiChildFlags_ResizeY
        if value:
            self.child_flags |= imgui.ImGuiChildFlags_ResizeY

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiWindowFlags flags = self.window_flags
        if self.last_menubar_child is not None:
            flags |= imgui.ImGuiWindowFlags_MenuBar
        cdef imgui.ImVec2 pos_p
        cdef imgui.ImVec2 requested_size = self.scaled_requested_size()
        cdef imgui.ImGuiChildFlags child_flags = self.child_flags
        # Else they have no effect
        if child_flags & imgui.ImGuiChildFlags_AutoResizeX:
            requested_size.x = 0
            # incompatible flags
            child_flags &= ~imgui.ImGuiChildFlags_ResizeX
        if child_flags & imgui.ImGuiChildFlags_AutoResizeY:
            requested_size.y = 0
            child_flags &= ~imgui.ImGuiChildFlags_ResizeY
        # Else imgui is not happy
        if child_flags & imgui.ImGuiChildFlags_AlwaysAutoResize:
            if (child_flags & (imgui.ImGuiChildFlags_AutoResizeX | imgui.ImGuiChildFlags_AutoResizeY)) == 0:
                child_flags &= ~imgui.ImGuiChildFlags_AlwaysAutoResize
        if imgui.BeginChild(self.imgui_label.c_str(),
                            requested_size,
                            child_flags,
                            flags):
            self.state.cur.content_region_size = imgui.GetContentRegionAvail()
            pos_p = imgui.GetCursorScreenPos()
            # TODO: since Child windows are ... windows, should we update window_pos ?
            swap(pos_p, self.context._viewport.parent_pos)
            if self.last_widgets_child is not None:
                self.last_widgets_child.draw()
            if self.last_menubar_child is not None:
                self.last_menubar_child.draw()
            self.context._viewport.parent_pos = pos_p
            self.state.cur.rendered = True
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            self.state.cur.rect_size = imgui.GetWindowSize()
            # TODO scrolling
        else:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
        imgui.EndChild()
        return False # maybe True when visible ?

cdef class ColorButton(uiItem):
    def __cinit__(self):
        self.flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self.theme_condition_category = theme_categories.t_colorbutton
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Writable attribute: ignore Alpha component (will only read 3 components from the input pointer)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_tooltip(self):
        """
        Writable attribute: disable default tooltip when hovering the preview
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_drag_drop(self):
        """
        Writable attribute: disable drag and drop source
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoDragDrop) != 0

    @no_drag_drop.setter
    def no_drag_drop(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoDragDrop
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoDragDrop

    @property
    def no_border(self):
        """
        Writable attribute: disable the default border
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoBorder) != 0

    @no_border.setter
    def no_border(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoBorder
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoBorder

    # TODO: there are more options, which can be user toggled.

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        cdef imgui.ImVec4 col = SharedColor.getF4(<SharedColor>self._value)
        activated = imgui.ColorButton(self.imgui_label.c_str(),
                                      col,
                                      self.flags,
                                      self.scaled_requested_size())
        self.update_current_state()
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated


cdef class ColorEdit(uiItem):
    def __cinit__(self):
        self.flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self.theme_condition_category = theme_categories.t_coloredit
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Writable attribute: ignore Alpha component (will only read 3 components from the input pointer)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_picker(self):
        """
        Writable attribute: disable picker when clicking on color square.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoPicker) != 0

    @no_picker.setter
    def no_picker(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoPicker
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoPicker

    @property
    def no_options(self):
        """
        Writable attribute: disable toggling options menu when right-clicking on inputs/small preview.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoOptions) != 0

    @no_options.setter
    def no_options(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoOptions
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoOptions

    @property
    def no_small_preview(self):
        """
        Writable attribute: disable color square preview next to the inputs. (e.g. to show only the inputs)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoSmallPreview) != 0

    @no_small_preview.setter
    def no_small_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoSmallPreview
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoSmallPreview

    @property
    def no_inputs(self):
        """
        Writable attribute: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoInputs
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoInputs

    @property
    def no_tooltip(self):
        """
        Writable attribute: disable default tooltip when hovering the preview
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_label(self):
        """
        Writable attribute: disable display of inline text label (the label is still forwarded to the tooltip and picker).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoLabel
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoLabel

    @property
    def no_drag_drop(self):
        """
        Writable attribute: disable drag and drop target
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoDragDrop) != 0

    @no_drag_drop.setter
    def no_drag_drop(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoDragDrop
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoDragDrop

    # TODO: there are more options, which can be user toggled.

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        cdef imgui.ImVec4 col = SharedColor.getF4(<SharedColor>self._value)
        cdef float[4] color = [col.x, col.y, col.z, col.w]
        activated = imgui.ColorEdit4(self.imgui_label.c_str(),
                                      color,
                                      self.flags)
        self.update_current_state()
        col = imgui.ImVec4(color[0], color[1], color[2], color[3])
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated


cdef class ColorPicker(uiItem):
    def __cinit__(self):
        self.flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self.theme_condition_category = theme_categories.t_colorpicker
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Writable attribute: ignore Alpha component (will only read 3 components from the input pointer)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_small_preview(self):
        """
        Writable attribute: disable color square preview next to the inputs. (e.g. to show only the inputs)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoSmallPreview) != 0

    @no_small_preview.setter
    def no_small_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoSmallPreview
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoSmallPreview

    @property
    def no_inputs(self):
        """
        Writable attribute: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoInputs
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoInputs

    @property
    def no_tooltip(self):
        """
        Writable attribute: disable default tooltip when hovering the preview
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_label(self):
        """
        Writable attribute: disable display of inline text label (the label is still forwarded to the tooltip and picker).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoLabel
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoLabel

    @property
    def no_side_preview(self):
        """
        Writable attribute: disable bigger color preview on right side of the picker, use small color square preview instead.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & imgui.ImGuiColorEditFlags_NoSidePreview) != 0

    @no_side_preview.setter
    def no_side_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~imgui.ImGuiColorEditFlags_NoSidePreview
        if value:
            self.flags |= imgui.ImGuiColorEditFlags_NoSidePreview

    # TODO: there are more options, which can be user toggled.

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        cdef imgui.ImVec4 col = SharedColor.getF4(<SharedColor>self._value)
        cdef float[4] color = [col.x, col.y, col.z, col.w]
        activated = imgui.ColorPicker4(self.imgui_label.c_str(),
                                       color,
                                       self.flags,
                                       NULL) # ref_col ??
        self.update_current_state()
        col = imgui.ImVec4(color[0], color[1], color[2], color[3])
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated

"""
Complex ui items
"""

cdef class TimeWatcher(uiItem):
    """
    A placeholder uiItem that doesn't draw
    or have any impact on rendering.
    This item calls the callback with times in ns.
    These times can be compared with the times in the metrics
    that can be obtained from the viewport in order to
    precisely figure out the time spent rendering specific items.

    The first time corresponds to the time when the next sibling
    requested this sibling to render. At this step, no sibling
    of this item (previous or next) have rendered anything.

    The second time corresponds to the time when the previous
    siblings have finished rendering and it is now the turn
    of this item to render. Next items have not rendered yet.

    The third time corresponds to the time when viewport
    started rendering items for this frame. It is a duplicate of
    context.viewport.metrics.last_t_before_rendering. It is
    given to prevent the user from having to keep track of the
    viewport metrics (since the callback might be called
    after or before the viewport updated its metrics for this
    frame or another one).

    The fourth number corresponds to the frame count
    at the the time the callback was issued.

    Note the times relate to CPU time (checking states, preparing
    GPU data, etc), not to GPU rendering time.
    """
    def __cinit__(self):
        self.state.cap.has_position = False
        self.state.cap.has_rect_size = False
        self.can_be_disabled = False

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef long long time_start = ctime.monotonic_ns()
        if self._prev_sibling is not None:
            (<uiItem>self._prev_sibling).draw()
        cdef long long time_end = ctime.monotonic_ns()
        cdef int i
        if not(self._callbacks.empty()):
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg3long1int(<Callback>self._callbacks[i],
                                                         self,
                                                         self,
                                                         time_start,
                                                         time_end,
                                                         self.context._viewport.last_t_before_rendering,
                                                         self.context._viewport.frame_count)
        

cdef class Window(uiItem):
    def __cinit__(self):
        self.window_flags = imgui.ImGuiWindowFlags_None
        self.main_window = False
        self.modal = False
        self.popup = False
        self.has_close_button = True
        self.state.cur.open = True
        self.collapse_update_requested = False
        self.no_open_over_existing_popup = True
        self.on_close_callback = None
        self.min_size = imgui.ImVec2(100., 100.)
        self.max_size = imgui.ImVec2(30000., 30000.)
        self.theme_condition_category = theme_categories.t_window
        self.scroll_x = 0. # TODO
        self.scroll_y = 0.
        self.scroll_x_update_requested = False
        self.scroll_y_update_requested = False
        # Read-only states
        self.scroll_max_x = 0.
        self.scroll_max_y = 0.

        # backup states when we set/unset primary
        #self.backup_window_flags = imgui.ImGuiWindowFlags_None
        #self.backup_pos = self.position
        #self.backup_rect_size = self.state.cur.rect_size
        # Type info
        self.can_have_widget_child = True
        #self.can_have_drawing_child = True
        self.can_have_menubar_child = True
        self.can_have_payload_child = True
        self.element_child_category = child_type.cat_window
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_focused = True
        self.state.cap.has_content_region = True

    @property
    def no_title_bar(self):
        """Writable attribute to disable the title-bar"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoTitleBar) else False

    @no_title_bar.setter
    def no_title_bar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoTitleBar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoTitleBar

    @property
    def no_resize(self):
        """Writable attribute to block resizing"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoResize) else False

    @no_resize.setter
    def no_resize(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoResize
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoResize

    @property
    def no_move(self):
        """Writable attribute the window to be move with interactions"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoMove) else False

    @no_move.setter
    def no_move(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoMove
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoMove

    @property
    def no_scrollbar(self):
        """Writable attribute to indicate the window should have no scrollbar
           Does not disable scrolling via mouse or keyboard
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoScrollbar) else False

    @no_scrollbar.setter
    def no_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoScrollbar
    
    @property
    def no_scroll_with_mouse(self):
        """Writable attribute to indicate the mouse wheel
           should have no effect on scrolling of this window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoScrollWithMouse) else False

    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoScrollWithMouse
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoScrollWithMouse

    @property
    def no_collapse(self):
        """Writable attribute to disable user collapsing window by double-clicking on it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoCollapse) else False

    @no_collapse.setter
    def no_collapse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoCollapse
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoCollapse

    @property
    def autosize(self):
        """Writable attribute to tell the window should
           automatically resize to fit its content
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysAutoResize) else False

    @autosize.setter
    def autosize(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysAutoResize
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysAutoResize

    @property
    def no_background(self):
        """
        Writable attribute to disable drawing background
        color and outside border
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoBackground) else False

    @no_background.setter
    def no_background(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoBackground
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoBackground

    @property
    def no_saved_settings(self):
        """
        Writable attribute to never load/save settings in .ini file
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoSavedSettings) else False

    @no_saved_settings.setter
    def no_saved_settings(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoSavedSettings
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoSavedSettings

    @property
    def no_mouse_inputs(self):
        """
        Writable attribute to disable mouse input event catching of the window.
        Events such as clicked, hovering, etc will be passed to items behind the
        window.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoMouseInputs) else False

    @no_mouse_inputs.setter
    def no_mouse_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoMouseInputs
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoMouseInputs

    @property
    def no_keyboard_inputs(self):
        """
        Writable attribute to disable keyboard manipulation (scroll).
        The window will not take focus of the keyboard.
        Does not affect items inside the window.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoNav) else False

    @no_keyboard_inputs.setter
    def no_keyboard_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoNav
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoNav

    @property
    def menubar(self):
        """
        Writable attribute to indicate whether the window has a menu bar.

        There will be menubar if either the user has asked for it,
        or there is a menubar child.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.last_menubar_child is not None) or (self.window_flags & imgui.ImGuiWindowFlags_MenuBar) != 0

    @menubar.setter
    def menubar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_MenuBar

    @property
    def horizontal_scrollbar(self):
        """
        Writable attribute to enable having an horizontal scrollbar
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_HorizontalScrollbar) else False

    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_HorizontalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_HorizontalScrollbar

    @property
    def no_focus_on_appearing(self):
        """
        Writable attribute to indicate when the windows moves from
        an un-shown to a shown item shouldn't be made automatically
        focused
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoFocusOnAppearing) else False

    @no_focus_on_appearing.setter
    def no_focus_on_appearing(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoFocusOnAppearing
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoFocusOnAppearing

    @property
    def no_bring_to_front_on_focus(self):
        """
        Writable attribute to indicate when the window takes focus (click on it, etc)
        it shouldn't be shown in front of other windows
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoBringToFrontOnFocus) else False

    @no_bring_to_front_on_focus.setter
    def no_bring_to_front_on_focus(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoBringToFrontOnFocus
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoBringToFrontOnFocus

    @property
    def always_show_vertical_scrollvar(self):
        """
        Writable attribute to tell to always show a vertical scrollbar
        even when the size does not require it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar) else False

    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar

    @property
    def always_show_horizontal_scrollvar(self):
        """
        Writable attribute to tell to always show a horizontal scrollbar
        even when the size does not require it (only if horizontal scrollbar
        are enabled)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar) else False

    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar

    @property
    def unsaved_document(self):
        """
        Writable attribute to display a dot next to the title, as if the window
        contains unsaved changes.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_UnsavedDocument) else False

    @unsaved_document.setter
    def unsaved_document(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_UnsavedDocument
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_UnsavedDocument

    @property
    def disallow_docking(self):
        """
        Writable attribute to disable docking for the window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoDocking) else False

    @disallow_docking.setter
    def disallow_docking(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoDocking
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoDocking

    @property
    def no_open_over_existing_popup(self):
        """
        Writable attribute for modal and popup windows to prevent them from
        showing if there is already an existing popup/modal window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.no_open_over_existing_popup

    @no_open_over_existing_popup.setter
    def no_open_over_existing_popup(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.no_open_over_existing_popup = value

    @property
    def modal(self):
        """
        Writable attribute to indicate the window is a modal window.
        Modal windows are similar to popup windows, but they have a close
        button and are not closed by clicking outside.
        Clicking has no effect of items outside the modal window until it is closed.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.modal

    @modal.setter
    def modal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.modal = value

    @property
    def popup(self):
        """
        Writable attribute to indicate the window is a popup window.
        Popup windows are centered (unless a pos is set), do not have a
        close button, and are closed when they lose focus (clicking outside the
        window).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.popup

    @popup.setter
    def popup(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.popup = value

    @property
    def has_close_button(self):
        """
        Writable attribute to indicate the window has a close button.
        Has effect only for normal and modal windows.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.has_close_button and not(self.popup)

    @has_close_button.setter
    def has_close_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.has_close_button = value

    @property
    def collapsed(self):
        """
        Writable attribute to collapse (~minimize) or uncollapse the window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.state.cur.open)

    @collapsed.setter
    def collapsed(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.cur.open = not(value)
        self.collapse_update_requested = True

    @property
    def on_close(self):
        """
        Callback to call when the window is closed.
        Note closing the window does not destroy or unattach the item.
        Instead it is switched to a show=False state.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.on_close_callback

    @on_close.setter
    def on_close(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.on_close_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def primary(self):
        """
        Writable attribute: Indicate if the window is the primary window.
        There is maximum one primary window. The primary window covers the whole
        viewport and can be used to draw on the background.
        It is equivalent to setting:
        no_bring_to_front_on_focus
        no_saved_settings
        no_resize
        no_collapse
        no_title_bar
        and running item.focused = True on all the other windows
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.main_window

    @primary.setter
    def primary(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        # If window has a parent, it is the viewport
        lock_gil_friendly(m, self.context._viewport.mutex)
        lock_gil_friendly(m2, self.mutex)

        if self._parent is None:
            raise ValueError("Window must be attached before becoming primary")
        if self.main_window == value:
            return # Nothing to do
        self.main_window = value
        if value:
            # backup previous state
            self.backup_window_flags = self.window_flags
            self.backup_pos = self.state.cur.pos_to_viewport
            self.backup_rect_size = self.requested_size # We should backup self.state.cur.rect_size, but the we have a dpi scaling issue
            # Make primary
            self.window_flags = \
                imgui.ImGuiWindowFlags_NoBringToFrontOnFocus | \
                imgui.ImGuiWindowFlags_NoSavedSettings | \
			    imgui.ImGuiWindowFlags_NoResize | \
                imgui.ImGuiWindowFlags_NoCollapse | \
                imgui.ImGuiWindowFlags_NoTitleBar
            self.state.cur.pos_to_viewport.x = 0
            self.state.cur.pos_to_viewport.y = 0
            self.requested_size.x = 0
            self.requested_size.y = 0
            self.pos_update_requested = True
            self.size_update_requested = True
        else:
            # Restore previous state
            self.window_flags = self.backup_window_flags
            self.state.cur.pos_to_viewport = self.backup_pos
            self.requested_size = self.backup_rect_size
            # Tell imgui to update the window shape
            self.pos_update_requested = True
            self.size_update_requested = True

        # Re-tell imgui the window hierarchy
        cdef Window w = self.context._viewport.last_window_child
        cdef Window next = None
        while w is not None:
            lock_gil_friendly(m3, w.mutex)
            w.state.cur.focused = True
            w.focus_update_requested = True
            next = w._prev_sibling
            # TODO: previous code did restore previous states on each window. Figure out why
            w = next

    @property
    def min_size(self):
        """
        Writable attribute to indicate the minimum window size
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.min_size)

    @min_size.setter
    def min_size(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.min_size.x = max(1, value[0])
        self.min_size.y = max(1, value[1])

    @property
    def max_size(self):
        """
        Writable attribute to indicate the maximum window size
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self.max_size)

    @max_size.setter
    def max_size(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.max_size.x = max(1, value[0])
        self.max_size.y = max(1, value[1])

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<uiItem>self._prev_sibling).draw()

        if not(self._show):
            if self.show_update_requested:
                self.set_previous_states()
                self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
                self.run_handlers()
                self.show_update_requested = False
            return

        self.set_previous_states()

        if self.focus_update_requested:
            if self.state.cur.focused:
                imgui.SetNextWindowFocus()
            self.focus_update_requested = False

        if self.pos_update_requested:
            imgui.SetNextWindowPos(self.state.cur.pos_to_viewport, <imgui.ImGuiCond>0)
            self.pos_update_requested = False

        if self.size_update_requested:
            imgui.SetNextWindowSize(self.scaled_requested_size(),
                                    <imgui.ImGuiCond>0)
            self.size_update_requested = False

        if self.collapse_update_requested:
            imgui.SetNextWindowCollapsed(not(self.state.cur.open), <imgui.ImGuiCond>0)
            self.collapse_update_requested = False

        imgui.SetNextWindowSizeConstraints(self.min_size, self.max_size)

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
            imgui.SetNextWindowSize(imgui.ImVec2(<float>self.context._viewport.viewport.actualWidth,
                                           <float>self.context._viewport.viewport.actualHeight),
                                    <imgui.ImGuiCond>0)

        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        self.context._viewport.push_pending_theme_actions(
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
        cdef imgui.ImGuiWindowFlags flags = self.window_flags
        if self.last_menubar_child is not None:
            flags |= imgui.ImGuiWindowFlags_MenuBar

        if self.modal:
            visible = imgui.BeginPopupModal(self.imgui_label.c_str(),
                                            &self._show if self.has_close_button else <bool*>NULL,
                                            flags)
        elif self.popup:
            visible = imgui.BeginPopup(self.imgui_label.c_str(), flags)
        else:
            visible = imgui.Begin(self.imgui_label.c_str(),
                                  &self._show if self.has_close_button else <bool*>NULL,
                                  flags)

        # not(visible) means either closed or clipped
        # if has_close_button, show can be switched from True to False if closed

        if visible:
            # Retrieve the full region size before the cursor is moved.
            self.state.cur.content_region_size = imgui.GetContentRegionAvail()
            # Draw the window content
            self.context._viewport.window_pos = imgui.GetCursorScreenPos()
            self.context._viewport.parent_pos = self.context._viewport.window_pos # should we restore after ? TODO

            #if self.last_0_child is not None:
            #    self.last_0_child.draw(this_drawlist, startx, starty)

            if self.last_widgets_child is not None:
                self.last_widgets_child.draw()
            # TODO if self.children_widgets[i].tracked and show:
            #    imgui.SetScrollHereY(self.children_widgets[i].trackOffset)

            # Seems redundant with DrawInWindow
            # DrawInWindow is more powerful
            #self.context._viewport.in_plot = False
            #if self.last_drawings_child is not None:
            #    self.last_drawings_child.draw(imgui.GetWindowDrawList())

            if self.last_menubar_child is not None:
                self.last_menubar_child.draw()

        cdef imgui.ImVec2 rect_size
        if visible:
            # Set current states
            self.state.cur.rendered = True
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            rect_size = imgui.GetWindowSize()
            self.state.cur.rect_size = rect_size
            self.last_frame_update = self.context._viewport.frame_count # TODO remove ?
            self.state.cur.pos_to_viewport = imgui.GetWindowPos()
            self.state.cur.pos_to_parent = self.state.cur.pos_to_viewport
        else:
            # Window is hidden or closed
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()

        self.state.cur.open = not(imgui.IsWindowCollapsed())
        self.scroll_x = imgui.GetScrollX()
        self.scroll_y = imgui.GetScrollY()


        # Post draw

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
        self.context._viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        cdef bint closed = not(self._show) or (not(visible) and (self.modal or self.popup))
        if closed:
            self._show = False
            self.context.queue_callback_noarg(self.on_close_callback,
                                              self,
                                              self)
        self.show_update_requested = False

        self.run_handlers()


"""
Textures
"""



cdef class Texture(baseItem):
    def __cinit__(self):
        self.hint_dynamic = False
        self.dynamic = False
        self.allocated_texture = NULL
        self._width = 0
        self._height = 0
        self._num_chans = 0
        self._buffer_type = 0
        self.filtering_mode = 0

    def __delalloc__(self):
        cdef unique_lock[recursive_mutex] imgui_m
        # Note: textures might be referenced during imgui rendering.
        # Thus we must wait there is no rendering to free a texture.
        if self.allocated_texture != NULL:
            lock_gil_friendly(imgui_m, self.context.imgui_mutex)
            mvMakeUploadContextCurrent(dereference(self.context._viewport.viewport))
            mvFreeTexture(self.allocated_texture)
            mvReleaseUploadContext(dereference(self.context._viewport.viewport))

    def configure(self, *args, **kwargs):
        if len(args) == 1:
            self.set_content(np.ascontiguousarray(args[0]))
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to Texture. Expected content")
        self.filtering_mode = 1 if kwargs.pop("nearest_neighbor_upsampling", False) else 0
        return super().configure(**kwargs)

    @property
    def hint_dynamic(self):
        """
        Hint for texture placement that
        the texture will be updated very
        frequently.
        """
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
        """
        Whether to use nearest neighbor interpolation
        instead of bilinear interpolation when upscaling
        the texture. Must be set before set_value.
        """
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
        """ Width of the current texture content """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._width
    @property
    def height(self):
        """ Height of the current texture content """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._height
    @property
    def num_chans(self):
        """ Number of channels of the current texture content """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_chans

    def set_value(self, value):
        """
        Pass an array as texture data.
        The currently native formats are:
        - data type: uint8 or float32.
            Anything else will be converted to float32
            float32 data must be normalized between 0 and 1.
        - number of channels: 1 (R), 2 (RG), 3 (RGB), 4 (RGBA)

        In the case of single channel textures, during rendering, R is
        duplicated on G and B, thus the texture is displayed as gray,
        not red.

        If set_value is called on a texture which already
        has content, the previous allocation will be reused
        if the size, type and number of channels is identical.

        The data is uploaded right away during set_value,
        thus the call is not instantaneous.
        The data can be discarded after set_value.

        If you change the data of a texture, you don't
        need to bind it again to the objects it is
        bound. The objects will automatically take
        the updated texture.
        """
        self.set_content(np.asarray(value))

    cdef void set_content(self, cnp.ndarray content): # TODO: deadlock when held by external lock
        # The write mutex is to ensure order of processing of set_content
        # as we might release the item mutex to wait for imgui to render
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.write_mutex)
        lock_gil_friendly(m2, self.mutex)
        cdef int ndim = cnp.PyArray_NDIM(content)
        if ndim > 3 or ndim == 0:
            raise ValueError("Invalid number of texture dimensions")
        if self.readonly: # set for fonts
            raise ValueError("Target texture is read-only")
        cdef int height = 1
        cdef int width = 1
        cdef int num_chans = 1
        cdef int stride = 1

        if ndim >= 1:
            height = cnp.PyArray_DIM(content, 0)
        if ndim >= 2:
            width = cnp.PyArray_DIM(content, 1)
        if ndim >= 3:
            num_chans = cnp.PyArray_DIM(content, 2)
        if width * height * num_chans == 0:
            raise ValueError("Cannot set empty texture")

        # TODO: there must be a faster test
        if not(content.dtype == np.float32 or content.dtype == np.uint8):
            content = np.asarray(content, dtype=np.float32)

        # rows must be contiguous
        if ndim >= 2 and cnp.PyArray_STRIDE(content, 1) != (num_chans * (1 if content.dtype == np.uint8 else 4)):
            content = np.ascontiguousarray(content, dtype=content.dtype)

        stride = cnp.PyArray_STRIDE(content, 0)


        cdef bint reuse = self.allocated_texture != NULL
        cdef bint success
        cdef unsigned buffer_type = 1 if content.dtype == np.uint8 else 0
        reuse = reuse and not(self._width != width or self._height != height or self._num_chans != num_chans or self._buffer_type != buffer_type)

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
                mvMakeUploadContextCurrent(dereference(self.context._viewport.viewport))
                mvFreeTexture(self.allocated_texture)
                self.allocated_texture = NULL
                self.context.imgui_mutex.unlock()
            else:
                m2.unlock()
                mvMakeUploadContextCurrent(dereference(self.context._viewport.viewport))
                m2.lock()

            # Note we don't need the imgui mutex to create or upload textures.
            # In the case of GL, as only one thread can access GL data at a single
            # time, MakeUploadContextCurrent and ReleaseUploadContext enable
            # to upload/create textures from various threads. They hold a mutex.
            # That mutex is held in the relevant parts of frame rendering.

            self._width = width
            self._height = height
            self._num_chans = num_chans
            self._buffer_type = buffer_type

            if not(reuse):
                self.dynamic = self._hint_dynamic
                self.allocated_texture = mvAllocateTexture(width, height, num_chans, self.dynamic, buffer_type, self.filtering_mode)

            success = self.allocated_texture != NULL
            if success:
                if self.dynamic:
                    success = mvUpdateDynamicTexture(self.allocated_texture,
                                                     width,
                                                     height,
                                                     num_chans,
                                                     buffer_type,
                                                     cnp.PyArray_DATA(content),
                                                     stride)
                else:
                    success = mvUpdateStaticTexture(self.allocated_texture,
                                                    width,
                                                    height,
                                                    num_chans,
                                                    buffer_type,
                                                    cnp.PyArray_DATA(content),
                                                    stride)
            mvReleaseUploadContext(dereference(self.context._viewport.viewport))
            m.unlock()
            m2.unlock() # Release before we get gil again
        if not(success):
            raise MemoryError("Failed to upload target texture")

def get_system_fonts():
    """
    Returns a list of available fonts
    """
    fonts_filename = []
    try:
        from find_system_fonts_filename import get_system_fonts_filename, FindSystemFontsFilenameException
        fonts_filename = get_system_fonts_filename()
    except FindSystemFontsFilenameException:
        # Deal with the exception
        pass
    return fonts_filename

cdef class Font(baseItem):
    def __cinit__(self, context, *args, **kwargs):
        self.can_have_sibling = False
        self.font = NULL
        self.container = None
        self._scale = 1.
        self.dpi_scaling = True

    @property
    def texture(self):
        return self.container

    @property
    def size(self):
        """Readonly attribute: native height of characters"""
        if self.font == NULL:
            raise ValueError("Uninitialized font")
        return self.font.FontSize

    @property
    def scale(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        """Writable attribute: multiplicative factor to scale the font when used"""
        return self._scale

    @scale.setter
    def scale(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value <= 0.:
            raise ValueError(f"Invalid scale {value}")
        self._scale = value

    @property
    def no_scaling(self):
        """
        boolean. Defaults to False.
        If set, disables the automated scaling to the dpi
        scale value for this font.
        The manual user-set scale is still applied.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.dpi_scaling = not(value)

    cdef void push(self) noexcept nogil:
        if self.font == NULL:
            return
        self.mutex.lock()
        self.font.Scale = \
            (self.context._viewport.global_scale if self.dpi_scaling else 1.) * self._scale
        imgui.PushFont(self.font)

    cdef void pop(self) noexcept nogil:
        if self.font == NULL:
            return
        imgui.PopFont()
        self.mutex.unlock()

cdef class FontTexture(baseItem):
    """
    Packs one or several fonts into
    a texture for internal use by ImGui.
    """
    def __cinit__(self, context, *args, **kwargs):
        self._built = False
        self.can_have_sibling = False
        self.atlas = imgui.ImFontAtlas()
        self._texture = Texture(context)
        self.fonts_files = []
        self.fonts = []

    def __delalloc__(self):
        self.atlas.Clear() # Unsure if needed

    def add_font_file(self,
                      str path,
                      float size=13.,
                      int index_in_file=0,
                      float density_scale=2.,
                      bint align_to_pixel=False):
        """
        Prepare the target font file to be added to the FontTexture

        path: path to the input font file (ttf, otf, etc).
        size: Target pixel size at which the font will be rendered by default.
        index_in_file: index of the target font in the font file.
        density_scale: rasterizer oversampling to better render when
            the font scale is not 1.
        align_to_pixel: For sharp fonts, will prevent blur by
            aligning font rendering to the pixel. The spacing
            between characters might appear slightly odd as
            a result, so don't enable when not needed.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._built:
            raise ValueError("Cannot add Font to built FontTexture")
        if not(os.path.exists(path)):
            raise ValueError(f"File {path} does not exist")
        if size <= 0. or density_scale <= 0.:
            raise ValueError("Invalid texture size")
        cdef imgui.ImFontConfig config = imgui.ImFontConfig()
        # Unused with freetype
        #config.OversampleH = 3 if subpixel else 1
        #config.OversampleV = 3 if subpixel else 1
        #if not(subpixel):
        config.PixelSnapH = align_to_pixel
        with open(path, 'rb') as fp:
            font_data = fp.read()
        cdef const unsigned char[:] font_data_u8 = font_data
        config.SizePixels = size
        config.RasterizerDensity = density_scale
        config.FontNo = index_in_file
        config.FontDataOwnedByAtlas = False
        cdef imgui.ImFont *font = \
            self.atlas.AddFontFromMemoryTTF(<void*>&font_data_u8[0],
                                            font_data_u8.shape[0],
                                            size,
                                            &config,
                                            NULL)
        if font == NULL:
            raise ValueError(f"Failed to load target Font file {path}")
        cdef Font font_object = Font(self.context)
        font_object.container = self
        font_object.font = font
        self.fonts.append(font_object)

    @property
    def built(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._built

    @property
    def texture(self):
        """
        Readonly texture containing the font data.
        build() must be called first
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._built):
            raise ValueError("Texture not yet built")
        return self._texture

    def __len__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._built):
            return 0
        return <int>self.atlas.Fonts.size()

    def __getitem__(self, index):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._built):
            raise ValueError("Texture not yet built")
        if index < 0 or index >= <int>self.atlas.Fonts.size():
            raise IndexError("Outside range")
        return self.fonts[index]

    def build(self):
        """
        Packs all the fonts appended with add_font_file
        into a readonly texture. 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._built:
            return
        if self.atlas.Fonts.Size == 0:
            raise ValueError("You must add fonts first")
        # build
        if not(self.atlas.Build()):
            raise RuntimeError("Failed to build target texture data")
        # Retrieve the target buffer
        cdef unsigned char *data = NULL
        cdef int width, height, bpp
        if self.atlas.TexPixelsUseColors:
            self.atlas.GetTexDataAsRGBA32(&data, &width, &height, &bpp)
        else:
            self.atlas.GetTexDataAsAlpha8(&data, &width, &height, &bpp)

        # Upload texture
        cdef cython.view.array data_array = cython.view.array(shape=(height, width, bpp), itemsize=1, format='B', mode='c', allocate_buffer=False)
        data_array.data = <char*>data
        self._texture.filtering_mode = 2 # 111A bilinear
        self._texture.set_value(np.asarray(data_array, dtype=np.uint8))
        assert(self._texture.allocated_texture != NULL)
        self._texture.readonly = True
        self.atlas.SetTexID(<imgui.ImTextureID>self._texture.allocated_texture)

        # Release temporary CPU memory
        self.atlas.ClearInputData()
        self._built = True


cdef class baseTheme(baseItem):
    """
    Base theme element. Contains a set of theme elements
    to apply for a given category (color, style)/(imgui/implot/imnode)
    """
    def __cinit__(self):
        self.element_child_category = child_type.cat_theme
        self.can_have_sibling = True
        self.enabled = True
    def configure(self, **kwargs):
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

"""
Plots
"""

cdef extern from * nogil:
    """
    ImPlotAxisFlags GetAxisConfig(int axis)
    {
        return ImPlot::GetCurrentContext()->CurrentPlot->Axes[axis].Flags;
    }
    ImPlotLocation GetLegendConfig(ImPlotLegendFlags &flags)
    {
        flags = ImPlot::GetCurrentContext()->CurrentPlot->Items.Legend.Flags;
        return ImPlot::GetCurrentContext()->CurrentPlot->Items.Legend.Location;
    }
    ImPlotFlags GetPlotConfig()
    {
        return ImPlot::GetCurrentContext()->CurrentPlot->Flags;
    }
    bool IsItemHidden(const char* label_id)
    {
        ImPlotItem* item = ImPlot::GetItem(label_id);
        return item != nullptr && !item->Show;
    }
    """
    implot.ImPlotAxisFlags GetAxisConfig(int)
    implot.ImPlotLocation GetLegendConfig(implot.ImPlotLegendFlags&)
    implot.ImPlotFlags GetPlotConfig()
    bint IsItemHidden(const char*)

# BaseItem that has has no parent/child nor sibling
cdef class PlotAxisConfig(baseItem):
    def __cinit__(self):
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_clicked = True
        self.p_state = &self.state
        self._enabled = True
        self._scale = AxisScale.linear
        self._tick_format = b""
        self.flags = 0
        self._min = 0
        self._max = 1
        self.to_fit = True
        self.dirty_minmax = False
        self._constraint_min = -INFINITY
        self._constraint_max = INFINITY
        self._zoom_min = 0
        self._zoom_max = INFINITY

    @property
    def enabled(self):
        """
        Whether elements using this axis should
        be drawn.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value

    @property
    def scale(self):
        """
        Current AxisScale.
        Default is AxisScale.linear
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale

    @scale.setter
    def scale(self, AxisScale value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value == AxisScale.linear or \
           value == AxisScale.time or \
           value == AxisScale.log10 or\
           value == AxisScale.symlog:
            self._scale = value
        else:
            raise ValueError("Invalid scale. Expecting an AxisScale")

    @property
    def min(self):
        """
        Current minimum of the range displayed.
        Do not set max <= min. Set invert to change
        the axis order.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min.setter
    def min(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value
        self.dirty_minmax = True

    @property
    def max(self):
        """
        Current maximum of the range displayed.
        Do not set max <= min. Set invert to change
        the axis order.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max.setter
    def max(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value
        self.dirty_minmax = True

    @property
    def constraint_min(self):
        """
        Constraint on the minimum value
        of min.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._constraint_min

    @constraint_min.setter
    def constraint_min(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._constraint_min = value

    @property
    def constraint_max(self):
        """
        Constraint on the maximum value
        of max.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._constraint_max

    @constraint_max.setter
    def constraint_max(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._constraint_max = value

    @property
    def zoom_min(self):
        """
        Constraint on the minimum value
        of the zoom
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._zoom_min

    @zoom_min.setter
    def zoom_min(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._zoom_min = value

    @property
    def zoom_max(self):
        """
        Constraint on the maximum value
        of the zoom
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._zoom_max

    @zoom_max.setter
    def zoom_max(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._zoom_max = value

    @property
    def no_label(self):
        """
        Writable attribute to not render the axis label
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoLabel
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoLabel

    @property
    def no_gridlines(self):
        """
        Writable attribute to not render grid lines
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoGridLines) != 0

    @no_gridlines.setter
    def no_gridlines(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoGridLines
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoGridLines

    @property
    def no_tick_marks(self):
        """
        Writable attribute to not render tick marks
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoTickMarks) != 0

    @no_tick_marks.setter
    def no_tick_marks(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoTickMarks
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoTickMarks

    @property
    def no_tick_labels(self):
        """
        Writable attribute to not render tick labels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoTickLabels) != 0

    @no_tick_labels.setter
    def no_tick_labels(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoTickLabels
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoTickLabels

    @property
    def no_initial_fit(self):
        """
        Writable attribute to disable fitting the extent
        of the axis to the data on the first frame.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoInitialFit) != 0

    @no_initial_fit.setter
    def no_initial_fit(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoInitialFit
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoInitialFit
            self.to_fit = False

    @property
    def no_menus(self):
        """
        Writable attribute to prevent right-click to
        open context menus.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoMenus) != 0

    @no_menus.setter
    def no_menus(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoMenus
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoMenus

    @property
    def no_side_switch(self):
        """
        Writable attribute to prevent the user from switching
        the axis by dragging it.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoSideSwitch) != 0

    @no_side_switch.setter
    def no_side_switch(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoSideSwitch
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoSideSwitch

    @property
    def no_highlight(self):
        """
        Writable attribute to not highlight the axis background
        when hovered or held
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_NoHighlight) != 0

    @no_highlight.setter
    def no_highlight(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_NoHighlight
        if value:
            self.flags |= implot.ImPlotAxisFlags_NoHighlight

    @property
    def opposite(self):
        """
        Writable attribute to render ticks and labels on
        the opposite side.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_Opposite) != 0

    @opposite.setter
    def opposite(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_Opposite
        if value:
            self.flags |= implot.ImPlotAxisFlags_Opposite

    @property
    def foreground_grid(self):
        """
        Writable attribute to render gridlines on top of
        the data rather than behind.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_Foreground) != 0

    @foreground_grid.setter
    def foreground_grid(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_Foreground
        if value:
            self.flags |= implot.ImPlotAxisFlags_Foreground

    @property
    def invert(self):
        """
        Writable attribute to invert the values of the axis
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_Invert) != 0

    @invert.setter
    def invert(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_Invert
        if value:
            self.flags |= implot.ImPlotAxisFlags_Invert

    @property
    def auto_fit(self):
        """
        Writable attribute to force the axis to fit its range
        to the data every frame.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_AutoFit) != 0

    @auto_fit.setter
    def auto_fit(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_AutoFit
        if value:
            self.flags |= implot.ImPlotAxisFlags_AutoFit

    @property
    def restrict_fit_to_range(self):
        """
        Writable attribute to ignore points that are outside
        the visible region of the opposite axis when fitting
        this axis.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_RangeFit) != 0

    @restrict_fit_to_range.setter
    def restrict_fit_to_range(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_RangeFit
        if value:
            self.flags |= implot.ImPlotAxisFlags_RangeFit

    @property
    def pan_stretch(self):
        """
        Writable attribute that when set, if panning in a locked or
        constrained state, will cause the axis to stretch
        if possible.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_PanStretch) != 0

    @pan_stretch.setter
    def pan_stretch(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_PanStretch
        if value:
            self.flags |= implot.ImPlotAxisFlags_PanStretch

    @property
    def lock_min(self):
        """
        Writable attribute to lock the axis minimum value
        when panning/zooming
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_LockMin) != 0

    @lock_min.setter
    def lock_min(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_LockMin
        if value:
            self.flags |= implot.ImPlotAxisFlags_LockMin

    @property
    def lock_max(self):
        """
        Writable attribute to lock the axis maximum value
        when panning/zooming
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotAxisFlags_LockMax) != 0

    @lock_max.setter
    def lock_max(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotAxisFlags_LockMax
        if value:
            self.flags |= implot.ImPlotAxisFlags_LockMax

    @property
    def hovered(self):
        """
        Readonly attribute: Is the mouse inside the axis label area
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return tuple(self.state.cur.clicked)

    @property
    def mouse_coord(self):
        """
        Readonly attribute:
        The last estimated mouse position in plot space
        for this axis.
        Beware not to assign the same instance of
        PlotAxisConfig to several axes if you plan on using
        this.
        The mouse position is updated everytime the plot is
        drawn and the axis is enabled.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._mouse_coord

    @property
    def handlers(self):
        """
        Writable attribute: bound handlers for the axis.
        Only visible, hovered and clicked handlers are compatible.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @handlers.setter
    def handlers(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

    def fit(self):
        """
        Request for a fit of min/max to the data the next time the plot is drawn
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.to_fit = True

    @property
    def label(self):
        """
        Writable attribute: axis name
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._label, encoding='utf-8')

    @label.setter
    def label(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._label = bytes(value, 'utf-8')

    @property
    def format(self):
        """
        Writable attribute: format string to display axis values
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._format, encoding='utf-8')

    @format.setter
    def format(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._format = bytes(value, 'utf-8')

    @property
    def labels(self):
        """
        Writable attribute: array of strings to display as labels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [str(v, encoding='utf-8') for v in self._labels]

    @labels.setter
    def labels(self, value):
        cdef unique_lock[recursive_mutex] m
        cdef int i
        lock_gil_friendly(m, self.mutex)
        self._labels.clear()
        self._labels_cstr.clear()
        if value is None:
            return
        if hasattr(value, '__len__'):
            for v in value:
                self._labels.push_back(bytes(v, 'utf-8'))
            for i in range(<int>self._labels.size()):
                self._labels_cstr.push_back(self._labels[i].c_str())
        else:
            raise ValueError(f"Invalid type {type(value)} passed as labels. Expected array of strings")

    @property
    def labels_coord(self):
        """
        Writable attribute: coordinate for each label in labels at
        which to display the labels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [v for v in self._labels_coord]

    @labels_coord.setter
    def labels_coord(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._labels_coord.clear()
        if value is None:
            return
        if hasattr(value, '__len__'):
            for v in value:
                self._labels_coord.push_back(v)
        else:
            raise ValueError(f"Invalid type {type(value)} passed as labels_coord. Expected array of strings")

    cdef void setup(self, implot.ImAxis axis) noexcept nogil:
        """
        Apply the config to the target axis during plot
        setup
        """
        self.set_previous_states()
        self.state.cur.hovered = False
        self.state.cur.rendered = False

        if self._enabled == False:
            self.context._viewport.enabled_axes[axis] = False
            return
        self.context._viewport.enabled_axes[axis] = True
        self.state.cur.rendered = True

        cdef implot.ImPlotAxisFlags flags = self.flags
        if self.to_fit:
            flags |= implot.ImPlotAxisFlags_AutoFit
        if <int>self._label.size() > 0:
            implot.SetupAxis(axis, self._label.c_str(), flags)
        else:
            implot.SetupAxis(axis, NULL, flags)
        """
        if self.dirty_minmax:
            # enforce min < max
            self._max = max(self._max, self._min + 1e-12)
            implot.SetupAxisLimits(axis,
                                   self._min,
                                   self._max,
                                   implot.ImPlotCond_Always)
        """
        self.prev_min = self._min
        self.prev_max = self._max
        # We use SetupAxisLinks to get the min/max update
        # right away during EndPlot(), rather than the
        # next frame
        implot.SetupAxisLinks(axis, &self._min, &self._max)

        implot.SetupAxisScale(axis, self._scale)

        if <int>self._format.size() > 0:
            implot.SetupAxisFormat(axis, self._format.c_str())

        if self._constraint_min != -INFINITY or \
           self._constraint_max != INFINITY:
            self._constraint_max = max(self._constraint_max, self._constraint_min + 1e-12)
            implot.SetupAxisLimitsConstraints(axis,
                                              self._constraint_min,
                                              self._constraint_max)
        if self._zoom_min > 0 or \
           self._zoom_max != INFINITY:
            self._zoom_min = max(0, self._zoom_min)
            self._zoom_max = max(self._zoom_min, self._zoom_max)
            implot.SetupAxisZoomConstraints(axis,
                                            self._zoom_min,
                                            self._zoom_max)
        cdef int label_count = min(<int>self._labels_coord.size(), <int>self._labels_cstr.size())
        if label_count > 0:
            implot.SetupAxisTicks(axis,
                                  self._labels_coord.data(),
                                  label_count,
                                  self._labels_cstr.data())

    cdef void after_setup(self, implot.ImAxis axis) noexcept nogil:
        """
        Update states, etc. after the elements were setup
        """
        if not(self.context._viewport.enabled_axes[axis]):
            if self.state.cur.rendered:
                self.set_hidden()
            return
        cdef implot.ImPlotRect rect
        #self.prev_min = self._min
        #self.prev_max = self._max
        self.dirty_minmax = False
        if axis <= implot.ImAxis_X3:
            rect = implot.GetPlotLimits(axis, implot.IMPLOT_AUTO)
            #self._min = rect.X.Min
            #self._max = rect.X.Max
            self._mouse_coord = implot.GetPlotMousePos(axis, implot.IMPLOT_AUTO).x
        else:
            rect = implot.GetPlotLimits(implot.IMPLOT_AUTO, axis)
            #self._min = rect.Y.Min
            #self._max = rect.Y.Max
            self._mouse_coord = implot.GetPlotMousePos(implot.IMPLOT_AUTO, axis).y

        # Take into accounts flags changed by user interactions
        cdef implot.ImPlotAxisFlags flags = GetAxisConfig(<int>axis)
        if self.to_fit and (self.flags & implot.ImPlotAxisFlags_AutoFit) == 0:
            # Remove Autofit flag introduced for to_fit
            flags &= ~implot.ImPlotAxisFlags_AutoFit
            self.to_fit = False
        self.flags = flags

        cdef bint hovered = implot.IsAxisHovered(axis)
        cdef int i
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.cur.clicked[i] = hovered and imgui.IsMouseClicked(i, False)
            self.state.cur.double_clicked[i] = hovered and imgui.IsMouseDoubleClicked(i)
        cdef bint backup_hovered = self.state.cur.hovered
        self.state.cur.hovered = hovered
        self.run_handlers() # TODO FIX multiple configs tied. Maybe just not support ?
        if not(backup_hovered) or self.state.cur.hovered:
            return
        # Restore correct states
        # We do it here and not above to trigger the handlers only once
        self.state.cur.hovered |= backup_hovered
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.cur.clicked[i] = self.state.cur.hovered and imgui.IsMouseClicked(i, False)
            self.state.cur.double_clicked[i] = self.state.cur.hovered and imgui.IsMouseDoubleClicked(i)

    cdef void after_plot(self, implot.ImAxis axis) noexcept nogil:
        # The fit only impacts the next frame
        if self._min != self.prev_min or self._max != self.prev_max:
            self.context._viewport.viewport.needs_refresh.store(True)

    cdef void set_hidden(self) noexcept nogil:
        self.set_previous_states()
        self.state.cur.hovered = False
        self.state.cur.rendered = False
        cdef int i
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.cur.clicked[i] = False
            self.state.cur.double_clicked[i] = False
        self.run_handlers()


cdef class PlotLegendConfig(baseItem):
    def __cinit__(self):
        self._show = True
        self._location = LegendLocation.northwest
        self.flags = 0

    '''
    # Probable doesn't work. Use instead plot no_legend
    @property
    def show(self):
        """
        Whether the legend is shown or hidden
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_siblings_no_handlers()
        self._show = value
    '''

    @property
    def location(self):
        """
        Position of the legend.
        Default is LegendLocation.northwest
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._location

    @location.setter
    def location(self, LegendLocation value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value == LegendLocation.center or \
           value == LegendLocation.north or \
           value == LegendLocation.south or \
           value == LegendLocation.west or \
           value == LegendLocation.east or \
           value == LegendLocation.northeast or \
           value == LegendLocation.northwest or \
           value == LegendLocation.southeast or \
           value == LegendLocation.southwest:
            self._location = value
        else:
            raise ValueError("Invalid location. Must be a LegendLocation")

    @property
    def no_buttons(self):
        """
        Writable attribute to prevent legend icons
        to function as hide/show buttons
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLegendFlags_NoButtons) != 0

    @no_buttons.setter
    def no_buttons(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLegendFlags_NoButtons
        if value:
            self.flags |= implot.ImPlotLegendFlags_NoButtons

    @property
    def no_highlight_item(self):
        """
        Writable attribute to disable highlighting plot items
        when their legend entry is hovered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLegendFlags_NoHighlightItem) != 0

    @no_highlight_item.setter
    def no_highlight_item(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLegendFlags_NoHighlightItem
        if value:
            self.flags |= implot.ImPlotLegendFlags_NoHighlightItem

    @property
    def no_highlight_axis(self):
        """
        Writable attribute to disable highlighting axes
        when their legend entry is hovered
        (only relevant if x/y-axis count > 1)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLegendFlags_NoHighlightAxis) != 0

    @no_highlight_axis.setter
    def no_highlight_axis(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLegendFlags_NoHighlightAxis
        if value:
            self.flags |= implot.ImPlotLegendFlags_NoHighlightAxis

    @property
    def no_menus(self):
        """
        Writable attribute to disable right-clicking
        to open context menus.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLegendFlags_NoMenus) != 0

    @no_menus.setter
    def no_menus(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLegendFlags_NoMenus
        if value:
            self.flags |= implot.ImPlotLegendFlags_NoMenus

    @property
    def outside(self):
        """
        Writable attribute to render the legend outside
        of the plot area
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLegendFlags_Outside) != 0

    @outside.setter
    def outside(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLegendFlags_Outside
        if value:
            self.flags |= implot.ImPlotLegendFlags_Outside

    @property
    def horizontal(self):
        """
        Writable attribute to display the legend entries
        horizontally rather than vertically
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLegendFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLegendFlags_Horizontal
        if value:
            self.flags |= implot.ImPlotLegendFlags_Horizontal

    @property
    def sorted(self):
        """
        Writable attribute to display the legend entries
        in alphabetical order
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLegendFlags_Sort) != 0

    @sorted.setter
    def sorted(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLegendFlags_Sort
        if value:
            self.flags |= implot.ImPlotLegendFlags_Sort

    cdef void setup(self) noexcept nogil:
        implot.SetupLegend(self._location, self.flags)
        # NOTE: Setup does just fill the location and flags.
        # No item is created at this point,
        # and thus we don't push fonts, check states, etc.

    cdef void after_setup(self) noexcept nogil:
        # The user can interact with legend configuration
        # with the mouse
        self._location = <LegendLocation>GetLegendConfig(self.flags)


cdef class Plot(uiItem):
    """
    Plot. Can have Plot elements as child.

    By default the axes X1 and Y1 are enabled,
    but other can be enabled, up to X3 and Y3.
    For instance:
    my_plot.X2.enabled = True

    By default, the legend and axes have reserved space.
    They can have their own handlers that can react to
    when they are hovered by the mouse or clicked.

    The states of the plot relate to the rendering area (excluding
    the legend, padding and axes). Thus if you want to react
    to mouse event inside the plot area (for example implementing
    clicking an curve), you can do it with using handlers bound
    to the plot (+ some logic in your callbacks). 
    """
    def __cinit__(self, context, *args, **kwargs):
        self.can_have_plot_element_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_content_region = True
        self._X1 = PlotAxisConfig(context)
        self._X2 = PlotAxisConfig(context, enabled=False)
        self._X3 = PlotAxisConfig(context, enabled=False)
        self._Y1 = PlotAxisConfig(context)
        self._Y2 = PlotAxisConfig(context, enabled=False)
        self._Y3 = PlotAxisConfig(context, enabled=False)
        self._legend = PlotLegendConfig(context)
        self._pan_button = imgui.ImGuiMouseButton_Left
        self._pan_modifier = 0
        self._fit_button = imgui.ImGuiMouseButton_Left
        self._menu_button = imgui.ImGuiMouseButton_Right
        self._override_mod = imgui.ImGuiMod_Ctrl
        self._zoom_mod = 0
        self._zoom_rate = 0.1
        self._use_local_time = False
        self._use_ISO8601 = False
        self._use_24hour_clock = False
        # Box select/Query rects. To remove
        # Disabling implot query rects. This is better
        # to have it implemented outside implot.
        self.flags = implot.ImPlotFlags_NoBoxSelect

    @property
    def X1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X1

    @X1.setter
    def X1(self, PlotAxisConfig value not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._X1 = value

    @property
    def X2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X2

    @X2.setter
    def X2(self, PlotAxisConfig value not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._X2 = value

    @property
    def X3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X3

    @X3.setter
    def X3(self, PlotAxisConfig value not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._X3 = value

    @property
    def Y1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y1

    @Y1.setter
    def Y1(self, PlotAxisConfig value not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._Y1 = value

    @property
    def Y2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y2

    @Y2.setter
    def Y2(self, PlotAxisConfig value not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._Y2 = value

    @property
    def Y3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y3

    @Y3.setter
    def Y3(self, PlotAxisConfig value not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._Y3 = value

    @property
    def axes(self):
        """
        Helper read-only property to retrieve the 6 axes
        in an array [X1, X2, X3, Y1, Y2, Y3]
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [self._X1, self._X2, self._X3, \
                self._Y1, self._Y2, self._Y3]

    @property
    def legend_config(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._legend

    @legend_config.setter
    def legend_config(self, PlotLegendConfig value not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._legend = value

    @property
    def content_pos(self):
        """
        Readable attribute indicating the top left starting
        position of the plot content in viewport coordinates.

        The size of the plot content area is available with
        content_size_avail.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return IntPairFromVec2(self._content_pos)

    @property
    def pan_button(self):
        """
        Button that when held enables to navigate inside the plot
        Default is the left mouse button.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pan_button

    @pan_button.setter
    def pan_button(self, int button):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._pan_button = button

    @property
    def pan_mod(self):
        """
        Modifier combination (shift/ctrl/alt/super) that must be
        pressed for pan_button to have effect.
        Default is no modifier.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pan_modifier

    @pan_mod.setter
    def pan_mod(self, int modifier):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (modifier & ~imgui.ImGuiMod_Mask_) != 0:
            raise ValueError("pan_mod must be a combinaison of modifiers")
        self._pan_modifier = modifier

    @property
    def fit_button(self):
        """
        Button that must be double-clicked to initiate
        a fit of the axes to the displayed data.
        Default is the left mouse button.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._fit_button

    @fit_button.setter
    def fit_button(self, int button):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._fit_button = button

    @property
    def menu_button(self):
        """
        Button that opens context menus
        (if enabled) when clicked.
        Default is the right mouse button.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._menu_button

    @menu_button.setter
    def menu_button(self, int button):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._menu_button = button

    @property
    def zoom_mod(self):
        """
        Modifier combination (shift/ctrl/alt/super) that
        must be hold for the mouse wheel to trigger a zoom
        of the plot.
        Default is no modifier.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._zoom_mod

    @zoom_mod.setter
    def zoom_mod(self, int modifier):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (modifier & ~imgui.ImGuiMod_Mask_) != 0:
            raise ValueError("zoom_mod must be a combinaison of modifiers")
        self._zoom_mod = modifier

    @property
    def zoom_rate(self):
        """
        Zoom rate for scroll (e.g. 0.1 = 10% plot range every
        scroll click);
        make negative to invert.
        Default is 0.1
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._zoom_rate

    @zoom_rate.setter
    def zoom_rate(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._zoom_rate = value

    @property
    def use_local_time(self):
        """
        If set, axis labels will be formatted for the system
        timezone when ImPlotAxisFlag_Time is enabled.
        Default is False.
        """
        return self._use_local_time

    @use_local_time.setter
    def use_local_time(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._use_local_time = value

    @property
    def use_ISO8601(self):
        """
        If set, dates will be formatted according to ISO 8601
        where applicable (e.g. YYYY-MM-DD, YYYY-MM,
        --MM-DD, etc.)
        Default is False.
        """
        return self._use_ISO8601

    @use_ISO8601.setter
    def use_ISO8601(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._use_ISO8601 = value

    @property
    def use_24hour_clock(self):
        """
        If set, times will be formatted using a 24 hour clock.
        Default is False
        """
        return self._use_24hour_clock

    @use_24hour_clock.setter
    def use_24hour_clock(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._use_24hour_clock = value

    @property
    def no_title(self):
        """
        Writable attribute to disable the display of the
        plot title
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_NoTitle) != 0

    @no_title.setter
    def no_title(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_NoTitle
        if value:
            self.flags |= implot.ImPlotFlags_NoTitle

    @property
    def no_menus(self):
        """
        Writable attribute to disable the user interactions
        to open the context menus
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_NoMenus) != 0

    @no_menus.setter
    def no_menus(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_NoMenus
        if value:
            self.flags |= implot.ImPlotFlags_NoMenus

    @property
    def no_mouse_pos(self):
        """
        Writable attribute to disable the display of the
        mouse position
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_NoMouseText) != 0

    @no_mouse_pos.setter
    def no_mouse_pos(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_NoMouseText
        if value:
            self.flags |= implot.ImPlotFlags_NoMouseText

    @property
    def crosshairs(self):
        """
        Writable attribute to replace the default mouse
        cursor by a crosshair when hovered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_Crosshairs) != 0

    @crosshairs.setter
    def crosshairs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_Crosshairs
        if value:
            self.flags |= implot.ImPlotFlags_Crosshairs

    @property
    def equal_aspects(self):
        """
        Writable attribute to constrain x/y axes
        pairs to have the same units/pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_Equal) != 0

    @equal_aspects.setter
    def equal_aspects(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_Equal
        if value:
            self.flags |= implot.ImPlotFlags_Equal

    @property
    def no_inputs(self):
        """
        Writable attribute to disable user interactions with
        the plot.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_NoInputs
        if value:
            self.flags |= implot.ImPlotFlags_NoInputs

    @property
    def no_frame(self):
        """
        Writable attribute to disable the drawing of the
        imgui frame.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_NoFrame) != 0

    @no_frame.setter
    def no_frame(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_NoFrame
        if value:
            self.flags |= implot.ImPlotFlags_NoFrame

    @property
    def no_legend(self):
        """
        Writable attribute to disable the display of the
        legend
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotFlags_NoLegend) != 0

    @no_legend.setter
    def no_legend(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotFlags_NoLegend
        if value:
            self.flags |= implot.ImPlotFlags_NoLegend

    cdef bint draw_item(self) noexcept nogil:
        cdef int i
        cdef imgui.ImVec2 rect_size
        cdef bint visible
        implot.GetStyle().UseLocalTime = self._use_local_time
        implot.GetStyle().UseISO8601 = self._use_ISO8601
        implot.GetStyle().Use24HourClock = self._use_24hour_clock
        implot.GetInputMap().Pan = self._pan_button
        implot.GetInputMap().Fit = self._fit_button
        implot.GetInputMap().Menu = self._menu_button
        implot.GetInputMap().ZoomRate = self._zoom_rate
        implot.GetInputMap().PanMod = self._pan_modifier
        implot.GetInputMap().ZoomMod = self._zoom_mod
        implot.GetInputMap().OverrideMod = self._override_mod

        self._X1.mutex.lock()
        self._X2.mutex.lock()
        self._X3.mutex.lock()
        self._Y1.mutex.lock()
        self._Y2.mutex.lock()
        self._Y3.mutex.lock()
        self._legend.mutex.lock()

        # Check at least one axis of each is enabled ?

        visible = implot.BeginPlot(self.imgui_label.c_str(),
                                   self.scaled_requested_size(),
                                   self.flags)
        # BeginPlot created the imgui Item
        self.state.cur.rect_size = imgui.GetItemRectSize()
        if visible:
            self.state.cur.rendered = True
            
            # Setup axes
            self._X1.setup(implot.ImAxis_X1)
            self._X2.setup(implot.ImAxis_X2)
            self._X3.setup(implot.ImAxis_X3)
            self._Y1.setup(implot.ImAxis_Y1)
            self._Y2.setup(implot.ImAxis_Y2)
            self._Y3.setup(implot.ImAxis_Y3)

            # From DPG: workaround for stuck selection
            # Unsure why it should be done here and not above
            # -> Not needed because query rects are not implemented with implot
            #if (imgui.GetIO().KeyMods & self._query_toggle_mod) == imgui.GetIO().KeyMods and \
            #    (imgui.IsMouseDown(self._select_button) or imgui.IsMouseReleased(self._select_button)):
            #    implot.GetInputMap().OverrideMod = imgui.ImGuiMod_None

            self._legend.setup()

            implot.SetupFinish()

            # These states are valid after SetupFinish
            # Update now to have up to date data for handlers of children.
            self.state.cur.hovered = implot.IsPlotHovered()
            update_current_mouse_states(self.state)
            self.state.cur.content_region_size = implot.GetPlotSize()
            self._content_pos = implot.GetPlotPos()

            self._X1.after_setup(implot.ImAxis_X1)
            self._X2.after_setup(implot.ImAxis_X2)
            self._X3.after_setup(implot.ImAxis_X3)
            self._Y1.after_setup(implot.ImAxis_Y1)
            self._Y2.after_setup(implot.ImAxis_Y2)
            self._Y3.after_setup(implot.ImAxis_Y3)
            self._legend.after_setup()

            implot.PushPlotClipRect(0.)

            if self.last_plot_element_child is not None:
                self.last_plot_element_child.draw()

            implot.PopPlotClipRect()
            # The user can interact with the plot
            # configuration with the mouse
            self.flags = GetPlotConfig()
            implot.EndPlot()
            self._X1.after_plot(implot.ImAxis_X1)
            self._X2.after_plot(implot.ImAxis_X2)
            self._X3.after_plot(implot.ImAxis_X3)
            self._Y1.after_plot(implot.ImAxis_Y1)
            self._Y2.after_plot(implot.ImAxis_Y2)
            self._Y3.after_plot(implot.ImAxis_Y3)
        elif self.state.cur.rendered:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            self._X1.set_hidden()
            self._X2.set_hidden()
            self._X3.set_hidden()
            self._Y1.set_hidden()
            self._Y2.set_hidden()
            self._Y3.set_hidden()
        self._X1.mutex.unlock()
        self._X2.mutex.unlock()
        self._X3.mutex.unlock()
        self._Y1.mutex.unlock()
        self._Y2.mutex.unlock()
        self._Y3.mutex.unlock()
        self._legend.mutex.unlock()
        return False
        # We don't need to restore the plot config as we
        # always overwrite it.


cdef class plotElement(baseItem):
    """
    Base class for plot children.
    """
    def __cinit__(self):
        self.imgui_label = b'###%ld'% self.uuid
        self.user_label = ""
        self.flags = implot.ImPlotItemFlags_None
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_plot_element
        self._show = True
        self._axes = [implot.ImAxis_X1, implot.ImAxis_Y1]
        self._theme = None

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
        return self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_siblings_no_handlers()
        self._show = value

    @property
    def axes(self):
        """
        Writable attribute: (X axis, Y axis)
        used for this plot element.
        Default is (X1, Y1)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._axes[0], self._axes[1])

    @axes.setter
    def axes(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int axis_x, axis_y
        try:
            (axis_x, axis_y) = value
            assert(axis_x in [implot.ImAxis_X1,
                              implot.ImAxis_X2,
                              implot.ImAxis_X3])
            assert(axis_y in [implot.ImAxis_Y1,
                              implot.ImAxis_Y2,
                              implot.ImAxis_Y3])
        except Exception as e:
            raise ValueError("Axes must be a tuple of valid X/Y axes")
        self._axes[0] = axis_x
        self._axes[1] = axis_y

    @property
    def label(self):
        """
        Writable attribute: label assigned to the element
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
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
    def theme(self):
        """
        Writable attribute: theme for the legend and plot
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Render siblings first
        if self._prev_sibling is not None:
            (<plotElement>self._prev_sibling).draw()

        return


cdef class plotElementWithLegend(plotElement):
    """
    Base class for plot children with a legend.

    Children of plot elements are rendered on a legend
    popup entry that gets shown on a right click (by default).
    """
    def __cinit__(self):
        self.state.cap.can_be_hovered = True # The legend only
        self.p_state = &self.state
        self._enabled = True
        self.enabled_dirty = True
        self._legend_button = imgui.ImGuiMouseButton_Right
        self._legend = True
        self.state.cap.can_be_hovered = True
        self.can_have_widget_child = True

    @property
    def no_legend(self):
        """
        Writable attribute to disable the legend for this plot
        element
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._legend)

    @no_legend.setter
    def no_legend(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._legend = not(value)
        # unsure if needed
        self.flags &= ~implot.ImPlotItemFlags_NoLegend
        if value:
            self.flags |= implot.ImPlotItemFlags_NoLegend

    @property
    def ignore_fit(self):
        """
        Writable attribute to make this element
        be ignored during plot fits
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotItemFlags_NoFit) != 0

    @ignore_fit.setter
    def ignore_fit(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotItemFlags_NoFit
        if value:
            self.flags |= implot.ImPlotItemFlags_NoFit

    @property
    def enabled(self):
        """
        Writable attribute: show/hide
        the item while still having a toggable
        entry in the menu.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value != self._enabled:
            self.enabled_dirty = True
        self._enabled = value

    @property
    def font(self):
        """
        Writable attribute: font used for the text rendered
        of this item and its subitems
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, Font value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def legend_button(self):
        """
        Button that opens the legend entry for
        this element.
        Default is the right mouse button.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._legend_button

    @legend_button.setter
    def legend_button(self, int button):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if button < 0 or button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._legend_button = button

    @property
    def legend_handlers(self):
        """
        Writable attribute: bound handlers for the legend.
        Only visible (set for the plot) and hovered (set 
        for the legend) handlers are compatible.
        To detect if the plot element is hovered, check
        the hovered state of the plot.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @legend_handlers.setter
    def legend_handlers(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

    @property
    def legend_hovered(self):
        """
        Readonly attribute: Is the legend of this
        item hovered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Render siblings first
        if self._prev_sibling is not None:
            (<plotElement>self._prev_sibling).draw()

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context._viewport.enabled_axes[self._axes[0]]) or \
           not(self.context._viewport.enabled_axes[self._axes[1]]):
            self.set_previous_states()
            self.state.cur.rendered = False
            self.state.cur.hovered = False
            self.propagate_hidden_state_to_children_with_handlers()
            self.run_handlers()
            return

        self.set_previous_states()

        # push theme, font
        if self._font is not None:
            self._font.push()

        self.context._viewport.push_pending_theme_actions(
            theme_enablers.t_enabled_any,
            theme_categories.t_plot
        )

        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])

        if self.enabled_dirty:
            implot.HideNextItem(not(self._enabled), implot.ImPlotCond_Always)
            self.enabled_dirty = False
        else:
            self._enabled = IsItemHidden(self.imgui_label.c_str())
        self.draw_element()

        self.state.cur.rendered = True
        self.state.cur.hovered = False
        cdef imgui.ImVec2 pos_w, pos_p
        if self._legend:
            # Popup that gets opened with a click on the entry
            # We don't open it if it will be empty as it will
            # display a small rect with nothing in it. It's surely
            # better to not display anything in this case.
            if self.last_widgets_child is not None:
                if implot.BeginLegendPopup(self.imgui_label.c_str(),
                                           self._legend_button):
                    if self.last_widgets_child is not None:
                        # sub-window
                        pos_w = imgui.GetCursorScreenPos()
                        pos_p = pos_w
                        swap(pos_w, self.context._viewport.window_pos)
                        swap(pos_p, self.context._viewport.parent_pos)
                        self.last_widgets_child.draw()
                        self.context._viewport.window_pos = pos_w
                        self.context._viewport.parent_pos = pos_p
                    implot.EndLegendPopup()
            self.state.cur.hovered = implot.IsLegendEntryHovered(self.imgui_label.c_str())


        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

        self.context._viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        self.run_handlers()

    cdef void draw_element(self) noexcept nogil:
        return

cdef class plotElementXY(plotElementWithLegend):
    def __cinit__(self):
        self._X = np.zeros(shape=(1,), dtype=np.float64)
        self._Y = np.zeros(shape=(1,), dtype=np.float64)

    @property
    def X(self):
        """Values on the X axis.

        By default, will try to use the passed array
        directly for its internal backing (no copy).
        Supported types for no copy are np.int32,
        np.float32, np.float64.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X

    @X.setter
    def X(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef cnp.ndarray array = np.asarray(value).reshape([-1])
        # We don't support array of pointers. Must be data,
        # with eventually a non-standard stride
        # type must also be one of the supported types
        if cnp.PyArray_CHKFLAGS(array, cnp.NPY_ARRAY_ELEMENTSTRIDES) and \
           (cnp.PyArray_TYPE(array) == cnp.NPY_INT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_FLOAT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_DOUBLE):
            self._X = array
        else:
            self._X = np.ascontiguousarray(array, dtype=np.float64)

    @property
    def Y(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y

    @Y.setter
    def Y(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef cnp.ndarray array = np.asarray(value).reshape([-1])
        # We don't support array of pointers. Must be data,
        # with eventually a non-standard stride
        # type must also be one of the supported types
        if cnp.PyArray_CHKFLAGS(array, cnp.NPY_ARRAY_ELEMENTSTRIDES) and \
           (cnp.PyArray_TYPE(array) == cnp.NPY_INT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_FLOAT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_DOUBLE):
            self._Y = array
        else:
            self._Y = np.ascontiguousarray(array, dtype=np.float64)

    cdef void check_arrays(self) noexcept nogil:
        # X and Y must be same type and same stride
        if cnp.PyArray_TYPE(self._X) != cnp.PyArray_TYPE(self._Y):
            with gil:
                self._X = np.ascontiguousarray(self._X, dtype=np.float64)
                self._Y = np.ascontiguousarray(self._Y, dtype=np.float64)
        if cnp.PyArray_STRIDE(self._X, 0) != cnp.PyArray_STRIDE(self._Y, 0):
            with gil:
                self._X = np.ascontiguousarray(self._X, dtype=np.float64)
                self._Y = np.ascontiguousarray(self._Y, dtype=np.float64)

cdef class PlotLine(plotElementXY):
    @property
    def segments(self):
        """
        Plot segments rather than a full line
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLineFlags_Segments) != 0

    @segments.setter
    def segments(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLineFlags_Segments
        if value:
            self.flags |= implot.ImPlotLineFlags_Segments

    @property
    def loop(self):
        """
        Connect the first and last points
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLineFlags_Loop) != 0

    @loop.setter
    def loop(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLineFlags_Loop
        if value:
            self.flags |= implot.ImPlotLineFlags_Loop

    @property
    def skip_nan(self):
        """
        A NaN data point will be ignored instead of
        being rendered as missing data.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLineFlags_SkipNaN) != 0

    @skip_nan.setter
    def skip_nan(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLineFlags_SkipNaN
        if value:
            self.flags |= implot.ImPlotLineFlags_SkipNaN

    @property
    def no_clip(self):
        """
        Markers (if displayed) on the edge of a plot will not be clipped.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLineFlags_NoClip) != 0

    @no_clip.setter
    def no_clip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLineFlags_NoClip
        if value:
            self.flags |= implot.ImPlotLineFlags_NoClip

    @property
    def shaded(self):
        """
        A filled region between the line and horizontal
        origin will be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotLineFlags_Shaded) != 0

    @shaded.setter
    def shaded(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotLineFlags_Shaded
        if value:
            self.flags |= implot.ImPlotLineFlags_Shaded

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = min(self._X.shape[0], self._Y.shape[0])
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotLine[int](self.imgui_label.c_str(),
                                 <const int*>cnp.PyArray_DATA(self._X),
                                 <const int*>cnp.PyArray_DATA(self._Y),
                                 size,
                                 self.flags,
                                 0,
                                 cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotLine[float](self.imgui_label.c_str(),
                                   <const float*>cnp.PyArray_DATA(self._X),
                                   <const float*>cnp.PyArray_DATA(self._Y),
                                   size,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotLine[double](self.imgui_label.c_str(),
                                    <const double*>cnp.PyArray_DATA(self._X),
                                    <const double*>cnp.PyArray_DATA(self._Y),
                                    size,
                                    self.flags,
                                    0,
                                    cnp.PyArray_STRIDE(self._X, 0))

cdef class plotElementXYY(plotElementWithLegend):
    def __cinit__(self):
        self._X = np.zeros(shape=(1,), dtype=np.float64)
        self._Y1 = np.zeros(shape=(1,), dtype=np.float64)
        self._Y2 = np.zeros(shape=(1,), dtype=np.float64)

    @property
    def X(self):
        """Values on the X axis.

        By default, will try to use the passed array
        directly for its internal backing (no copy).
        Supported types for no copy are np.int32,
        np.float32, np.float64.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X

    @X.setter
    def X(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef cnp.ndarray array = np.asarray(value).reshape([-1])
        # We don't support array of pointers. Must be data,
        # with eventually a non-standard stride
        # type must also be one of the supported types
        if cnp.PyArray_CHKFLAGS(array, cnp.NPY_ARRAY_ELEMENTSTRIDES) and \
           (cnp.PyArray_TYPE(array) == cnp.NPY_INT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_FLOAT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_DOUBLE):
            self._X = array
        else:
            self._X = np.ascontiguousarray(array, dtype=np.float64)

    @property
    def Y1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y1

    @Y1.setter
    def Y1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef cnp.ndarray array = np.asarray(value).reshape([-1])
        # We don't support array of pointers. Must be data,
        # with eventually a non-standard stride
        # type must also be one of the supported types
        if cnp.PyArray_CHKFLAGS(array, cnp.NPY_ARRAY_ELEMENTSTRIDES) and \
           (cnp.PyArray_TYPE(array) == cnp.NPY_INT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_FLOAT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_DOUBLE):
            self._Y1 = array
        else:
            self._Y1 = np.ascontiguousarray(array, dtype=np.float64)

    @property
    def Y2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y2

    @Y2.setter
    def Y2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef cnp.ndarray array = np.asarray(value).reshape([-1])
        # We don't support array of pointers. Must be data,
        # with eventually a non-standard stride
        # type must also be one of the supported types
        if cnp.PyArray_CHKFLAGS(array, cnp.NPY_ARRAY_ELEMENTSTRIDES) and \
           (cnp.PyArray_TYPE(array) == cnp.NPY_INT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_FLOAT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_DOUBLE):
            self._Y2 = array
        else:
            self._Y2 = np.ascontiguousarray(array, dtype=np.float64)

    cdef void check_arrays(self) noexcept nogil:
        # X, Y1 and Y2 must be same type and same stride
        if cnp.PyArray_TYPE(self._X) != cnp.PyArray_TYPE(self._Y1) or \
           cnp.PyArray_TYPE(self._X) != cnp.PyArray_TYPE(self._Y2):
            with gil:
                self._X = np.ascontiguousarray(self._X, dtype=np.float64)
                self._Y1 = np.ascontiguousarray(self._Y1, dtype=np.float64)
                self._Y2 = np.ascontiguousarray(self._Y2, dtype=np.float64)
        if cnp.PyArray_STRIDE(self._X, 0) != cnp.PyArray_STRIDE(self._Y1, 0) or \
           cnp.PyArray_STRIDE(self._X, 0) != cnp.PyArray_STRIDE(self._Y2, 0):
            with gil:
                self._X = np.ascontiguousarray(self._X, dtype=np.float64)
                self._Y1 = np.ascontiguousarray(self._Y1, dtype=np.float64)
                self._Y2 = np.ascontiguousarray(self._Y2, dtype=np.float64)

cdef class PlotShadedLine(plotElementXYY):
    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = min(min(self._X.shape[0], self._Y1.shape[0]), self._Y2.shape[0])
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotShaded[int](self.imgui_label.c_str(),
                                   <const int*>cnp.PyArray_DATA(self._X),
                                   <const int*>cnp.PyArray_DATA(self._Y1),
                                   <const int*>cnp.PyArray_DATA(self._Y2),
                                   size,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotShaded[float](self.imgui_label.c_str(),
                                     <const float*>cnp.PyArray_DATA(self._X),
                                     <const float*>cnp.PyArray_DATA(self._Y1),
                                     <const float*>cnp.PyArray_DATA(self._Y2),
                                     size,
                                     self.flags,
                                     0,
                                     cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotShaded[double](self.imgui_label.c_str(),
                                      <const double*>cnp.PyArray_DATA(self._X),
                                      <const double*>cnp.PyArray_DATA(self._Y1),
                                      <const double*>cnp.PyArray_DATA(self._Y2),
                                      size,
                                      self.flags,
                                      0,
                                      cnp.PyArray_STRIDE(self._X, 0))

cdef class PlotStems(plotElementXY):
    @property
    def horizontal(self):
        """
        Stems will be rendered horizontally
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotStemsFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotStemsFlags_Horizontal
        if value:
            self.flags |= implot.ImPlotStemsFlags_Horizontal

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = min(self._X.shape[0], self._Y.shape[0])
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotStems[int](self.imgui_label.c_str(),
                                 <const int*>cnp.PyArray_DATA(self._X),
                                 <const int*>cnp.PyArray_DATA(self._Y),
                                 size,
                                 0.,
                                 self.flags,
                                 0,
                                 cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotStems[float](self.imgui_label.c_str(),
                                   <const float*>cnp.PyArray_DATA(self._X),
                                   <const float*>cnp.PyArray_DATA(self._Y),
                                   size,
                                   0.,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotStems[double](self.imgui_label.c_str(),
                                    <const double*>cnp.PyArray_DATA(self._X),
                                    <const double*>cnp.PyArray_DATA(self._Y),
                                    size,
                                    0.,
                                    self.flags,
                                    0,
                                    cnp.PyArray_STRIDE(self._X, 0))

cdef class PlotBars(plotElementXY):
    def __cinit__(self):
        self._weight = 1.

    @property
    def weight(self):
        """
        bar_size. TODO better document
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._weight

    @weight.setter
    def weight(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._weight = value

    @property
    def horizontal(self):
        """
        Bars will be rendered horizontally
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotBarsFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotBarsFlags_Horizontal
        if value:
            self.flags |= implot.ImPlotBarsFlags_Horizontal

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = min(self._X.shape[0], self._Y.shape[0])
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotBars[int](self.imgui_label.c_str(),
                                 <const int*>cnp.PyArray_DATA(self._X),
                                 <const int*>cnp.PyArray_DATA(self._Y),
                                 size,
                                 self._weight,
                                 self.flags,
                                 0,
                                 cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotBars[float](self.imgui_label.c_str(),
                                   <const float*>cnp.PyArray_DATA(self._X),
                                   <const float*>cnp.PyArray_DATA(self._Y),
                                   size,
                                   self._weight,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotBars[double](self.imgui_label.c_str(),
                                    <const double*>cnp.PyArray_DATA(self._X),
                                    <const double*>cnp.PyArray_DATA(self._Y),
                                    size,
                                    self._weight,
                                    self.flags,
                                    0,
                                    cnp.PyArray_STRIDE(self._X, 0))

cdef class PlotStairs(plotElementXY):
    @property
    def pre_step(self):
        """
        The y value is continued constantly to the left
        from every x position, i.e. the interval
        (x[i-1], x[i]] has the value y[i].
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotStairsFlags_PreStep) != 0

    @pre_step.setter
    def pre_step(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotStairsFlags_PreStep
        if value:
            self.flags |= implot.ImPlotStairsFlags_PreStep

    @property
    def shaded(self):
        """
        a filled region between the stairs and horizontal
        origin will be rendered; use PlotShadedLine for
        more advanced cases.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotStairsFlags_Shaded) != 0

    @shaded.setter
    def shaded(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotStairsFlags_Shaded
        if value:
            self.flags |= implot.ImPlotStairsFlags_Shaded

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = min(self._X.shape[0], self._Y.shape[0])
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotStairs[int](self.imgui_label.c_str(),
                                 <const int*>cnp.PyArray_DATA(self._X),
                                 <const int*>cnp.PyArray_DATA(self._Y),
                                 size,
                                 self.flags,
                                 0,
                                 cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotStairs[float](self.imgui_label.c_str(),
                                   <const float*>cnp.PyArray_DATA(self._X),
                                   <const float*>cnp.PyArray_DATA(self._Y),
                                   size,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotStairs[double](self.imgui_label.c_str(),
                                    <const double*>cnp.PyArray_DATA(self._X),
                                    <const double*>cnp.PyArray_DATA(self._Y),
                                    size,
                                    self.flags,
                                    0,
                                    cnp.PyArray_STRIDE(self._X, 0))

cdef class plotElementX(plotElementWithLegend):
    def __cinit__(self):
        self._X = np.zeros(shape=(1,), dtype=np.float64)

    @property
    def X(self):
        """Values on the X axis.

        By default, will try to use the passed array
        directly for its internal backing (no copy).
        Supported types for no copy are np.int32,
        np.float32, np.float64.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X

    @X.setter
    def X(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef cnp.ndarray array = np.asarray(value).reshape([-1])
        # We don't support array of pointers. Must be data,
        # with eventually a non-standard stride
        # type must also be one of the supported types
        if cnp.PyArray_CHKFLAGS(array, cnp.NPY_ARRAY_ELEMENTSTRIDES) and \
           (cnp.PyArray_TYPE(array) == cnp.NPY_INT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_FLOAT or \
            cnp.PyArray_TYPE(array) == cnp.NPY_DOUBLE):
            self._X = array
        else:
            self._X = np.ascontiguousarray(array, dtype=np.float64)

    cdef void check_arrays(self) noexcept nogil:
        return


cdef class PlotInfLines(plotElementX):
    """
    Draw vertical (or horizontal) infinite lines at
    the passed coordinates
    """
    @property
    def horizontal(self):
        """
        Plot horizontal lines rather than plots
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotInfLinesFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotInfLinesFlags_Horizontal
        if value:
            self.flags |= implot.ImPlotInfLinesFlags_Horizontal

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = self._X.shape[0]
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotInfLines[int](self.imgui_label.c_str(),
                                 <const int*>cnp.PyArray_DATA(self._X),
                                 size,
                                 self.flags,
                                 0,
                                 cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotInfLines[float](self.imgui_label.c_str(),
                                   <const float*>cnp.PyArray_DATA(self._X),
                                   size,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotInfLines[double](self.imgui_label.c_str(),
                                    <const double*>cnp.PyArray_DATA(self._X),
                                    size,
                                    self.flags,
                                    0,
                                    cnp.PyArray_STRIDE(self._X, 0))

cdef class PlotScatter(plotElementXY):
    @property
    def no_clip(self):
        """
        Markers on the edge of a plot will not be clipped
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotScatterFlags_NoClip) != 0

    @no_clip.setter
    def no_clip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotScatterFlags_NoClip
        if value:
            self.flags |= implot.ImPlotScatterFlags_NoClip

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = min(self._X.shape[0], self._Y.shape[0])
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotScatter[int](self.imgui_label.c_str(),
                                 <const int*>cnp.PyArray_DATA(self._X),
                                 <const int*>cnp.PyArray_DATA(self._Y),
                                 size,
                                 self.flags,
                                 0,
                                 cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotScatter[float](self.imgui_label.c_str(),
                                   <const float*>cnp.PyArray_DATA(self._X),
                                   <const float*>cnp.PyArray_DATA(self._Y),
                                   size,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotScatter[double](self.imgui_label.c_str(),
                                    <const double*>cnp.PyArray_DATA(self._X),
                                    <const double*>cnp.PyArray_DATA(self._Y),
                                    size,
                                    self.flags,
                                    0,
                                    cnp.PyArray_STRIDE(self._X, 0))

'''
cdef class PlotHistogram2D(plotElementXY):
    @property
    def density(self):
        """
        Counts will be normalized, i.e. the PDF will be visualized
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotHistogramFlags_Density) != 0

    @density.setter
    def density(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotHistogramFlags_Density
        if value:
            self.flags |= implot.ImPlotHistogramFlags_Density

    @property
    def no_outliers(self):
        """
        Exclude values outside the specifed histogram range
        from the count toward normalizing and cumulative counts.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotHistogramFlags_NoOutliers) != 0

    @no_outliers.setter
    def no_outliers(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotHistogramFlags_NoOutliers
        if value:
            self.flags |= implot.ImPlotHistogramFlags_NoOutliers

# TODO: row col flag ???

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int size = min(self._X.shape[0], self._Y.shape[0])
        if size == 0:
            return

        if cnp.PyArray_TYPE(self._X) == cnp.NPY_INT:
            implot.PlotScatter[int](self.imgui_label.c_str(),
                                 <const int*>cnp.PyArray_DATA(self._X),
                                 <const int*>cnp.PyArray_DATA(self._Y),
                                 size,
                                 self._weight,
                                 self.flags,
                                 0,
                                 cnp.PyArray_STRIDE(self._X, 0))
        elif cnp.PyArray_TYPE(self._X) == cnp.NPY_FLOAT:
            implot.PlotScatter[float](self.imgui_label.c_str(),
                                   <const float*>cnp.PyArray_DATA(self._X),
                                   <const float*>cnp.PyArray_DATA(self._Y),
                                   size,
                                   self._weight,
                                   self.flags,
                                   0,
                                   cnp.PyArray_STRIDE(self._X, 0))
        else:
            implot.PlotScatter[double](self.imgui_label.c_str(),
                                    <const double*>cnp.PyArray_DATA(self._X),
                                    <const double*>cnp.PyArray_DATA(self._Y),
                                    size,
                                    self._weight,
                                    self.flags,
                                    0,
                                    cnp.PyArray_STRIDE(self._X, 0))
'''
'''
cdef class plotDraggable(plotElement):
    """
    Base class for plot draggable elements.
    """
    def __cinit__(self):
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_active = True
        self.flags = implot.ImPlotDragToolFlags_None

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
    def no_cursors(self):
        """
        Writable attribute to make drag tools
        not change cursor icons when hovered or held.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotDragToolFlags_NoCursors) != 0

    @no_cursors.setter
    def no_cursors(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotDragToolFlags_NoCursors
        if value:
            self.flags |= implot.ImPlotDragToolFlags_NoCursors

    @property
    def ignore_fit(self):
        """
        Writable attribute to make the drag tool
        not considered for plot fits.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotDragToolFlags_NoFit) != 0

    @ignore_fit.setter
    def ignore_fit(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotDragToolFlags_NoFit
        if value:
            self.flags |= implot.ImPlotDragToolFlags_NoFit

    @property
    def ignore_inputs(self):
        """
        Writable attribute to lock the tool from user inputs
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotDragToolFlags_NoInputs) != 0

    @ignore_inputs.setter
    def ignore_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotDragToolFlags_NoInputs
        if value:
            self.flags |= implot.ImPlotDragToolFlags_NoInputs

    @property
    def delayed(self):
        """
        Writable attribute to delay rendering
        by one frame.

        One use case is position-contraints.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.flags & implot.ImPlotDragToolFlags_Delayed) != 0

    @delayed.setter
    def delayed(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.flags &= ~implot.ImPlotDragToolFlags_Delayed
        if value:
            self.flags |= implot.ImPlotDragToolFlags_Delayed

    @property
    def active(self):
        """
        Readonly attribute: is the drag tool held
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return tuple(self.state.cur.clicked)

    @property
    def double_clicked(self):
        """
        Readonly attribute: has the item just been double-clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.double_clicked

    @property
    def hovered(self):
        """
        Readonly attribute: Is the item hovered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    cdef void draw(self) noexcept nogil:
        cdef int i
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Render siblings first
        if self._prev_sibling is not None:
            (<plotElement>self._prev_sibling).draw()

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context._viewport.enabled_axes[self._axes[0]]) or \
           not(self.context._viewport.enabled_axes[self._axes[1]]):
            self.state.cur.hovered = False
            self.state.cur.rendered = False
            for i in range(imgui.ImGuiMouseButton_COUNT):
                self.state.cur.clicked[i] = False
                self.state.cur.double_clicked[i] = False
            self.propagate_hidden_state_to_children_with_handlers()
            return

        # push theme, font
        self.context._viewport.push_pending_theme_actions(
            theme_enablers.t_enabled_any,
            theme_categories.t_plot
        )

        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])
        self.state.cur.rendered = True
        self.draw_element()

        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

        self.context._viewport.pop_applied_pending_theme_actions()

        self.run_handlers()

    cdef void draw_element(self) noexcept nogil:
        return
'''

cdef class DrawInPlot(plotElementWithLegend):
    """
    A plot element that enables to insert Draw* items
    inside a plot in plot coordinates.

    defaults to no_legend = True
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self._legend = False
        self._ignore_fit = False

    @property
    def ignore_fit(self):
        """
        Writable attribute to make this element
        be ignored during plot fits
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._ignore_fit

    @ignore_fit.setter
    def ignore_fit(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._ignore_fit = value

    cdef void draw(self) noexcept nogil:
        # Render siblings first
        if self._prev_sibling is not None:
            (<plotElement>self._prev_sibling).draw()

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context._viewport.enabled_axes[self._axes[0]]) or \
           not(self.context._viewport.enabled_axes[self._axes[1]]):
            self.set_previous_states()
            self.state.cur.rendered = False
            self.state.cur.hovered = False
            self.propagate_hidden_state_to_children_with_handlers()
            self.run_handlers()
            return

        self.set_previous_states()

        # push theme, font
        if self._font is not None:
            self._font.push()

        self.context._viewport.push_pending_theme_actions(
            theme_enablers.t_enabled_any,
            theme_categories.t_plot
        )

        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])

        # Reset current drawInfo
        self.context._viewport.scales = [1., 1.]
        self.context._viewport.shifts = [0., 0.]
        self.context._viewport.in_plot = True
        self.context._viewport.plot_fit = False if self._ignore_fit else implot.FitThisFrame()
        self.context._viewport.thickness_multiplier = implot.GetStyle().LineWeight
        self.context._viewport.size_multiplier = implot.GetPlotSize().x / implot.GetPlotLimits(self._axes[0], self._axes[1]).Size().x
        self.context._viewport.thickness_multiplier = self.context._viewport.thickness_multiplier * self.context._viewport.size_multiplier
        self.context._viewport.parent_pos = implot.GetPlotPos()

        cdef bint render = True

        if self._legend:
            render = implot.BeginItem(self.imgui_label.c_str(), self.flags, -1)
        else:
            implot.PushPlotClipRect(0.)

        if render:
            if self.last_drawings_child is not None:
                self.last_drawings_child.draw(implot.GetPlotDrawList())

            if self._legend:
                implot.EndItem()
            else:
                implot.PopPlotClipRect()

        self.state.cur.rendered = True
        self.state.cur.hovered = False
        cdef imgui.ImVec2 pos_w, pos_p
        if self._legend:
            # Popup that gets opened with a click on the entry
            # We don't open it if it will be empty as it will
            # display a small rect with nothing in it. It's surely
            # better to not display anything in this case.
            if self.last_widgets_child is not None:
                if implot.BeginLegendPopup(self.imgui_label.c_str(),
                                           self._legend_button):
                    if self.last_widgets_child is not None:
                        # sub-window
                        pos_w = imgui.GetCursorScreenPos()
                        pos_p = pos_w
                        swap(pos_w, self.context._viewport.window_pos)
                        swap(pos_p, self.context._viewport.parent_pos)
                        self.last_widgets_child.draw()
                        self.context._viewport.window_pos = pos_w
                        self.context._viewport.parent_pos = pos_p
                    implot.EndLegendPopup()
            self.state.cur.hovered = implot.IsLegendEntryHovered(self.imgui_label.c_str())

        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

        self.context._viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        self.run_handlers()

"""
System File dialog
"""

cdef extern from "SDL3/SDL_dialog.h" nogil:
    struct SDL_Window_:
        pass
    ctypedef SDL_Window_* SDL_Window
    struct SDL_DialogFileFilter:
        const char* name
        const char* pattern
    ctypedef void (*SDL_DialogFileCallback)(void*, const char*const*, int)
    void SDL_ShowOpenFileDialog(SDL_DialogFileCallback, void*, SDL_Window_*, SDL_DialogFileFilter*, int, const char*, bint)
    void SDL_ShowSaveFileDialog(SDL_DialogFileCallback, void*, SDL_Window_*, SDL_DialogFileFilter*, int, const char*)
    void SDL_ShowOpenFolderDialog(SDL_DialogFileCallback, void*, SDL_Window_*, const char*, bint)

cdef void dialog_callback(void *userdata,
                          const char *const*filelist,
                          int filter) noexcept nogil:
    with gil:
        dialog_callback_gil(userdata, filelist, filter)

cdef void dialog_callback_gil(void *userdata,
                          const char *const*filelist,
                          int filter):
    cdef object callback
    result = None
    if filelist != NULL:
        result = []
        while filelist[0] != NULL:
            result.append(str(<bytes>filelist[0], encoding='utf-8'))
            filelist += 1
    if userdata == NULL:
        return
    callback = <object><PyObject*>userdata
    try:
        callback(result)
    except Exception as e:
        print(traceback.format_exc())
    
def show_open_file_dialog(callback, str default_location=None, bint allow_multiple_files=False):
    """
    Open the OS file open selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected.

    default_location: optional default location
    allow_multiple_files (default to False): if True, allow
        selecting several paths which will be passed to the list
        given to the callback. If False, the list has maximum a
        single argument.
    """
    Py_INCREF(callback)
    cdef char *default_location_c = NULL
    cdef bytes default_location_array = None
    if default_location is not None:
        default_location_array = bytes(default_location, 'utf-8')
        default_location_c = <char *>default_location_array
    SDL_ShowOpenFileDialog(dialog_callback, <void*><PyObject*>callback, NULL, NULL, 0, default_location_c, allow_multiple_files)

def show_save_file_dialog(callback, str default_location=None):
    """
    Open the OS file save selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected. else, the list
    will contain a single path.

    default_location: optional default location
    """
    Py_INCREF(callback)
    cdef char *default_location_c = NULL
    cdef bytes default_location_array = None
    if default_location is not None:
        default_location_array = bytes(default_location, 'utf-8')
        default_location_c = <char *>default_location_array
    SDL_ShowSaveFileDialog(dialog_callback, <void*><PyObject*>callback, NULL, NULL, 0, default_location_c)

def show_open_folder_dialog(callback, str default_location=None, bint allow_multiple_files=False):
    """
    Open the OS directory open selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected.

    default_location: optional default location
    allow_multiple_files (default to False): if True, allow
        selecting several paths which will be passed to the list
        given to the callback. If False, the list has maximum a
        single argument.
    """
    Py_INCREF(callback)
    cdef char *default_location_c = NULL
    cdef bytes default_location_array = None
    if default_location is not None:
        default_location_array = bytes(default_location, 'utf-8')
        default_location_c = <char *>default_location_array
    SDL_ShowOpenFolderDialog(dialog_callback, <void*><PyObject*>callback, NULL, default_location_c, allow_multiple_files)


"""
To avoid linking to imgui in the other .so
"""

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

cdef void imgui_PushStyleVar2(int i, float[2] val) noexcept nogil:
    imgui.PushStyleVar(<imgui.ImGuiStyleVar>i, imgui.ImVec2(val[0], val[1]))

cdef void imgui_PopStyleVar(int count) noexcept nogil:
    imgui.PopStyleVar(count)

cdef void implot_PushStyleVar0(int i, int val) noexcept nogil:
    implot.PushStyleVar(<implot.ImPlotStyleVar>i, val)

cdef void implot_PushStyleVar1(int i, float val) noexcept nogil:
    implot.PushStyleVar(<implot.ImPlotStyleVar>i, val)

cdef void implot_PushStyleVar2(int i, float[2] val) noexcept nogil:
    implot.PushStyleVar(<implot.ImPlotStyleVar>i, imgui.ImVec2(val[0], val[1]))

cdef void implot_PopStyleVar(int count) noexcept nogil:
    implot.PopStyleVar(count)

cdef void imnodes_PushStyleVar1(int i, float val) noexcept nogil:
    imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>i, val)

cdef void imnodes_PushStyleVar2(int i, float[2] val) noexcept nogil:
    imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>i, imgui.ImVec2(val[0], val[1]))

cdef void imnodes_PopStyleVar(int count) noexcept nogil:
    imnodes.PopStyleVar(count)

cdef void imgui_SetMouseCursor(int cursor) noexcept nogil:
    # Applies only for this frame. Is reset the next frame
    imgui.SetMouseCursor(<imgui.ImGuiMouseCursor>cursor)

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
