cimport cython
from dearcygui.wrapper cimport imgui

from enum import IntFlag, IntEnum

cdef imgui.ImU32 imgui_ColorConvertFloat4ToU32(imgui.ImVec4 color_float4) noexcept nogil:
    return imgui.ColorConvertFloat4ToU32(color_float4)

cdef imgui.ImVec4 imgui_ColorConvertU32ToFloat4(imgui.ImU32 color_uint) noexcept nogil:
    return imgui.ColorConvertU32ToFloat4(color_uint)

def color_as_int(val)-> int:
    cdef imgui.ImU32 color = parse_color(val)
    return int(color)

def color_as_ints(val) -> tuple[int, int, int, int]:
    cdef imgui.ImU32 color = parse_color(val)
    cdef imgui.ImVec4 color_vec = imgui.ColorConvertU32ToFloat4(color)
    return (int(255. * color_vec.x),
            int(255. * color_vec.y),
            int(255. * color_vec.z),
            int(255. * color_vec.w))

def color_as_floats(val) -> tuple[float, float, float, float]:
    cdef imgui.ImU32 color = parse_color(val)
    cdef imgui.ImVec4 color_vec = imgui.ColorConvertU32ToFloat4(color)
    return (color_vec.x, color_vec.y, color_vec.z, color_vec.w)

@cython.freelist(8)
cdef class Coord:
    """Fast writable 2D coordinate tuple (x, y) which supports a lot of operations"""
    #def __cinit__(self): Commented as trivial. Commenting enables auto-generated __reduce__
    #    self._x = 0
    #    self._y = 0

    def __init__(self, double x = 0., double y = 0.):
        self._x = x
        self._y = y

    @property
    def x(self):
        """Coordinate on the horizontal axis"""
        return self._x

    @property
    def y(self):
        """Coordinate on the vertical axis"""
        return self._y

    def __len__(self):
        return 2

    def __getitem__(self, key):
        cdef int index
        if isinstance(key, int):
            index = <int>key
            if index == 0:
                return self._x
            if index == 1:
                return self._y
        elif isinstance(key, str):
            if key == "x":
                return self._x
            if key == "y":
                return self._y
        raise IndexError(f"Invalid key: {key}")

    def __setitem__(self, key, value):
        cdef int index
        if isinstance(key, int):
            index = <int>key
            if index == 0:
                self._x = <double>value
                return
            if index == 1:
                self._y = <double>value
                return
        elif isinstance(key, str):
            if key == "x":
                self._x = <double>value
                return
            if key == "y":
                self._y = <double>value
                return
        raise IndexError(f"Invalid key: {key}")

    def __add__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        other_coord[0] += self._x
        other_coord[1] += self._y
        return Coord.build(other_coord)

    def __radd__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        other_coord[0] += self._x
        other_coord[1] += self._y
        return Coord.build(other_coord)

    def __iadd__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        self._x += other_coord[0]
        self._y += other_coord[1]
        return self

    def __sub__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        other_coord[0] -= self._x
        other_coord[1] -= self._y
        return Coord.build(other_coord)

    def __rsub__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        other_coord[0] -= self._x
        other_coord[1] -= self._y
        return Coord.build(other_coord)

    def __isub__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        self._x -= other_coord[0]
        self._y -= other_coord[1]
        return self

    def __mul__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] *= self._x
        other_coord[1] *= self._y
        return Coord.build(other_coord)

    def __rmul__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] *= self._x
        other_coord[1] *= self._y
        return Coord.build(other_coord)

    def __imul__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
            self._x *= other_coord[0]
            self._y *= other_coord[1]
        else:
            # scalar
            other_coord[0] = other 
            self._x *= other_coord[0]
            self._y *= other_coord[0]
        return self

    def __truediv__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] = self._x / other_coord[0]
        other_coord[1] = self._y / other_coord[1]
        return Coord.build(other_coord)

    def __rtruediv__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] = other_coord[0] / self._x
        other_coord[1] = other_coord[1] / self._y
        return Coord.build(other_coord)

    def __itruediv__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
            self._x /= other_coord[0]
            self._y /= other_coord[1]
        else:
            # scalar
            other_coord[0] = other 
            self._x /= other_coord[0]
            self._y /= other_coord[0]
        return self

    def __neg__(self):
        cdef double[2] other_coord
        other_coord[0] = -self._x
        other_coord[1] = -self._y
        return Coord.build(other_coord)

    def __pos__(self):
        cdef double[2] other_coord
        other_coord[0] = self._x
        other_coord[1] = self._y
        return Coord.build(other_coord)

    def __abs__(self):
        cdef double[2] other_coord
        other_coord[0] = abs(self._x)
        other_coord[1] = abs(self._y)
        return Coord.build(other_coord)

    # lexicographic ordering
    def __lt__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        if self._x < other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y < other_coord[1]:
            return True
        return False

    def __le__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        if self._x < other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y <= other_coord[1]:
            return True
        return False

    def __eq__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        return self._x == other_coord[0] and self._y == other_coord[1]

    def __ne__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        return self._x != other_coord[0] or self._y != other_coord[1]

    def __gt__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        if self._x > other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y > other_coord[1]:
            return True
        return False

    def __ge__(self, other):
        cdef double[2] other_coord
        try:
             read_coord(other_coord, other)
        except TypeError:
             return NotImplemented
        if self._x > other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y >= other_coord[1]:
            return True
        return False

    def __hash__(self):
        return hash((self._x, self._y))

    def __bool__(self):
        return self._x == 0 and self._y == 0

    def __str__(self):
        return str((self._x, self._y))

    def __repr__(self):
        return f"Coord({self._x}, {self._y})"

    # Fast instanciation from Cython
    @staticmethod
    cdef Coord build(double[2] &coord):
        cdef Coord item = Coord.__new__(Coord)
        item._x = coord[0]
        item._y = coord[1]
        return item

class ChildType(IntFlag):
    NOCHILD = 0,
    DRAWING = 1,
    HANDLER = 2,
    MENUBAR = 4,
    PLOTELEMENT = 8,
    TAB = 16,
    THEME = 32,
    VIEWPORTDRAWLIST = 64,
    WIDGET = 128,
    WINDOW = 256

class Key(IntEnum):
    TAB = imgui.ImGuiKey_Tab,
    LEFTARROW = imgui.ImGuiKey_LeftArrow,
    RIGHTARROW = imgui.ImGuiKey_RightArrow,
    UPARROW = imgui.ImGuiKey_UpArrow,
    DOWNARROW = imgui.ImGuiKey_DownArrow,
    PAGEUP = imgui.ImGuiKey_PageUp,
    PAGEDOWN = imgui.ImGuiKey_PageDown,
    HOME = imgui.ImGuiKey_Home,
    END = imgui.ImGuiKey_End,
    INSERT = imgui.ImGuiKey_Insert,
    DELETE = imgui.ImGuiKey_Delete,
    BACKSPACE = imgui.ImGuiKey_Backspace,
    SPACE = imgui.ImGuiKey_Space,
    ENTER = imgui.ImGuiKey_Enter,
    ESCAPE = imgui.ImGuiKey_Escape,
    LEFTCTRL = imgui.ImGuiKey_LeftCtrl,
    LEFTSHIFT = imgui.ImGuiKey_LeftShift,
    LEFTALT = imgui.ImGuiKey_LeftAlt,
    LEFTSUPER = imgui.ImGuiKey_LeftSuper,
    RIGHTCTRL = imgui.ImGuiKey_RightCtrl,
    RIGHTSHIFT = imgui.ImGuiKey_RightShift,
    RIGHTALT = imgui.ImGuiKey_RightAlt,
    RIGHTSUPER = imgui.ImGuiKey_RightSuper,
    MENU = imgui.ImGuiKey_Menu,
    ZERO = imgui.ImGuiKey_0,
    ONE = imgui.ImGuiKey_1,
    TWO = imgui.ImGuiKey_2,
    THREE = imgui.ImGuiKey_3,
    FOUR = imgui.ImGuiKey_4,
    FIVE = imgui.ImGuiKey_5,
    SIX = imgui.ImGuiKey_6,
    SEVEN = imgui.ImGuiKey_7,
    EIGHT = imgui.ImGuiKey_8,
    NINE = imgui.ImGuiKey_9,
    A = imgui.ImGuiKey_A,
    B = imgui.ImGuiKey_B,
    C = imgui.ImGuiKey_C,
    D = imgui.ImGuiKey_D,
    E = imgui.ImGuiKey_E,
    F = imgui.ImGuiKey_F,
    G = imgui.ImGuiKey_G,
    H = imgui.ImGuiKey_H,
    I = imgui.ImGuiKey_I,
    J = imgui.ImGuiKey_J,
    K = imgui.ImGuiKey_K,
    L = imgui.ImGuiKey_L,
    M = imgui.ImGuiKey_M,
    N = imgui.ImGuiKey_N,
    O = imgui.ImGuiKey_O,
    P = imgui.ImGuiKey_P,
    Q = imgui.ImGuiKey_Q,
    R = imgui.ImGuiKey_R,
    S = imgui.ImGuiKey_S,
    T = imgui.ImGuiKey_T,
    U = imgui.ImGuiKey_U,
    V = imgui.ImGuiKey_V,
    W = imgui.ImGuiKey_W,
    X = imgui.ImGuiKey_X,
    Y = imgui.ImGuiKey_Y,
    Z = imgui.ImGuiKey_Z,
    F1 = imgui.ImGuiKey_F1,
    F2 = imgui.ImGuiKey_F2,
    F3 = imgui.ImGuiKey_F3,
    F4 = imgui.ImGuiKey_F4,
    F5 = imgui.ImGuiKey_F5,
    F6 = imgui.ImGuiKey_F6,
    F7 = imgui.ImGuiKey_F7,
    F8 = imgui.ImGuiKey_F8,
    F9 = imgui.ImGuiKey_F9,
    F10 = imgui.ImGuiKey_F10,
    F11 = imgui.ImGuiKey_F11,
    F12 = imgui.ImGuiKey_F12,
    F13 = imgui.ImGuiKey_F13,
    F14 = imgui.ImGuiKey_F14,
    F15 = imgui.ImGuiKey_F15,
    F16 = imgui.ImGuiKey_F16,
    F17 = imgui.ImGuiKey_F17,
    F18 = imgui.ImGuiKey_F18,
    F19 = imgui.ImGuiKey_F19,
    F20 = imgui.ImGuiKey_F20,
    F21 = imgui.ImGuiKey_F21,
    F22 = imgui.ImGuiKey_F22,
    F23 = imgui.ImGuiKey_F23,
    F24 = imgui.ImGuiKey_F24,
    APOSTROPHE = imgui.ImGuiKey_Apostrophe,
    COMMA = imgui.ImGuiKey_Comma,
    MINUS = imgui.ImGuiKey_Minus,
    PERIOD = imgui.ImGuiKey_Period,
    SLASH = imgui.ImGuiKey_Slash,
    SEMICOLON = imgui.ImGuiKey_Semicolon,
    EQUAL = imgui.ImGuiKey_Equal,
    LEFTBRACKET = imgui.ImGuiKey_LeftBracket,
    BACKSLASH = imgui.ImGuiKey_Backslash,
    RIGHTBRACKET = imgui.ImGuiKey_RightBracket,
    GRAVEACCENT = imgui.ImGuiKey_GraveAccent,
    CAPSLOCK = imgui.ImGuiKey_CapsLock,
    SCROLLLOCK = imgui.ImGuiKey_ScrollLock,
    NUMLOCK = imgui.ImGuiKey_NumLock,
    PRINTSCREEN = imgui.ImGuiKey_PrintScreen,
    PAUSE = imgui.ImGuiKey_Pause,
    KEYPAD0 = imgui.ImGuiKey_Keypad0,
    KEYPAD1 = imgui.ImGuiKey_Keypad1,
    KEYPAD2 = imgui.ImGuiKey_Keypad2,
    KEYPAD3 = imgui.ImGuiKey_Keypad3,
    KEYPAD4 = imgui.ImGuiKey_Keypad4,
    KEYPAD5 = imgui.ImGuiKey_Keypad5,
    KEYPAD6 = imgui.ImGuiKey_Keypad6,
    KEYPAD7 = imgui.ImGuiKey_Keypad7,
    KEYPAD8 = imgui.ImGuiKey_Keypad8,
    KEYPAD9 = imgui.ImGuiKey_Keypad9,
    KEYPADDECIMAL = imgui.ImGuiKey_KeypadDecimal,
    KEYPADDIVIDE = imgui.ImGuiKey_KeypadDivide,
    KEYPADMULTIPLY = imgui.ImGuiKey_KeypadMultiply,
    KEYPADSUBTRACT = imgui.ImGuiKey_KeypadSubtract,
    KEYPADADD = imgui.ImGuiKey_KeypadAdd,
    KEYPADENTER = imgui.ImGuiKey_KeypadEnter,
    KEYPADEQUAL = imgui.ImGuiKey_KeypadEqual,
    APPBACK = imgui.ImGuiKey_AppBack,
    APPFORWARD = imgui.ImGuiKey_AppForward,
    GAMEPADSTART = imgui.ImGuiKey_GamepadStart,
    GAMEPADBACK = imgui.ImGuiKey_GamepadBack,
    GAMEPADFACELEFT = imgui.ImGuiKey_GamepadFaceLeft,
    GAMEPADFACERIGHT = imgui.ImGuiKey_GamepadFaceRight,
    GAMEPADFACEUP = imgui.ImGuiKey_GamepadFaceUp,
    GAMEPADFACEDOWN = imgui.ImGuiKey_GamepadFaceDown,
    GAMEPADDPADLEFT = imgui.ImGuiKey_GamepadDpadLeft,
    GAMEPADDPADRIGHT = imgui.ImGuiKey_GamepadDpadRight,
    GAMEPADDPADUP = imgui.ImGuiKey_GamepadDpadUp,
    GAMEPADDPADDOWN = imgui.ImGuiKey_GamepadDpadDown,
    GAMEPADL1 = imgui.ImGuiKey_GamepadL1,
    GAMEPADR1 = imgui.ImGuiKey_GamepadR1,
    GAMEPADL2 = imgui.ImGuiKey_GamepadL2,
    GAMEPADR2 = imgui.ImGuiKey_GamepadR2,
    GAMEPADL3 = imgui.ImGuiKey_GamepadL3,
    GAMEPADR3 = imgui.ImGuiKey_GamepadR3,
    GAMEPADLSTICKLEFT = imgui.ImGuiKey_GamepadLStickLeft,
    GAMEPADLSTICKRIGHT = imgui.ImGuiKey_GamepadLStickRight,
    GAMEPADLSTICKUP = imgui.ImGuiKey_GamepadLStickUp,
    GAMEPADLSTICKDOWN = imgui.ImGuiKey_GamepadLStickDown,
    GAMEPADRSTICKLEFT = imgui.ImGuiKey_GamepadRStickLeft,
    GAMEPADRSTICKRIGHT = imgui.ImGuiKey_GamepadRStickRight,
    GAMEPADRSTICKUP = imgui.ImGuiKey_GamepadRStickUp,
    GAMEPADRSTICKDOWN = imgui.ImGuiKey_GamepadRStickDown,
    MOUSELEFT = imgui.ImGuiKey_MouseLeft,
    MOUSERIGHT = imgui.ImGuiKey_MouseRight,
    MOUSEMIDDLE = imgui.ImGuiKey_MouseMiddle,
    MOUSEX1 = imgui.ImGuiKey_MouseX1,
    MOUSEX2 = imgui.ImGuiKey_MouseX2,
    MOUSEWHEELX = imgui.ImGuiKey_MouseWheelX,
    MOUSEWHEELY = imgui.ImGuiKey_MouseWheelY,
    RESERVEDFORMODCTRL = imgui.ImGuiKey_ReservedForModCtrl,
    RESERVEDFORMODSHIFT = imgui.ImGuiKey_ReservedForModShift,
    RESERVEDFORMODALT = imgui.ImGuiKey_ReservedForModAlt,
    RESERVEDFORMODSUPER = imgui.ImGuiKey_ReservedForModSuper

class KeyMod(IntFlag):
    NOMOD = 0,
    CTRL = imgui.ImGuiKey_ModCtrl,
    SHIFT = imgui.ImGuiKey_ModShift,
    ALT = imgui.ImGuiKey_ModAlt,
    SUPER = imgui.ImGuiKey_ModSuper

class KeyOrMod(IntFlag):
    NOMOD = 0,
    TAB = imgui.ImGuiKey_Tab,
    LEFTARROW = imgui.ImGuiKey_LeftArrow,
    RIGHTARROW = imgui.ImGuiKey_RightArrow,
    UPARROW = imgui.ImGuiKey_UpArrow,
    DOWNARROW = imgui.ImGuiKey_DownArrow,
    PAGEUP = imgui.ImGuiKey_PageUp,
    PAGEDOWN = imgui.ImGuiKey_PageDown,
    HOME = imgui.ImGuiKey_Home,
    END = imgui.ImGuiKey_End,
    INSERT = imgui.ImGuiKey_Insert,
    DELETE = imgui.ImGuiKey_Delete,
    BACKSPACE = imgui.ImGuiKey_Backspace,
    SPACE = imgui.ImGuiKey_Space,
    ENTER = imgui.ImGuiKey_Enter,
    ESCAPE = imgui.ImGuiKey_Escape,
    LEFTCTRL = imgui.ImGuiKey_LeftCtrl,
    LEFTSHIFT = imgui.ImGuiKey_LeftShift,
    LEFTALT = imgui.ImGuiKey_LeftAlt,
    LEFTSUPER = imgui.ImGuiKey_LeftSuper,
    RIGHTCTRL = imgui.ImGuiKey_RightCtrl,
    RIGHTSHIFT = imgui.ImGuiKey_RightShift,
    RIGHTALT = imgui.ImGuiKey_RightAlt,
    RIGHTSUPER = imgui.ImGuiKey_RightSuper,
    MENU = imgui.ImGuiKey_Menu,
    ZERO = imgui.ImGuiKey_0,
    ONE = imgui.ImGuiKey_1,
    TWO = imgui.ImGuiKey_2,
    THREE = imgui.ImGuiKey_3,
    FOUR = imgui.ImGuiKey_4,
    FIVE = imgui.ImGuiKey_5,
    SIX = imgui.ImGuiKey_6,
    SEVEN = imgui.ImGuiKey_7,
    EIGHT = imgui.ImGuiKey_8,
    NINE = imgui.ImGuiKey_9,
    A = imgui.ImGuiKey_A,
    B = imgui.ImGuiKey_B,
    C = imgui.ImGuiKey_C,
    D = imgui.ImGuiKey_D,
    E = imgui.ImGuiKey_E,
    F = imgui.ImGuiKey_F,
    G = imgui.ImGuiKey_G,
    H = imgui.ImGuiKey_H,
    I = imgui.ImGuiKey_I,
    J = imgui.ImGuiKey_J,
    K = imgui.ImGuiKey_K,
    L = imgui.ImGuiKey_L,
    M = imgui.ImGuiKey_M,
    N = imgui.ImGuiKey_N,
    O = imgui.ImGuiKey_O,
    P = imgui.ImGuiKey_P,
    Q = imgui.ImGuiKey_Q,
    R = imgui.ImGuiKey_R,
    S = imgui.ImGuiKey_S,
    T = imgui.ImGuiKey_T,
    U = imgui.ImGuiKey_U,
    V = imgui.ImGuiKey_V,
    W = imgui.ImGuiKey_W,
    X = imgui.ImGuiKey_X,
    Y = imgui.ImGuiKey_Y,
    Z = imgui.ImGuiKey_Z,
    F1 = imgui.ImGuiKey_F1,
    F2 = imgui.ImGuiKey_F2,
    F3 = imgui.ImGuiKey_F3,
    F4 = imgui.ImGuiKey_F4,
    F5 = imgui.ImGuiKey_F5,
    F6 = imgui.ImGuiKey_F6,
    F7 = imgui.ImGuiKey_F7,
    F8 = imgui.ImGuiKey_F8,
    F9 = imgui.ImGuiKey_F9,
    F10 = imgui.ImGuiKey_F10,
    F11 = imgui.ImGuiKey_F11,
    F12 = imgui.ImGuiKey_F12,
    F13 = imgui.ImGuiKey_F13,
    F14 = imgui.ImGuiKey_F14,
    F15 = imgui.ImGuiKey_F15,
    F16 = imgui.ImGuiKey_F16,
    F17 = imgui.ImGuiKey_F17,
    F18 = imgui.ImGuiKey_F18,
    F19 = imgui.ImGuiKey_F19,
    F20 = imgui.ImGuiKey_F20,
    F21 = imgui.ImGuiKey_F21,
    F22 = imgui.ImGuiKey_F22,
    F23 = imgui.ImGuiKey_F23,
    F24 = imgui.ImGuiKey_F24,
    APOSTROPHE = imgui.ImGuiKey_Apostrophe,
    COMMA = imgui.ImGuiKey_Comma,
    MINUS = imgui.ImGuiKey_Minus,
    PERIOD = imgui.ImGuiKey_Period,
    SLASH = imgui.ImGuiKey_Slash,
    SEMICOLON = imgui.ImGuiKey_Semicolon,
    EQUAL = imgui.ImGuiKey_Equal,
    LEFTBRACKET = imgui.ImGuiKey_LeftBracket,
    BACKSLASH = imgui.ImGuiKey_Backslash,
    RIGHTBRACKET = imgui.ImGuiKey_RightBracket,
    GRAVEACCENT = imgui.ImGuiKey_GraveAccent,
    CAPSLOCK = imgui.ImGuiKey_CapsLock,
    SCROLLLOCK = imgui.ImGuiKey_ScrollLock,
    NUMLOCK = imgui.ImGuiKey_NumLock,
    PRINTSCREEN = imgui.ImGuiKey_PrintScreen,
    PAUSE = imgui.ImGuiKey_Pause,
    KEYPAD0 = imgui.ImGuiKey_Keypad0,
    KEYPAD1 = imgui.ImGuiKey_Keypad1,
    KEYPAD2 = imgui.ImGuiKey_Keypad2,
    KEYPAD3 = imgui.ImGuiKey_Keypad3,
    KEYPAD4 = imgui.ImGuiKey_Keypad4,
    KEYPAD5 = imgui.ImGuiKey_Keypad5,
    KEYPAD6 = imgui.ImGuiKey_Keypad6,
    KEYPAD7 = imgui.ImGuiKey_Keypad7,
    KEYPAD8 = imgui.ImGuiKey_Keypad8,
    KEYPAD9 = imgui.ImGuiKey_Keypad9,
    KEYPADDECIMAL = imgui.ImGuiKey_KeypadDecimal,
    KEYPADDIVIDE = imgui.ImGuiKey_KeypadDivide,
    KEYPADMULTIPLY = imgui.ImGuiKey_KeypadMultiply,
    KEYPADSUBTRACT = imgui.ImGuiKey_KeypadSubtract,
    KEYPADADD = imgui.ImGuiKey_KeypadAdd,
    KEYPADENTER = imgui.ImGuiKey_KeypadEnter,
    KEYPADEQUAL = imgui.ImGuiKey_KeypadEqual,
    APPBACK = imgui.ImGuiKey_AppBack,
    APPFORWARD = imgui.ImGuiKey_AppForward,
    GAMEPADSTART = imgui.ImGuiKey_GamepadStart,
    GAMEPADBACK = imgui.ImGuiKey_GamepadBack,
    GAMEPADFACELEFT = imgui.ImGuiKey_GamepadFaceLeft,
    GAMEPADFACERIGHT = imgui.ImGuiKey_GamepadFaceRight,
    GAMEPADFACEUP = imgui.ImGuiKey_GamepadFaceUp,
    GAMEPADFACEDOWN = imgui.ImGuiKey_GamepadFaceDown,
    GAMEPADDPADLEFT = imgui.ImGuiKey_GamepadDpadLeft,
    GAMEPADDPADRIGHT = imgui.ImGuiKey_GamepadDpadRight,
    GAMEPADDPADUP = imgui.ImGuiKey_GamepadDpadUp,
    GAMEPADDPADDOWN = imgui.ImGuiKey_GamepadDpadDown,
    GAMEPADL1 = imgui.ImGuiKey_GamepadL1,
    GAMEPADR1 = imgui.ImGuiKey_GamepadR1,
    GAMEPADL2 = imgui.ImGuiKey_GamepadL2,
    GAMEPADR2 = imgui.ImGuiKey_GamepadR2,
    GAMEPADL3 = imgui.ImGuiKey_GamepadL3,
    GAMEPADR3 = imgui.ImGuiKey_GamepadR3,
    GAMEPADLSTICKLEFT = imgui.ImGuiKey_GamepadLStickLeft,
    GAMEPADLSTICKRIGHT = imgui.ImGuiKey_GamepadLStickRight,
    GAMEPADLSTICKUP = imgui.ImGuiKey_GamepadLStickUp,
    GAMEPADLSTICKDOWN = imgui.ImGuiKey_GamepadLStickDown,
    GAMEPADRSTICKLEFT = imgui.ImGuiKey_GamepadRStickLeft,
    GAMEPADRSTICKRIGHT = imgui.ImGuiKey_GamepadRStickRight,
    GAMEPADRSTICKUP = imgui.ImGuiKey_GamepadRStickUp,
    GAMEPADRSTICKDOWN = imgui.ImGuiKey_GamepadRStickDown,
    MOUSELEFT = imgui.ImGuiKey_MouseLeft,
    MOUSERIGHT = imgui.ImGuiKey_MouseRight,
    MOUSEMIDDLE = imgui.ImGuiKey_MouseMiddle,
    MOUSEX1 = imgui.ImGuiKey_MouseX1,
    MOUSEX2 = imgui.ImGuiKey_MouseX2,
    MOUSEWHEELX = imgui.ImGuiKey_MouseWheelX,
    MOUSEWHEELY = imgui.ImGuiKey_MouseWheelY,
    RESERVEDFORMODCTRL = imgui.ImGuiKey_ReservedForModCtrl,
    RESERVEDFORMODSHIFT = imgui.ImGuiKey_ReservedForModShift,
    RESERVEDFORMODALT = imgui.ImGuiKey_ReservedForModAlt,
    RESERVEDFORMODSUPER = imgui.ImGuiKey_ReservedForModSuper,
    CTRL = imgui.ImGuiKey_ModCtrl,
    SHIFT = imgui.ImGuiKey_ModShift,
    ALT = imgui.ImGuiKey_ModAlt,
    SUPER = imgui.ImGuiKey_ModSuper
