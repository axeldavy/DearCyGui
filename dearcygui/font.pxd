from dearcygui.wrapper cimport imgui
from .types cimport *
from .core cimport baseItem, baseFont, Texture

cdef class Font(baseFont):
    cdef imgui.ImFont *font
    cdef FontTexture container
    cdef bint dpi_scaling
    cdef float _scale
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class FontTexture(baseItem):
    """
    Packs one or several fonts into
    a texture for internal use by ImGui.
    """
    cdef imgui.ImFontAtlas atlas
    cdef Texture _texture
    cdef bint _built
    cdef list fonts_files # content of the font files
    cdef list fonts

cdef class GlyphSet:
    cdef readonly int height
    cdef readonly dict images
    cdef readonly dict positioning
    cdef readonly int origin_y
    cpdef void add_glyph(self,
                         int unicode_key, 
                         object image,
                         float dy,
                         float dx,
                         float advance)

cdef class FontRenderer:
    cdef object face
    cpdef GlyphSet render_glyph_set(self,
                                    target_pixel_height=?,
                                    target_size=?,
                                    str hinter=?,
                                    restrict_to=?,
                                    allow_color=?)