###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True
try:
    cimport cython
except ImportError:
    print("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")
import time

cdef extern from 'randnumber.c':

    struct vector2d:
       float x;
       float y;

    float randRangeFloat(float lower, float upper, unsigned int t)nogil
    int randRange(int lower, int upper)nogil


cpdef randrange(a, b):
    return randRange(a, b)

cpdef randrangefloat(a, b):
    return randRangeFloat(a, b, time.time())