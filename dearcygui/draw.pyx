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
#cython: auto_pickle=False
#distutils: language=c++

from dearcygui.wrapper cimport imgui
from dearcygui.wrapper.mutex cimport recursive_mutex, unique_lock
from .core cimport baseItem, drawingItem, \
    lock_gil_friendly, draw_drawing_children, read_point, \
    unparse_color, parse_color, read_vec4
from .types cimport child_type

from libcpp.algorithm cimport swap
from libcpp.cmath cimport atan, sin, cos, trunc, floor, round as cround
from libc.math cimport M_PI, INFINITY

import scipy
import scipy.spatial


cdef class ViewportDrawList(baseItem):
    def __cinit__(self):
        self.element_child_category = child_type.cat_viewport_drawlist
        self.can_have_drawing_child = True
        self._show = True
        self._front = True
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

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # Reset current drawInfo
        self.context._viewport.in_plot = False
        self.context._viewport.window_pos = imgui.ImVec2(0., 0.)
        self.context._viewport.parent_pos = imgui.ImVec2(0., 0.)
        self.context._viewport.shifts = [0., 0.]
        self.context._viewport.scales = [1., 1.]

        cdef imgui.ImDrawList* internal_drawlist = \
            imgui.GetForegroundDrawList() if self._front else \
            imgui.GetBackgroundDrawList()
        draw_drawing_children(self, internal_drawlist)


"""
Draw containers
"""

cdef class DrawingList(drawingItem):
    """
    A simple drawing item that renders its children.
    Useful to arrange your items and quickly
    hide/show/delete them by manipulating the list.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        draw_drawing_children(self, drawlist)

cdef class DrawingListScale(drawingItem):
    """
    Similar to a DrawingList, but
    can apply shift and scale to the data
    """
    def __cinit__(self):
        self._scales = [1., 1.]
        self._shifts = [0., 0.]
        self._no_parent_scale = False
        self.can_have_drawing_child = True

    @property
    def scales(self):
        """
        Scales applied to the x and y axes
        Default is (1., 1.).
        The scales multiply any previous scales
        already set (including plot scales).
        Use no_parent_scale to remove that behaviour.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scales

    @scales.setter
    def scales(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scales[0] = values[0]
        self._scales[1] = values[1]

    @property
    def shifts(self):
        """
        Shifts applied to the x and y axes.
        Default is (0., 0.)
        The shifts are applied any previous
        shift and scale.
        For instance on x, the transformation to
        screen space is:
        parent_x_transform(x * scales[0] + shifts[0])
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._shifts

    @shifts.setter
    def shifts(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._shifts[0] = values[0]
        self._shifts[1] = values[1]

    @property
    def no_parent_scale(self):
        """
        Resets any previous scaling to screen space.
        shifts are transformed to screen space using
        the parent transform and serves as origin (0, 0)
        for the child coordinates.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_parent_scale

    @no_parent_scale.setter
    def no_parent_scale(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_parent_scale = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # save states
        cdef double[2] cur_scales = self.context._viewport.scales
        cdef double[2] cur_shifts = self.context._viewport.shifts
        cdef bint cur_in_plot = self.context._viewport.in_plot

        cdef float[2] p
        if self._no_parent_scale:
            self.context._viewport.apply_current_transform(p, self._shifts)
            self.context._viewport.scales = self._scales
            self.context._viewport.shifts[0] = <double>p[0]
            self.context._viewport.shifts[1] = <double>p[1]
            self.context._viewport.in_plot = False
        else:
            self.context._viewport.scales[0] = cur_scales[0] * self._scales[0]
            self.context._viewport.scales[1] = cur_scales[1] * self._scales[1]
            self.context._viewport.shifts[0] = self.context._viewport.shifts[0] + cur_scales[0] * self._shifts[0]
            self.context._viewport.shifts[1] = self.context._viewport.shifts[1] + cur_scales[1] * self._shifts[1]
            # TODO investigate if it'd be better if we do or not:
            # maybe instead have the multipliers as params
            #if cur_in_plot:
            #    self.thickness_multiplier *= cur_scales[0]
            #    self.size_multiplier *= cur_scales[0]

        # draw children
        draw_drawing_children(self, drawlist)

        # restore states
        self.context._viewport.scales = cur_scales
        self.context._viewport.shifts = cur_shifts
        self.context._viewport.in_plot = cur_in_plot

"""
Draw items
"""

cdef class DrawArrow(drawingItem):
    def __cinit__(self):
        # p1, p2, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.
        self.size = 4.
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

    cdef void __compute_tip(self):
        # Copy paste from original code

        cdef double xsi = self.end[0]
        cdef double xfi = self.start[0]
        cdef double ysi = self.end[1]
        cdef double yfi = self.start[1]

        # length of arrow head
        cdef double xoffset = self.size
        cdef double yoffset = self.size

        # get pointer angle w.r.t +X (in radians)
        cdef double angle = 0.0
        if xsi >= xfi and ysi >= yfi:
            angle = atan((ysi - yfi) / (xsi - xfi))
        elif xsi < xfi and ysi >= yfi:
            angle = M_PI + atan((ysi - yfi) / (xsi - xfi))
        elif xsi < xfi and ysi < yfi:
            angle = -M_PI + atan((ysi - yfi) / (xsi - xfi))
        elif xsi >= xfi and ysi < yfi:
            angle = atan((ysi - yfi) / (xsi - xfi))

        cdef double x1 = <double>(xsi - xoffset * cos(angle))
        cdef double y1 = <double>(ysi - yoffset * sin(angle))
        self.corner1 = [x1 - 0.5 * self.size * sin(angle),
                        y1 + 0.5 * self.size * cos(angle)]
        self.corner2 = [x1 + 0.5 * self.size * cos((M_PI / 2.0) - angle),
                        y1 - 0.5 * self.size * sin((M_PI / 2.0) - angle)]

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] tstart
        cdef float[2] tend
        cdef float[2] tcorner1
        cdef float[2] tcorner2
        self.context._viewport.apply_current_transform(tstart, self.start)
        self.context._viewport.apply_current_transform(tend, self.end)
        self.context._viewport.apply_current_transform(tcorner1, self.corner1)
        self.context._viewport.apply_current_transform(tcorner2, self.corner2)
        cdef imgui.ImVec2 itstart = imgui.ImVec2(tstart[0], tstart[1])
        cdef imgui.ImVec2 itend  = imgui.ImVec2(tend[0], tend[1])
        cdef imgui.ImVec2 itcorner1 = imgui.ImVec2(tcorner1[0], tcorner1[1])
        cdef imgui.ImVec2 itcorner2 = imgui.ImVec2(tcorner2[0], tcorner2[1])
        drawlist.AddTriangleFilled(itend, itcorner1, itcorner2, self.color)
        drawlist.AddLine(itend, itstart, self.color, thickness)
        drawlist.AddTriangle(itend, itcorner1, itcorner2, self.color, thickness)


cdef class DrawBezierCubic(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 0.
        self.segments = 0

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        self.context._viewport.apply_current_transform(p4, self.p4)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        cdef imgui.ImVec2 ip4 = imgui.ImVec2(p4[0], p4[1])
        drawlist.AddBezierCubic(ip1, ip2, ip3, ip4, self.color, self.thickness, self.segments)

cdef class DrawBezierQuadratic(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 0.
        self.segments = 0

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        drawlist.AddBezierQuadratic(ip1, ip2, ip3, self.color, self.thickness, self.segments)

cdef class DrawCircle(drawingItem):
    def __cinit__(self):
        # center is zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.radius = 1.
        self.thickness = 1.
        self.segments = 0

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        cdef float radius = self.radius
        if self.context._viewport.in_plot:
            if thickness > 0:
                thickness *= self.context._viewport.thickness_multiplier
            if radius > 0:
                radius *= self.context._viewport.size_multiplier
        thickness = abs(thickness)
        radius = abs(radius)

        cdef float[2] center
        self.context._viewport.apply_current_transform(center, self.center)
        cdef imgui.ImVec2 icenter = imgui.ImVec2(center[0], center[1])
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            drawlist.AddCircleFilled(icenter, radius, self.fill, self.segments)
        drawlist.AddCircle(icenter, radius, self.color, self.segments, thickness)


cdef class DrawEllipse(drawingItem):
    # TODO: I adapted the original code,
    # But these deserves rewrite: call the imgui Ellipse functions instead
    # and add rotation parameter
    def __cinit__(self):
        # pmin/pmax is zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.
        self.segments = 0
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

    cdef void __fill_points(self):
        cdef int segments = max(self.segments, 3)
        cdef double width = self.pmax[0] - self.pmin[0]
        cdef double height = self.pmax[1] - self.pmin[1]
        cdef double cx = width / 2. + self.pmin[0]
        cdef double cy = height / 2. + self.pmin[1]
        cdef double radian_inc = (M_PI * 2.) / <double>segments
        self.points.clear()
        self.points.reserve(segments+1)
        cdef int i
        # vector needs double4 rather than double[4]
        cdef double4 p
        width = abs(width)
        height = abs(height)
        for i in range(segments):
            p.p[0] = cx + cos(<double>i * radian_inc) * width / 2.
            p.p[1] = cy - sin(<double>i * radian_inc) * height / 2.
            self.points.push_back(p)
        self.points.push_back(self.points[0])

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self.points.size() < 3:
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef vector[imgui.ImVec2] transformed_points
        transformed_points.reserve(self.points.size())
        cdef int i
        cdef float[2] p
        for i in range(<int>self.points.size()):
            self.context._viewport.apply_current_transform(p, self.points[i].p)
            transformed_points.push_back(imgui.ImVec2(p[0], p[1]))
        # TODO imgui requires clockwise order for correct AA
        # Reverse order if needed
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            drawlist.AddConvexPolyFilled(transformed_points.data(),
                                                <int>transformed_points.size(),
                                                self.fill)
        drawlist.AddPolyline(transformed_points.data(),
                                    <int>transformed_points.size(),
                                    self.color,
                                    0,
                                    thickness)


cdef class DrawImage(drawingItem):
    def __cinit__(self):
        self.uv = [0., 0., 1., 1.]
        self.color_multiplier = 4294967295 # 0xffffffff
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
        read_vec4[float](self.uv, value)
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
    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.texture is None:
            return
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.texture.mutex)
        if self.texture.allocated_texture == NULL:
            return

        cdef float[2] pmin
        cdef float[2] pmax
        self.context._viewport.apply_current_transform(pmin, self.pmin)
        self.context._viewport.apply_current_transform(pmax, self.pmax)
        cdef imgui.ImVec2 ipmin = imgui.ImVec2(pmin[0], pmin[1])
        cdef imgui.ImVec2 ipmax = imgui.ImVec2(pmax[0], pmax[1])
        cdef imgui.ImVec2 uvmin = imgui.ImVec2(self.uv[0], self.uv[1])
        cdef imgui.ImVec2 uvmax = imgui.ImVec2(self.uv[2], self.uv[3])
        drawlist.AddImage(<imgui.ImTextureID>self.texture.allocated_texture, ipmin, ipmax, uvmin, uvmax, self.color_multiplier)

cdef class DrawImageQuad(drawingItem):
    def __cinit__(self):
        self.uv1 = [0., 0.]
        self.uv2 = [0., 0.]
        self.uv3 = [0., 0.]
        self.uv4 = [0., 0.]
        self.color_multiplier = 4294967295 # 0xffffffff
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
        return list(self.uv1)
    @uv1.setter
    def uv1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv1, value)
    @property
    def uv2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv2)
    @uv2.setter
    def uv2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv2, value)
    @property
    def uv3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv3)
    @uv3.setter
    def uv3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self.uv3, value)
    @property
    def uv4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self.uv4)
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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.texture is None:
            return
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.texture.mutex)
        if self.texture.allocated_texture == NULL:
            return

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4

        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        self.context._viewport.apply_current_transform(p4, self.p4)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])
        cdef imgui.ImVec2 iuv1 = imgui.ImVec2(self.uv1[0], self.uv1[1])
        cdef imgui.ImVec2 iuv2 = imgui.ImVec2(self.uv2[0], self.uv2[1])
        cdef imgui.ImVec2 iuv3 = imgui.ImVec2(self.uv3[0], self.uv3[1])
        cdef imgui.ImVec2 iuv4 = imgui.ImVec2(self.uv4[0], self.uv4[1])
        drawlist.AddImageQuad(<imgui.ImTextureID>self.texture.allocated_texture, \
            ip1, ip2, ip3, ip4, iuv1, iuv2, iuv3, iuv4, self.color_multiplier)

cdef class DrawLine(drawingItem):
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        drawlist.AddLine(ip1, ip2, self.color, thickness)

cdef class DrawPolyline(drawingItem):
    def __cinit__(self):
        # points is empty init by cython
        self.color = 4294967295 # 0xffffffff
        self.thickness = 1.
        self.closed = False

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self.points.size() < 2:
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip1_
        cdef imgui.ImVec2 ip2
        self.context._viewport.apply_current_transform(p, self.points[0].p)
        ip1 = imgui.ImVec2(p[0], p[1])
        ip1_ = ip1
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        cdef int i
        for i in range(1, <int>self.points.size()):
            self.context._viewport.apply_current_transform(p, self.points[i].p)
            ip2 = imgui.ImVec2(p[0], p[1])
            drawlist.AddLine(ip1, ip2, self.color, thickness)
            ip1 = ip2
        if self.closed and self.points.size() > 2:
            drawlist.AddLine(ip1_, ip2, self.color, thickness)


cdef inline bint is_counter_clockwise(imgui.ImVec2 p1,
                                      imgui.ImVec2 p2,
                                      imgui.ImVec2 p3) noexcept nogil:
    cdef float det = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    return det > 0.


cdef class DrawPolygon(drawingItem):
    def __cinit__(self):
        # points is empty init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.

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

    # ImGui Polygon fill requires clockwise order and convex polygon.
    # We want to be more lenient -> triangulate
    cdef void __triangulate(self):
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            return
        # TODO: optimize with arrays
        points = []
        cdef int i
        for i in range(<int>self.points.size()):
            # For now perform only in 2D
            points.append([self.points[i].p[0], self.points[i].p[1]])
        # order is counter clock-wise
        self.triangulation_indices = scipy.spatial.Delaunay(points).simplices

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self.points.size() < 2:
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip
        cdef vector[imgui.ImVec2] ipoints
        cdef int i
        cdef bint ccw
        ipoints.reserve(self.points.size())
        for i in range(<int>self.points.size()):
            self.context._viewport.apply_current_transform(p, self.points[i].p)
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        # Draw interior
        if self.fill & imgui.IM_COL32_A_MASK != 0 and self.triangulation_indices.shape[0] > 0:
            # imgui requires clockwise order + convexity for correct AA
            # The triangulation always returns counter-clockwise
            # but the matrix can change the order.
            # The order should be the same for all triangles, except in plot with log
            # scale.
            for i in range(self.triangulation_indices.shape[0]):
                ccw = is_counter_clockwise(ipoints[self.triangulation_indices[i, 0]],
                                           ipoints[self.triangulation_indices[i, 1]],
                                           ipoints[self.triangulation_indices[i, 2]])
                if ccw:
                    drawlist.AddTriangleFilled(ipoints[self.triangulation_indices[i, 0]],
                                                      ipoints[self.triangulation_indices[i, 2]],
                                                      ipoints[self.triangulation_indices[i, 1]],
                                                      self.fill)
                else:
                    drawlist.AddTriangleFilled(ipoints[self.triangulation_indices[i, 0]],
                                                      ipoints[self.triangulation_indices[i, 1]],
                                                      ipoints[self.triangulation_indices[i, 2]],
                                                      self.fill)

        # Draw closed boundary
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        for i in range(1, <int>self.points.size()):
            drawlist.AddLine(ipoints[i-1], ipoints[i], self.color, thickness)
        if self.points.size() > 2:
            drawlist.AddLine(ipoints[0], ipoints[<int>self.points.size()-1], self.color, thickness)



cdef class DrawQuad(drawingItem):
    def __cinit__(self):
        # p1, p2, p3, p4 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4
        cdef bint ccw

        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        self.context._viewport.apply_current_transform(p4, self.p4)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])

        # imgui requires clockwise order + convex for correct AA
        if self.fill & imgui.IM_COL32_A_MASK != 0:
            ccw = is_counter_clockwise(ip1,
                                       ip2,
                                       ip3)
            if ccw:
                drawlist.AddTriangleFilled(ip1, ip3, ip2, self.fill)
            else:
                drawlist.AddTriangleFilled(ip1, ip2, ip3, self.fill)
            ccw = is_counter_clockwise(ip1,
                                       ip4,
                                       ip3)
            if ccw:
                drawlist.AddTriangleFilled(ip1, ip3, ip4, self.fill)
            else:
                drawlist.AddTriangleFilled(ip1, ip4, ip3, self.fill)

        drawlist.AddLine(ip1, ip2, self.color, thickness)
        drawlist.AddLine(ip2, ip3, self.color, thickness)
        drawlist.AddLine(ip3, ip4, self.color, thickness)
        drawlist.AddLine(ip4, ip1, self.color, thickness)

cdef class DrawRect(drawingItem):
    def __cinit__(self):
        self.pmin = [0., 0.]
        self.pmax = [1., 1.]
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.color_upper_left = 0
        self.color_upper_right = 0
        self.color_bottom_left = 0
        self.color_bottom_right = 0
        self.rounding = 0.
        self.thickness = 1.
        self.multicolor = False

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] pmin
        cdef float[2] pmax
        cdef imgui.ImVec2 ipmin
        cdef imgui.ImVec2 ipmax
        cdef imgui.ImU32 col_up_left = self.color_upper_left
        cdef imgui.ImU32 col_up_right = self.color_upper_right
        cdef imgui.ImU32 col_bot_left = self.color_bottom_left
        cdef imgui.ImU32 col_bot_right = self.color_bottom_right

        self.context._viewport.apply_current_transform(pmin, self.pmin)
        self.context._viewport.apply_current_transform(pmax, self.pmax)
        ipmin = imgui.ImVec2(pmin[0], pmin[1])
        ipmax = imgui.ImVec2(pmax[0], pmax[1])

        # The transform might invert the order
        if ipmin.x > ipmax.x:
            swap(ipmin.x, ipmax.x)
            swap(col_up_left, col_up_right)
            swap(col_bot_left, col_bot_right)
        if ipmin.y > ipmax.y:
            swap(ipmin.y, ipmax.y)
            swap(col_up_left, col_bot_left)
            swap(col_up_right, col_bot_right)

        # imgui requires clockwise order + convex for correct AA
        if self.multicolor:
            if (col_up_left|col_up_right|col_bot_left|col_up_right) & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddRectFilledMultiColor(ipmin,
                                                        ipmax,
                                                        col_up_left,
                                                        col_up_right,
                                                        col_bot_left,
                                                        col_bot_right)
        else:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddRectFilled(ipmin,
                                              ipmax,
                                              self.fill,
                                              self.rounding,
                                              imgui.ImDrawFlags_RoundCornersAll)

        drawlist.AddRect(ipmin,
                                ipmax,
                                self.color,
                                self.rounding,
                                imgui.ImDrawFlags_RoundCornersAll,
                                thickness)

cdef class DrawText(drawingItem):
    def __cinit__(self):
        self.color = 4294967295 # 0xffffffff
        self.size = 0. # 0: default size. DearPyGui uses 1. internally, then 10. in the wrapper.

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float[2] p

        self.context._viewport.apply_current_transform(p, self.pos)
        cdef imgui.ImVec2 ip = imgui.ImVec2(p[0], p[1])
        cdef float size = self.size
        if size > 0 and self.context._viewport.in_plot:
            size *= self.context._viewport.size_multiplier
        size = abs(size)
        drawlist.AddText(self._font.font if self._font is not None else NULL, size, ip, self.color, self.text.c_str())



cdef class DrawTriangle(drawingItem):
    def __cinit__(self):
        # p1, p2, p3 are zero init by cython
        self.color = 4294967295 # 0xffffffff
        self.fill = 0
        self.thickness = 1.
        self.cull_mode = 0

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

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self.thickness
        if self.context._viewport.in_plot and thickness > 0:
            thickness *= self.context._viewport.thickness_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef bint ccw

        self.context._viewport.apply_current_transform(p1, self.p1)
        self.context._viewport.apply_current_transform(p2, self.p2)
        self.context._viewport.apply_current_transform(p3, self.p3)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ccw = is_counter_clockwise(ip1,
                                   ip2,
                                   ip3)

        if self.cull_mode == 1 and ccw:
            return
        if self.cull_mode == 2 and not(ccw):
            return

        # imgui requires clockwise order + convex for correct AA
        if ccw:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddTriangleFilled(ip1, ip3, ip2, self.fill)
            drawlist.AddTriangle(ip1, ip3, ip2, self.color, thickness)
        else:
            if self.fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddTriangleFilled(ip1, ip2, ip3, self.fill)
            drawlist.AddTriangle(ip1, ip2, ip3, self.color, thickness)
