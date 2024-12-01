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
    lock_gil_friendly, draw_drawing_children, read_point, read_coord, \
    unparse_color, parse_color
from .types cimport child_type, Coord

from libcpp.algorithm cimport swap
from libcpp.cmath cimport atan, atan2, sin, cos, sqrt, trunc, floor, round as cround
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
        """Writable attribute: Display the drawings in front of all items (rather than behind)"""
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
        # TODO: dpi scaling
        self.context._viewport.shifts = [0., 0.]
        self.context._viewport.scales = [1., 1.]
        self.context._viewport.thickness_multiplier = 1.
        self.context._viewport.size_multiplier = 1.

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


cdef class DrawingClip(drawingItem):
    """
    A DrawingList, but with clipping.

    By default, all items are submitted to the GPU.
    The GPU handles efficiently clipping items that are outside
    the clipping regions.

    In most cases, that's enough and you don't need
    this item.

    However if you have a really huge amount of drawing
    primitives, the submission can be CPU intensive.
    In this case you might want to skip submitting
    groups of drawing primitives that are known to be
    outside the visible region.

    Another use case, is when you want to have a different
    density of items depending on the zoom level.

    Both the above use-cases can be done manually
    using a DrawingList and setting the show
    attribute programmatically.

    This item enables to do this automatically.

    This item defines a clipping rectangle space-wise
    and zoom-wise. If this clipping rectangle is not
    in the visible space, the children are not rendered.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self._scale_max = 1e300
        self._pmin = [-1e300, -1e300]
        self._pmax = [1e300, 1e300]

    @property
    def pmin(self):
        """(xmin, ymin) corner of the rect that
        must be on screen for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)
    @property
    def pmax(self):
        """(xmax, ymax) corner of the rect that
        must be on screen for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)

    @property
    def scale_min(self):
        """
        The coordinate space to screen space scaling
        must be strictly above this amount (measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0))
        for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_min
    @scale_min.setter
    def scale_min(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_min = value
    @property
    def scale_max(self):
        """
        The coordinate space to screen space scaling
        must be lower or equal to this amount (measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0))
        for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_max
    @scale_max.setter
    def scale_max(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_max = value

    @property
    def no_global_scaling(self):
        """
        By default, the pixel size of scale_min/max
        is multiplied by the global scale in order
        to have the same behaviour of various screens.

        Setting to True this field disables that.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale

    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        cdef float[2] pmin
        cdef float[2] pmax
        cdef double[2] unscaled_p1
        cdef double[2] unscaled_p2
        cdef float[2] p1
        cdef float[2] p2
        cdef float scale

        self.context._viewport.apply_current_transform(pmin, self._pmin)
        self.context._viewport.apply_current_transform(pmax, self._pmax)

        cdef imgui.ImVec2 rect_min = drawlist.GetClipRectMin()
        cdef imgui.ImVec2 rect_max = drawlist.GetClipRectMax()
        cdef bint visible = True
        if max(pmin[0], pmax[0]) < rect_min.x:
            visible = False
        elif min(pmin[0], pmax[0]) > rect_max.x:
            visible = False
        elif max(pmin[1], pmax[1]) < rect_min.y:
            visible = False
        elif min(pmin[1], pmax[1]) > rect_max.y:
            visible = False
        else:
            unscaled_p1[0] = 0
            unscaled_p1[1] = 0
            unscaled_p2[0] = 1
            unscaled_p2[1] = 0
            self.context._viewport.apply_current_transform(p1, unscaled_p1)
            self.context._viewport.apply_current_transform(p2, unscaled_p2)
            scale = p2[0] - p1[0]
            if not(self._no_global_scale):
                scale /= self.context._viewport.global_scale
            if scale <= self._scale_min or scale > self._scale_max:
                visible = False

        if visible:
            # draw children
            draw_drawing_children(self, drawlist)


cdef class DrawingScale(drawingItem):
    """
    A DrawingList, with a change in origin and scaling.
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
        for the children.

        Default is (1., 1.).

        Unless no_parent_scale is True,
        when applied, scales multiplies any previous
        scales already set (including plot scales).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._scales)

    @scales.setter
    def scales(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scales[0] = values[0]
        self._scales[1] = values[1]

    @property
    def origin(self):
        """
        Position in coordinate space of the
        new origin for the children.

        Default is (0., 0.)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._shifts)

    @origin.setter
    def origin(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._shifts[0] = values[0]
        self._shifts[1] = values[1]

    @property
    def no_parent_scaling(self):
        """
        Resets any previous scaling to screen space.

        Note origin is still transformed to screen space
        using the parent transform.

        When set to True, the global scale still
        impacts the scaling. Use no_global_scaling to
        disable this behaviour.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_parent_scale

    @no_parent_scaling.setter
    def no_parent_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_parent_scale = value

    @property
    def no_global_scaling(self):
        """
        Disables the global scale when no_parent_scaling is True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale

    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # save states
        cdef float global_scale = self.context._viewport.global_scale
        cdef double[2] cur_scales = self.context._viewport.scales
        cdef double[2] cur_shifts = self.context._viewport.shifts
        cdef bint cur_in_plot = self.context._viewport.in_plot
        cdef float cur_size_mul = self.context._viewport.size_multiplier
        cdef float cur_thick_mul = self.context._viewport.thickness_multiplier

        cdef float[2] p
        if self._no_parent_scale:
            self.context._viewport.apply_current_transform(p, self._shifts)
            self.context._viewport.shifts[0] = <double>p[0]
            self.context._viewport.shifts[1] = <double>p[1]
        else:
            # Doing manually keeps precision and plot transform
            self.context._viewport.shifts[0] = self.context._viewport.shifts[0] + cur_scales[0] * self._shifts[0]
            self.context._viewport.shifts[1] = self.context._viewport.shifts[1] + cur_scales[1] * self._shifts[1]

        if self._no_parent_scale:
            self.context._viewport.scales = self._scales
            if not(self._no_global_scale):
                self.context._viewport.scales[0] = self.context._viewport.scales[0] * global_scale
                self.context._viewport.scales[1] = self.context._viewport.scales[1] * global_scale
                self.context._viewport.thickness_multiplier = global_scale
            else:
                self.context._viewport.thickness_multiplier = 1.
            self.context._viewport.size_multiplier = self.context._viewport.scales[0]
            # Disable using plot transform
            self.context._viewport.in_plot = False
        else:
            self.context._viewport.scales[0] = cur_scales[0] * self._scales[0]
            self.context._viewport.scales[1] = cur_scales[1] * self._scales[1]
            self.context._viewport.size_multiplier = self.context._viewport.size_multiplier * self._scales[0]

        # draw children
        draw_drawing_children(self, drawlist)

        # restore states
        #self.context._viewport.global_scale = global_scale
        self.context._viewport.scales = cur_scales
        self.context._viewport.shifts = cur_shifts
        self.context._viewport.in_plot = cur_in_plot
        self.context._viewport.size_multiplier = cur_size_mul
        self.context._viewport.thickness_multiplier = cur_thick_mul


"""
Useful items
"""

cdef class DrawSplitBatch(drawingItem):
    """
    By default the rendering algorithms tries
    to batch drawing primitives together as much
    as possible. It detects when items need to be
    drawn in separate batches (for instance UI rendering,
    or drawing an image), but it is not always enough.

    When you need to force some items to be
    drawn after others, for instance to have a line
    overlap another, this item will force later items
    to be drawn in separate batches to the previous one.
    """
    cdef void draw(self, imgui.ImDrawList* drawlist) noexcept nogil:
        drawlist.AddDrawCmd()


"""
Draw items
"""

cdef class DrawArrow(drawingItem):
    def __cinit__(self):
        # p1, p2, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._size = 4.
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._end)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._end, value)
        self.__compute_tip()
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._start)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._start, value)
        self.__compute_tip()
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
        self.__compute_tip()
    @property
    def size(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._size = value
        self.__compute_tip()

    cdef void __compute_tip(self):
        # Copy paste from original code

        cdef double xsi = self._end[0]
        cdef double xfi = self._start[0]
        cdef double ysi = self._end[1]
        cdef double yfi = self._start[1]

        # length of arrow head
        cdef double xoffset = self._size
        cdef double yoffset = self._size

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
        self._corner1 = [x1 - 0.5 * self._size * sin(angle),
                        y1 + 0.5 * self._size * cos(angle)]
        self._corner2 = [x1 + 0.5 * self._size * cos((M_PI / 2.0) - angle),
                        y1 - 0.5 * self._size * sin((M_PI / 2.0) - angle)]

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] tstart
        cdef float[2] tend
        cdef float[2] tcorner1
        cdef float[2] tcorner2
        self.context._viewport.apply_current_transform(tstart, self._start)
        self.context._viewport.apply_current_transform(tend, self._end)
        self.context._viewport.apply_current_transform(tcorner1, self._corner1)
        self.context._viewport.apply_current_transform(tcorner2, self._corner2)
        cdef imgui.ImVec2 itstart = imgui.ImVec2(tstart[0], tstart[1])
        cdef imgui.ImVec2 itend  = imgui.ImVec2(tend[0], tend[1])
        cdef imgui.ImVec2 itcorner1 = imgui.ImVec2(tcorner1[0], tcorner1[1])
        cdef imgui.ImVec2 itcorner2 = imgui.ImVec2(tcorner2[0], tcorner2[1])
        drawlist.AddTriangleFilled(itend, itcorner1, itcorner2, self._color)
        drawlist.AddLine(itend, itstart, self._color, thickness)
        drawlist.AddTriangle(itend, itcorner1, itcorner2, self._color, thickness)


cdef class DrawBezierCubic(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 0.
        self._segments = 0

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        self.context._viewport.apply_current_transform(p1, self._p1)
        self.context._viewport.apply_current_transform(p2, self._p2)
        self.context._viewport.apply_current_transform(p3, self._p3)
        self.context._viewport.apply_current_transform(p4, self._p4)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        cdef imgui.ImVec2 ip4 = imgui.ImVec2(p4[0], p4[1])
        drawlist.AddBezierCubic(ip1, ip2, ip3, ip4, self._color, self._thickness, self._segments)

cdef class DrawBezierQuadratic(drawingItem):
    def __cinit__(self):
        # p1, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 0.
        self._segments = 0

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        self.context._viewport.apply_current_transform(p1, self._p1)
        self.context._viewport.apply_current_transform(p2, self._p2)
        self.context._viewport.apply_current_transform(p3, self._p3)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        drawlist.AddBezierQuadratic(ip1, ip2, ip3, self._color, self._thickness, self._segments)

cdef class DrawCircle(drawingItem):
    def __cinit__(self):
        # center is zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._radius = 1.
        self._thickness = 1.
        self._segments = 0

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
    @property
    def radius(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        cdef float radius = self._radius
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        if radius > 0:
            radius *= self.context._viewport.size_multiplier
        else:
            radius *= self.context._viewport.global_scale
        thickness = abs(thickness)
        radius = abs(radius)

        cdef float[2] center
        self.context._viewport.apply_current_transform(center, self._center)
        cdef imgui.ImVec2 icenter = imgui.ImVec2(center[0], center[1])
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            drawlist.AddCircleFilled(icenter, radius, self._fill, self._segments)
        drawlist.AddCircle(icenter, radius, self._color, self._segments, thickness)


cdef class DrawEllipse(drawingItem):
    # TODO: I adapted the original code,
    # But these deserves rewrite: call the imgui Ellipse functions instead
    # and add rotation parameter
    def __cinit__(self):
        # pmin/pmax is zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.
        self._segments = 0
    @property
    def pmin(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)
        self.__fill_points()
    @property
    def pmax(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)
        self.__fill_points()
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value
        self.__fill_points()

    cdef void __fill_points(self):
        cdef int segments = max(self._segments, 3)
        cdef double width = self._pmax[0] - self._pmin[0]
        cdef double height = self._pmax[1] - self._pmin[1]
        cdef double cx = width / 2. + self._pmin[0]
        cdef double cy = height / 2. + self._pmin[1]
        cdef double radian_inc = (M_PI * 2.) / <double>segments
        self._points.clear()
        self._points.reserve(segments+1)
        cdef int i
        # vector needs double2 rather than double[2]
        cdef double2 p
        width = abs(width)
        height = abs(height)
        for i in range(segments):
            p.p[0] = cx + cos(<double>i * radian_inc) * width / 2.
            p.p[1] = cy - sin(<double>i * radian_inc) * height / 2.
            self._points.push_back(p)
        self._points.push_back(self._points[0])

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self._points.size() < 3:
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef vector[imgui.ImVec2] transformed_points
        transformed_points.reserve(self._points.size())
        cdef int i
        cdef float[2] p
        for i in range(<int>self._points.size()):
            self.context._viewport.apply_current_transform(p, self._points[i].p)
            transformed_points.push_back(imgui.ImVec2(p[0], p[1]))
        # TODO imgui requires clockwise order for correct AA
        # Reverse order if needed
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            drawlist.AddConvexPolyFilled(transformed_points.data(),
                                                <int>transformed_points.size(),
                                                self._fill)
        drawlist.AddPolyline(transformed_points.data(),
                                    <int>transformed_points.size(),
                                    self._color,
                                    0,
                                    thickness)


cdef class DrawImage(drawingItem):
    """
    Draw an image in coordinate space.

    DrawImage supports three ways to express its position in space:
    - p1, p2, p3, p4, the positions of the corners of the image, in
       a clockwise order
    - pmin and pmax, where pmin = p1, and pmax = p3, and p2/p4
        are automatically set such that the image is parallel
        to the axes.
    - center, direction, width, height for the coordinate of the center,
        the angle of (center, middle of p2 and p3) against the x horizontal axis,
        and the width/height of the image at direction 0.

    uv1/uv2/uv3/uv4 are the normalized texture coordinates at p1/p2/p3/p4

    The systems are similar, but writing to p1/p2/p3/p4 is more expressive
    as it allows to have non-rectangular shapes.
    The last system enables to indicate a size in screen space rather
    than in coordinate space by passing negative values to width and height.
    """

    def __cinit__(self):
        self.uv1 = [0., 0.]
        self.uv2 = [1., 0.]
        self.uv3 = [1., 1.]
        self.uv4 = [0., 1.]
        self._color_multiplier = 4294967295 # 0xffffffff
    @property
    def texture(self):
        """Image content"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)) and value is not None:
            raise TypeError("texture must be a Texture")
        self._texture = value
    @property
    def pmin(self):
        """Top left corner"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self._p2[1] = self._p1[1]
        self._p4[0] = self._p1[0]
        self.update_center()
    @property
    def pmax(self):
        """Bottom right corner"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
        self._p2[0] = self._p3[0]
        self._p4[1] = self._p3[1]
        self.update_center()
    @property
    def center(self):
        """Center of pmin/pmax"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        """Center of pmin/pmax"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        self.update_extremities()
    @property
    def height(self):
        """Height of the shape. Negative means screen space."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._height
    @height.setter
    def height(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._height = value
        self.update_extremities()
    @property
    def width(self):
        """Width of the shape. Negative means screen space."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._width
    @width.setter
    def width(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._width = value
        self.update_extremities()
    @property
    def direction(self):
        """Angle of (center, middle of p2/p3) with the horizontal axis"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
    @property
    def p1(self):
        """Top left corner"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self.update_center()
    @property
    def p2(self):
        """Top right corner"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        """Bottom right corner"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
        self.update_center()
    @property
    def p4(self):
        """Bottom left corner"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)
    @property
    def uv_min(self):
        """Texture coordinate for pmin. Writes to uv1/2/4."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv1)
    @uv_min.setter
    def uv_min(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv1, value)
        self._uv2[1] = self._uv1[0]
        self._uv4[0] = self._uv1[1]
    @property
    def uv_max(self):
        """Texture coordinate for pmax. Writes to uv2/3/4."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv3)
    @uv_max.setter
    def uv_max(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv3, value)
        self._uv2[0] = self._uv3[0]
        self._uv4[1] = self._uv3[1]
    @property
    def uv1(self):
        """Texture coordinate for p1"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv1)
    @uv1.setter
    def uv1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv1, value)
    @property
    def uv2(self):
        """Texture coordinate for p2"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv2)
    @uv2.setter
    def uv2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv2, value)
    @property
    def uv3(self):
        """Texture coordinate for p3"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv3)
    @uv3.setter
    def uv3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv3, value)
    @property
    def uv4(self):
        """Texture coordinate for p4"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv4)
    @uv4.setter
    def uv4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv4, value)
    @property
    def color_multiplier(self):
        """
        The image is mixed with this color.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_multiplier
        unparse_color(color_multiplier, self._color_multiplier)
        return list(color_multiplier)
    @color_multiplier.setter
    def color_multiplier(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_multiplier = parse_color(value)
    @property
    def rounding(self):
        """Rounding of the corners of the shape.
        
        If non-zero, the renderered image will be rectangular
        and parallel to the axes.
        (p1/p2/p3/p4 will behave like pmin/pmax)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rounding
    @rounding.setter
    def rounding(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._rounding = value

    cdef void update_extremities(self) noexcept nogil:
        cdef double dx = cos(self._direction)
        cdef double dy = sin(self._direction)
        dx = 0.5 * self._width * dx
        dy = 0.5 * self._height * dy
        self._p1[0] = self._center[0] - dx
        self._p1[1] = self._center[1] - dy
        self._p3[0] = self._center[0] + dx
        self._p3[1] = self._center[1] + dy
        self._p2[1] = self._p1[0]
        self._p4[0] = self._p1[1]
        self._p2[0] = self._p3[0]
        self._p4[1] = self._p3[1]

    cdef void update_center(self) noexcept nogil:
        self._center[0] = (self._p1[0] + self._p3[0]) * 0.5
        self._center[1] = (self._p1[1] + self._p3[1]) * 0.5
        cdef double width2 = (self._p1[0] - self._p2[0]) * (self._p1[0] - self._p2[0]) +\
            (self._p1[1] - self._p2[1]) * (self._p1[1] - self._p2[1])
        cdef double height2 = (self._p2[0] - self._p3[0]) * (self._p2[0] - self._p3[0]) +\
            (self._p2[1] - self._p3[1]) * (self._p2[1] - self._p3[1])
        self._width = sqrt(width2)
        self._height = sqrt(height2)
        # center of p2/p3
        cdef double x, y
        x = 0.5 * (self._p2[0] + self._p3[0])
        y = 0.5 * (self._p2[1] + self._p3[1])
        if max(width2, height2) < 1e-60:
            self._direction = 0
        else:
            self._direction = atan2( \
                y - self._center[1],
                x - self._center[0]
                )

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self._texture is None:
            return
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self._texture.mutex)
        if self._texture.allocated_texture == NULL:
            return

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        cdef float[2] center
        cdef float dx, dy
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4
        cdef float actual_width
        cdef double actual_height

        if self._width >= 0 and self._height >= 0:
            self.context._viewport.apply_current_transform(p1, self._p1)
            self.context._viewport.apply_current_transform(p2, self._p2)
            self.context._viewport.apply_current_transform(p3, self._p3)
            self.context._viewport.apply_current_transform(p4, self._p4)
        else:
            self.context._viewport.apply_current_transform(center, self._center)
            actual_width = -self._width
            actual_height = -self._height
            if self._height >= 0 or self._width >= 0:
                self.context._viewport.apply_current_transform(p1, self._p1)
                self.context._viewport.apply_current_transform(p2, self._p2)
                self.context._viewport.apply_current_transform(p3, self._p3)
                if actual_width < 0:
                    # compute the coordinate space width
                    actual_width = sqrt(
                        (p1[0] - p2[0]) * (p1[0] - p2[0]) +\
                        (p1[1] - p2[1]) * (p1[1] - p2[1])
                    )
                else:
                    # compute the coordinate space height
                    actual_height = sqrt(
                        (p2[0] - p3[0]) * (p2[0] - p3[0]) +\
                        (p2[1] - p3[1]) * (p2[1] - p3[1])
                    )
            dx = 0.5 * cos(self._direction) * actual_width
            dy = 0.5 * sin(self._direction) * actual_height
            p1[0] = center[0] - dx
            p1[1] = center[1] - dy
            p3[0] = center[0] + dx
            p3[1] = center[1] + dy
            p2[1] = p1[0]
            p4[0] = p1[1]
            p2[0] = p3[0]
            p4[1] = p3[1]

        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])
        cdef imgui.ImVec2 iuv1 = imgui.ImVec2(self._uv1[0], self._uv1[1])
        cdef imgui.ImVec2 iuv2 = imgui.ImVec2(self._uv2[0], self._uv2[1])
        cdef imgui.ImVec2 iuv3 = imgui.ImVec2(self._uv3[0], self._uv3[1])
        cdef imgui.ImVec2 iuv4 = imgui.ImVec2(self._uv4[0], self._uv4[1])
        if self._rounding != 0.:
            # TODO: we could allow to control what is rounded.
            drawlist.AddImageRounded(<imgui.ImTextureID>self._texture.allocated_texture, \
            ip1, ip3, iuv1, iuv3, self._color_multiplier, self._rounding, imgui.ImDrawFlags_RoundCornersAll)
        else:
            drawlist.AddImageQuad(<imgui.ImTextureID>self._texture.allocated_texture, \
                ip1, ip2, ip3, ip4, iuv1, iuv2, iuv3, iuv4, self._color_multiplier)

cdef class DrawLine(drawingItem):
    """
    A line segment is coordinate space.

    DrawLine supports two ways to express its position in space:
    - p1 and p2 for the coordinate of its extremities
    - center, direction, length for the coordinate of the center,
        the angle of (center, p2) against the x horizontal axis,
        and the segment length.

    Both systems are equivalent and the related fields are always valid.
    The main difference is that length can be set to a negative value,
    to indicate a length in screen space rather than in coordinate space.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of one of the extremities of the line segment
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self.update_center()
    @property
    def p2(self):
        """
        Coordinates of one of the extremities of the line segment
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
        self.update_center()

    cdef void update_extremities(self) noexcept nogil:
        cdef double length = abs(self._length)
        cdef double dx = cos(self._direction)
        cdef double dy = sin(self._direction)
        dx = 0.5 * length * dx
        dy = 0.5 * length * dy
        self._p1[0] = self._center[0] - dx
        self._p1[1] = self._center[1] - dy
        self._p2[0] = self._center[0] + dx
        self._p2[1] = self._center[1] + dy

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of the center of the line segment
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        self.update_extremities()
    @property
    def length(self):
        """
        Length of the line segment. Negatives mean screen space.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._length
    @length.setter
    def length(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._length = value
        self.update_extremities()
    @property
    def direction(self):
        """
        Angle (rad) of the line segment relative to the horizontal axis.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        self.update_extremities()

    cdef void update_center(self) noexcept nogil:
        self._center[0] = (self._p1[0] + self._p2[0]) * 0.5
        self._center[1] = (self._p1[1] + self._p2[1]) * 0.5
        cdef double length2 = (self._p1[0] - self._p2[0]) * (self._p1[0] - self._p2[0]) +\
            (self._p1[1] - self._p2[1]) * (self._p1[1] - self._p2[1])
        self._length = sqrt(length2)
        if length2 < 1e-60:
            self._direction = 0
        else:
            self._direction = atan2( \
                self._p2[1] - self._center[1],
                self._p2[0] - self._center[0]
                )

    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] center
        cdef float dx, dy
        if self._length >= 0:
            self.context._viewport.apply_current_transform(p1, self._p1)
            self.context._viewport.apply_current_transform(p2, self._p2)
        else:
            self.context._viewport.apply_current_transform(center, self._center)
            dx = -0.5 * cos(self._direction) * self._length
            dy = -0.5 * sin(self._direction) * self._length
            p1[0] = center[0] - dx
            p1[1] = center[1] - dy
            p2[0] = center[0] + dx
            p2[1] = center[1] + dy

        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        drawlist.AddLine(ip1, ip2, self._color, thickness)

cdef class DrawPolyline(drawingItem):
    def __cinit__(self):
        # points is empty init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._closed = False

    @property
    def points(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef double2 p
        cdef int i
        for i in range(<int>self._points.size()):
            res.append(Coord.build(self._points[i].p))
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double2 p
        cdef int i
        self._points.clear()
        for i in range(len(value)):
            read_coord(p.p, value[i])
            self._points.push_back(p)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def closed(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closed
    @closed.setter
    def closed(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._closed = value
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self._points.size() < 2:
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip1_
        cdef imgui.ImVec2 ip2
        self.context._viewport.apply_current_transform(p, self._points[0].p)
        ip1 = imgui.ImVec2(p[0], p[1])
        ip1_ = ip1
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        cdef int i
        for i in range(1, <int>self._points.size()):
            self.context._viewport.apply_current_transform(p, self._points[i].p)
            ip2 = imgui.ImVec2(p[0], p[1])
            drawlist.AddLine(ip1, ip2, self._color, thickness)
            ip1 = ip2
        if self._closed and self._points.size() > 2:
            drawlist.AddLine(ip1_, ip2, self._color, thickness)


cdef inline bint is_counter_clockwise(imgui.ImVec2 p1,
                                      imgui.ImVec2 p2,
                                      imgui.ImVec2 p3) noexcept nogil:
    cdef float det = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    return det > 0.


cdef class DrawPolygon(drawingItem):
    def __cinit__(self):
        # points is empty init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def points(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef double2 p
        cdef int i
        for i in range(<int>self._points.size()):
            res.append(Coord.build(self._points[i].p))
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double2 p
        cdef int i
        self._points.clear()
        for i in range(len(value)):
            read_coord(p.p, value[i])
            self._points.push_back(p)
        self.__triangulate()
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    # ImGui Polygon fill requires clockwise order and convex polygon.
    # We want to be more lenient -> triangulate
    cdef void __triangulate(self):
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            return
        # TODO: optimize with arrays
        points = []
        cdef int i
        for i in range(<int>self._points.size()):
            # For now perform only in 2D
            points.append([self._points[i].p[0], self._points[i].p[1]])
        # order is counter clock-wise
        self._triangulation_indices = scipy.spatial.Delaunay(points).simplices

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self._points.size() < 2:
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip
        cdef vector[imgui.ImVec2] ipoints
        cdef int i
        cdef bint ccw
        ipoints.reserve(self._points.size())
        for i in range(<int>self._points.size()):
            self.context._viewport.apply_current_transform(p, self._points[i].p)
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        # Draw interior
        if self._fill & imgui.IM_COL32_A_MASK != 0 and self._triangulation_indices.shape[0] > 0:
            # imgui requires clockwise order + convexity for correct AA
            # The triangulation always returns counter-clockwise
            # but the matrix can change the order.
            # The order should be the same for all triangles, except in plot with log
            # scale.
            for i in range(self._triangulation_indices.shape[0]):
                ccw = is_counter_clockwise(ipoints[self._triangulation_indices[i, 0]],
                                           ipoints[self._triangulation_indices[i, 1]],
                                           ipoints[self._triangulation_indices[i, 2]])
                if ccw:
                    drawlist.AddTriangleFilled(ipoints[self._triangulation_indices[i, 0]],
                                                      ipoints[self._triangulation_indices[i, 2]],
                                                      ipoints[self._triangulation_indices[i, 1]],
                                                      self._fill)
                else:
                    drawlist.AddTriangleFilled(ipoints[self._triangulation_indices[i, 0]],
                                                      ipoints[self._triangulation_indices[i, 1]],
                                                      ipoints[self._triangulation_indices[i, 2]],
                                                      self._fill)

        # Draw closed boundary
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        for i in range(1, <int>self._points.size()):
            drawlist.AddLine(ipoints[i-1], ipoints[i], self._color, thickness)
        if self._points.size() > 2:
            drawlist.AddLine(ipoints[0], ipoints[<int>self._points.size()-1], self._color, thickness)

cdef class DrawQuad(drawingItem):
    def __cinit__(self):
        # p1, p2, p3, p4 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
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

        self.context._viewport.apply_current_transform(p1, self._p1)
        self.context._viewport.apply_current_transform(p2, self._p2)
        self.context._viewport.apply_current_transform(p3, self._p3)
        self.context._viewport.apply_current_transform(p4, self._p4)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])

        # imgui requires clockwise order + convex for correct AA
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            ccw = is_counter_clockwise(ip1,
                                       ip2,
                                       ip3)
            if ccw:
                drawlist.AddTriangleFilled(ip1, ip3, ip2, self._fill)
            else:
                drawlist.AddTriangleFilled(ip1, ip2, ip3, self._fill)
            ccw = is_counter_clockwise(ip1,
                                       ip4,
                                       ip3)
            if ccw:
                drawlist.AddTriangleFilled(ip1, ip3, ip4, self._fill)
            else:
                drawlist.AddTriangleFilled(ip1, ip4, ip3, self._fill)

        drawlist.AddLine(ip1, ip2, self._color, thickness)
        drawlist.AddLine(ip2, ip3, self._color, thickness)
        drawlist.AddLine(ip3, ip4, self._color, thickness)
        drawlist.AddLine(ip4, ip1, self._color, thickness)

cdef class DrawRect(drawingItem):
    def __cinit__(self):
        self._pmin = [0., 0.]
        self._pmax = [1., 1.]
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._color_upper_left = 0
        self._color_upper_right = 0
        self._color_bottom_left = 0
        self._color_bottom_right = 0
        self._rounding = 0.
        self._thickness = 1.
        self._multicolor = False

    @property
    def pmin(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)
    @property
    def pmax(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
        self._color_upper_left = self._fill
        self._color_upper_right = self._fill
        self._color_bottom_right = self._fill
        self._color_bottom_left = self._fill
        self._multicolor = False
    @property
    def fill_p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_left
        unparse_color(color_upper_left, self._color_upper_left)
        return list(color_upper_left)
    @fill_p1.setter
    def fill_p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_upper_left = parse_color(value)
        self._multicolor = True
    @property
    def fill_p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_right
        unparse_color(color_upper_right, self._color_upper_right)
        return list(color_upper_right)
    @fill_p2.setter
    def fill_p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_upper_right = parse_color(value)
        self._multicolor = True
    @property
    def fill_p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_right
        unparse_color(color_bottom_right, self._color_bottom_right)
        return list(color_bottom_right)
    @fill_p3.setter
    def fill_p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_bottom_right = parse_color(value)
        self._multicolor = True
    @property
    def fill_p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_left
        unparse_color(color_bottom_left, self._color_bottom_left)
        return list(color_bottom_left)
    @fill_p4.setter
    def fill_p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_bottom_left = parse_color(value)
        self._multicolor = True
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def rounding(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rounding
    @rounding.setter
    def rounding(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._rounding = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float rounding = self._rounding
        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] pmin
        cdef float[2] pmax
        cdef imgui.ImVec2 ipmin
        cdef imgui.ImVec2 ipmax
        cdef imgui.ImU32 col_up_left = self._color_upper_left
        cdef imgui.ImU32 col_up_right = self._color_upper_right
        cdef imgui.ImU32 col_bot_left = self._color_bottom_left
        cdef imgui.ImU32 col_bot_right = self._color_bottom_right

        self.context._viewport.apply_current_transform(pmin, self._pmin)
        self.context._viewport.apply_current_transform(pmax, self._pmax)
        ipmin = imgui.ImVec2(pmin[0], pmin[1])
        ipmax = imgui.ImVec2(pmax[0], pmax[1])

        # imgui requires clockwise order + convex for correct AA
        # The transform might invert the order
        if ipmin.x > ipmax.x:
            swap(ipmin.x, ipmax.x)
            swap(col_up_left, col_up_right)
            swap(col_bot_left, col_bot_right)
        if ipmin.y > ipmax.y:
            swap(ipmin.y, ipmax.y)
            swap(col_up_left, col_bot_left)
            swap(col_up_right, col_bot_right)


        if self._multicolor:
            if col_up_left == col_up_right and \
               col_up_left == col_bot_left and \
               col_up_left == col_up_right:
                self._fill = col_up_left
                self._multicolor = False

        if self._multicolor:
            if (col_up_left|col_up_right|col_bot_left|col_up_right) & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddRectFilledMultiColor(ipmin,
                                                 ipmax,
                                                 col_up_left,
                                                 col_up_right,
                                                 col_bot_right,
                                                 col_bot_left)
                rounding = 0
        else:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddRectFilled(ipmin,
                                       ipmax,
                                       self._fill,
                                       rounding,
                                       imgui.ImDrawFlags_RoundCornersAll)

        drawlist.AddRect(ipmin,
                                ipmax,
                                self._color,
                                rounding,
                                imgui.ImDrawFlags_RoundCornersAll,
                                thickness)


cdef class DrawRegularPolygon(drawingItem):
    """
    Draws a regular polygon with n points

    The polygon is defined by the center,
    the direction of the first point, and
    the radius.

    Radius can be negative to mean screen space.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._num_points = 1

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of the center of the shape
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
    @property
    def radius(self):
        """
        Radius of the shape. Negative means screen space.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value
    @property
    def direction(self):
        """
        Angle (rad) of the first point of the shape.

        The angle is relative to the horizontal axis.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        self.dirty = True
    @property
    def num_points(self):
        """
        Number of points in the shape.
        num_points=1 gives a circle.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_points
    @num_points.setter
    def num_points(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_points = value
        self.dirty = True
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._fill)
        return list(color)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)
        cdef float radius = self._radius
        cdef int num_points = self._num_points

        if radius == 0 or num_points <= 0:
            return

        # Angle of the first point
        cdef float start_angle = -self._direction # - because inverted y

        cdef float[2] center
        cdef imgui.ImVec2 icenter

        cdef float[2] p
        cdef imgui.ImVec2 ip
        cdef vector[imgui.ImVec2] ipoints
        cdef int i
        cdef float angle
        cdef float2 pp

        if self.dirty and num_points >= 2:
            self._points.clear()
            for i in range(num_points):
                # Similar to imgui draw code, we guarantee
                # increasing angle to force a specific order.
                angle = start_angle + (<float>i / <float>num_points) * (M_PI * 2.)
                pp.p[0] = cos(angle)
                pp.p[1] = sin(angle)
                self._points.push_back(pp)
            self.dirty = False

        if radius < 0:
            # screen space radius
            radius = -radius * self.context._viewport.global_scale
        else:
            radius = radius * self.context._viewport.size_multiplier

        self.context._viewport.apply_current_transform(center, self._center)
        icenter = imgui.ImVec2(center[0], center[1])

        if num_points == 1:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddCircleFilled(icenter, radius, self._fill, 0)
            drawlist.AddCircle(icenter, radius, self._color, 0, thickness)
            return

        # TODO: imgui does (radius - 0.5) for outline and radius for fill... Should we ? Is it correct with thickness != 1 ?
        ipoints.reserve(self._points.size())
        for i in range(<int>self._points.size()):
            p[0] = center[0] + radius * self._points[i].p[0]
            p[1] = center[1] + radius * self._points[i].p[1]
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        if num_points == 2:
            drawlist.AddLine(ipoints[0], ipoints[1], self._color, thickness)
            return

        if self._fill & imgui.IM_COL32_A_MASK != 0:
            drawlist.AddConvexPolyFilled(ipoints.data(), <int>ipoints.size(), self._fill)
        drawlist.AddPolyline(ipoints.data(), <int>ipoints.size(), self._color, imgui.ImDrawFlags_Closed, thickness)


cdef class DrawStar(drawingItem):
    """
    Draws a star shaped polygon with n points
    on the exterior circle.

    The polygon is defined by the center,
    the direction of the first point, the radius
    of the exterior circle and the inner radius.

    Crosses, astrisks, etc can be obtained using
    a radius of 0.

    Radius can be negative to mean screen space.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._num_points = 5
        self.dirty = True

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of the center of the shape
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
    @property
    def radius(self):
        """
        Radius of the shape. Negative means screen space.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value
    @property
    def inner_radius(self):
        """
        Radius of the inner shape.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._inner_radius
    @inner_radius.setter
    def inner_radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._inner_radius = value
    @property
    def direction(self):
        """
        Angle (rad) of the first point of the shape.

        The angle is relative to the horizontal axis.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        self.dirty = True
    @property
    def num_points(self):
        """
        Number of points in the shape.
        Must be >= 3.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_points
    @num_points.setter
    def num_points(self, int value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_points = value
        self.dirty = True
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._fill)
        return list(color)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)
        cdef float radius = self._radius
        cdef float inner_radius = self._inner_radius
        cdef int num_points = self._num_points
        cdef int num_segments = max(1, num_points - 1)

        if radius == 0 or num_points <= 2:
            return

        # In coordinate space. We can't assume that the axis is not in log scale
        # thus we pass the points via the transform, fix later...

        # Angle of the first point
        cdef float angle
        cdef float start_angle = -self._direction # - because inverted y
        cdef float start_angle_inner = -self._direction - M_PI / <float>num_points
        
        cdef float[2] center
        cdef imgui.ImVec2 icenter, ip
        cdef float[2] p
        cdef float2 pp
        cdef int i
        cdef vector[imgui.ImVec2] ipoints
        cdef vector[imgui.ImVec2] inner_ipoints

        if self.dirty:
            self._points.clear()
            for i in range(num_points):
                # Similar to imgui draw code, we guarantee
                # increasing angle to force a specific order.
                angle = start_angle + (<float>i / <float>num_points) * (M_PI * 2.)
                pp.p[0] = cos(angle)
                pp.p[1] = sin(angle)
                self._points.push_back(pp)
            self._inner_points.clear()
            for i in range(num_points):
                # Similar to imgui draw code, we guarantee
                # increasing angle to force a specific order.
                angle = start_angle_inner + (<float>i / <float>num_points) * (M_PI * 2.)
                pp.p[0] = cos(angle)
                pp.p[1] = sin(angle)
                self._inner_points.push_back(pp)
            self.dirty = False

        if radius < 0:
            # screen space radius
            radius = -radius * self.context._viewport.global_scale
            inner_radius = abs(inner_radius) * self.context._viewport.global_scale
        else:
            radius = radius * self.context._viewport.size_multiplier
            inner_radius = abs(inner_radius) * self.context._viewport.size_multiplier
        inner_radius = min(radius, inner_radius)

        self.context._viewport.apply_current_transform(center, self._center)
        icenter = imgui.ImVec2(center[0], center[1])

        ipoints.reserve(self._points.size())
        for i in range(<int>self._points.size()):
            p[0] = center[0] + radius * self._points[i].p[0]
            p[1] = center[1] + radius * self._points[i].p[1]
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        if inner_radius == 0.:
            if num_points % 2 == 0:
                for i in range(num_points//2):
                    drawlist.AddLine(ipoints[i], ipoints[i+num_points//2], self._color, thickness)
            else:
                for i in range(num_points):
                    drawlist.AddLine(ipoints[i], icenter, self._color, thickness)
            return

        inner_ipoints.reserve(self._inner_points.size())
        for i in range(<int>self._inner_points.size()):
            p[0] = center[0] + inner_radius * self._inner_points[i].p[0]
            p[1] = center[1] + inner_radius * self._inner_points[i].p[1]
            ip = imgui.ImVec2(p[0], p[1])
            inner_ipoints.push_back(ip)

        if self._fill & imgui.IM_COL32_A_MASK != 0:
            # fill inner region
            drawlist.AddConvexPolyFilled(inner_ipoints.data(), <int>inner_ipoints.size(), self._fill)
            # fill the rest
            for i in range(num_points-1):
                drawlist.AddTriangleFilled(ipoints[i],
                                           inner_ipoints[i],
                                           inner_ipoints[i+1],
                                           self._fill)
            drawlist.AddTriangleFilled(ipoints[num_points-1],
                                       inner_ipoints[num_points-1],
                                       inner_ipoints[0],
                                       self._fill)

        for i in range(num_points-1):
            drawlist.AddLine(ipoints[i], inner_ipoints[i], self._color, thickness)
            drawlist.AddLine(ipoints[i], inner_ipoints[i+1], self._color, thickness)
        drawlist.AddLine(ipoints[num_points-1], inner_ipoints[num_points-1], self._color, thickness)
        drawlist.AddLine(ipoints[num_points-1], inner_ipoints[0], self._color, thickness)

cdef class DrawText(drawingItem):
    def __cinit__(self):
        self._color = 4294967295 # 0xffffffff
        self._size = 0. # 0: default size. DearPyGui uses 1. internally, then 10. in the wrapper.

    @property
    def pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pos)
    @pos.setter
    def pos(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pos, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
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
        return str(self._text, encoding='utf-8')
    @text.setter
    def text(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._text = bytes(value, 'utf-8')
    @property
    def size(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._size = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float[2] p

        self.context._viewport.apply_current_transform(p, self._pos)
        cdef imgui.ImVec2 ip = imgui.ImVec2(p[0], p[1])
        cdef float size = self._size
        if size > 0:
            size *= self.context._viewport.size_multiplier
        else:
            size *= self.context._viewport.global_scale
        size = abs(size)
        if size == 0:
            drawlist.AddText(ip, self._color, self._text.c_str())
        else:
            drawlist.AddText(self._font.font if self._font is not None else NULL, size, ip, self._color, self._text.c_str())



cdef class DrawTriangle(drawingItem):
    def __cinit__(self):
        # p1, p2, p3 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   imgui.ImDrawList* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context._viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context._viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef bint ccw

        self.context._viewport.apply_current_transform(p1, self._p1)
        self.context._viewport.apply_current_transform(p2, self._p2)
        self.context._viewport.apply_current_transform(p3, self._p3)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ccw = is_counter_clockwise(ip1,
                                   ip2,
                                   ip3)

        # imgui requires clockwise order + convex for correct AA
        if ccw:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddTriangleFilled(ip1, ip3, ip2, self._fill)
            drawlist.AddTriangle(ip1, ip3, ip2, self._color, thickness)
        else:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                drawlist.AddTriangleFilled(ip1, ip2, ip3, self._fill)
            drawlist.AddTriangle(ip1, ip2, ip3, self._color, thickness)
