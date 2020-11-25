###cython: boundscheck=False, wraparound=False, nonecheck=False, optimize.use_switch=True


try:
    import pygame
    from pygame.math import Vector2
    from pygame import Rect, BLEND_RGB_ADD, HWACCEL, BLEND_RGB_MAX, BLEND_RGB_MULT, transform
    from pygame import Surface, SRCALPHA, mask, event, RLEACCEL
    from pygame.transform import rotate, scale, smoothscale
    from pygame.surfarray import pixels3d, array3d, pixels_alpha
    from pygame.image import frombuffer
except ImportError as e:
    print(e)
    raise ImportError("\n<Pygame> library is missing on your system."
          "\nTry: \n   C:\\pip install pygame on a window command prompt.")

try:
    cimport cython
    from cython.parallel cimport prange
except ImportError:
    raise ImportError("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")

try:
    import numpy
except ImportError:
    raise ImportError("\n<Numpy> library is missing on your system."
          "\nTry: \n   C:\\pip install numpy on a window command prompt.")

from numpy import empty, uint8
from libc.stdlib cimport srand, rand, RAND_MAX, qsort, malloc, free, abs

DEF ONE_255 = 1.0/255.0
DEF ONE_360 = 1.0/360.0


cdef extern from 'hsv_c.c' nogil:

    struct hsv:
        double h
        double s
        double v

    struct rgb:
        double r
        double g
        double b

    # METHOD 1
    double * rgb_to_hsv(double red, double green, double blue)nogil
    double * hsv_to_rgb(double h, double s, double v)nogil
    # METHOD 2
    hsv struct_rgb_to_hsv(double red, double green, double blue)nogil
    rgb struct_hsv_to_rgb(double h, double s, double v)nogil

    double fmax_rgb_value(double red, double green, double blue)nogil
    double fmin_rgb_value(double red, double green, double blue)nogil

ctypedef hsv HSV
ctypedef rgb RGB

# ------------------------------------ INTERFACE ----------------------------------------------

#***********************************************
#**********  METHOD HSV TO RGB   ***************
#***********************************************
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
# CYTHON VERSION
cpdef hsv2rgb(double h, double s, double v):
    cdef:
        double *rgb
        double r, g, b
    rgb = hsv2rgb_c(h, s, v)
    r, g, b = rgb[0], rgb[1], rgb[2]
    free(rgb)
    return r, g ,b

# CYTHON VERSION
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cpdef rgb2hsv(double r, double g, double b):
    cdef:
        double *hsv
        double h, s, v
    hsv = rgb2hsv_c(r, g, b)
    h, s, v = hsv[0], hsv[1], hsv[2]
    free(hsv)
    return h, s, v

# C VERSION METHOD 1
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cpdef rgb_to_hsv_c(double r, double g, double b):
    cdef:
        double *hsv
        double h, s, v
    hsv = rgb_to_hsv(r, g, b)
    h, s, v = hsv[0], hsv[1], hsv[2]
    free(hsv)
    return h, s, v

# C VERSION METHOD 1
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cpdef hsv_to_rgb_c(double h, double s, double v):
    cdef:
        double *rgb
        double r, g, b
    rgb = hsv_to_rgb(h, s, v)
    r, g, b = rgb[0], rgb[1], rgb[2]
    free(rgb)
    return r, g, b


# C VERSION METHOD 2
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cpdef tuple struct_rgb_to_hsv_c(double r, double g, double b):
    cdef HSV hsv_
    hsv_ = struct_rgb_to_hsv(r, g, b)
    return hsv_.h, hsv_.s, hsv_.v

# C VERSION METHOD 2
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cpdef tuple struct_hsv_to_rgb_c(double h, double s, double v):
    cdef RGB rgb_
    rgb_ = struct_hsv_to_rgb(h, s, v)
    return rgb_.r, rgb_.g, rgb_.b

cpdef hue_surface_24(surface_, float shift_):
    return hue_surface_24c(surface_, shift_)

cpdef hue_surface_32(surface_, float shift_):
    return hue_surface_32c(surface_, shift_)


#------------------------------------- CYTHON CODE --------------------------------------
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double * rgb2hsv_c(double r, double g, double b)nogil:
    """
    Convert RGB color model into HSV
    This method is identical to the python library colorsys.rgb_to_hsv
    * Don't forget to free the memory allocated for hsv values if you are 
    calling the method without using the cpdef function (see interface section).
    (Use the same pointer address returned by malloc() to free the block)
    
    :param r: python float; red in range[0 ... 1.0]
    :param g: python float; green in range [0 ... 1.0]
    :param b: python float; blue in range [0 ... 1.0]
    :return: Return HSV values 
    
    to convert in % do the following :
    h = h * 360.0
    s = s * 100.0
    v = v * 100.0
    
    """
    cdef:
        double mx, mn
        double h, df, s, v, df_
        double *hsv = <double *> malloc(3 * sizeof(double))

    mx = fmax_rgb_value(r, g, b)
    mn = fmin_rgb_value(r, g, b)

    df = mx - mn
    df_ = 1.0/df
    if mx == mn:
        h = 0.0

    elif mx == r:
        h = (60 * ((g-b) * df_) + 360) % 360
    elif mx == g:
        h = (60 * ((b-r) * df_) + 120) % 360
    elif mx == b:
        h = (60 * ((r-g) * df_) + 240) % 360
    if mx == 0:
        s = 0.0
    else:
        s = df/mx
    v = mx
    hsv[0] = h * ONE_360
    hsv[1] = s
    hsv[2] = v
    return hsv


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cdef double * hsv2rgb_c(double h, double s, double v)nogil:
    """
    Convert hsv color model to rgb
    * Don't forget to free the memory allocated for rgb values if you are 
    calling the method without using the cpdef function (see interface section).
    (Use the same pointer address returned by malloc() to free the block)

    :param h: python float; hue in range [0.0 ... 1.0]
    :param s: python float; saturation   [0.0 ... 1.0] 
    :param v: python float; value        [0.0 ... 1.0]
    :return: Return RGB floating values (normalized [0.0 ... 1.0]).
             multiply (red * 255.0, green * 255.0, blue * 255.0) to get the right pixel color.
    """
    cdef:
        int i = 0
        double f, p, q, t
        double *rgb = <double *> malloc(3 * sizeof(double))

    if s == 0.0:
        rgb[0] = v
        rgb[1] = v
        rgb[2] = v
        return rgb

    i = <int>(h * 6.0)
    f = (h * 6.0) - i
    p = v*(1.0 - s)
    q = v*(1.0 - s * f)
    t = v*(1.0 - s * (1.0 - f))
    i = i % 6

    if i == 0:
        rgb[0] = v
        rgb[1] = t
        rgb[2] = p
        return rgb
    elif i == 1:
        rgb[0] = q
        rgb[1] = v
        rgb[2] = p
        return rgb
    elif i == 2:
        rgb[0] = p
        rgb[1] = v
        rgb[2] = t
        return rgb
    elif i == 3:
        rgb[0] = p
        rgb[1] = q
        rgb[2] = v
        return rgb
    elif i == 4:
        rgb[0] = t
        rgb[1] = p
        rgb[2] = v
        return rgb
    elif i == 5:
        rgb[0] = v
        rgb[1] = p
        rgb[2] = q
        return rgb

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef hue_surface_24c(surface_, double shift_):

    assert isinstance(surface_, Surface), \
           'Expecting Surface for argument surface_ got %s ' % type(surface_)
    assert isinstance(shift_, float), \
            'Expecting double for argument shift_, got %s ' % type(shift_)
    assert 0.0<= shift_ <=1.0, 'Positional argument shift_ should be between[0.0 .. 1.0]'

    cdef int width, height
    width, height = surface_.get_size()

    try:
        rgb_ = pixels3d(surface_)
    except (pygame.error, ValueError):
        try:
            rgb_ = array3d(surface_)
        except:
            raise ValueError('\nInvalid pixel format.')

    cdef:
        unsigned char [:, :, :] rgb_array = rgb_
        unsigned char [:, :, ::1] new_array = empty((height, width, 3), dtype=uint8)
        int i=0, j=0
        float r, g, b
        float h, s, v
        float rr, gg, bb, mx, mn
        float df, df_
        float f, p, q, t, ii

    with nogil:
        for i in prange(width, schedule='static', num_threads=8, chunksize=4):
            for j in range(height):
                r, g, b = rgb_array[i, j, 0], rgb_array[i, j, 1], rgb_array[i, j, 2]

                rr = r * ONE_255 # / 255.0
                gg = g * ONE_255 # / 255.0
                bb = b * ONE_255 # / 255.0
                mx = fmax_rgb_value(rr, gg, bb)
                mn = fmin_rgb_value(rr, gg, bb)
                df = mx-mn
                df_ = 1.0/df
                if mx == mn:
                    h = 0
                elif mx == rr:
                    h = (60 * ((gg-bb) * df_) + 360) % 360
                elif mx == gg:
                    h = (60 * ((bb-rr) * df_) + 120) % 360
                elif mx == bb:
                    h = (60 * ((rr-gg) * df_) + 240) % 360
                if mx == 0:
                    s = 0
                else:
                    s = df/mx
                v = mx
                h = (h * ONE_360) + shift_

                if s == 0.0:
                    r, g, b = v, v, v
                ii = <int>(h * 6.0)
                f = (h * 6.0) - ii
                p = v*(1.0 - s)
                q = v*(1.0 - s * f)
                t = v*(1.0 - s * (1.0 - f))
                ii = ii % 6

                if ii == 0:
                    r, g, b = v, t, p
                if ii == 1:
                    r, g, b = q, v, p
                if ii == 2:
                    r, g, b = p, v, t
                if ii == 3:
                    r, g, b = p, q, v
                if ii == 4:
                    r, g, b = t, p, v
                if ii == 5:
                    r, g, b = v, p, q

                new_array[j, i, 0], new_array[j, i, 1], \
                new_array[j, i, 2] = <int>(r*255.0), <int>(g*255.0), <int>(b*255.0)

    return frombuffer(new_array, (width, height), 'RGB')


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef hue_surface_32c(surface_: Surface, float shift_):


    assert isinstance(surface_, Surface), \
           'Expecting Surface for argument surface_ got %s ' % type(surface_)
    assert isinstance(shift_, float), \
           'Expecting float for argument shift_, got %s ' % type(shift_)
    assert 0.0 <= shift_ <= 1.0, 'Positional argument shift_ should be between[0.0 .. 1.0]'

    try:
        rgb_ = pixels3d(surface_)
        alpha_ = pixels_alpha(surface_)
    except (pygame.error, ValueError):
       raise ValueError('\nCompatible only for 32-bit format with per-pixel transparency.')

    cdef int width, height
    width, height = surface_.get_size()

    cdef:
        unsigned char [:, :, :] rgb_array = rgb_
        unsigned char [:, :] alpha_array = alpha_
        unsigned char [:, :, ::1] new_array = empty((height, width, 4), dtype=uint8)
        int i=0, j=0
        #float r, g, b
        #float h, s, v
        double r, g, b
        double h, s, v
        float rr, gg, bb, mx, mn
        float df, df_
        float f, p, q, t, ii
        double *hsv
        double *rgb

    with nogil:
        for i in prange(width, schedule='static', num_threads=8):
            for j in range(height):
                r, g, b = rgb_array[i, j, 0], rgb_array[i, j, 1], rgb_array[i, j, 2]

                rr = r * ONE_255
                gg = g * ONE_255
                bb = b * ONE_255
                mx = max(rr, gg, bb)
                mn = min(rr, gg, bb)
                df = mx-mn
                df_ = 1.0/df
                if mx == mn:
                    h = 0
                elif mx == rr:
                    h = (60 * ((gg-bb) * df_) + 360) % 360
                elif mx == gg:
                    h = (60 * ((bb-rr) * df_) + 120) % 360
                elif mx == bb:
                    h = (60 * ((rr-gg) * df_) + 240) % 360
                if mx == 0:
                    s = 0
                else:
                    s = df/mx
                v = mx

                h = h * ONE_360 + shift_

                if s == 0.0:
                    r, g, b = v, v, v
                ii = <int>(h * 6.0)
                f = (h * 6.0) - ii
                p = v*(1.0 - s)
                q = v*(1.0 - s * f)
                t = v*(1.0 - s * (1.0 - f))
                ii = ii % 6

                if ii == 0:
                    r, g, b = v, t, p
                if ii == 1:
                    r, g, b = q, v, p
                if ii == 2:
                    r, g, b = p, v, t
                if ii == 3:
                    r, g, b = p, q, v
                if ii == 4:
                    r, g, b = t, p, v
                if ii == 5:
                    r, g, b = v, p, q

                new_array[j, i, 0], new_array[j, i, 1], \
                new_array[j, i, 2], new_array[j, i, 3] = int(r*255.0), int(g*255.0), int(b*255.0), alpha_array[i, j]

    return frombuffer(new_array, (width, height ), 'RGBA')



import colorsys

def shift_hue(r, g, b, shift_):
    """ hue shifting algorithm
        Transform an RGB color into its hsv equivalent and rotate color with shift_ parameter
        then transform hsv back to RGB."""
    # The HSVA components are in the ranges H = [0, 360], S = [0, 100], V = [0, 100], A = [0, 100].
    h, s, v, a = pygame.Color(int(r), int(g), int(b)).hsva
    # shift the hue and revert back to rgb
    rgb_color = colorsys.hsv_to_rgb((h + shift_) * 0.002777, s * 0.01, v * 0.01) # (1/360, 1/100, 1/100)
    return rgb_color[0] * 255, rgb_color[1] * 255, rgb_color[2] * 255

def hue_surface(surface_: pygame.Surface, shift_: int):

    rgb_array = pygame.surfarray.pixels3d(surface_)
    alpha_array = pygame.surfarray.pixels_alpha(surface_)

    vectorize_ = numpy.vectorize(shift_hue)
    source_array_ = vectorize_(rgb_array[:, :, 0], rgb_array[:, :, 1], rgb_array[:, :, 2], shift_)

    source_array_ = numpy.array(source_array_).transpose(1, 2, 0)
    #array = make_array(source_array_, alpha_array)
    #return make_surface(array).convert_alpha()
    array = numpy.dstack((source_array_, alpha_array))
    return pygame.image.frombuffer((array.transpose(1, 0, 2)).copy(order='C').astype(numpy.uint8),
                                   (array.shape[:2][0], array.shape[:2][1]), 'RGBA').convert_alpha()