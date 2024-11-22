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
#cython: auto_pickle=False
#distutils: language=c++

from libcpp cimport bool
import traceback

cimport cython
cimport cython.view
from cython.operator cimport dereference
from libc.string cimport memset, memcpy

# This file is the only one that is linked to the C++ code
# Thus it is the only one allowed to make calls to it

from dearcygui.wrapper cimport *
from dearcygui.backends.backend cimport *
# We use unique_lock rather than lock_guard as
# the latter doesn't support nullary constructor
# which causes trouble to cython
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock, defer_lock_t
from dearcygui.fonts import make_extended_latin_font

from concurrent.futures import Executor, ThreadPoolExecutor
from libcpp.algorithm cimport swap
from libcpp.cmath cimport round as cround
from libcpp.set cimport set as cpp_set
from libcpp.vector cimport vector
from libc.math cimport M_PI, INFINITY
cimport dearcygui.backends.time as ctime

from .types cimport *

import os
import numpy as np
cimport numpy as cnp
cnp.import_array()

import time as python_time
import threading
import weakref


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
        item = self.last_tab_child
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
        child = self.last_tab_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_tab_child
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
                if self._parent.last_drawings_child is self:
                    self._parent.last_drawings_child = self._prev_sibling
                elif self._parent.last_handler_child is self:
                    self._parent.last_handler_child = self._prev_sibling
                elif self._parent.last_menubar_child is self:
                    self._parent.last_menubar_child = self._prev_sibling
                elif self._parent.last_plot_element_child is self:
                    self._parent.last_plot_element_child = self._prev_sibling
                elif self._parent.last_tab_child is self:
                    self._parent.last_tab_child = self._prev_sibling
                elif self._parent.last_theme_child is self:
                    self._parent.last_theme_child = self._prev_sibling
                elif self._parent.last_widgets_child is self:
                    self._parent.last_widgets_child = self._prev_sibling
                elif self._parent.last_window_child is self:
                    self._parent.last_window_child = self._prev_sibling
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

        # delete all children recursively
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).__delete_and_siblings()
        if self.last_handler_child is not None:
            (<baseItem>self.last_handler_child).__delete_and_siblings()
        if self.last_menubar_child is not None:
            (<baseItem>self.last_menubar_child).__delete_and_siblings()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).__delete_and_siblings()
        if self.last_tab_child is not None:
            (<baseItem>self.last_tab_child).__delete_and_siblings()
        if self.last_theme_child is not None:
            (<baseItem>self.last_theme_child).__delete_and_siblings()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).__delete_and_siblings()
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).__delete_and_siblings()
        # TODO: free item specific references (themes, font, etc)
        self.last_drawings_child = None
        self.last_handler_child = None
        self.last_menubar_child = None
        self.last_plot_element_child = None
        self.last_tab_child = None
        self.last_theme_child = None
        self.last_widgets_child = None
        self.last_window_child = None
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
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).__delete_and_siblings()
        if self.last_handler_child is not None:
            (<baseItem>self.last_handler_child).__delete_and_siblings()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).__delete_and_siblings()
        if self.last_tab_child is not None:
            (<baseItem>self.last_tab_child).__delete_and_siblings()
        if self.last_theme_child is not None:
            (<baseItem>self.last_theme_child).__delete_and_siblings()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).__delete_and_siblings()
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).__delete_and_siblings()
        # delete previous sibling
        if self._prev_sibling is not None:
            (<baseItem>self._prev_sibling).__delete_and_siblings()
        # Free references
        self._parent = None
        self._prev_sibling = None
        self._next_sibling = None
        self.last_drawings_child = None
        self.last_handler_child = None
        self.last_menubar_child = None
        self.last_plot_element_child = None
        self.last_tab_child = None
        self.last_theme_child = None
        self.last_widgets_child = None
        self.last_window_child = None

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
        # handlers, themes, font have no states and no children that can have some.
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
        self.skipped_last_frame = False
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

        Initializes the default font and attaches it to the
        viewport, if None is set already. This font size is scaled
        to be sharp at the target value of viewport.dpi * viewport.scale.
        See FontTexture for how to update the default font
        to a different size or to account for viewport.dpi or
        viewport.scale changes.
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
        cdef float global_scale = self.viewport.dpi * self._scale
        if self._font is None:
            default_font_texture = FontTexture(self.context)
            h, c_i, c_p = make_extended_latin_font(round(17*global_scale))
            default_font_texture.add_custom_font(h, c_i, c_p)
            default_font_texture.build()
            self._font = default_font_texture[0]
            self._font.scale = 1./global_scale
        self.initialized = True
        imgui.GetIO().IniFilename = NULL
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
        Change the mouse cursor to one of MouseCursor.
        The mouse cursor is reset every frame.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <MouseCursor>self._cursor

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
        self.redraw_needed = False
        self.shifts = [0., 0.]
        self.scales = [1., 1.]
        self.in_plot = False
        self.start_pending_theme_actions = 0
        #if self.filedialogRoots is not None:
        #    self.filedialogRoots.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        self.parent_pos = imgui.ImVec2(0., 0.)
        self.window_pos = imgui.ImVec2(0., 0.)
        imgui.PushID(self.uuid)
        draw_menubar_children(self)
        draw_window_children(self)
        #if self.last_viewport_drawlist_child is not None:
        #    self.last_viewport_drawlist_child.draw(<imgui.ImDrawList*>NULL, 0., 0.)
        imgui.PopID()
        if self._theme is not None:
            self._theme.pop()
        if self._font is not None:
            self._font.pop()
        self.run_handlers()
        self.last_t_after_rendering = ctime.monotonic_ns()
        if self.redraw_needed:
            self.viewport.needs_refresh.store(True)
            self.viewport.shouldSkipPresenting = True
            # Skip presenting frames if we can afford
            # it and redraw fast hoping for convergence
            if not(self.skipped_last_frame):
                self.t_first_skip = self.last_t_after_rendering
                self.skipped_last_frame = True
            elif (self.last_t_after_rendering - self.t_first_skip) > 1e7:
                # 10 ms elapsed, redraw even if might not be perfect
                self.skipped_last_frame = False
                self.viewport.shouldSkipPresenting = False
        else:
            if self.skipped_last_frame:
                # probably not needed
                self.viewport.needs_refresh.store(True)
            self.skipped_last_frame = False
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
                                         ThemeEnablers theme_activation_condition_enabled,
                                         ThemeCategories theme_activation_condition_category) noexcept nogil:
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
        cdef ThemeEnablers theme_activation_condition_enabled = self.current_theme_activation_condition_enabled
        cdef ThemeCategories theme_activation_condition_category = self.current_theme_activation_condition_category

        cdef bool apply
        for i in range(start, end):
            apply = True
            if self.pending_theme_actions[i].activation_condition_enabled != ThemeEnablers.ANY and \
               theme_activation_condition_enabled != ThemeEnablers.ANY and \
               self.pending_theme_actions[i].activation_condition_enabled != theme_activation_condition_enabled:
                apply = False
            if self.pending_theme_actions[i].activation_condition_category != theme_activation_condition_category and \
               self.pending_theme_actions[i].activation_condition_category != ThemeCategories.t_any:
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


# Callbacks


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
        self.can_have_plot_element_child = True
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

# Drawing items base class

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

    cdef void draw(self, imgui.ImDrawList* l) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return


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
        return

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
        if not(self._enabled):
            return
        if self.check_state(item):
            self.run_callback(item)

    cdef void run_callback(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.queue_callback_arg1obj(self._callback, self, item, item)


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
        self.requested_size = imgui.ImVec2(0., 0.)
        self.dpi_scaling = True
        self._indent = 0.
        self.theme_condition_enabled = ThemeEnablers.TRUE
        self.theme_condition_category = ThemeCategories.t_any
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_widget
        self.state.cap.has_position = True # ALL widgets have position
        self.state.cap.has_rect_size = True # ALL items have a rectangle size
        self.p_state = &self.state
        self._pos_policy = [Positioning.DEFAULT, Positioning.DEFAULT]
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
        self.theme_condition_enabled = ThemeEnablers.TRUE if value else ThemeEnablers.FALSE
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
            self._pos_policy[0] = Positioning.REL_VIEWPORT
        if y is not None:
            self.state.cur.pos_to_viewport.y = y
            self._pos_policy[1] = Positioning.REL_VIEWPORT
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
            self._pos_policy[0] = Positioning.REL_WINDOW
        if y is not None:
            self.state.cur.pos_to_window.y = y
            self._pos_policy[1] = Positioning.REL_WINDOW
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
            self._pos_policy[0] = Positioning.REL_PARENT
        if y is not None:
            self.state.cur.pos_to_parent.y = y
            self._pos_policy[1] = Positioning.REL_PARENT
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
            self._pos_policy[0] = Positioning.REL_DEFAULT
        if y is not None:
            self.state.cur.pos_to_default.y = y
            self._pos_policy[1] = Positioning.REL_DEFAULT
        self.pos_update_requested = True

    @pos_policy.setter
    def pos_policy(self, Positioning value):
        policies = [
            Positioning.DEFAULT,
            Positioning.REL_DEFAULT,
            Positioning.REL_PARENT,
            Positioning.REL_WINDOW,
            Positioning.REL_VIEWPORT
        ]
        if hasattr(value, "__len__"):
            (x, y) = value
            if x not in policies or y not in policies:
                raise ValueError("Invalid Positioning policy")
            self._pos_policy[0] = x
            self._pos_policy[1] = y
            self.pos_update_requested = True
        else:
            if value not in policies:
                raise ValueError("Invalid Positioning policy")
            self._pos_policy[0] = value
            self._pos_policy[1] = value
            self.pos_update_requested = True

    @height.setter
    def height(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.y = <float>value
        self.size_update_requested = True

    @width.setter
    def width(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.x = <float>value
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

        cdef Positioning[2] policy = self._pos_policy
        cdef imgui.ImVec2 pos = cursor_pos_backup

        if policy[0] == Positioning.REL_DEFAULT:
            pos.x += self.state.cur.pos_to_default.x
        elif policy[0] == Positioning.REL_PARENT:
            pos.x = self.context._viewport.parent_pos.x + self.state.cur.pos_to_parent.x
        elif policy[0] == Positioning.REL_WINDOW:
            pos.x = self.context._viewport.window_pos.x + self.state.cur.pos_to_window.x
        elif policy[0] == Positioning.REL_VIEWPORT:
            pos.x = self.state.cur.pos_to_viewport.x
        # else: DEFAULT

        if policy[1] == Positioning.REL_DEFAULT:
            pos.y += self.state.cur.pos_to_default.y
        elif policy[1] == Positioning.REL_PARENT:
            pos.y = self.context._viewport.parent_pos.y + self.state.cur.pos_to_parent.y
        elif policy[1] == Positioning.REL_WINDOW:
            pos.y = self.context._viewport.window_pos.y + self.state.cur.pos_to_window.y
        elif policy[1] == Positioning.REL_VIEWPORT:
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
        if policy[0] == Positioning.REL_DEFAULT or \
           policy[0] == Positioning.DEFAULT:
            pos.x = imgui.GetCursorScreenPos().x

        if policy[1] == Positioning.REL_DEFAULT or \
           policy[1] == Positioning.DEFAULT:
            pos.y = imgui.GetCursorScreenPos().y

        imgui.SetCursorScreenPos(pos)

        if indent > 0.:
            imgui.Unindent(indent)
        elif indent < 0:
            imgui.Unindent(0)

        # Note: not affected by the Unindent.
        if self._no_newline and \
           (policy[1] == Positioning.REL_DEFAULT or \
            policy[1] == Positioning.DEFAULT):
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
Complex ui items
"""


cdef class TimeWatcher(uiItem):
    """
    A placeholder uiItem parent that doesn't draw
    or have any impact on rendering.
    This item calls the callback with times in ns.
    These times can be compared with the times in the metrics
    that can be obtained from the viewport in order to
    precisely figure out the time spent rendering specific items.

    The first time corresponds to the time this item is called
    for rendering

    The second time corresponds to the time after the
    children have finished rendering.

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
        self.can_have_widget_child = True

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef long long time_start = ctime.monotonic_ns()
        draw_ui_children(self)
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
        self.theme_condition_category = ThemeCategories.t_window
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
            imgui.SetNextWindowPos(self.state.cur.pos_to_viewport, imgui.ImGuiCond_Always)
            self.pos_update_requested = False

        if self.size_update_requested:
            imgui.SetNextWindowSize(self.scaled_requested_size(),
                                    imgui.ImGuiCond_Always)
            self.size_update_requested = False

        if self.collapse_update_requested:
            imgui.SetNextWindowCollapsed(not(self.state.cur.open), imgui.ImGuiCond_Always)
            self.collapse_update_requested = False

        cdef imgui.ImVec2 min_size = self.min_size
        cdef imgui.ImVec2 max_size = self.max_size
        if self.dpi_scaling:
            min_size.x *= self.context._viewport.global_scale
            min_size.y *= self.context._viewport.global_scale
            max_size.x *= self.context._viewport.global_scale
            max_size.y *= self.context._viewport.global_scale
        imgui.SetNextWindowSizeConstraints(min_size, max_size)

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
            # No transparency
            imgui.SetNextWindowBgAlpha(1.0)
            #to prevent main window corners from showing
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowRounding, 0.0)
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowPadding, imgui.ImVec2(0.0, 0.))
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowBorderSize, 0.)
            imgui.SetNextWindowPos(imgui.ImVec2(0.0, 0.0), imgui.ImGuiCond_Always)
            imgui.SetNextWindowSize(imgui.ImVec2(<float>self.context._viewport.viewport.actualWidth,
                                           <float>self.context._viewport.viewport.actualHeight),
                                    imgui.ImGuiCond_Always)

        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        self.context._viewport.push_pending_theme_actions(
            ThemeEnablers.ANY,
            ThemeCategories.t_window
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

        if self.main_window:
            # To not affect children.
            # the styles are used in Begin() only
            imgui.PopStyleVar(3)

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

            draw_ui_children(self)
            # TODO if self.children_widgets[i].tracked and show:
            #    imgui.SetScrollHereY(self.children_widgets[i].trackOffset)

            draw_menubar_children(self)

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
        # The sizing of windows might not converge right away
        if self.state.cur.content_region_size.x != self.state.prev.content_region_size.x or \
           self.state.cur.content_region_size.y != self.state.prev.content_region_size.y:
            self.context._viewport.redraw_needed = True


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
        return

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

    In order to have sharp fonts with various screen
    dpi scalings, two options are available:
    1) Handle scaling yourself:
        Whenever the global scale changes, make
        a new font using a scaled size, and
        set no_scaling to True
    2) Handle scaling yourself at init only:
        In most cases it is reasonnable to
        assume the dpi scale will not change.
        In that case the easiest is to check
        the viewport dpi scale after initialization,
        load the scaled font size, and then set
        font.scale to the inverse of the dpi scale.
        This will render at the intended size
        as long as the dpi scale is not changed,
        and will scale if it changes (but will be
        slightly blurry).

    Currently the default font uses option 2). Call
    fonts.make_extended_latin_font(your_size) and
    add_custom_font to get the default font at a different
    scale, and implement 1) or 2) yourself.
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
                      float density_scale=1.,
                      bint align_to_pixel=False):
        """
        Prepare the target font file to be added to the FontTexture,
        using ImGui's font loader.

        path: path to the input font file (ttf, otf, etc).
        size: Target pixel size at which the font will be rendered by default.
        index_in_file: index of the target font in the font file.
        density_scale: rasterizer oversampling to better render when
            the font scale is not 1. Not a miracle solution though,
            as it causes blurry inputs if the actual scale used
            during rendering is less than density_scale.
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
        config.OversampleH = 1
        config.OversampleV = 1
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

    def add_custom_font(self,
                        font_height,
                        character_images,
                        character_Positioning):
        """
        See fonts.py for a detailed explanation of
        the input arguments.

        Currently add_custom_font calls build()
        and thus prevents adding new fonts, but
        this might not be true in the future, thus
        you should still call build().
        """
        if self._built:
            raise ValueError("Cannot add Font to built FontTexture")

        cdef imgui.ImFontConfig config = imgui.ImFontConfig()
        config.SizePixels = font_height
        config.FontDataOwnedByAtlas = False
        config.OversampleH = 1
        config.OversampleV = 1

        # Imgui currently requires a font
        # to be able to add custom glyphs
        cdef imgui.ImFont *font = \
            self.atlas.AddFontDefault(&config)

        keys = sorted(character_images.keys())
        # TODO check keys are identical
        cdef float x, y, advance
        cdef int w, h, i, j
        for i, key in enumerate(keys):
            image = character_images[key]
            h = image.shape[0] + 1
            w = image.shape[1] + 1
            (y, x, advance) = character_Positioning[key]
            j = self.atlas.AddCustomRectFontGlyph(font,
                                             int(key),
                                             w, h,
                                             advance,
                                             imgui.ImVec2(x, y))
            assert(j == i)

        cdef Font font_object = Font(self.context)
        font_object.container = self
        font_object.font = font
        self.fonts.append(font_object)

        # build
        if not(self.atlas.Build()):
            raise RuntimeError("Failed to build target texture data")
        # Retrieve the target buffer
        cdef unsigned char *data = NULL
        cdef int width, height, bpp
        cdef bint use_color = False
        for image in character_images.values():
            if len(image.shape) == 2 and image.shape[2] > 1:
                if image.shape[2] != 4:
                    raise ValueError("Color data must be rgba (4 channels)")
                use_color = True
        if self.atlas.TexPixelsUseColors or use_color:
            self.atlas.GetTexDataAsRGBA32(&data, &width, &height, &bpp)
        else:
            self.atlas.GetTexDataAsAlpha8(&data, &width, &height, &bpp)

        # write our font characters at the target location
        cdef cython.view.array data_array = cython.view.array(shape=(height, width, bpp), itemsize=1, format='B', mode='c', allocate_buffer=False)
        data_array.data = <char*>data
        array = np.asarray(data_array, dtype=np.uint8)
        cdef imgui.ImFontAtlasCustomRect *rect
        cdef int ym, yM, xm, xM
        if len(array.shape) == 2:
            array = array[:,:,np.newaxis]
        cdef unsigned char[:,:,:] array_view = array
        cdef unsigned char[:,:,:] src_view
        for i, key in enumerate(keys):
            rect = self.atlas.GetCustomRectByIndex(i)
            ym = rect.Y
            yM = rect.Y + rect.Height
            xm = rect.X
            xM = rect.X + rect.Width
            src_view = character_images[key]
            array_view[ym:(yM-1), xm:(xM-1),:] = src_view[:,:,:]
            array_view[yM-1, xm:xM,:] = 0
            array_view[ym:yM, xM-1,:] = 0

        # Upload texture
        if use_color:
            self._texture.filtering_mode = 0 # rgba bilinear
        else:
            self._texture.filtering_mode = 2 # 111A bilinear
        self._texture.set_value(array)
        assert(self._texture.allocated_texture != NULL)
        self._texture.readonly = True
        self.atlas.SetTexID(<imgui.ImTextureID>self._texture.allocated_texture)

        # Release temporary CPU memory
        self.atlas.ClearInputData()
        self._built = True

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

