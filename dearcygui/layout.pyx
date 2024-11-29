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

cimport cython
from cpython.ref cimport PyObject

from dearcygui.wrapper cimport imgui
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from libcpp.algorithm cimport swap
from libcpp.cmath cimport floor

from .core cimport uiItem, Callback, lock_gil_friendly
from .types cimport *

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
        self.theme_condition_category = ThemeCategories.t_layout
        self.prev_content_area.x = 0
        self.prev_content_area.y = 0
        self.previous_last_child = NULL

    def update_layout(self):
        cdef int i
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        for i in range(<int>self._callbacks.size()):
            self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

    # final enables inlining
    @cython.final
    cdef imgui.ImVec2 get_content_area(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        cdef float global_scale = self.context._viewport.global_scale
        if not(self.dpi_scaling):
            global_scale = 1.

        if self.requested_size.x > 0:
            if self.requested_size.x < 1.:
                # percentage of available space
                cur_content_area.x = floor(cur_content_area.x * self.requested_size.x)
            else:
                # direct size.
                cur_content_area.x = floor(global_scale * self.requested_size.x)
        # 0 means default, which is full available size
        elif self.requested_size.x < 0:
            # negative size: subtraction from available size
            cur_content_area.x = floor(cur_content_area.x + global_scale * self.requested_size.x)

        if self.requested_size.y > 0:
            if self.requested_size.y < 1.:
                cur_content_area.y = floor(cur_content_area.y * self.requested_size.y)
            else:
                cur_content_area.y = floor(global_scale * self.requested_size.y)
        elif self.requested_size.y < 0:
            cur_content_area.y = floor(cur_content_area.y + global_scale * self.requested_size.y)
        cur_content_area.x = max(0, cur_content_area.x)
        cur_content_area.y = max(0, cur_content_area.y)
        return cur_content_area

    cdef bint check_change(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = self.get_content_area()
        cdef imgui.ImVec2 cur_spacing = imgui.GetStyle().ItemSpacing
        cdef bint changed = False
        if cur_content_area.x != self.prev_content_area.x or \
           cur_content_area.y != self.prev_content_area.y or \
           self.previous_last_child != <PyObject*>self.last_widgets_child or \
           cur_spacing.x != self.spacing.x or \
           cur_spacing.y != self.spacing.y or \
           self.size_update_requested or \
           self.force_update: # TODO: check spacing too
            changed = True
            self.prev_content_area = cur_content_area
            self.spacing = cur_spacing
            self.previous_last_child = <PyObject*>self.last_widgets_child
            self.force_update = False
            self.size_update_requested = False
        return changed

    @cython.final
    cdef void draw_child(self, uiItem child) noexcept nogil:
        child.draw()
        if child.state.cur.rect_size.x != child.state.prev.rect_size.x or \
           child.state.cur.rect_size.y != child.state.prev.rect_size.y:
            child.context._viewport.redraw_needed = True
            self.force_update = True

    @cython.final
    cdef void draw_children(self) noexcept nogil:
        """
        Similar to draw_ui_children, but detects
        any change relative to expected sizes
        """
        if self.last_widgets_child is None:
            return
        cdef PyObject *child = <PyObject*> self.last_widgets_child
        while (<uiItem>child)._prev_sibling is not None:
            child = <PyObject *>(<uiItem>child)._prev_sibling
        while (<uiItem>child) is not None:
            self.draw_child(<uiItem>child)
            child = <PyObject *>(<uiItem>child)._next_sibling

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = self.get_content_area() # TODO: pass to the callback ? Or set as state ?
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
            self.draw_children()
            self.context._viewport.parent_pos = pos_p
        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                       imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        return changed

cdef class HorizontalLayout(Layout):
    """
    A basic layout to organize the items
    horizontally.
    """
    def __cinit__(self):
        self._alignment_mode = Alignment.LEFT

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

        FOR LEFT/RIGHT/CENTER, ItemSpacing's style can
        be used to control spacing between the items.
        Default is LEFT.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @alignment_mode.setter
    def alignment_mode(self, Alignment value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if <int>value < 0 or value > Alignment.MANUAL:
            raise ValueError("Invalid alignment value")
        if value == self._alignment_mode:
            return
        self.force_update = True
        self._alignment_mode = value

    @property
    def no_wrap(self):
        """
        Disable wrapping to the next row when the
        elements cannot fit in the available region.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_wrap

    @no_wrap.setter
    def no_wrap(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value == self._no_wrap:
            return
        self.force_update = True
        self._no_wrap = value

    @property
    def wrap_x(self):
        """
        When wrapping, on the second row and later rows,
        start from the wrap_x position relative to the
        starting position. Note the value is in pixel value
        and you must scale it if needed. The wrapping position
        is clamped such that you always start at a position >= 0
        relative to the window content area, thus passing
        a significant negative value will bring back to
        the start of the window.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._wrap_x

    @wrap_x.setter
    def wrap_x(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._wrap_x = value

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
        if len(value) > 0:
            self._alignment_mode = Alignment.MANUAL
        # TODO: checks
        self._positions.clear()
        for v in value:
            self._positions.push_back(v)
        self.force_update = True

    def update_layout(self):
        """
        Force an update of the layout next time the scene
        is rendered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.force_update = True

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

    cdef void __update_layout(self) noexcept nogil:
        # Assumes all children are locked
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        cdef float end_x = self.prev_content_area.x
        cdef float available_width = end_x
        #cdef float available_height = self.prev_content_area.y
        cdef float spacing_x = self.spacing.x
        cdef float spacing_y = self.spacing.y
        # Get back to the first child
        while ((<uiItem>child)._prev_sibling) is not None:
            child = <PyObject*>((<uiItem>child)._prev_sibling)
        cdef PyObject *sibling
        cdef int i, n_items_this_row, row
        cdef float target_x, expected_x, expected_size, expected_size_next
        cdef float y, next_y = 0
        cdef float wrap_x = max(-self.state.cur.pos_to_window.x, self._wrap_x)
        cdef bint pos_change = False
        row = 0
        while (<uiItem>child) is not None:
            # Compute the number of items on this row
            if row == 1:
                # starting from the second row, begin to wrap at the target
                available_width -= wrap_x
            y = next_y
            n_items_this_row = 1
            expected_size = (<uiItem>child).state.cur.rect_size.x
            next_y = (<uiItem>child).state.cur.rect_size.y
            sibling = child
            while (<uiItem>sibling)._next_sibling is not None:
                # Does the next item fit ?
                expected_size_next = expected_size + self.spacing.x + \
                    (<uiItem>(<uiItem>sibling)._next_sibling).state.cur.rect_size.x
                # No: stop there
                if expected_size_next > available_width and not(self._no_wrap):
                    break
                expected_size = expected_size_next
                next_y = max(next_y, y + (<uiItem>sibling).state.cur.rect_size.y)
                sibling = <PyObject*>(<uiItem>sibling)._next_sibling
                n_items_this_row += 1
            next_y = next_y + spacing_y

            # Determine the element positions
            sibling = child
            """
            if self._alignment_mode == Alignment.LEFT:
                for i in range(n_items_this_row-1):
                    (<uiItem>sibling)._pos_policy[0] = Positioning.DEFAULT # TODO: MOVE to rel parent
                    (<uiItem>sibling)._no_newline = True
                    sibling = <PyObject*>(<uiItem>sibling)._next_sibling
                (<uiItem>sibling)._pos_policy[0] = Positioning.DEFAULT
                (<uiItem>sibling)._no_newline = False
            """
            if self._alignment_mode == Alignment.LEFT:
                target_x = 0 if row == 0 else wrap_x
            elif self._alignment_mode == Alignment.RIGHT:
                target_x = end_x - expected_size
            elif self._alignment_mode == Alignment.CENTER:
                # Center right away (not waiting the second row) with wrap_x
                target_x = (end_x + wrap_x) // 2 - \
                    expected_size // 2 # integer rounding to avoid blurring
            elif self._alignment_mode == Alignment.JUSTIFIED:
                target_x = 0 if row == 0 else wrap_x
                # Increase spacing to fit target space
                spacing_x = self.spacing.x + \
                    max(0, \
                        floor((available_width - expected_size) /
                               (n_items_this_row-1)))

            # Important for auto fit windows
            target_x = max(0 if row == 0 else wrap_x, target_x)

            expected_x = 0
            for i in range(n_items_this_row-1):
                (<uiItem>sibling).state.cur.pos_to_default.x = target_x - expected_x
                pos_change |= (<uiItem>sibling).state.cur.pos_to_default.x != (<uiItem>sibling).state.prev.pos_to_default.x
                (<uiItem>sibling)._pos_policy[0] = Positioning.REL_DEFAULT
                (<uiItem>sibling)._pos_policy[1] = Positioning.DEFAULT
                (<uiItem>sibling)._no_newline = True
                expected_x = target_x + self.spacing.x + (<uiItem>sibling).state.cur.rect_size.x
                target_x = target_x + spacing_x + (<uiItem>sibling).state.cur.rect_size.x
                sibling = <PyObject*>(<uiItem>sibling)._next_sibling
            # Last item of the row
            if (self._alignment_mode == Alignment.RIGHT or \
               (self._alignment_mode == Alignment.JUSTIFIED and n_items_this_row != 1)) and \
               (<uiItem>child).state.cur.rect_size.x == (<uiItem>child).state.prev.rect_size.x:
                # Align right item properly even if rounding
                # occured on spacing.
                # We check the item size is fixed because if the item tries to autosize
                # to the available content, it can lead to convergence issues
                # undo previous spacing
                target_x -= spacing_x
                # ideal spacing
                spacing_x = \
                    end_x - (target_x + (<uiItem>sibling).state.cur.rect_size.x)
                # real spacing
                target_x += max(spacing_x, self.spacing.x)

            (<uiItem>sibling).state.cur.pos_to_default.x = target_x - expected_x
            pos_change |= (<uiItem>sibling).state.cur.pos_to_default.x != (<uiItem>sibling).state.prev.pos_to_default.x
            (<uiItem>sibling)._pos_policy[0] = Positioning.REL_DEFAULT
            (<uiItem>sibling)._pos_policy[1] = Positioning.DEFAULT
            (<uiItem>sibling)._no_newline = False
            child = <PyObject*>(<uiItem>sibling)._next_sibling
            row += 1
        # A change in position change alter the size for some items
        if pos_change:
            self.force_update = True
            self.context._viewport.redraw_needed = True


    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        if self.last_widgets_child is None:# or \
            #cur_content_area.x <= 0 or \
            #cur_content_area.y <= 0: # <= 0 occurs when not visible
            # self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            return False
        cdef bint changed = self.check_change()
        if changed:
            self.last_widgets_child.lock_and_previous_siblings()
            self.__update_layout()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef imgui.ImVec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = imgui.GetCursorScreenPos()
            swap(pos_p, self.context._viewport.parent_pos)
            self.draw_children()
            self.context._viewport.parent_pos = pos_p
        if changed:
            # We maintain the lock during the rendering
            # just to be sure the user doesn't change the
            # Positioning we took care to manage :-)
            self.last_widgets_child.unlock_and_previous_siblings()
        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                   imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        if self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
           self.state.cur.rect_size.y != self.state.prev.rect_size.y:
            self.force_update = True
            self.context._viewport.redraw_needed = True
        return changed


cdef class VerticalLayout(Layout):
    """
    Same as HorizontalLayout but vertically
    """
    def __cinit__(self):
        self._alignment_mode = Alignment.TOP

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

        FOR TOP/BOTTOM/CENTER, ItemSpacing's style can
        be used to control spacing between the items.
        Default is TOP.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @alignment_mode.setter
    def alignment_mode(self, Alignment value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if <int>value < 0 or value > Alignment.MANUAL:
            raise ValueError("Invalid alignment value")
        self._alignment_mode = value

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
        if len(value) > 0:
            self._alignment_mode = Alignment.MANUAL
        # TODO: checks
        self._positions.clear()
        for v in value:
            self._positions.push_back(v)

    def update_layout(self):
        """
        Force an update of the layout next time the scene
        is rendered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.force_update = True

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
            (<uiItem>child)._pos_policy[1] = Positioning.REL_PARENT
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
        if self._alignment_mode == Alignment.TOP:
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                (<uiItem>child)._pos_policy[1] = Positioning.REL_DEFAULT
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == Alignment.RIGHT:
            pos_end = available_height
            child = <PyObject*>self.last_widgets_child
            while (<uiItem>child) is not None:
                # Position at which to render to end at pos_end
                target_pos = pos_end - (<uiItem>child).state.cur.rect_size.y
                (<uiItem>child).state.cur.pos_to_parent.y = target_pos
                pos_end = target_pos - self._spacing
                child = <PyObject*>((<uiItem>child)._prev_sibling)
        elif self._alignment_mode == Alignment.CENTER:
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
        elif self._alignment_mode == Alignment.JUSTIFIED:
            size = self.__compute_items_size(n_items)
            if n_items == 1:
                # prefer to revert to align top
                self.last_widgets_child._pos_policy[1] = Positioning.DEFAULT
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
            self.context._viewport.redraw_needed = True

    cdef bint check_change(self) noexcept nogil:
        # Same as Layout check_change but ignores horizontal content
        # area changes
        cdef imgui.ImVec2 cur_content_area = imgui.GetContentRegionAvail()
        cdef float cur_spacing = imgui.GetStyle().ItemSpacing.y
        cdef bint changed = False
        if cur_content_area.y != self.prev_content_area.y or \
           self.previous_last_child != <PyObject*>self.last_widgets_child or \
           self.size_update_requested or \
           self._spacing != cur_spacing or \
           self.force_update:
            changed = True
            self.prev_content_area = cur_content_area
            self.previous_last_child = <PyObject*>self.last_widgets_child
            self._spacing = cur_spacing
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
        if changed:
            self.last_widgets_child.lock_and_previous_siblings()
            self.__update_layout()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef imgui.ImVec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = imgui.GetCursorScreenPos()
            swap(pos_p, self.context._viewport.parent_pos)
            self.draw_children()
            self.context._viewport.parent_pos = pos_p
        if changed:
            # We maintain the lock during the rendering
            # just to be sure the user doesn't change the
            # positioning we took care to manage :-)
            self.last_widgets_child.unlock_and_previous_siblings()
        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                   imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        if self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
           self.state.cur.rect_size.y != self.state.prev.rect_size.y:
            self.context._viewport.redraw_needed = True
        return changed