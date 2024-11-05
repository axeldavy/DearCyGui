
from libcpp.cmath cimport round
from libcpp.unordered_map cimport unordered_map, pair
from libcpp.string cimport string
from dearcygui.wrapper cimport imgui, implot, imnodes
cimport cython
from cython.operator cimport dereference
from .core cimport *
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from cpython cimport PyObject_GenericSetAttr

cdef class ThemeColorImGui(baseTheme):
    """
    Theme color parameters that affect how ImGui
    renders items.
    All colors accept three formats:
    - unsigned (encodes a rgba little-endian)
    - (r, g, b, a) with r, g, b, a as integers.
    - (r, g, b, a) with r, g, b, a as floats.

    When r, g, b, a are floats, they should be normalized
    between 0 and 1, while integers are between 0 and 255.
    If a is missing, it defaults to 255.

    Keyword Arguments:
        Text: Color for text rendering
        TextDisabled: Color for the text of disabled items
        WindowBg: Background of normal windows
        ChildBg:  Background of child windows
        PopupBg: Background of popups, menus, tooltips windows
        Border: Color of borders
        BorderShadow: Color of border shadows
        FrameBg: Background of checkbox, radio button, plot, slider, text input
        FrameBgHovered: Color of FrameBg when the item is hovered
        FrameBgActive: Color of FrameBg when the item is active
        TitleBg: Title bar
        TitleBgActive: Title bar when focused
        TitleBgCollapsed: Title bar when collapsed
        MenuBarBg: Background color of the menu bar
        ScrollbarBg: Background color of the scroll bar
        ScrollbarGrab: Color of the scroll slider
        ScrollbarGrabHovered: Color of the scroll slider when hovered
        ScrollbarGrabActive: Color of the scroll slider when selected
        CheckMark: Checkbox tick and RadioButton circle
        SliderGrab: Color of sliders
        SliderGrabActive: Color of selected sliders
        Button: Color of buttons
        ButtonHovered: Color of buttons when hovered
        ButtonActive: Color of buttons when selected
        Header: Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
        HeaderHovered: Header color when hovered
        HeaderActive: Header color when clicked
        Separator: Color of separators
        SeparatorHovered: Color of separator when hovered
        SeparatorActive: Color of separator when active
        ResizeGrip: Resize grip in lower-right and lower-left corners of windows.
        ResizeGripHovered: ResizeGrip when hovered
        ResizeGripActive: ResizeGrip when clicked
        TabHovered: Tab background, when hovered
        Tab: Tab background, when tab-bar is focused & tab is unselected
        TabSelected: Tab background, when tab-bar is focused & tab is selected
        TabSelectedOverline: Tab horizontal overline, when tab-bar is focused & tab is selected
        TabDimmed: Tab background, when tab-bar is unfocused & tab is unselected
        TabDimmedSelected: Tab background, when tab-bar is unfocused & tab is selected
        TabDimmedSelectedOverline: ..horizontal overline, when tab-bar is unfocused & tab is selected
        PlotLines: Color of SimplePlot lines
        PlotLinesHovered: Color of SimplePlot lines when hovered
        PlotHistogram: Color of SimplePlot histogram
        PlotHistogramHovered: Color of SimplePlot histogram when hovered
        TableHeaderBg: Table header background
        TableBorderStrong: Table outer and header borders (prefer using Alpha=1.0 here)
        TableBorderLight: Table inner borders (prefer using Alpha=1.0 here)
        TableRowBg: Table row background (even rows)
        TableRowBgAlt: Table row background (odd rows)
        TextLink: Hyperlink color
        TextSelectedBg: Color of the background of selected text
        DragDropTarget: Rectangle highlighting a drop target
        NavHighlight: Gamepad/keyboard: current highlighted item
        NavWindowingHighlight: Highlight window when using CTRL+TAB
        NavWindowingDimBg: Darken/colorize entire screen behind the CTRL+TAB window list, when active
        ModalWindowDimBg: Darken/colorize entire screen behind a modal window, when one is active
    """

    def __cinit__(self):
        cdef int i
        cdef string col_name
        for i in range(imgui.ImGuiCol_COUNT):
            col_name = string(imgui_GetStyleColorName(i))
            self.name_to_index[col_name] = i

    def __dir__(self):
        cdef list results = []
        cdef int i
        cdef str name
        for i in range(imgui.ImGuiCol_COUNT):
            name = str(imgui_GetStyleColorName(i), encoding='utf-8')
            results.append(name)
        return results + dir(baseTheme)

    def __getattr__(self, name):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Color %s not found" % name)
        cdef int color_index = dereference(element).second
        cdef unordered_map[int, imgui.ImU32].iterator element_content = self.index_to_value.find(color_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImU32 value = dereference(element_content).second
        # TODO: maybe use unparse_color
        return value

    def __getitem__(self, key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int color_index
        cdef unordered_map[int, imgui.ImU32].iterator element_content
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Color %s not found" % key)
            color_index = dereference(element).second
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= imgui.ImGuiCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        element_content = self.index_to_value.find(color_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImU32 value = dereference(element_content).second
        return value

    def __setattr__(self, name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint found
        cdef string name_str
        cdef unordered_map[string, int].iterator element
        try:
            name_str = bytes(name, 'utf-8')
            element = self.name_to_index.find(name_str)
            found = element != self.name_to_index.end()
        except Exception:
            found = False
        if not(found):
            PyObject_GenericSetAttr(self, name, value)
            return
        cdef int color_index = dereference(element).second
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __setitem__(self, key, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int color_index
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Color %s not found" % key)
            color_index = dereference(element).second
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= imgui.ImGuiCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __iter__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int, imgui.ImU32] element_content
        cdef str name
        for element_content in self.index_to_value:
            name = str(imgui_GetStyleColorName(element_content.first), encoding='utf-8')
            result.append((name, int(element_content.second)))
        return iter(result)

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if not(self.enabled):
            self.last_push_size.push_back(0)
            return
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            # Note: imgui seems to convert U32 for this. Maybe use float4
            imgui_PushStyleColor(element_content.first, element_content.second)
        self.last_push_size.push_back(<int>self.index_to_value.size())

    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef pair[int, imgui.ImU32] element_content
        cdef theme_action action
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push_to_list(v)
        if not(self.enabled):
            return
        for element_content in self.index_to_value:
            action.activation_condition_enabled = theme_enablers.t_enabled_any
            action.activation_condition_category = theme_categories.t_any
            action.type = theme_types.t_color
            action.backend = theme_backends.t_imgui
            action.theme_index = element_content.first
            action.value_type = theme_value_types.t_u32
            action.value.value_u32 = element_content.second
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            imgui_PopStyleColor(count)
        if self._prev_sibling is not None:
            # Note: we are guaranteed to have the same
            # siblings than during push()
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()

@cython.no_gc_clear
cdef class ThemeColorImPlot(baseTheme):
    def __cinit__(self):
        cdef int i
        cdef string col_name
        for i in range(implot.ImPlotCol_COUNT):
            col_name = string(implot_GetStyleColorName(i))
            self.name_to_index[col_name] = i

    def __dir__(self):
        cdef list results = []
        cdef int i
        cdef str name
        for i in range(implot.ImPlotCol_COUNT):
            name = str(implot_GetStyleColorName(i), encoding='utf-8')
            results.append(name)
        return results + dir(baseTheme)

    def __getattr__(self, name):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Color %s not found" % name)
        cdef int color_index = dereference(element).second
        cdef unordered_map[int, imgui.ImU32].iterator element_content = self.index_to_value.find(color_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImU32 value = dereference(element_content).second
        return value

    def __getitem__(self, key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int color_index
        cdef unordered_map[int, imgui.ImU32].iterator element_content
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Color %s not found" % key)
            color_index = dereference(element).second
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= implot.ImPlotCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        element_content = self.index_to_value.find(color_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImU32 value = dereference(element_content).second
        return value

    def __setattr__(self, name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint found
        cdef string name_str
        cdef unordered_map[string, int].iterator element
        try:
            name_str = bytes(name, 'utf-8')
            element = self.name_to_index.find(name_str)
            found = element != self.name_to_index.end()
        except Exception:
            found = False
        if not(found):
            PyObject_GenericSetAttr(self, name, value)
            return
        cdef int color_index = dereference(element).second
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __setitem__(self, key, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int color_index
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Color %s not found" % key)
            color_index = dereference(element).second
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= implot.ImPlotCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __iter__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int, imgui.ImU32] element_content
        cdef str name
        for element_content in self.index_to_value:
            name = str(implot_GetStyleColorName(element_content.first), encoding='utf-8')
            result.append((name, int(element_content.second)))
        return iter(result)

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if not(self.enabled):
            self.last_push_size.push_back(0)
            return
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            # Note: imgui seems to convert U32 for this. Maybe use float4
            implot_PushStyleColor(element_content.first, element_content.second)
        self.last_push_size.push_back(<int>self.index_to_value.size())

    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef pair[int, imgui.ImU32] element_content
        cdef theme_action action
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push_to_list(v)
        if not(self.enabled):
            return
        for element_content in self.index_to_value:
            action.activation_condition_enabled = theme_enablers.t_enabled_any
            action.activation_condition_category = theme_categories.t_any
            action.type = theme_types.t_color
            action.backend = theme_backends.t_implot
            action.theme_index = element_content.first
            action.value_type = theme_value_types.t_u32
            action.value.value_u32 = element_content.second
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            implot_PopStyleColor(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()

@cython.no_gc_clear
cdef class ThemeColorImNodes(baseTheme):
    def __cinit__(self):
        self.names = [
            b"NodeBackground",
            b"NodeBackgroundHovered",
            b"NodeBackgroundSelected",
            b"NodeOutline",
            b"TitleBar",
            b"TitleBarHovered",
            b"TitleBarSelected",
            b"Link",
            b"LinkHovered",
            b"LinkSelected",
            b"Pin",
            b"PinHovered",
            b"BoxSelector",
            b"BoxSelectorOutline",
            b"GridBackground",
            b"GridLine",
            b"GridLinePrimary",
            b"MiniMapBackground",
            b"MiniMapBackgroundHovered",
            b"MiniMapOutline",
            b"MiniMapOutlineHovered",
            b"MiniMapNodeBackground",
            b"MiniMapNodeBackgroundHovered",
            b"MiniMapNodeBackgroundSelected",
            b"MiniMapNodeOutline",
            b"MiniMapLink",
            b"MiniMapLinkSelected",
            b"MiniMapCanvas",
            b"MiniMapCanvasOutline"
        ]
        cdef int i
        cdef string name_str
        for i, name in enumerate(self.names):
            name_str = name
            self.name_to_index[name_str] = i

    def __dir__(self):
        return self.names + dir(baseTheme)

    def __getattr__(self, name):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Color %s not found" % name)
        cdef int color_index = dereference(element).second
        cdef unordered_map[int, imgui.ImU32].iterator element_content = self.index_to_value.find(color_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImU32 value = dereference(element_content).second
        return value

    def __getitem__(self, key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int color_index
        cdef unordered_map[int, imgui.ImU32].iterator element_content
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Color %s not found" % key)
            color_index = dereference(element).second
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= imnodes.ImNodesCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        element_content = self.index_to_value.find(color_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImU32 value = dereference(element_content).second
        return value

    def __setattr__(self, name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint found
        cdef string name_str
        cdef unordered_map[string, int].iterator element
        try:
            name_str = bytes(name, 'utf-8')
            element = self.name_to_index.find(name_str)
            found = element != self.name_to_index.end()
        except Exception:
            found = False
        if not(found):
            PyObject_GenericSetAttr(self, name, value)
            return
        cdef int color_index = dereference(element).second
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __setitem__(self, key, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int color_index
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Color %s not found" % key)
            color_index = dereference(element).second
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= imnodes.ImNodesCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __iter__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            result.append((self.names[element_content.first],
                           int(element_content.second)))
        return iter(result)

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if not(self.enabled):
            self.last_push_size.push_back(0)
            return
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            # Note: imgui seems to convert U32 for this. Maybe use float4
            imnodes_PushStyleColor(element_content.first, element_content.second)
        self.last_push_size.push_back(<int>self.index_to_value.size())

    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef pair[int, imgui.ImU32] element_content
        cdef theme_action action
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push_to_list(v)
        if not(self.enabled):
            return
        for element_content in self.index_to_value:
            action.activation_condition_enabled = theme_enablers.t_enabled_any
            action.activation_condition_category = theme_categories.t_any
            action.type = theme_types.t_color
            action.backend = theme_backends.t_imnodes
            action.theme_index = element_content.first
            action.value_type = theme_value_types.t_u32
            action.value.value_u32 = element_content.second
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
           imnodes_PopStyleColor(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()


cdef class baseThemeStyle(baseTheme):
    def __cinit__(self):
        self.dpi = -1.
        self.backend = theme_backends.t_imgui
        self.dpi_scaling = True

    @property
    def no_scaling(self):
        """
        boolean. Defaults to False.
        If set, disables the automated scaling to the dpi
        scale value for this theme
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.dpi_scaling = not(value)

    @property
    def no_rounding(self):
        """
        boolean. Defaults to False.
        If set, disables rounding (after scaling) to the
        closest integer the parameters. The rounding is only
        applied to parameters which impact item positioning
        in a way that would prevent a pixel perfect result.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.round_after_scale)

    @no_rounding.setter
    def no_rounding(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.round_after_scale = not(value)

    def __getitem__(self, key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int style_index
        if isinstance(key, str):
            return getattr(self, key)
        elif isinstance(key, int):
            style_index = key
            if style_index < 0 or style_index >= len(self.names):
                raise KeyError("No element of index %d" % key)
            return getattr(self, self.names[style_index])
        raise TypeError("%s is an invalid index type" % str(type(key)))

    def __setitem__(self, key, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int style_index
        if isinstance(key, str):
            setattr(self, key, value)
        elif isinstance(key, int):
            style_index = key
            if style_index < 0 or style_index >= len(self.names):
                raise KeyError("No element of index %d" % key)
            setattr(self, self.names[style_index], value)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))

    def __iter__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int, theme_value_info] element_content
        for element_content in self.index_to_value:
            name = self.names[element_content.first]
            if element_content.second.value_type == theme_value_types.t_int:
                result.append((name, element_content.second.value.value_int))
            elif element_content.second.value_type == theme_value_types.t_float:
                result.append((name, element_content.second.value.value_float))
            elif element_content.second.value_type == theme_value_types.t_float2:
                result.append((name, element_content.second.value.value_float2))
            elif element_content.second.value_type == theme_value_types.t_u32:
                result.append((name, element_content.second.value.value_u32))
        return iter(result)

    cdef object __common_getter(self, int index, theme_value_types type):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[int, theme_value_info].iterator element_content = self.index_to_value.find(index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef theme_value_info value = dereference(element_content).second
        if value.value_type == theme_value_types.t_int:
            return value.value.value_int
        elif value.value_type == theme_value_types.t_float:
            return value.value.value_float
        elif value.value_type == theme_value_types.t_float2:
            return value.value.value_float2
        elif value.value_type == theme_value_types.t_u32:
            return value.value.value_u32
        return None

    cdef void __common_setter(self, int index, theme_value_types type, bint should_scale, bint should_round, py_value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if py_value is None:
            # Delete the value
            self.index_to_value.erase(index)
            self.dpi = -1 # regenerate the scaled dpi array
            return
        cdef theme_value_info value
        if type == theme_value_types.t_float:
            value.value.value_float = float(py_value)
        elif type == theme_value_types.t_float2:
            if not(hasattr(py_value, '__len__')) or len(py_value) != 2:
                raise ValueError(f"Expected a tuple, got {py_value}")
            value.value.value_float2[0] = float(py_value[0])
            value.value.value_float2[1] = float(py_value[1])
        elif type == theme_value_types.t_int:
            value.value.value_int = int(py_value)
        elif type == theme_value_types.t_u32:
            value.value.value_u32 = <unsigned>int(py_value)
        value.value_type = type
        value.should_scale = should_scale
        value.should_round = should_round
        self.index_to_value[index] = value
        self.dpi = -1 # regenerate the scaled dpi array

    cdef void __compute_for_dpi(self) noexcept nogil:
        cdef float dpi = self.context._viewport.global_scale
        cdef bint should_scale = self.dpi_scaling
        cdef bint should_round = self.round_after_scale
        self.dpi = dpi
        self.index_to_value_for_dpi.clear()
        cdef pair[int, theme_value_info] element_content
        for element_content in self.index_to_value:
            if should_scale and element_content.second.should_scale:
                if element_content.second.value_type == theme_value_types.t_int:
                    element_content.second.value.value_int = <int>(round(element_content.second.value.value_int * dpi))
                elif element_content.second.value_type == theme_value_types.t_float:
                    element_content.second.value.value_float *= dpi
                elif element_content.second.value_type == theme_value_types.t_float2:
                    element_content.second.value.value_float2[0] *= dpi
                    element_content.second.value.value_float2[1] *= dpi
                elif element_content.second.value_type == theme_value_types.t_u32:
                    element_content.second.value.value_u32 = <unsigned>(round(element_content.second.value.value_int * dpi))
            if should_round and element_content.second.should_round:
                if element_content.second.value_type == theme_value_types.t_float:
                    element_content.second.value.value_float = round(element_content.second.value.value_float)
                elif element_content.second.value_type == theme_value_types.t_float2:
                    element_content.second.value.value_float2[0] = round(element_content.second.value.value_float2[0])
                    element_content.second.value.value_float2[1] = round(element_content.second.value.value_float2[1])
            self.index_to_value_for_dpi.insert(element_content)

    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef pair[int, theme_value_info] element_content
        cdef theme_action action
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push_to_list(v)
        if not(self.enabled):
            return
        if self.context._viewport.global_scale != self.dpi:
            self.__compute_for_dpi()
        for element_content in self.index_to_value_for_dpi:
            action.activation_condition_enabled = theme_enablers.t_enabled_any
            action.activation_condition_category = theme_categories.t_any
            action.type = theme_types.t_style
            action.backend = self.backend
            action.theme_index = element_content.first
            action.value_type = element_content.second.value_type
            action.value = element_content.second.value
            v.push_back(action)

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if not(self.enabled):
            self.last_push_size.push_back(0)
            return
        if self.context._viewport.global_scale != self.dpi:
            self.__compute_for_dpi()
        cdef pair[int, theme_value_info] element_content
        if self.backend == theme_backends.t_imgui:
            for element_content in self.index_to_value_for_dpi:
                if element_content.second.value_type == theme_value_types.t_float:
                    imgui_PushStyleVar1(element_content.first, element_content.second.value.value_float)
                else:
                    imgui_PushStyleVar2(element_content.first, element_content.second.value.value_float2)
        elif self.backend == theme_backends.t_implot:
            for element_content in self.index_to_value_for_dpi:
                if element_content.second.value_type == theme_value_types.t_float:
                    implot_PushStyleVar1(element_content.first, element_content.second.value.value_float)
                elif element_content.second.value_type == theme_value_types.t_int:
                    implot_PushStyleVar0(element_content.first, element_content.second.value.value_int)
                else:
                    implot_PushStyleVar2(element_content.first, element_content.second.value.value_float2)
        elif self.backend == theme_backends.t_imnodes:
            for element_content in self.index_to_value_for_dpi:
                if element_content.second.value_type == theme_value_types.t_float:
                    imnodes_PushStyleVar1(element_content.first, element_content.second.value.value_float)
                else:
                    imnodes_PushStyleVar2(element_content.first, element_content.second.value.value_float2)
        self.last_push_size.push_back(<int>self.index_to_value_for_dpi.size())

    cdef void pop(self) noexcept nogil:
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            if self.backend == theme_backends.t_imgui:
                imgui_PopStyleVar(count)
            elif self.backend == theme_backends.t_implot:
                implot_PopStyleVar(count)
            elif self.backend == theme_backends.t_imnodes:
                imnodes_PopStyleVar(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()


cdef class ThemeStyleImGui(baseThemeStyle):
    def __cinit__(self):
        self.names = [
            "Alpha",                    # float     Alpha
            "DisabledAlpha",            # float     DisabledAlpha
            "WindowPadding",            # ImVec2    WindowPadding
            "WindowRounding",           # float     WindowRounding
            "WindowBorderSize",         # float     WindowBorderSize
            "WindowMinSize",            # ImVec2    WindowMinSize
            "WindowTitleAlign",         # ImVec2    WindowTitleAlign
            "ChildRounding",            # float     ChildRounding
            "ChildBorderSize",          # float     ChildBorderSize
            "PopupRounding",            # float     PopupRounding
            "PopupBorderSize",          # float     PopupBorderSize
            "FramePadding",             # ImVec2    FramePadding
            "FrameRounding",            # float     FrameRounding
            "FrameBorderSize",          # float     FrameBorderSize
            "ItemSpacing",              # ImVec2    ItemSpacing
            "ItemInnerSpacing",         # ImVec2    ItemInnerSpacing
            "IndentSpacing",            # float     IndentSpacing
            "CellPadding",              # ImVec2    CellPadding
            "ScrollbarSize",            # float     ScrollbarSize
            "ScrollbarRounding",        # float     ScrollbarRounding
            "GrabMinSize",              # float     GrabMinSize
            "GrabRounding",             # float     GrabRounding
            "TabRounding",              # float     TabRounding
            "TabBorderSize",            # float     TabBorderSize
            "TabBarBorderSize",         # float     TabBarBorderSize
            "TabBarOverlineSize",       # float     TabBarOverlineSize
            "TableAngledHeadersAngle",  # float     TableAngledHeadersAngle
            "TableAngledHeadersTextAlign",# ImVec2  TableAngledHeadersTextAlign
            "ButtonTextAlign",          # ImVec2    ButtonTextAlign
            "SelectableTextAlign",      # ImVec2    SelectableTextAlign
            "SeparatorTextBorderSize",  # float     SeparatorTextBorderSize
            "SeparatorTextAlign",       # ImVec2    SeparatorTextAlign
            "SeparatorTextPadding",     # ImVec2    SeparatorTextPadding
        ]
        self.backend = theme_backends.t_imgui

    @property
    def Alpha(self):
        """
        Global alpha applied to everything in Dear ImGui.

        The value is in the range [0, 1]. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 0, theme_value_types.t_float)

    @Alpha.setter
    def Alpha(self, value):
        baseThemeStyle.__common_setter(self, 0, theme_value_types.t_float, False, False, value)

    @property
    def DisabledAlpha(self):
        """
        Unused currently.

        The value is in the range [0, 1]. Defaults to 0.6
        """
        return baseThemeStyle.__common_getter(self, 1, theme_value_types.t_float)

    @DisabledAlpha.setter
    def DisabledAlpha(self, value):
        baseThemeStyle.__common_setter(self, 1, theme_value_types.t_float, False, False, value)

    @property
    def WindowPadding(self):
        """
        Padding within a window.

        The value is a pair of float (dx, dy). Defaults to (8, 8)
        """
        return baseThemeStyle.__common_getter(self, 2, theme_value_types.t_float2)

    @WindowPadding.setter
    def WindowPadding(self, value):
        baseThemeStyle.__common_setter(self, 2, theme_value_types.t_float2, True, True, value)

    @property
    def WindowRounding(self):
        """
        Radius of window corners rounding. Set to 0.0 to have rectangular windows. Large values tend to lead to variety of artifacts and are not recommended.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle.__common_getter(self, 3, theme_value_types.t_float)

    @WindowRounding.setter
    def WindowRounding(self, value):
        baseThemeStyle.__common_setter(self, 3, theme_value_types.t_float, True, False, value)

    @property
    def WindowBorderSize(self):
        """
        Thickness of border around windows. Generally set to 0.0 or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 4, theme_value_types.t_float)

    @WindowBorderSize.setter
    def WindowBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 4, theme_value_types.t_float, True, True, value)

    @property
    def WindowMinSize(self):
        """
        Minimum window size

        The value is a pair of float (dx, dy). Defaults to (32, 32)
        """
        return baseThemeStyle.__common_getter(self, 5, theme_value_types.t_float2)

    @WindowMinSize.setter
    def WindowMinSize(self, value):
        baseThemeStyle.__common_setter(self, 5, theme_value_types.t_float2, True, True, value)

    @property
    def WindowTitleAlign(self):
        """
        Alignment for window title bar text in percentages

        The value is a pair of float (dx, dy). Defaults to (0., 0.5), which means left-aligned, vertical centering on the row
        """
        return baseThemeStyle.__common_getter(self, 6, theme_value_types.t_float2)

    @WindowTitleAlign.setter
    def WindowTitleAlign(self, value):
        baseThemeStyle.__common_setter(self, 6, theme_value_types.t_float2, False, False, value)

    @property
    def ChildRounding(self):
        """
        Radius of child window corners rounding. Set to 0.0 to have rectangular child windows.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle.__common_getter(self, 7, theme_value_types.t_float)

    @ChildRounding.setter
    def ChildRounding(self, value):
        baseThemeStyle.__common_setter(self, 7, theme_value_types.t_float, True, False, value)

    @property
    def ChildBorderSize(self):
        """
        Thickness of border around child windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 8, theme_value_types.t_float)

    @ChildBorderSize.setter
    def ChildBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 8, theme_value_types.t_float, True, True, value)

    @property
    def PopupRounding(self):
        """
        Radius of popup or tooltip window corners rounding. Set to 0.0 to have rectangular popup or tooltip windows.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle.__common_getter(self, 9, theme_value_types.t_float)

    @PopupRounding.setter
    def PopupRounding(self, value):
        baseThemeStyle.__common_setter(self, 9, theme_value_types.t_float, True, False, value)

    @property
    def PopupBorderSize(self):
        """
        Thickness of border around popup or tooltip windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 10, theme_value_types.t_float)

    @PopupBorderSize.setter
    def PopupBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 10, theme_value_types.t_float, True, True, value)

    @property
    def FramePadding(self):
        """
        Padding within a framed rectangle (used by most widgets)

        The value is a pair of floats. Defaults to (4,3).
        """
        return baseThemeStyle.__common_getter(self, 11, theme_value_types.t_float2)

    @FramePadding.setter
    def FramePadding(self, value):
        baseThemeStyle.__common_setter(self, 11, theme_value_types.t_float2, True, True, value)

    @property
    def FrameRounding(self):
        """
        Radius of frame corners rounding. Set to 0.0 to have rectangular frame (most widgets).

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle.__common_getter(self, 12, theme_value_types.t_float)

    @FrameRounding.setter
    def FrameRounding(self, value):
        baseThemeStyle.__common_setter(self, 12, theme_value_types.t_float, True, False, value)

    @property
    def FrameBorderSize(self):
        """
        Thickness of border around frames (most widgets). Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle.__common_getter(self, 13, theme_value_types.t_float)

    @FrameBorderSize.setter
    def FrameBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 13, theme_value_types.t_float, True, True, value)

    @property
    def ItemSpacing(self):
        """
        Horizontal and vertical spacing between widgets/lines.

        The value is a pair of floats. Defaults to (8, 4).
        """
        return baseThemeStyle.__common_getter(self, 14, theme_value_types.t_float2)

    @ItemSpacing.setter
    def ItemSpacing(self, value):
        baseThemeStyle.__common_setter(self, 14, theme_value_types.t_float2, True, True, value)

    @property
    def ItemInnerSpacing(self):
        """
        Horizontal and vertical spacing between elements inside of a composed widget.

        The value is a pair of floats. Defaults to (4, 4).
        """
        return baseThemeStyle.__common_getter(self, 15, theme_value_types.t_float2)

    @ItemInnerSpacing.setter
    def ItemInnerSpacing(self, value):
        baseThemeStyle.__common_setter(self, 15, theme_value_types.t_float2, True, True, value)

    @property
    def IndentSpacing(self):
        """
        Default horizontal spacing for indentations. For instance when entering a tree node.
        A good value is Generally == (FontSize + FramePadding.x*2).

        The value is a float. Defaults to 21.
        """
        return baseThemeStyle.__common_getter(self, 16, theme_value_types.t_float)

    @IndentSpacing.setter
    def IndentSpacing(self, value):
        baseThemeStyle.__common_setter(self, 16, theme_value_types.t_float, True, True, value)

    @property
    def CellPadding(self):
        """
        Tables: padding between cells.
        The x padding is applied for the whole Table,
        while y can be different for every row.

        The value is a pair of floats. Defaults to (4, 2).
        """
        return baseThemeStyle.__common_getter(self, 17, theme_value_types.t_float2)

    @CellPadding.setter
    def CellPadding(self, value):
        baseThemeStyle.__common_setter(self, 17, theme_value_types.t_float2, True, True, value)

    @property
    def ScrollbarSize(self):
        """
        Width of the vertical scrollbar, Height of the horizontal scrollbar

        The value is a float. Defaults to 14.
        """
        return baseThemeStyle.__common_getter(self, 18, theme_value_types.t_float)

    @ScrollbarSize.setter
    def ScrollbarSize(self, value):
        baseThemeStyle.__common_setter(self, 18, theme_value_types.t_float, True, True, value)

    @property
    def ScrollbarRounding(self):
        """
        Radius of grab corners rounding for scrollbar.

        The value is a float. Defaults to 9.
        """
        return baseThemeStyle.__common_getter(self, 19, theme_value_types.t_float)

    @ScrollbarRounding.setter
    def ScrollbarRounding(self, value):
        baseThemeStyle.__common_setter(self, 19, theme_value_types.t_float, True, True, value)

    @property
    def GrabMinSize(self):
        """
        Minimum width/height of a grab box for slider/scrollbar.

        The value is a float. Defaults to 12.
        """
        return baseThemeStyle.__common_getter(self, 20, theme_value_types.t_float)

    @GrabMinSize.setter
    def GrabMinSize(self, value):
        baseThemeStyle.__common_setter(self, 20, theme_value_types.t_float, True, True, value)

    @property
    def GrabRounding(self):
        """
        Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle.__common_getter(self, 21, theme_value_types.t_float)

    @GrabRounding.setter
    def GrabRounding(self, value):
        baseThemeStyle.__common_setter(self, 21, theme_value_types.t_float, True, False, value)

    @property
    def TabRounding(self):
        """
        Radius of upper corners of a tab. Set to 0.0f to have rectangular tabs.

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle.__common_getter(self, 22, theme_value_types.t_float)

    @TabRounding.setter
    def TabRounding(self, value):
        baseThemeStyle.__common_setter(self, 22, theme_value_types.t_float, True, False, value)

    @property
    def TabBorderSize(self):
        """
        Thickness of borders around tabs.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle.__common_getter(self, 23, theme_value_types.t_float)

    @TabBorderSize.setter
    def TabBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 23, theme_value_types.t_float, True, True, value)

    @property
    def TabBarBorderSize(self):
        """
        Thickness of tab-bar separator, which takes on the tab active color to denote focus.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 24, theme_value_types.t_float)

    @TabBarBorderSize.setter
    def TabBarBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 24, theme_value_types.t_float, True, True, value)

    @property
    def TabBarOverlineSize(self):
        """
        Thickness of tab-bar overline, which highlights the selected tab-bar.

        The value is a float. Defaults to 2.
        """
        return baseThemeStyle.__common_getter(self, 25, theme_value_types.t_float)

    @TabBarOverlineSize.setter
    def TabBarOverlineSize(self, value):
        baseThemeStyle.__common_setter(self, 25, theme_value_types.t_float, True, True, value)

    @property
    def TableAngledHeadersAngle(self):
        """
        Tables: Angle of angled headers (supported values range from -50 degrees to +50 degrees).

        The value is a float. Defaults to 35.0f * (IM_PI / 180.0f).
        """
        return baseThemeStyle.__common_getter(self, 26, theme_value_types.t_float)

    @TableAngledHeadersAngle.setter
    def TableAngledHeadersAngle(self, value):
        baseThemeStyle.__common_setter(self, 26, theme_value_types.t_float, False, False, value)

    @property
    def TableAngledHeadersTextAlign(self):
        """
        Tables: Alignment (percentages) of angled headers within the cell
    
        The value is a pair of floats. Defaults to (0.5, 0.), i.e. top-centered
        """
        return baseThemeStyle.__common_getter(self, 27, theme_value_types.t_float2)

    @TableAngledHeadersTextAlign.setter
    def TableAngledHeadersTextAlign(self, value):
        baseThemeStyle.__common_setter(self, 27, theme_value_types.t_float2, False, False, value)

    @property
    def ButtonTextAlign(self):
        """
        Alignment of button text when button is larger than text.
    
        The value is a pair of floats. Defaults to (0.5, 0.5), i.e. centered
        """
        return baseThemeStyle.__common_getter(self, 28, theme_value_types.t_float2)

    @ButtonTextAlign.setter
    def ButtonTextAlign(self, value):
        baseThemeStyle.__common_setter(self, 28, theme_value_types.t_float2, False, False, value)

    @property
    def SelectableTextAlign(self):
        """
        Alignment of selectable text (in percentages).
    
        The value is a pair of floats. Defaults to (0., 0.), i.e. top-left. It is advised to keep the default.
        """
        return baseThemeStyle.__common_getter(self, 29, theme_value_types.t_float2)

    @SelectableTextAlign.setter
    def SelectableTextAlign(self, value):
        baseThemeStyle.__common_setter(self, 29, theme_value_types.t_float2, False, False, value)

    @property
    def SeparatorTextBorderSize(self):
        """
        Thickness of border in Separator() text.
    
        The value is a float. Defaults to 3.
        """
        return baseThemeStyle.__common_getter(self, 30, theme_value_types.t_float)

    @SeparatorTextBorderSize.setter
    def SeparatorTextBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 30, theme_value_types.t_float, True, True, value)

    @property
    def SelectableTextAlign(self):
        """
        Alignment of text within the separator in percentages.
    
        The value is a pair of floats. Defaults to (0., 0.5), i.e. left-centered
        """
        return baseThemeStyle.__common_getter(self, 31, theme_value_types.t_float2)

    @SelectableTextAlign.setter
    def SelectableTextAlign(self, value):
        baseThemeStyle.__common_setter(self, 31, theme_value_types.t_float2, False, False, value)

    @property
    def SeparatorTextPadding(self):
        """
        Horizontal offset of text from each edge of the separator + spacing on other axis. Generally small values. .y is recommended to be == FramePadding.y.
    
        The value is a pair of floats. Defaults to (20., 3.).
        """
        return baseThemeStyle.__common_getter(self, 32, theme_value_types.t_float2)

    @SeparatorTextPadding.setter
    def SeparatorTextPadding(self, value):
        baseThemeStyle.__common_setter(self, 32, theme_value_types.t_float2, True, True, value)


cdef class ThemeStyleImPlot(baseThemeStyle):
    def __cinit__(self):
        self.names = [
            "LineWeight",         # float,  plot item line weight in pixels
            "Marker",             # int,    marker specification
            "MarkerSize",         # float,  marker size in pixels (roughly the marker's "radius")
            "MarkerWeight",       # float,  plot outline weight of markers in pixels
            "FillAlpha",          # float,  alpha modifier applied to all plot item fills
            "ErrorBarSize",       # float,  error bar whisker width in pixels
            "ErrorBarWeight",     # float,  error bar whisker weight in pixels
            "DigitalBitHeight",   # float,  digital channels bit height (at 1) in pixels
            "DigitalBitGap",      # float,  digital channels bit padding gap in pixels
            "PlotBorderSize",     # float,  thickness of border around plot area
            "MinorAlpha",         # float,  alpha multiplier applied to minor axis grid lines
            "MajorTickLen",       # ImVec2, major tick lengths for X and Y axes
            "MinorTickLen",       # ImVec2, minor tick lengths for X and Y axes
            "MajorTickSize",      # ImVec2, line thickness of major ticks
            "MinorTickSize",      # ImVec2, line thickness of minor ticks
            "MajorGridSize",      # ImVec2, line thickness of major grid lines
            "MinorGridSize",      # ImVec2, line thickness of minor grid lines
            "PlotPadding",        # ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
            "LabelPadding",       # ImVec2, padding between axes labels, tick labels, and plot edge
            "LegendPadding",      # ImVec2, legend padding from plot edges
            "LegendInnerPadding", # ImVec2, legend inner padding from legend edges
            "LegendSpacing",      # ImVec2, spacing between legend entries
            "MousePosPadding",    # ImVec2, padding between plot edge and interior info text
            "AnnotationPadding",  # ImVec2, text padding around annotation labels
            "FitPadding",         # ImVec2, additional fit padding as a percentage of the fit extents (e.g. ImVec2(0.1f,0.1f) adds 10% to the fit extents of X and Y)
            "PlotDefaultSize",    # ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
            "PlotMinSize",        # ImVec2, minimum size plot frame can be when shrunk
        ]
        self.backend = theme_backends.t_implot

    @property
    def LineWeight(self):
        """
        Plot item line weight in pixels.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 0, theme_value_types.t_float)

    @LineWeight.setter
    def LineWeight(self, value):
        baseThemeStyle.__common_setter(self, 0, theme_value_types.t_float, True, False, value)

    @property
    def Marker(self):
        """
        Marker specification.

        The value is an integer. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 1, theme_value_types.t_int)

    @Marker.setter
    def Marker(self, value):
        baseThemeStyle.__common_setter(self, 1, theme_value_types.t_int, False, False, value)

    @property
    def MarkerSize(self):
        """
        Marker size in pixels (roughly the marker's "radius").

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle.__common_getter(self, 2, theme_value_types.t_float)

    @MarkerSize.setter
    def MarkerSize(self, value):
        baseThemeStyle.__common_setter(self, 2, theme_value_types.t_float, True, False, value)

    @property
    def MarkerWeight(self):
        """
        Plot outline weight of markers in pixels.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 3, theme_value_types.t_float)

    @MarkerWeight.setter
    def MarkerWeight(self, value):
        baseThemeStyle.__common_setter(self, 3, theme_value_types.t_float, True, False, value)

    @property
    def FillAlpha(self):
        """
        Alpha modifier applied to all plot item fills.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 4, theme_value_types.t_float)

    @FillAlpha.setter
    def FillAlpha(self, value):
        baseThemeStyle.__common_setter(self, 4, theme_value_types.t_float, False, False, value)

    @property
    def ErrorBarSize(self):
        """
        Error bar whisker width in pixels.

        The value is a float. Defaults to 5.
        """
        return baseThemeStyle.__common_getter(self, 5, theme_value_types.t_float)

    @ErrorBarSize.setter
    def ErrorBarSize(self, value):
        baseThemeStyle.__common_setter(self, 5, theme_value_types.t_float, True, True, value)

    @property
    def ErrorBarWeight(self):
        """
        Error bar whisker weight in pixels.

        The value is a float. Defaults to 1.5.
        """
        return baseThemeStyle.__common_getter(self, 6, theme_value_types.t_float)

    @ErrorBarWeight.setter
    def ErrorBarWeight(self, value):
        baseThemeStyle.__common_setter(self, 6, theme_value_types.t_float, True, False, value)

    @property
    def DigitalBitHeight(self):
        """
        Digital channels bit height (at 1) in pixels.

        The value is a float. Defaults to 8.
        """
        return baseThemeStyle.__common_getter(self, 7, theme_value_types.t_float)

    @DigitalBitHeight.setter
    def DigitalBitHeight(self, value):
        baseThemeStyle.__common_setter(self, 7, theme_value_types.t_float, True, True, value)

    @property
    def DigitalBitGap(self):
        """
        Digital channels bit padding gap in pixels.

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle.__common_getter(self, 8, theme_value_types.t_float)

    @DigitalBitGap.setter
    def DigitalBitGap(self, value):
        baseThemeStyle.__common_setter(self, 8, theme_value_types.t_float, True, True, value)

    @property
    def PlotBorderSize(self):
        """
        Thickness of border around plot area.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle.__common_getter(self, 9, theme_value_types.t_float)

    @PlotBorderSize.setter
    def PlotBorderSize(self, value):
        baseThemeStyle.__common_setter(self, 9, theme_value_types.t_float, True, True, value)

    @property
    def MinorAlpha(self):
        """
        Alpha multiplier applied to minor axis grid lines.

        The value is a float. Defaults to 0.25.
        """
        return baseThemeStyle.__common_getter(self, 10, theme_value_types.t_float)

    @MinorAlpha.setter
    def MinorAlpha(self, value):
        baseThemeStyle.__common_setter(self, 10, theme_value_types.t_float, False, False, value)

    @property
    def MajorTickLen(self):
        """
        Major tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle.__common_getter(self, 11, theme_value_types.t_float2)

    @MajorTickLen.setter
    def MajorTickLen(self, value):
        baseThemeStyle.__common_setter(self, 11, theme_value_types.t_float2, True, True, value)

    @property
    def MinorTickLen(self):
        """
        Minor tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle.__common_getter(self, 12, theme_value_types.t_float2)

    @MinorTickLen.setter
    def MinorTickLen(self, value):
        baseThemeStyle.__common_setter(self, 12, theme_value_types.t_float2, True, True, value)

    @property
    def MajorTickSize(self):
        """
        Line thickness of major ticks.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle.__common_getter(self, 13, theme_value_types.t_float2)

    @MajorTickSize.setter
    def MajorTickSize(self, value):
        baseThemeStyle.__common_setter(self, 13, theme_value_types.t_float2, True, False, value)

    @property
    def MinorTickSize(self):
        """
        Line thickness of minor ticks.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle.__common_getter(self, 14, theme_value_types.t_float2)

    @MinorTickSize.setter
    def MinorTickSize(self, value):
        baseThemeStyle.__common_setter(self, 14, theme_value_types.t_float2, True, False, value)

    @property
    def MajorGridSize(self):
        """
        Line thickness of major grid lines.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle.__common_getter(self, 15, theme_value_types.t_float2)

    @MajorGridSize.setter
    def MajorGridSize(self, value):
        baseThemeStyle.__common_setter(self, 15, theme_value_types.t_float2, True, False, value)

    @property
    def MinorGridSize(self):
        """
        Line thickness of minor grid lines.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle.__common_getter(self, 16, theme_value_types.t_float2)

    @MinorGridSize.setter
    def MinorGridSize(self, value):
        baseThemeStyle.__common_setter(self, 16, theme_value_types.t_float2, True, False, value)

    @property
    def PlotPadding(self):
        """
        Padding between widget frame and plot area, labels, or outside legends (i.e. main padding).

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle.__common_getter(self, 17, theme_value_types.t_float2)

    @PlotPadding.setter
    def PlotPadding(self, value):
        baseThemeStyle.__common_setter(self, 17, theme_value_types.t_float2, True, True, value)

    @property
    def LabelPadding(self):
        """
        Padding between axes labels, tick labels, and plot edge.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle.__common_getter(self, 18, theme_value_types.t_float2)

    @LabelPadding.setter
    def LabelPadding(self, value):
        baseThemeStyle.__common_setter(self, 18, theme_value_types.t_float2, True, True, value)

    @property
    def LegendPadding(self):
        """
        Legend padding from plot edges.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle.__common_getter(self, 19, theme_value_types.t_float2)

    @LegendPadding.setter
    def LegendPadding(self, value):
        baseThemeStyle.__common_setter(self, 19, theme_value_types.t_float2, True, True, value)

    @property
    def LegendInnerPadding(self):
        """
        Legend inner padding from legend edges.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle.__common_getter(self, 20, theme_value_types.t_float2)

    @LegendInnerPadding.setter
    def LegendInnerPadding(self, value):
        baseThemeStyle.__common_setter(self, 20, theme_value_types.t_float2, True, True, value)

    @property
    def LegendSpacing(self):
        """
        Spacing between legend entries.

        The value is a pair of floats. Defaults to (5, 0).
        """
        return baseThemeStyle.__common_getter(self, 21, theme_value_types.t_float2)

    @LegendSpacing.setter
    def LegendSpacing(self, value):
        baseThemeStyle.__common_setter(self, 21, theme_value_types.t_float2, True, True, value)

    @property
    def MousePosPadding(self):
        """
        Padding between plot edge and interior info text.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle.__common_getter(self, 22, theme_value_types.t_float2)

    @MousePosPadding.setter
    def MousePosPadding(self, value):
        baseThemeStyle.__common_setter(self, 22, theme_value_types.t_float2, True, True, value)

    @property
    def AnnotationPadding(self):
        """
        Text padding around annotation labels.

        The value is a pair of floats. Defaults to (2, 2).
        """
        return baseThemeStyle.__common_getter(self, 23, theme_value_types.t_float2)

    @AnnotationPadding.setter
    def AnnotationPadding(self, value):
        baseThemeStyle.__common_setter(self, 23, theme_value_types.t_float2, True, True, value)

    @property
    def FitPadding(self):
        """
        Additional fit padding as a percentage of the fit extents (e.g. (0.1,0.1) adds 10% to the fit extents of X and Y).

        The value is a pair of floats. Defaults to (0, 0).
        """
        return baseThemeStyle.__common_getter(self, 24, theme_value_types.t_float2)

    @FitPadding.setter
    def FitPadding(self, value):
        baseThemeStyle.__common_setter(self, 24, theme_value_types.t_float2, False, False, value)

    @property
    def PlotDefaultSize(self):
        """
        Default size used for plots

        The value is a pair of floats. Defaults to (400, 300).
        """
        return baseThemeStyle.__common_getter(self, 25, theme_value_types.t_float2)

    @PlotDefaultSize.setter
    def PlotDefaultSize(self, value):
        baseThemeStyle.__common_setter(self, 25, theme_value_types.t_float2, True, True, value)

    @property
    def PlotMinSize(self):
        """
        Minimum size plot frame can be when shrunk.

        The value is a pair of floats. Defaults to (200, 150).
        """
        return baseThemeStyle.__common_getter(self, 26, theme_value_types.t_float2)

    @PlotMinSize.setter
    def PlotMinSize(self, value):
        baseThemeStyle.__common_setter(self, 26, theme_value_types.t_float2, True, True, value)

cdef class ThemeStyleImNodes(baseThemeStyle):
    pass # TODO

'''
cdef extern from * nogil:
    """
    const int styles_imnodes_sizes[15] = {
    1,
    1,
    2,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    2,
    2,
    };
    """
    cdef int[15] styles_imnodes_sizes

cdef class ThemeStyleImNodes(baseThemeStyle):
    def __cinit__(self):
        self.names = [
            b"GridSpacing",
            b"NodeCornerRounding",
            b"NodePadding",
            b"NodeBorderThickness",
            b"LinkThickness",
            b"LinkLineSegmentsPerLength",
            b"LinkHoverDistance",
            b"PinCircleRadius",
            b"PinQuadSideLength",
            b"PinTriangleSideLength",
            b"PinLineThickness",
            b"PinHoverRadius",
            b"PinOffset",
            b"MiniMapPadding",
            b"MiniMapOffset"
        ]
        cdef int i
        cdef string name_str
        for i, name in enumerate(self.names):
            name_str = name
            self.name_to_index[name_str] = i
        self.backend = theme_backends.t_imnodes

    def __dir__(self):
        return self.names + dir(baseTheme)

    def __getattr__(self, name):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Element %s not found" % name)
        cdef int style_index = dereference(element).second
        cdef unordered_map[int, imgui.ImVec2].iterator element_content = self.index_to_value.find(style_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImVec2 value = dereference(element_content).second
        if styles_imnodes_sizes[style_index] == 2:
            return (value.x, value.y)
        return value.x

    def __getitem__(self, key):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int style_index
        cdef unordered_map[int, imgui.ImVec2].iterator element_content
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Element %s not found" % key)
            style_index = dereference(element).second
        elif isinstance(key, int):
            style_index = key
            if style_index < 0 or style_index >= imnodes.ImNodesStyleVar_COUNT:
                raise KeyError("No element of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        element_content = self.index_to_value.find(style_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImVec2 value = dereference(element_content).second
        if styles_imnodes_sizes[style_index] == 2:
            return (value.x, value.y)
        return value.x

    def __setattr__(self, name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint found
        cdef string name_str
        cdef unordered_map[string, int].iterator element
        try:
            name_str = bytes(name, 'utf-8')
            element = self.name_to_index.find(name_str)
            found = element != self.name_to_index.end()
        except Exception:
            found = False
        if not(found):
            PyObject_GenericSetAttr(self, name, value)
            return
        cdef int style_index = dereference(element).second
        if value is None:
            self.index_to_value.erase(style_index)
            return
        cdef imgui.ImVec2 value_to_store
        try:
            if styles_imnodes_sizes[style_index] <= 1:
                value_to_store.x = value
                value_to_store.y = 0.
            else:
                value_to_store.x = value[0]
                value_to_store.y = value[1]
        except Exception as e:
            if styles_imnodes_sizes[style_index] == 1:
                raise ValueError("Expected type float for style " + name)
            if styles_imnodes_sizes[style_index] == 0:
                raise ValueError("Expected type int for style " + name)
            raise ValueError("Expected type (float, float) for style " + name)

        self.index_to_value[style_index] = value_to_store

    def __setitem__(self, key, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[string, int].iterator element
        cdef int style_index
        cdef string name_str
        if isinstance(key, str):
            name_str = bytes(key, 'utf-8')
            element = self.name_to_index.find(name_str)
            if element == self.name_to_index.end():
                raise KeyError("Element %s not found" % key)
            style_index = dereference(element).second
        elif isinstance(key, int):
            style_index = key
            if style_index < 0 or style_index >= imnodes.ImNodesStyleVar_COUNT:
                raise KeyError("No element of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(style_index)
            return

        cdef imgui.ImVec2 value_to_store
        try:
            if styles_imnodes_sizes[style_index] <= 1:
                value_to_store.x = value
                value_to_store.y = 0.
            else:
                value_to_store.x = value[0]
                value_to_store.y = value[1]
        except Exception as e:
            if styles_imnodes_sizes[style_index] == 1:
                raise ValueError("Expected type float for style " + self.names[style_index])
            raise ValueError("Expected type (float, float) for style " + self.names[style_index])

        self.index_to_value[style_index] = value_to_store

    def __iter__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int, imgui.ImVec2] element_content
        for element_content in self.index_to_value:
            name = self.names[element_content.first]
            if styles_imnodes_sizes[element_content.first] == 1:
                result.append((name, element_content.second.x))
            else:
                result.append((name,
                               (element_content.second.x,
                                element_content.second.y)))
        return iter(result)

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if not(self.enabled):
            self.last_push_size.push_back(0)
            return
        cdef pair[int, imgui.ImVec2] element_content
        for element_content in self.index_to_value:
            if styles_imnodes_sizes[element_content.first] == 1:
                imnodes_PushStyleVar1(element_content.first, element_content.second.x)
            else:
                imnodes_PushStyleVar2(element_content.first, element_content.second)
        self.last_push_size.push_back(<int>self.index_to_value.size())

    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef pair[int, imgui.ImVec2] element_content
        cdef theme_action action
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push_to_list(v)
        if not(self.enabled):
            return
        for element_content in self.index_to_value:
            action.activation_condition_enabled = theme_enablers.t_enabled_any
            action.activation_condition_category = theme_categories.t_any
            action.type = theme_types.t_style
            action.backend = theme_backends.t_imnodes
            action.theme_index = element_content.first
            if styles_imnodes_sizes[element_content.first] == 1:
                action.value_type = theme_value_types.t_float
                action.value.value_float = element_content.second.x
            else:
                action.value_type = theme_value_types.t_float2
                action.value.value_float2[0] = element_content.second.x
                action.value.value_float2[1] = element_content.second.y
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            imnodes_PopStyleVar(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()
'''

cdef class ThemeList(baseTheme):
    def __cinit__(self):
        self.can_have_theme_child = True

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if self.last_theme_child is not None:
            self.last_theme_child.push()

    cdef void pop(self) noexcept nogil:
        if self.last_theme_child is not None:
            self.last_theme_child.pop()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()
    
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push_to_list(v)
        if self.last_theme_child is not None:
            self.last_theme_child.push_to_list(v)


cdef class ThemeListWithCondition(baseTheme):
    def __cinit__(self):
        self.can_have_theme_child = True
        self.activation_condition_enabled = theme_enablers.t_enabled_any
        self.activation_condition_category = theme_categories.t_any

    @property
    def condition_enabled(self):
        """
        Writable attribute: As long as it is active, the theme list
        waits to be applied that the conditions are met.
        enabled condition: 0: no condition. 1: enabled must be true. 2: enabled must be false
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.activation_condition_enabled

    @condition_enabled.setter
    def condition_enabled(self, theme_enablers value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # TODO: check bounds
        self.activation_condition_enabled = value

    @property
    def condition_category(self):
        """
        Writable attribute: As long as it is active, the theme list
        waits to be applied that the conditions are met.
        category condition: 0: no condition. other value: see list
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.activation_condition_category

    @condition_category.setter
    def condition_category(self, theme_categories value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # TODO: check bounds
        self.activation_condition_category = value

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if not(self.enabled):
            self.last_push_size.push_back(0)
            return
        cdef int prev_size, i, new_size, count, applied_count
        cdef theme_enablers condition_enabled
        cdef theme_categories condition_category
        count = 0
        applied_count = 0
        if self.last_theme_child is not None:
            prev_size = <int>self.context._viewport.pending_theme_actions.size()
            self.last_theme_child.push_to_list(self.context._viewport.pending_theme_actions)
            new_size = <int>self.context._viewport.pending_theme_actions.size()
            count = new_size - prev_size
            # Set the conditions
            for i in range(prev_size, new_size):
                condition_enabled = self.context._viewport.pending_theme_actions[i].activation_condition_enabled
                condition_category = self.context._viewport.pending_theme_actions[i].activation_condition_category
                if self.activation_condition_enabled != theme_enablers.t_enabled_any:
                    if condition_enabled != theme_enablers.t_enabled_any and \
                       condition_enabled != self.activation_condition_enabled:
                        # incompatible conditions. Disable
                        condition_enabled = theme_enablers.t_discarded
                    else:
                        condition_enabled = self.activation_condition_enabled
                if self.activation_condition_category != theme_categories.t_any:
                    if condition_category != theme_categories.t_any and \
                       condition_category != self.activation_condition_category:
                        # incompatible conditions. Disable
                        condition_enabled = theme_enablers.t_discarded
                    else:
                        condition_category = self.activation_condition_category
                self.context._viewport.pending_theme_actions[i].activation_condition_enabled = condition_enabled
                self.context._viewport.pending_theme_actions[i].activation_condition_category = condition_category
            # Find if any of the conditions hold right now, and if so execute them
            # It is important to execute them now rather than later because we need
            # to insert before the next siblings
            if count > 0:
                self.context._viewport.push_pending_theme_actions_on_subset(prev_size, new_size)

        self.last_push_size.push_back(count)

    cdef void pop(self) noexcept nogil:
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        cdef int i
        for i in range(count):
            self.context._viewport.pending_theme_actions.pop_back()
        if count > 0:
            self.context._viewport.pop_applied_pending_theme_actions()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()
    
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int prev_size, i, new_size
        cdef theme_enablers condition_enabled
        cdef theme_categories condition_category
        if self._prev_sibling is not None:
            prev_size = <int>v.size()
            (<baseTheme>self._prev_sibling).push_to_list(v)
            new_size = <int>v.size()
            # Set the conditions
            for i in range(prev_size, new_size):
                condition_enabled = v[i].activation_condition_enabled
                condition_category = v[i].activation_condition_category
                if self.activation_condition_enabled != theme_enablers.t_enabled_any:
                    if condition_enabled != theme_enablers.t_enabled_any and \
                       condition_enabled != self.activation_condition_enabled:
                        # incompatible conditions. Disable
                        condition_enabled = theme_enablers.t_discarded
                    else:
                        condition_enabled = self.activation_condition_enabled
                if self.activation_condition_category != theme_categories.t_any:
                    if condition_category != theme_categories.t_any and \
                       condition_category != self.activation_condition_category:
                        # incompatible conditions. Disable
                        condition_enabled = theme_enablers.t_discarded
                    else:
                        condition_category = self.activation_condition_category
                v[i].activation_condition_enabled = condition_enabled
                v[i].activation_condition_category = condition_category
        if self.last_theme_child is not None:
            self.last_theme_child.push_to_list(v)


cdef class ThemeStopCondition(baseTheme):
    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        self.start_pending_theme_actions_backup.push_back(self.context._viewport.start_pending_theme_actions)
        if self.enabled:
            self.context._viewport.start_pending_theme_actions = <int>self.context._viewport.pending_theme_actions.size()
    cdef void pop(self) noexcept nogil:
        self.context._viewport.start_pending_theme_actions = self.start_pending_theme_actions_backup.back()
        self.start_pending_theme_actions_backup.pop_back()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        return
