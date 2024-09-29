from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from .core cimport *
import numpy as np

cdef class ViewportDrawList(ViewportDrawList_):
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._front = kwargs.pop("front", self._front)
        self._show = kwargs.pop("show", self._show)
        super().configure(**kwargs)
    @property
    def front(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._front
    @front.setter
    def front(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._front = value
    @property
    def show(self):
        """
        Writable attribute: Should the object be drawn/shown ?
        In case show is set to False, this disables any
        callback (for example the close callback won't be called
        if a window is hidden with show = False).
        In the case of items that can be closed,
        show is set to False automatically on close.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._show = value

cdef class DrawLayer(DrawLayer_):
    def configure(self, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._cull_mode = kwargs.pop("cull_mode", self._cull_mode)
        self._perspective_divide = kwargs.pop("perspective_divide", self._perspective_divide)
        self._depth_clipping = kwargs.pop("depth_clipping", self._depth_clipping)
        if "transform" in kwargs:
            # call the property setter
            self.transform = kwargs.pop("transform")
        super().configure(**kwargs)
    @property
    def perspective_divide(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._perspective_divide
    @perspective_divide.setter
    def perspective_divide(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._perspective_divide = value
    @property
    def depth_clipping(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._depth_clipping
    @depth_clipping.setter
    def depth_clipping(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._depth_clipping = value
    @property
    def cull_mode(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._cull_mode
    @cull_mode.setter
    def cull_mode(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._cull_mode = value
    @property
    def transform(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self.has_matrix_transform):
            # identity:
            return [[1., 0., 0., 0.], [0., 1., 0., 0.], [0., 0., 1., 0.], [0., 0., 0., 1.]]
        res = []
        cdef int i
        for i in range(4):
            res.append(list(self._transform[i]))
        return res
    @transform.setter
    def transform(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int i, j
        if len(value) == 16:
            for i in range(16):
                self._transform[i//4][i%4] = <float>value[i]
        elif len(value) == 4:
            for i in range(4):
                if len(value[i]) != 4:
                    raise ValueError("Invalid matrix format")
                for j in range(4):
                    self._transform[i][j] = <float>value[i][j]
        else:
             raise ValueError("Expected a 4x4 matrix")

    def clip_space(self,
                   float topleftx,
                   float toplefty,
                   float width,
                   float height,
                   float mindepth,
                   float maxdepth):
        self.clipViewport[0] = topleftx
        self.clipViewport[1] = toplefty + height
        self.clipViewport[2] = width
        self.clipViewport[3] = height
        self.clipViewport[4] = mindepth
        self.clipViewport[5] = maxdepth
        self.transform[0] = [width, 0., 0., topleftx + (width / 2.)]
        self.transform[0] = [0., -height, 0., toplefty + (height / 2.)]
        self.transform[0] = [0., 0., 0.25, 0.5]
        self.transform[1] = [0., 0., 0., 1.]
        self.has_matrix_transform = True

cdef class DrawArrow(DrawArrow_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(args) == 2:
            read_point[float](self.end, args[0])
            read_point[float](self.start, args[1])
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawArrow. Expected p1 and p2")
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        self.size = kwargs.pop("size", self.size)
        super().configure(**kwargs)
        self.__compute_tip()

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.end)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.end, value)
        self.__compute_tip()
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.start)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.start, value)
        self.__compute_tip()
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value
        self.__compute_tip()
    @property
    def size(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.size = value
        self.__compute_tip()


cdef class DrawBezierCubic(DrawBezierCubic_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(args) == 4:
            (p1, p2, p3, p4) = args
            read_point[float](self.p1, p1)
            read_point[float](self.p2, p2)
            read_point[float](self.p3, p3)
            read_point[float](self.p4, p4)
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawBezierCubic. Expected p1, p2, p3 and p4")
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        self.segments = kwargs.pop("segments", self.segments)
        super().configure(**kwargs)
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p4, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.segments = value

cdef class DrawBezierQuadratic(DrawBezierQuadratic_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(args) == 3:
            (p1, p2, p3) = args
            read_point[float](self.p1, p1)
            read_point[float](self.p2, p2)
            read_point[float](self.p3, p3)
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawBezierQuadratic. Expected p1, p2 and p3")
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        self.segments = kwargs.pop("segments", self.segments)
        super().configure(**kwargs)
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p3, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.segments = value

cdef class DrawCircle(DrawCircle_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(args) == 2:
            (center, radius) = args
            read_point[float](self.center, center)
            self.radius = radius
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawCircle. Expected center and radius")
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        if "fill" in kwargs:
            self.fill = parse_color(kwargs.pop("fill"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        self.segments = kwargs.pop("segments", self.segments)
        super().configure(**kwargs)
    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.center, value)
    @property
    def radius(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.radius)
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.radius = value
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self.fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.segments = value

cdef class DrawEllipse(DrawEllipse_):
    def configure(self, *args, **kwargs):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint recompute_points = False
        if len(args) == 2:
            (pmin, pmax) = args
            read_point[float](self.pmin, pmin)
            read_point[float](self.pmax, pmax)
            recompute_points = True
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawEllipse. Expected pmin and pmax")
        # pmin/pmax can also be passed as optional arguments
        if "pmin" in kwargs:
            read_point[float](self.pmin, kwargs.pop("pmin"))
            recompute_points = True
        if "pmax" in kwargs:
            read_point[float](self.pmax, kwargs.pop("pmax"))
            recompute_points = True
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        if "fill" in kwargs:
            self.fill = parse_color(kwargs.pop("fill"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        self.segments = kwargs.pop("segments", self.segments)
        super().configure(**kwargs)
        if recompute_points:
            self.__fill_points()
    @property
    def pmin(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.pmin, value)
        self.__fill_points()
    @property
    def pmax(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.pmax, value)
        self.__fill_points()
    @property
    def radius(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.radius)
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.radius = value
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self.fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.segments = value
        self.__fill_points()


cdef class DrawImage(DrawImage_):
    def configure(self, *args, **kwargs):
        if len(args) == 3:
            texture = args[0]
            if texture == 2:#MV_ATLAS_UUID:
                assert(False) # TODO
            else:
                if not(isinstance(texture, Texture)):
                    raise TypeError("texture input must be a Texture")
                self.texture = <Texture>texture
            read_point[float](self.pmin, args[1])
            read_point[float](self.pmax, args[2])
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawImage. Expected texture, pmin, pmax")
        if "pmin" in kwargs:
            read_point[float](self.pmin, kwargs.pop("pmin"))
        if "pmax" in kwargs:
            read_point[float](self.pmax, kwargs.pop("pmax"))
        if "texture_tag" in kwargs:
            raise ValueError("Invalid use of dctDrawImage. texture_tag must be converted to Texture reference")
        if "texture" in kwargs:
            texture = kwargs.pop("texture")
            if not(isinstance(texture, Texture)):
                raise TypeError("texture input must be a Texture")
            self.texture = <Texture>texture
        if "uv_max" in kwargs:
            uv_max = kwargs.pop("uv_max")
            self.uv[2] = uv_max[0]
            self.uv[3] = uv_max[1]
        if "uv_min" in kwargs:
            uv_min = kwargs.pop("uv_min")
            self.uv[0] = uv_min[0]
            self.uv[1] = uv_min[1]
        if "color" in kwargs:
            #TODO warn_once()
            self.color_multiplier = parse_color(kwargs.pop("color"))
        if "color_multiplier" in kwargs:
            self.color_multiplier = parse_color(kwargs.pop("color_multiplier"))
        super().configure(**kwargs)

    @property
    def texture(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)):
            raise TypeError("texture must be a Texture")
        self.texture = value
    @property
    def pmin(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.pmin, value)
    @property
    def pmax(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.pmax, value)
    @property
    def uv(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv)
    @uv.setter
    def uv(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv, value)
    @property
    def color_multiplier(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_multiplier
        unparse_color(color_multiplier, self.color_multiplier)
        return list(color_multiplier)
    @color_multiplier.setter
    def color_multiplier(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color_multiplier = parse_color(value)

cdef class DrawImageQuad(DrawImageQuad_):
    def configure(self, *args, **kwargs):
        if len(args) == 5:
            texture = args[0]
            if texture == 2:#MV_ATLAS_UUID:
                assert(False) # TODO
            else:
                if not(isinstance(texture, Texture)):
                    raise TypeError("texture input must be a Texture")
                self.texture = <Texture>texture
            read_point[float](self.p1, args[1])
            read_point[float](self.p2, args[2])
            read_point[float](self.p3, args[3])
            read_point[float](self.p4, args[4])
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawImage. Expected texture, p1, p2, p3, p4")
        if "p1" in kwargs:
            read_point[float](self.p1, kwargs.pop("p1"))
        if "p2" in kwargs:
            read_point[float](self.p2, kwargs.pop("p2"))
        if "p3" in kwargs:
            read_point[float](self.p3, kwargs.pop("p3"))
        if "p4" in kwargs:
            read_point[float](self.p4, kwargs.pop("p4"))
        if "texture_tag" in kwargs:
            raise ValueError("Invalid use of dctDrawImage. texture_tag must be converted to Texture reference")
        if "texture" in kwargs:
            texture = kwargs.pop("texture")
            if not(isinstance(texture, Texture)):
                raise TypeError("texture input must be a Texture")
            self.texture = <Texture>texture
        if "uv1" in kwargs:
            read_point[float](self.uv1, kwargs.pop("uv1"))
        if "uv2" in kwargs:
            read_point[float](self.uv2, kwargs.pop("uv2"))
        if "uv3" in kwargs:
            read_point[float](self.uv3, kwargs.pop("uv3"))
        if "uv4" in kwargs:
            read_point[float](self.uv4, kwargs.pop("uv4"))
        if "color" in kwargs:
            #TODO warn_once()
            self.color_multiplier = parse_color(kwargs.pop("color"))
        if "color_multiplier" in kwargs:
            self.color_multiplier = parse_color(kwargs.pop("color_multiplier"))
        super().configure(**kwargs)

    @property
    def texture(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)):
            raise TypeError("texture must be a Texture")
        self.texture = value
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p4, value)
    @property
    def uv1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv1)[:2]
    @uv1.setter
    def uv1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv1, value)
    @property
    def uv2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv2)[:2]
    @uv2.setter
    def uv2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv2, value)
    @property
    def uv3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv3)[:2]
    @uv3.setter
    def uv3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv3, value)
    @property
    def uv4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv4)[:2]
    @uv4.setter
    def uv4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv4, value)
    @property
    def color_multiplier(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_multiplier
        unparse_color(color_multiplier, self.color_multiplier)
        return list(color_multiplier)
    @color_multiplier.setter
    def color_multiplier(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color_multiplier = parse_color(value)

cdef class DrawLine(DrawLine_):
    def configure(self, *args, **kwargs):
        if len(args) == 2:
            read_point[float](self.p1, args[0])
            read_point[float](self.p2, args[1])
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawLine. Expected p1, p2")
        if "p1" in kwargs:
            read_point[float](self.p1, kwargs.pop("p1"))
        if "p2" in kwargs:
            read_point[float](self.p2, kwargs.pop("p2"))
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        super().configure(**kwargs)

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p2, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def closed(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.closed
    @closed.setter
    def closed(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.closed = value
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value

cdef class DrawPolyline(DrawPolyline_):
    def configure(self, *args, **kwargs):
        points = None
        if len(args) == 1:
            points = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawPolyline. Expected list of points")
        if "points" in kwargs:
            points = kwargs.pop("points")
        cdef float4 p
        cdef int i
        if not(points is None):
            self.points.clear()
            for i in range(len(points)):
                read_point[float](p.p, points[i])
                self.points.push_back(p)
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        self.closed = kwargs.pop("closed", self.closed)
        self.thickness = kwargs.pop("thickness", self.thickness)
        super().configure(**kwargs)

    @property
    def points(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef float4 p
        cdef int i
        for i in range(<int>self.points.size()):
            res.append(self.points[i].p)
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float4 p
        cdef int i
        self.points.clear()
        for i in range(len(value)):
            read_point[float](p.p, value[i])
            self.points.push_back(p)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def closed(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.closed
    @closed.setter
    def closed(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.closed = value
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value

cdef class DrawPolygon(DrawPolygon_):
    def configure(self, *args, **kwargs):
        points = None
        if len(args) == 1:
            points = args[0]
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawPolygon. Expected list of points")
        if "points" in kwargs:
            points = kwargs.pop("points")
        cdef float4 p
        cdef int i
        if not(points is None):
            self.points.clear()
            for i in range(len(points)):
                read_point[float](p.p, points[i])
                self.points.push_back(p)
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        if "fill" in kwargs:
            self.fill = parse_color(kwargs.pop("fill"))
        self.closed = kwargs.pop("closed", self.closed)
        self.thickness = kwargs.pop("thickness", self.thickness)
        super().configure(**kwargs)

    @property
    def points(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef float4 p
        cdef int i
        for i in range(<int>self.points.size()):
            res.append(self.points[i].p)
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float4 p
        cdef int i
        self.points.clear()
        for i in range(len(value)):
            read_point[float](p.p, value[i])
            self.points.push_back(p)
        self.__triangulate()
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self.fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value


cdef class DrawQuad(DrawQuad_):
    def configure(self, *args, **kwargs):
        if len(args) == 4:
            (p1, p2, p3, p4) = args
            read_point[float](self.p1, p1)
            read_point[float](self.p2, p2)
            read_point[float](self.p3, p3)
            read_point[float](self.p4, p4)
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawQuad. Expected p1, p2, p3 and p4")
        if "p1" in kwargs:
            read_point[float](self.p1, kwargs.pop("p1"))
        if "p2" in kwargs:
            read_point[float](self.p2, kwargs.pop("p2"))
        if "p3" in kwargs:
            read_point[float](self.p3, kwargs.pop("p3"))
        if "p4" in kwargs:
            read_point[float](self.p4, kwargs.pop("p4"))
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        if "fill" in kwargs:
            self.fill = parse_color(kwargs.pop("fill"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        super().configure(**kwargs)

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p4, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self.fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value

cdef class DrawRect(DrawRect_):
    def configure(self, *args, **kwargs):
        if len(args) == 2:
            (pmin, pmax) = args
            read_point[float](self.pmin, pmin)
            read_point[float](self.pmax, pmax)
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawRect. Expected pmin and pmax")
        if "pmin" in kwargs:
            read_point[float](self.pmin, kwargs.pop("pmin"))
        if "pmax" in kwargs:
            read_point[float](self.pmax, kwargs.pop("pmax"))
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        if "fill" in kwargs:
            self.fill = parse_color(kwargs.pop("fill"))
        if "color_upper_left" in kwargs:
            self.color_upper_left = parse_color(kwargs.pop("color_upper_left"))
        if "color_upper_right" in kwargs:
            self.color_upper_right = parse_color(kwargs.pop("color_upper_right"))
        if "color_bottom_left" in kwargs:
            self.color_bottom_left = parse_color(kwargs.pop("color_bottom_left"))
        if "color_bottom_right" in kwargs:
            self.color_bottom_right = parse_color(kwargs.pop("color_bottom_right"))
        if "corner_colors" in kwargs:
            if kwargs["corner_colors"] is not None:
                (color_upper_right, color_upper_left, color_bottom_right, color_bottom_left) = \
                    kwargs.pop("corner_colors")
                self.color_upper_left = parse_color(color_upper_left)
                self.color_upper_right = parse_color(color_upper_right)
                self.color_bottom_left = parse_color(color_bottom_left)
                self.color_bottom_right = parse_color(color_bottom_right)
            else:
                del kwargs["corner_colors"]
        self.rounding = kwargs.pop("rounding", self.rounding)
        self.thickness = kwargs.pop("thickness", self.thickness)
        self.multicolor = kwargs.pop("multicolor", self.multicolor)
        if self.multicolor:
            self.rounding = 0.
        super().configure(**kwargs)

    @property
    def pmin(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.pmin, value)
    @property
    def pmax(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.pmax, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self.fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.fill = parse_color(value)
    @property
    def color_upper_left(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_left
        unparse_color(color_upper_left, self.color_upper_left)
        return list(color_upper_left)
    @color_upper_left.setter
    def color_upper_left(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color_upper_left = parse_color(value)
    @property
    def color_upper_right(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_right
        unparse_color(color_upper_right, self.color_upper_right)
        return list(color_upper_right)
    @color_upper_right.setter
    def color_upper_right(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color_upper_right = parse_color(value)
    @property
    def color_bottom_left(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_left
        unparse_color(color_bottom_left, self.color_bottom_left)
        return list(color_bottom_left)
    @color_bottom_left.setter
    def color_bottom_left(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color_bottom_left = parse_color(value)
    @property
    def color_bottom_right(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_right
        unparse_color(color_bottom_right, self.color_bottom_right)
        return list(color_bottom_right)
    @color_bottom_right.setter
    def color_bottom_right(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color_bottom_right = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value
    @property
    def multicolor(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.multicolor
    @multicolor.setter
    def multicolor(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.multicolor = value

cdef class DrawText(DrawText_):
    def configure(self, *args, **kwargs):
        if len(args) == 1:
            read_point[float](self.pos, args[0])
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawText. Expected pos")
        if "pos" in kwargs:
            read_point[float](self.pos, kwargs.pop("pos"))
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        if "text" in kwargs:
            self.text = bytes(str(kwargs.pop("text")), 'utf-8')
        self.size = kwargs.pop("size", self.size)
        super().configure(**kwargs)

    @property
    def pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pos)
    @pos.setter
    def pos(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.pos, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def text(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self.text)
    @text.setter
    def text(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.text = bytes(value, 'utf-8')
    @property
    def size(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.size = value


cdef class DrawTriangle(DrawTriangle_):
    def configure(self, *args, **kwargs):
        if len(args) == 3:
            (p1, p2, p3) = args
            read_point[float](self.p1, p1)
            read_point[float](self.p2, p2)
            read_point[float](self.p3, p3)
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to DrawQuad. Expected p1, p2 and p3")
        if "p1" in kwargs:
            read_point[float](self.p1, kwargs.pop("p1"))
        if "p2" in kwargs:
            read_point[float](self.p2, kwargs.pop("p2"))
        if "p3" in kwargs:
            read_point[float](self.p3, kwargs.pop("p3"))
        if "color" in kwargs:
            self.color = parse_color(kwargs.pop("color"))
        if "fill" in kwargs:
            self.fill = parse_color(kwargs.pop("fill"))
        self.thickness = kwargs.pop("thickness", self.thickness)
        self.cull_mode = kwargs.pop("cull_mode", self.cull_mode)
        super().configure(**kwargs)

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.p3, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self.fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.thickness = value
    @property
    def cull_mode(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.cull_mode
    @cull_mode.setter
    def cull_mode(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.cull_mode = value