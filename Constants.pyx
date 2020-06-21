###cython: boundscheck=False, wraparound=False, nonecheck=False, optimize.use_switch=True
# encoding: utf-8

from numpy import arange

# CYTHON IS REQUIRED
from pygame.rect import Rect

try:
    cimport cython
    from cython.parallel cimport prange
    from cpython cimport PyObject, PyObject_HasAttr, PyObject_IsInstance
    from cpython.list cimport PyList_Append, PyList_GetItem, PyList_Size
except ImportError:
    print("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")
    raise SystemExit



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class CONSTANTS:
    """
    DEFINE YOUR GAME VARIABLES AND CONSTANT

    To access your variables
    1) Create first an instance of the class
        GL = CONSTANTS()
    2) Access the variable
        GL.MAX_FPS      -> point to MAX_FPS VAR

    PS: TO MAKE YOUR VARIABLE VISIBLE FROM AN EXTERNAL ACCESS USE
        cdef public
        If the variable is not public, an attribute error will be raised
    """

    cdef:
        public int FRAME, MAX_FPS
        public object SHOCK_WAVE, SCREENRECT, screen, All, VERTEX_DEBRIS
        public double [:] SHOCK_WAVE_RANGE
        public int SHOCK_WAVE_INDEX, SHOCK_WAVE_LEN
        public object BOMB_CONTAINER, DEBRIS_CONTAINER, PLAYER_GROUP,\
            GROUP_UNION, ENEMY_GROUP, SC_spaceship, SC_explosion, player, BACKGROUND_VECTOR
        public float SOUND_LEVEL, TIME_PASSED_SECONDS
        public bint PAUSE


    def __cinit__(self):
        self.FRAME               = 0
        self.MAX_FPS             = 800
        self.SHOCK_WAVE          = False  # True move the screen with a dampening variation (left - right)
        self.SHOCK_WAVE_RANGE    = arange(0.0, 10.0, 0.1)
        self.SHOCK_WAVE_LEN      = len(self.SHOCK_WAVE_RANGE) - 1
        self.SHOCK_WAVE_INDEX    = 0
        self.SCREENRECT          = Rect(0, 0, 800, 1024)
        self.screen              = None
        self.All                 = None
        self.PLAYER_GROUP        = None
        self.ENEMY_GROUP         = None
        self.GROUP_UNION         = None
        self.SC_spaceship        = None
        self.SC_explosion        = None
        self.SOUND_LEVEL         = 1.0
        self.player              = None
        self.PAUSE               = False
        self.TIME_PASSED_SECONDS = 0.0
        self.BACKGROUND_VECTOR   = None


