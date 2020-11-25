# encoding: utf-8
import time
import timeit
from random import randint

from pygame.image import tostring


from SoundServer import SoundControl

try:
    import pygame
    from pygame.math import Vector2
    from pygame import Rect, BLEND_RGB_ADD, HWACCEL, BLEND_RGB_MAX, BLEND_RGB_MULT, transform, HWSURFACE, BLEND_RGB_MIN
    from pygame import Surface, SRCALPHA, mask, event, RLEACCEL
    from pygame.transform import rotate, scale, smoothscale
    from pygame import Rect
except ImportError as e:
    print(e)
    raise ImportError("\n<Pygame> library is missing on your system."
          "\nTry: \n   C:\\pip install pygame on a window command prompt.")

try:
   from Sprites import Sprite
   from Sprites import Group, collide_mask, collide_rect, LayeredUpdates, LayeredUpdatesModified, \
       spritecollideany, collide_rect_ratio
except ImportError:
    raise ImportError("\nSprites.pyd missing!.Build the project first.")

from Constants import CONSTANTS
GL = CONSTANTS()
pygame.display.init()
SCREEN    = pygame.display.set_mode(GL.SCREENRECT.size,  HWSURFACE, 32)
GL.screen = SCREEN


from PlayerClass import Player
from Textures import COBRA, BACKGROUND, G5V200_ANIMATION, FIRE_PARTICLE_1
from numpy import fromstring, uint8
from matplotlib import pyplot as plt
from EnemyBossClass import EnemyBoss, damped_oscillation
from xml_parsing import xml_get_weapon
from Textures import G5V200_SHADOW, G5V200_SHADOW_ROTATION_BUFFER, BLURRY_WATER1, FIRE_PARTICLE_1, RADIAL, EXPLOSION19, \
    HALO_SPRITE9, EXPLOSION_DEBRIS, LASER_FX074, FX074_ROTATE_BUFFER, LASER_FX086, FX086_ROTATE_BUFFER, EXHAUST4, \
    EXPLOSION_LIST, HALO_SPRITE12


def xml_parsing(xml_features):
    weapon_features = {}
    for key, value in xml_features.items():
        if key in ('name', 'type'):
            continue

        if key == "image":
            try:
                weapon_features[key] = eval(value)
            except NameError:
                raise NameError('\nSprite %s image %s not loaded into memory!' % (key, value))

        elif key == "sprite_rotozoom":
            try:
                weapon_features[key] = eval(value)
            except NameError:
                raise NameError('\nSprite %s image %s not loaded into memory!' % (key, value))

        elif key == 'range':
            weapon_features[key] = eval(value)

        elif key == 'velocity':
            weapon_features[key] = pygame.math.Vector2(float(value), float(value))

        else:
            try:
                weapon_features[key] = int(value)
            except ValueError:
                try:
                    weapon_features[key] = float(value)
                except ValueError:
                    raise ValueError('\nData not understood: %s %s ' % (key, value))
    return weapon_features


if __name__ == '__main__':

    pygame.init()
    if int(pygame.version.ver[0]) >= 2:
        pygame.mixer.init(44100, -16, 1, 4095, allowedchanges=0)
    else:
        pygame.mixer.init(44100, -16, 1, 4095)

    GL.SC_explosion        = SoundControl(GL.SCREENRECT, 20)
    clock                  = pygame.time.Clock()
    GL.TIME_PASSED_SECONDS = clock.tick(GL.MAX_FPS)
    All                    = LayeredUpdatesModified()
    GL.All                 = All
    GL.PLAYER_GROUP        = pygame.sprite.Group()
    GL.VERTEX_DEBRIS       = pygame.sprite.Group()
    GL.ENEMY_GROUP         = pygame.sprite.Group()

    SCREENRECT = GL.SCREENRECT
    FX074_XML = dict(xml_get_weapon('Weapon.xml', 'LASER_FX074'))
    FX086_XML = dict(xml_get_weapon('Weapon.xml', 'LASER_FX086'))
    LASER_FX074_DICT = xml_parsing(FX074_XML)
    LASER_FX086_DICT = xml_parsing(FX086_XML)

    STOP_GAME       = False
    QUIT            = False
    PLAYER_GROUP    = Group()
    GL.PLAYER_GROUP = PLAYER_GROUP
    containers      = GL.All, PLAYER_GROUP
    GL.player       = Player(gl_=GL, containers_=containers, image_=COBRA, pos_x=GL.SCREENRECT.centerx,
                        pos_y=GL.SCREENRECT.centery + 300)

    enemy = EnemyBoss(gl_=GL, weapon1_=LASER_FX074_DICT, weapon2_=LASER_FX086_DICT, containers_=GL.All,
                      pos_x=200, pos_y=150, image_=G5V200_ANIMATION, timing_=60.0,
                      layer_=-2, _blend=0)

    RECORDING    = False  # allow RECORDING video
    VIDEO        = []     # Capture frames
    FPS_AVG      = []
    CONSTANT_AVG = []
    DT           = 0
    VIDEO_FPS    = 60.0
    C1           = 1000.0/VIDEO_FPS

    # TWEAKS
    gl_all                 = GL.All
    gl_all_draw            = GL.All.draw
    gl_all_update          = GL.All.update
    gl_time_passed_seconds = GL.TIME_PASSED_SECONDS
    clock_tick             = clock.tick
    clock_get_fps          = clock.get_fps
    display_flip           = pygame.display.flip
    screen_blit            = SCREEN.blit
    event_pump             = pygame.event.pump
    key_get_pressed        = pygame.key.get_pressed

    TMP = []
    while not STOP_GAME:

        event_pump()
        keys = key_get_pressed()

        if keys[pygame.K_ESCAPE]:
            STOP_GAME = True

        if keys[pygame.K_RIGHT]:
            GL.player.rect.centerx += 4

        if keys[pygame.K_LEFT]:
            GL.player.rect.centerx -= 4

        if keys[pygame.K_UP]:
            GL.player.rect.centery -= 4

        if keys[pygame.K_DOWN]:
            GL.player.rect.centery += 4

        if keys[pygame.K_F8]:
            pygame.image.save(SCREEN, "screenshot" + str(GL.FRAME) + ".png")
        if keys[pygame.K_SPACE]:
            if not enemy.alive():
                GL.FRAME = 0
                enemy = EnemyBoss(gl_=GL, weapon1_=LASER_FX074_DICT, weapon2_=LASER_FX086_DICT, containers_=GL.All,
                      pos_x=200, pos_y=150, image_=G5V200_ANIMATION, timing_=60.0,
                      layer_=-2, _blend=0)

        if GL.SHOCK_WAVE:
            # shake the screen
            # if DT % 16 == 0:
            screen_blit(BACKGROUND, (damped_oscillation(GL.SHOCK_WAVE_RANGE[GL.SHOCK_WAVE_INDEX]) * 50, 0))
            s = Surface(GL.SCREENRECT.size)
            s.fill((max(255 - GL.SHOCK_WAVE_INDEX * 4, 0), 0, 0, 0))
            SCREEN.blit(s, (0, 0), special_flags=BLEND_RGB_ADD)
            GL.SHOCK_WAVE_INDEX += 1
            if GL.SHOCK_WAVE_INDEX > GL.SHOCK_WAVE_LEN:
                GL.SHOCK_WAVE = False
                GL.SHOCK_WAVE_INDEX = 0
        else:
            screen_blit(BACKGROUND, (0, 0))

        gl_all_update()

        if not enemy.alive():
            enemy.update_debris(GL, framerate_=17)

        #print(timeit.timeit("enemy.update_debris(GL)", "from __main__ import enemy, GL", number=100000))
        gl_all_draw(SCREEN)
        # collision = pygame.sprite.spritecollideany(GL.player,
        #                                            EnemyBoss.BULLET_HELL_VERTEX,
        #                                            collided = pygame.sprite.collide_circle_ratio(0.65))
        # collision.kill()

        gl_time_passed_seconds = clock_tick(GL.MAX_FPS)
        DT += gl_time_passed_seconds

        # print(clock_get_fps(), len(GL.All))

        display_flip()

        GL.SC_explosion.update()
        # GL.SC_spaceship.update()
        GL.FRAME += 1

        # !! REMOVE THE BLOCK BELOW FOR A RELEASE VERSION !!
        if clock_get_fps() != 0:
            t1 = time.time()
            FPS_AVG.append(clock_get_fps())
            if len(FPS_AVG)!= 0:
                  avg = sum(FPS_AVG)/len(FPS_AVG)
            CONSTANT_AVG.append(avg)
            t2 = time.time()
            TMP.append(t2 - t1)

        if RECORDING:
            if GL.MAX_FPS > VIDEO_FPS:
                if DT >= C1:
                    VIDEO.append(tostring(SCREEN, 'RGB', False))
                    DT = 0
            else:
                VIDEO.append(tostring(SCREEN, 'RGB', False))
        GL.TIME_PASSED_SECONDS = gl_time_passed_seconds

    # *** Record the video
    if RECORDING:
        print(GL.SCREENRECT.w, GL.SCREENRECT.h)
        import cv2
        from cv2 import COLOR_RGBA2BGR
        import numpy

        video = cv2.VideoWriter('Bombing.avi',
                                cv2.VideoWriter_fourcc('M', 'J', 'P', 'G'), VIDEO_FPS,
                                (GL.SCREENRECT.w, GL.SCREENRECT.h), True)

        for event in pygame.event.get():
            pygame.event.clear()

        for image in VIDEO:
            image = fromstring(image, uint8).reshape(GL.SCREENRECT.h, GL.SCREENRECT.w, 3)
            image = cv2.cvtColor(image, COLOR_RGBA2BGR)
            video.write(image)

        cv2.destroyAllWindows()
        video.release()

    plt.plot(FPS_AVG)
    plt.plot(CONSTANT_AVG)
    AVG = []
    assert len(FPS_AVG)!=0, '\nFPS_AVG list cannot be empty!'
    avg = sum(FPS_AVG) / len(FPS_AVG)
    for r in range(len(FPS_AVG)):
        AVG.append(avg)

    plt.plot(AVG)
    plt.plot(TMP)
    plt.title("FPS AVG")
    plt.draw()
    plt.show()

    pygame.quit()
