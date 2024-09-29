from libcpp.unordered_map cimport unordered_map
from libcpp.string cimport string
from dearcygui.wrapper cimport imgui
from .core cimport *

cdef class ThemeColorImGui(baseTheme):
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImU32] index_to_value
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeColorImPlot(baseTheme):
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImU32] index_to_value
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeColorImNodes(baseTheme):
    cdef list names
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImU32] index_to_value
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeStyleImGui(baseTheme):
    cdef list names
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImVec2] index_to_value
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeStyleImPlot(baseTheme):
    cdef list names
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImVec2] index_to_value
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeStyleImNodes(baseTheme):
    cdef list names
    cdef unordered_map[string, int] name_to_index
    cdef unordered_map[int, imgui.ImVec2] index_to_value
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeList(baseTheme):
    """
    A set of base theme elements to apply when we render an item.
    Warning: it is bad practice to bind a theme to every item, and
    is not free on CPU. Instead set the theme as high as possible in
    the rendering hierarchy, and only change locally reduced sets
    of theme elements if needed.

    Contains theme styles and colors.
    Can contain a theme list.
    Can be bound to items.

    WARNING: if you bind a theme element to an item,
    and that theme element belongs to a theme list,
    the siblings before the theme element will get
    applied as well.
    """
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeListWithCondition(baseTheme):
    """
    A ThemeList but with delayed activation.
    If during rendering of the children the condition
    is met, then the theme gets applied.

    Contains theme styles and colors.
    Can contain a theme list.
    Can be in a theme list
    Can be bound to items.
    Concatenates with previous theme lists with
    conditions during rendering.
    The condition gets checked on the bound item,
    not just the children.

    As the elements in this list get checked everytime
    a item in the child tree is rendered, use this lightly.
    """
    cdef theme_enablers activation_condition_enabled
    cdef theme_categories activation_condition_category
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil

cdef class ThemeStopCondition(baseTheme):
    """
    a Theme that blocks any previous theme
    list with condition from propagating to children
    of the item bound. Does not affect the bound item.

    Does not work inside a ThemeListWithCondition
    """
    cdef vector[int] start_pending_theme_actions_backup
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil
