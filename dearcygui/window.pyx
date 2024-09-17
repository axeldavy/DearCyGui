from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from dearcygui.wrapper cimport imgui
from .core cimport *

cdef class dcgWindow(dcgWindow_):
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        remaining = {}
        for (key, value) in kwargs.items():
            if hasattr(self, key):
                setattr(self, key, value)
            # convert old flags
            elif key == "no_close":
                self.has_close_button = value
            else:
                remaining[key] = value
        super().configure(**remaining)

    @property
    def no_title_bar(self):
        """Writable attribute to disable the title-bar"""
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
        """Writable attribute to block resizing"""
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
        """Writable attribute the window to be move with interactions"""
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
        """Writable attribute to indicate the window should have no scrollbar
           Does not disable scrolling via mouse or keyboard
        """
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
        """Writable attribute to indicate the mouse wheel
           should have no effect on scrolling of this window
        """
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
        """Writable attribute to disable user collapsing window by double-clicking on it
        """
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
        """Writable attribute to tell the window should
           automatically resize to fit its content
        """
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
        """
        Writable attribute to disable drawing background
        color and outside border
        """
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
        """
        Writable attribute to never load/save settings in .ini file
        """
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
        """
        Writable attribute to disable mouse input event catching of the window.
        Events such as clicked, hovering, etc will be passed to items behind the
        window.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoMouseInputs) else False

    @no_mouse_inputs.setter
    def no_mouse_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return True if (self.window_flags & imgui.ImGuiWindowFlags_NoNav) else False

    @no_keyboard_inputs.setter
    def no_keyboard_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.window_flags &= ~imgui.ImGuiWindowFlags_NoNav
        if value:
            self.window_flags |= imgui.ImGuiWindowFlags_NoNav

    @property
    def menubar(self):
        """
        Writable attribute to indicate whether the window should have a menu bar
        """
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
        """
        Writable attribute to enable having an horizontal scrollbar
        """
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
        """
        Writable attribute to indicate when the windows moves from
        an un-shown to a shown item shouldn't be made automatically
        focused
        """
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
        """
        Writable attribute to indicate when the window takes focus (click on it, etc)
        it shouldn't be shown in front of other windows
        """
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
        """
        Writable attribute to tell to always show a vertical scrollbar
        even when the size does not require it
        """
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
        """
        Writable attribute to tell to always show a horizontal scrollbar
        even when the size does not require it (only if horizontal scrollbar
        are enabled)
        """
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
        """
        Writable attribute to display a dot next to the title, as if the window
        contains unsaved changes.
        """
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
        """
        Writable attribute to disable docking for the window
        """
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
        """
        Writable attribute for modal and popup windows to prevent them from
        showing if there is already an existing popup/modal window
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.no_open_over_existing_popup

    @no_open_over_existing_popup.setter
    def no_open_over_existing_popup(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.no_open_over_existing_popup = value

    @property
    def modal(self):
        """
        Writable attribute to indicate the window is a modal window.
        Modal windows are similar to popup windows, but they have a close
        button and are not closed by clicking outside.
        Clicking has no effect of items outside the modal window until it is closed.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.modal

    @modal.setter
    def modal(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.modal = value

    @property
    def popup(self):
        """
        Writable attribute to indicate the window is a popup window.
        Popup windows are centered (unless a pos is set), do not have a
        close button, and are closed when they lose focus (clicking outside the
        window).
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.popup

    @popup.setter
    def popup(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.popup = value

    @property
    def has_close_button(self):
        """
        Writable attribute to indicate the window has a close button.
        Has effect only for normal and modal windows.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.has_close_button and not(self.popup)

    @has_close_button.setter
    def has_close_button(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.has_close_button = value

    @property
    def collapsed(self):
        """
        Writable attribute to collapse (~minimize) or uncollapse the window
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.collapsed 

    @collapsed.setter
    def collapsed(self, bint value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.collapsed = value
        self.collapse_update_requested = True

    @property
    def on_close(self):
        """
        Callback to call when the window is closed.
        Note closing the window does not destroy or unattach the item.
        Instead it is switched to a show=False state.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.on_close_callback

    @on_close.setter
    def on_close(self, value):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.on_close_callback = value if isinstance(value, dcgCallback) or value is None else dcgCallback(value)

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
            self._width = <int>self.backup_rect_size.x
            self._height = <int>self.backup_rect_size.y
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