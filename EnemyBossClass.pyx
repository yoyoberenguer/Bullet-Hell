###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True
import copy
import timeit

from BindSprites import BindSprite, BindShadow, BindExplosion
from Halo import Halo
from Sounds import EXPLOSION_SOUND_2, GROUND_EXPLOSION
from Surface_tools import make_transparent
from Textures import G5V200_SHADOW, G5V200_SHADOW_ROTATION_BUFFER, BLURRY_WATER1, FIRE_PARTICLE_1, RADIAL, EXPLOSION19, \
    HALO_SPRITE9, EXPLOSION_DEBRIS, LASER_FX074, FX074_ROTATE_BUFFER, LASER_FX086, FX086_ROTATE_BUFFER, EXHAUST4, \
    EXPLOSION_LIST, HALO_SPRITE12

try:
    cimport cython
    from cython.parallel cimport prange
    from cpython cimport PyObject, PyObject_HasAttr, PyObject_IsInstance, PyObject_CallFunctionObjArgs
    from cpython.list cimport PyList_Append, PyList_GetItem, PyList_Size, PyList_SetItem
    from cpython.dict cimport PyDict_Values, PyDict_Keys, PyDict_Items, PyDict_GetItem, \
        PyDict_SetItem, PyDict_Copy
except ImportError:
    print("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")
    raise SystemExit

try:
    import pygame
    from pygame.math import Vector2
    from pygame import Rect, BLEND_RGB_ADD, HWACCEL, BLEND_RGB_MAX, BLEND_RGB_MULT, transform, BLEND_RGB_SUB
    from pygame import Surface, SRCALPHA, mask, event, RLEACCEL
    from pygame.transform import rotate, scale, smoothscale, rotozoom
except ImportError as e:
    print(e)
    raise ImportError("\n<Pygame> library is missing on your system."
          "\nTry: \n   C:\\pip install pygame on a window command prompt.")

try:
   from Sprites cimport Sprite
   from Sprites import Group, collide_mask, collide_rect, LayeredUpdates, spritecollideany, collide_rect_ratio
except ImportError:
    raise ImportError("\nSprites.pyd missing!.Build the project first.")

from numpy import array, arange


from libc.math cimport cos, exp, sin, atan2
import time


cdef extern from 'vector.c':

    struct vector2d:
       float x;
       float y;

    cdef float M_PI;
    cdef float M_PI2;
    cdef float M_2PI
    cdef float RAD_TO_DEG;
    cdef float DEG_TO_RAD;
    void vecinit(vector2d *v, float x, float y)nogil
    float vlength(vector2d *v)nogil
    void subv_inplace(vector2d *v1, vector2d v2)nogil
    vector2d subcomponents(vector2d v1, vector2d v2)nogil
    void scale_inplace(float c, vector2d *v)nogil

cdef extern from 'randnumber.c':
    float randRangeFloat(float lower, float upper)nogil
    int randRange(int lower, int upper)nogil

cdef long int [::1] OSCILLATIONS = array([10, 7, 2, -2, -5, -6, -4, -1,
                      -1, 3, 3, 2, 0, -1, -3, -2, -2,
                      0, 0, 1, 1, 0, -1, -1, 0], dtype=int)

cdef list VERTEX_DEBRIS            = []
cdef list VERTEX_BULLET_HELL       = []

cdef list COS_TABLE = []
cdef list SIN_TABLE = []
cdef int angle
COS_TABLE.append(cos(angle * DEG_TO_RAD) for angle in range(0, 360))
SIN_TABLE.append(sin(angle * DEG_TO_RAD) for angle in range(0, 360))

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef float damped_oscillation(double t)nogil:
    return <float>(exp(-t) * cos(M_PI * t))


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class DebrisGenerator(Sprite):

        cdef:
            public int _layer, _blend
            public object image, rect
            object position, vector, gl
            int index
            float dt, timer, timing

        def __init__(self, gl_, int x_, int y_, float timing_ =60.0, int _blend=0, int _layer=0):

            Sprite.__init__(self, gl_.All)

            self.image    = <object>PyList_GetItem(EXPLOSION_DEBRIS, randRange(0, len(EXPLOSION_DEBRIS) - 1))
            self.image    = rotozoom(self.image, randRange(0, 359), randRangeFloat(0.4, 1.0))
            self.position = Vector2(x_ + randRange(-100, 100), y_ + randRange(-100, 100))
            self.rect     = self.image.get_rect(center=self.position)
            cdef:
                float angle = randRangeFloat(0, M_2PI)
            self.vector   = Vector2(cos(angle) * randRange(-50, 50), sin(angle) * randRange(-50, 50))

            self.index    = 0
            self._layer   = _layer
            self._blend   = _blend
            self.dt       = 0
            self.gl       = gl_
            self.timing   =  1000.0 / timing_

             # TIMER CONTROL
            if gl_.MAX_FPS > timing_:
                self.timer = self.timing
            else:
                self.timer = 0.0

        cpdef update(self, args=None):

            cdef:
                float deceleration
                float dt         = self.dt
                rect             = self.rect
                screenrect       = self.gl.SCREENRECT
                float vector_x   = self.vector.x
                float vector_y   = self.vector.y
                image            = self.image
                int index        = self.index
                int w, h

            if dt > self.timer:

                if rect.colliderect(screenrect):

                    rect.x -= vector_x
                    rect.y -= vector_y
                    with nogil:
                        # DEBRIS DECELERATION
                        deceleration = 1.0 / (1.0 + 0.0001 * index * index)
                        vector_x *= deceleration
                        vector_y *= deceleration

                    if index % 2 == 0:
                        try:
                            w = image.get_width()
                            h = image.get_height()
                            image = scale(image, (w-1, h-1))
                        except ValueError:
                            self.kill()

                    dt = 0
                    self.index += 1
                    self.vector.x = vector_x
                    self.vector.y = vector_y
                    self.image = image

                else:
                    self.kill()
            dt += self.gl.TIME_PASSED_SECONDS
            self.dt = dt

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef loop_display_bullets(gl_):
    display_bullets(gl_)


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef void display_bullets(gl):
    """
    DISPLAY(DRAW) BULLETS 
        
    This method can be call from the main loop of your program or 
    in the update method of your sprite class. 
    To avoid a flickering effect between video flips, make sure
    to call this method every ticks.
    
    VERTEX_BULLET_HELL is a vertex array (python list) containing 
    all the bullets to be processed. 
    Bullets are dictionaries entity, not pygame sprites. 
    The above statement imply the following:
    1 - When a bullet is outside your game display, the function remove 
        will be called to erase the bullet.. not kill(). 
    2 - Make sure to call this function last and before flipping your display (no layer attributes)    
    
    e.g calling this method before drawing the background will place all the bullets 
    behind the background.
    
    Note: The game maximum FPS (default 60 FPS) is automatically dealt with pygame function
    in the main loop of your program. 
    If the value maximum FPS is changed to 800 for example, this would have an effect 
    on the bullets speed since the bullet velocity was computed for 60 FPS.  
    :return: None
    """

    cdef:
        screen_blit = gl.screen.blit
        screenrect  = gl.SCREENRECT
        int w2 = <object>PyDict_GetItem(BULLET_DICT, 'w2')
        int h2 = <object>PyDict_GetItem(BULLET_DICT, 'h2')
        int index
        dict s

    for s in list(VERTEX_BULLET_HELL):

        rect      = <object>PyDict_GetItem(s, 'rect')
        vector    = <object>PyDict_GetItem(s, 'vector')
        position  = <object>PyDict_GetItem(s, 'position')
        index     = <object>PyDict_GetItem(s, 'index')

        # BULLET OUTSIDE DISPLAY ?
        if rect.colliderect(screenrect):

            # BULLET POSITION IS UPDATED.
            position  += vector

            rect.centerx = <int>position.x - w2
            rect.centery = <int>position.y - h2
            index += 1
            PyDict_SetItem(s, 'index', index)
            PyObject_CallFunctionObjArgs(screen_blit,
                 <PyObject*><object>PyDict_GetItem(s, 'image'),
                 <PyObject*>rect.center,
                 <PyObject*>None,
                 <PyObject*><object>PyDict_GetItem(s, '_blend'),
                 NULL)
        else:
            VERTEX_BULLET_HELL.remove(s)


# FIRE PARTICLE CONTAINER
cdef list EXPLOSION_CONTAINER = []
cdef dict EXPLOSION_DICT = {'center': (0, 0), 'index': 0}

cdef dict BULLET_DICT = {'image':LASER_FX074, 'rect':None,
               'position':None, 'vector': None, '_blend': 1,
               'index': 0, 'damage': 0, 'w2': LASER_FX074.get_width() >> 1,
               'h2': LASER_FX074.get_height() >> 1}

cdef dict RING_DICT = {'image':None, 'rect':None,
               'position':None, 'vector': None, '_blend': 1,
               'index': 0, 'damage': 0}
cdef list RING_MODEL = []

cdef long int [::1] PATTERNS = array([10, 11, 12, 15,  16, 17, 18, 22, 24, 33], dtype=int)
cdef unsigned int PATTERN_LENGTH = len(PATTERNS) - 1

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef list create_bullets():

    cdef:
        int shooting_range = 36, shooting_angle = 5, dt_angle = 10
        float rad_angle
        float velocity = 12.0
        image = LASER_FX086
        list FX086 = FX086_ROTATE_BUFFER
        int r
        dict bullet_dict = RING_DICT

    for r in range(1):
        bullet_dict = PyDict_Copy(bullet_dict)
        shooting_angle += dt_angle
        rad_angle = shooting_angle * DEG_TO_RAD
        vector = Vector2( <float>cos(rad_angle) * velocity,
                         -<float>sin(rad_angle) * velocity)
        offset_x = 0
        offset_y = 0
        position = Vector2(0, 0)
        image = <object>PyList_GetItem(FX086, shooting_angle)
        rect  = image.get_rect(center=(0, 0))
        PyDict_SetItem(bullet_dict, 'image',    image)
        PyDict_SetItem(bullet_dict, 'rect',     rect)
        PyDict_SetItem(bullet_dict, 'position', position)
        PyDict_SetItem(bullet_dict, 'vector',   vector)
        RING_MODEL.append(bullet_dict)

    return RING_MODEL


RING_MODEL = create_bullets()



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef inline vector2d get_vector(int heading_, float magnitude_)nogil:
    """
    RETURN VECTOR COMPONENTS RELATIVE TO A GIVEN ANGLE AND MAGNITUDE 
    :return: Vector2d 
    """
    cdef float angle_radian = DEG_TO_RAD * heading_
    cdef vector2d vec
    vecinit(&vec, cos(angle_radian), -sin(angle_radian))
    scale_inplace(magnitude_, &vec)
    return vec


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef inline int get_angle(int obj1_x, int obj1_y, int obj2_x, int obj2_y)nogil:
        """
        RETURN THE ANGLE IN RADIANS BETWEEN TWO OBJECT OBJ1 & OBJ2 (center to center)
        
        :param obj1_x: source x coordinate
        :param obj1_y: source y coordinate
        :param obj2_x: target x coordinate
        :param obj2_y: target y coordinate
        :return: integer;  Angle between both objects (degrees)
        """
        cdef int dx = obj2_x - obj1_x
        cdef int dy = obj2_y - obj1_y
        return -<int>((RAD_TO_DEG * atan2(dy, dx)) % 360)


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class EnemyBoss(Sprite):

    cdef:
        public object image, rect
        public int _layer, _blend, _rotation, last_rotation, clocking_index
        object image_copy
        int length, index, length1, sprite_orientation, disruption_index, \
            quake_length, quake_index, exp_length, bullet_hell_angle, shooting_angle, \
            destruction_timer, explosion_frequency
        float timing, dt, timer, bullet_hell_ring_reload
        public bint clocking_status, destruction_status, disruption_status,\
            quake

    def __init__(self, gl_, weapon1_, weapon2_, containers_, int pos_x, int pos_y, image_,
                 float timing_=60.0, int layer_=-2, int _blend=0):
        """

        :param gl_        : class; global Constants/variables
        :param weapon1_   : dict; weapon1 features
        :param weapon2_   : dict; weapon2 features
        :param containers_: Sprite group(s) to use
        :param pos_x      : integer; x coordinates
        :param pos_y      : integer; y coordinates
        :param image_     : pygame.Surface; Surface/animations
        :param timing_    : float; FPS
        :param layer_     : integer; Layer to use
        :param _blend     : integer; additive mode
        """

        Sprite.__init__(self, containers_)
        self._layer = layer_
        self.gl     = gl_

        if PyObject_IsInstance(gl_.All, LayeredUpdates):
            gl_.All.change_layer(self, layer_)

        if PyObject_IsInstance(image_, list):
            self.image   = <object>PyList_GetItem(image_, 0)
            self.length1 = PyList_Size(image_) - 1
        else:
            self.image   = image_
        self.image_copy  = image_.copy()
        self.rect        = self.image.get_rect(center=(pos_x, pos_y))
        self.dt          = 0
        self.index       = 0
        self.timing      =  1000.0 / timing_
        self.fps         = timing_
        self._blend      = _blend

        # FLAG RAISED WHEN SHIP IS EXPLODING
        self.destruction_status  = False
        self.destruction_timer   = 0
        self.explosion_frequency = 50
        # FLAG RAISED WHEN SHIP IS DISRUPTED
        self.disruption_status  = False
        self.disruption_index   = 0

        # SPRITE ORIENTATION
        # ANGLE IN DEGREES CORRESPONDING
        # TO THE ORIGINAL IMAGE ORIENTATION
        # 0 DEGREES, SPACESHIP IMAGE IS ORIENTED
        # TOWARD THE RIGHT
        self.sprite_orientation = 0

        # ANGLE IN DEGREES CORRESPONDING
        # TO THE DIFFERENCE BETWEEN ORIGINAL (
        # self.sprite._rotation) IMAGE AND
        # ACTUAL SPRITE ORIENTATION
        # ZERO WOULD MEAN THAT THE SPRITE ANGLE IS
        # EQUAL TO THE ORIGINAL IMAGE ORIENTATION
        self._rotation      = 0
        # LEAVE IT AT 1 (INITIATE FIRST SHADOW DISPLAY)
        self.last_rotation  = 1

        self.weapon1 = weapon1_
        self.weapon2 = weapon2_
        self.bullet_hell_ring_reload = \
            <object>PyDict_GetItem(weapon1_,'reloading_time')  # 1.5 seconds
        self.ring_count_down         = \
            <object>PyDict_GetItem(weapon1_,'reload_countdown')

        self.bullet_hell_reload      = \
            <object>PyDict_GetItem(weapon2_,'reloading_time')
        self.bullet_count_down       = \
            <object>PyDict_GetItem(weapon2_,'reload_countdown')

        self.pattern_countdown       = 10e3 # 10 secs
        self.pattern_index           = 0

        self.bullet_hell_angle = PATTERNS[self.pattern_index]
        self.shooting_angle = 0

        # TIMER CONTROL
        if gl_.MAX_FPS > timing_:
            self.timer = self.timing
        else:
            self.timer = 0.0

        self.shadow         = G5V200_SHADOW
        self.quake_range    = arange(0.0, 1.0, 0.1)
        self.quake_length   = len(self.quake_range) - 1
        self.quake_index    = 0
        self.quake          = False

        # CLOCKING DEVICE STATUS
        self.clocking_status = False
        self.clocking_index  = 0    # MAX OPACITY

        self.exp_surface = FIRE_PARTICLE_1
        self.exp_length  = PyList_Size(FIRE_PARTICLE_1) - 1

        # DROP THE ENEMY SPACESHIP SHADOW
        self.enemy_shadow()

        # BUFFER 100 DEBRIS THAT WILL BE DISPLAY AFTER BOSS SPACESHIP EXPLOSION
        self.create_debris(x_=self.rect.centerx,
                           y_=self.rect.centery, debris_number_=200)

        # CREATE 36 BULLETS
        self.create_bullet_hell_ring(False)

        # DISPLAY PROPULSION
        self.exhaust_instance = None
        self.display_exhaust()



    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    cpdef update(self, args=None):
        cdef:
            int w2, h2, r, w, h
            float f_vol, volume
            float dt       = self.dt
            gl             = self.gl
            image          = self.image
            image_copy     = self.image_copy
            rect           = self.rect
            int index      = self.index
            int rect_cx    = rect.centerx
            int rect_cy    = rect.centery
            p_rect         = gl.player.rect
            clocking_index = self.clocking_index
            # COMPILE LOGIC VARIABLE
            bint is_list                   = \
                PyObject_IsInstance(image_copy, list)
            bint disruption_or_destruction = \
                self.disruption_status or self.destruction_status
            bint exhaust_running           = \
                self.exhaust_instance is not None and self.exhaust_instance.alive()

        # display_bullets(gl)

        if dt > self.timer:

            # GET THE ANGLE BETWEEN THE SPACESHIP AND THE PLAYER
            # TODO IMPLEMENT THE MAX_ROTATION / FRAME OTHERWISE SHIP WILL TURN
            # VERY FAST WHEN PLAYER IS PASSING BY

            if not disruption_or_destruction:
                self._rotation = get_angle(rect_cx, rect_cy,
                                           p_rect.centerx, p_rect.centery)

            image, rect = self.rot_center(
                <object>PyList_GetItem(image_copy, index),
                self._rotation, rect_cx, rect_cy)

            # DISRUPTION EFFECT (APPLY TEXTURE TO SELF.IMAGE)
            if disruption_or_destruction:
                image = self.disruption_effect(image)
                # SHOW EXPLOSIONS ON THE SPACESHIP HULL
                # CREATE HULL EXPLOSIONS
                position = Vector2(randRange(-rect.w >> 1, rect.w >> 1),
                                   randRange(-rect.h, rect.h))
                self.create_hull_explosions_fx(position.x, position.y)
                image = self.display_hull_explosions_fx(image)

            # QUAKE EFFECT
            if self.quake:
                self.spaceship_quake()
                # UPDATE THE RECT POSITION
                rect = self.rect
                rect_cx = self.rect.centerx
                rect_cy = self.rect.centery

            if self.destruction_status:

                # STOP THE SHIP EXHAUST SYSTEM
                self.stop_exhaust(exhaust_running)

                self.destruction_timer += 1

                # TRIGGER THE SPACESHIP EXPLOSION
                if self.destruction_timer > 150:
                    self.enemy_explosion()

                if gl.FRAME % self.explosion_frequency == 0:

                    # CHOOSE AN EXPLOSION FROM A PRE DEFINED LIST
                    rnd_explosion = <object>PyList_GetItem(EXPLOSION_LIST,
                                        randRange(0, PyList_Size(EXPLOSION_LIST) - 1))

                    w = (<object>PyList_GetItem(rnd_explosion, 0)).get_width()
                    h = (<object>PyList_GetItem(rnd_explosion, 0)).get_height()
                    w2 = w >> 2
                    h2 = h >> 2

                    # RANDOMIZE EXPLOSION LOCATION (OFFSET)
                    position = Vector2(randRangeFloat(-w2, w2),
                                       randRangeFloat(-h2 , h2 ))

                    # CREATE A FLASHING LIGHT EFFECT
                    Halo(gl_=gl, containers_=gl.All, images_=RADIAL,
                                 x=position.x + rect_cx, y=position.y + rect_cy, timing_=self.fps,
                                 layer_=randRange(self._layer - 1, self._layer), blend_=BLEND_RGB_ADD)

                    # VOLUME IS PROPORTIONAL TO THE EXPLOSION DIAMETER
                    f_vol = w / 512 if w != 0 else 1
                    volume = gl.SOUND_LEVEL / (1 / f_vol)
                    # PLAY AN EXPLOSION SOUND FROM A LIST OF SOUNDS
                    self.gl.SC_explosion.play(
                        sound_=<object>PyList_GetItem(GROUND_EXPLOSION, randRange(0, PyList_Size(GROUND_EXPLOSION)-1)),
                        loop_=False, priority_=2, volume_=volume, fade_out_ms=0, panning_=True,
                        name_='EXPLOSIONS', x_=rect.centerx)

                    # RANDOMIZE EXPLOSION FREQUENCY
                    self.explosion_frequency = randRange(10, 20)

                    # DISPLAY EXPLOSION
                    BindExplosion(containers_=gl.All, images_=rnd_explosion, gl_=gl,
                                  pos_x=position.x+rect_cx, pos_y=position.y+rect_cy, timing_=self.fps,
                                  layer_=self._layer, blend_=BLEND_RGB_ADD)

                    rect_ = self.rect.copy()
                    rect_.center = position + Vector2(rect.center)

                    Halo(gl_=gl, containers_=gl.All, images_=HALO_SPRITE12,
                                 x=rect_.centerx, y=rect_.centery, timing_=self.fps,
                                 layer_=self._layer, blend_=0)

                    # WILL ALLOW THE FUNCTION CALL spaceship_quake
                    self.quake = True

                    for r in range(10):
                        DebrisGenerator(gl_=gl, x_=rect_cx, y_=rect_cy, timing_ =self.fps,
                                            _blend=BLEND_RGB_ADD, _layer=0)

            # if self.gl.FRAME % 100 == 0:
            #     self.add_ring()
            #     ...

            if self.clocking_status and not disruption_or_destruction:
               image = self.clocking_device(image, clocking_index)

            if is_list:
                if index < self.length1:
                    index += 1
                else:
                    index = 0

            dt = 0

        dt += gl.TIME_PASSED_SECONDS
        self.dt    = dt
        self.index = index
        self.image = image
        self.rect  = rect

        if self.is_bullet_ring_reloading():
            self.create_bullet_hell_ring(disruption_or_destruction)

        if self.is_bullet_reloading():
            self.create_bullet_hell(disruption_or_destruction)

        display_bullets(gl)

        # TESTING CLOCKING DEVICE
        # if gl.FRAME > 250:
        #     self.clocking_status = True
        #     self.clocking_index += 1 if clocking_index < 180 else 0

        # TESTING EXPLOSIONS
        # if gl.FRAME > 800:
        #     self.destruction_status = True
        self.pattern_countdown -= gl.TIME_PASSED_SECONDS

    cdef clocking_device(self, image, clock_value):
        """
        CONTROL THE SPACESHIP HULL OPACITY 
        
        Add transparency to a surface (image)
        :param image      : Surface; image to modify  
        :param clock_value: Alpha value to use 
        :return           : return a pygame surface 
        """
        return make_transparent(image, clock_value).convert_alpha()


    cdef void enemy_shadow(self):
        """
        # DROP A SHADOW BELOW THE AIRCRAFT
        
        This method has to be called during instantiation
        Shadow instance is autonomous
        :return: None
        """
        cdef:
            gl    = self.gl
            int w = self.shadow.get_width()  >> 1
            int h = self.shadow.get_height() >> 1

        BindShadow(containers_      = gl.All,
                   object_          = self,
                   gl_              = gl,
                   offset_          = (w, h),
                   rotation_buffer_ = G5V200_SHADOW_ROTATION_BUFFER,
                   timing_          = (1.0/self.timing) * 1000.0,
                   layer_           = self._layer - 1,
                   dependency_      = True,
                   blend_           = BLEND_RGB_SUB)

    cdef tuple rot_center(self, image_, int angle_, int x, int y):
        """
        ROTATE THE ENEMY SPACESHIP IMAGE  
        
        :param y     : integer; x coordinate (rect center value) 
        :param x     : integer; y coordinate (rect center value)
        :param image_: pygame.Surface; Surface to rotate
        :param angle_: integer; Angle in degrees 
        :return: Return a tuple (surface, rect)
        """
        new_image = rotozoom(image_, angle_, 1.0)
        return new_image, new_image.get_rect(center=(x, y))

    cpdef location(self):
        """
        RETURN SPRITE RECT
        :return: Return the sprite rect (keep compatibility with other class)
        """
        return self.rect

    cdef int damage_calculator(self, int damage_, float gamma_, float distance_)nogil:
        """
        DETERMINES MAXIMUM DAMAGE TRANSFERABLE TO A TARGET.
        
        :param damage_  : int; Maximal damage  
        :param gamma_   : float;   
        :param distance_: float; distance between target and enemy rect center
        :return         : integer; Damage to transfer to target after impact.
        """
        cdef float delta = gamma_ * distance_

        if delta == 0:
            return damage_

        damage = <int>(damage_ / (gamma_ * distance_))
        if damage > damage_:
            return damage_
        return damage

    cdef float get_distance(self, vector2d v1, vector2d v2)nogil:
        """
        RETURN EUCLIDEAN DISTANCE BETWEEN TWO OBJECTS (v2 - v1)
        
        :param v1: vector2d; Vector 1 (Center of object 1)
        :param v2: vector2d; Vector 2 (Center of object 2)
        :return  : float; Vector length (Distance between two objects)
        """
        subv_inplace(&v2, v1)
        return vlength(&v2)

    cdef float damped_oscillation(self, double t)nogil:
        """
        DAMPENING EQUATION
        :return: float; 
        """
        return <float>(exp(-t) * cos(M_PI * t))

    cdef void spaceship_quake(self):
        """
        CREATE A QUAKE EFFECT (SPACESHIP SHACKING EFFECT)
        :return: None
        """
        cdef:
            int qi = self.quake_index
            int ql = self.quake_length

        self.rect.centerx += OSCILLATIONS[qi]
        qi += 1

        if qi > self.quake_length:
            self.quake = False
            qi = 0

        self.quake_index = qi

    cdef disruption_effect(self, image_):
        """
        APPLY A TEXTURE TO SELF.IMAGE (SPACESHIP DISRUPTION EFFECT)
        :return: pygame.Surface
        """
        cdef int length = <object>PyList_Size(BLURRY_WATER1) - 1
        disruption_layer_effect = <object>PyList_GetItem(BLURRY_WATER1, self.disruption_index % length)
        image_.blit(disruption_layer_effect, (0, 0), special_flags=BLEND_RGB_ADD)
        self.disruption_index += 1
        return image_

    cdef void disruption_effect_stop(self):
        """
        STOP THE DISRUPTION EFFECT 
        :return: None
        """
        self.disruption_index = 0

    cdef void create_hull_explosions_fx(self, int x_, int y_):
        """
        MULTIPLE HULL EXPLOSION EFFECT
            
        :param x_       : integer; particle x coordinate
        :param y_       : integer; particle y coordinate
        :return         : None
        """
        new_dict = PyDict_Copy(EXPLOSION_DICT)
        PyDict_SetItem(new_dict, 'center', (x_, y_))
        PyList_Append(EXPLOSION_CONTAINER, new_dict)


    cdef display_hull_explosions_fx(self, image_):
        """
        ITERATE OVER THE EXPLOSION CONTAINER
        
        :return: None 
        """

        cdef:
            int explosion_index
            int exp_length = self.exp_length
            image_blit     = image_.blit
            exp_surface    = self.exp_surface
            list explosion_container = EXPLOSION_CONTAINER
            dict explosion

        for explosion in explosion_container:

            explosion_index = <object>PyDict_GetItem(explosion, 'index')
            image           = <object>PyList_GetItem(exp_surface, explosion_index)
            center          = <object>PyDict_GetItem(explosion, 'center')

            PyObject_CallFunctionObjArgs(image_blit,
                                         <PyObject*>image,
                                         <PyObject*>center,
                                         <PyObject*>None,
                                         <PyObject*>BLEND_RGB_ADD,
                                         NULL)

            if explosion_index >= exp_length:
                explosion_container.remove(explosion)
            explosion['index'] += 1
        return image_


    cdef void enemy_explosion(self):
        """
        ENEMY SPACESHIP IS EXPLODING (LIGHT AND SOUND EFFECT)
        :return: None
        """
        cdef:
            gl = self.gl
            int rect_x = self.rect.centerx
            int rect_y = self.rect.centery
            int x, y, r
            float fps = self.fps

        # CREATE A FLASHING LIGHT EFFECT
        BindSprite(images_=RADIAL, containers_=gl.All, object_=self, gl_=gl,
                   offset_=None, timing_=fps, layer_=0, blend_=BLEND_RGB_ADD)

        BindExplosion(containers_=gl.All, images_=EXPLOSION19, gl_=gl,
                       pos_x=rect_x, pos_y=rect_y,
                      timing_=fps, layer_=0, blend_=BLEND_RGB_ADD)

        for r in range(2):
            # RANDOMIZE POSITION
            x = randRange(rect_x  - 100, rect_x + 100)
            y = randRange(rect_y  - 100, rect_y + 100)
            # CREATE AN EXPLOSION
            BindExplosion(containers_=gl.All, images_=EXPLOSION19, gl_=gl,
                       pos_x=x, pos_y=y, timing_=fps, layer_=0, blend_=BLEND_RGB_ADD)

        # CREATE HALO
        Halo(gl_=gl, containers_=gl.All, images_=HALO_SPRITE9,
                   x =rect_x, y =rect_y, timing_=fps, layer_=0, blend_=BLEND_RGB_ADD)

        gl.SC_explosion.play(
                sound_=EXPLOSION_SOUND_2,
                loop_=0, priority_=0,
                volume_=gl.SOUND_LEVEL,
                fade_out_ms=0, panning_=False,
                name_='G5V200_EXPLOSION',
                x_=rect_x, object_id_=id(EXPLOSION_SOUND_2))

        # BELOW CAUSE THE PROGRAM TO LAG
        self.gl.SHOCK_WAVE = True

        # DESTROY SPACESHIP
        self.kill()


    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    cdef void create_debris(self, int x_, int y_, int debris_number_):
        """
        CREATE SPACESHIP DEBRIS (DISPLAY AFTER EXPLOSION)
        
        :param debris_number_: integer; Debris number to be display (max entities)
        :param x_: integer; centre of the explosion x coordinate
        :param y_: integer; centre of the explosion y coordinate 
        :return: return None
        """

        cdef:
            int r
            dict debris_dict = {'image':None, 'rect':None, 'vector':None, 'index':0}
            int length = PyList_Size(EXPLOSION_DEBRIS) - 1, pos_x, pos_y
            float velocity, angle
            float rand
            vector2d vector

        for r in range(debris_number_):
            with nogil:
                angle = randRangeFloat(0, M_2PI)
                rand  = randRangeFloat(0.4, 1.0)
                pos_x = x_ + randRange(-100, 100)
                pos_y = y_ + randRange(-100, 100)
                velocity           = randRange(1, 25)
                vecinit(&vector, cos(angle) * velocity, sin(angle) * velocity)
            debris             = PyDict_Copy(debris_dict)
            PyDict_SetItem(debris, 'image', <object>PyList_GetItem(EXPLOSION_DEBRIS, randRange(0, length)))
            PyDict_SetItem(debris, 'image', rotozoom(debris['image'], <int>(angle * RAD_TO_DEG), rand))
            PyDict_SetItem(debris, 'rect', debris['image'].get_rect(center=(pos_x, pos_y)))
            PyDict_SetItem(debris, 'vector', vector)
            # PyDict_SetItem(debris, 'index', 0)
            VERTEX_DEBRIS.append(debris)


    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    cpdef void update_debris(self, gl_, int framerate_):
        """
        UPDATE DEBRIS POSITIONS 
        
        This method has to be called from the main loop has the 
        enemy instance is killed when the enemy ship is destroyed.  
        
        :param framerate_: integer; Framerate   
        :param gl_       : class; global game variable / constants
        :return          : None
        """

        cdef:
            screenrect = gl_.SCREENRECT
            screen     = gl_.screen
            float deceleration = 0
            int w, h
            screen_blit = screen.blit
            int index
            vector2d vector
            dict debris

        for debris in VERTEX_DEBRIS:

            rect    = <object>PyDict_GetItem(debris, 'rect')
            image   = <object>PyDict_GetItem(debris, 'image')
            index   = <object>PyDict_GetItem(debris, 'index')
            vector_ = <object>PyDict_GetItem(debris, 'vector')
            vecinit(&vector, vector_['x'], vector_['y'])

            if PyObject_CallFunctionObjArgs(rect.colliderect, <PyObject*>screenrect, NULL):
                with nogil:
                    deceleration = 1.0 / (1.0 + 1e-6 * index * index)
                    vector.x *= deceleration
                    vector.y *= deceleration
                rect.move_ip(vector.x, vector.y)

                PyObject_CallFunctionObjArgs(screen_blit,
                                         <PyObject*>image,
                                         <PyObject*>rect.center,
                                         <PyObject*>None,
                                         <PyObject*>BLEND_RGB_ADD,
                                         NULL)

                if index % framerate_ == 0:

                    try:
                        w = image.get_width()
                        h = image.get_height()
                        image = scale(image, (w - 1, h - 1))
                    except ValueError:
                        VERTEX_DEBRIS.remove(debris)
                        continue

                PyDict_SetItem(debris, 'index', index + 1)
                PyDict_SetItem(debris, 'rect', rect)
                PyDict_SetItem(debris, 'image', image)
                PyDict_SetItem(debris, 'vector', vector)

            else:
                VERTEX_DEBRIS.remove(debris)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    cdef void create_bullet_hell_ring(self, bint disruption_or_destruction):
        """
        CREATE BULLET RING (BULLET HELL)
        
        This method create bullets and put them into a vertex array VERTEX_BULLET_HELL
        The bullet parameters are setup during the instantiation and attributes can be resumed 
        into a python dictionaries BULLET_DICT = {'image':LASER_FX074, 'rect':None,
               'position':None, 'vector': None, '_blend': 1,
               'index': 0, 'damage': 0, 'w2': LASER_FX074.get_width() >> 1,
               'h2': LASER_FX074.get_height() >> 1}
               
        One the bullet has been pushed into the vertex array, the method display_bullets 
        will take over and update all the bullets positions at once on your display.
        
        :param : disruption_or_destruction: bool; Boolean value True if ship is exploding or disrupted
        :return: None
        """
        if disruption_or_destruction:
            return

        # NOTE 36 BULLETS CAN BE CREATED BEFORE THE MAIN LOOP
        # ONLY RECTS AND POSITION ATTRIBUTES HAVE TO BE UPDATE.
        # SEE METHOD ADD_BULLET FOR AN IMPLEMENTATION EXAMPLE.
        cdef:
            # COVER 0 - 360 degrees
            int shooting_range = 36
            # FIRST SHOT WILL BE AT 5 DEGREES
            int shooting_angle = 5
            # INCREMENT ANGLE BY 10 DEGREES
            int dt_angle       = 10
            gl                 = self.gl
            float velocity     = (<object>PyDict_GetItem(self.weapon1,'velocity')).length()
            float cs           = 50.0
            float rad_angle, offset_x, offset_y, rad_angle_
            int rect_x         = self.rect.centerx
            int rect_y         = self.rect.centery
            image              = LASER_FX074
            list FX074         = FX074_ROTATE_BUFFER
            int r
            dict bullet_dict
            int rotation = self._rotation

        with nogil:
            rad_angle_ = DEG_TO_RAD * rotation
            offset_x, offset_y = -cos(rad_angle_) * cs, -sin(rad_angle_) * cs

        position = Vector2(rect_x + offset_x, rect_y - offset_y)
        # CREATE 36 BULLETS
        for r in range(shooting_range):

            bullet_dict = PyDict_Copy(BULLET_DICT)
            with nogil:
                shooting_angle += dt_angle
                shooting_angle %= 360
                rad_angle = shooting_angle * DEG_TO_RAD
            # if PyObject_IsInstance(gl.All, LayeredUpdates):
            #     gl.All.change_layer(bullet_dict, self._layer)
            vector = Vector2( <float>cos(rad_angle) * velocity,
                             -<float>sin(rad_angle) * velocity)
            image = <object>PyList_GetItem(FX074, shooting_angle)
            rect  = image.get_rect(center=(position.x, position.y))
            PyDict_SetItem(bullet_dict, 'image',    image)
            PyDict_SetItem(bullet_dict, 'rect',     rect)
            PyDict_SetItem(bullet_dict, 'position', Vector2(position))
            PyDict_SetItem(bullet_dict, 'vector',   vector)
            VERTEX_BULLET_HELL.append(bullet_dict)


    cdef bint is_bullet_ring_reloading(self):
        """
        CHECK IF A WEAPON IS RELOADED AND READY.
        
        Returns True when the weapon is ready to shoot else return False
        :return: bool; True | False
        """

        if self.ring_count_down <= 0:
            # RESET THE COUNTER
            self.ring_count_down = self.bullet_hell_ring_reload
            # READY TO SHOOT
            return True
        else:
            # DECREMENT COUNT DOWN VALUE WITH LATEST DT (DIFFERENTIAL TIME) VALUE
            self.ring_count_down -= self.gl.TIME_PASSED_SECONDS
            # RELOADING
            return False

    cdef bint is_bullet_reloading(self):
        """
        CHECK IF A WEAPON IS RELOADED AND READY.
        Returns True when the weapon is ready to shoot else return False
        :return: bool; True | False
        """
        if self.bullet_count_down <= 0:
            # RESET THE COUNTER
            self.bullet_count_down = self.bullet_hell_reload
            # READY TO SHOOT
            return True
        else:
            # DECREMENT COUNT DOWN VALUE WITH LATEST DT (DIFFERENTIAL TIME) VALUE
            self.bullet_count_down -= self.gl.TIME_PASSED_SECONDS
            # RELOADING
            return False


    cdef void display_exhaust(self):
        """
        DISPLAY ENEMY PROPULSION EXHAUST (FOLLOW THE SHIP MOVEMENT)
        
        :return: None
        """
        cdef:
            int height = (<object>PyList_GetItem(self.image_copy, 0)).get_height()
            int offset_y = (height >> 1) + 20

        self.exhaust_instance = BindSprite(images_=EXHAUST4, containers_=self.gl.All, object_=self, gl_=self.gl,
                   offset_=(0, offset_y), timing_=self.fps, layer_=self._layer - 1,
                   loop_=True, dependency_=True, follow_=True, event_='G5200_EXHAUST', blend_=0)

    cdef void stop_exhaust(self, exhaust_running):
        if exhaust_running:
            self.exhaust_instance.kill_instance(self.exhaust_instance)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    cdef void create_bullet_hell(self, disruption_or_destruction):
        """
        CREATE BULLET HELL
        
        This method create bullets and put them into a vertex array VERTEX_BULLET_HELL
        The bullet parameters are setup during the instantiation and attributes can be resumed 
        into a python dictionaries BULLET_DICT = {'image':LASER_FX074, 'rect':None,
               'position':None, 'vector': None, '_blend': 1,
               'index': 0, 'damage': 0, 'w2': LASER_FX074.get_width() >> 1,
               'h2': LASER_FX074.get_height() >> 1}
               
        One the bullet has been pushed into the vertex array, the method display_bullets 
        will take over and update all the bullets positions at once on your display.
        
        :return: None
        """
        if disruption_or_destruction:
            return

        cdef:
            int deg_angle      = 0
            gl                 = self.gl
            int gl_frame       = gl.FRAME
            float rad_angle, offset_x, offset_y, rad_angle_
            float velocity     = (<object>PyDict_GetItem(self.weapon2,'velocity')).length()
            float cs           = 50.0
            int rect_x         = self.rect.centerx
            int rect_y         = self.rect.centery
            image              = LASER_FX086 # not defined yet
            list FX086         = FX086_ROTATE_BUFFER
            int r
            dict bullet_dict
            int rotation = self._rotation

        # CHANGE BULLET PATTERN EVERY
        if self.pattern_countdown < 0:
            # PATTERN IS A NUMPY ARRAY
            self.pattern_index +=1
            self.bullet_hell_angle = PATTERNS[self.pattern_index % PATTERN_LENGTH]
            self.pattern_countdown = 10e3

        # RELEASE THE GIL
        with nogil:
            # rad_angle_ is the spaceship rotation value in radians
            rad_angle_ = DEG_TO_RAD * rotation
            # OFFSET BULLETS ORIGIN
            offset_x, offset_y = -cos(rad_angle_) * cs, -sin(rad_angle_) * cs

        # BULLET ORIGIN
        position = Vector2(rect_x + offset_x, rect_y - offset_y)

        cdef int bullet_hell_angle = self.bullet_hell_angle

        # CREATE 4 BULLETS SHOOT AT DIFFERENT ANGLE (SAME ORIGIN)
        # AT CONSTANT VELOCITY
        for r in range(4):

            bullet_dict = PyDict_Copy(BULLET_DICT)
            self.shooting_angle += bullet_hell_angle
            deg_angle = self.shooting_angle % 360
            rad_angle = deg_angle * DEG_TO_RAD
            # if PyObject_IsInstance(gl.All, LayeredUpdates):
            #     gl.All.change_layer(bullet_dict, self._layer)
            vector = Vector2( <float>cos(rad_angle) * velocity,
                             -<float>sin(rad_angle) * velocity)

            image = <object>PyList_GetItem(FX086, deg_angle)
            rect  = image.get_rect(center=(position.x, position.y))
            PyDict_SetItem(bullet_dict, 'image',    image)
            PyDict_SetItem(bullet_dict, 'rect',     rect)
            PyDict_SetItem(bullet_dict, 'position', Vector2(position))
            PyDict_SetItem(bullet_dict, 'vector',   vector)
            VERTEX_BULLET_HELL.append(bullet_dict)




    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.nonecheck(False)
    @cython.cdivision(True)
    cdef void add_ring(self):
        """
        NOT USED
        
        :return: 
        """

        cdef:
            list model = []
            rect = self.rect
            rect_x = self.rect.centerx
            rect_y = self.rect.centery
            int shooting_angle = 0
            int i = 0
            dict bullet

        for i in range(36):

            bullet_dict = PyDict_Copy(BULLET_DICT)
            bullet = <object>PyList_GetItem(RING_MODEL, i)
            position = Vector2(rect_x, rect_y)
            image = <object>PyDict_GetItem(bullet, 'image')
            rect  = image.get_rect(center=(position.x, position.y))
            PyDict_SetItem(bullet_dict, 'image',    image)
            PyDict_SetItem(bullet_dict, 'rect',     rect)
            PyDict_SetItem(bullet_dict, 'position', Vector2(position))
            PyDict_SetItem(bullet_dict, 'vector',   bullet['vector'])

            VERTEX_BULLET_HELL.append(bullet_dict)
