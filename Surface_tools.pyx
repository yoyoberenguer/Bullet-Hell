# encoding: utf-8
###cython: boundscheck=False, wraparound=False, nonecheck=False, optimize.use_switch=True

try:
    cimport cython
    from cython.parallel cimport prange
    from cpython cimport PyObject_CallFunctionObjArgs, PyObject, \
        PyList_SetSlice, PyObject_HasAttr, PyObject_IsInstance, \
        PyObject_CallMethod, PyObject_CallObject
    from cpython.dict cimport PyDict_DelItem, PyDict_Clear, PyDict_GetItem, PyDict_SetItem, \
        PyDict_Values, PyDict_Keys, PyDict_Items
    from cpython.list cimport PyList_Append, PyList_GetItem, PyList_Size, PyList_SetItem
    from cpython.object cimport PyObject_SetAttr

except ImportError:
    raise ImportError("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")

import numpy
from numpy import empty, uint8, asarray

try:
    import pygame
    from pygame import Rect
    from pygame.math import Vector2
    from pygame import Rect, BLEND_RGB_ADD, HWACCEL
    from pygame import Surface, SRCALPHA, mask, RLEACCEL
    from pygame.transform import rotate, scale, smoothscale
    from pygame.surfarray import array3d, pixels3d, array_alpha, pixels_alpha

except ImportError:
    raise ImportError("\n<Pygame> library is missing on your system."
          "\nTry: \n   C:\\pip install pygame on a window command prompt.")

DEF THREAD_NUMBER = 8
DEF SCHEDULE = 'static'

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef make_array_c_code(unsigned char[:, :, :] rgb_array_c, unsigned char[:, :] alpha_c):
    """
    STACK ARRAY RGB VALUES WITH ALPHA CHANNEL.
    
    :param rgb_array_c: numpy.ndarray (w, h, 3) uint8 containing RGB values 
    :param alpha_c    : numpy.ndarray (w, h) uint8 containing alpha values 
    :return           : return a numpy.ndarray (w, h, 4) uint8, stack array of RGBA values
    The values are copied into a new array (out array is not transpose).
    """
    cdef int width, height
    try:
        width, height = (<object> rgb_array_c).shape[:2]
    except (ValueError, pygame.error) as e:
        raise ValueError('\nArray shape not understood.')

    cdef:
        unsigned char[:, :, ::1] new_array =  empty((width, height, 4), dtype=uint8)
        int i=0, j=0
    # EQUIVALENT TO A NUMPY DSTACK
    with nogil:
        for i in prange(width, schedule=SCHEDULE, num_threads=THREAD_NUMBER):
            for j in range(height):
                new_array[i, j, 0], new_array[i, j, 1], new_array[i, j, 2], \
                new_array[i, j, 3] =  rgb_array_c[i, j, 0], rgb_array_c[i, j, 1], \
                                   rgb_array_c[i, j, 2], alpha_c[i, j]
    return asarray(new_array)



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef make_transparent(image_, int alpha_):
    """
    MODIFY TRANSPARENCY TO A PYGAME SURFACE 
    
    :param image_: Surface; pygame.Surface to modify  
    :param alpha_: int; integer value representing the new alpha value 
    :return: Surface with new alpha value
    """

    # NOTE: REMOVED FOR SPEED
    # assert isinstance(image_, Surface), \
    #     'Expecting Surface for positional argument image_ got %s ' % type(image_)
    # assert isinstance(alpha_, int), \
    #     'Expecting int for positional argument alpha_ got %s ' % type(alpha_)
    #
    # if not (0 <= alpha_ <= 255):
    #     raise ValueError('\n[-] invalid value for argument alpha_, range [0..255] got %s ' % alpha_)
    #
    # if not image_.get_bitsize() == 32:
    #     raise TypeError("\nSurface without per-pixel information.")

    try:
        rgb = pixels3d(image_)
    except (pygame.error, ValueError):
        raise ValueError('\nInvalid surface.')

    try:
        alpha = pixels_alpha(image_)
    except (pygame.error, ValueError):
        raise ValueError('\nSurface without per-pixel information.')

    cdef int w, h
    w, h = image_.get_size()

    # REMOVE FOR SPEED
    # if w==0 or h==0:
    #     raise ValueError(
    #         'Image with incorrect shape, must be (w>0, h>0) got (w:%s, h:%s) ' % (w, h))

    cdef:
        unsigned char [:, :, ::1] new_array = numpy.empty((h, w, 4), dtype=numpy.uint8)
        unsigned char [:, :] alpha_array = alpha
        unsigned char [:, :, :] rgb_array = rgb
        int i=0, j=0, a

    with nogil:

        for i in prange(w, schedule=SCHEDULE, num_threads=THREAD_NUMBER):
            for j in range(h):
                new_array[j, i, 0] = rgb_array[i, j, 0]
                new_array[j, i, 1] = rgb_array[i, j, 1]
                new_array[j, i, 2] = rgb_array[i, j, 2]
                a = alpha_array[i, j] - alpha_
                if a < 0:
                    a = 0
                new_array[j, i, 3] = a

    return pygame.image.frombuffer(new_array, (w, h), 'RGBA')


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef reshape(sprite_, factor_=1.0):
    """
    RESHAPE ANIMATION OR IMAGE 
    
    :param sprite_: list, image; list containing the surface to rescale
    :param factor_: float, int or tuple; Represent the scale factor (new size)
    :return: return  animation or a single image (rescale) 
    """

    cdef:
        float f_factor_
        tuple t_factor_

    if PyObject_IsInstance(factor_, (float, int)):
        # FLOAT OR INT
        try:
            f_factor_ = <float>factor_
            if f_factor_ == 1.0:
                return sprite_
        except ValueError:
            raise ValueError('\nArgument factor_ must be float or int got %s ' % type(factor_))
    # TUPLE
    else:
        try:
            t_factor_ = tuple(factor_)
            if (<float>t_factor_[0] == 0.0 and <float>t_factor_[1] == 0.0):
                return sprite_
        except ValueError:
            raise ValueError('\nArgument factor_ must be a list or tuple got %s ' % type(factor_))

    cdef:
        int i = 0
        int w, h
        int c1, c2
        sprite_copy = sprite_.copy()

    if PyObject_IsInstance(factor_, (float, int)):
        if PyObject_IsInstance(sprite_, list):
            c1 = <int>(sprite_[i].get_width()  * factor_)
            c2 = <int>(sprite_[i].get_height() * factor_)
        else:
            c1 = <int>(sprite_.get_width()  * factor_)
            c2 = <int>(sprite_.get_height() * factor_)

    # ANIMATION
    if PyObject_IsInstance(sprite_copy, list):

        for surface in sprite_copy:
            if PyObject_IsInstance(factor_, (float, int)):
                sprite_copy[i] = smoothscale(surface, (c1, c2))
            elif PyObject_IsInstance(factor_, (tuple, list)):
                sprite_copy[i] = smoothscale(surface, (factor_[0], factor_[1]))
            else:
                raise ValueError('\nArgument factor_ incorrect '
                             'type must be float, int or tuple got %s ' % type(factor_))
            i += 1

    # SINGLE IMAGE
    else:
        if PyObject_IsInstance(factor_, (float, int)):
            sprite_copy = smoothscale(sprite_copy,(c1, c2))
        elif PyObject_IsInstance(factor_, (tuple, list)):
            sprite_copy = smoothscale(sprite_copy,factor_[0], factor_[1])
        else:
            raise ValueError('\nArgument factor_ incorrect '
                             'type must be float, int or tuple got %s ' % type(factor_))

    return sprite_copy

