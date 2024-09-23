
##########################################################
# Compatibility file for DearPyGui
#
#   Resources:
#     * FAQ:         https://github.com/hoffstadt/DearPyGui/discussions/categories/frequently-asked-questions-faq 
#     * Homepage:    https://github.com/hoffstadt/DearPyGui 
#     * Wiki:        https://github.com/hoffstadt/DearPyGui/wiki 
#     * Issues:      https://github.com/hoffstadt/DearPyGui/issues
#     * Discussions: https://github.com/hoffstadt/DearPyGui/discussions
##########################################################

import warnings
import functools
import inspect
from contextlib import contextmanager

import dearcygui as dcg

from dearcygui import constants

from typing import List, Any, Callable, Union, Tuple

dcg_context = None

# reserved fields:
constants.mvReservedUUID_0 = 10
constants.mvReservedUUID_1 = 11
constants.mvReservedUUID_2 = 12
constants.mvReservedUUID_3 = 13
constants.mvReservedUUID_4 = 14
constants.mvReservedUUID_5 = 15
constants.mvReservedUUID_6 = 16
constants.mvReservedUUID_7 = 17
constants.mvReservedUUID_8 = 18
constants.mvReservedUUID_9 = 19
constants.mvReservedUUID_10 = 20


########################################################################################################################
# User API Index
#
#    * Sections
#      - Helper Commands
#      - Tool Commands
#      - Information Commands
#      - Configuration Getter Commands
#      - Configuration Setter Commands
#      - State Commands
#      - Viewport Setter Commands
#      - Viewport Getter Commands
#      - Deprecated Commands
#      - Container Context Managers
#      - Public _dearpygui Wrappings
#      - Constants
#
########################################################################################################################

########################################################################################################################
# Helper Commands
########################################################################################################################

def run_callbacks(jobs):
    """ New in 1.2. Runs callbacks from the callback queue and checks arguments. """

    if jobs is None:
        pass
    else:
        for job in jobs:
            if job[0] is None:
                pass
            else:
                sig = inspect.signature(job[0])
                args = []
                for arg in range(len(sig.parameters)):
                    args.append(job[arg+1])
                job[0](*args)

def get_major_version():
    """ return Dear PyGui Major Version """
    return internal_dpg.get_app_configuration()["major_version"]

def get_minor_version():
    """ return Dear PyGui Minor Version """
    return internal_dpg.get_app_configuration()["minor_version"]

def get_dearpygui_version():
    """ return Dear PyGui Version """
    return internal_dpg.get_app_configuration()["version"]

def configure_item(item : Union[int, str], **kwargs) -> None:
    """Configures an item after creation."""
    item.configure(**kwargs)

def configure_app(**kwargs) -> None:
    """Configures an item after creation."""
    internal_dpg.configure_app(**kwargs)

def configure_viewport(item : Union[int, str], **kwargs) -> None:
    """Configures a viewport after creation."""
    dcg_context.viewport.configure(**kwargs)

def start_dearpygui():
    """Prepares viewport (if not done already). sets up, cleans up, and runs main event loop.

    Returns:
        None
    """

    if not is_viewport_ok():
        raise RuntimeError("Viewport was not created and shown.")
        return

    while(is_dearpygui_running()):
        render_dearpygui_frame()   


@contextmanager
def mutex():
    """ Handles locking/unlocking render thread mutex. """
    try:
        yield dcg_context.viewport.lock_mutex(wait=True)
    finally:
        dcg_context.unlock_mutex()


def popup(parent: Union[int, str], mousebutton: int = constants.mvMouseButton_Right, modal: bool=False, tag:Union[int, str]=0, min_size:Union[List[int], Tuple[int, ...]]=[100,100], max_size: Union[List[int], Tuple[int, ...]] =[30000, 30000], no_move: bool=False, no_background: bool=False) -> int:
    """A window that will be displayed when a parent item is hovered and the corresponding mouse button has been clicked. By default a popup will shrink fit the items it contains.
    This is useful for context windows, and simple modal window popups.
    When popups are used a modal they have more avaliable settings (i.e. title, resize, width, height) These
    can be set by using configure item. 
    This is a light wrapper over window. For more control over a modal|popup window use a normal window with the modal|popup keyword 
    and set the item handler and mouse events manually.

    Args:
        parent: The UI item that will need to be hovered.
        **mousebutton: The mouse button that will trigger the window to popup.
        **modal: Will force the user to interact with the popup.
        **min_size: New in 1.4. Minimum window size.
        **max_size: New in 1.4. Maximum window size.
        **no_move: New in 1.4. Prevents the window from moving based on user input.
        **no_background: New in 1.4. Sets Background and border alpha to transparent.

    Returns:
        item's uuid
    """
    if modal:
        item = window(modal=True, show=False, autosize=True, min_size=min_size, max_size=max_size, no_move=no_move, no_background=no_background)
    else:
        item = window(popup=True, show=False, autosize=True, min_size=min_size, max_size=max_size, no_move=no_move, no_background=no_background)
    def callback(item=item):
        item.show = True
    handler = item_clicked_handler(mousebutton, callback=callback)
    parent.bind_handler(handler)
    return item


########################################################################################################################
# Tool Commands
########################################################################################################################

def show_style_editor() -> None:
    """Shows the standard style editor window

    Returns:
        None
    """
    internal_dpg.show_tool(constants.mvTool_Style)


def show_metrics() -> None:
    """Shows the standard metrics window

    Returns:
        None
    """
    internal_dpg.show_tool(constants.mvTool_Metrics)


def show_about() -> None:
    """Shows the standard about window

    Returns:
        None
    """
    internal_dpg.show_tool(constants.mvTool_About)


def show_debug() -> None:
    """Shows the standard debug window

    Returns:
        None
    """
    internal_dpg.show_tool(constants.mvTool_Debug)


def show_documentation() -> None:
    """Shows the standard documentation window

    Returns:
        None
    """
    internal_dpg.show_tool(constants.mvTool_Doc)


def show_font_manager() -> None:
    """Shows a debug tool for the font manager

    Returns:
        None
    """
    internal_dpg.show_tool(constants.mvTool_Font)


def show_item_registry() -> None:
    """Shows the item hierarchy of your application

    Returns:
        None
    """
    internal_dpg.show_tool(constants.mvTool_ItemRegistry)


########################################################################################################################
# Information Commands
########################################################################################################################

def get_item_slot(item: Union[int, str]) -> Union[int, None]:
    """Returns an item's target slot.

    Returns:
        slot as a int
    """
    item = dcg_context[item]
    if isinstance(item, dcg.uiItem):
        return 1
    elif isinstance(item, dcg.drawingItem):
        return 2
    else:
        return 0 # ????


def is_item_container(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is a container.

    Returns:
        status as a bool
    """
    return internal_dpg.get_item_info(item)["container"]


def get_item_parent(item: Union[int, str]) -> Union[int, None]:
    """Gets the item's parent.

    Returns:
        parent as a int or None
    """
    return dcg_context[item].parent


def filter_slot(items, slot):
    return [item for item in items if get_item_slot(item) == slot]

def get_item_children(item: Union[int, str] , slot: int = -1) -> Union[dict, List[int], None]:
    """Provides access to the item's children slots.

    Returns:
        A 2-D tuple of children slots ex. ((child_slot_1),(child_slot_2),(child_slot_3),...) or a single slot if slot is used.
    """
    children = item.children
    if slot < 0 or slot > 4:
        return (filter_slot(children, 0),
                filter_slot(children, 1),
                filter_slot(children, 2),
                filter_slot(children, 3))
    return filter_slot(children, slot)


def get_item_type(item: Union[int, str]) -> Union[str]:
    """Gets the item's type.

    Returns:
        type as a string or None
    """
    return type(dcg_context[item])


def get_item_theme(item: Union[int, str]) -> int:
    """Gets the item's theme.

    Returns:
        theme's uuid
    """
    return dcg_context[item].theme


def get_item_font(item: Union[int, str]) -> int:
    """Gets the item's font.

    Returns:
        font's uuid
    """
    return dcg_context[item].font


def get_item_disabled_theme(item: Union[int, str]) -> int:
    """Gets the item's disabled theme.

    Returns:
        theme's uuid
    """
    return internal_dpg.get_item_info(item)["disabled_theme"]


########################################################################################################################
# Configuration Setter Commands
########################################################################################################################

def enable_item(item: Union[int, str]):
    """Enables the item.

    Args:
        **item: Item to enable.

    Returns:
        None
    """
    try:
        dcg_context[item].enabled = True
    except AttributeError:
        # TODO: once warning
        pass


def disable_item(item: Union[int, str]):
    """Disables the item.

    Args:
        **item: Item to disable.

    Returns:
        None
    """
    try:
        dcg_context[item].enabled = False
    except AttributeError:
        # TODO: once warning
        pass


def set_item_label(item: Union[int, str], label: str):
    """Sets the item's displayed label, anything after the characters "##" in the name will not be shown.

    Args:
        item: Item label will be applied to.
        label: Displayed name to be applied.

    Returns:
        None
    """
    dcg_context[item].label = label


def set_item_source(item: Union[int, str], source: Union[int, str]):
    """Sets the item's value, to the source's value. Widget's value will now be "linked" to source's value.

    Args:
        item: Item to me linked.
        source: Source to link to.

    Returns:
        None
    """
    dcg_context[item].shareable_value = dcg_context[source].shareable_value


def set_item_pos(item: Union[int, str], pos: List[float]):
    """Sets the item's position.

    Args:
        item: Item the absolute position will be applied to.
        pos: X and Y positions relative to parent of the item.

    Returns:
        None
    """
    dcg_context[item].pos = pos


def set_item_width(item: Union[int, str], width: int):
    """Sets the item's width.

    Args:
        item: Item the Width will be applied to.
        width: Width to be applied.

    Returns:
        None
    """
    dcg_context[item].width = width


def set_item_height(item: Union[int, str], height: int):
    """Sets the item's height.

    Args:
        item: Item the Height will be applied to.
        height: Height to be applied.

    Returns:
        None
    """
    dcg_context[item].height = height


def set_item_indent(item: Union[int, str], indent: int):
    """Sets the item's indent.

    Args:
        item: Item the Height will be applied to.
        height: Height to be applied.

    Returns:
        None
    """
    dcg_context[item].indent = indent


def set_item_track_offset(item: Union[int, str], offset: float):
    """Sets the item's track offset.

    Args:
        item: Item the Height will be applied to.
        height: Height to be applied.

    Returns:
        None
    """
    internal_dpg.configure_item(item, track_offset=offset)


def set_item_payload_type(item: Union[int, str], payload_type: str):
    """Sets the item's payload type.

    Args:
        item: Item the Height will be applied to.
        height: Height to be applied.

    Returns:
        None
    """
    internal_dpg.configure_item(item, payload_type=str)


def set_item_callback(item: Union[int, str], callback: Callable):
    """Sets the item's callack.

    Args:
        item: Item the callback will be applied to.
        callback: Callback to be applied.

    Returns:
        None
    """
    dcg_context[item].callback = callback


def set_item_drag_callback(item: Union[int, str], callback: Callable):
    """Sets the item's drag callack.

    Args:
        item: Item the callback will be applied to.
        callback: Callback to be applied.

    Returns:
        None
    """
    internal_dpg.configure_item(item, drag_callback=callback)


def set_item_drop_callback(item: Union[int, str], callback: Callable):
    """Sets the item's drop callack.

    Args:
        item: Item the callback will be applied to.
        callback: Callback to be applied.

    Returns:
        None
    """
    internal_dpg.configure_item(item, drop_callback=callback)


def track_item(item: Union[int, str]):
    """Track item in scroll region.

    Args:
        item: Item the callback will be applied to.
        callback: Callback to be applied.

    Returns:
        None
    """
    internal_dpg.configure_item(item, tracked=True)


def untrack_item(item: Union[int, str]):
    """Track item in scroll region.

    Args:
        item: Item the callback will be applied to.
        callback: Callback to be applied.

    Returns:
        None
    """
    internal_dpg.configure_item(item, tracked=False)


def set_item_user_data(item: Union[int, str], user_data: Any):
    """Sets the item's callack_data to any python object.

    Args:
        item: Item the callback will be applied to.
        user_data: Callback_data to be applied.

    Returns:
        None
    """
    dcg_context[item].user_data=user_data


def show_item(item: Union[int, str]):
    """Shows the item.

    Args:
        item: Item to show.

    Returns:
        None
    """
    dcg_context[item].show = True


def hide_item(item: Union[int, str], *, children_only: bool = False):
    """Hides the item.

    Args:
        **item: Item to hide.

    Returns:
        None
    """
    item = dcg_context[item]
    if children_only:
        for child in item.children:
            child.show = False
    else:
        item.show = False


########################################################################################################################
# Configuration Getter Commands
########################################################################################################################

def get_item_label(item: Union[int, str]) -> Union[str, None]:
    """Gets the item's label.

    Returns:
        label as a string or None
    """
    return dcg_context[item].label


def get_item_filter_key(item: Union[int, str]) -> Union[str, None]:
    """Gets the item's filter key.

    Returns:
        filter key as a string or None
    """
    return internal_dpg.get_item_configuration(item)["filter_key"]


def is_item_tracked(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is tracked.

    Returns:
        tracked as a bool or None
    """
    return internal_dpg.get_item_configuration(item)["tracked"]


def get_item_indent(item: Union[int, str]) -> Union[int, None]:
    """Gets the item's indent.

    Returns:
        indent as a int or None
    """
    return dcg_context[item].indent


def get_item_track_offset(item: Union[int, str]) -> Union[float, None]:
    """Gets the item's track offset.

    Returns:
        track offset as a int or None
    """
    return internal_dpg.get_item_configuration(item)["track_offset"]


def get_item_width(item: Union[int, str]) -> Union[int, None]:
    """Gets the item's width.

    Returns:
        width as a int or None
    """
    return dcg_context[item].width


def get_item_height(item: Union[int, str]) -> Union[int, None]:
    """Gets the item's height.

    Returns:
        height as a int or None
    """
    return dcg_context[item].height


def get_item_callback(item: Union[int, str]) -> Union[Callable, None]:
    """Gets the item's callback.

    Returns:
        callback as a callable or None
    """
    # TODO: callback.callback ?
    return dcg_context[item].callback


def get_item_drag_callback(item: Union[int, str]) -> Union[Callable, None]:
    """Gets the item's drag callback.

    Returns:
        callback as a callable or None
    """
    return internal_dpg.get_item_configuration(item)["drag_callback"]


def get_item_drop_callback(item: Union[int, str]) -> Union[Callable, None]:
    """Gets the item's drop callback.

    Returns:
        callback as a callable or None
    """
    return internal_dpg.get_item_configuration(item)["drop_callback"]


def get_item_user_data(item: Union[int, str]) -> Union[Any, None]:
    """Gets the item's callback data.

    Returns:
        callback data as a python object or None
    """
    return dcg_context[item].user_data


def get_item_source(item: Union[int, str]) -> Union[str, None]:
    """Gets the item's source.

    Returns:
        source as a string or None
    """
    return dcg_context[item].shareable_value


########################################################################################################################
# State Commands
########################################################################################################################

def is_item_hovered(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is hovered.

    Returns:
        status as a bool
    """
    return dcg_context[item].hovered


def is_item_active(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is active.

    Returns:
        status as a bool
    """
    return dcg_context[item].active


def is_item_focused(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is focused.

    Returns:
        status as a bool
    """
    return dcg_context[item].focused


def is_item_clicked(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is clicked.

    Returns:
        status as a bool
    """
    return max(dcg_context[item].clicked)


def is_item_left_clicked(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is left clicked.

    Returns:
        status as a bool
    """
    return dcg_context[item].clicked[0]


def is_item_right_clicked(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is right clicked.

    Returns:
        status as a bool
    """
    return dcg_context[item].clicked[1]


def is_item_middle_clicked(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is middle clicked.

    Returns:
        status as a bool
    """
    return dcg_context[item].clicked[2]


def is_item_visible(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is visible.

    Returns:
        status as a bool
    """
    return dcg_context[item].visible


def is_item_edited(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is edited.

    Returns:
        status as a bool
    """
    return dcg_context[item].edited


def is_item_activated(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is activated.

    Returns:
        status as a bool
    """
    return dcg_context[item].activated


def is_item_deactivated(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is deactivated.

    Returns:
        status as a bool
    """
    return dcg_context[item].deactivated


def is_item_deactivated_after_edit(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is deactivated_after_edit.

    Returns:
        status as a bool
    """
    return dcg_context[item].deactivated_after_edited


def is_item_toggled_open(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is toggled_open.

    Returns:
        status as a bool
    """
    return internal_dpg.get_item_state(item)["toggled_open"]


def is_item_ok(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is ok and can be used.

    Returns:
        status as a bool
    """
    return True


def is_item_shown(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is shown.

    Returns:
        status as a bool
    """
    return dcg_context[item].show


def is_item_enabled(item: Union[int, str]) -> Union[bool, None]:
    """Checks if item is enabled.

    Returns:
        status as a bool
    """
    item = dcg_context[item]
    try:
        return item.enabled
    except AttributeError:
        return True


def get_item_pos(item: Union[int, str]) -> List[int]:
    """Returns item's position.

    Returns:
        position
    """
    return dcg_context[item].pos


def get_available_content_region(item: Union[int, str]) -> List[int]:
    """Returns item's available content region.

    Returns:
        position
    """
    return dcg_context[item].content_region_avail


def get_item_rect_size(item: Union[int, str]) -> List[int]:
    """Returns item's available content region.

    Returns:
        position
    """
    return dcg_context[item].rect_size


def get_item_rect_min(item: Union[int, str]) -> List[int]:
    """Returns item's minimum content region.

    Returns:
        position
    """
    return dcg_context[item].rect_min


def get_item_rect_max(item: Union[int, str]) -> List[int]:
    """Returns item's maximum content region.

    Returns:
        position
    """
    return dcg_context[item].rect_max


########################################################################################################################
# Viewport Setter Commands
########################################################################################################################

def set_viewport_clear_color(color: List[int]):
    """Sets the viewport's clear color.

    Returns:
        None
    """
    dcg_context.viewport.clear_color = color

def set_viewport_small_icon(icon: str):
    """Sets the viewport's small icon. Must be ico for windows.

    Returns:
        None
    """
    dcg_context.viewport.small_icon=icon


def set_viewport_large_icon(icon: str):
    """Sets the viewport's large icon. Must be ico for windows.

    Returns:
        None
    """
    dcg_context.viewport.large_icon=icon


def set_viewport_pos(pos: List[float]):
    """Sets the viewport's position.

    Returns:
        None
    """
    dcg_context.viewport.x_pos=pos[0]
    dcg_context.viewport.y_pos=pos[1]


def set_viewport_width(width: int):
    """Sets the viewport's width.

    Returns:
        None
    """
    dcg_context.viewport.width=width


def set_viewport_height(height: int):
    """Sets the viewport's height.

    Returns:
        None
    """
    dcg_context.viewport.height=height


def set_viewport_min_width(width: int):
    """Sets the viewport's minimum width.

    Returns:
        None
    """
    dcg_context.viewport.min_width=width


def set_viewport_max_width(width: int):
    """Sets the viewport's max width.

    Returns:
        None
    """
    dcg_context.viewport.max_width=width


def set_viewport_min_height(height: int):
    """Sets the viewport's minimum height.

    Returns:
        None
    """
    dcg_context.viewport.min_height=height


def set_viewport_max_height(height: int):
    """Sets the viewport's max width.

    Returns:
        None
    """
    dcg_context.viewport.max_height=height


def set_viewport_title(title: str):
    """Sets the viewport's title.

    Returns:
        None
    """
    dcg_context.viewport.title=title


def set_viewport_always_top(value: bool):
    """Sets the viewport always on top.

    Returns:
        None
    """
    dcg_context.viewport.always_on_top=value


def set_viewport_resizable(value: bool):
    """Sets the viewport resizable.

    Returns:
        None
    """
    dcg_context.viewport.resizable=value

def set_viewport_vsync(value: bool):
    """Sets the viewport vsync.

    Returns:
        None
    """
    dcg_context.viewport.vsync=value


def set_viewport_decorated(value: bool):
    """Sets the viewport to be decorated.

    Returns:
        None
    """
    dcg_context.viewport.decorated=value

########################################################################################################################
# Viewport Getter Commands
########################################################################################################################

def get_viewport_clear_color() ->List[int]:
    """Gets the viewport's clear color.

    Returns:
        List[int]
    """
    return dcg_context.viewport.clear_color


def get_viewport_pos() ->List[float]:
    """Gets the viewport's position.

    Returns:
        viewport position.
    """
    x_pos = dcg_context.viewport.x_pos
    y_pos = dcg_context.viewport.y_pos
    return [x_pos, y_pos]


def get_viewport_width() -> int:
    """Gets the viewport's width.

    Returns:
        viewport width
    """
    return dcg_context.viewport.width


def get_viewport_client_width() -> int:
    """Gets the viewport's client width.

    Returns:
        viewport width
    """
    return dcg_context.viewport.client_width


def get_viewport_client_height() -> int:
    """Gets the viewport's client height.

    Returns:
        viewport width
    """
    return dcg_context.viewport.client_height


def get_viewport_height() -> int:
    """Gets the viewport's height.

    Returns:
        int
    """
    return dcg_context.viewport.height


def get_viewport_min_width() -> int:
    """Gets the viewport's minimum width.

    Returns:
        int
    """
    return dcg_context.viewport.min_width


def get_viewport_max_width() -> int:
    """Gets the viewport's max width.

    Returns:
        int
    """
    return dcg_context.viewport.max_width


def get_viewport_min_height() -> int:
    """Gets the viewport's minimum height.

    Returns:
        int
    """
    return dcg_context.viewport.min_height


def get_viewport_max_height() -> int:
    """Gets the viewport's max width.

    Returns:
        int
    """
    return dcg_context.viewport.max_height


def get_viewport_title() -> str:
    """Gets the viewport's title.

    Returns:
        str
    """
    return dcg_context.viewport.title


def is_viewport_always_top() -> bool:
    """Checks the viewport always on top flag.

    Returns:
        bool
    """
    return dcg_context.viewport.always_on_top


def is_viewport_resizable() -> bool:
    """Checks the viewport resizable flag.

    Returns:
        bool
    """
    return dcg_context.viewport.resizable


def is_viewport_vsync_on() -> bool:
    """Checks the viewport vsync flag.

    Returns:
        bool
    """
    return dcg_context.viewport.vsync


def is_viewport_decorated() -> bool:
    """Checks if the viewport is docorated.

    Returns:
        bool
    """
    return dcg_context.viewport.decorated

##########################################################
# Core Wrappings
##########################################################

def add_2d_histogram_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, xbins: int =-1, ybins: int =-1, xmin_range: float =0.0, xmax_range: float =0.0, ymin_range: float =0.0, ymax_range: float =0.0, density: bool =False, outliers: bool =False, col_major: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a 2d histogram series.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        xbins (int, optional): 
        ybins (int, optional): 
        xmin_range (float, optional): set the min x range value, the values under this min will be ignored
        xmax_range (float, optional): set the max x range value, the values over this max will be ignored
        ymin_range (float, optional): set the min y range value, the values under this min will be ignored
        ymax_range (float, optional): set the max y range value, the values over this max will be ignored. If all xmin, xmax, ymin and ymax are 0.0, then the values will be the min and max values of the series
        density (bool, optional): counts will be normalized, i.e. the PDF will be visualized
        outliers (bool, optional): exclude values outside the specified histogram range from the count used for normalizing
        col_major (bool, optional): data will be read in column major order
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return add_2d_histogram_series(x, y, label=label, user_data=user_data, show=show, xbins=xbins, ybins=ybins, xmin_range=xmin_range, xmax_range=xmax_range, ymin_range=ymin_range, ymax_range=ymax_range, density=density, outliers=outliers, col_major=col_major, **kwargs)

def add_3d_slider(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[float], Tuple[float, ...]] =(0.0, 0.0, 0.0, 0.0), max_x: float =100.0, max_y: float =100.0, max_z: float =100.0, min_x: float =0.0, min_y: float =0.0, min_z: float =0.0, scale: float =1.0, **kwargs) -> Union[int, str]:
    """     Adds a 3D box slider.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        max_x (float, optional): Applies upper limit to slider.
        max_y (float, optional): Applies upper limit to slider.
        max_z (float, optional): Applies upper limit to slider.
        min_x (float, optional): Applies lower limit to slider.
        min_y (float, optional): Applies lower limit to slider.
        min_z (float, optional): Applies lower limit to slider.
        scale (float, optional): Size of the widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return add_3d_slider(label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, max_x=max_x, max_y=max_y, max_z=max_z, min_x=min_x, min_y=min_y, min_z=min_z, scale=scale, **kwargs)

def alias(alias : str, item : Union[int, str], **kwargs) -> None:
    """     Adds an alias.

    Args:
        alias (str): 
        item (Union[int, str]): 
    Returns:
        None
    """

    dcg_context[item].tag = alias

def area_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, fill: Union[int, List[int], Tuple[int, ...]] =0, contribute_to_bounds: bool =True, **kwargs) -> Union[int, str]:
    """     Adds an area series to a plot.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        fill (Union[List[int], Tuple[int, ...]], optional): 
        contribute_to_bounds (bool, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return area_series(x, y, label=label, user_data=user_data, show=show, fill=fill, contribute_to_bounds=contribute_to_bounds, **kwargs)

def axis_tag(*, label: str =None, user_data: Any =None, show: bool =True, default_value: float =0.0, color: Union[int, List[int], Tuple[int, ...]] =0, auto_rounding: bool =False, **kwargs) -> Union[int, str]:
    """     Adds custom labels to axes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        default_value (float, optional): 
        color (Union[List[int], Tuple[int, ...]], optional): 
        auto_rounding (bool, optional): When enabled, the value displayed on the tag will be automatically rounded to the precision of other values displayed at axis' ticks. Only makes sense when label is not set, i.e. when the tag displays its location on the axis.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return axis_tag(label=label, user_data=user_data, show=show, value=default_value, color=color, auto_rounding=auto_rounding, **kwargs)

def bar_group_series(values : Union[List[float], Tuple[float, ...]], label_ids : Union[List[str], Tuple[str, ...]], group_size : int, *, label: str =None, user_data: Any =None, show: bool =True, group_width: float =0.67, shift: int =0, horizontal: bool =False, stacked: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a bar groups series to a plot.

    Args:
        values (Any): 
        label_ids (Union[List[str], Tuple[str, ...]]): Label of each bar in a group
        group_size (int): Number of bars in a group
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        group_width (float, optional): Size of bar groups
        shift (int, optional): The position on the x axis where to start plotting bar groups
        horizontal (bool, optional): bar groups will be rendered horizontally on the current y-axis
        stacked (bool, optional): items in a group will be stacked on top of each other
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return bar_group_series(values, label_ids, group_size, label=label, user_data=user_data, show=show, group_width=group_width, shift=shift, horizontal=horizontal, stacked=stacked, **kwargs)

def bar_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, weight: float =1.0, horizontal: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a bar series to a plot.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        weight (float, optional): 
        horizontal (bool, optional): bars will be rendered horizontally on the current y-axis
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return bar_series(x, y, label=label, user_data=user_data, show=show, weight=weight, horizontal=horizontal, **kwargs)

def bool_value(*, label: str =None, user_data: Any =None, default_value: bool =False, parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a bool value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (bool, optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_bool(dcg_context, default_value)

def button(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, small: bool =False, arrow: bool =False, direction: int =0, repeat: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a button.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        small (bool, optional): Shrinks the size of the button to the text of the label it contains. Useful for embedding in text.
        arrow (bool, optional): Displays an arrow in place of the text string. This requires the direction keyword.
        direction (int, optional): Sets the cardinal direction for the arrow by using constants mvDir_Left, mvDir_Up, mvDir_Down, mvDir_Right, mvDir_None. Arrow keyword must be set to True.
        repeat (bool, optional): Hold to continuosly repeat the click.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgButton(dcg_context, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, small=small, arrow=arrow, direction=direction, repeat=repeat, **kwargs)

def candle_series(dates : Union[List[float], Tuple[float, ...]], opens : Union[List[float], Tuple[float, ...]], closes : Union[List[float], Tuple[float, ...]], lows : Union[List[float], Tuple[float, ...]], highs : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, bull_color: Union[int, List[int], Tuple[int, ...]] =(0, 255, 113, 255), bear_color: Union[int, List[int], Tuple[int, ...]] =(218, 13, 79, 255), weight: float =0.25, tooltip: bool =True, time_unit: int =5, **kwargs) -> Union[int, str]:
    """     Adds a candle series to a plot.

    Args:
        dates (Any): 
        opens (Any): 
        closes (Any): 
        lows (Any): 
        highs (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        bull_color (Union[List[int], Tuple[int, ...]], optional): 
        bear_color (Union[List[int], Tuple[int, ...]], optional): 
        weight (float, optional): 
        tooltip (bool, optional): 
        time_unit (int, optional): mvTimeUnit_* constants. Default mvTimeUnit_Day.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return candle_series(dates, opens, closes, lows, highs, label=label, user_data=user_data, show=show, bull_color=bull_color, bear_color=bear_color, weight=weight, tooltip=tooltip, time_unit=time_unit, **kwargs)

def char_remap(source : int, target : int, *, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Remaps a character.

    Args:
        source (int): 
        target (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return char_remap(source, target, label=label, user_data=user_data, **kwargs)

def checkbox(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a checkbox.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (bool, optional): Sets the default value of the checkmark
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgCheckbox(dcg_context, label=label, user_data=user_data, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, **kwargs)

def child_window(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, border: bool =True, autosize_x: bool =False, autosize_y: bool =False, no_scrollbar: bool =False, horizontal_scrollbar: bool =False, menubar: bool =False, no_scroll_with_mouse: bool =False, flattened_navigation: bool =True, always_use_window_padding: bool =False, resizable_x: bool =False, resizable_y: bool =False, always_auto_resize: bool =False, frame_style: bool =False, auto_resize_x: bool =False, auto_resize_y: bool =False, **kwargs) -> Union[int, str]:
    """     Adds an embedded child window. Will show scrollbars when items do not fit. About using auto_resize/resizable flags: size measurement for a given axis is only performed when the child window is within visible boundaries, or is just appearing and it won't update its auto-size while clipped. While not perfect, it is a better default behavior as the always-on performance gain is more valuable than the occasional 'resizing after becoming visible again' glitch. You may also use always_auto_resize to force an update even when child window is not in view. However doing so will degrade performance. Remember that combining both auto_resize_x and auto_resize_y defeats purpose of a scrolling region and is NOT recommended.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        border (bool, optional): Shows/Hides the border around the sides.
        autosize_x (bool, optional): Autosize the window to its parents size in x.
        autosize_y (bool, optional): Autosize the window to its parents size in y.
        no_scrollbar (bool, optional):  Disable scrollbars (window can still scroll with mouse or programmatically).
        horizontal_scrollbar (bool, optional): Allow horizontal scrollbar to appear (off by default).
        menubar (bool, optional): Shows/Hides the menubar at the top.
        no_scroll_with_mouse (bool, optional): Disable user vertically scrolling with mouse wheel.
        flattened_navigation (bool, optional): Allow gamepad/keyboard navigation to cross over parent border to this child (only use on child that have no scrolling!)
        always_use_window_padding (bool, optional): Pad with style.WindowPadding even if no border are drawn (no padding by default for non-bordered child windows because it makes more sense)
        resizable_x (bool, optional): Allow resize from right border (layout direction). Enable .ini saving.
        resizable_y (bool, optional): Allow resize from bottom border (layout direction). 
        always_auto_resize (bool, optional): Combined with auto_resize_x/auto_resize_y. Always measure size even when child is hidden and always disable clipping optimization! NOT RECOMMENDED.
        frame_style (bool, optional): Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.
        auto_resize_x (bool, optional): Enable auto-resizing width based on child content. Read 'IMPORTANT: Size measurement' details above.
        auto_resize_y (bool, optional): Enable auto-resizing height based on child content. Read 'IMPORTANT: Size measurement' details above.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return child_window(label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, border=border, autosize_x=autosize_x, autosize_y=autosize_y, no_scrollbar=no_scrollbar, horizontal_scrollbar=horizontal_scrollbar, menubar=menubar, no_scroll_with_mouse=no_scroll_with_mouse, flattened_navigation=flattened_navigation, always_use_window_padding=always_use_window_padding, resizable_x=resizable_x, resizable_y=resizable_y, always_auto_resize=always_auto_resize, frame_style=frame_style, auto_resize_x=auto_resize_x, auto_resize_y=auto_resize_y, **kwargs)

def clipper(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, show: bool =True, **kwargs) -> Union[int, str]:
    """     Helper to manually clip large list of items. Increases performance by not searching or drawing widgets outside of the clipped region.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return clipper(label=label, user_data=user_data, width=width, indent=indent, show=show, **kwargs)

def collapsing_header(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, closable: bool =False, default_open: bool =False, open_on_double_click: bool =False, open_on_arrow: bool =False, leaf: bool =False, bullet: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a collapsing header to add items to. Must be closed with the end command.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        closable (bool, optional): Adds the ability to hide this widget by pressing the (x) in the top right of widget.
        default_open (bool, optional): Sets the collapseable header open by default.
        open_on_double_click (bool, optional): Need double-click to open node.
        open_on_arrow (bool, optional): Only open when clicking on the arrow part.
        leaf (bool, optional): No collapsing, no arrow (use as a convenience for leaf nodes).
        bullet (bool, optional): Display a bullet instead of arrow.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return collapsing_header(label=label, user_data=user_data, indent=indent, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, closable=closable, default_open=default_open, open_on_double_click=open_on_double_click, open_on_arrow=open_on_arrow, leaf=leaf, bullet=bullet, **kwargs)

def color_button(default_value : Union[List[int], Tuple[int, ...]] =(0, 0, 0, 255), *, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, no_alpha: bool =False, no_border: bool =False, no_drag_drop: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a color button.

    Args:
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        no_alpha (bool, optional): Removes the displayed slider that can change alpha channel.
        no_border (bool, optional): Disable border around the image.
        no_drag_drop (bool, optional): Disable ability to drag and drop small preview (color square) to apply colors to other items.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return color_button(default_value, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, no_alpha=no_alpha, no_border=no_border, no_drag_drop=no_drag_drop, **kwargs)

def color_edit(default_value : Union[List[int], Tuple[int, ...]] =(0, 0, 0, 255), *, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, no_alpha: bool =False, no_picker: bool =False, no_options: bool =False, no_small_preview: bool =False, no_inputs: bool =False, no_tooltip: bool =False, no_label: bool =False, no_drag_drop: bool =False, alpha_bar: bool =False, alpha_preview: int =0, display_mode: int =constants.mvColorEdit_rgb, display_type: int =constants.mvColorEdit_uint8, input_mode: int =constants.mvColorEdit_input_rgb, **kwargs) -> Union[int, str]:
    """     Adds an RGBA color editor. Left clicking the small color preview will provide a color picker. Click and draging the small color preview will copy the color to be applied on any other color widget.

    Args:
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        no_alpha (bool, optional): Removes the displayed slider that can change alpha channel.
        no_picker (bool, optional): Disable picker popup when color square is clicked.
        no_options (bool, optional): Disable toggling options menu when right-clicking on inputs/small preview.
        no_small_preview (bool, optional): Disable colored square preview next to the inputs. (e.g. to show only the inputs). This only displays if the side preview is not shown.
        no_inputs (bool, optional): Disable inputs sliders/text widgets. (e.g. to show only the small preview colored square)
        no_tooltip (bool, optional): Disable tooltip when hovering the preview.
        no_label (bool, optional): Disable display of inline text label.
        no_drag_drop (bool, optional): Disable ability to drag and drop small preview (color square) to apply colors to other items.
        alpha_bar (bool, optional): Show vertical alpha bar/gradient in picker.
        alpha_preview (int, optional): mvColorEdit_AlphaPreviewNone, mvColorEdit_AlphaPreview, or mvColorEdit_AlphaPreviewHalf
        display_mode (int, optional): mvColorEdit_rgb, mvColorEdit_hsv, or mvColorEdit_hex
        display_type (int, optional): mvColorEdit_uint8 or mvColorEdit_float
        input_mode (int, optional): mvColorEdit_input_* values
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return color_edit(default_value, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, no_alpha=no_alpha, no_picker=no_picker, no_options=no_options, no_small_preview=no_small_preview, no_inputs=no_inputs, no_tooltip=no_tooltip, no_label=no_label, no_drag_drop=no_drag_drop, alpha_bar=alpha_bar, alpha_preview=alpha_preview, display_mode=display_mode, display_type=display_type, input_mode=input_mode, **kwargs)

def color_picker(default_value : Union[List[int], Tuple[int, ...]] =(0, 0, 0, 255), *, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, no_alpha: bool =False, no_side_preview: bool =False, no_small_preview: bool =False, no_inputs: bool =False, no_tooltip: bool =False, no_label: bool =False, alpha_bar: bool =False, display_rgb: bool =False, display_hsv: bool =False, display_hex: bool =False, picker_mode: int =constants.mvColorPicker_bar, alpha_preview: int =0, display_type: int =constants.mvColorEdit_uint8, input_mode: int =constants.mvColorEdit_input_rgb, **kwargs) -> Union[int, str]:
    """     Adds an RGB color picker. Right click the color picker for options. Click and drag the color preview to copy the color and drop on any other color widget to apply. Right Click allows the style of the color picker to be changed.

    Args:
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        no_alpha (bool, optional): Removes the displayed slider that can change alpha channel.
        no_side_preview (bool, optional): Disable bigger color preview on right side of the picker, use small colored square preview instead , unless small preview is also hidden.
        no_small_preview (bool, optional): Disable colored square preview next to the inputs. (e.g. to show only the inputs). This only displays if the side preview is not shown.
        no_inputs (bool, optional): Disable inputs sliders/text widgets. (e.g. to show only the small preview colored square)
        no_tooltip (bool, optional): Disable tooltip when hovering the preview.
        no_label (bool, optional): Disable display of inline text label.
        alpha_bar (bool, optional): Show vertical alpha bar/gradient in picker.
        display_rgb (bool, optional): Override _display_ type among RGB/HSV/Hex.
        display_hsv (bool, optional): Override _display_ type among RGB/HSV/Hex.
        display_hex (bool, optional): Override _display_ type among RGB/HSV/Hex.
        picker_mode (int, optional): mvColorPicker_bar or mvColorPicker_wheel
        alpha_preview (int, optional): mvColorEdit_AlphaPreviewNone, mvColorEdit_AlphaPreview, or mvColorEdit_AlphaPreviewHalf
        display_type (int, optional): mvColorEdit_uint8 or mvColorEdit_float
        input_mode (int, optional): mvColorEdit_input_* values.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return color_picker(default_value, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, no_alpha=no_alpha, no_side_preview=no_side_preview, no_small_preview=no_small_preview, no_inputs=no_inputs, no_tooltip=no_tooltip, no_label=no_label, alpha_bar=alpha_bar, display_rgb=display_rgb, display_hsv=display_hsv, display_hex=display_hex, picker_mode=picker_mode, alpha_preview=alpha_preview, display_type=display_type, input_mode=input_mode, **kwargs)

def color_value(*, label: str =None, user_data: Any =None, default_value: Union[List[float], Tuple[float, ...]] =(0.0, 0.0, 0.0, 0.0), parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a color value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_color(dcg_context, default_value)

def colormap(colors : List[Union[List[int], Tuple[int, ...]]], qualitative : bool, *, label: str =None, user_data: Any =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_4, **kwargs) -> Union[int, str]:
    """     Adds a legend that pairs colors with normalized value 0.0->1.0. Each color will be  This is typically used with a heat series. (ex. [[0, 0, 0, 255], [255, 255, 255, 255]] will be mapped to a soft transition from 0.0-1.0)

    Args:
        colors (Any): colors that will be mapped to the normalized value 0.0->1.0
        qualitative (bool): Qualitative will create hard transitions for color boundries across the value range when enabled.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return colormap(colors, qualitative, label=label, user_data=user_data, show=show, **kwargs)

def colormap_button(default_value : Union[List[int], Tuple[int, ...]] =(0, 0, 0, 255), *, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, **kwargs) -> Union[int, str]:
    """     Adds a button that a color map can be bound to.

    Args:
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return colormap_button(default_value, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, **kwargs)

def colormap_registry(*, label: str =None, user_data: Any =None, show: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a colormap registry.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return colormap_registry(label=label, user_data=user_data, show=show, **kwargs)

def colormap_scale(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], colormap: Union[int, str] =0, min_scale: float =0.0, max_scale: float =1.0, format: str ='%g', reverse_dir: bool =False, mirror: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a legend that pairs values with colors. This is typically used with a heat series. 

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        colormap (Union[int, str], optional): mvPlotColormap_* constants or mvColorMap uuid from a color map registry
        min_scale (float, optional): Sets the min number of the color scale. Typically is the same as the min scale from the heat series.
        max_scale (float, optional): Sets the max number of the color scale. Typically is the same as the max scale from the heat series.
        format (str, optional): Formatting used for the labels.
        reverse_dir (bool, optional): invert the colormap bar and axis scale (this only affects rendering; if you only want to reverse the scale mapping, make scale_min > scale_max)
        mirror (bool, optional): render the colormap label and tick labels on the opposite side
        id (Union[int, str], optional): (deprecated) 
        drag_callback (Callable, optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'drag_callback' in kwargs.keys():

        warnings.warn('drag_callback keyword removed', DeprecationWarning, 2)

        kwargs.pop('drag_callback', None)

    #return colormap_scale(label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, drop_callback=drop_callback, show=show, pos=pos, colormap=colormap, min_scale=min_scale, max_scale=max_scale, format=format, reverse_dir=reverse_dir, mirror=mirror, **kwargs)

def colormap_slider(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, **kwargs) -> Union[int, str]:
    """     Adds a color slider that a color map can be bound to.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        id (Union[int, str], optional): (deprecated) 
        drag_callback (Callable, optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'drag_callback' in kwargs.keys():

        warnings.warn('drag_callback keyword removed', DeprecationWarning, 2)

        kwargs.pop('drag_callback', None)

    #return colormap_slider(label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, **kwargs)

def combo(items : Union[List[str], Tuple[str, ...]] =(), *, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: str ='', popup_align_left: bool =False, no_arrow_button: bool =False, no_preview: bool =False, fit_width: bool =False, height_mode: int =1, **kwargs) -> Union[int, str]:
    """     Adds a combo dropdown that allows a user to select a single option from a drop down window. All items will be shown as selectables on the dropdown.

    Args:
        items (Union[List[str], Tuple[str, ...]], optional): A tuple of items to be shown in the drop down window. Can consist of any combination of types but will convert all items to strings to be shown.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (str, optional): Sets a selected item from the drop down by specifying the string value.
        popup_align_left (bool, optional): Align the contents on the popup toward the left.
        no_arrow_button (bool, optional): Display the preview box without the square arrow button indicating dropdown activity.
        no_preview (bool, optional): Display only the square arrow button and not the selected value.
        fit_width (bool, optional): Fit the available width.
        height_mode (int, optional): Controlls the number of items shown in the dropdown by the constants mvComboHeight_Small, mvComboHeight_Regular, mvComboHeight_Large, mvComboHeight_Largest
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgCombo(dcg_context, items=items, label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, popup_align_left=popup_align_left, no_arrow_button=no_arrow_button, no_preview=no_preview, fit_width=fit_width, height_mode=height_mode, **kwargs)

def custom_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], channel_count : int, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, y1: Any =[], y2: Any =[], y3: Any =[], tooltip: bool =True, no_fit: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a custom series to a plot. New in 1.6.

    Args:
        x (Any): 
        y (Any): 
        channel_count (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        y1 (Any, optional): 
        y2 (Any, optional): 
        y3 (Any, optional): 
        tooltip (bool, optional): Show tooltip when plot is hovered.
        no_fit (bool, optional): the item won't be considered for plot fits
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return custom_series(x, y, channel_count, label=label, user_data=user_data, callback=callback, show=show, y1=y1, y2=y2, y3=y3, tooltip=tooltip, no_fit=no_fit, **kwargs)

def date_picker(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: dict ={'month_day': 14, 'year':20, 'month':5}, level: int =0, **kwargs) -> Union[int, str]:
    """     Adds a data picker.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (dict, optional): 
        level (int, optional): Use avaliable constants. mvDatePickerLevel_Day, mvDatePickerLevel_Month, mvDatePickerLevel_Year
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return date_picker(label=label, user_data=user_data, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, level=level, **kwargs)

def digital_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a digital series to a plot. Digital plots do not respond to y drag or zoom, and are always referenced to the bottom of the plot.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return digital_series(x, y, label=label, user_data=user_data, show=show, **kwargs)

def double4_value(*, label: str =None, user_data: Any =None, default_value: Any =(0.0, 0.0, 0.0, 0.0), parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a double value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (Any, optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_double4(dcg_context, default_value)

def double_value(*, label: str =None, user_data: Any =None, default_value: float =0.0, parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a double value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (float, optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_double(dcg_context, default_value)

def drag_double(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, format: str ='%0.3f', speed: float =1.0, min_value: float =0.0, max_value: float =100.0, no_input: bool =False, clamped: bool =False, **kwargs) -> Union[int, str]:
    """     Adds drag for a single double value. Useful when drag float is not accurate enough. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the drag. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        speed (float, optional): Sets the sensitivity the float will be modified while dragging.
        min_value (float, optional): Applies a limit only to draging entry only.
        max_value (float, optional): Applies a limit only to draging entry only.
        no_input (bool, optional): Disable direct entry methods or Enter key allowing to input text directly into the widget.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="double", size=1, drag=True, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, print_format=format, speed=speed, min_value=min_value, max_value=max_value, no_input=no_input, clamped=clamped, **kwargs)

def drag_doublex(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Any =(0.0, 0.0, 0.0, 0.0), size: int =4, format: str ='%0.3f', speed: float =1.0, min_value: float =0.0, max_value: float =100.0, no_input: bool =False, clamped: bool =False, **kwargs) -> Union[int, str]:
    """     Adds drag input for a set of double values up to 4. Useful when drag float is not accurate enough. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the drag. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Any, optional): 
        size (int, optional): Number of doubles to be displayed.
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        speed (float, optional): Sets the sensitivity the float will be modified while dragging.
        min_value (float, optional): Applies a limit only to draging entry only.
        max_value (float, optional): Applies a limit only to draging entry only.
        no_input (bool, optional): Disable direct entry methods or Enter key allowing to input text directly into the widget.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="double", drag=True, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, size=size, print_format=format, speed=speed, min_value=min_value, max_value=max_value, no_input=no_input, clamped=clamped, **kwargs)

def drag_float(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, format: str ='%0.3f', speed: float =1.0, min_value: float =0.0, max_value: float =100.0, no_input: bool =False, clamped: bool =False, **kwargs) -> Union[int, str]:
    """     Adds drag for a single float value. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the drag. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        speed (float, optional): Sets the sensitivity the float will be modified while dragging.
        min_value (float, optional): Applies a limit only to draging entry only.
        max_value (float, optional): Applies a limit only to draging entry only.
        no_input (bool, optional): Disable direct entry methods or Enter key allowing to input text directly into the widget.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="float", drag=True, size=1, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, print_format=format, speed=speed, min_value=min_value, max_value=max_value, no_input=no_input, clamped=clamped, **kwargs)

def drag_floatx(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[float], Tuple[float, ...]] =(0.0, 0.0, 0.0, 0.0), size: int =4, format: str ='%0.3f', speed: float =1.0, min_value: float =0.0, max_value: float =100.0, no_input: bool =False, clamped: bool =False, **kwargs) -> Union[int, str]:
    """     Adds drag input for a set of float values up to 4. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the drag. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        size (int, optional): Number of floats to be displayed.
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        speed (float, optional): Sets the sensitivity the float will be modified while dragging.
        min_value (float, optional): Applies a limit only to draging entry only.
        max_value (float, optional): Applies a limit only to draging entry only.
        no_input (bool, optional): Disable direct entry methods or Enter key allowing to input text directly into the widget.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="float", drag=True, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, size=size, print_format=format, speed=speed, min_value=min_value, max_value=max_value, no_input=no_input, clamped=clamped, **kwargs)

def drag_int(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: int =0, format: str ='%d', speed: float =1.0, min_value: int =0, max_value: int =100, no_input: bool =False, clamped: bool =False, **kwargs) -> Union[int, str]:
    """     Adds drag for a single int value. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the drag. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (int, optional): 
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        speed (float, optional): Sets the sensitivity the float will be modified while dragging.
        min_value (int, optional): Applies a limit only to draging entry only.
        max_value (int, optional): Applies a limit only to draging entry only.
        no_input (bool, optional): Disable direct entry methods or Enter key allowing to input text directly into the widget.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="int", size=1, drag=True, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, print_format=format, speed=speed, min_value=min_value, max_value=max_value, no_input=no_input, clamped=clamped, **kwargs)

def drag_intx(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[int], Tuple[int, ...]] =(0, 0, 0, 0), size: int =4, format: str ='%d', speed: float =1.0, min_value: int =0, max_value: int =100, no_input: bool =False, clamped: bool =False, **kwargs) -> Union[int, str]:
    """     Adds drag input for a set of int values up to 4. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the drag. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        size (int, optional): Number of ints to be displayed.
        format (str, optional): Determines the format the int will be displayed as use python string formatting.
        speed (float, optional): Sets the sensitivity the float will be modified while dragging.
        min_value (int, optional): Applies a limit only to draging entry only.
        max_value (int, optional): Applies a limit only to draging entry only.
        no_input (bool, optional): Disable direct entry methods or Enter key allowing to input text directly into the widget.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="int", drag=True, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, size=size, print_format=format, speed=speed, min_value=min_value, max_value=max_value, no_input=no_input, clamped=clamped, **kwargs)

def drag_line(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, default_value: float =0.0, color: Union[int, List[int], Tuple[int, ...]] =0, thickness: float =1.0, show_label: bool =True, vertical: bool =True, delayed: bool =False, no_cursor: bool =False, no_fit: bool =False, no_inputs: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a drag line to a plot.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        default_value (float, optional): 
        color (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        show_label (bool, optional): 
        vertical (bool, optional): 
        delayed (bool, optional): tool rendering will be delayed one frame; useful when applying position-constraints
        no_cursor (bool, optional): drag tools won't change cursor icons when hovered or held
        no_fit (bool, optional): the drag tool won't be considered for plot fits
        no_inputs (bool, optional): lock the tool from user inputs
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return drag_line(label=label, user_data=user_data, callback=callback, show=show, value=default_value, color=color, thickness=thickness, show_label=show_label, vertical=vertical, delayed=delayed, no_cursor=no_cursor, no_fit=no_fit, no_inputs=no_inputs, **kwargs)

def drag_payload(*, label: str =None, user_data: Any =None, show: bool =True, drag_data: Any =None, drop_data: Any =None, payload_type: str ='$$DPG_PAYLOAD', **kwargs) -> Union[int, str]:
    """     User data payload for drag and drop operations.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        show (bool, optional): Attempt to render widget.
        drag_data (Any, optional): Drag data
        drop_data (Any, optional): Drop data
        payload_type (str, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return drag_payload(label=label, user_data=user_data, show=show, drag_data=drag_data, drop_data=drop_data, payload_type=payload_type, **kwargs)

def drag_point(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, default_value: Any =(0.0, 0.0), color: Union[int, List[int], Tuple[int, ...]] =0, thickness: float =1.0, show_label: bool =True, offset: Union[List[float], Tuple[float, ...]] =(16.0, 8.0), clamped: bool =True, delayed: bool =False, no_cursor: bool =False, no_fit: bool =False, no_inputs: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a drag point to a plot.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        default_value (Any, optional): 
        color (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        show_label (bool, optional): 
        offset (Union[List[float], Tuple[float, ...]], optional): Offset of the label, in pixels, relative to the drag point itself
        clamped (bool, optional): Keep the label within the visible area of the plot even if the drag point itself goes outside of the visible area
        delayed (bool, optional): tool rendering will be delayed one frame; useful when applying position-constraints
        no_cursor (bool, optional): drag tools won't change cursor icons when hovered or held
        no_fit (bool, optional): the drag tool won't be considered for plot fits
        no_inputs (bool, optional): lock the tool from user inputs
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return drag_point(label=label, user_data=user_data, callback=callback, show=show, value=default_value, color=color, thickness=thickness, show_label=show_label, offset=offset, clamped=clamped, delayed=delayed, no_cursor=no_cursor, no_fit=no_fit, no_inputs=no_inputs, **kwargs)

def drag_rect(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, default_value: Any =(0.0, 0.0, 0.0, 0.0), color: Union[int, List[int], Tuple[int, ...]] =0, delayed: bool =False, no_cursor: bool =False, no_fit: bool =False, no_inputs: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a drag rectangle to a plot.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        default_value (Any, optional): The coordinates are specified in a sequence of: (xmin, ymin, xmax, ymax)
        color (Union[List[int], Tuple[int, ...]], optional): 
        delayed (bool, optional): tool rendering will be delayed one frame; useful when applying position-constraints
        no_cursor (bool, optional): drag tools won't change cursor icons when hovered or held
        no_fit (bool, optional): the drag tool won't be considered for plot fits
        no_inputs (bool, optional): lock the tool from user inputs
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return drag_rect(label=label, user_data=user_data, callback=callback, show=show, value=default_value, color=color, delayed=delayed, no_cursor=no_cursor, no_fit=no_fit, no_inputs=no_inputs, **kwargs)

def draw_layer(*, label: str =None, user_data: Any =None, show: bool =True, perspective_divide: bool =False, depth_clipping: bool =False, cull_mode: int =0, **kwargs) -> Union[int, str]:
    """     New in 1.1. Creates a layer useful for grouping drawlist items.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        perspective_divide (bool, optional): New in 1.1. apply perspective divide
        depth_clipping (bool, optional): New in 1.1. apply depth clipping
        cull_mode (int, optional): New in 1.1. culling mode, mvCullMode_* constants. Only works with triangles currently.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawLayer(dcg_context, label=label, user_data=user_data, show=show, perspective_divide=perspective_divide, depth_clipping=depth_clipping, cull_mode=cull_mode, **kwargs)

def draw_node(*, label: str =None, user_data: Any =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     New in 1.1. Creates a drawing node to associate a transformation matrix. Child node matricies will concatenate.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawNode(dcg_context, label=label, user_data=user_data, show=show, **kwargs)

def drawlist(width : int, height : int, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, **kwargs) -> Union[int, str]:
    """     Adds a drawing canvas.

    Args:
        width (int): 
        height (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawList(dcg_context, width, height, label=label, user_data=user_data, callback=callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, **kwargs)

def dynamic_texture(width : int, height : int, default_value : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, parent: Union[int, str] =constants.mvReservedUUID_2, **kwargs) -> Union[int, str]:
    """     Adds a dynamic texture.

    Args:
        width (int): 
        height (int): 
        default_value (Union[List[float], Tuple[float, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgTexture(dcg_context, default_value, hint_dynamic=True, label=label, user_data=user_data, **kwargs)

def error_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], negative : Union[List[float], Tuple[float, ...]], positive : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, contribute_to_bounds: bool =True, horizontal: bool =False, **kwargs) -> Union[int, str]:
    """     Adds an error series to a plot.

    Args:
        x (Any): 
        y (Any): 
        negative (Any): 
        positive (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        contribute_to_bounds (bool, optional): 
        horizontal (bool, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return error_series(x, y, negative, positive, label=label, user_data=user_data, show=show, contribute_to_bounds=contribute_to_bounds, horizontal=horizontal, **kwargs)

def file_dialog(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, callback: Callable =None, show: bool =True, default_path: str ='', default_filename: str ='.', file_count: int =0, modal: bool =False, directory_selector: bool =False, min_size: Union[List[int], Tuple[int, ...]] =[100, 100], max_size: Union[List[int], Tuple[int, ...]] =[30000, 30000], cancel_callback: Callable =None, **kwargs) -> Union[int, str]:
    """     Displays a file or directory selector depending on keywords. Displays a file dialog by default. Callback will be ran when the file or directory picker is closed. The app_data arguemnt will be populated with information related to the file and directory as a dictionary.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        default_path (str, optional): Path that the file dialog will default to when opened.
        default_filename (str, optional): Default name that will show in the file name input.
        file_count (int, optional): Number of visible files in the dialog.
        modal (bool, optional): Forces user interaction with the file selector.
        directory_selector (bool, optional): Shows only directory/paths as options. Allows selection of directory/paths only.
        min_size (Union[List[int], Tuple[int, ...]], optional): Minimum window size.
        max_size (Union[List[int], Tuple[int, ...]], optional): Maximum window size.
        cancel_callback (Callable, optional): Callback called when cancel button is clicked.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return file_dialog(label=label, user_data=user_data, width=width, height=height, callback=callback, show=show, default_path=default_path, default_filename=default_filename, file_count=file_count, modal=modal, directory_selector=directory_selector, min_size=min_size, max_size=max_size, cancel_callback=cancel_callback, **kwargs)

def file_extension(extension : str, *, label: str =None, user_data: Any =None, width: int =0, height: int =0, custom_text: str ='', **kwargs) -> Union[int, str]:
    """     Creates a file extension filter option in the file dialog.

    Args:
        extension (str): Extension that will show as an when the parent is a file dialog.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        custom_text (str, optional): Replaces the displayed text in the drop down for this extension.
        color (Union[List[int], Tuple[int, ...]], optional): Color for the text that will be shown with specified extensions.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return file_extension(extension, label=label, user_data=user_data, width=width, height=height, custom_text=custom_text, **kwargs)

def filter_set(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, show: bool =True, **kwargs) -> Union[int, str]:
    """     Helper to parse and apply text filters (e.g. aaaaa[, bbbbb][, ccccc])

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return filter_set(label=label, user_data=user_data, width=width, indent=indent, show=show, **kwargs)

def float4_value(*, label: str =None, user_data: Any =None, default_value: Union[List[float], Tuple[float, ...]] =(0.0, 0.0, 0.0, 0.0), parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a float4 value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_float4(dcg_context, default_value)

def float_value(*, label: str =None, user_data: Any =None, default_value: float =0.0, parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a float value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (float, optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_float(dcg_context, default_value)

def float_vect_value(*, label: str =None, user_data: Any =None, default_value: Union[List[float], Tuple[float, ...]] =(), parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a float vect value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_floatvect(dcg_context, default_value)

def font(file : str, size : int, *, label: str =None, user_data: Any =None, pixel_snapH: bool =False, parent: Union[int, str] =constants.mvReservedUUID_0, **kwargs) -> Union[int, str]:
    """     Adds font to a font registry.

    Args:
        file (str): 
        size (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        pixel_snapH (bool, optional): Align every glyph to pixel boundary. Useful e.g. if you are merging a non-pixel aligned font with the default font, or rendering text piece-by-piece (e.g. for coloring).
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
        default_font (bool, optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'default_font' in kwargs.keys():

        warnings.warn('default_font keyword removed', DeprecationWarning, 2)

        kwargs.pop('default_font', None)

    #return font(file, size, label=label, user_data=user_data, pixel_snapH=pixel_snapH, **kwargs)

def font_chars(chars : Union[List[int], Tuple[int, ...]], *, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Adds specific font characters to a font.

    Args:
        chars (Union[List[int], Tuple[int, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return font_chars(chars, label=label, user_data=user_data, **kwargs)

def font_range(first_char : int, last_char : int, *, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Adds a range of font characters to a font.

    Args:
        first_char (int): 
        last_char (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return font_range(first_char, last_char, label=label, user_data=user_data, **kwargs)

def font_range_hint(hint : int, *, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Adds a range of font characters (mvFontRangeHint_ constants).

    Args:
        hint (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return font_range_hint(hint, label=label, user_data=user_data, **kwargs)

def font_registry(*, label: str =None, user_data: Any =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a font registry.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return font_registry(label=label, user_data=user_data, show=show, **kwargs)

def group(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, horizontal: bool =False, horizontal_spacing: float =-1, xoffset: float =0.0, **kwargs) -> Union[int, str]:
    """     Creates a group that other widgets can belong to. The group allows item commands to be issued for all of its members.
Enable property acts in a special way enabling/disabling everything inside the group. (Use mvStyleVar_DisabledAlpha to edit colors within the disabled group.)

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        horizontal (bool, optional): Forces child widgets to be added in a horizontal layout.
        horizontal_spacing (float, optional): Spacing for the horizontal layout.
        xoffset (float, optional): Offset from containing window x item location within group.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgGroup(dcg_context, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, horizontal=horizontal, horizontal_spacing=horizontal_spacing, xoffset=xoffset, **kwargs)

def handler_registry(*, label: str =None, user_data: Any =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a handler registry.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgGlobalHandlerList(dcg_context, label=label, user_data=user_data, show=show, parent=dcg_context.viewport, **kwargs)

def heat_series(x : Union[List[float], Tuple[float, ...]], rows : int, cols : int, *, label: str =None, user_data: Any =None, show: bool =True, scale_min: float =0.0, scale_max: float =1.0, bounds_min: Any =(0.0, 0.0), bounds_max: Any =(1.0, 1.0), format: str ='%0.1f', contribute_to_bounds: bool =True, col_major: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a heat series to a plot.

    Args:
        x (Any): 
        rows (int): 
        cols (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        scale_min (float, optional): Sets the color scale min. Typically paired with the color scale widget scale_min.
        scale_max (float, optional): Sets the color scale max. Typically paired with the color scale widget scale_max.
        bounds_min (Any, optional): 
        bounds_max (Any, optional): 
        format (str, optional): 
        contribute_to_bounds (bool, optional): 
        col_major (bool, optional): data will be read in column major order
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return heat_series(x, rows, cols, label=label, user_data=user_data, show=show, scale_min=scale_min, scale_max=scale_max, bounds_min=bounds_min, bounds_max=bounds_max, format=format, contribute_to_bounds=contribute_to_bounds, col_major=col_major, **kwargs)

def histogram_series(x : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, bins: int =-1, bar_scale: float =1.0, min_range: float =0.0, max_range: float =0.0, cumulative: bool =False, density: bool =False, outliers: bool =True, horizontal: bool =False, contribute_to_bounds: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a histogram series to a plot.

    Args:
        x (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        bins (int, optional): 
        bar_scale (float, optional): 
        min_range (float, optional): set the min range value, the values under this min will be ignored
        max_range (float, optional): set the max range value, the values over this max will be ignored. If both min and max are 0.0, then the values will be the min and max values of the series
        cumulative (bool, optional): each bin will contain its count plus the counts of all previous bins
        density (bool, optional): counts will be normalized, i.e. the PDF will be visualized, or the CDF will be visualized if Cumulative is also set
        outliers (bool, optional): exclude values outside the specifed histogram range from the count toward normalizing and cumulative counts
        horizontal (bool, optional): histogram bars will be rendered horizontally
        contribute_to_bounds (bool, optional): 
        id (Union[int, str], optional): (deprecated) 
        cumlative (bool, optional): (deprecated) Deprecated because of typo
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'cumlative' in kwargs.keys():
        warnings.warn('cumlative keyword renamed to cumulative', DeprecationWarning, 2)
        cumulative=kwargs['cumlative']

    #return histogram_series(x, label=label, user_data=user_data, show=show, bins=bins, bar_scale=bar_scale, min_range=min_range, max_range=max_range, cumulative=cumulative, density=density, outliers=outliers, horizontal=horizontal, contribute_to_bounds=contribute_to_bounds, **kwargs)

def image(texture_tag : Union[int, str], *, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, tint_color: Union[List[float], Tuple[float, ...]] =-1, border_color: Union[List[float], Tuple[float, ...]] =(0, 0, 0, 0), uv_min: Union[List[float], Tuple[float, ...]] =(0.0, 0.0), uv_max: Union[List[float], Tuple[float, ...]] =(1.0, 1.0), **kwargs) -> Union[int, str]:
    """     Adds an image from a specified texture. uv_min and uv_max represent the normalized texture coordinates of the original image that will be shown. Using range (0.0,0.0)->(1.0,1.0) for texture coordinates will generally display the entire texture.

    Args:
        texture_tag (Union[int, str]): The texture_tag should come from a texture that was added to a texture registry.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        tint_color (Union[List[float], Tuple[float, ...]], optional): Applies a color tint to the entire texture.
        border_color (Union[List[float], Tuple[float, ...]], optional): Displays a border of the specified color around the texture. If the theme style has turned off the border it will not be shown.
        uv_min (Union[List[float], Tuple[float, ...]], optional): Normalized texture coordinates min point.
        uv_max (Union[List[float], Tuple[float, ...]], optional): Normalized texture coordinates max point.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgImage(dcg_context, texture=dcg_context[texture_tag], label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, color_multiplier=tint_color, border_color=border_color, uv=(uv_min[0], uv_min[1], uv_max[0], uv_max[1]), **kwargs)

def image_button(texture_tag : Union[int, str], *, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, tint_color: Union[List[float], Tuple[float, ...]] =-1, background_color: Union[List[float], Tuple[float, ...]] =(0, 0, 0, 0), uv_min: Union[List[float], Tuple[float, ...]] =(0.0, 0.0), uv_max: Union[List[float], Tuple[float, ...]] =(1.0, 1.0), **kwargs) -> Union[int, str]:
    """     Adds an button with a texture. uv_min and uv_max represent the normalized texture coordinates of the original image that will be shown. Using range (0.0,0.0)->(1.0,1.0) texture coordinates will generally display the entire texture

    Args:
        texture_tag (Union[int, str]): The texture_tag should come from a texture that was added to a texture registry.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        tint_color (Union[List[float], Tuple[float, ...]], optional): Applies a color tint to the entire texture.
        background_color (Union[List[float], Tuple[float, ...]], optional): Displays a border of the specified color around the texture.
        uv_min (Union[List[float], Tuple[float, ...]], optional): Normalized texture coordinates min point.
        uv_max (Union[List[float], Tuple[float, ...]], optional): Normalized texture coordinates max point.
        id (Union[int, str], optional): (deprecated) 
        frame_padding (int, optional): (deprecated) Empty space around the outside of the texture. Button will show around the texture.
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'frame_padding' in kwargs.keys():
        warnings.warn('frame_padding keyword deprecated. This is not supported anymore by ImGui but still used here as deprecated.', DeprecationWarning, 2)

    return dcg.dcgImageButton(dcg_context, texture=dcg_context[texture_tag], label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, color_multiplier=tint_color, background_color=background_color, uv=(uv_min[0], uv_min[1], uv_max[0], uv_max[1]), **kwargs)

def image_series(texture_tag : Union[int, str], bounds_min : Union[List[float], Tuple[float, ...]], bounds_max : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, uv_min: Union[List[float], Tuple[float, ...]] =(0.0, 0.0), uv_max: Union[List[float], Tuple[float, ...]] =(1.0, 1.0), tint_color: Union[int, List[int], Tuple[int, ...]] =-1, **kwargs) -> Union[int, str]:
    """     Adds an image series to a plot.

    Args:
        texture_tag (Union[int, str]): 
        bounds_min (Any): 
        bounds_max (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        uv_min (Union[List[float], Tuple[float, ...]], optional): normalized texture coordinates
        uv_max (Union[List[float], Tuple[float, ...]], optional): normalized texture coordinates
        tint_color (Union[List[int], Tuple[int, ...]], optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return image_series(texture_tag, bounds_min, bounds_max, label=label, user_data=user_data, show=show, uv_min=uv_min, uv_max=uv_max, tint_color=tint_color, **kwargs)

def inf_line_series(x : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, horizontal: bool =False, **kwargs) -> Union[int, str]:
    """     Adds an infinite line series to a plot.

    Args:
        x (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        horizontal (bool, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return inf_line_series(x, label=label, user_data=user_data, show=show, horizontal=horizontal, **kwargs)

def input_double(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, format: str ='%.3f', min_value: float =0.0, max_value: float =100.0, step: float =0.1, step_fast: float =1.0, min_clamped: bool =False, max_clamped: bool =False, on_enter: bool =False, readonly: bool =False, **kwargs) -> Union[int, str]:
    """     Adds input for an double. Useful when input float is not accurate enough. +/- buttons can be activated by setting the value of step.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        min_value (float, optional): Value for lower limit of input. By default this limits the step buttons. Use min_clamped to limit manual input.
        max_value (float, optional): Value for upper limit of input. By default this limits the step buttons. Use max_clamped to limit manual input.
        step (float, optional): Increment to change value by when the step buttons are pressed. Setting this and step_fast to a value of 0 or less will turn off step buttons.
        step_fast (float, optional): Increment to change value by when ctrl + step buttons are pressed. Setting this and step to a value of 0 or less will turn off step buttons.
        min_clamped (bool, optional): Activates and deactivates the enforcment of min_value.
        max_clamped (bool, optional): Activates and deactivates the enforcment of max_value.
        on_enter (bool, optional): Only runs callback on enter key press.
        readonly (bool, optional): Activates read only mode where no text can be input but text can still be highlighted.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgInputValue(dcg_context, format="double", label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, print_format=format, min_value=min_value, max_value=max_value, step=step, step_fast=step_fast, min_clamped=min_clamped, max_clamped=max_clamped, on_enter=on_enter, readonly=readonly, **kwargs)

def input_doublex(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Any =(0.0, 0.0, 0.0, 0.0), format: str ='%.3f', min_value: float =0.0, max_value: float =100.0, size: int =4, min_clamped: bool =False, max_clamped: bool =False, on_enter: bool =False, readonly: bool =False, **kwargs) -> Union[int, str]:
    """     Adds multi double input for up to 4 double values. Useful when input float mulit is not accurate enough.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Any, optional): 
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        min_value (float, optional): Value for lower limit of input for each cell. Use min_clamped to turn on.
        max_value (float, optional): Value for upper limit of input for each cell. Use max_clamped to turn on.
        size (int, optional): Number of components displayed for input.
        min_clamped (bool, optional): Activates and deactivates the enforcment of min_value.
        max_clamped (bool, optional): Activates and deactivates the enforcment of max_value.
        on_enter (bool, optional): Only runs callback on enter key press.
        readonly (bool, optional): Activates read only mode where no text can be input but text can still be highlighted.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgInputValue(dcg_context, format="double", label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, print_format=format, min_value=min_value, max_value=max_value, size=size, min_clamped=min_clamped, max_clamped=max_clamped, on_enter=on_enter, readonly=readonly, **kwargs)

def input_float(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, format: str ='%.3f', min_value: float =0.0, max_value: float =100.0, step: float =0.1, step_fast: float =1.0, min_clamped: bool =False, max_clamped: bool =False, on_enter: bool =False, readonly: bool =False, **kwargs) -> Union[int, str]:
    """     Adds input for an float. +/- buttons can be activated by setting the value of step.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        min_value (float, optional): Value for lower limit of input. By default this limits the step buttons. Use min_clamped to limit manual input.
        max_value (float, optional): Value for upper limit of input. By default this limits the step buttons. Use max_clamped to limit manual input.
        step (float, optional): Increment to change value by when the step buttons are pressed. Setting this and step_fast to a value of 0 or less will turn off step buttons.
        step_fast (float, optional): Increment to change value by when ctrl + step buttons are pressed. Setting this and step to a value of 0 or less will turn off step buttons.
        min_clamped (bool, optional): Activates and deactivates the enforcment of min_value.
        max_clamped (bool, optional): Activates and deactivates the enforcment of max_value.
        on_enter (bool, optional): Only runs callback on enter key press.
        readonly (bool, optional): Activates read only mode where no text can be input but text can still be highlighted.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgInputValue(dcg_context, format="float", label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, print_format=format, min_value=min_value, max_value=max_value, step=step, step_fast=step_fast, min_clamped=min_clamped, max_clamped=max_clamped, on_enter=on_enter, readonly=readonly, **kwargs)

def input_floatx(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[float], Tuple[float, ...]] =(0.0, 0.0, 0.0, 0.0), format: str ='%.3f', min_value: float =0.0, max_value: float =100.0, size: int =4, min_clamped: bool =False, max_clamped: bool =False, on_enter: bool =False, readonly: bool =False, **kwargs) -> Union[int, str]:
    """     Adds multi float input for up to 4 float values.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        min_value (float, optional): Value for lower limit of input for each cell. Use min_clamped to turn on.
        max_value (float, optional): Value for upper limit of input for each cell. Use max_clamped to turn on.
        size (int, optional): Number of components displayed for input.
        min_clamped (bool, optional): Activates and deactivates the enforcment of min_value.
        max_clamped (bool, optional): Activates and deactivates the enforcment of max_value.
        on_enter (bool, optional): Only runs callback on enter key press.
        readonly (bool, optional): Activates read only mode where no text can be input but text can still be highlighted.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgInputValue(dcg_context, format="float", label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, print_format=format, min_value=min_value, max_value=max_value, size=size, min_clamped=min_clamped, max_clamped=max_clamped, on_enter=on_enter, readonly=readonly, **kwargs)

def input_int(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: int =0, min_value: int =0, max_value: int =100, step: int =1, step_fast: int =100, min_clamped: bool =False, max_clamped: bool =False, on_enter: bool =False, readonly: bool =False, **kwargs) -> Union[int, str]:
    """     Adds input for an int. +/- buttons can be activated by setting the value of step.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (int, optional): 
        min_value (int, optional): Value for lower limit of input. By default this limits the step buttons. Use min_clamped to limit manual input.
        max_value (int, optional): Value for upper limit of input. By default this limits the step buttons. Use max_clamped to limit manual input.
        step (int, optional): Increment to change value by when the step buttons are pressed. Setting this and step_fast to a value of 0 or less will turn off step buttons.
        step_fast (int, optional): Increment to change value by when ctrl + step buttons are pressed. Setting this and step to a value of 0 or less will turn off step buttons.
        min_clamped (bool, optional): Activates and deactivates the enforcment of min_value.
        max_clamped (bool, optional): Activates and deactivates the enforcment of max_value.
        on_enter (bool, optional): Only runs callback on enter key press.
        readonly (bool, optional): Activates read only mode where no text can be input but text can still be highlighted.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgInputValue(dcg_context, format="int", label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, min_value=min_value, max_value=max_value, step=step, step_fast=step_fast, min_clamped=min_clamped, max_clamped=max_clamped, on_enter=on_enter, readonly=readonly, **kwargs)

def input_intx(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[int], Tuple[int, ...]] =(0, 0, 0, 0), min_value: int =0, max_value: int =100, size: int =4, min_clamped: bool =False, max_clamped: bool =False, on_enter: bool =False, readonly: bool =False, **kwargs) -> Union[int, str]:
    """     Adds multi int input for up to 4 integer values.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        min_value (int, optional): Value for lower limit of input for each cell. Use min_clamped to turn on.
        max_value (int, optional): Value for upper limit of input for each cell. Use max_clamped to turn on.
        size (int, optional): Number of components displayed for input.
        min_clamped (bool, optional): Activates and deactivates the enforcment of min_value.
        max_clamped (bool, optional): Activates and deactivates the enforcment of max_value.
        on_enter (bool, optional): Only runs callback on enter.
        readonly (bool, optional): Activates read only mode where no text can be input but text can still be highlighted.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgInputValue(dcg_context, format="int", label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, min_value=min_value, max_value=max_value, size=size, min_clamped=min_clamped, max_clamped=max_clamped, on_enter=on_enter, readonly=readonly, **kwargs)

def input_text(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: str ='', hint: str ='', multiline: bool =False, no_spaces: bool =False, uppercase: bool =False, tab_input: bool =False, decimal: bool =False, hexadecimal: bool =False, readonly: bool =False, password: bool =False, scientific: bool =False, on_enter: bool =False, auto_select_all: bool =False, ctrl_enter_for_new_line: bool =False, no_horizontal_scroll: bool =False, always_overwrite: bool =False, no_undo_redo: bool =False, escape_clears_all: bool =False, **kwargs) -> Union[int, str]:
    """     Adds input for text.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (str, optional): 
        hint (str, optional): Displayed only when value is an empty string. Will reappear if input value is set to empty string. Will not show if default value is anything other than default empty string.
        multiline (bool, optional): Allows for multiline text input.
        no_spaces (bool, optional): Filter out spaces and tabs.
        uppercase (bool, optional): Automatically make all inputs uppercase.
        tab_input (bool, optional): Allows tabs to be input into the string value instead of changing item focus.
        decimal (bool, optional): Only allow characters 0123456789.+-*/
        hexadecimal (bool, optional): Only allow characters 0123456789ABCDEFabcdef
        readonly (bool, optional): Activates read only mode where no text can be input but text can still be highlighted.
        password (bool, optional): Display all input characters as '*'.
        scientific (bool, optional): Only allow characters 0123456789.+-*/eE (Scientific notation input)
        on_enter (bool, optional): Only runs callback on enter key press.
        auto_select_all (bool, optional): Select entire text when first taking mouse focus
        ctrl_enter_for_new_line (bool, optional): In multi-line mode, unfocus with Enter, add new line with Ctrl+Enter (default is opposite: unfocus with Ctrl+Enter, add line with Enter).
        no_horizontal_scroll (bool, optional): Disable following the cursor horizontally
        always_overwrite (bool, optional): Overwrite mode
        no_undo_redo (bool, optional): Disable undo/redo.
        escape_clears_all (bool, optional): Escape key clears content if not empty, and deactivate otherwise (contrast to default behavior of Escape to revert)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgInputText(dcg_context, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, hint=hint, multiline=multiline, no_spaces=no_spaces, uppercase=uppercase, tab_input=tab_input, decimal=decimal, hexadecimal=hexadecimal, readonly=readonly, password=password, scientific=scientific, on_enter=on_enter, auto_select_all=auto_select_all, ctrl_enter_for_new_line=ctrl_enter_for_new_line, no_horizontal_scroll=no_horizontal_scroll, always_overwrite=always_overwrite, no_undo_redo=no_undo_redo, escape_clears_all=escape_clears_all, **kwargs)

def int4_value(*, label: str =None, user_data: Any =None, default_value: Union[List[int], Tuple[int, ...]] =(0, 0, 0, 0), parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a int4 value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_int4(dcg_context, default_value)

def int_value(*, label: str =None, user_data: Any =None, default_value: int =0, parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a int value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (int, optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_int(dcg_context, default_value)

def item_activated_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a activated handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgActivatedHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_active_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a active handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgActiveHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_clicked_handler(button : int =-1, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a clicked handler.

    Args:
        button (int, optional): Submits callback for all mouse buttons
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgClickedHandler(dcg_context, button, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_deactivated_after_edit_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a deactivated after edit handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDeactivatedAfterEditHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_deactivated_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a deactivated handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDeactivatedHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_double_clicked_handler(button : int =-1, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a double click handler.

    Args:
        button (int, optional): Submits callback for all mouse buttons
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDoubleClickedHandler(dcg_context, button, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_edited_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds an edited handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgEditedHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_focus_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a focus handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgFocusHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_handler_registry(*, label: str =None, user_data: Any =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds an item handler registry.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgItemHandlerList(dcg_context, label=label, user_data=user_data, show=show, **kwargs)

def item_hover_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a hover handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgHoverHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_resize_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a resize handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgResizeHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_toggled_open_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a togged open handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgToggledOpenHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def item_visible_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a visible handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgVisibleHandler(dcg_context, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def key_down_handler(key : int =constants.mvKey_None, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a key down handler.

    Args:
        key (int, optional): Submits callback for all keys
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgKeyDownHandler(dcg_context, key, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def key_press_handler(key : int =constants.mvKey_None, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a key press handler.

    Args:
        key (int, optional): Submits callback for all keys
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgKeyPressHandler(dcg_context, key, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def key_release_handler(key : int =constants.mvKey_None, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a key release handler.

    Args:
        key (int, optional): Submits callback for all keys
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgKeyReleaseHandler(dcg_context, key, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def knob_float(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, min_value: float =0.0, max_value: float =100.0, **kwargs) -> Union[int, str]:
    """     Adds a knob that rotates based on change in x mouse position.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        min_value (float, optional): Applies lower limit to value.
        max_value (float, optional): Applies upper limit to value.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return knob_float(label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, min_value=min_value, max_value=max_value, **kwargs)

def line_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, segments: bool =False, loop: bool =False, skip_nan: bool =False, no_clip: bool =False, shaded: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a line series to a plot.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        segments (bool, optional): a line segment will be rendered from every two consecutive points
        loop (bool, optional): the last and first point will be connected to form a closed loop
        skip_nan (bool, optional): NaNs values will be skipped instead of rendered as missing data
        no_clip (bool, optional): markers (if displayed) on the edge of a plot will not be clipped
        shaded (bool, optional): a filled region between the line and horizontal origin will be rendered; use shade_series for more advanced cases
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return line_series(x, y, label=label, user_data=user_data, show=show, segments=segments, loop=loop, skip_nan=skip_nan, no_clip=no_clip, shaded=shaded, **kwargs)

def listbox(items : Union[List[str], Tuple[str, ...]] =(), *, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: str ='', num_items: int =3, **kwargs) -> Union[int, str]:
    """     Adds a listbox. If height is not large enough to show all items a scroll bar will appear.

    Args:
        items (Union[List[str], Tuple[str, ...]], optional): A tuple of items to be shown in the listbox. Can consist of any combination of types. All items will be displayed as strings.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (str, optional): String value of the item that will be selected by default.
        num_items (int, optional): Expands the height of the listbox to show specified number of items.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgListBox(dcg_context, items=items, label=label, user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, num_items_shown_when_open=num_items, **kwargs)

def loading_indicator(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], style: int =0, circle_count: int =8, speed: float =1.0, radius: float =3.0, thickness: float =1.0, color: Union[int, List[int], Tuple[int, ...]] =(51, 51, 55, 255), secondary_color: Union[int, List[int], Tuple[int, ...]] =(29, 151, 236, 103), **kwargs) -> Union[int, str]:
    """     Adds a rotating animated loading symbol.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        style (int, optional): 0 is rotating dots style, 1 is rotating bar style.
        circle_count (int, optional): Number of dots show if dots or size of circle if circle.
        speed (float, optional): Speed the anamation will rotate.
        radius (float, optional): Radius size of the loading indicator.
        thickness (float, optional): Thickness of the circles or line.
        color (Union[List[int], Tuple[int, ...]], optional): Color of the growing center circle.
        secondary_color (Union[List[int], Tuple[int, ...]], optional): Background of the dots in dot mode.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return loading_indicator(label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, drop_callback=drop_callback, show=show, pos=pos, style=style, circle_count=circle_count, speed=speed, radius=radius, thickness=thickness, color=color, secondary_color=secondary_color, **kwargs)

def menu(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drop_callback: Callable =None, show: bool =True, enabled: bool =True, filter_key: str ='', tracked: bool =False, track_offset: float =0.5, **kwargs) -> Union[int, str]:
    """     Adds a menu to an existing menu bar.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgMenu(dcg_context, label=label, user_data=user_data, indent=indent, payload_type=payload_type, drop_callback=drop_callback, show=show, enabled=enabled, filter_key=filter_key, tracked=tracked, track_offset=track_offset, **kwargs)

def menu_bar(*, label: str =None, user_data: Any =None, indent: int =0, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a menu bar to a window.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgMenuBar(dcg_context, label=label, user_data=user_data, indent=indent, show=show, **kwargs)

def menu_item(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: bool =False, shortcut: str ='', check: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a menu item to an existing menu. Menu items act similar to selectables and has a bool value. When placed in a menu the checkmark will reflect its value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (bool, optional): This value also controls the checkmark when shown.
        shortcut (str, optional): Displays text on the menu item. Typically used to show a shortcut key command.
        check (bool, optional): Displays a checkmark on the menu item when it is selected and placed in a menu.
        id (Union[int, str], optional): (deprecated) 
        drag_callback (Callable, optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'drag_callback' in kwargs.keys():

        warnings.warn('drag_callback keyword removed', DeprecationWarning, 2)

        kwargs.pop('drag_callback', None)

    return dcg.dcgMenuItem(dcg_context, label=label, user_data=user_data, indent=indent, payload_type=payload_type, callback=callback, drop_callback=drop_callback, show=show, enabled=enabled, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, shortcut=shortcut, check=check, **kwargs)

def mouse_click_handler(button : int =-1, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a mouse click handler.

    Args:
        button (int, optional): Submits callback for all mouse buttons
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgMouseClickHandler(dcg_context, button, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def mouse_double_click_handler(button : int =-1, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a mouse double click handler.

    Args:
        button (int, optional): Submits callback for all mouse buttons
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgMouseDoubleClickHandler(dcg_context, button, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def mouse_down_handler(button : int =-1, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a mouse down handler.

    Args:
        button (int, optional): Submits callback for all mouse buttons
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgMouseDownHandler(dcg_context, button, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def mouse_drag_handler(button : int =-1, threshold : float =10.0, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a mouse drag handler.

    Args:
        button (int, optional): Submits callback for all mouse buttons
        threshold (float, optional): The threshold the mouse must be dragged before the callback is ran
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgMouseDragHandler(dcg_context, button, threshold, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def mouse_move_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a mouse move handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    # TODO
    #return mouse_move_handler(label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def mouse_release_handler(button : int =-1, *, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a mouse release handler.

    Args:
        button (int, optional): Submits callback for all mouse buttons
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgMouseReleaseHandler(dcg_context, button, label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def mouse_wheel_handler(*, label: str =None, user_data: Any =None, callback: Callable =None, show: bool =True, parent: Union[int, str] =constants.mvReservedUUID_1, **kwargs) -> Union[int, str]:
    """     Adds a mouse wheel handler.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    # TODO
    #return mouse_wheel_handler(label=label, user_data=user_data, callback=callback, show=show, **kwargs)

def node(*, label: str =None, user_data: Any =None, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, draggable: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a node to a node editor.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        draggable (bool, optional): Allow node to be draggable.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return node(label=label, user_data=user_data, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, draggable=draggable, **kwargs)

def node_attribute(*, label: str =None, user_data: Any =None, indent: int =0, show: bool =True, filter_key: str ='', tracked: bool =False, track_offset: float =0.5, attribute_type: int =0, shape: int =1, category: str ='general', **kwargs) -> Union[int, str]:
    """     Adds a node attribute to a node.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        attribute_type (int, optional): mvNode_Attr_Input, mvNode_Attr_Output, or mvNode_Attr_Static.
        shape (int, optional): Pin shape.
        category (str, optional): Category
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return node_attribute(label=label, user_data=user_data, indent=indent, show=show, filter_key=filter_key, tracked=tracked, track_offset=track_offset, attribute_type=attribute_type, shape=shape, category=category, **kwargs)

def node_editor(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, callback: Callable =None, show: bool =True, filter_key: str ='', tracked: bool =False, track_offset: float =0.5, delink_callback: Callable =None, menubar: bool =False, minimap: bool =False, minimap_location: int =2, **kwargs) -> Union[int, str]:
    """     Adds a node editor.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        delink_callback (Callable, optional): Callback ran when a link is detached.
        menubar (bool, optional): Shows or hides the menubar.
        minimap (bool, optional): Shows or hides the Minimap. New in 1.6.
        minimap_location (int, optional): mvNodeMiniMap_Location_* constants. New in 1.6.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return node_editor(label=label, user_data=user_data, width=width, height=height, callback=callback, show=show, filter_key=filter_key, tracked=tracked, track_offset=track_offset, delink_callback=delink_callback, menubar=menubar, minimap=minimap, minimap_location=minimap_location, **kwargs)

def node_link(attr_1 : Union[int, str], attr_2 : Union[int, str], *, label: str =None, user_data: Any =None, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a node link between 2 node attributes.

    Args:
        attr_1 (Union[int, str]): 
        attr_2 (Union[int, str]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return node_link(attr_1, attr_2, label=label, user_data=user_data, show=show, **kwargs)

def pie_series(x : float, y : float, radius : float, values : Union[List[float], Tuple[float, ...]], labels : Union[List[str], Tuple[str, ...]], *, label: str =None, user_data: Any =None, show: bool =True, format: str ='%0.2f', angle: float =90.0, normalize: bool =False, ignore_hidden: bool =False, **kwargs) -> Union[int, str]:
    """     Adds an pie series to a plot.

    Args:
        x (float): 
        y (float): 
        radius (float): 
        values (Any): 
        labels (Union[List[str], Tuple[str, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        format (str, optional): 
        angle (float, optional): 
        normalize (bool, optional): force normalization of pie chart values (i.e. always make a full circle if sum < 0)
        ignore_hidden (bool, optional): ignore hidden slices when drawing the pie chart (as if they were not there)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return pie_series(x, y, radius, values, labels, label=label, user_data=user_data, show=show, format=format, angle=angle, normalize=normalize, ignore_hidden=ignore_hidden, **kwargs)

def plot(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, no_title: bool =False, no_menus: bool =False, no_box_select: bool =False, no_mouse_pos: bool =False, query: bool =False, query_color: Union[List[float], Tuple[float, ...]] =(0, 255, 0, 255), min_query_rects: int =1, max_query_rects: int =1, crosshairs: bool =False, equal_aspects: bool =False, no_inputs: bool =False, no_frame: bool =False, use_local_time: bool =False, use_ISO8601: bool =False, use_24hour_clock: bool =False, pan_button: int =constants.mvMouseButton_Left, pan_mod: int =constants.mvKey_None, context_menu_button: int =constants.mvMouseButton_Right, fit_button: int =constants.mvMouseButton_Left, box_select_button: int =constants.mvMouseButton_Right, box_select_mod: int =constants.mvKey_None, box_select_cancel_button: int =constants.mvMouseButton_Left, query_toggle_mod: int =constants.mvKey_ModCtrl, horizontal_mod: int =constants.mvKey_ModAlt, vertical_mod: int =constants.mvKey_ModShift, override_mod: int =constants.mvKey_ModCtrl, zoom_mod: int =constants.mvKey_None, zoom_rate: int =0.1, **kwargs) -> Union[int, str]:
    """     Adds a plot which is used to hold series, and can be drawn to with draw commands. For all _mod parameters use mvKey_ModX enums, or mvKey_ModDisabled to disable the modifier.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        no_title (bool, optional): the plot title will not be displayed
        no_menus (bool, optional): the user will not be able to open context menus with right-click
        no_box_select (bool, optional): the user will not be able to box-select with right-click drag
        no_mouse_pos (bool, optional): the text of mouse position, in plot coordinates, will not be displayed inside of the plot
        query (bool, optional): the user will be able to draw query rects with CTRL + right-click drag
        query_color (Union[List[float], Tuple[float, ...]], optional): Color of the query rectangles.
        min_query_rects (int, optional): The minimum number of query rects that can be in the plot. If there are less rects than this value, it won't be possible to delete them.
        max_query_rects (int, optional): The maximum number of query rects that can be in the plot. If the number is reached any rect added will replace the latest one. (0 means unlimited)
        crosshairs (bool, optional): the default mouse cursor will be replaced with a crosshair when hovered
        equal_aspects (bool, optional): primary x and y axes will be constrained to have the same units/pixel (does not apply to auxiliary y-axes)
        no_inputs (bool, optional): the user will not be able to interact with the plot
        no_frame (bool, optional): the ImGui frame will not be rendered
        use_local_time (bool, optional): axis labels will be formatted for your timezone when
        use_ISO8601 (bool, optional): dates will be formatted according to ISO 8601 where applicable (e.g. YYYY-MM-DD, YYYY-MM, --MM-DD, etc.)
        use_24hour_clock (bool, optional): times will be formatted using a 24 hour clock
        pan_button (int, optional): mouse button that enables panning when held
        pan_mod (int, optional): optional modifier that must be held for panning
        context_menu_button (int, optional): opens context menus (if enabled) when clicked
        fit_button (int, optional): fits visible data when double clicked
        box_select_button (int, optional): begins box selection when pressed and confirms selection when released
        box_select_mod (int, optional): begins box selection when pressed and confirms selection when released
        box_select_cancel_button (int, optional): cancels active box selection when pressed
        query_toggle_mod (int, optional): when held, active box selections turn into queries
        horizontal_mod (int, optional): expands active box selection/query horizontally to plot edge when held
        vertical_mod (int, optional): expands active box selection/query vertically to plot edge when held
        override_mod (int, optional): when held, all input is ignored; used to enable axis/plots as DND sources
        zoom_mod (int, optional): optional modifier that must be held for scroll wheel zooming
        zoom_rate (int, optional): zoom rate for scroll (e.g. 0.1f = 10% plot range every scroll click); make negative to invert
        id (Union[int, str], optional): (deprecated) 
        no_highlight (bool, optional): (deprecated) Removed because not supported from the backend anymore. To control the highlighting of series use the same argument in `plot_legend`
        no_child (bool, optional): (deprecated) a child window region will not be used to capture mouse scroll (can boost performance for single ImGui window applications)
        anti_aliased (bool, optional): (deprecated) This feature was deprecated in ImPlot. To enable/disable anti_aliasing use `dpg.configure_app()` with the `anti_aliasing` parameters.
        query_button (int, optional): (deprecated) This refers to the old way of querying of ImPlot, now replaced with `DragRect()`
        query_mod (int, optional): (deprecated) This refers to the old way of querying of ImPlot, now replaced with `DragRect()`
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'no_highlight' in kwargs.keys():

        warnings.warn('no_highlight keyword removed', DeprecationWarning, 2)

        kwargs.pop('no_highlight', None)

    if 'no_child' in kwargs.keys():

        warnings.warn('no_child keyword removed', DeprecationWarning, 2)

        kwargs.pop('no_child', None)

    if 'anti_aliased' in kwargs.keys():

        warnings.warn('anti_aliased keyword removed', DeprecationWarning, 2)

        kwargs.pop('anti_aliased', None)

    if 'query_button' in kwargs.keys():

        warnings.warn('query_button keyword removed', DeprecationWarning, 2)

        kwargs.pop('query_button', None)

    if 'query_mod' in kwargs.keys():

        warnings.warn('query_mod keyword removed', DeprecationWarning, 2)

        kwargs.pop('query_mod', None)

    #return plot(label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, no_title=no_title, no_menus=no_menus, no_box_select=no_box_select, no_mouse_pos=no_mouse_pos, query=query, query_color=query_color, min_query_rects=min_query_rects, max_query_rects=max_query_rects, crosshairs=crosshairs, equal_aspects=equal_aspects, no_inputs=no_inputs, no_frame=no_frame, use_local_time=use_local_time, use_ISO8601=use_ISO8601, use_24hour_clock=use_24hour_clock, pan_button=pan_button, pan_mod=pan_mod, context_menu_button=context_menu_button, fit_button=fit_button, box_select_button=box_select_button, box_select_mod=box_select_mod, box_select_cancel_button=box_select_cancel_button, query_toggle_mod=query_toggle_mod, horizontal_mod=horizontal_mod, vertical_mod=vertical_mod, override_mod=override_mod, zoom_mod=zoom_mod, zoom_rate=zoom_rate, **kwargs)

def plot_annotation(*, label: str =None, user_data: Any =None, show: bool =True, default_value: Any =(0.0, 0.0), offset: Union[List[float], Tuple[float, ...]] =(0.0, 0.0), color: Union[int, List[int], Tuple[int, ...]] =0, clamped: bool =True, **kwargs) -> Union[int, str]:
    """     Adds an annotation to a plot.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        default_value (Any, optional): 
        offset (Union[List[float], Tuple[float, ...]], optional): 
        color (Union[List[int], Tuple[int, ...]], optional): 
        clamped (bool, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return plot_annotation(label=label, user_data=user_data, show=show, value=default_value, offset=offset, color=color, clamped=clamped, **kwargs)

def plot_axis(axis : int, *, label: str =None, user_data: Any =None, payload_type: str ='$$DPG_PAYLOAD', drop_callback: Callable =None, show: bool =True, no_label: bool =False, no_gridlines: bool =False, no_tick_marks: bool =False, no_tick_labels: bool =False, no_initial_fit: bool =False, no_menus: bool =False, no_side_switch: bool =False, no_highlight: bool =False, opposite: bool =False, foreground_grid: bool =False, tick_format: str ='', scale: int =constants.mvPlotScale_Linear, invert: bool =False, auto_fit: bool =False, range_fit: bool =False, pan_stretch: bool =False, lock_min: bool =False, lock_max: bool =False, **kwargs) -> Union[int, str]:
    """     Adds an axis to a plot.

    Args:
        axis (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        no_label (bool, optional): the axis label will not be displayed
        no_gridlines (bool, optional): no grid lines will be displayed
        no_tick_marks (bool, optional): no tick marks will be displayed
        no_tick_labels (bool, optional): no text labels will be displayed
        no_initial_fit (bool, optional): axis will not be initially fit to data extents on the first rendered frame
        no_menus (bool, optional): the user will not be able to open context menus with right-click
        no_side_switch (bool, optional): the user will not be able to switch the axis side by dragging it
        no_highlight (bool, optional): the axis will not have its background highlighted when hovered or held
        opposite (bool, optional): axis ticks and labels will be rendered on the conventionally opposite side (i.e, right or top)
        foreground_grid (bool, optional): grid lines will be displayed in the foreground (i.e. on top of data) instead of the background
        tick_format (str, optional): Sets a custom tick label formatter
        scale (int, optional): Sets the axis' scale. Can have only mvPlotScale_ values
        invert (bool, optional): the axis values will be inverted (i.e. growing from right to left)
        auto_fit (bool, optional): axis will be auto-fitting to data extents
        range_fit (bool, optional): axis will only fit points if the point is in the visible range of the **orthogonal** axis
        pan_stretch (bool, optional): panning in a locked or constrained state will cause the axis to stretch if possible
        lock_min (bool, optional): the axis minimum value will be locked when panning/zooming
        lock_max (bool, optional): the axis maximum value will be locked when panning/zooming
        id (Union[int, str], optional): (deprecated) 
        log_scale (bool, optional): (deprecated) Old way to set log scale in the axis. Use 'scale' argument instead.
        time (bool, optional): (deprecated) Old way to set time scale in the axis. Use 'scale' argument instead.
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'log_scale' in kwargs.keys():
        warnings.warn('log_scale keyword deprecated. See the new scale argument.', DeprecationWarning, 2)

    if 'time' in kwargs.keys():
        warnings.warn('time keyword deprecated. See the new scale argument.', DeprecationWarning, 2)

    #return plot_axis(axis, label=label, user_data=user_data, payload_type=payload_type, drop_callback=drop_callback, show=show, no_label=no_label, no_gridlines=no_gridlines, no_tick_marks=no_tick_marks, no_tick_labels=no_tick_labels, no_initial_fit=no_initial_fit, no_menus=no_menus, no_side_switch=no_side_switch, no_highlight=no_highlight, opposite=opposite, foreground_grid=foreground_grid, tick_format=tick_format, scale=scale, invert=invert, auto_fit=auto_fit, range_fit=range_fit, pan_stretch=pan_stretch, lock_min=lock_min, lock_max=lock_max, **kwargs)

def plot_legend(*, label: str =None, user_data: Any =None, payload_type: str ='$$DPG_PAYLOAD', drop_callback: Callable =None, show: bool =True, location: int =5, horizontal: bool =False, sort: bool =False, outside: bool =False, no_highlight_item: bool =False, no_highlight_axis: bool =False, no_menus: bool =False, no_buttons: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a plot legend to a plot.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        location (int, optional): location, mvPlot_Location_*
        horizontal (bool, optional): legend entries will be displayed horizontally
        sort (bool, optional): legend entries will be displayed in alphabetical order
        outside (bool, optional): legend will be rendered outside of the plot area
        no_highlight_item (bool, optional): plot items will not be highlighted when their legend entry is hovered
        no_highlight_axis (bool, optional): axes will not be highlighted when legend entries are hovered (only relevant if x/y-axis count > 1)
        no_menus (bool, optional): the user will not be able to open context menus with right-click
        no_buttons (bool, optional): legend icons will not function as hide/show buttons
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return plot_legend(label=label, user_data=user_data, payload_type=payload_type, drop_callback=drop_callback, show=show, location=location, horizontal=horizontal, sort=sort, outside=outside, no_highlight_item=no_highlight_item, no_highlight_axis=no_highlight_axis, no_menus=no_menus, no_buttons=no_buttons, **kwargs)

def progress_bar(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, overlay: str ='', default_value: float =0.0, **kwargs) -> Union[int, str]:
    """     Adds a progress bar.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        overlay (str, optional): Overlayed text onto the bar that typically used to display the value of the progress.
        default_value (float, optional): Normalized value to fill the bar from 0.0 to 1.0. Put a negative value to show an indeterminate progress bar.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgProgressBar(dcg_context, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, overlay=overlay, value=default_value, **kwargs)

def radio_button(items : Union[List[str], Tuple[str, ...]] =(), *, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: str ='', horizontal: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a set of radio buttons. If items keyword is empty, nothing will be shown.

    Args:
        items (Union[List[str], Tuple[str, ...]], optional): A tuple of items to be shown as radio options. Can consist of any combination of types. All types will be shown as strings.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (str, optional): Default selected radio option. Set by using the string value of the item.
        horizontal (bool, optional): Displays the radio options horizontally.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgRadioButton(dcg_context, items=items, label=label, user_data=user_data, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, horizontal=horizontal, **kwargs)

def raw_texture(width : int, height : int, default_value : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, format: int =constants.mvFormat_Float_rgba, parent: Union[int, str] =constants.mvReservedUUID_2, **kwargs) -> Union[int, str]:
    """     Adds a raw texture.

    Args:
        width (int): 
        height (int): 
        default_value (Union[List[float], Tuple[float, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        format (int, optional): Data format.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgTexture(dcg_context, default_value, hint_dynamic=True, label=label, user_data=user_data, **kwargs)

def scatter_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, no_clip: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a scatter series to a plot.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        no_clip (bool, optional): markers on the edge of a plot will not be clipped
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return scatter_series(x, y, label=label, user_data=user_data, show=show, no_clip=no_clip, **kwargs)

def selectable(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: bool =False, span_columns: bool =False, disable_popup_close: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a selectable. Similar to a button but can indicate its selected state.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (bool, optional): 
        span_columns (bool, optional): Forces the selectable to span the width of all columns if placed in a table.
        disable_popup_close (bool, optional): Disable closing a modal or popup window.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSelectable(dcg_context, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, span_columns=span_columns, disable_popup_close=disable_popup_close, **kwargs)

def separator(*, label: str =None, user_data: Any =None, indent: int =0, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], **kwargs) -> Union[int, str]:
    """     Adds a horizontal line separator. Use 'label' parameter to add text and mvStyleVar_SeparatorText* elements to style it.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSeparator(dcg_context, label=label, user_data=user_data, indent=indent, show=show, pos=pos, **kwargs)

def series_value(*, label: str =None, user_data: Any =None, default_value: Any =(), parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a plot series value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (Any, optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return series_value(label=label, user_data=user_data, value=default_value, **kwargs)

def shade_series(x : Union[List[float], Tuple[float, ...]], y1 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, y2: Any =[], **kwargs) -> Union[int, str]:
    """     Adds a shade series to a plot.

    Args:
        x (Any): 
        y1 (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        y2 (Any, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return shade_series(x, y1, label=label, user_data=user_data, show=show, y2=y2, **kwargs)

def simple_plot(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[float], Tuple[float, ...]] =(), overlay: str ='', histogram: bool =False, autosize: bool =True, min_scale: float =0.0, max_scale: float =0.0, **kwargs) -> Union[int, str]:
    """     Adds a simple plot for visualization of a 1 dimensional set of values.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        overlay (str, optional): overlays text (similar to a plot title)
        histogram (bool, optional): 
        autosize (bool, optional): 
        min_scale (float, optional): 
        max_scale (float, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSimplePlot(dcg_context, label=label, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, overlay=overlay, histogram=histogram, autosize=autosize, min_scale=min_scale, max_scale=max_scale, **kwargs)

def slider_double(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, vertical: bool =False, no_input: bool =False, clamped: bool =False, min_value: float =0.0, max_value: float =100.0, format: str ='%.3f', **kwargs) -> Union[int, str]:
    """     Adds slider for a single double value. Useful when slider float is not accurate enough. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the slider. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        vertical (bool, optional): Sets orientation of the slidebar and slider to vertical.
        no_input (bool, optional): Disable direct entry methods double-click or ctrl+click or Enter key allowing to input text directly into the item.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        min_value (float, optional): Applies a limit only to sliding entry only.
        max_value (float, optional): Applies a limit only to sliding entry only.
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="double", size=1, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, vertical=vertical, no_input=no_input, clamped=clamped, min_value=min_value, max_value=max_value, print_format=format, **kwargs)

def slider_doublex(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Any =(0.0, 0.0, 0.0, 0.0), size: int =4, no_input: bool =False, clamped: bool =False, min_value: float =0.0, max_value: float =100.0, format: str ='%.3f', **kwargs) -> Union[int, str]:
    """     Adds multi slider for up to 4 double values. Usueful for when multi slide float is not accurate enough. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the slider. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Any, optional): 
        size (int, optional): Number of doubles to be displayed.
        no_input (bool, optional): Disable direct entry methods double-click or ctrl+click or Enter key allowing to input text directly into the item.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        min_value (float, optional): Applies a limit only to sliding entry only.
        max_value (float, optional): Applies a limit only to sliding entry only.
        format (str, optional): Determines the format the int will be displayed as use python string formatting.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="double", user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, size=size, no_input=no_input, clamped=clamped, min_value=min_value, max_value=max_value, print_format=format, **kwargs)

def slider_float(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: float =0.0, vertical: bool =False, no_input: bool =False, clamped: bool =False, min_value: float =0.0, max_value: float =100.0, format: str ='%.3f', **kwargs) -> Union[int, str]:
    """     Adds slider for a single float value. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the slider. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (float, optional): 
        vertical (bool, optional): Sets orientation of the slidebar and slider to vertical.
        no_input (bool, optional): Disable direct entry methods double-click or ctrl+click or Enter key allowing to input text directly into the item.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        min_value (float, optional): Applies a limit only to sliding entry only.
        max_value (float, optional): Applies a limit only to sliding entry only.
        format (str, optional): Determines the format the float will be displayed as use python string formatting.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="float", size=1, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, vertical=vertical, no_input=no_input, clamped=clamped, min_value=min_value, max_value=max_value, print_format=format, **kwargs)

def slider_floatx(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[float], Tuple[float, ...]] =(0.0, 0.0, 0.0, 0.0), size: int =4, no_input: bool =False, clamped: bool =False, min_value: float =0.0, max_value: float =100.0, format: str ='%.3f', **kwargs) -> Union[int, str]:
    """     Adds multi slider for up to 4 float values. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the slider. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[float], Tuple[float, ...]], optional): 
        size (int, optional): Number of floats to be displayed.
        no_input (bool, optional): Disable direct entry methods double-click or ctrl+click or Enter key allowing to input text directly into the item.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        min_value (float, optional): Applies a limit only to sliding entry only.
        max_value (float, optional): Applies a limit only to sliding entry only.
        format (str, optional): Determines the format the int will be displayed as use python string formatting.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="float", user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, size=size, no_input=no_input, clamped=clamped, min_value=min_value, max_value=max_value, print_format=format, **kwargs)

def slider_int(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: int =0, vertical: bool =False, no_input: bool =False, clamped: bool =False, min_value: int =0, max_value: int =100, format: str ='%d', **kwargs) -> Union[int, str]:
    """     Adds slider for a single int value. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the slider. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (int, optional): 
        vertical (bool, optional): Sets orientation of the slidebar and slider to vertical.
        no_input (bool, optional): Disable direct entry methods double-click or ctrl+click or Enter key allowing to input text directly into the item.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        min_value (int, optional): Applies a limit only to sliding entry only.
        max_value (int, optional): Applies a limit only to sliding entry only.
        format (str, optional): Determines the format the int will be displayed as use python string formatting.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="int", size=1, user_data=user_data, width=width, height=height, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, vertical=vertical, no_input=no_input, clamped=clamped, min_value=min_value, max_value=max_value, print_format=format, **kwargs)

def slider_intx(*, label: str =None, user_data: Any =None, width: int =0, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, enabled: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: Union[List[int], Tuple[int, ...]] =(0, 0, 0, 0), size: int =4, no_input: bool =False, clamped: bool =False, min_value: int =0, max_value: int =100, format: str ='%d', **kwargs) -> Union[int, str]:
    """     Adds multi slider for up to 4 int values. Directly entry can be done with double click or CTRL+Click. Min and Max alone are a soft limit for the slider. Use clamped keyword to also apply limits to the direct entry modes.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (Union[List[int], Tuple[int, ...]], optional): 
        size (int, optional): Number of ints to be displayed.
        no_input (bool, optional): Disable direct entry methods double-click or ctrl+click or Enter key allowing to input text directly into the item.
        clamped (bool, optional): Applies the min and max limits to direct entry methods also such as double click and CTRL+Click.
        min_value (int, optional): Applies a limit only to sliding entry only.
        max_value (int, optional): Applies a limit only to sliding entry only.
        format (str, optional): Determines the format the int will be displayed as use python string formatting.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSlider(dcg_context, label=label, format="int", user_data=user_data, width=width, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, enabled=enabled, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, size=size, no_input=no_input, clamped=clamped, min_value=min_value, max_value=max_value, print_format=format, **kwargs)

def spacer(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], **kwargs) -> Union[int, str]:
    """     Adds a spacer item that can be used to help with layouts or can be used as a placeholder item.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgSpacer(dcg_context, label=label, user_data=user_data, width=width, height=height, indent=indent, show=show, pos=pos, **kwargs)

def stage(*, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Adds a stage.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    return dcg.dcgPlacerHolderParent(**kwargs)

def stair_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, pre_step: bool =False, shaded: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a stair series to a plot.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        pre_step (bool, optional): the y value is continued constantly to the left from every x position, i.e. the interval (x[i-1], x[i]] has the value y[i]
        shaded (bool, optional): a filled region between the line and horizontal origin will be rendered; use shade_series for more advanced cases
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return stair_series(x, y, label=label, user_data=user_data, show=show, pre_step=pre_step, shaded=shaded, **kwargs)

def static_texture(width : int, height : int, default_value : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, parent: Union[int, str] =constants.mvReservedUUID_2, **kwargs) -> Union[int, str]:
    """     Adds a static texture.

    Args:
        width (int): 
        height (int): 
        default_value (Union[List[float], Tuple[float, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgTexture(dcg_context, default_value, label=label, user_data=user_data, **kwargs)

def stem_series(x : Union[List[float], Tuple[float, ...]], y : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, indent: int =0, show: bool =True, horizontal: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a stem series to a plot.

    Args:
        x (Any): 
        y (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        horizontal (bool, optional): stems will be rendered horizontally on the current y-axis
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return stem_series(x, y, label=label, user_data=user_data, indent=indent, show=show, horizontal=horizontal, **kwargs)

def string_value(*, label: str =None, user_data: Any =None, default_value: str ='', parent: Union[int, str] =constants.mvReservedUUID_3, **kwargs) -> Union[int, str]:
    """     Adds a string value.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        default_value (str, optional): 
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.shared_str(dcg_context, label=label, user_data=user_data, value=default_value, **kwargs)

def subplots(rows : int, columns : int, *, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, row_ratios: Union[List[float], Tuple[float, ...]] =[], column_ratios: Union[List[float], Tuple[float, ...]] =[], no_title: bool =False, no_menus: bool =False, no_resize: bool =False, no_align: bool =False, share_series: bool =False, link_rows: bool =False, link_columns: bool =False, link_all_x: bool =False, link_all_y: bool =False, column_major: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a collection of plots.

    Args:
        rows (int): 
        columns (int): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        row_ratios (Union[List[float], Tuple[float, ...]], optional): 
        column_ratios (Union[List[float], Tuple[float, ...]], optional): 
        no_title (bool, optional): the subplot title will not be displayed
        no_menus (bool, optional): the user will not be able to open context menus with right-click
        no_resize (bool, optional): resize splitters between subplot cells will be not be provided
        no_align (bool, optional): subplot edges will not be aligned vertically or horizontally
        share_series (bool, optional): when set to True, series from all sub-plots will be shared to some extent, using a single common color set and showing them in a single legend in the subplots item. Otherwise each plot will be independent from others and will have its own legend
        link_rows (bool, optional): link the y-axis limits of all plots in each row (does not apply auxiliary y-axes)
        link_columns (bool, optional): link the x-axis limits of all plots in each column
        link_all_x (bool, optional): link the x-axis limits in every plot in the subplot
        link_all_y (bool, optional): link the y-axis limits in every plot in the subplot (does not apply to auxiliary y-axes)
        column_major (bool, optional): subplots are added in column major order instead of the default row major order
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return subplots(rows, columns, label=label, user_data=user_data, width=width, height=height, indent=indent, callback=callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, row_ratios=row_ratios, column_ratios=column_ratios, no_title=no_title, no_menus=no_menus, no_resize=no_resize, no_align=no_align, share_series=share_series, link_rows=link_rows, link_columns=link_columns, link_all_x=link_all_x, link_all_y=link_all_y, column_major=column_major, **kwargs)

def tab(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drop_callback: Callable =None, show: bool =True, filter_key: str ='', tracked: bool =False, track_offset: float =0.5, closable: bool =False, no_tooltip: bool =False, order_mode: int =0, **kwargs) -> Union[int, str]:
    """     Adds a tab to a tab bar.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        closable (bool, optional): Creates a button on the tab that can hide the tab.
        no_tooltip (bool, optional): Disable tooltip for the given tab.
        order_mode (int, optional): set using a constant: mvTabOrder_Reorderable: allows reordering, mvTabOrder_Fixed: fixed ordering, mvTabOrder_Leading: adds tab to front, mvTabOrder_Trailing: adds tab to back
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return tab(label=label, user_data=user_data, indent=indent, payload_type=payload_type, drop_callback=drop_callback, show=show, filter_key=filter_key, tracked=tracked, track_offset=track_offset, closable=closable, no_tooltip=no_tooltip, order_mode=order_mode, **kwargs)

def tab_bar(*, label: str =None, user_data: Any =None, indent: int =0, callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, reorderable: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a tab bar.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        reorderable (bool, optional): Allows for the user to change the order of the tabs.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return tab_bar(label=label, user_data=user_data, indent=indent, callback=callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, reorderable=reorderable, **kwargs)

def tab_button(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, filter_key: str ='', tracked: bool =False, track_offset: float =0.5, no_reorder: bool =False, leading: bool =False, trailing: bool =False, no_tooltip: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a tab button to a tab bar.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        no_reorder (bool, optional): Disable reordering this tab or having another tab cross over this tab. Fixes the position of this tab in relation to the order of neighboring tabs at start. 
        leading (bool, optional): Enforce the tab position to the left of the tab bar (after the tab list popup button).
        trailing (bool, optional): Enforce the tab position to the right of the tab bar (before the scrolling buttons).
        no_tooltip (bool, optional): Disable tooltip for the given tab.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return tab_button(label=label, user_data=user_data, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, filter_key=filter_key, tracked=tracked, track_offset=track_offset, no_reorder=no_reorder, leading=leading, trailing=trailing, no_tooltip=no_tooltip, **kwargs)

def table(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, indent: int =0, callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', header_row: bool =True, clipper: bool =False, inner_width: int =0, policy: int =0, freeze_rows: int =0, freeze_columns: int =0, sort_multi: bool =False, sort_tristate: bool =False, resizable: bool =False, reorderable: bool =False, hideable: bool =False, sortable: bool =False, context_menu_in_body: bool =False, row_background: bool =False, borders_innerH: bool =False, borders_outerH: bool =False, borders_innerV: bool =False, borders_outerV: bool =False, no_host_extendX: bool =False, no_host_extendY: bool =False, no_keep_columns_visible: bool =False, precise_widths: bool =False, no_clip: bool =False, pad_outerX: bool =False, no_pad_outerX: bool =False, no_pad_innerX: bool =False, scrollX: bool =False, scrollY: bool =False, no_saved_settings: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a table.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        callback (Callable, optional): Registers a callback.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        header_row (bool, optional): show headers at the top of the columns
        clipper (bool, optional): Use clipper (rows must be same height).
        inner_width (int, optional): 
        policy (int, optional): 
        freeze_rows (int, optional): 
        freeze_columns (int, optional): 
        sort_multi (bool, optional): Hold shift when clicking headers to sort on multiple column.
        sort_tristate (bool, optional): Allow no sorting, disable default sorting.
        resizable (bool, optional): Enable resizing columns
        reorderable (bool, optional): Enable reordering columns in header row (need calling TableSetupColumn() + TableHeadersRow() to display headers)
        hideable (bool, optional): Enable hiding/disabling columns in context menu.
        sortable (bool, optional): Enable sorting. Call TableGetSortSpecs() to obtain sort specs. Also see ImGuiTableFlags_SortMulti and ImGuiTableFlags_SortTristate.
        context_menu_in_body (bool, optional): Right-click on columns body/contents will display table context menu. By default it is available in TableHeadersRow().
        row_background (bool, optional): Set each RowBg color with ImGuiCol_TableRowBg or ImGuiCol_TableRowBgAlt (equivalent of calling TableSetBgColor with ImGuiTableBgFlags_RowBg0 on each row manually)
        borders_innerH (bool, optional): Draw horizontal borders between rows.
        borders_outerH (bool, optional): Draw horizontal borders at the top and bottom.
        borders_innerV (bool, optional): Draw vertical borders between columns.
        borders_outerV (bool, optional): Draw vertical borders on the left and right sides.
        no_host_extendX (bool, optional): Make outer width auto-fit to columns, overriding outer_size.x value. Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
        no_host_extendY (bool, optional): Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.
        no_keep_columns_visible (bool, optional): Disable keeping column always minimally visible when ScrollX is off and table gets too small. Not recommended if columns are resizable.
        precise_widths (bool, optional): Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.
        no_clip (bool, optional): Disable clipping rectangle for every individual columns.
        pad_outerX (bool, optional): Default if BordersOuterV is on. Enable outer-most padding. Generally desirable if you have headers.
        no_pad_outerX (bool, optional): Default if BordersOuterV is off. Disable outer-most padding.
        no_pad_innerX (bool, optional): Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off).
        scrollX (bool, optional): Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size. Changes default sizing policy. Because this create a child window, ScrollY is currently generally recommended when using ScrollX.
        scrollY (bool, optional): Enable vertical scrolling.
        no_saved_settings (bool, optional): Never load/save settings in .ini file.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return table(label=label, user_data=user_data, width=width, height=height, indent=indent, callback=callback, show=show, pos=pos, filter_key=filter_key, header_row=header_row, clipper=clipper, inner_width=inner_width, policy=policy, freeze_rows=freeze_rows, freeze_columns=freeze_columns, sort_multi=sort_multi, sort_tristate=sort_tristate, resizable=resizable, reorderable=reorderable, hideable=hideable, sortable=sortable, context_menu_in_body=context_menu_in_body, row_background=row_background, borders_innerH=borders_innerH, borders_outerH=borders_outerH, borders_innerV=borders_innerV, borders_outerV=borders_outerV, no_host_extendX=no_host_extendX, no_host_extendY=no_host_extendY, no_keep_columns_visible=no_keep_columns_visible, precise_widths=precise_widths, no_clip=no_clip, pad_outerX=pad_outerX, no_pad_outerX=no_pad_outerX, no_pad_innerX=no_pad_innerX, scrollX=scrollX, scrollY=scrollY, no_saved_settings=no_saved_settings, **kwargs)

def table_cell(*, label: str =None, user_data: Any =None, height: int =0, show: bool =True, filter_key: str ='', **kwargs) -> Union[int, str]:
    """     Adds a table.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        height (int, optional): Height of the item.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return table_cell(label=label, user_data=user_data, height=height, show=show, filter_key=filter_key, **kwargs)

def table_column(*, label: str =None, user_data: Any =None, width: int =0, show: bool =True, enabled: bool =True, init_width_or_weight: float =0.0, default_hide: bool =False, default_sort: bool =False, width_stretch: bool =False, width_fixed: bool =False, no_resize: bool =False, no_reorder: bool =False, no_hide: bool =False, no_clip: bool =False, no_sort: bool =False, no_sort_ascending: bool =False, no_sort_descending: bool =False, no_header_width: bool =False, prefer_sort_ascending: bool =True, prefer_sort_descending: bool =False, indent_enable: bool =False, indent_disable: bool =False, angled_header: bool =False, no_header_label: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a table column.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        enabled (bool, optional): Turns off functionality of widget and applies the disabled theme.
        init_width_or_weight (float, optional): 
        default_hide (bool, optional): Default as a hidden/disabled column.
        default_sort (bool, optional): Default as a sorting column.
        width_stretch (bool, optional): Column will stretch. Preferable with horizontal scrolling disabled (default if table sizing policy is _SizingStretchSame or _SizingStretchProp).
        width_fixed (bool, optional): Column will not stretch. Preferable with horizontal scrolling enabled (default if table sizing policy is _SizingFixedFit and table is resizable).
        no_resize (bool, optional): Disable manual resizing.
        no_reorder (bool, optional): Disable manual reordering this column, this will also prevent other columns from crossing over this column.
        no_hide (bool, optional): Disable ability to hide/disable this column.
        no_clip (bool, optional): Disable clipping for this column (all NoClip columns will render in a same draw command).
        no_sort (bool, optional): Disable ability to sort on this field (even if ImGuiTableFlags_Sortable is set on the table).
        no_sort_ascending (bool, optional): Disable ability to sort in the ascending direction.
        no_sort_descending (bool, optional): Disable ability to sort in the descending direction.
        no_header_width (bool, optional): Disable header text width contribution to automatic column width.
        prefer_sort_ascending (bool, optional): Make the initial sort direction Ascending when first sorting on this column (default).
        prefer_sort_descending (bool, optional): Make the initial sort direction Descending when first sorting on this column.
        indent_enable (bool, optional): Use current Indent value when entering cell (default for column 0).
        indent_disable (bool, optional): Ignore current Indent value when entering cell (default for columns > 0). Indentation changes _within_ the cell will still be honored.
        angled_header (bool, optional): Set this parameter to True to display the header text for this column in an angled (diagonal) orientation. This will add an additional row to accommodate the angled text.
        no_header_label (bool, optional): Disable horizontal label for this column. Name will still appear in context menu or in angled headers.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return table_column(label=label, user_data=user_data, width=width, show=show, enabled=enabled, init_width_or_weight=init_width_or_weight, default_hide=default_hide, default_sort=default_sort, width_stretch=width_stretch, width_fixed=width_fixed, no_resize=no_resize, no_reorder=no_reorder, no_hide=no_hide, no_clip=no_clip, no_sort=no_sort, no_sort_ascending=no_sort_ascending, no_sort_descending=no_sort_descending, no_header_width=no_header_width, prefer_sort_ascending=prefer_sort_ascending, prefer_sort_descending=prefer_sort_descending, indent_enable=indent_enable, indent_disable=indent_disable, angled_header=angled_header, no_header_label=no_header_label, **kwargs)

def table_row(*, label: str =None, user_data: Any =None, height: int =0, show: bool =True, filter_key: str ='', **kwargs) -> Union[int, str]:
    """     Adds a table row.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        height (int, optional): Height of the item.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return table_row(label=label, user_data=user_data, height=height, show=show, filter_key=filter_key, **kwargs)

def template_registry(*, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Adds a template registry.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return template_registry(label=label, user_data=user_data, **kwargs)

def text(default_value : str ='', *, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, wrap: int =-1, bullet: bool =False, show_label: bool =False, **kwargs) -> Union[int, str]:
    """     Adds text. Text can have an optional label that will display to the right of the text.

    Args:
        default_value (str, optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        wrap (int, optional): Number of pixels from the start of the item until wrapping starts.
        bullet (bool, optional): Places a bullet to the left of the text.
        color (Union[List[int], Tuple[int, ...]], optional): Color of the text (rgba).
        show_label (bool, optional): Displays the label to the right of the text.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgText(dcg_context, value=default_value, label=label, user_data=user_data, indent=indent, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, wrap=wrap, bullet=bullet, show_label=show_label, **kwargs)

def text_point(x : float, y : float, *, label: str =None, user_data: Any =None, show: bool =True, offset: Union[List[float], Tuple[float, ...]] =(0.0, 0.0), vertical: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a label series to a plot. x and y can only have one elements each.

    Args:
        x (float): 
        y (float): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        offset (Union[List[float], Tuple[float, ...]], optional): Offset of the label, in pixels, relative to the coordinates.
        vertical (bool, optional): 
        id (Union[int, str], optional): (deprecated) 
        x_offset (int, optional): (deprecated) Old way to set x offset of the label. Use `offset` argument instead.
        y_offset (int, optional): (deprecated) Old way to set y offset of the label. Use `offset` argument instead.
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'x_offset' in kwargs.keys():
        warnings.warn('x_offset keyword deprecated. See the new offset argument.', DeprecationWarning, 2)

    if 'y_offset' in kwargs.keys():
        warnings.warn('y_offset keyword deprecated. See the new offset argument.', DeprecationWarning, 2)

    #return text_point(x, y, label=label, user_data=user_data, show=show, offset=offset, vertical=vertical, **kwargs)

def texture_registry(*, label: str =None, user_data: Any =None, show: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a dynamic texture.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return texture_registry(label=label, user_data=user_data, show=show, **kwargs)

def theme(*, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Adds a theme.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        id (Union[int, str], optional): (deprecated) 
        default_theme (bool, optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'default_theme' in kwargs.keys():

        warnings.warn('default_theme keyword removed', DeprecationWarning, 2)

        kwargs.pop('default_theme', None)

    return dcg.dcgThemeList(dcg_context, label=label, user_data=user_data, **kwargs)

def theme_color(target : int =0, value : Union[List[int], Tuple[int, ...]] =(0, 0, 0, 255), *, category: int =0, **kwargs) -> Union[int, str]:
    """     Adds a theme color.

    Args:
        target (int, optional): 
        value (Union[List[int], Tuple[int, ...]], optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        category (int, optional): Options include mvThemeCat_Core, mvThemeCat_Plots, mvThemeCat_Nodes.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    # Note: This is ok but not very efficient, and purely for
    # dpg backward compatibility. If you have many elements in your theme,
    # prefer using a single dcgThemeColor
    if category == mvThemeCat_Core:
        theme_element = dcg.dcgThemeColorImGui(dcg_context, **kwargs)
    elif category == mvThemeCat_Plots:
        theme_element = dcg.dcgThemeColorImPlot(dcg_context, **kwargs)
    else:
        theme_element = dcg.dcgThemeColorImNodes(dcg_context, **kwargs)
    theme_element[target] = value
    return theme_element


def theme_component(item_type : int =0, *, label: str =None, user_data: Any =None, enabled_state: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a theme component.

    Args:
        item_type (int, optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        enabled_state (bool, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']
    if enabled_state:
        enabled_state = dcg.theme_enablers.t_enabled_True
    else:
        enabled_state = dcg.theme_enablers.t_enabled_False
    # TODO: convert category

    return dcg.dcgThemeListWithCondition(dcg_context, condition_category=item_type, condition_enabled=enabled_state, label=label, user_data=user_data, **kwargs)

def theme_style(target : int =0, x : float =1.0, y : float =-1.0, *, category: int =0, **kwargs) -> Union[int, str]:
    """     Adds a theme style.

    Args:
        target (int, optional): 
        x (float, optional): 
        y (float, optional): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        category (int, optional): Options include mvThemeCat_Core, mvThemeCat_Plots, mvThemeCat_Nodes.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    # Note: This is ok but not very efficient, and purely for
    # dpg backward compatibility. If you have many elements in your theme,
    # prefer using a single dcgThemeStyle
    if category == mvThemeCat_Core:
        theme_element = dcg.dcgThemeStyleImGui(dcg_context, **kwargs)
    elif category == mvThemeCat_Plots:
        theme_element = dcg.dcgThemeStyleImPlot(dcg_context, **kwargs)
    else:
        theme_element = dcg.dcgThemeStyleImNodes(dcg_context, **kwargs)
    try:
        theme_element[target] = (x, y)
    except Exception:
        theme_element[target] = x

    return theme_element

def time_picker(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', callback: Callable =None, drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_value: dict ={'hour': 14, 'min': 32, 'sec': 23}, hour24: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a time picker.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        callback (Callable, optional): Registers a callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_value (dict, optional): 
        hour24 (bool, optional): Show 24 hour clock instead of 12 hour.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return time_picker(label=label, user_data=user_data, indent=indent, payload_type=payload_type, callback=callback, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, value=default_value, hour24=hour24, **kwargs)

def tooltip(parent : Union[int, str], *, label: str =None, user_data: Any =None, show: bool =True, delay: float =0.0, hide_on_activity: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a tooltip window.

    Args:
        parent (Union[int, str]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        delay (float, optional): Activation delay: time, in seconds, during which the mouse should stay still in order to display the tooltip.  May be zero for instant activation.
        hide_on_activity (bool, optional): Hide the tooltip if the user has moved the mouse.  If False, the tooltip will follow mouse pointer.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #TODO fix return dcg.dcgTooltip(dcg_context, previous_sibling=dcg_context[parent], label=label, user_data=user_data, show=show, delay=delay, hide_on_activity=hide_on_activity, **kwargs)
    return dcg.dcgTooltip(dcg_context, label=label, user_data=user_data, show=show, delay=delay, hide_on_activity=hide_on_activity, **kwargs)

def tree_node(*, label: str =None, user_data: Any =None, indent: int =0, payload_type: str ='$$DPG_PAYLOAD', drag_callback: Callable =None, drop_callback: Callable =None, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], filter_key: str ='', tracked: bool =False, track_offset: float =0.5, default_open: bool =False, open_on_double_click: bool =False, open_on_arrow: bool =False, leaf: bool =False, bullet: bool =False, selectable: bool =False, span_text_width: bool =False, span_full_width: bool =False, **kwargs) -> Union[int, str]:
    """     Adds a tree node to add items to.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drag_callback (Callable, optional): Registers a drag callback for drag and drop.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        default_open (bool, optional): Sets the tree node open by default.
        open_on_double_click (bool, optional): Need double-click to open node.
        open_on_arrow (bool, optional): Only open when clicking on the arrow part.
        leaf (bool, optional): No collapsing, no arrow (use as a convenience for leaf nodes).
        bullet (bool, optional): Display a bullet instead of arrow.
        selectable (bool, optional): Makes the tree selectable.
        span_text_width (bool, optional): Makes hitbox and highlight only cover the label.
        span_full_width (bool, optional): Extend hit box to the left-most and right-most edges (cover the indent area).
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    #return tree_node(label=label, user_data=user_data, indent=indent, payload_type=payload_type, drag_callback=drag_callback, drop_callback=drop_callback, show=show, pos=pos, filter_key=filter_key, tracked=tracked, track_offset=track_offset, default_open=default_open, open_on_double_click=open_on_double_click, open_on_arrow=open_on_arrow, leaf=leaf, bullet=bullet, selectable=selectable, span_text_width=span_text_width, span_full_width=span_full_width, **kwargs)

def value_registry(*, label: str =None, user_data: Any =None, **kwargs) -> Union[int, str]:
    """     Adds a value registry.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.PlaceHolderParent(dcg_context, label=label, user_data=user_data, **kwargs)

def viewport_drawlist(*, label: str =None, user_data: Any =None, show: bool =True, filter_key: str ='', front: bool =True, **kwargs) -> Union[int, str]:
    """     A container that is used to present draw items or layers directly to the viewport. By default this will draw to the back of the viewport. Layers and draw items should be added to this widget as children.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        show (bool, optional): Attempt to render widget.
        filter_key (str, optional): Used by filter widget.
        front (bool, optional): Draws to the front of the view port instead of the back.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgViewportDrawList(dcg_context, parent=dcg_context.viewport, label=label, user_data=user_data, show=show, filter_key=filter_key, front=front, **kwargs)

def viewport_menu_bar(*, label: str =None, user_data: Any =None, indent: int =0, show: bool =True, **kwargs) -> Union[int, str]:
    """     Adds a menubar to the viewport.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return menu_bar(parent=dcg_context.viewport, label=label, user_data=user_data, indent=indent, show=show, **kwargs)

def window(*, label: str =None, user_data: Any =None, width: int =0, height: int =0, show: bool =True, pos: Union[List[int], Tuple[int, ...]] =[], min_size: Union[List[int], Tuple[int, ...]] =[100, 100], max_size: Union[List[int], Tuple[int, ...]] =[30000, 30000], menubar: bool =False, collapsed: bool =False, autosize: bool =False, no_resize: bool =False, unsaved_document: bool =False, no_title_bar: bool =False, no_move: bool =False, no_scrollbar: bool =False, no_collapse: bool =False, horizontal_scrollbar: bool =False, no_focus_on_appearing: bool =False, no_bring_to_front_on_focus: bool =False, no_close: bool =False, no_background: bool =False, modal: bool =False, popup: bool =False, no_saved_settings: bool =False, no_open_over_existing_popup: bool =True, no_scroll_with_mouse: bool =False, on_close: Callable =None, **kwargs) -> Union[int, str]:
    """     Creates a new window for following items to be added to.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int, ...]], optional): Places the item relative to window coordinates, [0,0] is top left.
        min_size (Union[List[int], Tuple[int, ...]], optional): Minimum window size.
        max_size (Union[List[int], Tuple[int, ...]], optional): Maximum window size.
        menubar (bool, optional): Shows or hides the menubar.
        collapsed (bool, optional): Collapse the window.
        autosize (bool, optional): Autosized the window to fit it's items.
        no_resize (bool, optional): Allows for the window size to be changed or fixed.
        unsaved_document (bool, optional): Show a special marker if the document is not saved.
        no_title_bar (bool, optional): Title name for the title bar of the window.
        no_move (bool, optional): Allows for the window's position to be changed or fixed.
        no_scrollbar (bool, optional):  Disable scrollbars. (window can still scroll with mouse or programmatically)
        no_collapse (bool, optional): Disable user collapsing window by double-clicking on it.
        horizontal_scrollbar (bool, optional): Allow horizontal scrollbar to appear. (off by default)
        no_focus_on_appearing (bool, optional): Disable taking focus when transitioning from hidden to visible state.
        no_bring_to_front_on_focus (bool, optional): Disable bringing window to front when taking focus. (e.g. clicking on it or programmatically giving it focus)
        no_close (bool, optional): Disable user closing the window by removing the close button.
        no_background (bool, optional): Sets Background and border alpha to transparent.
        modal (bool, optional): Fills area behind window according to the theme and disables user ability to interact with anything except the window.
        popup (bool, optional): Fills area behind window according to the theme, removes title bar, collapse and close. Window can be closed by selecting area in the background behind the window.
        no_saved_settings (bool, optional): Never load/save settings in .ini file.
        no_open_over_existing_popup (bool, optional): Don't open if there's already a popup
        no_scroll_with_mouse (bool, optional): Disable user vertically scrolling with mouse wheel.
        on_close (Callable, optional): Callback ran when window is closed.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgWindow(dcg_context, parent=dcg_context.viewport, label=label, user_data=user_data, width=width, height=height, show=show, pos=pos, min_size=min_size, max_size=max_size, menubar=menubar, collapsed=collapsed, autosize=autosize, no_resize=no_resize, unsaved_document=unsaved_document, no_title_bar=no_title_bar, no_move=no_move, no_scrollbar=no_scrollbar, no_collapse=no_collapse, horizontal_scrollbar=horizontal_scrollbar, no_focus_on_appearing=no_focus_on_appearing, no_bring_to_front_on_focus=no_bring_to_front_on_focus, no_close=no_close, no_background=no_background, modal=modal, popup=popup, no_saved_settings=no_saved_settings, no_open_over_existing_popup=no_open_over_existing_popup, no_scroll_with_mouse=no_scroll_with_mouse, on_close=on_close, **kwargs)

def apply_transform(item : Union[int, str], transform : Any, **kwargs) -> None:
    """     New in 1.1. Applies a transformation matrix to a layer.

    Args:
        item (Union[int, str]): Drawing node to apply transform to.
        transform (Any): Transformation matrix.
    Returns:
        None
    """

    #return internal_dpg.apply_transform(item, transform, **kwargs)

def bind_colormap(item : Union[int, str], source : Union[int, str], **kwargs) -> None:
    """     Sets the color map for widgets that accept it.

    Args:
        item (Union[int, str]): item that the color map will be applied to
        source (Union[int, str]): The colormap tag. This should come from a colormap that was added to a colormap registry.  Built in color maps are accessible through their corresponding constants mvPlotColormap_Twilight, mvPlotColormap_***
    Returns:
        None
    """

    #return internal_dpg.bind_colormap(item, source, **kwargs)

def bind_font(font : Union[int, str], **kwargs) -> Union[int, str]:
    """     Binds a global font.

    Args:
        font (Union[int, str]): 
    Returns:
        Union[int, str]
    """

    #dcg_context.viewport.font = dcg_context[font]

def bind_item_font(item : Union[int, str], font : Union[int, str], **kwargs) -> None:
    """     Sets an item's font.

    Args:
        item (Union[int, str]): 
        font (Union[int, str]): 
    Returns:
        None
    """

    #dcg_context[item].font = dcg_context[font]

def bind_item_handler_registry(item : Union[int, str], handler_registry : Union[int, str], **kwargs) -> None:
    """     Binds an item handler registry to an item.

    Args:
        item (Union[int, str]): 
        handler_registry (Union[int, str]): 
    Returns:
        None
    """

    dcg_context[item].handler = dcg_context[handler_registry]

def bind_item_theme(item : Union[int, str], theme : Union[int, str], **kwargs) -> None:
    """     Binds a theme to an item.

    Args:
        item (Union[int, str]): 
        theme (Union[int, str]): 
    Returns:
        None
    """

    dcg_context[item].theme = dcg_context[theme]

def bind_theme(theme : Union[int, str], **kwargs) -> None:
    """     Binds a global theme.

    Args:
        theme (Union[int, str]): 
    Returns:
        None
    """
    if isinstance(theme, int) and theme == 0:
        dcg_context.viewport.theme = None
    else:
        dcg_context.viewport.theme = dcg_context[theme]

def capture_next_item(callback : Callable, *, user_data: Any =None, **kwargs) -> None:
    """     Captures the next item.

    Args:
        callback (Callable): 
        user_data (Any, optional): New in 1.3. Optional user data to send to the callback
    Returns:
        None
    """

    #return internal_dpg.capture_next_item(callback, user_data=user_data, **kwargs)

def clear_selected_links(node_editor : Union[int, str], **kwargs) -> None:
    """     Clears a node editor's selected links.

    Args:
        node_editor (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.clear_selected_links(node_editor, **kwargs)

def clear_selected_nodes(node_editor : Union[int, str], **kwargs) -> None:
    """     Clears a node editor's selected nodes.

    Args:
        node_editor (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.clear_selected_nodes(node_editor, **kwargs)

def create_context(**kwargs) -> None:
    global dcg_context
    """     Creates the Dear PyGui context.

    Args:
    Returns:
        None
    """
    dcg_context = dcg.dcgContext(**kwargs)

    return dcg_context

def create_fps_matrix(eye : Union[List[float], Tuple[float, ...]], pitch : float, yaw : float, **kwargs) -> Any:
    """     New in 1.1. Create a 'first person shooter' matrix.

    Args:
        eye (Union[List[float], Tuple[float, ...]]): eye position
        pitch (float): pitch (in radians)
        yaw (float): yaw (in radians)
    Returns:
        Any
    """

    #return internal_dpg.create_fps_matrix(eye, pitch, yaw, **kwargs)

def create_lookat_matrix(eye : Union[List[float], Tuple[float, ...]], target : Union[List[float], Tuple[float, ...]], up : Union[List[float], Tuple[float, ...]], **kwargs) -> Any:
    """     New in 1.1. Creates a 'Look at matrix'.

    Args:
        eye (Union[List[float], Tuple[float, ...]]): eye position
        target (Union[List[float], Tuple[float, ...]]): target position
        up (Union[List[float], Tuple[float, ...]]): up vector
    Returns:
        Any
    """

    #return internal_dpg.create_lookat_matrix(eye, target, up, **kwargs)

def create_orthographic_matrix(left : float, right : float, bottom : float, top : float, zNear : float, zFar : float, **kwargs) -> Any:
    """     New in 1.1. Creates an orthographic matrix.

    Args:
        left (float): left plane
        right (float): right plane
        bottom (float): bottom plane
        top (float): top plane
        zNear (float): Near clipping plane.
        zFar (float): Far clipping plane.
    Returns:
        Any
    """

    #return internal_dpg.create_orthographic_matrix(left, right, bottom, top, zNear, zFar, **kwargs)

def create_perspective_matrix(fov : float, aspect : float, zNear : float, zFar : float, **kwargs) -> Any:
    """     New in 1.1. Creates a perspective matrix.

    Args:
        fov (float): Field of view (in radians)
        aspect (float): Aspect ratio (width/height)
        zNear (float): Near clipping plane.
        zFar (float): Far clipping plane.
    Returns:
        Any
    """

    #return internal_dpg.create_perspective_matrix(fov, aspect, zNear, zFar, **kwargs)

def create_rotation_matrix(angle : float, axis : Union[List[float], Tuple[float, ...]], **kwargs) -> Any:
    """     New in 1.1. Applies a transformation matrix to a layer.

    Args:
        angle (float): angle to rotate
        axis (Union[List[float], Tuple[float, ...]]): axis to rotate around
    Returns:
        Any
    """

    #return internal_dpg.create_rotation_matrix(angle, axis, **kwargs)

def create_scale_matrix(scales : Union[List[float], Tuple[float, ...]], **kwargs) -> Any:
    """     New in 1.1. Applies a transformation matrix to a layer.

    Args:
        scales (Union[List[float], Tuple[float, ...]]): scale values per axis
    Returns:
        Any
    """

    #return internal_dpg.create_scale_matrix(scales, **kwargs)

def create_translation_matrix(translation : Union[List[float], Tuple[float, ...]], **kwargs) -> Any:
    """     New in 1.1. Creates a translation matrix.

    Args:
        translation (Union[List[float], Tuple[float, ...]]): translation vector
    Returns:
        Any
    """

    #return internal_dpg.create_translation_matrix(translation, **kwargs)

def create_viewport(*, title: str ='Dear PyGui', small_icon: str ='', large_icon: str ='', width: int =1280, height: int =800, x_pos: int =100, y_pos: int =100, min_width: int =250, max_width: int =10000, min_height: int =250, max_height: int =10000, resizable: bool =True, vsync: bool =True, always_on_top: bool =False, decorated: bool =True, clear_color: Union[List[float], Tuple[float, ...]] =(0, 0, 0, 255), disable_close: bool =False, **kwargs) -> None:
    """     Creates a viewport. Viewports are required.

    Args:
        title (str, optional): Sets the title of the viewport.
        small_icon (str, optional): Sets the small icon that is found in the viewport's decorator bar. Must be ***.ico on windows and either ***.ico or ***.png on mac.
        large_icon (str, optional): Sets the large icon that is found in the task bar while the app is running. Must be ***.ico on windows and either ***.ico or ***.png on mac.
        width (int, optional): Sets the width of the drawable space on the viewport. Does not inclue the border.
        height (int, optional): Sets the height of the drawable space on the viewport. Does not inclue the border or decorator bar.
        x_pos (int, optional): Sets x position the viewport will be drawn in screen coordinates.
        y_pos (int, optional): Sets y position the viewport will be drawn in screen coordinates.
        min_width (int, optional): Applies a minimuim limit to the width of the viewport.
        max_width (int, optional): Applies a maximum limit to the width of the viewport.
        min_height (int, optional): Applies a minimuim limit to the height of the viewport.
        max_height (int, optional): Applies a maximum limit to the height of the viewport.
        resizable (bool, optional): Enables and Disables user ability to resize the viewport.
        vsync (bool, optional): Enables and Disables the renderloop vsync limit. vsync frame value is set by refresh rate of display.
        always_on_top (bool, optional): Forces the viewport to always be drawn ontop of all other viewports.
        decorated (bool, optional): Enabled and disabled the decorator bar at the top of the viewport.
        clear_color (Union[List[float], Tuple[float, ...]], optional): Sets the color of the back of the viewport.
        disable_close (bool, optional): Disables the viewport close button. can be used with set_exit_callback
    Returns:
        None
    """
    dcg_context.initialize_viewport(title=title, small_icon=small_icon, large_icon=large_icon, width=width, height=height, x_pos=x_pos, y_pos=y_pos, min_width=min_width, max_width=max_width, min_height=min_height, max_height=max_height, resizable=resizable, vsync=vsync, always_on_top=always_on_top, decorated=decorated, clear_color=clear_color, disable_close=disable_close, **kwargs)

def delete_item(item : Union[int, str], *, children_only: bool =False, slot: int =-1, **kwargs) -> None:
    """     Deletes an item..

    Args:
        item (Union[int, str]): 
        children_only (bool, optional): 
        slot (int, optional): 
    Returns:
        None
    """

    if not(children_only):
        dcg_context[item].delete_item()
    else:
        for child in filter_slot(dcg_context[item].children, slot):
            child.delete_item()

def destroy_context(**kwargs) -> None:
    """     Destroys the Dear PyGui context.

    Args:
    Returns:
        None
    """
    global dcg_context

    dcg_context = None

def does_alias_exist(alias : str, **kwargs) -> bool:
    """     Checks if an alias exist.

    Args:
        alias (str): 
    Returns:
        bool
    """

    try:
        item = dcg_context[alias]
        return True
    except Exception:
        return False

def does_item_exist(item : Union[int, str], **kwargs) -> bool:
    """     Checks if an item exist..

    Args:
        item (Union[int, str]): 
    Returns:
        bool
    """

    try:
        item = dcg_context[item]
        return True
    except Exception:
        return False

def draw_arrow(p1 : Union[List[float], Tuple[float, ...]], p2 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, thickness: float =1.0, size: int =4, **kwargs) -> Union[int, str]:
    """     Adds an arrow.

    Args:
        p1 (Union[List[float], Tuple[float, ...]]): Arrow tip.
        p2 (Union[List[float], Tuple[float, ...]]): Arrow tail.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        size (int, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawArrow(dcg_context, p1, p2, label=label, user_data=user_data, show=show, color=color, thickness=thickness, size=size, **kwargs)

def draw_bezier_cubic(p1 : Union[List[float], Tuple[float, ...]], p2 : Union[List[float], Tuple[float, ...]], p3 : Union[List[float], Tuple[float, ...]], p4 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, thickness: float =1.0, segments: int =0, **kwargs) -> Union[int, str]:
    """     Adds a cubic bezier curve.

    Args:
        p1 (Union[List[float], Tuple[float, ...]]): First point in curve.
        p2 (Union[List[float], Tuple[float, ...]]): Second point in curve.
        p3 (Union[List[float], Tuple[float, ...]]): Third point in curve.
        p4 (Union[List[float], Tuple[float, ...]]): Fourth point in curve.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        segments (int, optional): Number of segments to approximate bezier curve.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawBezierCubic(dcg_context, p1, p2, p3, p4, label=label, user_data=user_data, show=show, color=color, thickness=thickness, segments=segments, **kwargs)

def draw_bezier_quadratic(p1 : Union[List[float], Tuple[float, ...]], p2 : Union[List[float], Tuple[float, ...]], p3 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, thickness: float =1.0, segments: int =0, **kwargs) -> Union[int, str]:
    """     Adds a quadratic bezier curve.

    Args:
        p1 (Union[List[float], Tuple[float, ...]]): First point in curve.
        p2 (Union[List[float], Tuple[float, ...]]): Second point in curve.
        p3 (Union[List[float], Tuple[float, ...]]): Third point in curve.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        segments (int, optional): Number of segments to approximate bezier curve.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawBezierQuadratic(dcg_context, p1, p2, p3, label=label, user_data=user_data, show=show, color=color, thickness=thickness, segments=segments, **kwargs)

def draw_circle(center : Union[List[float], Tuple[float, ...]], radius : float, *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, fill: Union[int, List[int], Tuple[int, ...]] =0, thickness: float =1.0, segments: int =0, **kwargs) -> Union[int, str]:
    """     Adds a circle

    Args:
        center (Union[List[float], Tuple[float, ...]]): 
        radius (float): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        fill (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        segments (int, optional): Number of segments to approximate circle.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawCircle(dcg_context, center, radius, label=label, user_data=user_data, show=show, color=color, fill=fill, thickness=thickness, segments=segments, **kwargs)

def draw_ellipse(pmin : Union[List[float], Tuple[float, ...]], pmax : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, fill: Union[int, List[int], Tuple[int, ...]] =0, thickness: float =1.0, segments: int =32, **kwargs) -> Union[int, str]:
    """     Adds an ellipse.

    Args:
        pmin (Union[List[float], Tuple[float, ...]]): Min point of bounding rectangle.
        pmax (Union[List[float], Tuple[float, ...]]): Max point of bounding rectangle.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        fill (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        segments (int, optional): Number of segments to approximate bezier curve.
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawEllipse(dcg_context, pmin, pmax, label=label, user_data=user_data, show=show, color=color, fill=fill, thickness=thickness, segments=segments, **kwargs)

def draw_image(texture_tag : Union[int, str], pmin : Union[List[float], Tuple[float, ...]], pmax : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, uv_min: Union[List[float], Tuple[float, ...]] =(0.0, 0.0), uv_max: Union[List[float], Tuple[float, ...]] =(1.0, 1.0), color: Union[int, List[int], Tuple[int, ...]] =-1, **kwargs) -> Union[int, str]:
    """     Adds an image (for a drawing).

    Args:
        texture_tag (Union[int, str]): 
        pmin (Union[List[float], Tuple[float, ...]]): Point of to start drawing texture.
        pmax (Union[List[float], Tuple[float, ...]]): Point to complete drawing texture.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        uv_min (Union[List[float], Tuple[float, ...]], optional): Normalized coordinates on texture that will be drawn.
        uv_max (Union[List[float], Tuple[float, ...]], optional): Normalized coordinates on texture that will be drawn.
        color (Union[List[int], Tuple[int, ...]], optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    texture = dcg_context[texture_tag]
    return dcg.dcgDrawImage(dcg_context, texture, pmin, pmax, label=label, user_data=user_data, show=show, uv_min=uv_min, uv_max=uv_max, color=color, **kwargs)

def draw_image_quad(texture_tag : Union[int, str], p1 : Union[List[float], Tuple[float, ...]], p2 : Union[List[float], Tuple[float, ...]], p3 : Union[List[float], Tuple[float, ...]], p4 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, uv1: Union[List[float], Tuple[float, ...]] =(0.0, 0.0), uv2: Union[List[float], Tuple[float, ...]] =(1.0, 0.0), uv3: Union[List[float], Tuple[float, ...]] =(1.0, 1.0), uv4: Union[List[float], Tuple[float, ...]] =(0.0, 1.0), color: Union[int, List[int], Tuple[int, ...]] =-1, **kwargs) -> Union[int, str]:
    """     Adds an image (for a drawing).

    Args:
        texture_tag (Union[int, str]): 
        p1 (Union[List[float], Tuple[float, ...]]): 
        p2 (Union[List[float], Tuple[float, ...]]): 
        p3 (Union[List[float], Tuple[float, ...]]): 
        p4 (Union[List[float], Tuple[float, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        uv1 (Union[List[float], Tuple[float, ...]], optional): Normalized coordinates on texture that will be drawn.
        uv2 (Union[List[float], Tuple[float, ...]], optional): Normalized coordinates on texture that will be drawn.
        uv3 (Union[List[float], Tuple[float, ...]], optional): Normalized coordinates on texture that will be drawn.
        uv4 (Union[List[float], Tuple[float, ...]], optional): Normalized coordinates on texture that will be drawn.
        color (Union[List[int], Tuple[int, ...]], optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    texture = dcg_context[texture_tag]
    return dcg.dcgDrawImageQuad(dcg_context, texture, p1, p2, p3, p4, label=label, user_data=user_data, show=show, uv1=uv1, uv2=uv2, uv3=uv3, uv4=uv4, color=color, **kwargs)

def draw_line(p1 : Union[List[float], Tuple[float, ...]], p2 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, thickness: float =1.0, **kwargs) -> Union[int, str]:
    """     Adds a line.

    Args:
        p1 (Union[List[float], Tuple[float, ...]]): Start of line.
        p2 (Union[List[float], Tuple[float, ...]]): End of line.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawLine(dcg_context, p1, p2, label=label, user_data=user_data, show=show, color=color, thickness=thickness, **kwargs)

def draw_polygon(points : List[List[float]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, fill: Union[int, List[int], Tuple[int, ...]] =0, thickness: float =1.0, **kwargs) -> Union[int, str]:
    """     Adds a polygon.

    Args:
        points (List[List[float]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        fill (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawPolygon(dcg_context, points, label=label, user_data=user_data, show=show, color=color, fill=fill, thickness=thickness, **kwargs)

def draw_polyline(points : List[List[float]], *, label: str =None, user_data: Any =None, show: bool =True, closed: bool =False, color: Union[int, List[int], Tuple[int, ...]] =-1, thickness: float =1.0, **kwargs) -> Union[int, str]:
    """     Adds a polyline.

    Args:
        points (List[List[float]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        closed (bool, optional): Will close the polyline by returning to the first point.
        color (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawPolyline(dcg_context, points, label=label, user_data=user_data, show=show, closed=closed, color=color, thickness=thickness, **kwargs)

def draw_quad(p1 : Union[List[float], Tuple[float, ...]], p2 : Union[List[float], Tuple[float, ...]], p3 : Union[List[float], Tuple[float, ...]], p4 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, fill: Union[int, List[int], Tuple[int, ...]] =0, thickness: float =1.0, **kwargs) -> Union[int, str]:
    """     Adds a quad.

    Args:
        p1 (Union[List[float], Tuple[float, ...]]): 
        p2 (Union[List[float], Tuple[float, ...]]): 
        p3 (Union[List[float], Tuple[float, ...]]): 
        p4 (Union[List[float], Tuple[float, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        fill (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawQuad(dcg_context, p1, p2, p3, p4, label=label, user_data=user_data, show=show, color=color, fill=fill, thickness=thickness, **kwargs)

def draw_rectangle(pmin : Union[List[float], Tuple[float, ...]], pmax : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, fill: Union[int, List[int], Tuple[int, ...]] =0, multicolor: bool =False, rounding: float =0.0, thickness: float =1.0, corner_colors: Any =None, **kwargs) -> Union[int, str]:
    """     Adds a rectangle.

    Args:
        pmin (Union[List[float], Tuple[float, ...]]): Min point of bounding rectangle.
        pmax (Union[List[float], Tuple[float, ...]]): Max point of bounding rectangle.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        fill (Union[List[int], Tuple[int, ...]], optional): 
        multicolor (bool, optional): 
        rounding (float, optional): Number of pixels of the radius that will round the corners of the rectangle. Note: doesn't work with multicolor
        thickness (float, optional): 
        corner_colors (Any, optional): Corner colors in a list, starting with upper-left and going clockwise: (upper-left, upper-right, bottom-right, bottom-left). 'multicolor' must be set to 'True'.
        id (Union[int, str], optional): (deprecated) 
        color_upper_left (Union[List[int], Tuple[int, ...]], optional): (deprecated) Use corner_colors instead
        color_upper_right (Union[List[int], Tuple[int, ...]], optional): (deprecated) Use corner_colors instead
        color_bottom_right (Union[List[int], Tuple[int, ...]], optional): (deprecated) Use corner_colors instead
        color_bottom_left (Union[List[int], Tuple[int, ...]], optional): (deprecated) Use corner_colors instead
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    if 'color_upper_left' in kwargs.keys():
        warnings.warn('color_upper_left keyword deprecated. Use corner_colors instead.', DeprecationWarning, 2)

    if 'color_upper_right' in kwargs.keys():
        warnings.warn('color_upper_right keyword deprecated. Use corner_colors instead.', DeprecationWarning, 2)

    if 'color_bottom_right' in kwargs.keys():
        warnings.warn('color_bottom_right keyword deprecated. Use corner_colors instead.', DeprecationWarning, 2)

    if 'color_bottom_left' in kwargs.keys():
        warnings.warn('color_bottom_left keyword deprecated. Use corner_colors instead.', DeprecationWarning, 2)

    return dcg.dcgDrawRect(dcg_context, pmin, pmax, label=label, user_data=user_data, show=show, color=color, fill=fill, multicolor=multicolor, rounding=rounding, thickness=thickness, corner_colors=corner_colors, **kwargs)

def draw_text(pos : Union[List[float], Tuple[float, ...]], text : str, *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, size: float =10.0, **kwargs) -> Union[int, str]:
    """     Adds text (drawlist).

    Args:
        pos (Union[List[float], Tuple[float, ...]]): Top left point of bounding text rectangle.
        text (str): Text to draw.
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        size (float, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawText(dcg_context, pos, text, label=label, user_data=user_data, show=show, color=color, size=size, **kwargs)

def draw_triangle(p1 : Union[List[float], Tuple[float, ...]], p2 : Union[List[float], Tuple[float, ...]], p3 : Union[List[float], Tuple[float, ...]], *, label: str =None, user_data: Any =None, show: bool =True, color: Union[int, List[int], Tuple[int, ...]] =-1, fill: Union[int, List[int], Tuple[int, ...]] =0, thickness: float =1.0, **kwargs) -> Union[int, str]:
    """     Adds a triangle.

    Args:
        p1 (Union[List[float], Tuple[float, ...]]): 
        p2 (Union[List[float], Tuple[float, ...]]): 
        p3 (Union[List[float], Tuple[float, ...]]): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        color (Union[List[int], Tuple[int, ...]], optional): 
        fill (Union[List[int], Tuple[int, ...]], optional): 
        thickness (float, optional): 
        id (Union[int, str], optional): (deprecated) 
    Returns:
        Union[int, str]
    """

    if 'id' in kwargs.keys():
        warnings.warn('id keyword renamed to tag', DeprecationWarning, 2)
        tag=kwargs['id']

    return dcg.dcgDrawTriangle(dcg_context, p1, p2, p3, label=label, user_data=user_data, show=show, color=color, fill=fill, thickness=thickness, **kwargs)

def empty_container_stack(**kwargs) -> None:
    """     Emptyes the container stack.

    Args:
    Returns:
        None
    """

    #return internal_dpg.empty_container_stack(**kwargs)

def fit_axis_data(axis : Union[int, str], **kwargs) -> None:
    """     Sets the axis boundaries max/min in the data series currently on the plot.

    Args:
        axis (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.fit_axis_data(axis, **kwargs)

def focus_item(item : Union[int, str], **kwargs) -> None:
    """     Focuses an item.

    Args:
        item (Union[int, str]): 
    Returns:
        None
    """

    dcg_context[item].focused = True

def generate_uuid(**kwargs) -> Union[int, str]:
    """     Generate a new UUID.

    Args:
    Returns:
        Union[int, str]
    """

    #return internal_dpg.generate_uuid(**kwargs)

def get_active_window(**kwargs) -> Union[int, str]:
    """     Returns the active window.

    Args:
    Returns:
        Union[int, str]
    """

    #return internal_dpg.get_active_window(**kwargs)

def get_alias_id(alias : str, **kwargs) -> Union[int, str]:
    """     Returns the ID associated with an alias.

    Args:
        alias (str): 
    Returns:
        Union[int, str]
    """

    return dcg_context[alias].uuid

def get_aliases(**kwargs) -> Union[List[str], Tuple[str, ...]]:
    """     Returns all aliases.

    Args:
    Returns:
        Union[List[str], Tuple[str, ...]]
    """

    results = []
    for item in get_all_items():
        tag = item.tag
        if tag is None:
            continue
        results.append(tag)
    return results

def get_children_recursive(item):
    result = [item]
    children = item.children
    result += children
    for c in children:
        result += get_children_recursive(c)
    return result

def get_all_items(**kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns all items.

    Args:
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    return get_children_recursive(dcg_context.viewport)

def get_app_configuration(**kwargs) -> dict:
    """     Returns app configuration.

    Args:
    Returns:
        dict
    """

    #return internal_dpg.get_app_configuration(**kwargs)

def get_axis_limits(axis : Union[int, str], **kwargs) -> Union[List[float], Tuple[float, ...]]:
    """     Get the specified axis limits.

    Args:
        axis (Union[int, str]): 
    Returns:
        Union[List[float], Tuple[float, ...]]
    """

    #return internal_dpg.get_axis_limits(axis, **kwargs)

def get_callback_queue(**kwargs) -> Any:
    """     New in 1.2. Returns and clears callback queue.

    Args:
    Returns:
        Any
    """

    #return internal_dpg.get_callback_queue(**kwargs)

def get_clipboard_text(**kwargs) -> str:
    """     New in 1.3. Gets the clipboard text.

    Args:
    Returns:
        str
    """

    #return internal_dpg.get_clipboard_text(**kwargs)

def get_colormap_color(colormap : Union[int, str], index : int, **kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns a color from a colormap given an index >= 0. (ex. 0 will be the first color in the color list of the color map) Modulo will be performed against the number of items in the color list.

    Args:
        colormap (Union[int, str]): The colormap tag. This should come from a colormap that was added to a colormap registry. Built in color maps are accessible through their corresponding constants mvPlotColormap_Twilight, mvPlotColormap_***
        index (int): Desired position of the color in the colors list value of the colormap being quiered 
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    #return internal_dpg.get_colormap_color(colormap, index, **kwargs)

def get_delta_time(**kwargs) -> float:
    """     Returns time since last frame.

    Args:
    Returns:
        float
    """

    #return internal_dpg.get_delta_time(**kwargs)

def get_drawing_mouse_pos(**kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns mouse position in drawing.

    Args:
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    #return internal_dpg.get_drawing_mouse_pos(**kwargs)

def get_file_dialog_info(file_dialog : Union[int, str], **kwargs) -> dict:
    """     Returns information related to the file dialog. Typically used while the file dialog is in use to query data about the state or info related to the file dialog.

    Args:
        file_dialog (Union[int, str]): 
    Returns:
        dict
    """

    #return internal_dpg.get_file_dialog_info(file_dialog, **kwargs)

def get_focused_item(**kwargs) -> Union[int, str]:
    """     Returns the item currently having focus.

    Args:
    Returns:
        Union[int, str]
    """

    #return internal_dpg.get_focused_item(**kwargs)

def get_frame_count(**kwargs) -> int:
    """     Returns frame count.

    Args:
    Returns:
        int
    """

    #return internal_dpg.get_frame_count(**kwargs)

def get_frame_rate(**kwargs) -> float:
    """     Returns the average frame rate across 120 frames.

    Args:
    Returns:
        float
    """

    #return internal_dpg.get_frame_rate(**kwargs)

def get_global_font_scale(**kwargs) -> float:
    """     Returns global font scale.

    Args:
    Returns:
        float
    """

    #return internal_dpg.get_global_font_scale(**kwargs)

def get_item_alias(item : Union[int, str], **kwargs) -> str:
    """     Returns an item's alias.

    Args:
        item (Union[int, str]): 
    Returns:
        str
    """

    return dcg_context[item].tag


item_configuration_keys = set([
    "filter_key",
    "payload_type",
    "label",
    "use_internal_label",
    "source",
    "show",
    "enabled",
    "tracked",
    "width",
    "track_offset",
    "height",
    "indent",
    "callback",
    "drop_callback",
    "drag_callback",
    "user_data"
]) # + specific item keys

item_info_keys = set([
    "children",
    "type",
    "target",
    "parent",
    "theme",
    "handlers",
    "font",
    "container"
    "hover_handler_applicable",
    "active_handler_applicable",
    "focus_handler_applicable",
    "clicked_handler_applicable",
    "visible_handler_applicable",
    "edited_handler_applicable",
    "activated_handler_applicable",
    "deactivated_handler_applicable",
    "toggled_open_handler_applicable",
    "resized_handler_applicable"
])

item_state_keys = set([
    "ok",
    "pos",
    "hovered",
    "active",
    "focused",
    "clicked",
    "left_clicked",
    "right_clicked",
    "middle_clicked",
    "visible",
    "edited",
    "activated",
    "deactivated",
    "deactivated_after_edit",
    "toggled_open",
    "rect_min",
    "rect_max",
    "rect_size",
    "resized",
    "content_region_avail"
])

item_info_and_state_keys = item_info_keys.union(item_state_keys)


def get_item_configuration(item : Union[int, str], **kwargs) -> dict:
    """     Returns an item's configuration.

    Args:
        item (Union[int, str]): 
    Returns:
        dict
    """
    item = dcg_context[item]
    item_attributes = dir(item)
    configuration_attributes = item_attributes.difference(item_info_and_state_keys)
    if isinstance(item, dcg.baseTheme):
        # Theme uses attributes for its values
        # Keep only the generic ones
        configuration_attributes = configuration_attributes.intersection(item_configuration_keys)
    result = {}
    for attribute in configuration_attributes:
        try:
            result[attribute] = getattr(item, attribute)
        except AttributeError:
            # Some attributes are currently visible but unreachable
            pass

    return result

def get_item_info(item : Union[int, str], **kwargs) -> dict:
    """     Returns an item's information.

    Args:
        item (Union[int, str]): 
    Returns:
        dict
    """
    item = dcg_context[item]
    result = {
        "children": item.children,
        "parent": item.parent
    }
    if hasattr(item, "theme"):
        result["theme"] = item.theme
    if hasattr(item, "handlers"):
        result["handlers"] = item.handlers
    if hasattr(item, "font"):
        result["font"] = item.font
    # Ignoring the other fields, which seem
    # mainly useful for debugging during developpement
    return result

def get_item_state(item : Union[int, str], **kwargs) -> dict:
    """     Returns an item's state.

    Args:
        item (Union[int, str]): 
    Returns:
        dict
    """
    item = dcg_context[item]
    if isinstance(item, dcg.uiItem):
        return item.output_current_item_state()
    return {"ok": True, "visible": True, "pos": (0, 0)}

def get_item_types(**kwargs) -> dict:
    """     Returns an item types.

    Args:
    Returns:
        dict
    """

    raise ValueError("Item types are different in DCG and DPG")

def get_mouse_drag_delta(**kwargs) -> float:
    """     Returns mouse drag delta.

    Args:
    Returns:
        float
    """

    #return internal_dpg.get_mouse_drag_delta(**kwargs)

def get_mouse_pos(*, local: bool =True, **kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns mouse position.

    Args:
        local (bool, optional): 
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    #return internal_dpg.get_mouse_pos(local=local, **kwargs)

def get_platform(**kwargs) -> int:
    """     New in 1.6. Returns platform constant.

    Args:
    Returns:
        int
    """

    #return internal_dpg.get_platform(**kwargs)

def get_plot_mouse_pos(**kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns mouse position in plot.

    Args:
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    #return internal_dpg.get_plot_mouse_pos(**kwargs)

def get_plot_query_rects(plot : Union[int, str], **kwargs) -> List[List[float]]:
    """     Returns the query rects of the plot. Returns an array of array containing the top-left coordinates and bottom-right coordinates of the plot area.

    Args:
        plot (Union[int, str]): 
    Returns:
        List[List[float]]
    """

    #return internal_dpg.get_plot_query_rects(plot, **kwargs)

def get_selected_links(node_editor : Union[int, str], **kwargs) -> List[List[str]]:
    """     Returns a node editor's selected links.

    Args:
        node_editor (Union[int, str]): 
    Returns:
        List[List[str]]
    """

    #return internal_dpg.get_selected_links(node_editor, **kwargs)

def get_selected_nodes(node_editor : Union[int, str], **kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns a node editor's selected nodes.

    Args:
        node_editor (Union[int, str]): 
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    #return internal_dpg.get_selected_nodes(node_editor, **kwargs)

def get_text_size(text : str, *, wrap_width: float =-1.0, font: Union[int, str] =0, **kwargs) -> Union[List[float], Tuple[float, ...]]:
    """     Returns width/height of text with specified font (must occur after 1st frame).

    Args:
        text (str): 
        wrap_width (float, optional): Wrap width to use (-1.0 turns wrap off).
        font (Union[int, str], optional): Font to use.
    Returns:
        Union[List[float], Tuple[float, ...]]
    """

    #return internal_dpg.get_text_size(text, wrap_width=wrap_width, font=font, **kwargs)

def get_total_time(**kwargs) -> float:
    """     Returns total time since Dear PyGui has started.

    Args:
    Returns:
        float
    """

    #return internal_dpg.get_total_time(**kwargs)

def get_value(item : Union[int, str], **kwargs) -> Any:
    """     Returns an item's value.

    Args:
        item (Union[int, str]): 
    Returns:
        Any
    """

    return dcg_context[item].value

def get_values(items : Union[List[int], Tuple[int, ...]], **kwargs) -> Any:
    """     Returns values of a list of items.

    Args:
        items (Union[List[int], Tuple[int, ...]]): 
    Returns:
        Any
    """

    return [dcg_context[item].value for item in items]

def get_viewport_configuration(item : Union[int, str], **kwargs) -> dict:
    """     Returns a viewport's configuration.

    Args:
        item (Union[int, str]): 
    Returns:
        dict
    """
    keys = ["clear_color", "small_icon", "larg_icon",
             "x_pos", "y_pos", "width", "height",
            "client_width", "client_height",
            "resizable", "vsync",
            "min_width", "max_width",
            "min_height", "max_height",
            "always_on_top", "decorated",
            "title", "disable_close"]
    result = {}
    viewport = dcg_context.viewport
    for key in keys:
        result[key] = getattr(viewport, key)

    return result

def get_windows(**kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns all windows.

    Args:
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    return [item for item in dcg_context.viewport.children if isinstance(item, dcg.dcgWindow_)]

def get_x_scroll(item : Union[int, str], **kwargs) -> float:
    """     Undocumented

    Args:
        item (Union[int, str]): 
    Returns:
        float
    """

    #return internal_dpg.get_x_scroll(item, **kwargs)

def get_x_scroll_max(item : Union[int, str], **kwargs) -> float:
    """     Undocumented

    Args:
        item (Union[int, str]): 
    Returns:
        float
    """

    #return internal_dpg.get_x_scroll_max(item, **kwargs)

def get_y_scroll(item : Union[int, str], **kwargs) -> float:
    """     Undocumented

    Args:
        item (Union[int, str]): 
    Returns:
        float
    """

    #return internal_dpg.get_y_scroll(item, **kwargs)

def get_y_scroll_max(item : Union[int, str], **kwargs) -> float:
    """     Undocumented

    Args:
        item (Union[int, str]): 
    Returns:
        float
    """

    #return internal_dpg.get_y_scroll_max(item, **kwargs)

def highlight_table_cell(table : Union[int, str], row : int, column : int, color : Union[List[int], Tuple[int, ...]], **kwargs) -> None:
    """     Highlight specified table cell.

    Args:
        table (Union[int, str]): 
        row (int): 
        column (int): 
        color (Union[List[int], Tuple[int, ...]]): 
    Returns:
        None
    """

    #return internal_dpg.highlight_table_cell(table, row, column, color, **kwargs)

def highlight_table_column(table : Union[int, str], column : int, color : Union[List[int], Tuple[int, ...]], **kwargs) -> None:
    """     Highlight specified table column.

    Args:
        table (Union[int, str]): 
        column (int): 
        color (Union[List[int], Tuple[int, ...]]): 
    Returns:
        None
    """

    #return internal_dpg.highlight_table_column(table, column, color, **kwargs)

def highlight_table_row(table : Union[int, str], row : int, color : Union[List[int], Tuple[int, ...]], **kwargs) -> None:
    """     Highlight specified table row.

    Args:
        table (Union[int, str]): 
        row (int): 
        color (Union[List[int], Tuple[int, ...]]): 
    Returns:
        None
    """

    #return internal_dpg.highlight_table_row(table, row, color, **kwargs)

def is_dearpygui_running(**kwargs) -> bool:
    """     Checks if Dear PyGui is running

    Args:
    Returns:
        bool
    """

    return dcg_context.running

def is_key_down(key : int, **kwargs) -> bool:
    """     Checks if key is down.

    Args:
        key (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_key_down(key, **kwargs)

def is_key_pressed(key : int, **kwargs) -> bool:
    """     Checks if key is pressed.

    Args:
        key (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_key_pressed(key, **kwargs)

def is_key_released(key : int, **kwargs) -> bool:
    """     Checks if key is released.

    Args:
        key (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_key_released(key, **kwargs)

def is_mouse_button_clicked(button : int, **kwargs) -> bool:
    """     Checks if mouse button is clicked.

    Args:
        button (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_mouse_button_clicked(button, **kwargs)

def is_mouse_button_double_clicked(button : int, **kwargs) -> bool:
    """     Checks if mouse button is double clicked.

    Args:
        button (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_mouse_button_double_clicked(button, **kwargs)

def is_mouse_button_down(button : int, **kwargs) -> bool:
    """     Checks if mouse button is down.

    Args:
        button (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_mouse_button_down(button, **kwargs)

def is_mouse_button_dragging(button : int, threshold : float, **kwargs) -> bool:
    """     Checks if mouse button is down and dragging.

    Args:
        button (int): 
        threshold (float): 
    Returns:
        bool
    """

    #return internal_dpg.is_mouse_button_dragging(button, threshold, **kwargs)

def is_mouse_button_released(button : int, **kwargs) -> bool:
    """     Checks if mouse button is released.

    Args:
        button (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_mouse_button_released(button, **kwargs)

def is_table_cell_highlighted(table : Union[int, str], row : int, column : int, **kwargs) -> bool:
    """     Checks if a table cell is highlighted.

    Args:
        table (Union[int, str]): 
        row (int): 
        column (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_table_cell_highlighted(table, row, column, **kwargs)

def is_table_column_highlighted(table : Union[int, str], column : int, **kwargs) -> bool:
    """     Checks if a table column is highlighted.

    Args:
        table (Union[int, str]): 
        column (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_table_column_highlighted(table, column, **kwargs)

def is_table_row_highlighted(table : Union[int, str], row : int, **kwargs) -> bool:
    """     Checks if a table row is highlighted.

    Args:
        table (Union[int, str]): 
        row (int): 
    Returns:
        bool
    """

    #return internal_dpg.is_table_row_highlighted(table, row, **kwargs)

def is_viewport_ok(**kwargs) -> bool:
    """     Checks if a viewport has been created and shown.

    Args:
    Returns:
        bool
    """

    try:
        return dcg_context.viewport.shown
    except RuntimeError:
        return False

def last_container(**kwargs) -> Union[int, str]:
    """     Returns the last container item added.

    Args:
    Returns:
        Union[int, str]
    """

    return dcg_context.fetch_last_created_container()

def last_item(**kwargs) -> Union[int, str]:
    """     Returns the last item added.

    Args:
    Returns:
        Union[int, str]
    """

    return dcg_context.fetch_last_created_item()

def last_root(**kwargs) -> Union[int, str]:
    """     Returns the last root added (registry or window).

    Args:
    Returns:
        Union[int, str]
    """

    item = dcg_context.fetch_last_created_container()
    while item.parent is not dcg_context.viewport:
        item = item.parent
    return item

def load_image(file : str, *, gamma: float =1.0, gamma_scale_factor: float =1.0, **kwargs) -> Any:
    """     Loads an image. Returns width, height, channels, mvBuffer

    Args:
        file (str): 
        gamma (float, optional): Gamma correction factor. (default is 1.0 to avoid automatic gamma correction on loading.
        gamma_scale_factor (float, optional): Gamma scale factor.
    Returns:
        Any
    """

    #return internal_dpg.load_image(file, gamma=gamma, gamma_scale_factor=gamma_scale_factor, **kwargs)

def lock_mutex(**kwargs) -> None:
    """     Locks render thread mutex.

    Args:
    Returns:
        None
    """

    return dcg_context.viewport.lock_mutex(wait=True)

def maximize_viewport(**kwargs) -> None:
    """     Maximizes the viewport.

    Args:
    Returns:
        None
    """

    dcg_context.viewport.maximized = True

def minimize_viewport(**kwargs) -> None:
    """     Minimizes a viewport.

    Args:
    Returns:
        None
    """

    dcg_context.viewport.minimized = True

def move_item(item : Union[int, str], parent=None, before=None, **kwargs) -> None:
    """     Moves an item to a new location.

    Args:
        item (Union[int, str]): 
        parent (Union[int, str], optional): 
        before (Union[int, str], optional): 
    Returns:
        None
    """

    item = dcg_context[item]
    if before is not None:
        item.previous_sibling = before
    elif parent is not None:
        item.parent = parent
    else:
        raise ValueError("Neither parent nor before are set")

def move_item_down(item : Union[int, str], **kwargs) -> None:
    """     Moves an item down.

    Args:
        item (Union[int, str]): 
    Returns:
        None
    """

    # The logic seems reverse
    next_sibling = item.next_sibling
    if next_sibling is not None:
        item.previous_sibling = next_sibling

def move_item_up(item : Union[int, str], **kwargs) -> None:
    """     Moves an item up.

    Args:
        item (Union[int, str]): 
    Returns:
        None
    """

    # The logic seems reverse
    prev_sibling = item.previous_sibling
    if prev_sibling is not None:
        item.next_sibling = prev_sibling

def output_frame_buffer(file : str ='', *, callback: Callable =None, **kwargs) -> Any:
    """     Outputs frame buffer as a png if file is specified or through the second argument of a callback if specified. Render loop must have been started.

    Args:
        file (str, optional): 
        callback (Callable, optional): Callback will return framebuffer as an array through the second arg.
    Returns:
        Any
    """

    #return internal_dpg.output_frame_buffer(file, callback=callback, **kwargs)

def pop_container_stack(**kwargs) -> Union[int, str]:
    """     Pops the top item off the parent stack and return its ID.

    Args:
    Returns:
        Union[int, str]
    """

    return dcg_context.pop_next_parent(**kwargs)

def push_container_stack(item : Union[int, str], **kwargs) -> bool:
    """     Pushes an item onto the container stack.

    Args:
        item (Union[int, str]): 
    Returns:
        bool
    """

    return dcg_context.push_next_parent(item)

def remove_alias(alias : str, **kwargs) -> None:
    """     Removes an alias.

    Args:
        alias (str): 
    Returns:
        None
    """

    dcg_context[alias].tag = None

def render_dearpygui_frame(**kwargs) -> None:
    """     Render a single Dear PyGui frame.

    Args:
    Returns:
        None
    """

    return dcg_context.viewport.render_frame()

def reorder_items(container : Union[int, str], slot : int, new_order : Union[List[int], Tuple[int, ...]], **kwargs) -> None:
    """     Reorders an item's children.

    Args:
        container (Union[int, str]): 
        slot (int): 
        new_order (Union[List[int], Tuple[int, ...]]): 
    Returns:
        None
    """
    container = dcg_context[container]
    for item in new_order:
        item.parent = container

def reset_axis_limits_constraints(axis : Union[int, str], **kwargs) -> None:
    """     Remove an axis' limits constraints

    Args:
        axis (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.reset_axis_limits_constraints(axis, **kwargs)

def reset_axis_ticks(axis : Union[int, str], **kwargs) -> None:
    """     Removes the manually set axis ticks and applies the default axis ticks

    Args:
        axis (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.reset_axis_ticks(axis, **kwargs)

def reset_axis_zoom_constraints(axis : Union[int, str], **kwargs) -> None:
    """     Remove an axis' zoom constraints

    Args:
        axis (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.reset_axis_zoom_constraints(axis, **kwargs)

def reset_pos(item : Union[int, str], **kwargs) -> None:
    """     Resets an item's position after using 'set_item_pos'.

    Args:
        item (Union[int, str]): 
    Returns:
        None
    """

    dcg_context[item].pos = []

def sample_colormap(colormap : Union[int, str], t : float, **kwargs) -> Union[List[int], Tuple[int, ...]]:
    """     Returns a color from a colormap given t between 0.0-1.0.

    Args:
        colormap (Union[int, str]): The colormap tag. This should come from a colormap that was added to a colormap registry. Built in color maps are accessible through their corresponding constants mvPlotColormap_Twilight, mvPlotColormap_***
        t (float): Value of the colormap to sample between 0.0-1.0
    Returns:
        Union[List[int], Tuple[int, ...]]
    """

    #return internal_dpg.sample_colormap(colormap, t, **kwargs)

def save_image(file : str, width : int, height : int, data : Any, *, components: int =4, quality: int =50, **kwargs) -> None:
    """     Saves an image. Possible formats: png, bmp, tga, hdr, jpg.

    Args:
        file (str): 
        width (int): 
        height (int): 
        data (Any): 
        components (int, optional): Number of components (1-4). Default of 4.
        quality (int, optional): Stride in bytes (only used for jpg).
    Returns:
        None
    """

    #return internal_dpg.save_image(file, width, height, data, components=components, quality=quality, **kwargs)

def save_init_file(file : str, **kwargs) -> None:
    """     Save dpg.ini file.

    Args:
        file (str): 
    Returns:
        None
    """

    #return internal_dpg.save_init_file(file, **kwargs)

def set_axis_limits(axis : Union[int, str], ymin : float, ymax : float, **kwargs) -> None:
    """     Sets limits on the axis for pan and zoom.

    Args:
        axis (Union[int, str]): 
        ymin (float): 
        ymax (float): 
    Returns:
        None
    """

    #return internal_dpg.set_axis_limits(axis, ymin, ymax, **kwargs)

def set_axis_limits_auto(axis : Union[int, str], **kwargs) -> None:
    """     Removes all limits on specified axis.

    Args:
        axis (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.set_axis_limits_auto(axis, **kwargs)

def set_axis_limits_constraints(axis : Union[int, str], vmin : float, vmax : float, **kwargs) -> None:
    """     Sets an axis' limits constraints so that users can't pan beyond a min or max value

    Args:
        axis (Union[int, str]): 
        vmin (float): 
        vmax (float): 
    Returns:
        None
    """

    #return internal_dpg.set_axis_limits_constraints(axis, vmin, vmax, **kwargs)

def set_axis_ticks(axis : Union[int, str], label_pairs : Any, **kwargs) -> None:
    """     Replaces axis ticks with 'label_pairs' argument.

    Args:
        axis (Union[int, str]): 
        label_pairs (Any): Tuples of label and value in the form '((label, axis_value), (label, axis_value), ...)'
    Returns:
        None
    """

    #return internal_dpg.set_axis_ticks(axis, label_pairs, **kwargs)

def set_axis_zoom_constraints(axis : Union[int, str], vmin : float, vmax : float, **kwargs) -> None:
    """     Sets an axis' zoom constraints so that users can't zoom beyond a min or max value

    Args:
        axis (Union[int, str]): 
        vmin (float): 
        vmax (float): 
    Returns:
        None
    """

    #return internal_dpg.set_axis_zoom_constraints(axis, vmin, vmax, **kwargs)

def set_clip_space(item : Union[int, str], top_left_x : float, top_left_y : float, width : float, height : float, min_depth : float, max_depth : float, **kwargs) -> None:
    """     New in 1.1. Set the clip space for depth clipping and 'viewport' transformation.

    Args:
        item (Union[int, str]): draw layer to set clip space
        top_left_x (float): angle to rotate
        top_left_y (float): angle to rotate
        width (float): angle to rotate
        height (float): angle to rotate
        min_depth (float): angle to rotate
        max_depth (float): angle to rotate
    Returns:
        None
    """

    return item.clip_space(top_left_x, top_left_y, width, height, min_depth, max_depth, **kwargs)

def set_clipboard_text(text : str, **kwargs) -> None:
    """     New in 1.3. Sets the clipboard text.

    Args:
        text (str): 
    Returns:
        None
    """

    #return internal_dpg.set_clipboard_text(text, **kwargs)

def set_exit_callback(callback : Callable, *, user_data: Any =None, **kwargs) -> str:
    """     Sets a callback to run on last frame.

    Args:
        callback (Callable): 
        user_data (Any, optional): New in 1.3. Optional user data to send to the callback
    Returns:
        str
    """

    #return internal_dpg.set_exit_callback(callback, user_data=user_data, **kwargs)

def set_frame_callback(frame : int, callback : Callable, *, user_data: Any =None, **kwargs) -> str:
    """     Sets a callback to run on first frame.

    Args:
        frame (int): 
        callback (Callable): 
        user_data (Any, optional): New in 1.3. Optional user data to send to the callback
    Returns:
        str
    """

    #return internal_dpg.set_frame_callback(frame, callback, user_data=user_data, **kwargs)

def set_global_font_scale(scale : float, **kwargs) -> None:
    """     Sets global font scale.

    Args:
        scale (float): 
    Returns:
        None
    """

    #return internal_dpg.set_global_font_scale(scale, **kwargs)

def set_item_alias(item : Union[int, str], alias : str, **kwargs) -> None:
    """     Sets an item's alias.

    Args:
        item (Union[int, str]): 
        alias (str): 
    Returns:
        None
    """

    dcg_context[item].tag = alias

def set_item_children(item : Union[int, str], source : Union[int, str], slot : int, **kwargs) -> None:
    """     Sets an item's children.

    Args:
        item (Union[int, str]): 
        source (Union[int, str]): 
        slot (int): 
    Returns:
        None
    """
    source = dcg_context[source]
    item = dcg_context[item]
    for child in source.children:
        child.parent = item

def set_primary_window(window : Union[int, str], value : bool, **kwargs) -> None:
    """     Sets the primary window.

    Args:
        window (Union[int, str]): 
        value (bool): 
    Returns:
        None
    """
    dcg_context[window].primary = value

def set_table_row_color(table : Union[int, str], row : int, color : Union[List[int], Tuple[int, ...]], **kwargs) -> None:
    """     Set table row color.

    Args:
        table (Union[int, str]): 
        row (int): 
        color (Union[List[int], Tuple[int, ...]]): 
    Returns:
        None
    """

    #return internal_dpg.set_table_row_color(table, row, color, **kwargs)

def set_value(item : Union[int, str], value : Any, **kwargs) -> None:
    """     Set's an item's value.

    Args:
        item (Union[int, str]): 
        value (Any): 
    Returns:
        None
    """
    item = dcg_context[item]
    if isinstance(item, dcg.dcgTexture):
        item.set_value(value)
    else:
        item.value = value

def set_viewport_resize_callback(callback : Callable, *, user_data: Any =None, **kwargs) -> str:
    """     Sets a callback to run on viewport resize.

    Args:
        callback (Callable): 
        user_data (Any, optional): New in 1.3. Optional user data to send to the callback
    Returns:
        str
    """

    dcg_context.viewport.resize_callback = (callback, user_data)

def set_x_scroll(item : Union[int, str], value : float, **kwargs) -> None:
    """     Undocumented

    Args:
        item (Union[int, str]): 
        value (float): 
    Returns:
        None
    """

    #return internal_dpg.set_x_scroll(item, value, **kwargs)

def set_y_scroll(item : Union[int, str], value : float, **kwargs) -> None:
    """     Undocumented

    Args:
        item (Union[int, str]): 
        value (float): 
    Returns:
        None
    """

    #return internal_dpg.set_y_scroll(item, value, **kwargs)

def setup_dearpygui(**kwargs) -> None:
    """     Sets up Dear PyGui

    Args:
        viewport (Union[int, str], optional): (deprecated) 
    Returns:
        None
    """
    if 'viewport' in kwargs.keys():

        warnings.warn('viewport keyword removed', DeprecationWarning, 2)

        kwargs.pop('viewport', None)

    dcg_context.running = True

def show_imgui_demo(**kwargs) -> None:
    """     Shows the imgui demo.

    Args:
    Returns:
        None
    """

    #return internal_dpg.show_imgui_demo(**kwargs)

def show_implot_demo(**kwargs) -> None:
    """     Shows the implot demo.

    Args:
    Returns:
        None
    """

    #return internal_dpg.show_implot_demo(**kwargs)

def show_item_debug(item : Union[int, str], **kwargs) -> None:
    """     Shows an item's debug window

    Args:
        item (Union[int, str]): 
    Returns:
        None
    """

    #return internal_dpg.show_item_debug(item, **kwargs)

def show_tool(tool : Union[int, str], **kwargs) -> str:
    """     Shows a built in tool.

    Args:
        tool (Union[int, str]): 
    Returns:
        str
    """

    #return internal_dpg.show_tool(tool, **kwargs)

def show_viewport(*, minimized: bool =False, maximized: bool =False, **kwargs) -> None:
    """     Shows the main viewport.

    Args:
        minimized (bool, optional): Sets the state of the viewport to minimized
        maximized (bool, optional): Sets the state of the viewport to maximized
        viewport (Union[int, str], optional): (deprecated) 
    Returns:
        None
    """

    if 'viewport' in kwargs.keys():

        warnings.warn('viewport keyword removed', DeprecationWarning, 2)

        kwargs.pop('viewport', None)

    dcg_context.viewport.show(minimized=minimized, maximized=maximized)

def split_frame(*, delay: int =32, **kwargs) -> None:
    """     Waits one frame.

    Args:
        delay (int, optional): Minimal delay in in milliseconds
    Returns:
        None
    """

    #return internal_dpg.split_frame(delay=delay, **kwargs)

def stop_dearpygui(**kwargs) -> None:
    """     Stops Dear PyGui

    Args:
    Returns:
        None
    """

    dcg_context.running = False

def toggle_viewport_fullscreen(**kwargs) -> None:
    """     Toggle viewport fullscreen mode..

    Args:
    Returns:
        None
    """

    dcg_context.viewport.fullscreen = True

def top_container_stack(**kwargs) -> Union[int, str]:
    """     Returns the item on the top of the container stack.

    Args:
    Returns:
        Union[int, str]
    """

    #return internal_dpg.top_container_stack(**kwargs)

def unhighlight_table_cell(table : Union[int, str], row : int, column : int, **kwargs) -> None:
    """     Unhighlight specified table cell.

    Args:
        table (Union[int, str]): 
        row (int): 
        column (int): 
    Returns:
        None
    """

    #return internal_dpg.unhighlight_table_cell(table, row, column, **kwargs)

def unhighlight_table_column(table : Union[int, str], column : int, **kwargs) -> None:
    """     Unhighlight specified table column.

    Args:
        table (Union[int, str]): 
        column (int): 
    Returns:
        None
    """

    #return internal_dpg.unhighlight_table_column(table, column, **kwargs)

def unhighlight_table_row(table : Union[int, str], row : int, **kwargs) -> None:
    """     Unhighlight specified table row.

    Args:
        table (Union[int, str]): 
        row (int): 
    Returns:
        None
    """

    #return internal_dpg.unhighlight_table_row(table, row, **kwargs)

def unlock_mutex(**kwargs) -> None:
    """     Unlocks render thread mutex

    Args:
    Returns:
        None
    """

    return dcg_context.viewport.unlock_mutex()

def unset_table_row_color(table : Union[int, str], row : int, **kwargs) -> None:
    """     Remove user set table row color.

    Args:
        table (Union[int, str]): 
        row (int): 
    Returns:
        None
    """

    #return internal_dpg.unset_table_row_color(table, row, **kwargs)

def unstage(item : Union[int, str], **kwargs) -> None:
    """     Unstages an item.

    Args:
        item (Union[int, str]): 
    Returns:
        None
    """
    item = dcg_context[item]
    assert(isinstance(item, dcg.dcgPlaceHolderParent))
    # Ideally we'd lock the target parent mutex rather
    # than the viewport. The locking is to force the unstage
    # to be atomic (all done in one frame).
    with mutex():
        for child in item.children:
            child.configure(**kwargs)
    item.delete_item()


##########################################################
# Container Context Managers legacy + item legacy
##########################################################

add_button = button
add_checkbox = checkbox
add_child_window = child_window
add_clipper = clipper
add_color_button = color_button
add_color_edit = color_edit
add_color_picker = color_picker
add_color_value = color_value
add_colormap = colormap
add_colormap_button = colormap_button
add_colormap_scale = colormap_scale
add_colormap_slider = colormap_slider
add_collapsing_header = collapsing_header
add_colormap_registry = colormap_registry
add_combo = combo
add_custom_series = custom_series
add_date_picker = date_picker
add_digital_series = digital_series
add_double4_value = double4_value
add_double_value = double_value
add_drag_double = drag_double
add_drag_doublex = drag_doublex
add_drag_float = drag_float
add_drag_floatx = drag_floatx
add_drag_int = drag_int
add_drag_intx = drag_intx
add_drag_line = drag_line
add_drag_payload = drag_payload
add_drag_point = drag_point
add_drag_rect = drag_rect
add_draw_layer = draw_layer
add_draw_node = draw_node
add_drawlist = drawlist
add_dynamic_texture = dynamic_texture
add_error_series = error_series
add_file_dialog = file_dialog
add_file_extension = file_extension
add_filter_set = filter_set
add_float4_value = float4_value
add_float_value = float_value
add_float_vect_value = float_vect_value
add_font = font
add_font_chars = font_chars
add_font_range = font_range
add_font_range_hint = font_range_hint
add_font_registry = font_registry
add_group = group
add_handler_registry = handler_registry
add_heat_series = heat_series
add_histogram_series = histogram_series
add_image = image
add_image_button = image_button
add_image_series = image_series
add_inf_line_series = inf_line_series
add_input_double = input_double
add_input_doublex = input_doublex
add_input_float = input_float
add_input_floatx = input_floatx
add_input_int = input_int
add_input_intx = input_intx
add_input_text = input_text
add_int4_value = int4_value
add_int_value = int_value
add_item_activated_handler = item_activated_handler
add_item_active_handler = item_active_handler
add_item_clicked_handler = item_clicked_handler
add_item_deactivated_after_edit_handler = item_deactivated_after_edit_handler
add_item_deactivated_handler = item_deactivated_handler
add_item_double_clicked_handler = item_double_clicked_handler
add_item_edited_handler = item_edited_handler
add_item_focus_handler = item_focus_handler
add_item_handler_registry = item_handler_registry
add_item_hover_handler = item_hover_handler
add_item_resize_handler = item_resize_handler
add_item_toggled_open_handler = item_toggled_open_handler
add_item_visible_handler = item_visible_handler
add_key_down_handler = key_down_handler
add_key_press_handler = key_press_handler
add_key_release_handler = key_release_handler
add_knob_float = knob_float
add_line_series = line_series
add_listbox = listbox
add_loading_indicator = loading_indicator
add_menu = menu
add_menu_bar = menu_bar
add_menu_item = menu_item
add_mouse_click_handler = mouse_click_handler
add_mouse_double_click_handler = mouse_double_click_handler
add_mouse_down_handler = mouse_down_handler
add_mouse_drag_handler = mouse_drag_handler
add_mouse_move_handler = mouse_move_handler
add_mouse_release_handler = mouse_release_handler
add_mouse_wheel_handler = mouse_wheel_handler
add_node = node
add_node_attribute = node_attribute
add_node_editor = node_editor
add_node_link = node_link
add_pie_series = pie_series
add_plot = plot
add_plot_annotation = plot_annotation
add_plot_axis = plot_axis
add_plot_legend = plot_legend
add_progress_bar = progress_bar
add_radio_button = radio_button
add_raw_texture = raw_texture
add_scatter_series = scatter_series
add_selectable = selectable
add_separator = separator
add_series_value = series_value
add_shade_series = shade_series
add_simple_plot = simple_plot
add_slider_double = slider_double
add_slider_doublex = slider_doublex
add_slider_float = slider_float
add_slider_floatx = slider_floatx
add_slider_int = slider_int
add_slider_intx = slider_intx
add_spacer = spacer
add_stage = stage
add_stair_series = stair_series
add_static_texture = static_texture
add_string_value = string_value
add_stem_series = stem_series
add_subplots = subplots
add_tab = tab
add_tab_bar = tab_bar
add_tab_button = tab_button
add_table = table
add_table_cell = table_cell
add_table_column = table_column
add_table_row = table_row
add_template_registry = template_registry
add_text = text
add_text_point = text_point
add_texture_registry = texture_registry
add_theme = theme
add_theme_color = theme_color
add_theme_component = theme_component
add_theme_style = theme_style
add_time_picker = time_picker
add_tooltip = tooltip
add_tree_node = tree_node
add_value_registry = value_registry
add_viewport_drawlist = viewport_drawlist
add_viewport_menu_bar = viewport_menu_bar
add_window = window

##########################################################
# item legacy
##########################################################


##########################################################
# Deprecated Commands
##########################################################



def deprecated(reason):

    string_types = (type(b''), type(u''))

    if isinstance(reason, string_types):

        def decorator(func1):

            fmt1 = "Call to deprecated function {name} ({reason})."

            @functools.wraps(func1)
            def new_func1(*args, **kwargs):
                warnings.simplefilter('always', DeprecationWarning)
                warnings.warn(
                    fmt1.format(name=func1.__name__, reason=reason),
                    category=DeprecationWarning,
                    stacklevel=2
                )
                warnings.simplefilter('default', DeprecationWarning)
                return func1(*args, **kwargs)

            return new_func1

        return decorator

    elif inspect.isfunction(reason):

        func2 = reason
        fmt2 = "Call to deprecated function {name}."

        @functools.wraps(func2)
        def new_func2(*args, **kwargs):
            warnings.simplefilter('always', DeprecationWarning)
            warnings.warn(
                fmt2.format(name=func2.__name__),
                category=DeprecationWarning,
                stacklevel=2
            )
            warnings.simplefilter('default', DeprecationWarning)
            return func2(*args, **kwargs)

        return new_func2

@deprecated("Use 'configure_app(init_file=file)'.")
def set_init_file(file="dpg.ini"):
    """ deprecated function """
    internal_dpg.configure_app(init_file=file)

@deprecated("Use 'configure_app(init_file=file, load_init_file=True)'.")
def load_init_file(file):
    """ deprecated function """
    internal_dpg.configure_app(init_file=file, load_init_file=True)

@deprecated("Use: `is_viewport_ok(...)`")
def is_viewport_created():
    """ deprecated function """
    return is_viewport_ok()

@deprecated("Use: \ncreate_viewport()\nsetup_dearpygui()\nshow_viewport()")
def setup_viewport():
    """ deprecated function """
    create_viewport()
    setup_dearpygui()
    show_viewport()

@deprecated("Use: `bind_item_theme(...)`")
def set_item_theme(item, theme):
    """ deprecated function """
    item.theme = theme

@deprecated("Use: `bind_item_type_disabled_theme(...)`")
def set_item_type_disabled_theme(item, theme):
    raise RuntimeError("Unsupported feature")

@deprecated("Use: `bind_item_type_theme(...)`")
def set_item_type_theme(item, theme):
    raise RuntimeError("Unsupported feature")

@deprecated("Use: `bind_item_font(...)`")
def set_item_font(item, font):
    item.font = font

@deprecated("Use: `item_activated_handler(...)`")
def add_activated_handler(parent, **kwargs):
    """ deprecated function """
    return item_activated_handler(parent, **kwargs)

@deprecated("Use: `item_active_handler(...)`")
def add_active_handler(parent, **kwargs):
    """ deprecated function """
    return item_active_handler(parent, **kwargs)

@deprecated("Use: `item_clicked_handler(...)`")
def add_clicked_handler(parent, button=-1, **kwargs):
    """ deprecated function """
    return item_clicked_handler(parent, button, **kwargs)

@deprecated("Use: `item_deactived_after_edit_handler(...)`")
def add_deactivated_after_edit_handler(parent, **kwargs):
    """ deprecated function """
    return item_deactivated_after_edit_handler(parent, **kwargs)

@deprecated("Use: `item_deactivated_handler(...)`")
def add_deactivated_handler(parent, **kwargs):
    """ deprecated function """
    return item_deactivated_handler(parent, **kwargs)

@deprecated("Use: `item_edited_handler(...)`")
def add_edited_handler(parent, **kwargs):
    """ deprecated function """
    return item_edited_handler(parent, **kwargs)

@deprecated("Use: `item_focus_handler(...)`")
def add_focus_handler(parent, **kwargs):
    """ deprecated function """
    return item_focus_handler(parent, **kwargs)

@deprecated("Use: `item_hover_handler(...)`")
def add_hover_handler(parent, **kwargs):
    """ deprecated function """
    return item_hover_handler(parent, **kwargs)

@deprecated("Use: `item_resize_handler(...)`")
def add_resize_handler(parent, **kwargs):
    """ deprecated function """
    return item_resize_handler(parent, **kwargs)

@deprecated("Use: `item_toggled_open_handler(...)`")
def add_toggled_open_handler(parent, **kwargs):
    """ deprecated function """
    return item_toggled_open_handler(parent, **kwargs)

@deprecated("Use: `item_visible_handler(...)`")
def add_visible_handler(parent, **kwargs):
    """ deprecated function """
    return item_visible_handler(parent, **kwargs)

@deprecated("Use: `bind_colormap(...)`")
def set_colormap(item, source):
    """ deprecated function """
    return internal_dpg.bind_colormap(item, source)

@deprecated("Use: `bind_theme(0)`")
def reset_default_theme(item, source):
    """ deprecated function """
    dcg_context.viewport.theme = None

@deprecated
def set_staging_mode(mode):
    """ deprecated function """
    pass

@deprecated
def add_table_next_column(**kwargs):
    """ deprecated function """
    pass

@deprecated("Use: add_stage")
def add_staging_container(**kwargs):
    """ deprecated function """
    return stage(**kwargs)

@deprecated("Use: stage")
def staging_container(**kwargs):
    """ deprecated function """
    return stage(**kwargs)

@deprecated("Use: add_spacer(...)")
def add_spacing(**kwargs):
    """    (deprecated function) Adds vertical spacing. 

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks.
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int]], optional): Places the item relative to window coordinates, [0,0] is top left.
        count (int, optional): Number of spacings to add the size is dependant on the curret style.
    Returns:
        Union[int, str]
    """

    if 'count' in kwargs.keys():
        count = kwargs["count"]
        kwargs.pop("count", None)
        result_id = add_group(**kwargs)
        with result_id:
            for i in range(count):
                spacer()
    else:
        result_id = spacer(**kwargs)
    return result_id

@deprecated("Use: add_spacer(...)")
def add_dummy(**kwargs):
    """    (deprecated function) Adds a spacer or 'dummy' object.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks.
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int]], optional): Places the item relative to window coordinates, [0,0] is top left.
    Returns:
        Union[int, str]
    """

    return spacer(**kwargs)

@deprecated("Use: `destroy_context()`")
def cleanup_dearpygui():
    """ deprecated function """
    return destroy_context()

@deprecated("Use: group(horizontal=True)")
def add_same_line(**kwargs):
    """ deprecated function """

    last_item = internal_dpg.last_item()
    group = add_group(horizontal=True, **kwargs)
    move_item(last_item, parent=group)
    internal_dpg.capture_next_item(lambda s: internal_dpg.move_item(s, parent=group))
    return group

@deprecated("Use: `get_plot_query_rects()`")
def is_plot_queried(plot: Union[int, str], **kwargs):
    """    (deprecated function) Returns true if the plot is currently being queried. 

    Args:
        plot (Union[int, str]): 
    Returns:
        bool
    """

    return len(internal_dpg.get_plot_query_rects(plot, **kwargs)) > 0

@deprecated("Use: `get_plot_query_rects()`")
def get_plot_query_area(plot: Union[int, str], **kwargs):
    """    (deprecated function) Returns the last/current query area of the plot. If no area is available [0, 0, 0, 0] will be returned.

    Args:
        plot (Union[int, str]): 
    Returns:
        Union[List[float], Tuple[float, ...]]
    """

    if rects := internal_dpg.get_plot_query_rects(plot, **kwargs):
        return rects[0]
    else:
        return [0, 0, 0, 0]

@deprecated("Use: `inf_line_series(horizontal=True)`")
def add_hline_series(x, **kwargs):
    """    (deprecated function) Adds an infinite horizontal line series to a plot.

    Args:
        x (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated)
    Returns:
        Union[int, str]
    """

    return add_inf_line_series(x, **kwargs, horizontal=True)
            

@deprecated("Use: `inf_line_series()`")
def add_vline_series(x, **kwargs):
    """    (deprecated function) Adds an infinite vertical line series to a plot.

    Args:
        x (Any): 
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        source (Union[int, str], optional): Overrides 'id' as value storage key.
        show (bool, optional): Attempt to render widget.
        id (Union[int, str], optional): (deprecated)
    Returns:
        Union[int, str]
    """

    return add_inf_line_series(x, **kwargs)


@deprecated("Use: `child_window()`")
def add_child(**kwargs):
    """    (deprecated function) Adds an embedded child window. Will show scrollbars when items do not fit.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        border (bool, optional): Shows/Hides the border around the sides.
        autosize_x (bool, optional): Autosize the window to its parents size in x.
        autosize_y (bool, optional): Autosize the window to its parents size in y.
        no_scrollbar (bool, optional):  Disable scrollbars (window can still scroll with mouse or programmatically).
        horizontal_scrollbar (bool, optional): Allow horizontal scrollbar to appear (off by default).
        menubar (bool, optional): Shows/Hides the menubar at the top.
    Returns:
        Union[int, str]
    """

    return add_child_window(**kwargs)


@deprecated("Use: `child_window()`")
def child(**kwargs):
    """    (deprecated function) Adds an embedded child window. Will show scrollbars when items do not fit.

    Args:
        label (str, optional): Overrides 'name' as label.
        user_data (Any, optional): User data for callbacks
        tag (Union[int, str], optional): Unique id used to programmatically refer to the item.If label is unused this will be the label.
        width (int, optional): Width of the item.
        height (int, optional): Height of the item.
        indent (int, optional): Offsets the widget to the right the specified number multiplied by the indent style.
        parent (Union[int, str], optional): Parent to add this item to. (runtime adding)
        before (Union[int, str], optional): This item will be displayed before the specified item in the parent.
        payload_type (str, optional): Sender string type must be the same as the target for the target to run the payload_callback.
        drop_callback (Callable, optional): Registers a drop callback for drag and drop.
        show (bool, optional): Attempt to render widget.
        pos (Union[List[int], Tuple[int]], optional): Places the item relative to window coordinates, [0,0] is top left.
        filter_key (str, optional): Used by filter widget.
        tracked (bool, optional): Scroll tracking
        track_offset (float, optional): 0.0f:top, 0.5f:center, 1.0f:bottom
        border (bool, optional): Shows/Hides the border around the sides.
        autosize_x (bool, optional): Autosize the window to its parents size in x.
        autosize_y (bool, optional): Autosize the window to its parents size in y.
        no_scrollbar (bool, optional):  Disable scrollbars (window can still scroll with mouse or programmatically).
        horizontal_scrollbar (bool, optional): Allow horizontal scrollbar to appear (off by default).
        menubar (bool, optional): Shows/Hides the menubar at the top.
    Yields:
        Union[int, str]
    """
    return add_child_window(**kwargs)

@deprecated("Use: Just not recommended")
def setup_registries() -> None:
    """Adds default registries for fonts, handlers, textures, colormaps, and values."""
    add_font_registry(tag=constants.mvReservedUUID_0)
    add_handler_registry(tag=constants.mvReservedUUID_1)
    add_texture_registry(tag=constants.mvReservedUUID_2)
    add_value_registry(tag=constants.mvReservedUUID_3)
    add_colormap_registry(tag=constants.mvReservedUUID_4)

@deprecated("Use: `set_frame_callback()`")
def set_start_callback(callback):
    """ deprecated function """
    return internal_dpg.set_frame_callback(3, callback)





##########################################################
# Constants #
##########################################################

mvGraphicsBackend_D3D11=constants.mvGraphicsBackend_D3D11
mvGraphicsBackend_D3D12=constants.mvGraphicsBackend_D3D12
mvGraphicsBackend_VULKAN=constants.mvGraphicsBackend_VULKAN
mvGraphicsBackend_METAL=constants.mvGraphicsBackend_METAL
mvGraphicsBackend_OPENGL=constants.mvGraphicsBackend_OPENGL
mvMouseButton_Left=constants.mvMouseButton_Left
mvMouseButton_Right=constants.mvMouseButton_Right
mvMouseButton_Middle=constants.mvMouseButton_Middle
mvMouseButton_X1=constants.mvMouseButton_X1
mvMouseButton_X2=constants.mvMouseButton_X2
mvKey_ModDisabled=constants.mvKey_ModDisabled
mvKey_None=constants.mvKey_None
mvKey_0=constants.mvKey_0
mvKey_1=constants.mvKey_1
mvKey_2=constants.mvKey_2
mvKey_3=constants.mvKey_3
mvKey_4=constants.mvKey_4
mvKey_5=constants.mvKey_5
mvKey_6=constants.mvKey_6
mvKey_7=constants.mvKey_7
mvKey_8=constants.mvKey_8
mvKey_9=constants.mvKey_9
mvKey_A=constants.mvKey_A
mvKey_B=constants.mvKey_B
mvKey_C=constants.mvKey_C
mvKey_D=constants.mvKey_D
mvKey_E=constants.mvKey_E
mvKey_F=constants.mvKey_F
mvKey_G=constants.mvKey_G
mvKey_H=constants.mvKey_H
mvKey_I=constants.mvKey_I
mvKey_J=constants.mvKey_J
mvKey_K=constants.mvKey_K
mvKey_L=constants.mvKey_L
mvKey_M=constants.mvKey_M
mvKey_N=constants.mvKey_N
mvKey_O=constants.mvKey_O
mvKey_P=constants.mvKey_P
mvKey_Q=constants.mvKey_Q
mvKey_R=constants.mvKey_R
mvKey_S=constants.mvKey_S
mvKey_T=constants.mvKey_T
mvKey_U=constants.mvKey_U
mvKey_V=constants.mvKey_V
mvKey_W=constants.mvKey_W
mvKey_X=constants.mvKey_X
mvKey_Y=constants.mvKey_Y
mvKey_Z=constants.mvKey_Z
mvKey_Back=constants.mvKey_Back
mvKey_Tab=constants.mvKey_Tab
mvKey_Return=constants.mvKey_Return
mvKey_LShift=constants.mvKey_LShift
mvKey_RShift=constants.mvKey_RShift
mvKey_LControl=constants.mvKey_LControl
mvKey_RControl=constants.mvKey_RControl
mvKey_LAlt=constants.mvKey_LAlt
mvKey_RAlt=constants.mvKey_RAlt
mvKey_Pause=constants.mvKey_Pause
mvKey_CapsLock=constants.mvKey_CapsLock
mvKey_Escape=constants.mvKey_Escape
mvKey_Spacebar=constants.mvKey_Spacebar
mvKey_End=constants.mvKey_End
mvKey_Home=constants.mvKey_Home
mvKey_Left=constants.mvKey_Left
mvKey_Up=constants.mvKey_Up
mvKey_Right=constants.mvKey_Right
mvKey_Down=constants.mvKey_Down
mvKey_Print=constants.mvKey_Print
mvKey_Insert=constants.mvKey_Insert
mvKey_Delete=constants.mvKey_Delete
mvKey_NumPad0=constants.mvKey_NumPad0
mvKey_NumPad1=constants.mvKey_NumPad1
mvKey_NumPad2=constants.mvKey_NumPad2
mvKey_NumPad3=constants.mvKey_NumPad3
mvKey_NumPad4=constants.mvKey_NumPad4
mvKey_NumPad5=constants.mvKey_NumPad5
mvKey_NumPad6=constants.mvKey_NumPad6
mvKey_NumPad7=constants.mvKey_NumPad7
mvKey_NumPad8=constants.mvKey_NumPad8
mvKey_NumPad9=constants.mvKey_NumPad9
mvKey_Subtract=constants.mvKey_Subtract
mvKey_Decimal=constants.mvKey_Decimal
mvKey_Divide=constants.mvKey_Divide
mvKey_Multiply=constants.mvKey_Multiply
mvKey_Add=constants.mvKey_Add
mvKey_F1=constants.mvKey_F1
mvKey_F2=constants.mvKey_F2
mvKey_F3=constants.mvKey_F3
mvKey_F4=constants.mvKey_F4
mvKey_F5=constants.mvKey_F5
mvKey_F6=constants.mvKey_F6
mvKey_F7=constants.mvKey_F7
mvKey_F8=constants.mvKey_F8
mvKey_F9=constants.mvKey_F9
mvKey_F10=constants.mvKey_F10
mvKey_F11=constants.mvKey_F11
mvKey_F12=constants.mvKey_F12
mvKey_F13=constants.mvKey_F13
mvKey_F14=constants.mvKey_F14
mvKey_F15=constants.mvKey_F15
mvKey_F16=constants.mvKey_F16
mvKey_F17=constants.mvKey_F17
mvKey_F18=constants.mvKey_F18
mvKey_F19=constants.mvKey_F19
mvKey_F20=constants.mvKey_F20
mvKey_F21=constants.mvKey_F21
mvKey_F22=constants.mvKey_F22
mvKey_F23=constants.mvKey_F23
mvKey_F24=constants.mvKey_F24
mvKey_NumLock=constants.mvKey_NumLock
mvKey_ScrollLock=constants.mvKey_ScrollLock
mvKey_Period=constants.mvKey_Period
mvKey_Slash=constants.mvKey_Slash
mvKey_Backslash=constants.mvKey_Backslash
mvKey_Open_Brace=constants.mvKey_Open_Brace
mvKey_Close_Brace=constants.mvKey_Close_Brace
mvKey_Browser_Back=constants.mvKey_Browser_Back
mvKey_Browser_Forward=constants.mvKey_Browser_Forward
mvKey_Comma=constants.mvKey_Comma
mvKey_Minus=constants.mvKey_Minus
mvKey_Menu=constants.mvKey_Menu
mvKey_ModSuper=constants.mvKey_ModSuper
mvKey_ModShift=constants.mvKey_ModShift
mvKey_ModAlt=constants.mvKey_ModAlt
mvKey_ModCtrl=constants.mvKey_ModCtrl
mvKey_Clear=constants.mvKey_Clear
mvKey_Prior=constants.mvKey_Prior
mvKey_Next=constants.mvKey_Next
mvKey_Select=constants.mvKey_Select
mvKey_Execute=constants.mvKey_Execute
mvKey_LWin=constants.mvKey_LWin
mvKey_RWin=constants.mvKey_RWin
mvKey_Apps=constants.mvKey_Apps
mvKey_Sleep=constants.mvKey_Sleep
mvKey_Help=constants.mvKey_Help
mvKey_Browser_Refresh=constants.mvKey_Browser_Refresh
mvKey_Browser_Stop=constants.mvKey_Browser_Stop
mvKey_Browser_Search=constants.mvKey_Browser_Search
mvKey_Browser_Favorites=constants.mvKey_Browser_Favorites
mvKey_Browser_Home=constants.mvKey_Browser_Home
mvKey_Volume_Mute=constants.mvKey_Volume_Mute
mvKey_Volume_Down=constants.mvKey_Volume_Down
mvKey_Volume_Up=constants.mvKey_Volume_Up
mvKey_Media_Next_Track=constants.mvKey_Media_Next_Track
mvKey_Media_Prev_Track=constants.mvKey_Media_Prev_Track
mvKey_Media_Stop=constants.mvKey_Media_Stop
mvKey_Media_Play_Pause=constants.mvKey_Media_Play_Pause
mvKey_Launch_Mail=constants.mvKey_Launch_Mail
mvKey_Launch_Media_Select=constants.mvKey_Launch_Media_Select
mvKey_Launch_App1=constants.mvKey_Launch_App1
mvKey_Launch_App2=constants.mvKey_Launch_App2
mvKey_Colon=constants.mvKey_Colon
mvKey_Plus=constants.mvKey_Plus
mvKey_Tilde=constants.mvKey_Tilde
mvKey_Quote=constants.mvKey_Quote
mvKey_F25=constants.mvKey_F25
mvAll=constants.mvAll
mvTool_About=constants.mvTool_About
mvTool_Debug=constants.mvTool_Debug
mvTool_Doc=constants.mvTool_Doc
mvTool_ItemRegistry=constants.mvTool_ItemRegistry
mvTool_Metrics=constants.mvTool_Metrics
mvTool_Stack=constants.mvTool_Stack
mvTool_Style=constants.mvTool_Style
mvTool_Font=constants.mvTool_Font
mvFontAtlas=constants.mvFontAtlas
mvAppUUID=constants.mvAppUUID
mvInvalidUUID=constants.mvInvalidUUID
mvDir_None=constants.mvDir_None
mvDir_Left=constants.mvDir_Left
mvDir_Right=constants.mvDir_Right
mvDir_Up=constants.mvDir_Up
mvDir_Down=constants.mvDir_Down
mvComboHeight_Small=constants.mvComboHeight_Small
mvComboHeight_Regular=constants.mvComboHeight_Regular
mvComboHeight_Large=constants.mvComboHeight_Large
mvComboHeight_Largest=constants.mvComboHeight_Largest
mvPlatform_Windows=constants.mvPlatform_Windows
mvPlatform_Apple=constants.mvPlatform_Apple
mvPlatform_Linux=constants.mvPlatform_Linux
mvColorEdit_AlphaPreviewNone=constants.mvColorEdit_AlphaPreviewNone
mvColorEdit_AlphaPreview=constants.mvColorEdit_AlphaPreview
mvColorEdit_AlphaPreviewHalf=constants.mvColorEdit_AlphaPreviewHalf
mvColorEdit_uint8=constants.mvColorEdit_uint8
mvColorEdit_float=constants.mvColorEdit_float
mvColorEdit_rgb=constants.mvColorEdit_rgb
mvColorEdit_hsv=constants.mvColorEdit_hsv
mvColorEdit_hex=constants.mvColorEdit_hex
mvColorEdit_input_rgb=constants.mvColorEdit_input_rgb
mvColorEdit_input_hsv=constants.mvColorEdit_input_hsv
mvPlotColormap_Default=constants.mvPlotColormap_Default
mvPlotColormap_Deep=constants.mvPlotColormap_Deep
mvPlotColormap_Dark=constants.mvPlotColormap_Dark
mvPlotColormap_Pastel=constants.mvPlotColormap_Pastel
mvPlotColormap_Paired=constants.mvPlotColormap_Paired
mvPlotColormap_Viridis=constants.mvPlotColormap_Viridis
mvPlotColormap_Plasma=constants.mvPlotColormap_Plasma
mvPlotColormap_Hot=constants.mvPlotColormap_Hot
mvPlotColormap_Cool=constants.mvPlotColormap_Cool
mvPlotColormap_Pink=constants.mvPlotColormap_Pink
mvPlotColormap_Jet=constants.mvPlotColormap_Jet
mvPlotColormap_Twilight=constants.mvPlotColormap_Twilight
mvPlotColormap_RdBu=constants.mvPlotColormap_RdBu
mvPlotColormap_BrBG=constants.mvPlotColormap_BrBG
mvPlotColormap_PiYG=constants.mvPlotColormap_PiYG
mvPlotColormap_Spectral=constants.mvPlotColormap_Spectral
mvPlotColormap_Greys=constants.mvPlotColormap_Greys
mvColorPicker_bar=constants.mvColorPicker_bar
mvColorPicker_wheel=constants.mvColorPicker_wheel
mvTabOrder_Reorderable=constants.mvTabOrder_Reorderable
mvTabOrder_Fixed=constants.mvTabOrder_Fixed
mvTabOrder_Leading=constants.mvTabOrder_Leading
mvTabOrder_Trailing=constants.mvTabOrder_Trailing
mvTimeUnit_Us=constants.mvTimeUnit_Us
mvTimeUnit_Ms=constants.mvTimeUnit_Ms
mvTimeUnit_S=constants.mvTimeUnit_S
mvTimeUnit_Min=constants.mvTimeUnit_Min
mvTimeUnit_Hr=constants.mvTimeUnit_Hr
mvTimeUnit_Day=constants.mvTimeUnit_Day
mvTimeUnit_Mo=constants.mvTimeUnit_Mo
mvTimeUnit_Yr=constants.mvTimeUnit_Yr
mvDatePickerLevel_Day=constants.mvDatePickerLevel_Day
mvDatePickerLevel_Month=constants.mvDatePickerLevel_Month
mvDatePickerLevel_Year=constants.mvDatePickerLevel_Year
mvCullMode_None=constants.mvCullMode_None
mvCullMode_Back=constants.mvCullMode_Back
mvCullMode_Front=constants.mvCullMode_Front
mvFontRangeHint_Default=constants.mvFontRangeHint_Default
mvFontRangeHint_Japanese=constants.mvFontRangeHint_Japanese
mvFontRangeHint_Korean=constants.mvFontRangeHint_Korean
mvFontRangeHint_Chinese_Full=constants.mvFontRangeHint_Chinese_Full
mvFontRangeHint_Chinese_Simplified_Common=constants.mvFontRangeHint_Chinese_Simplified_Common
mvFontRangeHint_Cyrillic=constants.mvFontRangeHint_Cyrillic
mvFontRangeHint_Thai=constants.mvFontRangeHint_Thai
mvFontRangeHint_Vietnamese=constants.mvFontRangeHint_Vietnamese
mvNode_PinShape_Circle=constants.mvNode_PinShape_Circle
mvNode_PinShape_CircleFilled=constants.mvNode_PinShape_CircleFilled
mvNode_PinShape_Triangle=constants.mvNode_PinShape_Triangle
mvNode_PinShape_TriangleFilled=constants.mvNode_PinShape_TriangleFilled
mvNode_PinShape_Quad=constants.mvNode_PinShape_Quad
mvNode_PinShape_QuadFilled=constants.mvNode_PinShape_QuadFilled
mvNode_Attr_Input=constants.mvNode_Attr_Input
mvNode_Attr_Output=constants.mvNode_Attr_Output
mvNode_Attr_Static=constants.mvNode_Attr_Static
mvPlotBin_Sqrt=constants.mvPlotBin_Sqrt
mvPlotBin_Sturges=constants.mvPlotBin_Sturges
mvPlotBin_Rice=constants.mvPlotBin_Rice
mvPlotBin_Scott=constants.mvPlotBin_Scott
mvXAxis=constants.mvXAxis
mvXAxis2=constants.mvXAxis2
mvXAxis3=constants.mvXAxis3
mvYAxis=constants.mvYAxis
mvYAxis2=constants.mvYAxis2
mvYAxis3=constants.mvYAxis3
mvPlotScale_Linear=constants.mvPlotScale_Linear
mvPlotScale_Time=constants.mvPlotScale_Time
mvPlotScale_Log10=constants.mvPlotScale_Log10
mvPlotScale_SymLog=constants.mvPlotScale_SymLog
mvPlotMarker_None=constants.mvPlotMarker_None
mvPlotMarker_Circle=constants.mvPlotMarker_Circle
mvPlotMarker_Square=constants.mvPlotMarker_Square
mvPlotMarker_Diamond=constants.mvPlotMarker_Diamond
mvPlotMarker_Up=constants.mvPlotMarker_Up
mvPlotMarker_Down=constants.mvPlotMarker_Down
mvPlotMarker_Left=constants.mvPlotMarker_Left
mvPlotMarker_Right=constants.mvPlotMarker_Right
mvPlotMarker_Cross=constants.mvPlotMarker_Cross
mvPlotMarker_Plus=constants.mvPlotMarker_Plus
mvPlotMarker_Asterisk=constants.mvPlotMarker_Asterisk
mvPlot_Location_Center=constants.mvPlot_Location_Center
mvPlot_Location_North=constants.mvPlot_Location_North
mvPlot_Location_South=constants.mvPlot_Location_South
mvPlot_Location_West=constants.mvPlot_Location_West
mvPlot_Location_East=constants.mvPlot_Location_East
mvPlot_Location_NorthWest=constants.mvPlot_Location_NorthWest
mvPlot_Location_NorthEast=constants.mvPlot_Location_NorthEast
mvPlot_Location_SouthWest=constants.mvPlot_Location_SouthWest
mvPlot_Location_SouthEast=constants.mvPlot_Location_SouthEast
mvNodeMiniMap_Location_BottomLeft=constants.mvNodeMiniMap_Location_BottomLeft
mvNodeMiniMap_Location_BottomRight=constants.mvNodeMiniMap_Location_BottomRight
mvNodeMiniMap_Location_TopLeft=constants.mvNodeMiniMap_Location_TopLeft
mvNodeMiniMap_Location_TopRight=constants.mvNodeMiniMap_Location_TopRight
mvTable_SizingFixedFit=constants.mvTable_SizingFixedFit
mvTable_SizingFixedSame=constants.mvTable_SizingFixedSame
mvTable_SizingStretchProp=constants.mvTable_SizingStretchProp
mvTable_SizingStretchSame=constants.mvTable_SizingStretchSame
mvFormat_Float_rgba=constants.mvFormat_Float_rgba
mvFormat_Float_rgb=constants.mvFormat_Float_rgb
mvThemeCat_Core=constants.mvThemeCat_Core
mvThemeCat_Plots=constants.mvThemeCat_Plots
mvThemeCat_Nodes=constants.mvThemeCat_Nodes
mvThemeCol_Text=constants.mvThemeCol_Text
mvThemeCol_TextDisabled=constants.mvThemeCol_TextDisabled
mvThemeCol_WindowBg=constants.mvThemeCol_WindowBg
mvThemeCol_ChildBg=constants.mvThemeCol_ChildBg
mvThemeCol_Border=constants.mvThemeCol_Border
mvThemeCol_PopupBg=constants.mvThemeCol_PopupBg
mvThemeCol_BorderShadow=constants.mvThemeCol_BorderShadow
mvThemeCol_FrameBg=constants.mvThemeCol_FrameBg
mvThemeCol_FrameBgHovered=constants.mvThemeCol_FrameBgHovered
mvThemeCol_FrameBgActive=constants.mvThemeCol_FrameBgActive
mvThemeCol_TitleBg=constants.mvThemeCol_TitleBg
mvThemeCol_TitleBgActive=constants.mvThemeCol_TitleBgActive
mvThemeCol_TitleBgCollapsed=constants.mvThemeCol_TitleBgCollapsed
mvThemeCol_MenuBarBg=constants.mvThemeCol_MenuBarBg
mvThemeCol_ScrollbarBg=constants.mvThemeCol_ScrollbarBg
mvThemeCol_ScrollbarGrab=constants.mvThemeCol_ScrollbarGrab
mvThemeCol_ScrollbarGrabHovered=constants.mvThemeCol_ScrollbarGrabHovered
mvThemeCol_ScrollbarGrabActive=constants.mvThemeCol_ScrollbarGrabActive
mvThemeCol_CheckMark=constants.mvThemeCol_CheckMark
mvThemeCol_SliderGrab=constants.mvThemeCol_SliderGrab
mvThemeCol_SliderGrabActive=constants.mvThemeCol_SliderGrabActive
mvThemeCol_Button=constants.mvThemeCol_Button
mvThemeCol_ButtonHovered=constants.mvThemeCol_ButtonHovered
mvThemeCol_ButtonActive=constants.mvThemeCol_ButtonActive
mvThemeCol_Header=constants.mvThemeCol_Header
mvThemeCol_HeaderHovered=constants.mvThemeCol_HeaderHovered
mvThemeCol_HeaderActive=constants.mvThemeCol_HeaderActive
mvThemeCol_Separator=constants.mvThemeCol_Separator
mvThemeCol_SeparatorHovered=constants.mvThemeCol_SeparatorHovered
mvThemeCol_SeparatorActive=constants.mvThemeCol_SeparatorActive
mvThemeCol_ResizeGrip=constants.mvThemeCol_ResizeGrip
mvThemeCol_ResizeGripHovered=constants.mvThemeCol_ResizeGripHovered
mvThemeCol_ResizeGripActive=constants.mvThemeCol_ResizeGripActive
mvThemeCol_Tab=constants.mvThemeCol_Tab
mvThemeCol_TabHovered=constants.mvThemeCol_TabHovered
mvThemeCol_TabActive=constants.mvThemeCol_TabActive
mvThemeCol_TabUnfocused=constants.mvThemeCol_TabUnfocused
mvThemeCol_TabUnfocusedActive=constants.mvThemeCol_TabUnfocusedActive
mvThemeCol_DockingPreview=constants.mvThemeCol_DockingPreview
mvThemeCol_DockingEmptyBg=constants.mvThemeCol_DockingEmptyBg
mvThemeCol_PlotLines=constants.mvThemeCol_PlotLines
mvThemeCol_PlotLinesHovered=constants.mvThemeCol_PlotLinesHovered
mvThemeCol_PlotHistogram=constants.mvThemeCol_PlotHistogram
mvThemeCol_PlotHistogramHovered=constants.mvThemeCol_PlotHistogramHovered
mvThemeCol_TableHeaderBg=constants.mvThemeCol_TableHeaderBg
mvThemeCol_TableBorderStrong=constants.mvThemeCol_TableBorderStrong
mvThemeCol_TableBorderLight=constants.mvThemeCol_TableBorderLight
mvThemeCol_TableRowBg=constants.mvThemeCol_TableRowBg
mvThemeCol_TableRowBgAlt=constants.mvThemeCol_TableRowBgAlt
mvThemeCol_TextSelectedBg=constants.mvThemeCol_TextSelectedBg
mvThemeCol_DragDropTarget=constants.mvThemeCol_DragDropTarget
mvThemeCol_NavHighlight=constants.mvThemeCol_NavHighlight
mvThemeCol_NavWindowingHighlight=constants.mvThemeCol_NavWindowingHighlight
mvThemeCol_NavWindowingDimBg=constants.mvThemeCol_NavWindowingDimBg
mvThemeCol_ModalWindowDimBg=constants.mvThemeCol_ModalWindowDimBg
mvPlotCol_Line=constants.mvPlotCol_Line
mvPlotCol_Fill=constants.mvPlotCol_Fill
mvPlotCol_MarkerOutline=constants.mvPlotCol_MarkerOutline
mvPlotCol_MarkerFill=constants.mvPlotCol_MarkerFill
mvPlotCol_ErrorBar=constants.mvPlotCol_ErrorBar
mvPlotCol_FrameBg=constants.mvPlotCol_FrameBg
mvPlotCol_PlotBg=constants.mvPlotCol_PlotBg
mvPlotCol_PlotBorder=constants.mvPlotCol_PlotBorder
mvPlotCol_LegendBg=constants.mvPlotCol_LegendBg
mvPlotCol_LegendBorder=constants.mvPlotCol_LegendBorder
mvPlotCol_LegendText=constants.mvPlotCol_LegendText
mvPlotCol_TitleText=constants.mvPlotCol_TitleText
mvPlotCol_InlayText=constants.mvPlotCol_InlayText
mvPlotCol_AxisBg=constants.mvPlotCol_AxisBg
mvPlotCol_AxisBgActive=constants.mvPlotCol_AxisBgActive
mvPlotCol_AxisBgHovered=constants.mvPlotCol_AxisBgHovered
mvPlotCol_AxisGrid=constants.mvPlotCol_AxisGrid
mvPlotCol_AxisText=constants.mvPlotCol_AxisText
mvPlotCol_Selection=constants.mvPlotCol_Selection
mvPlotCol_Crosshairs=constants.mvPlotCol_Crosshairs
mvNodeCol_NodeBackground=constants.mvNodeCol_NodeBackground
mvNodeCol_NodeBackgroundHovered=constants.mvNodeCol_NodeBackgroundHovered
mvNodeCol_NodeBackgroundSelected=constants.mvNodeCol_NodeBackgroundSelected
mvNodeCol_NodeOutline=constants.mvNodeCol_NodeOutline
mvNodeCol_TitleBar=constants.mvNodeCol_TitleBar
mvNodeCol_TitleBarHovered=constants.mvNodeCol_TitleBarHovered
mvNodeCol_TitleBarSelected=constants.mvNodeCol_TitleBarSelected
mvNodeCol_Link=constants.mvNodeCol_Link
mvNodeCol_LinkHovered=constants.mvNodeCol_LinkHovered
mvNodeCol_LinkSelected=constants.mvNodeCol_LinkSelected
mvNodeCol_Pin=constants.mvNodeCol_Pin
mvNodeCol_PinHovered=constants.mvNodeCol_PinHovered
mvNodeCol_BoxSelector=constants.mvNodeCol_BoxSelector
mvNodeCol_BoxSelectorOutline=constants.mvNodeCol_BoxSelectorOutline
mvNodeCol_GridBackground=constants.mvNodeCol_GridBackground
mvNodeCol_GridLine=constants.mvNodeCol_GridLine
mvNodesCol_GridLinePrimary=constants.mvNodesCol_GridLinePrimary
mvNodesCol_MiniMapBackground=constants.mvNodesCol_MiniMapBackground
mvNodesCol_MiniMapBackgroundHovered=constants.mvNodesCol_MiniMapBackgroundHovered
mvNodesCol_MiniMapOutline=constants.mvNodesCol_MiniMapOutline
mvNodesCol_MiniMapOutlineHovered=constants.mvNodesCol_MiniMapOutlineHovered
mvNodesCol_MiniMapNodeBackground=constants.mvNodesCol_MiniMapNodeBackground
mvNodesCol_MiniMapNodeBackgroundHovered=constants.mvNodesCol_MiniMapNodeBackgroundHovered
mvNodesCol_MiniMapNodeBackgroundSelected=constants.mvNodesCol_MiniMapNodeBackgroundSelected
mvNodesCol_MiniMapNodeOutline=constants.mvNodesCol_MiniMapNodeOutline
mvNodesCol_MiniMapLink=constants.mvNodesCol_MiniMapLink
mvNodesCol_MiniMapLinkSelected=constants.mvNodesCol_MiniMapLinkSelected
mvNodesCol_MiniMapCanvas=constants.mvNodesCol_MiniMapCanvas
mvNodesCol_MiniMapCanvasOutline=constants.mvNodesCol_MiniMapCanvasOutline
mvStyleVar_Alpha=constants.mvStyleVar_Alpha
mvStyleVar_DisabledAlpha=constants.mvStyleVar_DisabledAlpha
mvStyleVar_WindowPadding=constants.mvStyleVar_WindowPadding
mvStyleVar_WindowRounding=constants.mvStyleVar_WindowRounding
mvStyleVar_WindowBorderSize=constants.mvStyleVar_WindowBorderSize
mvStyleVar_WindowMinSize=constants.mvStyleVar_WindowMinSize
mvStyleVar_WindowTitleAlign=constants.mvStyleVar_WindowTitleAlign
mvStyleVar_ChildRounding=constants.mvStyleVar_ChildRounding
mvStyleVar_ChildBorderSize=constants.mvStyleVar_ChildBorderSize
mvStyleVar_PopupRounding=constants.mvStyleVar_PopupRounding
mvStyleVar_PopupBorderSize=constants.mvStyleVar_PopupBorderSize
mvStyleVar_FramePadding=constants.mvStyleVar_FramePadding
mvStyleVar_FrameRounding=constants.mvStyleVar_FrameRounding
mvStyleVar_FrameBorderSize=constants.mvStyleVar_FrameBorderSize
mvStyleVar_ItemSpacing=constants.mvStyleVar_ItemSpacing
mvStyleVar_ItemInnerSpacing=constants.mvStyleVar_ItemInnerSpacing
mvStyleVar_IndentSpacing=constants.mvStyleVar_IndentSpacing
mvStyleVar_CellPadding=constants.mvStyleVar_CellPadding
mvStyleVar_ScrollbarSize=constants.mvStyleVar_ScrollbarSize
mvStyleVar_ScrollbarRounding=constants.mvStyleVar_ScrollbarRounding
mvStyleVar_GrabMinSize=constants.mvStyleVar_GrabMinSize
mvStyleVar_GrabRounding=constants.mvStyleVar_GrabRounding
mvStyleVar_TabRounding=constants.mvStyleVar_TabRounding
mvStyleVar_TabBorderSize=constants.mvStyleVar_TabBorderSize
mvStyleVar_TabBarBorderSize=constants.mvStyleVar_TabBarBorderSize
mvStyleVar_TableAngledHeadersAngle=constants.mvStyleVar_TableAngledHeadersAngle
mvStyleVar_TableAngledHeadersTextAlign=constants.mvStyleVar_TableAngledHeadersTextAlign
mvStyleVar_ButtonTextAlign=constants.mvStyleVar_ButtonTextAlign
mvStyleVar_SelectableTextAlign=constants.mvStyleVar_SelectableTextAlign
mvStyleVar_SeparatorTextBorderSize=constants.mvStyleVar_SeparatorTextBorderSize
mvStyleVar_SeparatorTextAlign=constants.mvStyleVar_SeparatorTextAlign
mvStyleVar_SeparatorTextPadding=constants.mvStyleVar_SeparatorTextPadding
mvStyleVar_DockingSeparatorSize=constants.mvStyleVar_DockingSeparatorSize
mvPlotStyleVar_LineWeight=constants.mvPlotStyleVar_LineWeight
mvPlotStyleVar_Marker=constants.mvPlotStyleVar_Marker
mvPlotStyleVar_MarkerSize=constants.mvPlotStyleVar_MarkerSize
mvPlotStyleVar_MarkerWeight=constants.mvPlotStyleVar_MarkerWeight
mvPlotStyleVar_FillAlpha=constants.mvPlotStyleVar_FillAlpha
mvPlotStyleVar_ErrorBarSize=constants.mvPlotStyleVar_ErrorBarSize
mvPlotStyleVar_ErrorBarWeight=constants.mvPlotStyleVar_ErrorBarWeight
mvPlotStyleVar_DigitalBitHeight=constants.mvPlotStyleVar_DigitalBitHeight
mvPlotStyleVar_DigitalBitGap=constants.mvPlotStyleVar_DigitalBitGap
mvPlotStyleVar_PlotBorderSize=constants.mvPlotStyleVar_PlotBorderSize
mvPlotStyleVar_MinorAlpha=constants.mvPlotStyleVar_MinorAlpha
mvPlotStyleVar_MajorTickLen=constants.mvPlotStyleVar_MajorTickLen
mvPlotStyleVar_MinorTickLen=constants.mvPlotStyleVar_MinorTickLen
mvPlotStyleVar_MajorTickSize=constants.mvPlotStyleVar_MajorTickSize
mvPlotStyleVar_MinorTickSize=constants.mvPlotStyleVar_MinorTickSize
mvPlotStyleVar_MajorGridSize=constants.mvPlotStyleVar_MajorGridSize
mvPlotStyleVar_MinorGridSize=constants.mvPlotStyleVar_MinorGridSize
mvPlotStyleVar_PlotPadding=constants.mvPlotStyleVar_PlotPadding
mvPlotStyleVar_LabelPadding=constants.mvPlotStyleVar_LabelPadding
mvPlotStyleVar_LegendPadding=constants.mvPlotStyleVar_LegendPadding
mvPlotStyleVar_LegendInnerPadding=constants.mvPlotStyleVar_LegendInnerPadding
mvPlotStyleVar_LegendSpacing=constants.mvPlotStyleVar_LegendSpacing
mvPlotStyleVar_MousePosPadding=constants.mvPlotStyleVar_MousePosPadding
mvPlotStyleVar_AnnotationPadding=constants.mvPlotStyleVar_AnnotationPadding
mvPlotStyleVar_FitPadding=constants.mvPlotStyleVar_FitPadding
mvPlotStyleVar_PlotDefaultSize=constants.mvPlotStyleVar_PlotDefaultSize
mvPlotStyleVar_PlotMinSize=constants.mvPlotStyleVar_PlotMinSize
mvNodeStyleVar_GridSpacing=constants.mvNodeStyleVar_GridSpacing
mvNodeStyleVar_NodeCornerRounding=constants.mvNodeStyleVar_NodeCornerRounding
mvNodeStyleVar_NodePadding=constants.mvNodeStyleVar_NodePadding
mvNodeStyleVar_NodeBorderThickness=constants.mvNodeStyleVar_NodeBorderThickness
mvNodeStyleVar_LinkThickness=constants.mvNodeStyleVar_LinkThickness
mvNodeStyleVar_LinkLineSegmentsPerLength=constants.mvNodeStyleVar_LinkLineSegmentsPerLength
mvNodeStyleVar_LinkHoverDistance=constants.mvNodeStyleVar_LinkHoverDistance
mvNodeStyleVar_PinCircleRadius=constants.mvNodeStyleVar_PinCircleRadius
mvNodeStyleVar_PinQuadSideLength=constants.mvNodeStyleVar_PinQuadSideLength
mvNodeStyleVar_PinTriangleSideLength=constants.mvNodeStyleVar_PinTriangleSideLength
mvNodeStyleVar_PinLineThickness=constants.mvNodeStyleVar_PinLineThickness
mvNodeStyleVar_PinHoverRadius=constants.mvNodeStyleVar_PinHoverRadius
mvNodeStyleVar_PinOffset=constants.mvNodeStyleVar_PinOffset
mvNodesStyleVar_MiniMapPadding=constants.mvNodesStyleVar_MiniMapPadding
mvNodesStyleVar_MiniMapOffset=constants.mvNodesStyleVar_MiniMapOffset

mvInputText=dcg.theme_categories.t_inputtext
mvButton=dcg.theme_categories.t_button
mvRadioButton=dcg.theme_categories.t_radiobutton
#mvTabBar=constants.mvTabBar
#mvTab=constants.mvTab
mvImage=dcg.theme_categories.t_image
mvMenuBar=dcg.theme_categories.t_menubar
mvViewportMenuBar=dcg.theme_categories.t_menubar
mvMenu=dcg.theme_categories.t_menu
mvMenuItem=dcg.theme_categories.t_menuitem
#mvChildWindow=constants.mvChildWindow
mvGroup=dcg.theme_categories.t_group
mvSliderFloat=dcg.theme_categories.t_slider
mvSliderInt=dcg.theme_categories.t_slider
mvFilterSet=dcg.theme_categories.t_slider
mvDragFloat=dcg.theme_categories.t_slider
mvDragInt=dcg.theme_categories.t_slider
mvInputFloat=dcg.theme_categories.t_inputvalue
mvInputInt=dcg.theme_categories.t_inputvalue
#mvColorEdit=constants.mvColorEdit
#mvClipper=constants.mvClipper
#mvColorPicker=constants.mvColorPicker
mvTooltip=dcg.theme_categories.t_tooltip
#mvCollapsingHeader=constants.mvCollapsingHeader
#mvSeparator=constants.mvSeparator
mvCheckbox=dcg.theme_categories.t_checkbox
mvListbox=dcg.theme_categories.t_listbox
mvText=dcg.theme_categories.t_text
mvCombo=dcg.theme_categories.t_combo
#mvPlot=constants.mvPlot
mvSimplePlot=dcg.theme_categories.t_simpleplot
#mvDrawlist=constants.mvDrawlist
#mvWindowAppItem=constants.mvWindowAppItem
mvSelectable=dcg.theme_categories.t_selectable
#mvTreeNode=constants.mvTreeNode
mvProgressBar=dcg.theme_categories.t_progressbar
#mvSpacer=constants.mvSpacer
mvImageButton=dcg.theme_categories.t_imagebutton
#mvTimePicker=constants.mvTimePicker
#mvDatePicker=constants.mvDatePicker
#mvColorButton=constants.mvColorButton
#mvFileDialog=constants.mvFileDialog
mvTabButton=dcg.theme_categories.t_tabbutton
#mvDrawNode=constants.mvDrawNode
#mvNodeEditor=constants.mvNodeEditor
#mvNode=constants.mvNode
#mvNodeAttribute=constants.mvNodeAttribute
#mvTable=constants.mvTable
#mvTableColumn=constants.mvTableColumn
#mvTableRow=constants.mvTableRow
#mvDrawLine=constants.mvDrawLine
#mvDrawArrow=constants.mvDrawArrow
#mvDrawTriangle=constants.mvDrawTriangle
#mvDrawImageQuad=constants.mvDrawImageQuad
#mvDrawCircle=constants.mvDrawCircle
#mvDrawEllipse=constants.mvDrawEllipse
#mvDrawBezierCubic=constants.mvDrawBezierCubic
#mvDrawBezierQuadratic=constants.mvDrawBezierQuadratic
#mvDrawQuad=constants.mvDrawQuad
#mvDrawRect=constants.mvDrawRect
#mvDrawText=constants.mvDrawText
#mvDrawPolygon=constants.mvDrawPolygon
#mvDrawPolyline=constants.mvDrawPolyline
#mvDrawImage=constants.mvDrawImage
#mvDragFloatMulti=constants.mvDragFloatMulti
#mvDragIntMulti=constants.mvDragIntMulti
mvSliderFloatMulti=dcg.theme_categories.t_slider
mvSliderIntMulti=dcg.theme_categories.t_slider
mvInputIntMulti=dcg.theme_categories.t_inputvalue
mvInputFloatMulti=dcg.theme_categories.t_inputvalue
"""
mvDragPoint=constants.mvDragPoint
mvDragLine=constants.mvDragLine
mvDragRect=constants.mvDragRect
mvAnnotation=constants.mvAnnotation
mvAxisTag=constants.mvAxisTag
mvLineSeries=constants.mvLineSeries
mvScatterSeries=constants.mvScatterSeries
mvStemSeries=constants.mvStemSeries
mvStairSeries=constants.mvStairSeries
mvBarSeries=constants.mvBarSeries
mvBarGroupSeries=constants.mvBarGroupSeries
mvErrorSeries=constants.mvErrorSeries
mvInfLineSeries=constants.mvInfLineSeries
mvHeatSeries=constants.mvHeatSeries
mvImageSeries=constants.mvImageSeries
mvPieSeries=constants.mvPieSeries
mvShadeSeries=constants.mvShadeSeries
mvLabelSeries=constants.mvLabelSeries
mvHistogramSeries=constants.mvHistogramSeries
mvDigitalSeries=constants.mvDigitalSeries
mv2dHistogramSeries=constants.mv2dHistogramSeries
mvCandleSeries=constants.mvCandleSeries
mvAreaSeries=constants.mvAreaSeries
mvColorMapScale=constants.mvColorMapScale
mvSlider3D=constants.mvSlider3D
mvKnobFloat=constants.mvKnobFloat
mvLoadingIndicator=constants.mvLoadingIndicator
mvNodeLink=constants.mvNodeLink
mvTextureRegistry=constants.mvTextureRegistry
mvStaticTexture=constants.mvStaticTexture
mvDynamicTexture=constants.mvDynamicTexture
mvStage=constants.mvStage
mvDrawLayer=constants.mvDrawLayer
mvViewportDrawlist=constants.mvViewportDrawlist
mvFileExtension=constants.mvFileExtension
mvPlotLegend=constants.mvPlotLegend
mvPlotAxis=constants.mvPlotAxis
mvHandlerRegistry=constants.mvHandlerRegistry
mvKeyDownHandler=constants.mvKeyDownHandler
mvKeyPressHandler=constants.mvKeyPressHandler
mvKeyReleaseHandler=constants.mvKeyReleaseHandler
mvMouseMoveHandler=constants.mvMouseMoveHandler
mvMouseWheelHandler=constants.mvMouseWheelHandler
mvMouseClickHandler=constants.mvMouseClickHandler
mvMouseDoubleClickHandler=constants.mvMouseDoubleClickHandler
mvMouseDownHandler=constants.mvMouseDownHandler
mvMouseReleaseHandler=constants.mvMouseReleaseHandler
mvMouseDragHandler=constants.mvMouseDragHandler
mvHoverHandler=constants.mvHoverHandler
mvActiveHandler=constants.mvActiveHandler
mvFocusHandler=constants.mvFocusHandler
mvVisibleHandler=constants.mvVisibleHandler
mvEditedHandler=constants.mvEditedHandler
mvActivatedHandler=constants.mvActivatedHandler
mvDeactivatedHandler=constants.mvDeactivatedHandler
mvDeactivatedAfterEditHandler=constants.mvDeactivatedAfterEditHandler
mvToggledOpenHandler=constants.mvToggledOpenHandler
mvClickedHandler=constants.mvClickedHandler
mvDoubleClickedHandler=constants.mvDoubleClickedHandler
mvDragPayload=constants.mvDragPayload
mvResizeHandler=constants.mvResizeHandler
mvFont=constants.mvFont
mvFontRegistry=constants.mvFontRegistry
mvTheme=constants.mvTheme
mvThemeColor=constants.mvThemeColor
mvThemeStyle=constants.mvThemeStyle
mvThemeComponent=constants.mvThemeComponent
mvFontRangeHint=constants.mvFontRangeHint
mvFontRange=constants.mvFontRange
mvFontChars=constants.mvFontChars
mvCharRemap=constants.mvCharRemap
mvValueRegistry=constants.mvValueRegistry
mvIntValue=constants.mvIntValue
mvFloatValue=constants.mvFloatValue
mvFloat4Value=constants.mvFloat4Value
mvInt4Value=constants.mvInt4Value
mvBoolValue=constants.mvBoolValue
mvStringValue=constants.mvStringValue
mvDoubleValue=constants.mvDoubleValue
mvDouble4Value=constants.mvDouble4Value
mvColorValue=constants.mvColorValue
mvFloatVectValue=constants.mvFloatVectValue
mvSeriesValue=constants.mvSeriesValue
mvRawTexture=constants.mvRawTexture
mvSubPlots=constants.mvSubPlots
mvColorMap=constants.mvColorMap
mvColorMapRegistry=constants.mvColorMapRegistry
mvColorMapButton=constants.mvColorMapButton
mvColorMapSlider=constants.mvColorMapSlider
mvTemplateRegistry=constants.mvTemplateRegistry
"""
#mvTableCell=constants.mvTableCell
#mvItemHandlerRegistry=constants.mvItemHandlerRegistry
mvInputDouble=dcg.theme_categories.t_inputvalue
mvInputDoubleMulti=dcg.theme_categories.t_inputvalue
mvDragDouble=dcg.theme_categories.t_slider
mvDragDoubleMulti=dcg.theme_categories.t_slider
mvSliderDouble=dcg.theme_categories.t_slider
mvSliderDoubleMulti=dcg.theme_categories.t_slider
#mvCustomSeries=constants.mvCustomSeries

mvReservedUUID_0=constants.mvReservedUUID_0
mvReservedUUID_1=constants.mvReservedUUID_1
mvReservedUUID_2=constants.mvReservedUUID_2
mvReservedUUID_3=constants.mvReservedUUID_3
mvReservedUUID_4=constants.mvReservedUUID_4
mvReservedUUID_5=constants.mvReservedUUID_5
mvReservedUUID_6=constants.mvReservedUUID_6
mvReservedUUID_7=constants.mvReservedUUID_7
mvReservedUUID_8=constants.mvReservedUUID_8
mvReservedUUID_9=constants.mvReservedUUID_9
mvReservedUUID_10=constants.mvReservedUUID_10
