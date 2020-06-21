###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True

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
class WeaponBulletHellClass:
    # Bullet hell class definition
    def __init__(self,
                 name_,         # bullet hell name
                 sprite_,       # laser sprite/surface
                 animation_,    # Muzzle flash if any
                 range_,        # maximum range
                 velocity_,     # maximum speed
                 damage_,       # maximum damage
                 energy_,       # energy needed for a single shot
                 sound_effect_, # laser sound effect
                 volume_,       # volume of the FX
                 shooting_,     # Variable True | False representing shooting status
                 reloading_,    # Reloading status
                 elapsed_,      # elapsed time since last shot
                 dt_angle_,     # Angle increment between each shots
                 angle_,        # first shot angle
                 bullet_hell_trajectory_,    # trajectory based on the angle variation
                 time_to_reload_ = None      # optional argument, time for the weapon to reload (not always used)
                 ):
        self.name = name_
        self.sprite = sprite_
        self.animation = animation_
        self.range = range_
        self.velocity = velocity_
        self.damage = damage_
        self.energy = energy_
        self.sound_effect = sound_effect_
        self.volume = volume_
        self.shooting = shooting_
        self.reloading = reloading_
        self.elapsed = elapsed_
        self.dt_angle = dt_angle_
        self.angle = angle_
        self.bullet_hell_trajectory = bullet_hell_trajectory_
        if time_to_reload_ is not None:
            self.time_to_reload = time_to_reload_
        ...

    def __copy__(self):
        """ copy the instance """
        return WeaponBulletHellClass(
            self.name, self.sprite, self.animation, self.range,
            self.velocity, self.damage, self.energy, self.sound_effect,
            self.volume, self.shooting, self.reloading, self.elapsed,
            self.dt_angle, self.angle, self.bullet_hell_trajectory,
            self.time_to_reload if hasattr(self, 'time_to_reload') else None
        )

