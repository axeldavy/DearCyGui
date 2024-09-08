from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from .core cimport *

cdef class dcgWindow(dcgWindow_):
    @property
    def primary(self):
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self.mainWindow

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
        if self.mainWindow == value:
            return # Nothing to do
        self.mainWindow = value
        if value:
            # backup previous state
            self._oldWindowflags = self.windowflags
            self._oldxpos = self.pos.x
            self._oldypos = self.pos.y
            self._oldWidth = self.width
            self._oldHeight = self.height
            # Make primary
            self.windowflags = \
                imgui.ImGuiWindowFlags_NoBringToFrontOnFocus | \
                imgui.ImGuiWindowFlags_NoSavedSettings | \
			    imgui.ImGuiWindowFlags_NoResize | \
                imgui.ImGuiWindowFlags_NoCollapse | \
                imgui.ImGuiWindowFlags_NoTitleBar
        else:
            # Propagate menubar to previous state
            if (self.windowflags & imgui.ImGuiWindowFlags_MenuBar) != 0:
                self._oldWindowflags |= imgui.ImGuiWindowFlags_MenuBar
            # Restore previous state
            self.windowflags = self._oldWindowflags
            self.pos.x = self._oldxpos
            self.pos.y = self._oldypos
            self.width = self._oldWidth
            self.height = self._oldHeight
            # Tell imgui to update the window shape
            self.dirtyPos = True
            self.dirty_size = True

        # Re-tell imgui the window hierarchy
        cdef dcgWindow w = self.context.viewport.windowRoots
        cdef dcgWindow next = None
        while w is not None:
            w.mutex.lock()
            w.focusNextFrame = True
            next = w.prev_sibling
            w.mutex.unlock()
            # TODO: previous code did restore previous states on each window. Figure out why
            w = next