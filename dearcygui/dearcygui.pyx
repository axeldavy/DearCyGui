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
#distutils: language = c++

import threading
from concurrent.futures import ThreadPoolExecutor
import functools
from libcpp cimport bool
from libcpp.functional cimport function
import traceback

cimport cython
from cython.operator cimport dereference
from dearcygui.wrapper cimport *
from libc.stdlib cimport malloc, free

import sys

cdef extern from "../src/mvContext.h" nogil:
    cdef void initializeImGui()


ctypedef long long UUID
class constants:
    mvGraphicsBackend_D3D11 = 0
    mvGraphicsBackend_D3D12 = 1
    mvGraphicsBackend_VULKAN = 2
    mvGraphicsBackend_METAL = 3
    mvGraphicsBackend_OPENGL = 4

    #-----------------------------------------------------------------------------
    # Mouse Codes
    #-----------------------------------------------------------------------------
    mvMouseButton_Left = imgui.ImGuiMouseButton_Left
    mvMouseButton_Right = imgui.ImGuiMouseButton_Right
    mvMouseButton_Middle = imgui.ImGuiMouseButton_Middle
    mvMouseButton_X1 = 3  # imgui.ImGuiKey_MouseX1
    mvMouseButton_X2 = 4  # imgui.ImGuiKey_MouseX2

    #-----------------------------------------------------------------------------
    # Key Codes
    #-----------------------------------------------------------------------------
    mvKey_ModDisabled = -1
    mvKey_None = imgui.ImGuiKey_None
    mvKey_0 = imgui.ImGuiKey_0
    mvKey_1 = imgui.ImGuiKey_1
    mvKey_2 = imgui.ImGuiKey_2
    mvKey_3 = imgui.ImGuiKey_3
    mvKey_4 = imgui.ImGuiKey_4
    mvKey_5 = imgui.ImGuiKey_5
    mvKey_6 = imgui.ImGuiKey_6
    mvKey_7 = imgui.ImGuiKey_7
    mvKey_8 = imgui.ImGuiKey_8
    mvKey_9 = imgui.ImGuiKey_9
    mvKey_A = imgui.ImGuiKey_A
    mvKey_B = imgui.ImGuiKey_B
    mvKey_C = imgui.ImGuiKey_C
    mvKey_D = imgui.ImGuiKey_D
    mvKey_E = imgui.ImGuiKey_E
    mvKey_F = imgui.ImGuiKey_F
    mvKey_G = imgui.ImGuiKey_G
    mvKey_H = imgui.ImGuiKey_H
    mvKey_I = imgui.ImGuiKey_I
    mvKey_J = imgui.ImGuiKey_J
    mvKey_K = imgui.ImGuiKey_K
    mvKey_L = imgui.ImGuiKey_L
    mvKey_M = imgui.ImGuiKey_M
    mvKey_N = imgui.ImGuiKey_N
    mvKey_O = imgui.ImGuiKey_O
    mvKey_P = imgui.ImGuiKey_P
    mvKey_Q = imgui.ImGuiKey_Q
    mvKey_R = imgui.ImGuiKey_R
    mvKey_S = imgui.ImGuiKey_S
    mvKey_T = imgui.ImGuiKey_T
    mvKey_U = imgui.ImGuiKey_U
    mvKey_V = imgui.ImGuiKey_V
    mvKey_W = imgui.ImGuiKey_W
    mvKey_X = imgui.ImGuiKey_X
    mvKey_Y = imgui.ImGuiKey_Y
    mvKey_Z = imgui.ImGuiKey_Z
    mvKey_Back = imgui.ImGuiKey_Backspace
    mvKey_Tab = imgui.ImGuiKey_Tab
    mvKey_Return = imgui.ImGuiKey_Enter
    mvKey_LShift = imgui.ImGuiKey_LeftShift
    mvKey_RShift = imgui.ImGuiKey_RightShift
    mvKey_LControl = imgui.ImGuiKey_LeftCtrl
    mvKey_RControl = imgui.ImGuiKey_RightCtrl
    mvKey_LAlt = imgui.ImGuiKey_LeftAlt
    mvKey_RAlt = imgui.ImGuiKey_RightAlt
    mvKey_Pause = imgui.ImGuiKey_Pause
    mvKey_CapsLock = imgui.ImGuiKey_CapsLock
    mvKey_Escape = imgui.ImGuiKey_Escape
    mvKey_Spacebar = imgui.ImGuiKey_Space
    mvKey_End = imgui.ImGuiKey_End
    mvKey_Home = imgui.ImGuiKey_Home
    mvKey_Left = imgui.ImGuiKey_LeftArrow
    mvKey_Up = imgui.ImGuiKey_UpArrow
    mvKey_Right = imgui.ImGuiKey_RightArrow
    mvKey_Down = imgui.ImGuiKey_DownArrow
    mvKey_Print = imgui.ImGuiKey_PrintScreen
    mvKey_Insert = imgui.ImGuiKey_Insert
    mvKey_Delete = imgui.ImGuiKey_Delete
    mvKey_NumPad0 = imgui.ImGuiKey_Keypad0
    mvKey_NumPad1 = imgui.ImGuiKey_Keypad1
    mvKey_NumPad2 = imgui.ImGuiKey_Keypad2
    mvKey_NumPad3 = imgui.ImGuiKey_Keypad3
    mvKey_NumPad4 = imgui.ImGuiKey_Keypad4
    mvKey_NumPad5 = imgui.ImGuiKey_Keypad5
    mvKey_NumPad6 = imgui.ImGuiKey_Keypad6
    mvKey_NumPad7 = imgui.ImGuiKey_Keypad7
    mvKey_NumPad8 = imgui.ImGuiKey_Keypad8
    mvKey_NumPad9 = imgui.ImGuiKey_Keypad9
    mvKey_Subtract = imgui.ImGuiKey_KeypadSubtract
    mvKey_Decimal = imgui.ImGuiKey_KeypadDecimal
    mvKey_Divide = imgui.ImGuiKey_KeypadDivide
    mvKey_Multiply = imgui.ImGuiKey_KeypadMultiply
    mvKey_Add = imgui.ImGuiKey_KeypadAdd
    mvKey_F1 = imgui.ImGuiKey_F1
    mvKey_F2 = imgui.ImGuiKey_F2
    mvKey_F3 = imgui.ImGuiKey_F3
    mvKey_F4 = imgui.ImGuiKey_F4
    mvKey_F5 = imgui.ImGuiKey_F5
    mvKey_F6 = imgui.ImGuiKey_F6
    mvKey_F7 = imgui.ImGuiKey_F7
    mvKey_F8 = imgui.ImGuiKey_F8
    mvKey_F9 = imgui.ImGuiKey_F9
    mvKey_F10 = imgui.ImGuiKey_F10
    mvKey_F11 = imgui.ImGuiKey_F11
    mvKey_F12 = imgui.ImGuiKey_F12
    mvKey_F13 = imgui.ImGuiKey_F13
    mvKey_F14 = imgui.ImGuiKey_F14
    mvKey_F15 = imgui.ImGuiKey_F15
    mvKey_F16 = imgui.ImGuiKey_F16
    mvKey_F17 = imgui.ImGuiKey_F17
    mvKey_F18 = imgui.ImGuiKey_F18
    mvKey_F19 = imgui.ImGuiKey_F19
    mvKey_F20 = imgui.ImGuiKey_F20
    mvKey_F21 = imgui.ImGuiKey_F21
    mvKey_F22 = imgui.ImGuiKey_F22
    mvKey_F23 = imgui.ImGuiKey_F23
    mvKey_F24 = imgui.ImGuiKey_F24
    mvKey_NumLock = imgui.ImGuiKey_NumLock
    mvKey_ScrollLock = imgui.ImGuiKey_ScrollLock
    mvKey_Period = imgui.ImGuiKey_Period
    mvKey_Slash = imgui.ImGuiKey_Slash
    mvKey_Backslash = imgui.ImGuiKey_Backslash
    mvKey_Open_Brace = imgui.ImGuiKey_LeftBracket
    mvKey_Close_Brace = imgui.ImGuiKey_RightBracket
    mvKey_Browser_Back = imgui.ImGuiKey_AppBack
    mvKey_Browser_Forward = imgui.ImGuiKey_AppForward
    mvKey_Comma = imgui.ImGuiKey_Comma # -> it seems to be the old mvKey_Separator
    mvKey_Minus = imgui.ImGuiKey_Minus
    mvKey_Menu = imgui.ImGuiKey_Menu
    mvKey_ModSuper = imgui.ImGuiMod_Super # Cmd/Super/Windows
    mvKey_ModShift = imgui.ImGuiMod_Shift
    mvKey_ModAlt = imgui.ImGuiMod_Alt
    mvKey_ModCtrl = imgui.ImGuiMod_Ctrl

    mvAll = 0
    mvTool_About = 3 # MV_TOOL_ABOUT_UUID
    mvTool_Debug = 4 # MV_TOOL_DEBUG_UUID
    mvTool_Doc = 5 # MV_TOOL_DOC_UUID
    mvTool_ItemRegistry = 6 # MV_TOOL_ITEM_REGISTRY_UUID
    mvTool_Metrics = 7 # MV_TOOL_METRICS_UUID
    mvTool_Stack = 10 # MV_TOOL_STACK_UUID
    mvTool_Style = 8 # MV_TOOL_STYLE_UUID
    mvTool_Font = 9 # MV_TOOL_FONT_UUID
    mvFontAtlas = 2 # MV_ATLAS_UUID
    mvAppUUID = 1 # MV_APP_UUID
    mvInvalidUUID = 0 # MV_INVALID_UUID
    mvDir_None = imgui.ImGuiDir_None
    mvDir_Left = imgui.ImGuiDir_Left
    mvDir_Right = imgui.ImGuiDir_Right
    mvDir_Up = imgui.ImGuiDir_Up
    mvDir_Down = imgui.ImGuiDir_Down
    mvComboHeight_Small = 0
    mvComboHeight_Regular = 1
    mvComboHeight_Large = 2
    mvComboHeight_Largest = 3

    mvPlatform_Windows = 0
    mvPlatform_Apple = 1
    mvPlatform_Linux = 2

    mvColorEdit_AlphaPreviewNone = 0
    mvColorEdit_AlphaPreview = imgui.ImGuiColorEditFlags_AlphaPreview
    mvColorEdit_AlphaPreviewHalf = imgui.ImGuiColorEditFlags_AlphaPreviewHalf
    mvColorEdit_uint8 = imgui.ImGuiColorEditFlags_Uint8
    mvColorEdit_float = imgui.ImGuiColorEditFlags_Float
    mvColorEdit_rgb = imgui.ImGuiColorEditFlags_DisplayRGB
    mvColorEdit_hsv = imgui.ImGuiColorEditFlags_DisplayHSV
    mvColorEdit_hex = imgui.ImGuiColorEditFlags_DisplayHex
    mvColorEdit_input_rgb = imgui.ImGuiColorEditFlags_InputRGB
    mvColorEdit_input_hsv = imgui.ImGuiColorEditFlags_InputHSV

    mvPlotColormap_Default = implot.ImPlotColormap_Deep # implot.ImPlot default colormap         (n=10)
    mvPlotColormap_Deep = implot.ImPlotColormap_Deep # a.k.a. seaborn deep (default) (n=10)
    mvPlotColormap_Dark = implot.ImPlotColormap_Dark # a.k.a. matplotlib "Set1"        (n=9)
    mvPlotColormap_Pastel = implot.ImPlotColormap_Pastel # a.k.a. matplotlib "Pastel1"     (n=9)
    mvPlotColormap_Paired = implot.ImPlotColormap_Paired # a.k.a. matplotlib "Paired"      (n=12)
    mvPlotColormap_Viridis = implot.ImPlotColormap_Viridis # a.k.a. matplotlib "viridis"     (n=11)
    mvPlotColormap_Plasma = implot.ImPlotColormap_Plasma # a.k.a. matplotlib "plasma"      (n=11)
    mvPlotColormap_Hot = implot.ImPlotColormap_Hot # a.k.a. matplotlib/MATLAB "hot"  (n=11)
    mvPlotColormap_Cool = implot.ImPlotColormap_Cool # a.k.a. matplotlib/MATLAB "cool" (n=11)
    mvPlotColormap_Pink = implot.ImPlotColormap_Pink # a.k.a. matplotlib/MATLAB "pink" (n=11)
    mvPlotColormap_Jet = implot.ImPlotColormap_Jet # a.k.a. MATLAB "jet"             (n=11)
    mvPlotColormap_Twilight = implot.ImPlotColormap_Twilight # a.k.a. MATLAB "twilight"             (n=11)
    mvPlotColormap_RdBu = implot.ImPlotColormap_RdBu # red/blue, Color Brewer            (n=11)
    mvPlotColormap_BrBG = implot.ImPlotColormap_BrBG # brown/blue-green, Color Brewer             (n=11)
    mvPlotColormap_PiYG = implot.ImPlotColormap_PiYG # pink/yellow-green, Color Brewer             (n=11)
    mvPlotColormap_Spectral = implot.ImPlotColormap_Spectral # color spectrum, Color Brewer             (n=11)
    mvPlotColormap_Greys = implot.ImPlotColormap_Greys # white/black             (n=11)

    mvColorPicker_bar = imgui.ImGuiColorEditFlags_PickerHueBar
    mvColorPicker_wheel = imgui.ImGuiColorEditFlags_PickerHueWheel

    mvTabOrder_Reorderable = 0
    mvTabOrder_Fixed = 1
    mvTabOrder_Leading = 2
    mvTabOrder_Trailing = 3

    mvTimeUnit_Us = 0
    mvTimeUnit_Ms = 1
    mvTimeUnit_S = 2
    mvTimeUnit_Min = 3
    mvTimeUnit_Hr = 4
    mvTimeUnit_Day = 5
    mvTimeUnit_Mo = 6
    mvTimeUnit_Yr = 7

    mvDatePickerLevel_Day = 0
    mvDatePickerLevel_Month = 1
    mvDatePickerLevel_Year = 2

    mvCullMode_None = 0
    mvCullMode_Back = 1
    mvCullMode_Front = 2

    mvFontRangeHint_Default = 0
    mvFontRangeHint_Japanese = 1
    mvFontRangeHint_Korean = 2
    mvFontRangeHint_Chinese_Full = 3
    mvFontRangeHint_Chinese_Simplified_Common = 4
    mvFontRangeHint_Cyrillic = 5
    mvFontRangeHint_Thai = 6
    mvFontRangeHint_Vietnamese = 7

    mvNode_PinShape_Circle = imnodes.ImNodesPinShape_Circle
    mvNode_PinShape_CircleFilled = imnodes.ImNodesPinShape_CircleFilled
    mvNode_PinShape_Triangle = imnodes.ImNodesPinShape_Triangle
    mvNode_PinShape_TriangleFilled = imnodes.ImNodesPinShape_TriangleFilled
    mvNode_PinShape_Quad = imnodes.ImNodesPinShape_Quad
    mvNode_PinShape_QuadFilled = imnodes.ImNodesPinShape_QuadFilled

    mvNode_Attr_Input = 0
    mvNode_Attr_Output = 1
    mvNode_Attr_Static = 2

    mvPlotBin_Sqrt = -1
    mvPlotBin_Sturges = -2
    mvPlotBin_Rice = -3
    mvPlotBin_Scott = -4

    mvXAxis = implot.ImAxis_X1
    mvXAxis2 = implot.ImAxis_X2
    mvXAxis3 = implot.ImAxis_X3
    mvYAxis = implot.ImAxis_Y1
    mvYAxis2 = implot.ImAxis_Y2
    mvYAxis3 = implot.ImAxis_Y3
    
    mvPlotScale_Linear = implot.ImPlotScale_Linear  # default linear scale
    mvPlotScale_Time = implot.ImPlotScale_Time  # date/time scale
    mvPlotScale_Log10 = implot.ImPlotScale_Log10  # base 10 logartithmic scale
    mvPlotScale_SymLog = implot.ImPlotScale_SymLog  # symmetric log scale

    mvPlotMarker_None = implot.ImPlotMarker_None  # no marker
    mvPlotMarker_Circle =  implot.ImPlotMarker_Circle  # a circle marker will be rendered at each point
    mvPlotMarker_Square =  implot.ImPlotMarker_Square  # a square maker will be rendered at each point
    mvPlotMarker_Diamond =  implot.ImPlotMarker_Diamond  # a diamond marker will be rendered at each point
    mvPlotMarker_Up =  implot.ImPlotMarker_Up  # an upward-pointing triangle marker will up rendered at each point
    mvPlotMarker_Down =  implot.ImPlotMarker_Down  # an downward-pointing triangle marker will up rendered at each point
    mvPlotMarker_Left =  implot.ImPlotMarker_Left  # an leftward-pointing triangle marker will up rendered at each point
    mvPlotMarker_Right =  implot.ImPlotMarker_Right  # an rightward-pointing triangle marker will up rendered at each point
    mvPlotMarker_Cross =  implot.ImPlotMarker_Cross  # a cross marker will be rendered at each point (not filled)
    mvPlotMarker_Plus =  implot.ImPlotMarker_Plus  # a plus marker will be rendered at each point (not filled)
    mvPlotMarker_Asterisk =  implot.ImPlotMarker_Asterisk # a asterisk marker will be rendered at each point (not filled)

    mvPlot_Location_Center = implot.ImPlotLocation_Center
    mvPlot_Location_North = implot.ImPlotLocation_North
    mvPlot_Location_South = implot.ImPlotLocation_South
    mvPlot_Location_West = implot.ImPlotLocation_West
    mvPlot_Location_East = implot.ImPlotLocation_East
    mvPlot_Location_NorthWest = implot.ImPlotLocation_NorthWest
    mvPlot_Location_NorthEast = implot.ImPlotLocation_NorthEast
    mvPlot_Location_SouthWest = implot.ImPlotLocation_SouthWest
    mvPlot_Location_SouthEast = implot.ImPlotLocation_SouthEast

    mvNodeMiniMap_Location_BottomLeft = imnodes.ImNodesMiniMapLocation_BottomLeft
    mvNodeMiniMap_Location_BottomRight = imnodes.ImNodesMiniMapLocation_BottomRight
    mvNodeMiniMap_Location_TopLeft =imnodes. ImNodesMiniMapLocation_TopLeft
    mvNodeMiniMap_Location_TopRight = imnodes.ImNodesMiniMapLocation_TopRight

    mvTable_SizingFixedFit = imgui.ImGuiTableFlags_SizingFixedFit
    mvTable_SizingFixedSame = imgui.ImGuiTableFlags_SizingFixedSame
    mvTable_SizingStretchProp = imgui.ImGuiTableFlags_SizingStretchProp
    mvTable_SizingStretchSame = imgui.ImGuiTableFlags_SizingStretchSame

    mvFormat_Float_rgba = 0
    mvFormat_Float_rgb = 1

    mvThemeCat_Core = 0
    mvThemeCat_Plots = 1
    mvThemeCat_Nodes = 2

    mvThemeCol_Text = imgui.ImGuiCol_Text
    mvThemeCol_TextDisabled = imgui.ImGuiCol_TextDisabled
    mvThemeCol_WindowBg = imgui.ImGuiCol_WindowBg            # Background of normal windows
    mvThemeCol_ChildBg = imgui.ImGuiCol_ChildBg              # Background of child windows
    mvThemeCol_Border = imgui.ImGuiCol_Border                # Background of popups, menus, tooltips windows
    mvThemeCol_PopupBg = imgui.ImGuiCol_PopupBg              # Background of popups, menus, tooltips windows
    mvThemeCol_BorderShadow = imgui.ImGuiCol_BorderShadow
    mvThemeCol_FrameBg = imgui.ImGuiCol_FrameBg             # Background of checkbox, radio button, plot, slider, text input
    mvThemeCol_FrameBgHovered = imgui.ImGuiCol_FrameBgHovered
    mvThemeCol_FrameBgActive = imgui.ImGuiCol_FrameBgActive
    mvThemeCol_TitleBg = imgui.ImGuiCol_TitleBg
    mvThemeCol_TitleBgActive = imgui.ImGuiCol_TitleBgActive
    mvThemeCol_TitleBgCollapsed = imgui.ImGuiCol_TitleBgCollapsed
    mvThemeCol_MenuBarBg = imgui.ImGuiCol_MenuBarBg
    mvThemeCol_ScrollbarBg = imgui.ImGuiCol_ScrollbarBg
    mvThemeCol_ScrollbarGrab = imgui.ImGuiCol_ScrollbarGrab
    mvThemeCol_ScrollbarGrabHovered = imgui.ImGuiCol_ScrollbarGrabHovered
    mvThemeCol_ScrollbarGrabActive = imgui.ImGuiCol_ScrollbarGrabActive
    mvThemeCol_CheckMark = imgui.ImGuiCol_CheckMark
    mvThemeCol_SliderGrab = imgui.ImGuiCol_SliderGrab
    mvThemeCol_SliderGrabActive = imgui.ImGuiCol_SliderGrabActive
    mvThemeCol_Button = imgui.ImGuiCol_Button
    mvThemeCol_ButtonHovered = imgui.ImGuiCol_ButtonHovered
    mvThemeCol_ButtonActive = imgui.ImGuiCol_ButtonActive
    mvThemeCol_Header = imgui.ImGuiCol_Header              # Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
    mvThemeCol_HeaderHovered = imgui.ImGuiCol_HeaderHovered
    mvThemeCol_HeaderActive = imgui.ImGuiCol_HeaderActive
    mvThemeCol_Separator = imgui.ImGuiCol_Separator
    mvThemeCol_SeparatorHovered = imgui.ImGuiCol_SeparatorHovered
    mvThemeCol_SeparatorActive = imgui.ImGuiCol_SeparatorActive
    mvThemeCol_ResizeGrip = imgui.ImGuiCol_ResizeGrip
    mvThemeCol_ResizeGripHovered = imgui.ImGuiCol_ResizeGripHovered
    mvThemeCol_ResizeGripActive = imgui.ImGuiCol_ResizeGripActive
    mvThemeCol_Tab = imgui.ImGuiCol_Tab
    mvThemeCol_TabHovered = imgui.ImGuiCol_TabHovered
    mvThemeCol_TabActive = imgui.ImGuiCol_TabActive
    mvThemeCol_TabUnfocused = imgui.ImGuiCol_TabUnfocused
    mvThemeCol_TabUnfocusedActive = imgui.ImGuiCol_TabUnfocusedActive
    mvThemeCol_DockingPreview = imgui.ImGuiCol_DockingPreview
    mvThemeCol_DockingEmptyBg = imgui.ImGuiCol_DockingEmptyBg
    mvThemeCol_PlotLines = imgui.ImGuiCol_PlotLines
    mvThemeCol_PlotLinesHovered = imgui.ImGuiCol_PlotLinesHovered
    mvThemeCol_PlotHistogram = imgui.ImGuiCol_PlotHistogram
    mvThemeCol_PlotHistogramHovered = imgui.ImGuiCol_PlotHistogramHovered
    mvThemeCol_TableHeaderBg = imgui.ImGuiCol_TableHeaderBg           # Table header background
    mvThemeCol_TableBorderStrong = imgui.ImGuiCol_TableBorderStrong   # Table outer and header borders (prefer using Alpha=1.0 here)
    mvThemeCol_TableBorderLight = imgui.ImGuiCol_TableBorderLight     # Table inner borders (prefer using Alpha=1.0 here)
    mvThemeCol_TableRowBg = imgui.ImGuiCol_TableRowBg                 # Table row background (even rows)
    mvThemeCol_TableRowBgAlt = imgui.ImGuiCol_TableRowBgAlt           # Table row background (odd rows)
    mvThemeCol_TextSelectedBg = imgui.ImGuiCol_TextSelectedBg
    mvThemeCol_DragDropTarget = imgui.ImGuiCol_DragDropTarget
    mvThemeCol_NavHighlight = imgui.ImGuiCol_NavHighlight                   # Gamepad/keyboard: current highlighted item
    mvThemeCol_NavWindowingHighlight = imgui.ImGuiCol_NavWindowingHighlight # Highlight window when using CTRL+TAB
    mvThemeCol_NavWindowingDimBg = imgui.ImGuiCol_NavWindowingDimBg         # Darken/colorize entire screen behind the CTRL+TAB window list = when active
    mvThemeCol_ModalWindowDimBg = imgui.ImGuiCol_ModalWindowDimBg           # Darken/colorize entire screen behind a modal window = when one is active

    # plotting

    # item styling colors
    mvPlotCol_Line = implot.ImPlotCol_Line                   # plot line/outline color (defaults to next unused color in current colormap)
    mvPlotCol_Fill = implot.ImPlotCol_Fill                   # plot fill color for bars (defaults to the current line color)
    mvPlotCol_MarkerOutline = implot.ImPlotCol_MarkerOutline # marker outline color (defaults to the current line color)
    mvPlotCol_MarkerFill = implot.ImPlotCol_MarkerFill       # marker fill color (defaults to the current line color)
    mvPlotCol_ErrorBar = implot.ImPlotCol_ErrorBar           # error bar color (defaults to ImGuiCol_Text)

    # plot styling colors
    mvPlotCol_FrameBg = implot.ImPlotCol_FrameBg           # plot frame background color (defaults to ImGuiCol_FrameBg)
    mvPlotCol_PlotBg = implot.ImPlotCol_PlotBg             # plot area background color (defaults to ImGuiCol_WindowBg)
    mvPlotCol_PlotBorder = implot.ImPlotCol_PlotBorder     # plot area border color (defaults to ImGuiCol_Border)
    mvPlotCol_LegendBg = implot.ImPlotCol_LegendBg         # legend background color (defaults to ImGuiCol_PopupBg)
    mvPlotCol_LegendBorder = implot.ImPlotCol_LegendBorder # legend border color (defaults to implot.ImPlotCol_PlotBorder)
    mvPlotCol_LegendText = implot.ImPlotCol_LegendText     # legend text color (defaults to implot.ImPlotCol_InlayText)
    mvPlotCol_TitleText = implot.ImPlotCol_TitleText       # plot title text color (defaults to ImGuiCol_Text)
    mvPlotCol_InlayText = implot.ImPlotCol_InlayText       # color of text appearing inside of plots (defaults to ImGuiCol_Text)
    mvPlotCol_AxisBg = implot.ImPlotCol_AxisBg             # background color of axis hover region (defaults to transparent)
    mvPlotCol_AxisBgActive = implot.ImPlotCol_AxisBgActive # axis active color (defaults to ImGuiCol_ButtonActive)
    mvPlotCol_AxisBgHovered = implot.ImPlotCol_AxisBgHovered# axis hover color (defaults to ImGuiCol_ButtonHovered)
    mvPlotCol_AxisGrid = implot.ImPlotCol_AxisGrid         # axis tick lables color (defaults to ImGuiCol_Text)
    mvPlotCol_AxisText = implot.ImPlotCol_AxisText         # axis label color (defaults to ImGuiCol_Text)
    mvPlotCol_Selection = implot.ImPlotCol_Selection       # box-selection color (defaults to yellow)
    mvPlotCol_Crosshairs = implot.ImPlotCol_Crosshairs     # crosshairs color (defaults to implot.ImPlotCol_PlotBorder)

    # nodes
    mvNodeCol_NodeBackground = imnodes.ImNodesCol_NodeBackground
    mvNodeCol_NodeBackgroundHovered = imnodes.ImNodesCol_NodeBackgroundHovered
    mvNodeCol_NodeBackgroundSelected = imnodes.ImNodesCol_NodeBackgroundSelected
    mvNodeCol_NodeOutline = imnodes.ImNodesCol_NodeOutline
    mvNodeCol_TitleBar = imnodes.ImNodesCol_TitleBar
    mvNodeCol_TitleBarHovered = imnodes.ImNodesCol_TitleBarHovered
    mvNodeCol_TitleBarSelected = imnodes.ImNodesCol_TitleBarSelected
    mvNodeCol_Link = imnodes.ImNodesCol_Link
    mvNodeCol_LinkHovered = imnodes.ImNodesCol_LinkHovered
    mvNodeCol_LinkSelected = imnodes.ImNodesCol_LinkSelected
    mvNodeCol_Pin = imnodes.ImNodesCol_Pin
    mvNodeCol_PinHovered = imnodes.ImNodesCol_PinHovered
    mvNodeCol_BoxSelector = imnodes.ImNodesCol_BoxSelector
    mvNodeCol_BoxSelectorOutline = imnodes.ImNodesCol_BoxSelectorOutline
    mvNodeCol_GridBackground = imnodes.ImNodesCol_GridBackground
    mvNodeCol_GridLine = imnodes.ImNodesCol_GridLine
    mvNodesCol_GridLinePrimary = imnodes.ImNodesCol_GridLinePrimary
    mvNodesCol_MiniMapBackground = imnodes.ImNodesCol_MiniMapBackground
    mvNodesCol_MiniMapBackgroundHovered = imnodes.ImNodesCol_MiniMapBackgroundHovered
    mvNodesCol_MiniMapOutline = imnodes.ImNodesCol_MiniMapOutline
    mvNodesCol_MiniMapOutlineHovered = imnodes.ImNodesCol_MiniMapOutlineHovered
    mvNodesCol_MiniMapNodeBackground = imnodes.ImNodesCol_MiniMapNodeBackground
    mvNodesCol_MiniMapNodeBackgroundHovered = imnodes.ImNodesCol_MiniMapNodeBackgroundHovered
    mvNodesCol_MiniMapNodeBackgroundSelected = imnodes.ImNodesCol_MiniMapNodeBackgroundSelected
    mvNodesCol_MiniMapNodeOutline = imnodes.ImNodesCol_MiniMapNodeOutline
    mvNodesCol_MiniMapLink = imnodes.ImNodesCol_MiniMapLink
    mvNodesCol_MiniMapLinkSelected = imnodes.ImNodesCol_MiniMapLinkSelected
    mvNodesCol_MiniMapCanvas = imnodes.ImNodesCol_MiniMapCanvas
    mvNodesCol_MiniMapCanvasOutline = imnodes.ImNodesCol_MiniMapCanvasOutline


    mvStyleVar_Alpha = imgui.ImGuiStyleVar_Alpha                             # float     Alpha
    mvStyleVar_DisabledAlpha = imgui.ImGuiStyleVar_DisabledAlpha             # float     DisabledAlpha
    mvStyleVar_WindowPadding = imgui.ImGuiStyleVar_WindowPadding             # ImVec2    WindowPadding
    mvStyleVar_WindowRounding = imgui.ImGuiStyleVar_WindowRounding           # float     WindowRounding
    mvStyleVar_WindowBorderSize = imgui.ImGuiStyleVar_WindowBorderSize       # float     WindowBorderSize
    mvStyleVar_WindowMinSize = imgui.ImGuiStyleVar_WindowMinSize             # ImVec2    WindowMinSize
    mvStyleVar_WindowTitleAlign = imgui.ImGuiStyleVar_WindowTitleAlign       # ImVec2    WindowTitleAlign
    mvStyleVar_ChildRounding = imgui.ImGuiStyleVar_ChildRounding             # float     ChildRounding
    mvStyleVar_ChildBorderSize = imgui.ImGuiStyleVar_ChildBorderSize         # float     ChildBorderSize
    mvStyleVar_PopupRounding = imgui.ImGuiStyleVar_PopupRounding             # float     PopupRounding
    mvStyleVar_PopupBorderSize = imgui.ImGuiStyleVar_PopupBorderSize         # float     PopupBorderSize
    mvStyleVar_FramePadding = imgui.ImGuiStyleVar_FramePadding               # ImVec2    FramePadding
    mvStyleVar_FrameRounding = imgui.ImGuiStyleVar_FrameRounding             # float     FrameRounding
    mvStyleVar_FrameBorderSize = imgui.ImGuiStyleVar_FrameBorderSize         # float     FrameBorderSize
    mvStyleVar_ItemSpacing = imgui.ImGuiStyleVar_ItemSpacing                 # ImVec2    ItemSpacing
    mvStyleVar_ItemInnerSpacing = imgui.ImGuiStyleVar_ItemInnerSpacing       # ImVec2    ItemInnerSpacing
    mvStyleVar_IndentSpacing = imgui.ImGuiStyleVar_IndentSpacing             # float     IndentSpacing
    mvStyleVar_CellPadding = imgui.ImGuiStyleVar_CellPadding                 # ImVec2    CellPadding
    mvStyleVar_ScrollbarSize = imgui.ImGuiStyleVar_ScrollbarSize             # float     ScrollbarSize
    mvStyleVar_ScrollbarRounding = imgui.ImGuiStyleVar_ScrollbarRounding     # float     ScrollbarRounding
    mvStyleVar_GrabMinSize = imgui.ImGuiStyleVar_GrabMinSize                 # float     GrabMinSize
    mvStyleVar_GrabRounding = imgui.ImGuiStyleVar_GrabRounding               # float     GrabRounding
    mvStyleVar_TabRounding = imgui.ImGuiStyleVar_TabRounding                 # float     TabRounding
    mvStyleVar_TabBorderSize = imgui.ImGuiStyleVar_TabBorderSize        	# float     TabBorderSize
    mvStyleVar_TabBarBorderSize = imgui.ImGuiStyleVar_TabBarBorderSize    	# float     TabBarBorderSize
    mvStyleVar_TableAngledHeadersAngle = imgui.ImGuiStyleVar_TableAngledHeadersAngle        # float     TableAngledHeadersAngle
    mvStyleVar_TableAngledHeadersTextAlign = imgui.ImGuiStyleVar_TableAngledHeadersTextAlign # ImVec2     TableAngledHeadersTextAlign
    mvStyleVar_ButtonTextAlign = imgui.ImGuiStyleVar_ButtonTextAlign         # ImVec2    ButtonTextAlign
    mvStyleVar_SelectableTextAlign = imgui.ImGuiStyleVar_SelectableTextAlign # ImVec2    SelectableTextAlign
    mvStyleVar_SeparatorTextBorderSize = imgui.ImGuiStyleVar_SeparatorTextBorderSize	# float     SeparatorTextBorderSize
    mvStyleVar_SeparatorTextAlign = imgui.ImGuiStyleVar_SeparatorTextAlign        # ImVec2    SeparatorTextAlign
    mvStyleVar_SeparatorTextPadding = imgui.ImGuiStyleVar_SeparatorTextPadding    	# ImVec2    SeparatorTextPadding
    mvStyleVar_DockingSeparatorSize = imgui.ImGuiStyleVar_DockingSeparatorSize    	# float     DockingSeparatorSize    

    # item styling variables
    mvPlotStyleVar_LineWeight =         implot.ImPlotStyleVar_LineWeight         # float,  plot item line weight in pixels
    mvPlotStyleVar_Marker =             implot.ImPlotStyleVar_Marker             # int,    marker specification
    mvPlotStyleVar_MarkerSize =         implot.ImPlotStyleVar_MarkerSize         # float,  marker size in pixels (roughly the marker's "radius")
    mvPlotStyleVar_MarkerWeight =       implot.ImPlotStyleVar_MarkerWeight       # float,  plot outline weight of markers in pixels
    mvPlotStyleVar_FillAlpha =          implot.ImPlotStyleVar_FillAlpha          # float,  alpha modifier applied to all plot item fills
    mvPlotStyleVar_ErrorBarSize =       implot.ImPlotStyleVar_ErrorBarSize       # float,  error bar whisker width in pixels
    mvPlotStyleVar_ErrorBarWeight =     implot.ImPlotStyleVar_ErrorBarWeight     # float,  error bar whisker weight in pixels
    mvPlotStyleVar_DigitalBitHeight =   implot.ImPlotStyleVar_DigitalBitHeight   # float,  digital channels bit height (at 1) in pixels
    mvPlotStyleVar_DigitalBitGap =      implot.ImPlotStyleVar_DigitalBitGap      # float,  digital channels bit padding gap in pixels

    # plot styling variables
    mvPlotStyleVar_PlotBorderSize = implot.ImPlotStyleVar_PlotBorderSize         # float,  thickness of border around plot area
    mvPlotStyleVar_MinorAlpha = implot.ImPlotStyleVar_MinorAlpha                 # float,  alpha multiplier applied to minor axis grid lines
    mvPlotStyleVar_MajorTickLen = implot.ImPlotStyleVar_MajorTickLen             # ImVec2, major tick lengths for X and Y axes
    mvPlotStyleVar_MinorTickLen = implot.ImPlotStyleVar_MinorTickLen             # ImVec2, minor tick lengths for X and Y axes
    mvPlotStyleVar_MajorTickSize = implot.ImPlotStyleVar_MajorTickSize           # ImVec2, line thickness of major ticks
    mvPlotStyleVar_MinorTickSize = implot.ImPlotStyleVar_MinorTickSize           # ImVec2, line thickness of minor ticks
    mvPlotStyleVar_MajorGridSize = implot.ImPlotStyleVar_MajorGridSize           # ImVec2, line thickness of major grid lines
    mvPlotStyleVar_MinorGridSize = implot.ImPlotStyleVar_MinorGridSize           # ImVec2, line thickness of minor grid lines
    mvPlotStyleVar_PlotPadding = implot.ImPlotStyleVar_PlotPadding               # ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
    mvPlotStyleVar_LabelPadding = implot.ImPlotStyleVar_LabelPadding             # ImVec2, padding between axes labels, tick labels, and plot edge
    mvPlotStyleVar_LegendPadding = implot.ImPlotStyleVar_LegendPadding           # ImVec2, legend padding from plot edges
    mvPlotStyleVar_LegendInnerPadding = implot.ImPlotStyleVar_LegendInnerPadding # ImVec2, legend inner padding from legend edges
    mvPlotStyleVar_LegendSpacing = implot.ImPlotStyleVar_LegendSpacing           # ImVec2, spacing between legend entries
    mvPlotStyleVar_MousePosPadding = implot.ImPlotStyleVar_MousePosPadding       # ImVec2, padding between plot edge and interior info text
    mvPlotStyleVar_AnnotationPadding = implot.ImPlotStyleVar_AnnotationPadding   # ImVec2, text padding around annotation labels
    mvPlotStyleVar_FitPadding = implot.ImPlotStyleVar_FitPadding                 # ImVec2, additional fit padding as a percentage of the fit extents (e.g. ImVec2(0.1f,0.1f) adds 10% to the fit extents of X and Y)
    mvPlotStyleVar_PlotDefaultSize = implot.ImPlotStyleVar_PlotDefaultSize       # ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
    mvPlotStyleVar_PlotMinSize = implot.ImPlotStyleVar_PlotMinSize               # ImVec2, minimum size plot frame can be when shrunk

    # nodes
    mvNodeStyleVar_GridSpacing = imnodes.ImNodesStyleVar_GridSpacing
    mvNodeStyleVar_NodeCornerRounding = imnodes.ImNodesStyleVar_NodeCornerRounding
    mvNodeStyleVar_NodePadding = imnodes.ImNodesStyleVar_NodePadding
    mvNodeStyleVar_NodeBorderThickness = imnodes.ImNodesStyleVar_NodeBorderThickness
    mvNodeStyleVar_LinkThickness = imnodes.ImNodesStyleVar_LinkThickness
    mvNodeStyleVar_LinkLineSegmentsPerLength = imnodes.ImNodesStyleVar_LinkLineSegmentsPerLength
    mvNodeStyleVar_LinkHoverDistance = imnodes.ImNodesStyleVar_LinkHoverDistance
    mvNodeStyleVar_PinCircleRadius = imnodes.ImNodesStyleVar_PinCircleRadius
    mvNodeStyleVar_PinQuadSideLength = imnodes.ImNodesStyleVar_PinQuadSideLength
    mvNodeStyleVar_PinTriangleSideLength = imnodes.ImNodesStyleVar_PinTriangleSideLength
    mvNodeStyleVar_PinLineThickness = imnodes.ImNodesStyleVar_PinLineThickness
    mvNodeStyleVar_PinHoverRadius = imnodes.ImNodesStyleVar_PinHoverRadius
    mvNodeStyleVar_PinOffset = imnodes.ImNodesStyleVar_PinOffset
    mvNodesStyleVar_MiniMapPadding = imnodes.ImNodesStyleVar_MiniMapPadding
    mvNodesStyleVar_MiniMapOffset = imnodes.ImNodesStyleVar_MiniMapOffset

class win32_constants:
    mvKey_Clear = 0x0C
    mvKey_Prior = 0x21
    mvKey_Next = 0x22
    mvKey_Select = 0x29
    mvKey_Execute = 0x2B
    mvKey_LWin = 0x5B
    mvKey_RWin = 0x5C
    mvKey_Apps = 0x5D
    mvKey_Sleep = 0x5F
    mvKey_Help = 0x2F
    mvKey_Browser_Refresh = 0xA8
    mvKey_Browser_Stop = 0xA9
    mvKey_Browser_Search = 0xAA
    mvKey_Browser_Favorites = 0xAB
    mvKey_Browser_Home = 0xAC
    mvKey_Volume_Mute = 0xAD
    mvKey_Volume_Down = 0xAE
    mvKey_Volume_Up = 0xAF
    mvKey_Media_Next_Track = 0xB0
    mvKey_Media_Prev_Track = 0xB1
    mvKey_Media_Stop = 0xB2
    mvKey_Media_Play_Pause = 0xB3
    mvKey_Launch_Mail = 0xB4
    mvKey_Launch_Media_Select = 0xB5
    mvKey_Launch_App1 = 0xB6
    mvKey_Launch_App2 = 0xB7
    mvKey_Colon = 0xBA
    mvKey_Plus = 0xBB
    mvKey_Tilde = 0xC0
    mvKey_Quote = 0xDE
    mvKey_F25 = 0x88

class unix_constants:
    mvKey_Clear = 259
    mvKey_Prior = 266
    mvKey_Next = 267
    mvKey_Select = -1
    mvKey_Execute = -1
    mvKey_LWin = 343
    mvKey_RWin = 347
    mvKey_Apps = -1
    mvKey_Sleep = -1
    mvKey_Help = -1
    mvKey_Browser_Refresh = -1
    mvKey_Browser_Stop = -1
    mvKey_Browser_Search = -1
    mvKey_Browser_Favorites = -1
    mvKey_Browser_Home = -1
    mvKey_Volume_Mute = -1
    mvKey_Volume_Down = -1
    mvKey_Volume_Up = -1
    mvKey_Media_Next_Track = -1
    mvKey_Media_Prev_Track = -1
    mvKey_Media_Stop = -1
    mvKey_Media_Play_Pause = -1
    mvKey_Launch_Mail = -1
    mvKey_Launch_Media_Select = -1
    mvKey_Launch_App1 = -1
    mvKey_Launch_App2 = -1
    mvKey_Colon = 59
    mvKey_Plus = 61
    mvKey_Tilde = 96
    mvKey_Quote = 39
    mvKey_F25 = 314

if sys.platform == "win32":
    for (key, value) in win32_constants.__dict__.items():
        setattr(constants, key, value)
else:
    for (key, value) in unix_constants.__dict__.items():
        if key[:2] == 'mv':
            setattr(constants, key, value)


cdef mvColor MV_BASE_COL_bgColor = mvColor(37, 37, 38, 255)
cdef mvColor MV_BASE_COL_lightBgColor = mvColor(82, 82, 85, 255)
cdef mvColor MV_BASE_COL_veryLightBgColor = mvColor(90, 90, 95, 255)
cdef mvColor MV_BASE_COL_panelColor = mvColor(51, 51, 55, 255)
cdef mvColor MV_BASE_COL_panelHoverColor = mvColor(29, 151, 236, 103)
cdef mvColor MV_BASE_COL_panelActiveColor = mvColor(0, 119, 200, 153)
cdef mvColor MV_BASE_COL_textColor = mvColor(255, 255, 255, 255)
cdef mvColor MV_BASE_COL_textDisabledColor = mvColor(151, 151, 151, 255)
cdef mvColor MV_BASE_COL_borderColor = mvColor(78, 78, 78, 255)
cdef mvColor mvImGuiCol_Text = MV_BASE_COL_textColor
cdef mvColor mvImGuiCol_TextSelectedBg = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_WindowBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_ChildBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_PopupBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_Border = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_BorderShadow = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_FrameBg = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_FrameBgHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_FrameBgActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_TitleBg = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_TitleBgActive = mvColor(15, 86, 135, 255)
cdef mvColor mvImGuiCol_TitleBgCollapsed = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_MenuBarBg = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_ScrollbarBg = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_ScrollbarGrab = MV_BASE_COL_lightBgColor
cdef mvColor mvImGuiCol_ScrollbarGrabHovered = MV_BASE_COL_veryLightBgColor
cdef mvColor mvImGuiCol_ScrollbarGrabActive = MV_BASE_COL_veryLightBgColor
cdef mvColor mvImGuiCol_CheckMark = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_SliderGrab = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_SliderGrabActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_Button = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_ButtonHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_ButtonActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_Header = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_HeaderHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_HeaderActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_Separator = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_SeparatorHovered = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_SeparatorActive = MV_BASE_COL_borderColor
cdef mvColor mvImGuiCol_ResizeGrip = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_ResizeGripHovered = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_Tab = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_TabHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_TabActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_TabUnfocused = MV_BASE_COL_panelColor
cdef mvColor mvImGuiCol_TabUnfocusedActive = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_DockingPreview = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_DockingEmptyBg = mvColor(51, 51, 51, 255)
cdef mvColor mvImGuiCol_PlotLines = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_PlotLinesHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_PlotHistogram = MV_BASE_COL_panelActiveColor
cdef mvColor mvImGuiCol_PlotHistogramHovered = MV_BASE_COL_panelHoverColor
cdef mvColor mvImGuiCol_DragDropTarget = mvColor(255, 255, 0, 179)
cdef mvColor mvImGuiCol_NavHighlight = MV_BASE_COL_bgColor
cdef mvColor mvImGuiCol_NavWindowingHighlight = mvColor(255, 255, 255, 179)
cdef mvColor mvImGuiCol_NavWindowingDimBg = mvColor(204, 204, 204, 51)
cdef mvColor mvImGuiCol_ModalWindowDimBg = mvColor(37, 37, 38, 150)
cdef mvColor mvImGuiCol_TableHeaderBg = mvColor(48, 48, 51, 255)
cdef mvColor mvImGuiCol_TableBorderStrong = mvColor(79, 79, 89, 255)
cdef mvColor mvImGuiCol_TableBorderLight = mvColor(59, 59, 64, 255)
cdef mvColor mvImGuiCol_TableRowBg = mvColor(0, 0, 0, 0)
cdef mvColor mvImGuiCol_TableRowBgAlt = mvColor(255, 255, 255, 15)

cdef unsigned int ConvertToUnsignedInt(const mvColor color):
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(color.r, color.g, color.b, color.a))

cdef void internal_resize_callback(void *fun, int a, int b) noexcept nogil:
    with gil:
        try:
            (<dcgViewport>object).__on_resize(a, b)
        except Exception as e:
            print("An error occured in the viewport resize callback", traceback.format_exc())

cdef void internal_close_callback(void *object) noexcept nogil:
    with gil:
        try:
            (<dcgViewport>object).__on_close()
        except Exception as e:
            print("An error occured in the viewport close callback", traceback.format_exc())

@cython.final
cdef class dcgViewport:
    cdef mvViewport *viewport
    cdef dcgContext context
    cdef public object resize_callback
    cdef public object close_callback
    cdef bint initialized
    cdef mvGraphics graphics
    cdef bint graphics_initialized

    def __init__(self, context):
        self.context = context
        self.resize_callback = None
        self.initialized = False

    def __cinit__(self):
        self.viewport = NULL
        self.graphics_initialized = False

    def __dealloc__(self):
        if self.graphics_initialized:
            cleanup_graphics(self.graphics)
        if self.viewport != NULL:
            mvCleanupViewport(dereference(self.viewport))
            #free(self.viewport) deleted by mvCleanupViewport
            self.viewport = NULL

    cdef initialize(self, unsigned width, unsigned height):
        self.viewport = mvCreateViewport(width, height)
        self.initialized = True

    cdef void __check_initialized(self):
        if not(self.initialized):
            raise RuntimeError("The viewport must be initialized before being used")

    @property
    def clear_color(self):
        self.__check_initialized()
        return (self.viewport.clearColor.r,
                self.viewport.clearColor.g,
                self.viewport.clearColor.b,
                self.viewport.clearColor.a)

    @clear_color.setter
    def clear_color(self, tuple value):
        cdef int r, g, b, a
        self.__check_initialized()
        (r, g, b, a) = value
        self.viewport.clearColor = colorFromInts(r, g, b, a)

    @property
    def small_icon(self):
        self.__check_initialized()
        return str(self.viewport.small_icon)

    @small_icon.setter
    def small_icon(self, str value):
        self.__check_initialized()
        self.viewport.small_icon = value.encode("utf-8")

    @property
    def large_icon(self):
        self.__check_initialized()
        return str(self.viewport.large_icon)

    @large_icon.setter
    def large_icon(self, str value):
        self.__check_initialized()
        self.viewport.large_icon = value.encode("utf-8")

    @property
    def x_pos(self):
        self.__check_initialized()
        return self.viewport.xpos

    @x_pos.setter
    def x_pos(self, int value):
        self.__check_initialized()
        self.viewport.xpos = value
        self.viewport.posDirty = 1

    @property
    def y_pos(self):
        self.__check_initialized()
        return self.viewport.ypos

    @y_pos.setter
    def y_pos(self, int value):
        self.__check_initialized()
        self.viewport.ypos = value
        self.viewport.posDirty = 1

    @property
    def width(self):
        self.__check_initialized()
        return self.viewport.actualWidth

    @width.setter
    def width(self, int value):
        self.__check_initialized()
        self.viewport.actualWidth = value
        self.viewport.sizeDirty = 1

    @property
    def height(self):
        self.__check_initialized()
        return self.viewport.actualHeight

    @height.setter
    def height(self, int value):
        self.__check_initialized()
        self.viewport.actualHeight = value
        self.viewport.sizeDirty = 1

    @property
    def resizable(self) -> bint:
        self.__check_initialized()
        return self.viewport.resizable

    @resizable.setter
    def resizable(self, bint value):
        self.__check_initialized()
        self.viewport.resizable = value
        self.viewport.modesDirty = 1

    @property
    def vsync(self) -> bint:
        self.__check_initialized()
        return self.viewport.vsync

    @vsync.setter
    def vsync(self, bint value):
        self.__check_initialized()
        self.viewport.vsync = value

    @property
    def min_width(self):
        self.__check_initialized()
        return self.viewport.minwidth

    @min_width.setter
    def min_width(self, unsigned value):
        self.__check_initialized()
        self.viewport.minwidth = value

    @property
    def max_width(self):
        self.__check_initialized()
        return self.viewport.maxwidth

    @max_width.setter
    def max_width(self, unsigned value):
        self.__check_initialized()
        self.viewport.maxwidth = value

    @property
    def min_height(self):
        self.__check_initialized()
        return self.viewport.minheight

    @min_height.setter
    def min_height(self, unsigned value):
        self.__check_initialized()
        self.viewport.minheight = value

    @property
    def max_height(self):
        self.__check_initialized()
        return self.viewport.maxheight

    @max_height.setter
    def max_height(self, unsigned value):
        self.__check_initialized()
        self.viewport.maxheight = value

    @property
    def always_on_top(self) -> bint:
        self.__check_initialized()
        return self.viewport.alwaysOnTop

    @always_on_top.setter
    def always_on_top(self, bint value):
        self.__check_initialized()
        self.viewport.alwaysOnTop = value
        self.viewport.modesDirty = 1

    @property
    def decorated(self) -> bint:
        self.__check_initialized()
        return self.viewport.decorated

    @decorated.setter
    def decorated(self, bint value):
        self.__check_initialized()
        self.viewport.decorated = value
        self.viewport.modesDirty = 1

    @property
    def title(self):
        self.__check_initialized()
        return str(self.viewport.title)

    @title.setter
    def title(self, str value):
        self.__check_initialized()
        self.viewport.title = value.encode("utf-8")
        self.viewport.titleDirty = 1

    @property
    def disable_close(self) -> bint:
        self.__check_initialized()
        return self.viewport.disableClose

    @disable_close.setter
    def disable_close(self, bint value):
        self.__check_initialized()
        self.viewport.disableClose = value
        self.viewport.modesDirty = 1

    @property
    def fullscreen(self):
        return self.viewport.fullScreen

    @fullscreen.setter
    def fullscreen(self, bint value):
        if value and not(self.viewport.fullScreen):
            mvToggleFullScreen(dereference(self.viewport))
        elif not(value) and (self.viewport.fullScreen):
            print("TODO: fullscreen(false)")

    @property
    def shown(self) -> bint:
        self.__check_initialized()
        return self.viewport.shown

    def configure(self, **kwargs):
        for (key, value) in kwargs.items():
            setattr(self, key, value)

    cdef void __on_resize(self, int width, int height):
        self.__check_initialized()
        self.viewport.actualHeight = height
        self.viewport.clientHeight = height
        self.viewport.actualWidth = width
        self.viewport.clientWidth = width
        self.viewport.resized = True
        if self.resize_callback is None:
            return
        dimensions = (self.viewport.actualWidth,
                      self.viewport.actualHeight,
                      self.viewport.clientWidth,
                      self.viewport.clientHeight)
        self.context.queue.submit(self.resize_callback, constants.MV_APP_UUID, dimensions)

    cdef void __on_close(self):
        self.__check_initialized()
        if self.close_callback is None:
            return
        self.context.queue.submit(self.close_callback, constants.MV_APP_UUID, None)

    def show(self, minimized=False, maximized=False):
        cdef imgui.ImGuiStyle* style
        cdef mvColor* colors
        self.__check_initialized()
        mvShowViewport(dereference(self.viewport),
                       minimized,
                       maximized,
                       internal_resize_callback,
                       <void*>self,
                       internal_close_callback,
                       <void*>self)
        if not(self.graphics_initialized):
            self.graphics = setup_graphics(dereference(self.viewport))
            imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = True
            # TODO if (GContext->IO.autoSaveIniFile). if (!GContext->IO.iniFile.empty())
			# io.IniFilename = GContext->IO.iniFile.c_str();

            # TODO if(GContext->IO.kbdNavigation)
		    # io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;  // Enable Keyboard Controls
            #if(GContext->IO.docking)
            # io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
            # io.ConfigDockingWithShift = GContext->IO.dockingShiftOnly;

            # Setup Dear ImGui style
            imgui.StyleColorsDark()
            style = &imgui.GetStyle()
            colors = <mvColor*>style.Colors

            colors[<int>imgui.ImGuiCol_Text] = MV_BASE_COL_textColor
            colors[<int>imgui.ImGuiCol_TextDisabled] = MV_BASE_COL_textDisabledColor
            colors[<int>imgui.ImGuiCol_WindowBg] = mvImGuiCol_WindowBg
            colors[<int>imgui.ImGuiCol_ChildBg] = mvImGuiCol_ChildBg
            colors[<int>imgui.ImGuiCol_PopupBg] = mvImGuiCol_PopupBg
            colors[<int>imgui.ImGuiCol_Border] = mvImGuiCol_Border
            colors[<int>imgui.ImGuiCol_BorderShadow] = mvImGuiCol_BorderShadow
            colors[<int>imgui.ImGuiCol_FrameBg] = mvImGuiCol_FrameBg
            colors[<int>imgui.ImGuiCol_FrameBgHovered] = mvImGuiCol_FrameBgHovered
            colors[<int>imgui.ImGuiCol_FrameBgActive] = mvImGuiCol_FrameBgActive
            colors[<int>imgui.ImGuiCol_TitleBg] = mvImGuiCol_TitleBg
            colors[<int>imgui.ImGuiCol_TitleBgActive] = mvImGuiCol_TitleBgActive
            colors[<int>imgui.ImGuiCol_TitleBgCollapsed] = mvImGuiCol_TitleBgCollapsed
            colors[<int>imgui.ImGuiCol_MenuBarBg] = mvImGuiCol_MenuBarBg
            colors[<int>imgui.ImGuiCol_ScrollbarBg] = mvImGuiCol_ScrollbarBg
            colors[<int>imgui.ImGuiCol_ScrollbarGrab] = mvImGuiCol_ScrollbarGrab
            colors[<int>imgui.ImGuiCol_ScrollbarGrabHovered] = mvImGuiCol_ScrollbarGrabHovered
            colors[<int>imgui.ImGuiCol_ScrollbarGrabActive] = mvImGuiCol_ScrollbarGrabActive
            colors[<int>imgui.ImGuiCol_CheckMark] = mvImGuiCol_CheckMark
            colors[<int>imgui.ImGuiCol_SliderGrab] = mvImGuiCol_SliderGrab
            colors[<int>imgui.ImGuiCol_SliderGrabActive] = mvImGuiCol_SliderGrabActive
            colors[<int>imgui.ImGuiCol_Button] = mvImGuiCol_Button
            colors[<int>imgui.ImGuiCol_ButtonHovered] = mvImGuiCol_ButtonHovered
            colors[<int>imgui.ImGuiCol_ButtonActive] = mvImGuiCol_ButtonActive
            colors[<int>imgui.ImGuiCol_Header] = mvImGuiCol_Header
            colors[<int>imgui.ImGuiCol_HeaderHovered] = mvImGuiCol_HeaderHovered
            colors[<int>imgui.ImGuiCol_HeaderActive] = mvImGuiCol_HeaderActive
            colors[<int>imgui.ImGuiCol_Separator] = mvImGuiCol_Separator
            colors[<int>imgui.ImGuiCol_SeparatorHovered] = mvImGuiCol_SeparatorHovered
            colors[<int>imgui.ImGuiCol_SeparatorActive] = mvImGuiCol_SeparatorActive
            colors[<int>imgui.ImGuiCol_ResizeGrip] = mvImGuiCol_ResizeGrip
            colors[<int>imgui.ImGuiCol_ResizeGripHovered] = mvImGuiCol_ResizeGripHovered
            colors[<int>imgui.ImGuiCol_ResizeGripActive] = mvImGuiCol_ResizeGripHovered
            colors[<int>imgui.ImGuiCol_Tab] = mvImGuiCol_Tab
            colors[<int>imgui.ImGuiCol_TabHovered] = mvImGuiCol_TabHovered
            colors[<int>imgui.ImGuiCol_TabActive] = mvImGuiCol_TabActive
            colors[<int>imgui.ImGuiCol_TabUnfocused] = mvImGuiCol_TabUnfocused
            colors[<int>imgui.ImGuiCol_TabUnfocusedActive] = mvImGuiCol_TabUnfocusedActive
            colors[<int>imgui.ImGuiCol_DockingPreview] = mvImGuiCol_DockingPreview
            colors[<int>imgui.ImGuiCol_DockingEmptyBg] = mvImGuiCol_DockingEmptyBg
            colors[<int>imgui.ImGuiCol_PlotLines] = mvImGuiCol_PlotLines
            colors[<int>imgui.ImGuiCol_PlotLinesHovered] = mvImGuiCol_PlotLinesHovered
            colors[<int>imgui.ImGuiCol_PlotHistogram] = mvImGuiCol_PlotHistogram
            colors[<int>imgui.ImGuiCol_PlotHistogramHovered] = mvImGuiCol_PlotHistogramHovered
            colors[<int>imgui.ImGuiCol_TableHeaderBg] = mvImGuiCol_TableHeaderBg
            colors[<int>imgui.ImGuiCol_TableBorderStrong] = mvImGuiCol_TableBorderStrong   # Prefer using Alpha=1.0 here
            colors[<int>imgui.ImGuiCol_TableBorderLight] = mvImGuiCol_TableBorderLight   # Prefer using Alpha=1.0 here
            colors[<int>imgui.ImGuiCol_TableRowBg] = mvImGuiCol_TableRowBg
            colors[<int>imgui.ImGuiCol_TableRowBgAlt] = mvImGuiCol_TableRowBgAlt
            colors[<int>imgui.ImGuiCol_TextSelectedBg] = mvImGuiCol_TextSelectedBg
            colors[<int>imgui.ImGuiCol_DragDropTarget] = mvImGuiCol_DragDropTarget
            colors[<int>imgui.ImGuiCol_NavHighlight] = mvImGuiCol_NavHighlight
            colors[<int>imgui.ImGuiCol_NavWindowingHighlight] = mvImGuiCol_NavWindowingHighlight
            colors[<int>imgui.ImGuiCol_NavWindowingDimBg] = mvImGuiCol_NavWindowingDimBg
            colors[<int>imgui.ImGuiCol_ModalWindowDimBg] = mvImGuiCol_ModalWindowDimBg

            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeBackground] = ConvertToUnsignedInt(mvColor(62, 62, 62, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeBackgroundHovered] = ConvertToUnsignedInt(mvColor(75, 75, 75, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeBackgroundSelected] = ConvertToUnsignedInt(mvColor(75, 75, 75, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_NodeOutline] = ConvertToUnsignedInt(mvColor(100, 100, 100, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_TitleBar] = ConvertToUnsignedInt(mvImGuiCol_TitleBg)
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_TitleBarHovered] = ConvertToUnsignedInt(mvImGuiCol_TitleBgActive)
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_TitleBarSelected] = ConvertToUnsignedInt(mvImGuiCol_FrameBgActive)
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_Link] = ConvertToUnsignedInt(mvColor(255, 255, 255, 200))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_LinkHovered] = ConvertToUnsignedInt(mvColor(66, 150, 250, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_LinkSelected] = ConvertToUnsignedInt(mvColor(66, 150, 250, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_Pin] = ConvertToUnsignedInt(mvColor(199, 199, 41, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_PinHovered] = ConvertToUnsignedInt(mvColor(255, 255, 50, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_BoxSelector] = ConvertToUnsignedInt(mvColor(61, 133, 224, 30))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_BoxSelectorOutline] = ConvertToUnsignedInt(mvColor(61, 133, 224, 150))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_GridBackground] = ConvertToUnsignedInt(mvColor(35, 35, 35, 255))
            imnodes.GetStyle().Colors[<int>imnodes.ImNodesCol_GridLine] = ConvertToUnsignedInt(mvColor(0, 0, 0, 255))

            self.graphics_initialized = True
        self.viewport.shown = 1


cdef class dcgContext:
    cdef bint waitOneFrame
    cdef bool started
    cdef public object mutex
    cdef float deltaTime # time since last frame
    cdef double time # total time since starting
    cdef int frame # frame count
    cdef int framerate # frame rate
    cdef public dcgViewport viewport
    #cdef dcgGraphics graphics
    cdef bool resetTheme
    #cdef dcgIO IO
    #cdef dcgItemRegistry itemRegistry
    #cdef dcgCallbackRegistry callbackRegistry
    #cdef dcgToolManager toolManager
    #cdef dcgInput input
    cdef UUID activeWindow
    cdef UUID focusedItem
    cdef public object on_close_callback
    cdef public object on_frame_callbacks
    cdef object queue
    def __init__(self):
        self.mutex = threading.RLock()
        self.on_close_callback = None
        self.on_frame_callbacks = None
        self.queue = ThreadPoolExecutor(max_workers=1)

    def __cinit__(self):
        self.waitOneFrame = False
        self.started = False
        self.deltaTime = 0.
        self.time = 0.
        self.frame = 0
        self.framerate = 0
        self.viewport = dcgViewport(self)
        self.resetTheme = False
        imgui.IMGUI_CHECKVERSION()
        imgui.CreateContext()
        implot.CreateContext()
        imnodes.CreateContext()
        #mvToolManager::GetFontManager()._dirty = true;

    def __dealloc__(self):
        self.started = True

    def __del__(self):
        if self.on_close_callback is not None:
            self.started = True
            self.queue.submit(self.on_close_callback)
            self.started = False

        imnodes.DestroyContext()
        implot.DestroyContext()
        imgui.DestroyContext()

        #mvToolManager::Reset()
        #ClearItemRegistry(*GContext->itemRegistry)

        self.queue.shutdown(wait=True)

    def initialize_viewport(self, **kwargs):
        self.viewport.initialize(width=kwargs["width"],
                                 height=kwargs["height"])
        self.viewport.configure(**kwargs)

    def start(self):
        if self.started:
            raise ValueError("Cannot call \"setup_dearpygui\" while a Dear PyGUI app is already running.")
        self.started = True
