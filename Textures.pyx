###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True
# TODO:
# TO GAIN EXTRA TIME RECORD CHANGES TO DISK TO AVOID TRANSFORMING/
# ROTATING/SCALING IMAGES EACH TIME (CACHE).
# FIRST LAUNCH WILL BE SLOWER BUT NEXT ONES SHOULD BE MUCH FASTER.
# WHEN THE CACHE IS CORRUPTED DELETE THE TEMPORARY FOLDER WHERE THE
# CACHE IS LOCATED.

from Surface_tools import reshape, make_transparent

try:
    cimport cython
    from cython.parallel cimport prange
    from cpython cimport PyObject, PyObject_HasAttr, PyObject_IsInstance
    from cpython.list cimport PyList_Append, PyList_GetItem, PyList_Size
except ImportError:
    print("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")
    raise SystemExit

try:
    import pygame
    from pygame.math import Vector2
    from pygame import Rect, BLEND_RGB_ADD, HWACCEL, BLEND_RGB_MAX, BLEND_RGB_MULT, transform
    from pygame import Surface, SRCALPHA, mask, event, RLEACCEL
    from pygame.transform import rotate, scale, smoothscale, rotozoom, scale2x
except ImportError as e:
    print(e)
    raise ImportError("\n<Pygame> library is missing on your system."
          "\nTry: \n   C:\\pip install pygame on a window command prompt.")

from SpriteSheet import sprite_sheet_fs8, sprite_sheet_per_pixel
from HSV import hue_surface_32
from BLOOM cimport bloom_effect_buffer24_c, bloom_effect_buffer32_c

from numpy import array


BACKGROUND   = pygame.image.load('Assets\\A5.png').convert(32, RLEACCEL)

cdef int w, h
COBRA        = pygame.image.load('Assets\\SpaceShip.png').convert_alpha()
# USE ADDITIVE MODE FOR BETTER APPEARANCE
COBRA.blit(COBRA, (0, 0), special_flags=BLEND_RGB_ADD)
w            = COBRA.get_width()
h            = COBRA.get_height()
COBRA_SHADOW = smoothscale(pygame.image.load('Assets\\SpaceShip_shadow_.png'),
    (<int>(w * 1.2), <int>(h * 1.2))).convert(32, RLEACCEL)


EXPLOSION19  = sprite_sheet_fs8('Assets\\Boss_explosion1_6x8_512_.png',
                                    chunk=512, rows_=8, columns_=6, tweak_=False)
cdef:
    int a = len(EXPLOSION19)
    int b = <int>(128.0 / a)
    int i = 0
for surface in EXPLOSION19:
    EXPLOSION19[i] = bloom_effect_buffer32_c(surface, 128 - i * b , 2).convert(32, RLEACCEL)
    i += 1

i = 0

G5V200_SURFACE   = pygame.image.load("Assets\\Boss7.png").convert_alpha()

G5V200_SURFACE   = smoothscale(G5V200_SURFACE, (200, 200))
# USE ADDITIVE MODE FOR BETTER APPEARANCE
G5V200_SURFACE.blit(G5V200_SURFACE, (0, 0), special_flags=BLEND_RGB_ADD)
G5V200_ANIMATION = [G5V200_SURFACE] * 30


s = pygame.display.get_surface()
for surf in G5V200_ANIMATION:
    image = hue_surface_32(surf, <double>(i * 12.0)/360.0).convert_alpha()
    image = bloom_effect_buffer32_c(image, 128, smooth_=1)
    # pygame.event.pump()
    # s.blit(image, (0, 0))
    # pygame.display.flip()
    # pygame.time.delay(500)
    G5V200_ANIMATION[i] = image.convert_alpha()
    # hue_surface(surf, i * 12)

    i += 1


w = G5V200_SURFACE.get_width()
h = G5V200_SURFACE.get_height()
G5V200_SHADOW = smoothscale(
    pygame.image.load('Assets\\Boss7_shadow_.png'),
    (<int>(w * 1.2) // 4, <int>(h * 1.2) // 4)).convert(32, pygame.RLEACCEL)

G5V200_SHADOW_ROTATION_BUFFER = []
for angle in range(360):
    PyList_Append(G5V200_SHADOW_ROTATION_BUFFER,
                  rotozoom(G5V200_SHADOW, angle, 4.0))

BLURRY_WATER1   = sprite_sheet_fs8('Assets\\Blurry_Water1_256x256_6x6.png', 256, 6, 6)
i = 0
for surf in BLURRY_WATER1:
    BLURRY_WATER1[i] = surf.convert(32, RLEACCEL)
    i += 1
# FIRE_PARTICLE_1 = sprite_sheet_fs8('Assets\\Particles_128x128_.png', 128, 6, 6)
FIRE_PARTICLE_1 = sprite_sheet_fs8("Assets\\Boss_explosion1_6x8_512_.png", 512, 8, 6)
i = 0
for surf in FIRE_PARTICLE_1:
    FIRE_PARTICLE_1[i] = surf.convert(32, RLEACCEL)
    i += 1

FIRE_PARTICLE_1 = reshape(FIRE_PARTICLE_1, (64, 64))


#
# RADIAL = [pygame.image.load("Assets\\Radial5_.png").convert(32, pygame.RLEACCEL)] * 5
# cdef:
#     j = 0
#     float ii=0
# w = RADIAL[0].get_width()
# h = RADIAL[0].get_height()
# for surface in RADIAL:
#     if j != 0:
#         RADIAL[j] = smoothscale(surface, (<int>(w / ii), <int>(h / ii)))
#     else:
#         RADIAL[0] = surface
#     ii +=1
#     j += 1
RADIAL = pygame.image.load("Assets\\Radial5_.png").convert(32, pygame.RLEACCEL)

HALO_SPRITE9  = []
TMP_SURFACE = pygame.image.load('Assets\\halo12_.png') # .convert(32, RLEACCEL)
w = TMP_SURFACE.get_width()
h = TMP_SURFACE.get_height()
cdef int number
for number in range(16):
    surface1 = smoothscale(TMP_SURFACE, (
        <int>(w * (1 + (number / 2.0))),
        <int>(h * (1 + (number / 2.0)))))
    # surface1 = make_transparent(surface1, number * 31)
    surface1 = bloom_effect_buffer24_c(surface1, 160 - number * 10, 2)

    # pygame.event.pump()
    # s.blit(surface1, (0, 0))
    # pygame.display.flip()
    # pygame.time.delay(200)

    HALO_SPRITE9.append(surface1)
del TMP_SURFACE




G5V200_DEBRIS = [
                pygame.image.load('Assets\\G5V200_DEBRIS_\\Boss7Debris1.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\Boss7Debris2.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\Boss7Debris3.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\Boss7Debris4.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\Boss7Debris5.png').convert(32, pygame.RLEACCEL)
                ]

G5V200_DEBRIS_HOT = [
                pygame.image.load('Assets\\G5V200_DEBRIS_\\debris1.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\debris2.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\debris3.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\debris4.png').convert(32, pygame.RLEACCEL),
                pygame.image.load('Assets\\G5V200_DEBRIS_\\debris5.png').convert(32, pygame.RLEACCEL)
                ]

G5V200_DEBRIS = reshape(G5V200_DEBRIS, factor_=(16, 16))
G5V200_DEBRIS_HOT = reshape(G5V200_DEBRIS_HOT, factor_=(16, 16))
EXPLOSION_DEBRIS = [*G5V200_DEBRIS_HOT, *G5V200_DEBRIS]


LASER_FX074 = pygame.image.load('Assets\\lzrfx074_1.png').convert(32, RLEACCEL)
LASER_FX074.blit(LASER_FX074, (0, 0), special_flags=BLEND_RGB_ADD)
w = LASER_FX074.get_width()
h = LASER_FX074.get_height()
LASER_FX074 = scale(LASER_FX074, (<int>(w *0.85) , <int>(h *0.85)))
FX074_ROTATE_BUFFER = []
for angle in range(361):
    FX074_ROTATE_BUFFER.append(rotate(LASER_FX074, angle).convert(32, RLEACCEL))


LASER_FX086 = pygame.image.load('Assets\\lzrfx086_.png').convert(32, RLEACCEL)
w = LASER_FX086.get_width()
h = LASER_FX086.get_height()
LASER_FX086 = scale(LASER_FX086, (<int>(w *0.75) , <int>(h *0.75)))
LASER_FX086.blit(LASER_FX086, (0, 0), special_flags=BLEND_RGB_ADD)

FX086_ROTATE_BUFFER = []
for angle in range(361):
    FX086_ROTATE_BUFFER.append(rotate(LASER_FX086, angle).convert(32, RLEACCEL))

EXHAUST4 = sprite_sheet_per_pixel('Assets\\Exhaust8.png', 256, 6, 6)
EXHAUST4 = reshape(EXHAUST4, (128, 128))

MISSILE_EXPLOSION = sprite_sheet_fs8("Assets\\explosion3_.png", 256, 4, 7)

HALO_SPRITE12 = [smoothscale(
    pygame.image.load('Assets\\Halo11.png').convert_alpha(), (64, 64))] * 10

STEPS = array([0., 0.03333333, 0.06666667, 0.1, 0.13333333,
             0.16666667, 0.2, 0.23333333, 0.26666667, 0.3,
             0.33333333, 0.36666667, 0.4, 0.43333333, 0.46666667,
             0.5, 0.53333333, 0.56666667, 0.6, 0.63333333,
             0.66666667, 0.7, 0.73333333, 0.76666667, 0.8,
             0.83333333, 0.86666667, 0.9, 0.93333333, 0.96666667])
i = 0
for surface in HALO_SPRITE12:
    image = make_transparent(surface, int(255 * STEPS[i]))
    surface1 =smoothscale(image, (
        int(surface.get_width()  * (1.0 + (i / 2.0))),
        int(surface.get_height() * (1.0 + (i / 2.0)))))
    HALO_SPRITE12[i] = surface1.convert_alpha()
    i += 1

EXPLOSION_LIST = [reshape(MISSILE_EXPLOSION, 1/2),
                  reshape(MISSILE_EXPLOSION, 2/3),
                  MISSILE_EXPLOSION,
                  reshape(MISSILE_EXPLOSION, 2)]


if __name__ == '__main__':
  ...