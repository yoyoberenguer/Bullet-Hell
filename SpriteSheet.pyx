###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True
import cv2

# NUMPY IS REQUIRED
try:
    import numpy
    from numpy import ndarray, zeros, empty, uint8, int32, float64, float32, dstack, full, ones,\
    asarray, ascontiguousarray
except ImportError:
    print("\n<numpy> library is missing on your system."
          "\nTry: \n   C:\\pip install numpy on a window command prompt.")
    raise SystemExit

cimport numpy as np


# CYTHON IS REQUIRED
try:
    cimport cython
    from cython.parallel cimport prange
    from cpython cimport PyObject, PyObject_HasAttr, PyObject_IsInstance
    from cpython.list cimport PyList_Append, PyList_GetItem, PyList_Size
except ImportError:
    print("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")
    raise SystemExit


# PYGAME IS REQUIRED
try:
    import pygame
    from pygame import Color, Surface, SRCALPHA, RLEACCEL, BufferProxy
    from pygame.surfarray import pixels3d, array_alpha, pixels_alpha, array3d, make_surface, blit_array
    from pygame.image import frombuffer

except ImportError:
    print("\n<Pygame> library is missing on your system."
          "\nTry: \n   C:\\pip install pygame on a window command prompt.")
    raise SystemExit



# TODO CYTHON

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
def sprite_sheet_per_pixel(file_: str, chunk: int, rows_: int, columns_: int) -> list:
    surface = pygame.image.load(file_)
    buffer_ = surface.get_view('2')

    w, h = surface.get_size()
    source_array = numpy.frombuffer(buffer_, dtype=numpy.uint8).reshape((h, w, 4))
    animation = []

    for rows in range(rows_):
        for columns in range(columns_):
            array1 = source_array[rows * chunk:(rows + 1) * chunk,
                     columns * chunk:(columns + 1) * chunk, :]

            surface_ = pygame.image.frombuffer(array1.copy(order='C'),
                                               (tuple(array1.shape[:2])), 'RGBA').convert_alpha()
            animation.append(surface_.convert(32, pygame.SWSURFACE | pygame.RLEACCEL | pygame.SRCALPHA))

    return animation



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef sprite_sheet_fs8(str file, int chunk, int rows_, int columns_, bint tweak_ = False, args=None):
    """
    LOAD ANIMATION (SPRITE SHEET) INTO A PYTHON LIST CONTAINING SURFACES.
    
    This version is slightly slower than sprite_sheet_fs8_numpy using Numpy arrays.
    
    :param file    : string; file to be split into sub-surface
    :param chunk   : Size of a sub-surface, e.g for a spritesheet containing 256x256 pixels surface use chunk = 256
    :param rows_   : integer; number of rows (or number of surface embedded vertically)
    :param columns_: integer; Number of columns (or number of horizontal embedded surface) 
    :param tweak_  : bool; If True allow to tweak the chunk size for asymetric sub-surface. 
    You must provide a tuple after tweak=True such args=(256,128). 
    args contains the width and height of the sub-surface.
    :param args:   : tuple; default value is None. Use args in conjunction to tweak o specify asymetric sub-surface. 
    e.g arg=(256, 128) for loading sub-surface 256x128 
    :return: a list of sub-surface
    """

    cdef:
        unsigned char [:, :, :] array = pixels3d(pygame.image.load(file))

    cdef:
        list animation = []
        int rows, columns
        int chunkx, chunky
        int start_x, end_x, start_y, end_y;
        int w, h
        make_surface   = pygame.pixelcopy.make_surface

    if tweak_:
        if args is not None:
            if PyObject_IsInstance(args, (tuple, list)):
                chunkx = args[0]
                chunky = args[1]
            else:
                raise ValueError('\nArgument args must be a tuple or a list got %s ' % type(args))
        else:
            raise ValueError('\nArgument tweak=True must be followed by args=(value, value) ')
    else:
        chunkx = chunky = chunk

    cdef:
        unsigned char [:, :, ::1] empty_array = empty((chunkx, chunky, 3), uint8)

    w = chunkx
    h = chunky


    if tweak_:

        for rows in range(rows_):
            start_y = rows * chunky
            end_y   = (rows + 1) * chunky
            for columns in range(columns_):
                start_x = columns * chunkx
                end_x   = (columns + 1) * chunkx
                array1 = splitx(array, start_x, start_y, w, h, empty_array)
                sub_surface = make_surface(numpy.asarray(array1))
                # sub_surface.set_colorkey((0, 0, 0, 0), RLEACCEL)
                PyList_Append(animation, sub_surface)

    else:
        for rows in range(rows_):
            start_y = rows * chunky
            end_y   = (rows + 1) * chunky
            for columns in range(columns_):
                start_x = columns * chunkx
                end_x   = (columns + 1) * chunkx
                array1 = splitx(array, start_x, start_y, w, h, empty_array)
                sub_surface = make_surface(numpy.asarray(array1))
                # sub_surface.set_colorkey((0, 0, 0, 0), RLEACCEL)
                PyList_Append(animation, sub_surface)
    return animation


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef inline unsigned char [:, :, :] splitx(
        unsigned char [:, :, :] array_,
        int start_x, int start_y, int w, int h,
        unsigned char [:, :, :] block) nogil:
    """
    SPLIT AN ARRAY INTO BLOCK OF EQUAL SIZES
    
    :param array_ : unsigned char; array of size w x h x 3 to parse into sub blocks
    :param start_x: int; start of the block (x value) 
    :param start_y: int; start of the block (y value)
    :param w      : int; width of the block
    :param h      : int; height of the block
    :param block  : unsigned char; empty block of size w_n x h_n x 3 to fill up 
    :return       : Return 3d array of size (w_n x h_n x 3) of RGB pixels  
    """

    cdef:
        int x, y, xx, yy


    for x in prange(w):
        xx = start_x + x
        for y in range(h):
            yy = start_y + y
            block[x, y, 0] = array_[xx, yy, 0]
            block[x, y, 1] = array_[xx, yy, 1]
            block[x, y, 2] = array_[xx, yy, 2]
    return block




@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cpdef sprite_sheet_fs8_numpy(str file, int chunk, int columns_,
                             int rows_, tweak_= False, args=None):
    """
    RETRIEVE ALL SPRITES FROM A SPRITE SHEETS.
    
    Method using numpy arrays.

    :param file    : str,  full path to the texture
    :param chunk   : int, size of a single image in bytes e.g 64x64 (equal
    :param rows_   : int, number of rows
    :param columns_: int, number of column
    :param tweak_  : bool, modify the chunk sizes (in bytes) in order to process
                     data with non equal width and height e.g 320x200
    :param args    : tuple, used with tweak_, args is a tuple containing the new chunk size,
                     e.g (320, 200)
    :return: list, Return textures (surface) containing per-pixel transparency into a
            python list

    """
    assert PyObject_IsInstance(file, str), \
        'Expecting string for argument file got %s: ' % type(file)
    assert PyObject_IsInstance(chunk, int),\
        'Expecting int for argument number got %s: ' % type(chunk)
    assert PyObject_IsInstance(rows_, int) and PyObject_IsInstance(columns_, int), \
        'Expecting int for argument rows_ and columns_ ' \
        'got %s, %s ' % (type(rows_), type(columns_))

    cdef int width, height

    try:
        image_ = pygame.image.load(file)
        width, height = image_.get_size()

    except (pygame.error, ValueError):
        raise FileNotFoundError('\nFile %s is not found ' % file)

    if width==0 or height==0:
        raise ValueError(
            'Surface dimensions is not correct, must be: (w>0, h>0) got (w:%s, h:%s) ' % (width, height))

    try:
        # Reference pixels into a 3d array
        # pixels3d(Surface) -> array
        # Create a new 3D array that directly references the pixel values
        # in a Surface. Any changes to the array will affect the pixels in
        # the Surface. This is a fast operation since no data is copied.
        # This will only work on Surfaces that have 24-bit or 32-bit formats.
        # Lower pixel formats cannot be referenced.
        rgb_array_ = pixels3d(image_)

    except (pygame.error, ValueError):
        # Copy pixels into a 3d array
        # array3d(Surface) -> array
        # Copy the pixels from a Surface into a 3D array.
        # The bit depth of the surface will control the size of the integer values,
        # and will work for any type of pixel format.
        # This function will temporarily lock the Surface as
        # pixels are copied (see the Surface.lock()
        # lock the Surface memory for pixel access
        # - lock the Surface memory for pixel access method).
        try:
            rgb_array_ = pygame.surfarray.array3d(image_)
        except (pygame.error, ValueError):
            raise ValueError('\nIncompatible pixel format.')


    cdef:
        np.ndarray[np.uint8_t, ndim=3] rgb_array = rgb_array_
        np.ndarray[np.uint8_t, ndim=3] array1    = empty((chunk, chunk, 3), dtype=uint8)
        int chunkx, chunky, rows = 0, columns = 0

    # modify the chunk size
    if tweak_ and args is not None:

        if PyObject_IsInstance(args, tuple):
            try:
                chunkx = args[0][0]
                chunky = args[0][1]
            except IndexError:
                raise IndexError('Parse argument not understood.')
            if chunkx==0 or chunky==0:
                raise ValueError('Chunkx and chunky cannot be equal to zero.')
            if (width % chunkx) != 0:
                raise ValueError('Chunkx size value is not a correct fraction of %s ' % width)
            if (height % chunky) != 0:
                raise ValueError('Chunky size value is not a correct fraction of %s ' % height)
        else:
            raise ValueError('Parse argument not understood.')
    else:
        chunkx, chunky = chunk, chunk

    cdef:
        list animation = []
        make_surface   = pygame.pixelcopy.make_surface

    # split sprite-sheet into many sprites
    for rows in range(rows_):
        for columns in range(columns_):
            array1   = rgb_array[columns * chunkx:(columns + 1) * chunkx, rows * chunky:(rows + 1) * chunky, :]
            surface_ = make_surface(array1).convert()
            surface_.set_colorkey((0, 0, 0, 0), RLEACCEL)
            PyList_Append(animation, surface_)

    return animation
