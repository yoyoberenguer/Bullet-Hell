###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True

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

try:
   from Sprites cimport Sprite
   from Sprites import Group, collide_mask, collide_rect, LayeredUpdates, \
       spritecollideany, LayeredUpdatesModified, collide_rect_ratio
except ImportError:
    raise ImportError("\nCannot import library Sprites.")


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class Halo(Sprite):

    cdef:
        object gl_, images_copy
        public object image, rect, _name
        tuple center
        int index
        float dt, timing, timer
        public int _blend
        bint is_list

    def __init__(self,
                 gl_,
                 containers_,
                 images_,
                 int x,
                 int y,
                 float timing_=60.0,
                 int layer_   =-3,
                 int blend_   =0
                 ):

        Sprite.__init__(self, containers_)

        if PyObject_IsInstance(gl_.All, LayeredUpdates):
            gl_.All.change_layer(self, layer_)

        self.is_list = PyObject_IsInstance(images_, list)

        self.images_copy = images_ # .copy()
        if self.is_list:
            self.image   = <object>PyList_GetItem(images_,0)
            self.length1 = <int>PyList_Size(self.images_copy) - 1
        else:
            self.image   = images_
            self.length1 = 0

        self.center      = (x, y)
        self.rect        = self.image.get_rect(center=(x, y))
        if not self.rect.colliderect(gl_.SCREENRECT):
            self.kill()
            return
        self._blend      = blend_
        self.dt          = 0
        self.index       = 0
        self.gl          = gl_

        # IF THE FPS IS ABOVE SELF.TIMING THEN
        # SLOW DOWN THE PARTICLE ANIMATION
        self.timing = 1000.0 / timing_

        if gl_.MAX_FPS > timing_:
            self.timer = self.timing
        else:
            self.timer = 0.0
        self._name = 'HALO'


    cpdef update(self, args=None):

        cdef:
            int index = self.index
            int length1   = self.length1

        if self.dt > self.timer:

            if self.is_list:
                self.image = <object>PyList_GetItem(self.images_copy, index)
                # RE-CENTER THE SPRITE POSITION (SPRITE SURFACE CAN HAVE DIFFERENT SIZES)
                self.rect  = self.image.get_rect(center=(self.center[0], self.center[1]))
                if index < length1:
                    index += 1
                else:
                    self.kill()
            else:
                self.kill()


            self.dt = 0

        self.dt += self.gl.TIME_PASSED_SECONDS
        self.index = index


