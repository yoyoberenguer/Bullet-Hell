from random import random, randint

import HSV
from HSV import struct_rgb_to_hsv_c, rgb_to_hsv_c, rgb2hsv
import timeit

from Sprites import Sprite
import pygame
from pygame.transform import rotozoom, scale
from pygame.math import Vector2
from random import uniform, randint
from math import pi, cos, sin
from rand import randrange, randrangefloat





if __name__ == '__main__':
    import os, random
    random.seed()
    for r in range(100):
        print(randrange(0, 100))

    for r in range(100):
        print(randrangefloat(0.0, 100.0))


    r = 255
    g = 128
    b = 64
    print(struct_rgb_to_hsv_c(r, g, b))
    print(timeit.timeit("struct_rgb_to_hsv_c(r, g, b)",
                  "from __main__ import struct_rgb_to_hsv_c, r, g, b", number =1000000))
    print(timeit.timeit("rgb_to_hsv_c(r, g, b)",
                        "from __main__ import rgb_to_hsv_c, r, g, b", number=1000000))

    print(timeit.timeit("rgb2hsv(r, g, b)",
                        "from __main__ import rgb2hsv, r, g, b", number=1000000))

    l = []
    for r in range(10000000):
        l.append(randint(0, 800))
    import numpy
    print("timing :", timeit.timeit("sum(l)", "from __main__ import l", number=1))
    print("timing :", timeit.timeit("numpy.sum(l)", "from __main__ import numpy, l", number=1))

