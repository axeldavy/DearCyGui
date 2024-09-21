
from libcpp.unordered_map cimport unordered_map, pair
from libcpp.string cimport string
from dearcygui.wrapper cimport imgui, implot, imnodes
cimport cython
from cython.operator cimport dereference
from .core cimport *
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock

cdef class dcgThemeColorImGui(baseTheme):
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
        return results + ["enabled"]

    def __getattr__(self, str name):
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

    def __setattr__(self, str name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Color %s not found" % name)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
            action.theme_activation_condition_enabled = theme_activation_condition_enabled_any
            action.theme_activation_condition_category = theme_activation_condition_category_any
            action.theme_type = theme_type_color
            action.theme_category = theme_category_imgui
            action.theme_index = element_content.first
            action.theme_value_type = theme_value_type_u32
            action.value.value_u32 = element_content.second
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            imgui_PopStyleColor(count)
        if self._prev_sibling is not None:
            # Note: we are guaranteed to have the same
            # siblings than during push()
            (<baseTheme>self._prev_sibling).pop()

cdef class dcgThemeColorImPlot(baseTheme):
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
        return results + ["enabled"]

    def __getattr__(self, str name):
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

    def __setattr__(self, str name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Color %s not found" % name)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
            action.theme_activation_condition_enabled = theme_activation_condition_enabled_any
            action.theme_activation_condition_category = theme_activation_condition_category_any
            action.theme_type = theme_type_color
            action.theme_category = theme_category_implot
            action.theme_index = element_content.first
            action.theme_value_type = theme_value_type_u32
            action.value.value_u32 = element_content.second
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            implot_PopStyleColor(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()


cdef class dcgThemeColorImNodes(baseTheme):
    def __cinit__(self):
        self.names = [
            "NodeBackground",
            "NodeBackgroundHovered",
            "NodeBackgroundSelected",
            "NodeOutline",
            "TitleBar",
            "TitleBarHovered",
            "TitleBarSelected",
            "Link",
            "LinkHovered",
            "LinkSelected",
            "Pin",
            "PinHovered",
            "BoxSelector",
            "BoxSelectorOutline",
            "GridBackground",
            "GridLine",
            "GridLinePrimary",
            "MiniMapBackground",
            "MiniMapBackgroundHovered",
            "MiniMapOutline",
            "MiniMapOutlineHovered",
            "MiniMapNodeBackground",
            "MiniMapNodeBackgroundHovered",
            "MiniMapNodeBackgroundSelected",
            "MiniMapNodeOutline",
            "MiniMapLink",
            "MiniMapLinkSelected",
            "MiniMapCanvas",
            "MiniMapCanvasOutline"
        ]
        cdef int i
        cdef string name_str
        for i, name in enumerate(self.names):
            name_str = name
            self.name_to_index[name_str] = i

    def __dir__(self):
        return self.names + ["enabled"]

    def __getattr__(self, str name):
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

    def __setattr__(self, str name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Color %s not found" % name)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
            action.theme_activation_condition_enabled = theme_activation_condition_enabled_any
            action.theme_activation_condition_category = theme_activation_condition_category_any
            action.theme_type = theme_type_color
            action.theme_category = theme_category_imnodes
            action.theme_index = element_content.first
            action.theme_value_type = theme_value_type_u32
            action.value.value_u32 = element_content.second
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
           imnodes_PopStyleColor(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()

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

cdef class dcgThemeStyleImGui(baseTheme):
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
            "DockingSeparatorSize"     # float
        ]
        cdef int i
        cdef string name_str
        for i, name in enumerate(self.names):
            name_str = name
            self.name_to_index[name_str] = i

    def __dir__(self):
        return self.names + ["enabled"]

    def __getattr__(self, str name):
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

    def __setattr__(self, str name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Element %s not found" % name)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
            action.theme_activation_condition_enabled = theme_activation_condition_enabled_any
            action.theme_activation_condition_category = theme_activation_condition_category_any
            action.theme_type = theme_type_style
            action.theme_category = theme_category_imgui
            action.theme_index = element_content.first
            if styles_imgui_sizes[element_content.first] == 1:
                action.theme_value_type = theme_value_type_float
                action.value.value_float = element_content.second.x
            else:
                action.theme_value_type = theme_value_type_float2
                action.value.value_float2[0] = element_content.second.x
                action.value.value_float2[1] = element_content.second.y
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            imgui_PopStyleVar(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()

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

cdef class dcgThemeStyleImPlot(baseTheme):
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
        cdef int i
        cdef string name_str
        for i, name in enumerate(self.names):
            name_str = name
            self.name_to_index[name_str] = i

    def __dir__(self):
        return self.names + ["enabled"]

    def __getattr__(self, str name):
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

    def __setattr__(self, str name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Element %s not found" % name)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
            action.theme_activation_condition_enabled = theme_activation_condition_enabled_any
            action.theme_activation_condition_category = theme_activation_condition_category_any
            action.theme_type = theme_type_style
            action.theme_category = theme_category_implot
            action.theme_index = element_content.first
            if styles_imgui_sizes[element_content.first] == 1:
                action.theme_value_type = theme_value_type_float
                action.value.value_float = element_content.second.x
            elif styles_imgui_sizes[element_content.first] == 0:
                action.theme_value_type = theme_value_type_int
                action.value.value_int = <int>element_content.second.x
            else:
                action.theme_value_type = theme_value_type_float2
                action.value.value_float2[0] = element_content.second.x
                action.value.value_float2[1] = element_content.second.y
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            implot_PopStyleVar(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()


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

cdef class dcgThemeStyleImNodes(baseTheme):
    def __cinit__(self):
        self.names = [
            "GridSpacing",
            "NodeCornerRounding",
            "NodePadding",
            "NodeBorderThickness",
            "LinkThickness",
            "LinkLineSegmentsPerLength",
            "LinkHoverDistance",
            "PinCircleRadius",
            "PinQuadSideLength",
            "PinTriangleSideLength",
            "PinLineThickness",
            "PinHoverRadius",
            "PinOffset",
            "MiniMapPadding",
            "MiniMapOffset"
        ]
        cdef int i
        cdef string name_str
        for i, name in enumerate(self.names):
            name_str = name
            self.name_to_index[name_str] = i

    def __dir__(self):
        return self.names + ["enabled"]

    def __getattr__(self, str name):
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

    def __setattr__(self, str name, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string name_str = bytes(name, 'utf-8')
        cdef unordered_map[string, int].iterator element = self.name_to_index.find(name_str)
        if element == self.name_to_index.end():
            raise AttributeError("Element %s not found" % name)
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
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
            action.theme_activation_condition_enabled = theme_activation_condition_enabled_any
            action.theme_activation_condition_category = theme_activation_condition_category_any
            action.theme_type = theme_type_style
            action.theme_category = theme_category_imnodes
            action.theme_index = element_content.first
            if styles_imgui_sizes[element_content.first] == 1:
                action.theme_value_type = theme_value_type_float
                action.value.value_float = element_content.second.x
            else:
                action.theme_value_type = theme_value_type_float2
                action.value.value_float2[0] = element_content.second.x
                action.value.value_float2[1] = element_content.second.y
            v.push_back(action)

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        if count > 0:
            imnodes_PopStyleVar(count)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()


cdef class dcgThemeList(baseTheme):
    def __cinit__(self):
        self.can_have_theme_child = True

    cdef void push(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if self.last_theme_child is not None:
            self.last_theme_child.push()

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.last_theme_child is not None:
            self.last_theme_child.pop()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
    
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push_to_list(v)
        if self.last_theme_child is not None:
            self.last_theme_child.push_to_list(v)


cdef class dcgThemeListWithCondition(baseTheme):
    def __cinit__(self):
        self.can_have_theme_child = True
        self.theme_activation_condition_enabled = theme_activation_condition_enabled_any
        self.theme_activation_condition_category = theme_activation_condition_category_any

    cdef void push(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        if not(self.enabled):
            self.last_push_size.push_back(0)
            return
        cdef int prev_size, i, new_size, count, applied_count
        cdef int condition_enabled, condition_category
        count = 0
        applied_count = 0
        if self.last_theme_child is not None:
            prev_size = <int>self.context.viewport.pending_theme_actions.size()
            self.last_theme_child.push_to_list(self.context.viewport.pending_theme_actions)
            new_size = <int>self.context.viewport.pending_theme_actions.size()
            count = new_size - prev_size
            # Set the conditions
            for i in range(prev_size, new_size):
                condition_enabled = self.context.viewport.pending_theme_actions[i].theme_activation_condition_enabled
                condition_category = self.context.viewport.pending_theme_actions[i].theme_activation_condition_category
                if self.theme_activation_condition_enabled != theme_activation_condition_enabled_any:
                    if condition_enabled != theme_activation_condition_enabled_any and \
                       condition_enabled != self.theme_activation_condition_enabled:
                        # incompatible conditions. Disable
                        condition_enabled = -1
                    else:
                        condition_enabled = self.theme_activation_condition_enabled
                if self.theme_activation_condition_category != theme_activation_condition_category_any:
                    if condition_category != theme_activation_condition_category_any and \
                       condition_category != self.theme_activation_condition_category:
                        # incompatible conditions. Disable
                        condition_category = -1
                    else:
                        condition_category = self.theme_activation_condition_category
                self.context.viewport.pending_theme_actions[i].theme_activation_condition_enabled = condition_enabled
                self.context.viewport.pending_theme_actions[i].theme_activation_condition_category = condition_category
            # Find if any of the conditions hold right now, and if so execute them
            # It is important to execute them now rather than later because we need
            # to insert before the next siblings
            if count > 0:
                self.context.viewport.push_pending_theme_actions_on_subset(prev_size, new_size)

        self.last_push_size.push_back(count)

    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int count = self.last_push_size.back()
        self.last_push_size.pop_back()
        cdef int i
        for i in range(count):
            self.context.viewport.pending_theme_actions.pop_back()
        if count > 0:
            self.context.viewport.pop_applied_pending_theme_actions()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
    
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef int prev_size, i, new_size
        if self._prev_sibling is not None:
            prev_size = <int>v.size()
            (<baseTheme>self._prev_sibling).push_to_list(v)
            new_size = <int>v.size()
            # Set the conditions
            for i in range(prev_size, new_size):
                condition_enabled = v[i].theme_activation_condition_enabled
                condition_category = v[i].theme_activation_condition_category
                if self.theme_activation_condition_enabled != theme_activation_condition_enabled_any:
                    if condition_enabled != theme_activation_condition_enabled_any and \
                       condition_enabled != self.theme_activation_condition_enabled:
                        # incompatible conditions. Disable
                        condition_enabled = -1
                    else:
                        condition_enabled = self.theme_activation_condition_enabled
                if self.theme_activation_condition_category != theme_activation_condition_category_any:
                    if condition_category != theme_activation_condition_category_any and \
                       condition_category != self.theme_activation_condition_category:
                        # incompatible conditions. Disable
                        condition_category = -1
                    else:
                        condition_category = self.theme_activation_condition_category
                v[i].theme_activation_condition_enabled = condition_enabled
                v[i].theme_activation_condition_category = condition_category
        if self.last_theme_child is not None:
            self.last_theme_child.push_to_list(v)


cdef class dcgThemeStopCondition(baseTheme):
    cdef void push(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).push()
        self.start_pending_theme_actions_backup.push_back(self.context.viewport.start_pending_theme_actions)
        if self.enabled:
            self.context.viewport.start_pending_theme_actions = <int>self.context.viewport.pending_theme_actions.size()
    cdef void pop(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.viewport.start_pending_theme_actions = self.start_pending_theme_actions_backup.back()
        self.start_pending_theme_actions_backup.pop_back()
        if self._prev_sibling is not None:
            (<baseTheme>self._prev_sibling).pop()
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        return
