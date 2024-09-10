from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from dearcygui.wrapper cimport imgui
from .core cimport *

cdef class dcgWindow(dcgWindow_):
    def configure(self, **kwargs):
        remaining = {}
        for (key, value) in kwargs.items():
            if hasattr(self, key):
                setattr(self, key, value)
            else:
                remaining[key] = value
        super().configure(**remaining)

    @property
    def no_title_bar(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoTitleBar) else False

    @no_title_bar.setter
    def no_title_bar(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoTitleBar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoTitleBar

    @property
    def no_resize(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoResize) else False

    @no_resize.setter
    def no_resize(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoResize
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoResize

    @property
    def no_move(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoMove) else False

    @no_move.setter
    def no_move(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoMove
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoMove

    @property
    def no_scrollbar(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoScrollbar) else False

    @no_scrollbar.setter
    def no_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoScrollbar
    
    @property
    def no_scroll_with_mouse(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoScrollWithMouse) else False

    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoScrollWithMouse
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoScrollWithMouse

    @property
    def no_collapse(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoCollapse) else False

    @no_collapse.setter
    def no_collapse(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoCollapse
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoCollapse

    @property
    def autosize(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysAutoResize) else False

    @autosize.setter
    def autosize(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysAutoResize
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysAutoResize

    @property
    def no_background(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoBackground) else False

    @no_background.setter
    def no_background(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoBackground
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoBackground

    @property
    def no_saved_settings(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoSavedSettings) else False

    @no_saved_settings.setter
    def no_saved_settings(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoSavedSettings
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoSavedSettings

    @property
    def no_mouse_inputs(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoMouseInputs) else False

    @no_mouse_inputs.setter
    def no_mouse_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoMouseInputs
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoMouseInputs

    @property
    def menubar(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_MenuBar) else False

    @menubar.setter
    def menubar(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        # Keep this state change if the primary state is changed
        self.backup_window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_MenuBar
            self.backup_window_flags |= imgui.ImGuiWindowFlags_MenuBar

    @property
    def horizontal_scrollbar(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_HorizontalScrollbar) else False

    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_HorizontalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_HorizontalScrollbar

    @property
    def no_focus_on_appearing(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoFocusOnAppearing) else False

    @no_focus_on_appearing.setter
    def no_focus_on_appearing(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoFocusOnAppearing
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoFocusOnAppearing

    @property
    def no_bring_to_front_on_focus(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoBringToFrontOnFocus) else False

    @no_bring_to_front_on_focus.setter
    def no_bring_to_front_on_focus(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoBringToFrontOnFocus
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoBringToFrontOnFocus

    @property
    def always_show_vertical_scrollvar(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar) else False

    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar

    @property
    def always_show_horizontal_scrollvar(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar) else False

    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar

    @property
    def unsaved_document(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_UnsavedDocument) else False

    @unsaved_document.setter
    def unsaved_document(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_UnsavedDocument
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_UnsavedDocument

    @property
    def disallow_docking(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoDocking) else False

    @disallow_docking.setter
    def disallow_docking(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoDocking
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoDocking

    @property
    def no_open_over_existing_popup(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.no_open_over_existing_popup

    @no_open_over_existing_popup.setter
    def no_open_over_existing_popup(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.no_open_over_existing_popup = value

    @property
    def modal(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.modal

    @modal.setter
    def modal(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.modal = value

    @property
    def popup(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.popup

    @popup.setter
    def popup(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.popup = value

    @property
    def has_close_button(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.has_close_button and not(self.popup)

    @has_close_button.setter
    def has_close_button(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.has_close_button = value

    @property
    def collapsed(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.collapsed 

    @collapsed.setter
    def collapsed(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.collapsed = value
        self.collapse_update_requested = True

    # TODO move to uiItem ?
    @property
    def min_size(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return (self.state.rect_min.x, self.state.rect_min.y)

    @min_size.setter
    def min_size(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        assert(len(value) == 2)
        self.state.rect_min.x = value[0]
        self.state.rect_min.y = value[1]

    @property
    def max_size(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return (self.state.rect_max.x, self.state.rect_max.y)

    @max_size.setter
    def max_size(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        assert(len(value) == 2)
        self.state.rect_max.x = value[0]
        self.state.rect_max.y = value[1]

    # TODO size ?

    @property
    def on_close(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.on_close

    @on_close.setter
    def on_close(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.on_close = value

    @property
    def primary(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.main_window

    @primary.setter
    def primary(self, bint value):
        self.lock_parent_and_item_mutex()
        if self.attached and self.parent is not None:
            # Non-root window. Cannot make primary
            self.unlock_parent_mutex()
            self.mutex.unlock()
            raise ValueError("Cannot make sub-window primary")
        if not(self.attached):
            self.unlock_parent_mutex() # should have no effect
            self.mutex.unlock()
            raise ValueError("Window must be attached before becoming primary")
        # window is in viewport children
        # Move the mutexes to unique_lock for easier exception handling
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.viewport.mutex)
        self.unlock_parent_mutex()
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        if self.main_window == value:
            return # Nothing to do
        self.main_window = value
        if value:
            # backup previous state
            self.backup_window_flags = self.window_flags
            self.backup_pos = self.state.relative_position
            self.backup_rect_size = self.state.rect_size
            # Make primary
            self.window_flags = \
                imgui.ImGuiWindowFlags_NoBringToFrontOnFocus | \
                imgui.ImGuiWindowFlags_NoSavedSettings | \
			    imgui.ImGuiWindowFlags_NoResize | \
                imgui.ImGuiWindowFlags_NoCollapse | \
                imgui.ImGuiWindowFlags_NoTitleBar
        else:
            # Restore previous state
            self.window_flags = self.backup_window_flags
            self.state.relative_position = self.backup_pos
            self.width = <int>self.backup_rect_size.x
            self.height = <int>self.backup_rect_size.y
            # Tell imgui to update the window shape
            self.pos_update_requested = True
            self.size_update_requested = True

        # Re-tell imgui the window hierarchy
        cdef dcgWindow w = self.context.viewport.windowRoots
        cdef dcgWindow next = None
        while w is not None:
            w.mutex.lock()
            w.state.focused = True
            w.focus_update_requested = True
            next = w.prev_sibling
            w.mutex.unlock()
            # TODO: previous code did restore previous states on each window. Figure out why
            w = next