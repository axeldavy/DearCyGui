from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from .core cimport *
import numpy as np

cdef class ViewportDrawList(ViewportDrawList_):
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
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.end)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.end, value)
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
        read_point[double](self.start, value)
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
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p4, value)
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
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p3, value)
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
    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.center, value)
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
    @property
    def pmin(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.pmin, value)
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
        read_point[double](self.pmax, value)
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
        read_point[double](self.pmin, value)
    @property
    def pmax(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.pmax, value)
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
        read_point[double](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p4, value)
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
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p2, value)
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

cdef class DrawPolyline(DrawPolyline_):
    @property
    def points(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef double4 p
        cdef int i
        for i in range(<int>self.points.size()):
            res.append(self.points[i].p)
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double4 p
        cdef int i
        self.points.clear()
        for i in range(len(value)):
            read_point[double](p.p, value[i])
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
    @property
    def points(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef double4 p
        cdef int i
        for i in range(<int>self.points.size()):
            res.append(self.points[i].p)
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double4 p
        cdef int i
        self.points.clear()
        for i in range(len(value)):
            read_point[double](p.p, value[i])
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
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p4, value)
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
    @property
    def pmin(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.pmin, value)
    @property
    def pmax(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.pmax, value)
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
        if self.multicolor: # TODO: move to draw ?
            self.rounding = 0.
    @property
    def rounding(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.rounding
    @rounding.setter
    def rounding(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.rounding = value

cdef class DrawText(DrawText_):
    @property
    def pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.pos)
    @pos.setter
    def pos(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.pos, value)
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
    def font(self):
        """
        Writable attribute: font used for the text rendered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, Font value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def text(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self.text, encoding='utf-8')
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
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self.p3, value)
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
