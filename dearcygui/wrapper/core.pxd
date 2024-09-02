from . cimport math

cdef extern from "mvCore.h" nogil:
	ctypedef struct mvColor:
		float r,g,b,a
		#mvColor()
		#mvColor(float r, float g, float b, float a)
		#mvColor(int r, int g, int b, int a)
		#mvColor(math.ImVec4 color)
		#const math.ImVec4 toVec4()
	unsigned int ConvertToUnsignedInt(const mvColor& color)
	int MV_APP_UUID
	int MV_START_UUID

cdef inline mvColor colorFromInts(int r, int g, int b, int a):
	cdef mvColor color
	color.r = r/255.
	color.g = g/255.
	color.b = b/255.
	color.a = a/255.
	return color
