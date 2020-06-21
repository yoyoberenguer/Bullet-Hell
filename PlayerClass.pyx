###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True

# encoding: utf-8
try:
    cimport cython
    from cython.parallel cimport prange
    from cpython cimport PyObject, PyObject_HasAttr, PyObject_IsInstance
    from cpython.list cimport PyList_Append, PyList_GetItem, PyList_Size
except ImportError:
    print("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")
    raise SystemExit

from pygame import BLEND_RGB_SUB

try:
   from Sprites cimport Sprite
   from Sprites import Group, collide_mask, collide_rect, LayeredUpdates, spritecollideany, collide_rect_ratio
except ImportError:
    raise ImportError("\nSprites.pyd missing!.Build the project first.")

from Textures import COBRA_SHADOW
from BindSprites import BindSprite, BindShadow

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class Player(Sprite):

    cdef:
        public image, rect
        object gl
        public int _layer, angle, life, max_life, _rotation, _blend, last_rotation
        float timing, timer, dt

    def __init__(self, gl_, containers_, image_,
                 int pos_x, int pos_y, float timing_=60.0, int layer_=0, int blend_=0):

        Sprite.__init__(self, containers_)

        self.image         = image_
        self.rect          = image_.get_rect(center=(pos_x, pos_y))
        # self.mask        = mask.from_surface(self.image)
        self.gl            = gl_
        self._layer        = layer_
        self.timing        = timing_
        self.angle         = 0
        self.life          = 1000
        self.max_life      = 1000
        self._rotation     = 0
        self.last_rotation = 0
        self._blend        = blend_
        self.dt            = 0
        self.shadow        = COBRA_SHADOW

        # IF THE FPS IS ABOVE SELF.TIMING THEN
        # SLOW DOWN THE UPDATE
        self.timing = 1000.0 / timing_

        if gl_.MAX_FPS > timing_:
            self.timer = self.timing
        else:
            self.timer = 0.0

        self.drop_shadow()

    cdef drop_shadow(self):

        # SHADOW TEXTURE
        cdef:
            int w = self.shadow.get_width() >> 1
            int h = self.shadow.get_height() >> 1
            gl    = self.gl

        BindShadow(containers_      = gl.All,
                   object_          = self,
                   gl_              = gl,
                   offset_          = (w, h),
                   rotation_buffer_ = None,
                   timing_          = (1.0/self.timing) * 1000.0,
                   layer_           = self._layer - 1,
                   dependency_      = True,
                   blend_           = BLEND_RGB_SUB)


    cpdef update(self, args=None):
        cdef:
            float dt = self.dt
            gl       = self.gl
            rect     = self.rect

        if dt > self.timer:
            rect = rect.clamp(gl.SCREENRECT)
            dt = 0

        dt += gl.TIME_PASSED_SECONDS
        self.dt   = dt
        self.rect = rect



