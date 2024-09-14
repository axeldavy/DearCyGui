
from libcpp.unordered_map cimport unordered_map, pair
from libcpp.string cimport string
from dearcygui.wrapper cimport imgui, implot, imnodes
cimport cython
from cython.operator cimport dereference
from .core cimport *

cdef class dcgThemeColorImGui(theme):
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
        return results

    def __getattribute__(self, str name):
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
            if color_index < 0 or color_index > imgui.ImGuiCol_COUNT:
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
            if color_index < 0 or color_index > imgui.ImGuiCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __iter__(self):
        cdef list result = []
        cdef pair[int, imgui.ImU32] element_content
        cdef str name
        for element_content in self.index_to_value:
            name = str(imgui_GetStyleColorName(element_content.first), encoding='utf-8')
            result.append((name, int(element_content.second)))
        return iter(result)

    cdef void push(self) noexcept nogil:
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            # Note: imgui seems to convert U32 for this. Maybe use float4
            imgui_PushStyleColor(element_content.first, element_content.second)

    cdef void pop(self) noexcept nogil:
        if self.index_to_value.size() == 0:
            return
        imgui_PopStyleColor(<int>self.index_to_value.size())

cdef class dcgThemeColorImPlot(theme):
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
        return results

    def __getattribute__(self, str name):
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
            if color_index < 0 or color_index > implot.ImPlotCol_COUNT:
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
            if color_index < 0 or color_index > implot.ImPlotCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __iter__(self):
        cdef list result = []
        cdef pair[int, imgui.ImU32] element_content
        cdef str name
        for element_content in self.index_to_value:
            name = str(implot_GetStyleColorName(element_content.first), encoding='utf-8')
            result.append((name, int(element_content.second)))
        return iter(result)

    cdef void push(self) noexcept nogil:
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            # Note: imgui seems to convert U32 for this. Maybe use float4
            implot_PushStyleColor(element_content.first, element_content.second)

    cdef void pop(self) noexcept nogil:
        if self.index_to_value.size() == 0:
            return
        implot_PopStyleColor(<int>self.index_to_value.size())


cdef class dcgThemeColorImNodes(theme):
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
        return self.names

    def __getattribute__(self, str name):
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
            if color_index < 0 or color_index > imnodes.ImNodesCol_COUNT:
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
            if color_index < 0 or color_index > imnodes.ImNodesCol_COUNT:
                raise KeyError("No color of index %d" % key)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))
        if value is None:
            self.index_to_value.erase(color_index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        self.index_to_value[color_index] = color

    def __iter__(self):
        cdef list result = []
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            result.append((self.names[element_content.first],
                           int(element_content.second)))
        return iter(result)

    cdef void push(self) noexcept nogil:
        cdef pair[int, imgui.ImU32] element_content
        for element_content in self.index_to_value:
            # Note: imgui seems to convert U32 for this. Maybe use float4
            imnodes_PushStyleColor(element_content.first, element_content.second)

    cdef void pop(self) noexcept nogil:
        if self.index_to_value.size() == 0:
            return
        imnodes_PopStyleColor(<int>self.index_to_value.size())