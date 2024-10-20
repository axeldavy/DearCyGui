
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

cdef extern from * nogil:
    """
    const int styles_imgui_sizes[34] = {
    1,
    1,
    2,
    1,
    1,
    2,
    2,
    1,
    1,
    1,
    1,
    2,
    1,
    1,
    2,
    2,
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
    2,
    2,
    2,
    1,
    2,
    2,
    1
    };
    """
    cdef int[34] styles_imgui_sizes

cdef class ThemeStyleImGui(baseTheme):
    def __cinit__(self):
        self.names = [
            b"Alpha",                    # float     Alpha
            b"DisabledAlpha",            # float     DisabledAlpha
            b"WindowPadding",            # ImVec2    WindowPadding
            b"WindowRounding",           # float     WindowRounding
            b"WindowBorderSize",         # float     WindowBorderSize
            b"WindowMinSize",            # ImVec2    WindowMinSize
            b"WindowTitleAlign",         # ImVec2    WindowTitleAlign
            b"ChildRounding",            # float     ChildRounding
            b"ChildBorderSize",          # float     ChildBorderSize
            b"PopupRounding",            # float     PopupRounding
            b"PopupBorderSize",          # float     PopupBorderSize
            b"FramePadding",             # ImVec2    FramePadding
            b"FrameRounding",            # float     FrameRounding
            b"FrameBorderSize",          # float     FrameBorderSize
            b"ItemSpacing",              # ImVec2    ItemSpacing
            b"ItemInnerSpacing",         # ImVec2    ItemInnerSpacing
            b"IndentSpacing",            # float     IndentSpacing
            b"CellPadding",              # ImVec2    CellPadding
            b"ScrollbarSize",            # float     ScrollbarSize
            b"ScrollbarRounding",        # float     ScrollbarRounding
            b"GrabMinSize",              # float     GrabMinSize
            b"GrabRounding",             # float     GrabRounding
            b"TabRounding",              # float     TabRounding
            b"TabBorderSize",            # float     TabBorderSize
            b"TabBarBorderSize",         # float     TabBarBorderSize
            b"TabBarOverlineSize",       # float     TabBarOverlineSize
            b"TableAngledHeadersAngle",  # float     TableAngledHeadersAngle
            b"TableAngledHeadersTextAlign",# ImVec2  TableAngledHeadersTextAlign
            b"ButtonTextAlign",          # ImVec2    ButtonTextAlign
            b"SelectableTextAlign",      # ImVec2    SelectableTextAlign
            b"SeparatorTextBorderSize",  # float     SeparatorTextBorderSize
            b"SeparatorTextAlign",       # ImVec2    SeparatorTextAlign
            b"SeparatorTextPadding",     # ImVec2    SeparatorTextPadding
            b"DockingSeparatorSize"     # float
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
            raise AttributeError("Element %s not found" % name)
        cdef int style_index = dereference(element).second
        cdef unordered_map[int, imgui.ImVec2].iterator element_content = self.index_to_value.find(style_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImVec2 value = dereference(element_content).second
        if styles_imgui_sizes[style_index] == 2:
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
            if style_index < 0 or style_index >= imgui.ImGuiStyleVar_COUNT:
                raise KeyError("No element of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        element_content = self.index_to_value.find(style_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImVec2 value = dereference(element_content).second
        if styles_imgui_sizes[style_index] == 2:
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
            if styles_imgui_sizes[style_index] == 1:
                value_to_store.x = value
                value_to_store.y = 0.
            else:
                value_to_store.x = value[0]
                value_to_store.y = value[1]
        except Exception as e:
            if styles_imgui_sizes[style_index] == 1:
                raise ValueError("Expected type float for style " + name)
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
            if style_index < 0 or style_index >= imgui.ImGuiStyleVar_COUNT:
                raise KeyError("No element of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(style_index)
            return

        cdef imgui.ImVec2 value_to_store
        try:
            if styles_imgui_sizes[style_index] == 1:
                value_to_store.x = value
                value_to_store.y = 0.
            else:
                value_to_store.x = value[0]
                value_to_store.y = value[1]
        except Exception as e:
            if styles_imgui_sizes[style_index] == 1:
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
            if styles_imgui_sizes[element_content.first] == 1:
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
            if styles_imgui_sizes[element_content.first] == 1:
                imgui_PushStyleVar1(element_content.first, element_content.second.x)
            else:
                imgui_PushStyleVar2(element_content.first, element_content.second)
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
            action.backend = theme_backends.t_imgui
            action.theme_index = element_content.first
            if styles_imgui_sizes[element_content.first] == 1:
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
            imgui_PopStyleVar(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()

# 0 used to mean int
cdef extern from * nogil:
    """
    const int styles_implot_sizes[27] = {
    1,
    0,
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
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2
    };
    """
    cdef int[27] styles_implot_sizes

cdef class ThemeStyleImPlot(baseTheme):
    def __cinit__(self):
        self.names = [
            b"LineWeight",         # float,  plot item line weight in pixels
            b"Marker",             # int,    marker specification
            b"MarkerSize",         # float,  marker size in pixels (roughly the marker's "radius")
            b"MarkerWeight",       # float,  plot outline weight of markers in pixels
            b"FillAlpha",          # float,  alpha modifier applied to all plot item fills
            b"ErrorBarSize",       # float,  error bar whisker width in pixels
            b"ErrorBarWeight",     # float,  error bar whisker weight in pixels
            b"DigitalBitHeight",   # float,  digital channels bit height (at 1) in pixels
            b"DigitalBitGap",      # float,  digital channels bit padding gap in pixels
            b"PlotBorderSize",     # float,  thickness of border around plot area
            b"MinorAlpha",         # float,  alpha multiplier applied to minor axis grid lines
            b"MajorTickLen",       # ImVec2, major tick lengths for X and Y axes
            b"MinorTickLen",       # ImVec2, minor tick lengths for X and Y axes
            b"MajorTickSize",      # ImVec2, line thickness of major ticks
            b"MinorTickSize",      # ImVec2, line thickness of minor ticks
            b"MajorGridSize",      # ImVec2, line thickness of major grid lines
            b"MinorGridSize",      # ImVec2, line thickness of minor grid lines
            b"PlotPadding",        # ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
            b"LabelPadding",       # ImVec2, padding between axes labels, tick labels, and plot edge
            b"LegendPadding",      # ImVec2, legend padding from plot edges
            b"LegendInnerPadding", # ImVec2, legend inner padding from legend edges
            b"LegendSpacing",      # ImVec2, spacing between legend entries
            b"MousePosPadding",    # ImVec2, padding between plot edge and interior info text
            b"AnnotationPadding",  # ImVec2, text padding around annotation labels
            b"FitPadding",         # ImVec2, additional fit padding as a percentage of the fit extents (e.g. ImVec2(0.1f,0.1f) adds 10% to the fit extents of X and Y)
            b"PlotDefaultSize",    # ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
            b"PlotMinSize",        # ImVec2, minimum size plot frame can be when shrunk
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
            raise AttributeError("Element %s not found" % name)
        cdef int style_index = dereference(element).second
        cdef unordered_map[int, imgui.ImVec2].iterator element_content = self.index_to_value.find(style_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImVec2 value = dereference(element_content).second
        if styles_implot_sizes[style_index] == 2:
            return (value.x, value.y)
        if styles_implot_sizes[style_index] == 0:
            return int(value.x)
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
            if style_index < 0 or style_index >= implot.ImPlotStyleVar_COUNT:
                raise KeyError("No element of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        element_content = self.index_to_value.find(style_index)
        if element_content == self.index_to_value.end():
            # None: default
            return None
        cdef imgui.ImVec2 value = dereference(element_content).second
        if styles_implot_sizes[style_index] == 2:
            return (value.x, value.y)
        if styles_implot_sizes[style_index] == 0:
            return int(value.x)
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
            if styles_implot_sizes[style_index] <= 1:
                value_to_store.x = value
                value_to_store.y = 0.
            else:
                value_to_store.x = value[0]
                value_to_store.y = value[1]
        except Exception as e:
            if styles_implot_sizes[style_index] == 1:
                raise ValueError("Expected type float for style " + name)
            if styles_implot_sizes[style_index] == 0:
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
            if style_index < 0 or style_index >= implot.ImPlotStyleVar_COUNT:
                raise KeyError("No element of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(style_index)
            return

        cdef imgui.ImVec2 value_to_store
        try:
            if styles_implot_sizes[style_index] <= 1:
                value_to_store.x = value
                value_to_store.y = 0.
            else:
                value_to_store.x = value[0]
                value_to_store.y = value[1]
        except Exception as e:
            if styles_implot_sizes[style_index] == 1:
                raise ValueError("Expected type float for style " + self.names[style_index])
            if styles_implot_sizes[style_index] == 0:
                raise ValueError("Expected type int for style " + self.names[style_index])
            raise ValueError("Expected type (float, float) for style " + self.names[style_index])

        self.index_to_value[style_index] = value_to_store

    def __iter__(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int, imgui.ImVec2] element_content
        for element_content in self.index_to_value:
            name = self.names[element_content.first]
            if styles_implot_sizes[element_content.first] == 1:
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
            if styles_implot_sizes[element_content.first] == 1:
                implot_PushStyleVar1(element_content.first, element_content.second.x)
            elif styles_implot_sizes[element_content.first] == 0:
                implot_PushStyleVar0(element_content.first, <int>element_content.second.x)
            else:
                implot_PushStyleVar2(element_content.first, element_content.second)
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
            action.backend = theme_backends.t_implot
            action.theme_index = element_content.first
            if styles_imgui_sizes[element_content.first] == 1:
                action.value_type = theme_value_types.t_float
                action.value.value_float = element_content.second.x
            elif styles_imgui_sizes[element_content.first] == 0:
                action.value_type = theme_value_types.t_int
                action.value.value_int = <int>element_content.second.x
            else:
                action.value_type = theme_value_types.t_float2
                action.value.value_float2[0] = element_content.second.x
                action.value.value_float2[1] = element_content.second.y
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            implot_PopStyleVar(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
        self.mutex.unlock()


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

cdef class ThemeStyleImNodes(baseTheme):
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
            if styles_imgui_sizes[element_content.first] == 1:
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
