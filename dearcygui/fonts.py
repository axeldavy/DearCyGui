"""
Loading a font is complicated.

This file proposes some helpers to load a font in a format
that DearCyGui can use. You can adapt to your needs.

What DearCyGui needs to render a text:
- A texture (RGBA or just Alpha) containing the font
- Correspondance between the unicode characters and where
  the character is in the texture.
- Correspondance between the unicode characters and their size
  and position when rendered (for instance A and g usually do not start
  and stop at the same coordinates).
- The vertical spacing taken by the font when rendered. It corresponds
  to the height of the box that will be allocated in the UI elements
  to the text.
- The horizontal spacing between the end of a character and the start of a
  new one. Note that some fonts have a different spacing depending on the pair
  of characters (it is called kerning), but it is not supported yet.

What is up to you to provide:
- Rendered bitmaps of your characters, at the target scale. Basically for
  good quality rendering, you should try to ensure that the size
  of the character when rendered is the same as the size in the bitmap.
  The size of the rendered character is affected by the rendering scale
  (screen dpi scale, window scale, plot scale, etc).
- Passing correct spacing value to have characters properly aligned, etc
"""

import freetype
import freetype.raw
import os
import numpy as np

class GlyphSet:
    """Container for font glyph data with convenient access methods"""
    def __init__(self, height: int, images: dict, positioning: dict, origin_y: int):
        self.height = height
        self.images = images 
        self.positioning = positioning
        self.origin_y = origin_y

    def get_raw_data(self) -> tuple[int, dict, dict, int]:
        """Get original data format as (height, character_images, character_positioning, target_origin_y)

        Outputs:
        --------
        height: The minimal vertical space to allocate for text
            such that all font characters can be rendered properly.
            Might be slightly different to target_pixel_height, as
            the scaling determined by target_pixel_height uses
            global font statistics. You may call fit_font_to_new_height,
            if you need to force a specific vertical spacing.
        character_images:
            a dict mapping integers (UTF-8 code) to their rendered
            character (numpy uint8 array: h, w, c)
        character_positioning:
            a dict mapping integers (UTF-8 code) to the positioning
            information for the rendered character. Each value
            consists in a pair of three elements: (dy, dx, advance)
            - dy is the coordinate of the topmost pixel of the
            character image relative to the drawing cursor,
            in a coordinate system where y increases when
            we go down, and the drawing cursor is at the top
            of the intended character position.
            - dx is the coordinate of the leftmost pixel of the
            character image relative to the drawing cursor.
            - advance corresponds to the number of pixels horizontally
            the drawing cursor should be moved to draw the next 
            character.
        target_origin_y:
            This is the coordinate from the position of the drawing
            cursor (top of the text region) of the base of the characters
            (bottom of an 'A'), in a coordinate system where y increases
            when going down. Useful if you need to merge fonts, or want
            to add special effects manually (underline, etc)
        
        """
        return self.height, self.images, self.positioning, self.origin_y

    def get_glyph(self, char: str) -> tuple[np.ndarray, tuple[int, int, int]] | None:
        """Get image and positioning data for a single character"""
        if not char or len(char) != 1:
            return None
        key = ord(char)
        if key not in self.images:
            return None
        return self.images[key], self.positioning[key]

    def get_glyph_image(self, char: str) -> np.ndarray | None:
        """Get just the image data for a single character"""
        result = self.get_glyph(char)
        return result[0] if result else None

    def get_glyph_metrics(self, char: str) -> tuple[int, int, int] | None:
        """Get just the positioning data for a single character"""
        result = self.get_glyph(char)
        return result[1] if result else None

    def get_glyph_vertical_offset(self, char: str) -> int | None:
        """Get vertical offset (dy) from text cursor position to glyph top"""
        metrics = self.get_glyph_metrics(char)
        return metrics[0] if metrics else None
        
    def get_glyph_horizontal_offset(self, char: str) -> int | None:
        """Get horizontal offset (dx) from text cursor to glyph left edge"""
        metrics = self.get_glyph_metrics(char)
        return metrics[1] if metrics else None

    def get_glyph_advance(self, char: str) -> int | None:
        """Get horizontal advance (pixels) to next character position"""
        metrics = self.get_glyph_metrics(char)
        return metrics[2] if metrics else None
        
    def get_glyph_dimensions(self, char: str) -> tuple[int, int] | None:
        """Get glyph bitmap dimensions as (height, width)"""
        image = self.get_glyph_image(char)
        if image is None:
            return None
        return image.shape[:2]
        
    def get_glyph_baseline(self, char: str) -> tuple[int, int] | None:
        """Get glyph baseline position relative to text cursor.
        
        Returns (x,y) coordinate of glyph origin (intersection of baseline and
        leftmost edge) relative to text cursor position, where:
        - Positive y is downward
        - Returns None if character not found
        """
        if not char or len(char) != 1:
            return None
        metrics = self.get_glyph_metrics(char)
        if metrics is None:
            return None
        dy, dx, _ = metrics
        return dx, self.origin_y - dy

    def get_font_metrics(self) -> tuple[int, int]:
        """Get global font metrics.
        
        Returns:
        --------
        height: Total height needed to render any character
        baseline: Y coordinate of baseline measured from top 
        """
        return self.height, self.origin_y

class FontLoader:
    """A class that manages font loading and text rendering"""
    def __init__(self, path):
        if not os.path.exists(path):
            raise ValueError(f"Font file {path} not found")
        self.face = freetype.Face(path)
        if self.face is None:
            raise ValueError("Failed to open the font")
            

    def _prepare_load_flags(self, hinter, allow_color) -> int:
        """Prepare FreeType loading flags"""

        """
        Prepare rendering flags
        Available flags are:
        freetype.FT_LOAD_FLAGS["FT_LOAD_NO_BITMAP"]:
            When a font contains pre-rendered bitmaps,
            ignores them instead of using them when the
            requested size is a perfect match.
        freetype.FT_LOAD_FLAGS["FT_LOAD_NO_HINTING"]:
            Disables "hinting", which is an algorithm
            to improve the sharpness of fonts.
            Small sizes may render blurry with this flag.
        freetype.FT_LOAD_FLAGS["FT_LOAD_FORCE_AUTOHINT"]:
            Ignores the font encapsulated hinting, and
            replace it with a general one. Useful for fonts
            with non-optimized hinting.
        freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]:
            Default font rendering with gray levels
        freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_LIGHT"]:
            Used with FT_LOAD_FORCE_AUTOHINT to use
            a variant of the general hinter that is less
            sharp, but respects more the original shape
            of the font.
        freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_MONO"]:
            The hinting is optimized to render monochrome
            targets (no blur/antialiasing).
            Should be set with
            freetype.FT_LOAD_TARGETS["FT_LOAD_MONOCHROME"].
        Other values exist but you'll likely not need them.
        """
        
        load_flags = 0
        if hinter == "none":
            load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]
            load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_NO_HINTING"]
            load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_NO_AUTOHINT"]
        elif hinter == "font":
            load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]
        elif hinter == "light":
            load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_LIGHT"]
            load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_FORCE_AUTOHINT"]
        elif hinter == "strong":
            load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]
            load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_FORCE_AUTOHINT"]
        elif hinter == "monochrome":
            load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_MONO"]
            load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_MONOCHROME"]
        else:
            raise ValueError("Invalid hinter. Must be none, font, light, strong or monochrome")

        if allow_color:
            load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_COLOR"]
            
        return load_flags

    def render_text_to_array(self, text: str,
                             target_size : int,
                             align_to_pixels=True,
                             enable_kerning=True,
                             hinter="light",
                             allow_color=True) -> tuple[np.ndarray, int]:
        """Render text string to a numpy array and return the array and bitmap_top"""
        self.face.set_pixel_sizes(0, int(round(target_size)))

        load_flags = self._prepare_load_flags(hinter, allow_color)

        # Calculate rough dimensions for initial buffer
        rough_width, rough_height, _, _ = self._calculate_text_dimensions(
            text, load_flags, align_to_pixels, enable_kerning
        )
        
        # Add margins to prevent overflow
        margin = target_size
        height = int(np.ceil(rough_height)) + 2 * margin
        width = int(np.ceil(rough_width)) + 2 * margin
        
        # Create output image array with margins
        image = np.zeros((height, width, 4), dtype=np.uint8)
        
        # Track actual bounds with local variables
        min_x = float('inf')
        max_x = float('-inf')
        min_y = float('inf')
        max_y = float('-inf')
        max_top = float('-inf')
        
        # Render each character
        x_offset = margin
        y_offset = margin
        previous_char = None
        kerning_mode = freetype.FT_KERNING_DEFAULT if align_to_pixels else freetype.FT_KERNING_UNFITTED
        
        for char in text:
            self.face.load_char(char, flags=load_flags)
            glyph = self.face.glyph
            bitmap = glyph.bitmap
            
            if enable_kerning and previous_char is not None:
                kerning = self.face.get_kerning(previous_char, char, mode=kerning_mode)
                x_offset += kerning.x / 64.0

            # Update bounds
            min_x = min(min_x, x_offset)
            max_x = max(max_x, x_offset + bitmap.width)
            min_y = min(min_y, y_offset + bitmap.rows - glyph.bitmap_top)
            max_y = max(max_y, y_offset + bitmap.rows)
            max_top = max(max_top, glyph.bitmap_top)

            self._render_glyph_to_image(glyph, image, x_offset, y_offset, align_to_pixels)

            if align_to_pixels:
                x_offset += round(glyph.advance.x/64)
            else:
                x_offset += glyph.linearHoriAdvance/65536
            previous_char = char

        # Handle empty text
        if min_x == float('inf'):
            return np.zeros((1, 1, 4), dtype=np.uint8), 0

        # Crop to actual content plus small margin
        crop_margin = 2
        min_x = max(int(min_x) - crop_margin, 0)
        min_y = max(int(min_y) - crop_margin, 0)
        max_x = min(int(np.ceil(max_x)) + crop_margin, width)
        max_y = min(int(np.ceil(max_y)) + crop_margin, height)

        return image[min_y:max_y, min_x:max_x], max_top

    def _calculate_text_dimensions(self, text: str, load_flags : int, align_to_pixels: bool, enable_kerning: bool):
        """Calculate the dimensions needed for the text"""
        width, max_top, max_bottom = 0, 0, 0
        previous_char = None
        kerning_mode = freetype.FT_KERNING_DEFAULT if align_to_pixels else freetype.FT_KERNING_UNFITTED
        
        for char in text:
            self.face.load_char(char, flags=load_flags)
            glyph = self.face.glyph
            bitmap = glyph.bitmap
            top = glyph.bitmap_top
            bottom = bitmap.rows - top
            max_top = max(max_top, top)
            max_bottom = max(max_bottom, bottom)
            
            if align_to_pixels:
                width += glyph.advance.x/64
            else:
                width += glyph.linearHoriAdvance/65536
                
            if enable_kerning and previous_char is not None:
                kerning = self.face.get_kerning(previous_char, char, mode=kerning_mode)
                width += kerning.x / 64.0
            previous_char = char
            
        return width, max_top + max_bottom, max_top, max_bottom

    def _render_glyph_to_image(self, glyph, image, x_offset, y_offset, align_to_pixels):
        """Render a single glyph to the image array"""
        if glyph.format == freetype.FT_GLYPH_FORMAT_BITMAP:
            bitmap = glyph.bitmap
            self._copy_bitmap_to_image(bitmap, image, x_offset, y_offset)
        else:
            # Handle non-bitmap glyphs
            if not align_to_pixels:
                subpixel_offset = freetype.FT_Vector(
                    int((x_offset - float(int(x_offset))) * 64), 0
                )
                gglyph = glyph.get_glyph()
                bglyph = gglyph.to_bitmap(freetype.FT_RENDER_MODE_NORMAL, subpixel_offset, True)
                self._copy_bitmap_to_image(bglyph.bitmap, image, x_offset, y_offset)

    def _copy_bitmap_to_image(self, bitmap, image, x_offset, y_offset):
        """Copy bitmap data to the image array"""
        for y in range(bitmap.rows):
            for x in range(bitmap.width):
                if bitmap.pixel_mode == freetype.FT_PIXEL_MODE_GRAY:
                    image[y + y_offset, int(x + x_offset), 3] = bitmap.buffer[y * bitmap.pitch + x]
                elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_BGRA:
                    image[y + y_offset, int(x + x_offset), :] = bitmap.buffer[
                        y * bitmap.pitch + x * 4:(y + 1) * bitmap.pitch + x * 4
                    ]

    def get_glyphs_bitmaps(self,
                           target_pixel_height=None,
                           target_size=0,
                           hinter="light",
                           restrict_to=None,
                           allow_color=True) -> GlyphSet:
        """
        Render the glyphs of the font at the target scale.

        Inputs:
        -------
        target_pixel_height: if set, scale the characters to match
            this height in pixels. The height here, refers to the
            distance between the maximum top of a character,
            and the minimum bottom of the character, when properly
            aligned.
        target_size: if set, scale the characters to match the
            font 'size' by scaling the pixel size at the 'nominal'
            value (default size of the font).
        hinter: "font", "none", "light", "strong" or "monochrome".
            The hinter is the rendering algorithm that
            impacts a lot the aspect of the characters,
            especially at low scales, to make them
            more readable. "none" will simply render
            at the target scale without any specific technique.
            "font" will use the font guidelines, but the result
            will depend on the quality of these guidelines.
            "light" will try to render sharp characters, while
            attempting to preserve the original shapes.
            "strong" attemps to render very sharp characters,
            even if the shape may be altered.
            "monochrome" will render extremely sharp characters,
            using only black and white pixels.
        restrict_to: set of ints that contains the unicode characters
            that should be loaded. If None, load all the characters
            available.
        allow_color: If the font contains colored glyphs, this enables
            to render them in color.

        Outputs:
        --------
        GlyphSet object containing the rendered characters.

        """

        # Indicate the target scale
        if target_pixel_height is not None:
            assert(False)# TODO
            #req = freetype.raw.FT_Size_Re
            #freetype.raw.FT_Request_Size(face, req)
        else:
            self.face.set_pixel_sizes(0, int(round(target_size)))

        load_flags = self._prepare_load_flags(hinter, allow_color)

        # global metrics for the target size, approximative
        # global_metrics : freetype.SizeMetrics = face.metrics

        character_images = {}
        character_positioning = {}
        unicode_to_glyph = {}

        # Retrieve the rendered characters
        for unicode_key, glyph_index in self.face.get_chars():
            if (restrict_to is not None) and (unicode_key not in restrict_to):
                continue
            # TODO: double check the unicode key is UTF-8
            unicode_to_glyph[unicode_key] = glyph_index
            # Render internally at the target scale
            self.face.load_glyph(glyph_index, flags=load_flags)
            glyph : freetype.GlyphSlot = self.face.glyph
            if hinter == "monochrome":
                glyph.render(freetype.FT_RENDER_MODES["FT_RENDER_MODE_MONO"])
            elif hinter == "light":
                glyph.render(freetype.FT_RENDER_MODES["FT_RENDER_MODE_LIGHT"])
            else:
                glyph.render(freetype.FT_RENDER_MODES["FT_RENDER_MODE_NORMAL"])
            # Retrieve the bitmap from it
            bitmap : freetype.Bitmap = glyph.bitmap
            # Positioning metrics
            metric : freetype.FT_Glyph_Metrics = glyph.metrics
            # positioning relative to the next pixel

            # lsb is the subpixel offset of our origin compared to the previous advance
            # rsb is the subpixel offset of the next origin compared to our origin
            # horiadvance is the horizontal displacement between
            # our origin and the next one

            assert(glyph.advance.x == metric.horiAdvance)
            advance =  (glyph._FT_GlyphSlot.contents.lsb_delta - glyph._FT_GlyphSlot.contents.rsb_delta + metric.horiAdvance) / 64.
            # Currently the backend does not support rounding the advance when rendering
            # the font (which would enable best support for lsb and rsb), thus we pre-round.
            advance = round(advance)
            # distance from our origin of the top
            bitmap_top = glyph.bitmap_top
            # distance from our origin of the left
            bitmap_left = glyph.bitmap_left
            # Other modes not supported below, but could be added.
            assert(bitmap.pixel_mode in [freetype.FT_PIXEL_MODE_GRAY,
                                        freetype.FT_PIXEL_MODE_MONO,
                                        freetype.FT_PIXEL_MODE_BGRA])

            if bitmap.rows == 0 or bitmap.width == 0:
                # empty characters, such as space
                image = np.zeros([1, 1, 1], dtype=np.uint8)
                bitmap_top=0
                bitmap_left=0
            elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_MONO:
                # monochrome 1-bit data
                image = 255*np.unpackbits(np.array(bitmap.buffer, dtype=np.uint8), count=bitmap.rows * 8*bitmap.pitch).reshape([bitmap.rows, 8*bitmap.pitch])
                image = image[:, :bitmap.width, np.newaxis]
            elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_GRAY:
                image = np.array(bitmap.buffer, dtype=np.uint8).reshape([bitmap.rows, bitmap.pitch])
                image = image[:, :bitmap.width, np.newaxis]
            elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_BGRA:
                image = np.array(bitmap.buffer, dtype=np.uint8).reshape([bitmap.rows, bitmap.pitch//4, 4])
                image = image[:, :bitmap.width, :]
                # swap B and R
                image[:, :, [0, 2]] = image[:, :, [2, 0]]

            character_images[unicode_key] = image
            character_positioning[unicode_key] = (bitmap_top, bitmap_left, advance)

        # Compute font height
        max_bitmap_top = 0
        max_bitmap_bot = 0
        for (image, (bitmap_top, _, _)) in zip(character_images.values(), character_positioning.values()):
            h = image.shape[0]
            max_bitmap_top = max(max_bitmap_top, bitmap_top)
            max_bitmap_bot = max(max_bitmap_bot, h - bitmap_top)

        height = max_bitmap_top + max_bitmap_bot + 1

        # Convert positioning data to the correct coordinate system
        target_origin_y = max_bitmap_top

        character_positioning_prev = character_positioning
        character_positioning = {}
        for (key, (bitmap_top, bitmap_left, advance)) in character_positioning_prev.items():
            character_positioning[key] = (target_origin_y-bitmap_top, bitmap_left, advance)

        return GlyphSet(height, character_images, character_positioning, target_origin_y)

def fit_font_to_new_height(target_height, height, character_positioning, target_origin=None):
    """
    Given the results of the call
    (height, character_image, character_positioning) = load_font(...),
    Change the character positioning data to be compatible to being
    rendered at target_height.
    Returns the updated character_positioning. 
    If you pass target_origin, returns as well the updated target_origin.
    """
    # Center the font around the new height
    pad = round((target_height-height)/2)
    updated_character_positioning = pad_font_top(character_positioning, pad)
    if target_origin is None:
        return updated_character_positioning
    else:
        return updated_character_positioning, target_origin+pad

def pad_font_top(character_positioning, pad):
    """
    Shift all the characters from the top origin by adding
    empty pixels
    """
    character_positioning_prev = character_positioning
    character_positioning = {}
    for (key, (dy, dx, advance)) in character_positioning_prev.items():
        character_positioning[key] = (dy + pad, dx, advance)
    return character_positioning

def align_fonts(heights, character_positionings, target_origins):
    """
    Given list of heights and a list of positioning data and origins,
    align the fonts to have a common origin.
    returns the new height, the list of updated positionings,
    as well as the new target_origin.
    """
    # find extremum positioning
    # in a top-down coordinate system centered on the bottom of 'A'
    min_y = min([-o for o in target_origins])
    max_y = max([h-o-1 for (h, o) in zip(heights, target_origins)])
    new_target_origin = -min_y
    updated_character_positionings = []
    for (height, character_positioning, target_origin) in \
        zip(heights, character_positionings, target_origins):
        delta = new_target_origin-target_origin
        updated_character_positionings.append(
            pad_font_top(character_positioning, delta)
        )
    height = max_y - min_y + 1
    return height, updated_character_positionings, new_target_origin

def center_font(height, character_positionings, target_origin, target_unicode=ord("B")):
    """
    Center the font on the target character.

    load_font's height corresponds to the minimal height to fit
    all the loaded characters. However the characters might not appear
    well centered when drawn in UI elements, for instance if a few
    special characters are very tall.

    center_font does make it so the target character ("B" by default) appears
    centered in the UI elements when drawn, and aligns the other characters
    to it.

    Inputs:
    -------
    height: current font height
    character_positionings: current positionings
    target_origin: current target origin (Bottom of 'A', 'B', etc)
        If the target_unicode character's bottom is not the target_origin,
        replace target_origin with h+character_positionings[target_unicode][0],
        where h = character_images[target_unicode].shape[0]
    target_unicode: unicode integer for the character on which we will center.
                    default is ord("B")

    Outputs:
    --------
    height: new height
    character_positionings: updated positionings
    target_origin: updated target origin
    """
    if not(isinstance(target_unicode, int)):
        raise ValueError("target_unicode must be an int (ord('B') for instance)")
    if target_unicode not in character_positionings:
        raise ValueError(f"target unicode character not found")

    (min_y, _, _) = character_positionings[target_unicode]
    max_y = target_origin
    current_center_y = height/2.
    target_center_y = (min_y+max_y)/2.
    # delta by which all coordinates must be shifted to center on the target
    delta = current_center_y - target_center_y
    # round to not introduce blur. round will y round up, which means
    # bottom visually
    delta = round(delta)
    if delta > 0:
        # we just shift everything down and increase height
        character_positionings = pad_font_top(character_positionings, delta)
        height = height + delta
        target_origin = target_origin + delta
    elif delta < 0:
        # pad the bottom, thus just increase height
        height = height - delta

    return height, character_positionings, target_origin

A_int = ord('A')
Z_int = ord('Z')
a_int = ord('a')
z_int = ord('z')
zero_int = ord('0')
nine_int = ord('9')

A_bold = ord("\U0001D400")
a_bold = ord("\U0001D41A")

A_italic = ord("\U0001D434")
a_italic = ord("\U0001D44E")

A_bitalic = ord("\U0001D468")
a_bitalic = ord("\U0001D482")

def make_chr_italic(c):
    code = ord(c)
    if code >= A_int and code <= Z_int:
        code = code - A_int + A_italic
    elif code >= a_int and code <= z_int:
        code = code - a_int + a_italic
    return chr(code)

def make_chr_bold(c):
    code = ord(c)
    if code >= A_int and code <= Z_int:
        code = code - A_int + A_bold
    elif code >= a_int and code <= z_int:
        code = code - a_int + a_bold
    return chr(code)

def make_chr_bold_italic(c):
    code = ord(c)
    if code >= A_int and code <= Z_int:
        code = code - A_int + A_bitalic
    elif code >= a_int and code <= z_int:
        code = code - a_int + a_bitalic
    return chr(code)

def make_italic(text):
    """
    Helper to convert a string into
    its italic version using the mathematical
    italic character encodings.
    """
    return "".join([make_chr_italic(c) for c in text])

def make_bold(text):
    """
    Helper to convert a string into
    its bold version using the mathematical
    bold character encodings.
    """
    return "".join([make_chr_bold(c) for c in text])

def make_bold_italic(text):
    """
    Helper to convert a string into
    its bold-italic version using the mathematical
    bold-italic character encodings.
    """
    return "".join([make_chr_bold_italic(c) for c in text])

class FontsManager:
    """A class that manages multiple fonts and provides font merging capabilities
    
    This class manages multiple FontLoader instances to provide:
    - Loading multiple fonts and reusing loaded fonts
    - Font merging with code page remapping 
    - Extended latin font generation with bold/italic variants
    """
    def __init__(self):
        self.loaders = {}  # Path -> FontLoader cache

    def get_loader(self, path):
        """Get or create a FontLoader for the given font path"""
        if path not in self.loaders:
            self.loaders[path] = FontLoader(path)
        return self.loaders[path]

    def merge_fonts(self, fonts_info, **kwargs):
        """
        Merge multiple fonts with code page remapping.
        
        fonts_info: List of tuples (font_path, restrict_to, code_map) where:
            - font_path: Path to font file
            - restrict_to: Set of unicode chars to load (optional)
            - code_map: function mapping source codes to target codes (optional)
        
        Returns tuple:
            (height, merged_images, merged_positioning)
        """
        heights = []
        character_images = []
        character_positioning = []
        origins = []

        for font_path, restrict_to, code_map in fonts_info:
            loader = self.get_loader(font_path)
            glyphset = loader.get_glyphs_bitmaps(
                restrict_to=restrict_to,
                **kwargs 
            )
            h, c_i, c_p, o = glyphset.get_raw_data()

            if code_map:
                if restrict_to is None:
                    raise ValueError("code_map requires restrict_to")
                # Remap character codes
                c_i_new = {}
                c_p_new = {} 
                for key in c_i.keys():
                    if key in restrict_to:
                        c_i_new[code_map(key)] = c_i[key]
                        c_p_new[code_map(key)] = c_p[key]
                c_i = c_i_new
                c_p = c_p_new

            heights.append(h)
            character_images.append(c_i)
            character_positioning.append(c_p)
            origins.append(o)

        # Align and merge fonts
        height, pos_aligned, origin = align_fonts(heights, character_positioning, origins)
        
        images_merged = {}
        pos_merged = {}
        for images, pos in zip(character_images, pos_aligned):
            images_merged.update(images)
            pos_merged.update(pos)

        # Center the merged font
        height, pos_merged, _ = center_font(height, pos_merged, origin)

        return height, images_merged, pos_merged

    def make_extended_latin_font(self, size: int,
                               main_font_path: str = None,
                               italic_font_path: str = None, 
                               bold_font_path: str = None,
                               bold_italic_path: str = None,
                               **kwargs):
        """Helper to load latin character set with bold/italic variants"""
        
        # Use default font paths if not specified
        if main_font_path is None:
            root_dir = os.path.dirname(__file__)
            main_font_path = os.path.join(root_dir, 'lmsans17-regular.otf')
        if italic_font_path is None:
            root_dir = os.path.dirname(__file__)
            italic_font_path = os.path.join(root_dir, 'lmromanslant17-regular.otf')
        if bold_font_path is None:
            root_dir = os.path.dirname(__file__)
            bold_font_path = os.path.join(root_dir, 'lmsans10-bold.otf')
        if bold_italic_path is None:
            root_dir = os.path.dirname(__file__)
            bold_italic_path = os.path.join(root_dir, 'lmromandemi10-oblique.otf')

        # Prepare font configurations
        restricted_latin = [ord(c) for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"]
        main_restrict = kwargs.pop("restrict_to", set(range(0, 256)))

        def make_bold_map(key):
            if key < a_int:
                return key - A_int + A_bold
            return key - a_int + a_bold

        def make_italic_map(key):
            if key < a_int:
                return key - A_int + A_italic  
            return key - a_int + a_italic

        def make_bold_italic_map(key):
            if key < a_int:
                return key - A_int + A_bitalic
            return key - a_int + a_bitalic

        fonts_info = [
            (main_font_path, main_restrict, None),
            (bold_font_path, restricted_latin, make_bold_map),
            (bold_italic_path, restricted_latin, make_bold_italic_map),
            (italic_font_path, restricted_latin, make_italic_map)
        ]

        return self.merge_fonts(fonts_info, target_size=size, **kwargs)

# Replace make_extended_latin_font implementation with:
def make_extended_latin_font(size: int, **kwargs):
    """Create an extended latin font using FontsManager"""
    manager = FontsManager()
    return manager.make_extended_latin_font(size, **kwargs)
