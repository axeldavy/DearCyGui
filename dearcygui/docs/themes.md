# Themes

## ThemeColor and ThemeStyle

**ImGui** is the main library used to render items. The appearance of many items,
as well as the style, and various spacing behaviours can be tuned using themes.
**ImPlot** is used to render plots.

- `ThemeColorImGui` enables to change the color of most objects
- `ThemeColorImPlot` enables to change the color of plot items
- `ThemeStyleImGui` enables to change the style and spacing of most items
- `ThemeStyleImPlot` enables to change the style and spacing of plots

By default all values passed, as well as default values, are scaled by the global scale, and rounded to an
integer when it makes sense. This can be disabled using `no_scaling` and `no_rounding`.

Values set in a theme instance are meant to replace any previous value currently set in the rendering tree.
When a theme is attached to an item, the values are replayed when the item is rendered, and the item,
as well as all its children will use these theme values (unless another theme is applied).

It is possible with `ThemeListWithCondition` to define a theme that will be only applied for children when a specific type of
item is found. However it is encouraged not to use them if possible for performance reasons, as every time an item is rendered,
all conditions will be checked. In addition, it is preferred to attach a theme to as few items as possible, in order to avoid
rewriting the values when not needed. Finally if you attach themes to many items, try to only set in them the values that
will impact these items.

```python
my_theme = dcg.ThemeStyleImGui(FramePadding=(0, 0))
...
item.theme = my_theme
...
my_theme.WindowRounding = 1 # adding a new setting in the theme
...
my_theme.WindowRounding = None # Removing a setting from the theme
...
my_theme[dcg.constants.WindowRounding] = 1 # alternative syntax
```

***

# Fonts

## The default font

The default font uses the Latex Latin Modern font at size 17, scaled by the global scale.
It combines several fonts in order to provide in a single font `bold`, *italics* and **bold-italics**.
The advantage of combining fonts into one is to benefit from text wrapping, as it is not needed
to issue several Text() calls. In addition combining fonts needs special centering and sizing.

## The default font at different sizes

New instances of the default font can be created using the *fonts* module
```python
import dearcygui as dcg

font_texture = dcg.FontTexture(C)
global_scale = C.viewport.dpi * C.viewport.scale
my_new_font_data = dcg.fonts.make_extended_latin_font(round(global_scale * my_new_size))
font_texture.add_custom_font(*my_new_font_data)
font_texture.build()
my_new_font = font_texture[0]
my_new_font.scale = 1./global_scale

my_item.font = my_new_font
```

The above example also shows you one way of handling dpi scaling properly, and get
sharp fonts on various displays.

The `dearcygui.fonts` module also provides some helpers to load new fonts and combining new ones.
In order to make bold/italics/bold-italics texts, it provides the unicode helpers `make_bold`,
`make_italic` and `make_bold_italic`.

## Simplest and fastest way of loading a font

To load a font, you need to load it in a `FontTexture`
```python

font_texture = dcg.FontTexture(C)
font_texture.add_font_file(path)
font_texture.build()
my_new_font = font_texture[0]
```

This is simple and fast (it uses **ImGui** directly), but as of writing it has its share
of imperfections.

## The better way of loading a font

```python

# Prepare the font texture
font_texture = dcg.FontTexture(C)
# Scale the size during glyph rendering
global_scale = C.viewport.dpi * C.viewport.scale
# Load the font glyphs and render them
# see load_font for various modes that impact
# how the glyphs are rendered.
height, character_images, character_positioning, target_origin_y = dcg.fonts.load_font(path, target_size=round(my_size*global_scale))
# Center properly the font glyphs
height, character_positionings, target_origin_y = dcg.fonts.center_font(height, character_positionings, target_origin_y)
# If your font contains some huge characters
# you might want to reduce the reserved vertical space
# with fit_font_to_new_height
# Load the texture data
font_texture.add_custom_font(height, character_images, character_positioning)
font_texture.build()
my_new_font = font_texture[0]
# The font is already scaled
my_new_font.scale = 1./global_scale
```

This will give you the best visual results. `make_extended_latin_font` is a helper that
performs the described operation and in addition aligns the merged fonts.

## Make your own font

The **fonts.py** in the source code gives you various helps and explanations on what is needed
to build a custom font. 