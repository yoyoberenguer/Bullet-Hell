###cython: boundscheck=False, wraparound=False, nonecheck=False, cdivision=True, optimize.use_switch=True
# encoding: utf-8

# CYTHON IS REQUIRED
from pygame.time import get_ticks

try:
    cimport cython
    from cython.parallel cimport prange
    from cpython cimport PyObject_CallFunctionObjArgs, PyObject, \
        PyList_SetSlice, PyObject_HasAttr, PyObject_IsInstance, \
        PyObject_CallMethod, PyObject_CallObject
    from cpython.dict cimport PyDict_DelItem, PyDict_Clear, PyDict_GetItem, PyDict_SetItem, \
        PyDict_Values, PyDict_Keys, PyDict_Items
    from cpython.list cimport PyList_Append, PyList_GetItem, PyList_Size
    from cpython.object cimport PyObject_SetAttr

except ImportError:
    raise ImportError("\n<cython> library is missing on your system."
          "\nTry: \n   C:\\pip install cython on a window command prompt.")

# PYGAME IS REQUIRED
try:
    from pygame import display
    from pygame.mask import from_surface
    from pygame import Rect


except ImportError:
    raise ImportError("\n<Pygame> library is missing on your system."
          "\nTry: \n   C:\\pip install pygame on a window command prompt.")

from libc.math cimport sqrt

# Python 3 does not have the callable function, but an equivalent can be made
# with the hasattr function.
if 'callable' not in dir(__builtins__):
    callable = lambda obj: PyObject_HasAttr(obj, '__call__')


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class Sprite(object):

    # The groups the sprite is in

    def __init__(self, *groups):
        """
        :param groups: python list containing pygame groups
        (optional argument)
        :return: None
        """
        self.__dict__ = {}
        self.__g = {}
        if groups is not None:
            self.add(*groups)

    def add(self, *groups):
        """add the sprite to groups

        Sprite.add(*groups): return None

        Any number of Group instances can be passed as arguments. The
        Sprite will be added to the Groups it is not already a member of.

        """
        has = self.__g.__contains__
        for group in groups:
            if PyObject_HasAttr(group, '_spritegroup'):
                if not has(group):
                    group.add_internal(self)
                    self.add_internal(group)
            else:
                self.add(*group)

    def remove(self, *groups):
        """remove the sprite from groups

        Sprite.remove(*groups): return None

        Any number of Group instances can be passed as arguments. The Sprite
        will be removed from the Groups it is currently a member of.

        """
        has = self.__g.__contains__
        for group in groups:
            if PyObject_HasAttr(group, '_spritegroup'):
                if has(group):
                    group.remove_internal(self)
                    self.remove_internal(group)
            else:
                self.remove(*group)

    cpdef add_internal(self, object group):
        PyDict_SetItem(self.__g, group, 0)
        # self.__g[group] = 0

    cpdef remove_internal(self, object group):
        PyDict_DelItem(self.__g, group)
        # del self.__g[group]

    cpdef update(self, args=None):
        """
        The default implementation of this method does nothing; it's just a
        convenient "hook" that you can override. This method is called by
        Group.update() with whatever arguments you give it.
        :param args: Optional argument (default None)
        :return: None
        """
        pass

    cpdef kill(self):
        """
        remove the Sprite from all Groups
        kill() -> None
        The Sprite is removed from all the Groups that contain it.
        This won't change anything about the state of the Sprite. 
        It is possible to continue to use the Sprite after this method 
        has been called, including adding it to Groups.
        :return: None
        """
        for c in self.__g:
            c.remove_internal(self)
        self.__g.clear()
        # PyDict_Clear(self.__g)

    cpdef list groups(self):
        """
        list of Groups that contain this Sprite
        groups() -> group_list
        Return a list of all the Groups that contain this Sprite.
        :return: group_list
        """
        return list(self.__g)

    cpdef bint alive(self):
        """
        does the sprite belong to any groups
        alive() -> bool
        Returns True when the Sprite belongs to one or more Groups.
        """
        return True if self.__g else False

    # METHOD BELOW CANNOT BE CONVERTED INTO CDEF
    # SPECIAL PYTHON METHOD
    def __repr__(self):
        return "<%s sprite(in %d groups)>" \
               % (self.__class__.__name__, len(self.__g))


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class DirtySprite(Sprite):
    """a more featureful subclass of Sprite with more attributes

    pygame.sprite.DirtySprite(*groups): return DirtySprite

    Extra DirtySprite attributes with their default values:

    dirty = 1
        If set to 1, it is repainted and then set to 0 again.
        If set to 2, it is always dirty (repainted each frame;
        flag is not reset).
        If set to 0, it is not dirty and therefore not repainted again.

    blendmode = 0
        It's the special_flags argument of Surface.blit; see the blendmodes in
        the Surface.blit documentation

    source_rect = None
        This is the source rect to use. Remember that it is relative to the top
        left corner (0, 0) of self.image.

    visible = 1
        Normally this is 1. If set to 0, it will not be repainted. (If you
        change visible to 1, you must set dirty to 1 for it to be erased from
        the SCREEN.)

    _layer = 0
        0 is the default value but this is able to be set differently
        when subclassing.

    """
    cdef int dirty, blendmode, _visible, _layer
    cdef object source_rect

    def __init__(self, *groups):

        self.dirty = 1
        self.blendmode = 0  # pygame 1.8, referred to as special_flags in
                            # the documentation of Surface.blit
        self._visible = 1
        self._layer = getattr(self, '_layer', 0)    # Default 0 unless
                                                    # initialized differently.
        self.source_rect = None
        Sprite.__init__(self, *groups)

    cpdef _set_visible(self, int val):
        """set the visible value (0 or 1) and makes the sprite dirty"""
        self._visible = val
        if self.dirty < 2:
            self.dirty = 1

    cpdef int _get_visible(self):
        """return the visible value of that sprite"""
        return self._visible

    visible = property(lambda self: self._get_visible(),
                       lambda self, value: self._set_visible(value),
                       doc="you can make this sprite disappear without "
                           "removing it from the group,\n"
                           "assign 0 for invisible and 1 for visible")

    def __repr__(self):
        return "<%s DirtySprite(in %d groups)>" % \
            (self.__class__.__name__, len(self.groups()))


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class AbstractGroup(object):

    cdef public bint _spritegroup
    cdef public dict spritedict
    cdef public list lostsprites

    def __cinit__(self, *args, **kwargs):

        self._spritegroup = True
        self.spritedict = {}
        self.lostsprites = []


    cpdef list sprites(self):
        """
        list of the Sprites this Group contains
        sprites() -> sprite_list
        Return a list of all the Sprites this group contains.
        You can also get an iterator from the group, but you cannot 
        iterator over a Group while modifying it.
        
        :return: sprite_list
        """
        return list(self.spritedict)

    # CANNOT BE cdef
    cpdef void add_internal(self, sprite):
        self.spritedict[sprite] = 0

    # CANNOT BE cdef
    cpdef void remove_internal(self, sprite):
        r = self.spritedict[sprite]
        if r:
            self.lostsprites.append(r)
        del self.spritedict[sprite]

    cpdef bint has_internal(self, sprite):
        return sprite in self.spritedict

    cpdef copy(self):
        """
        duplicate the Group
        copy() -> Group
        Creates a new Group with all the same Sprites as the original. 
        If you have subclassed Group, the new obj will have the 
        same (sub-)class as the original. This only works if the derived
         class's constructor takes the same arguments as the Group class's.
        :return: Group
        """
        return self.__class__(self.sprites())

    # SPECIAL CLASS CANNOT BE CYTHONIZED
    def __iter__(self):
        return iter(self.sprites())

    # SPECIAL CLASS CANNOT BE CYTHONIZED
    def __contains__(self, sprite):
        return self.has(sprite)

    def add(self, *sprites):
        """
        add sprite(s) to group

        Group.add(sprite, list, group, ...): return None

        Adds a sprite or sequence of sprites to a group.

        """
        cdef has_internal = self.has_internal
        cdef add_internal = self.add_internal
        cdef add          = self.add
        for sprite in sprites:
            # It's possible that some sprite is also an iterator.
            # If this is the case, we should add the sprite itself,
            # and not the iterator obj.
            if PyObject_IsInstance(sprite, Sprite):
                if not has_internal(sprite):
                    add_internal(sprite)
                    sprite.add_internal(self)
            else:
                try:
                    # See if sprite is an iterator, like a list or sprite
                    # group.
                    add(*sprite)
                except (TypeError, AttributeError):
                    # Not iterable. This is probably a sprite that is not an
                    # instance of the Sprite class or is not an instance of a
                    # subclass of the Sprite class. Alternately, it could be an
                    # old-style sprite group.
                    if PyObject_HasAttr(sprite, '_spritegroup'):

                        for spr in sprite.sprites():
                            if not has_internal(spr):
                                add_internal(spr)
                                spr.add_internal(self)
                    elif not has_internal(sprite):
                        add_internal(sprite)
                        sprite.add_internal(self)

    def remove(self, *sprites):
        """
        remove sprite(s) from group

        Group.remove(sprite, list, or group, ...): return None

        Removes a sprite or sequence of sprites from a group.

        """
        # This function behaves essentially the same as Group.add. It first
        # tries to handle each argument as an instance of the Sprite class. If
        # that failes, then it tries to handle the argument as an iterable
        # obj. If that failes, then it tries to handle the argument as an
        # old-style sprite group. Lastly, if that fails, it assumes that the
        # normal Sprite methods should be used.

        cdef remove_internal = self.remove_internal
        cdef has_internal = self.has_internal
        cdef remove          = self.remove

        for sprite in sprites:
            if PyObject_IsInstance(sprite, Sprite):
                if has_internal(sprite):
                    remove_internal(sprite)
                    sprite.remove_internal(self)
            else:
                try:
                    remove(*sprite)
                except (TypeError, AttributeError):
                    if PyObject_HasAttr(sprite, '_spritegroup'):
                        for spr in sprite.sprites():
                            if has_internal(spr):
                                remove_internal(spr)
                                spr.remove_internal(self)
                    elif has_internal(sprite):
                        remove_internal(sprite)
                        sprite.remove_internal(self)

    def has(self, *sprites):
        """ask if group has a sprite or sprites

        Group.has(sprite or group, ...): return bool

        Returns True if the given sprite or sprites are contained in the
        group. Alternatively, you can get the same information using the
        'in' operator, e.g. 'sprite in group', 'subgroup in group'.

        """
        cdef bint return_value = False
        cdef has_internal      = self.has_internal
        cdef has               = self.has

        for sprite in sprites:
            if PyObject_IsInstance(sprite, Sprite):
                # Check for Sprite instance's membership in this group
                if has_internal(sprite):
                    return_value = True
                else:
                    return False
            else:
                try:
                    if has(*sprite):
                        return_value = True
                    else:
                        return False
                except (TypeError, AttributeError):
                    if PyObject_HasAttr(sprite, '_spritegroup'):
                        for spr in sprite.sprites():
                            if has_internal(spr):
                                return_value = True
                            else:
                                return False
                    else:
                        if has_internal(sprite):
                            return_value = True
                        else:
                            return False

        return return_value

    cpdef void update(self, args=None):
        """
        call the update method on contained Sprites
        update(*args, **kwargs) -> None
        Calls the update() method on all Sprites in the Group. 
        The base Sprite class has an update method that takes 
        any number of arguments and does nothing. The arguments 
        passed to Group.update() will be passed to each Sprite.
        There is no way to get the return value from the Sprite.update() methods.
        :param args: 
        :return: 
        """
        # method update is supposed to be override by user's class.
        for s in self.sprites():
            s.update()

    cpdef draw(self, object surface):
        """
        blit the Sprite images
        draw(Surface) -> None
        Draws the contained Sprites to the Surface argument. 
        This uses the Sprite.image attribute for the source
         surface, and Sprite.rect for the position.
        The Group does not keep sprites in any order, so the 
        draw order is arbitrary.
        :param surface: 
        :return: None
        """
        cdef:
            list sprites = list(self.spritedict)
            surface_blit = surface.blit
            spritedict = self.spritedict

        for spr in sprites:
            # blit all the sprite using surface.blit.
            # Note that special flag is unused
            # Also the below assume that the sprite has an image and a
            # pygame rect. This is not always the case, and the below code
            # might throw and error message
            # contains pygame rect
            # self.spritedict[spr] = surface_blit(spr.image, spr.rect)
            ret = PyObject_CallFunctionObjArgs(surface_blit,
                                         <PyObject*>spr.image,
                                         <PyObject*>spr.rect, NULL)
            # PyDict_SetItem(spritedict, spr, ret)
            self.spritedict[spr] = ret

        # all sprites being drawn, clear the dict lostsprites
        self.lostsprites[:] = []

    # TODO CYTHON
    cpdef void clear(self, object surface, object bgd):
        """
        draw a background over the Sprites
        clear(Surface_dest, background) -> None
        Erases the Sprites used in the last Group.draw() call.
        The destination Surface is cleared by filling the drawn
        Sprite positions with the background.
        The background is usually a Surface image the same dimensions
        as the destination Surface. However, it can also be a callback
        function that takes two arguments; the destination Surface
        and an area to clear. The background callback function will
         be called several times each clear.
        Here is an example callback that will clear the Sprites with solid red:

        def clear_callback(surf, rect):
            color = 255, 0, 0
            surf.fill(color, rect)
        :param surface:
        :param bgd:
        :return:
        """

        if callable(bgd):
            for r in self.lostsprites:
                bgd(surface, r)
            for r in PyDict_Values(self.spritedict):
                if r:
                    bgd(surface, r)
        else:
            surface_blit = surface.blit
            for r in self.lostsprites:
                surface_blit(bgd, r, r)
            for r in PyDict_Values(self.spritedict):
                if r:
                    surface_blit(bgd, r, r)

    cpdef void empty(self):
        """
        remove all Sprites
        empty() -> None
        Removes all Sprites from this Group.
        :return:
        """
        cdef list sprites = list(self.spritedict) # -> keys
        cdef object s

        for s in sprites:
            # remove sprite from group
            # r = self.spritedict[s]
            r = PyDict_GetItem(self.spritedict, s)
            if r:
                PyList_Append(self.lostsprites, <object>r)
            PyDict_DelItem(self.spritedict, s)
            # remove sprite itself
            s.remove_internal(self)

    def __nonzero__(self):
        return truth(list(self.spritedict))

    def __len__(self):
        return PyList_Size(self.sprites())

    def __repr__(self):
        return "<%s(%d sprites)>" % (self.__class__.__name__, len(self))



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class Group(AbstractGroup):
    """container class for many Sprites

    pygame.sprite.Group(*sprites): return Group

    A simple container for Sprite objects. This class can be subclassed to
    create containers with more specific behaviors. The constructor takes any
    number of Sprite arguments to add to the Group. The group supports the
    following standard Python operations:

        in      test if a Sprite is contained
        len     the number of Sprites contained
        bool    test if any Sprites are contained
        iter    iterate through all the Sprites

    The Sprites in the Group are not ordered, so the Sprites are drawn and
    iterated over in no particular order.

    """

    def __init__(self, *sprites):
        AbstractGroup.__init__(self)
        if sprites is not None:
            self.add(*sprites)


RenderPlain = Group
RenderClear = Group

# TODO CYTHON
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class RenderUpdates(Group):
    """Group class that tracks dirty updates

    pygame.sprite.RenderUpdates(*sprites): return RenderUpdates

    This class is derived from pygame.sprite.Group(). It has an enhanced draw
    method that tracks the changed areas of the SCREEN.

    """
    def draw(self, surface):
       spritedict = self.spritedict
       surface_blit = surface.blit
       dirty = self.lostsprites
       self.lostsprites = []
       dirty_append = dirty.append
       for s in self.sprites():
           r = spritedict[s]
           newrect = surface_blit(s.image, s.rect)
           if r:
               if newrect.colliderect(r):
                   dirty_append(newrect.union(r))
               else:
                   dirty_append(newrect)
                   dirty_append(r)
           else:
               dirty_append(newrect)
           spritedict[s] = newrect
       return dirty


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class OrderedUpdates(RenderUpdates):
    """RenderUpdates class that draws Sprites in order of addition

    pygame.sprite.OrderedUpdates(*spites): return OrderedUpdates

    This class derives from pygame.sprite.RenderUpdates().  It maintains
    the order in which the Sprites were added to the Group for rendering.
    This makes adding and removing Sprites from the Group a little
    slower than regular Groups.

    """
    cdef list _spritelist

    def __cinit__(self, *sprites_):
        self._spritelist = []
        # INHERIT METHOD DRAW
        RenderUpdates.__init__(self, *sprites_)

    # OVERRIDE METHOD AbstractGroup.sprites
    cpdef list sprites(self):
        return list(self._spritelist)

    # OVERRIDE METHOD AbstractGroup.add_internal
    cpdef void add_internal(self, sprite):
        RenderUpdates.add_internal(self, sprite)
        self._spritelist.append(sprite)

    # OVERRIDE METHOD AbstractGroup.remove_internal
    cpdef void remove_internal(self, sprite):
        RenderUpdates.remove_internal(self, sprite)
        self._spritelist.remove(sprite)

# TODO TEST CYTHON
@cython.boundscheck(False)
@cython.wraparound(True)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class LayeredUpdates(AbstractGroup):
    """RenderUpdates class that draws Sprites in order of addition

    pygame.sprite.OrderedUpdates(*spites): return OrderedUpdates

    This class derives from pygame.sprite.RenderUpdates().  It maintains
    the order in which the Sprites were added to the Group for rendering.
    This makes adding and removing Sprites from the Group a little
    slower than regular Groups.

    """

    cdef public dict _spritelayers
    cdef public list _spritelist
    cdef public int _default_layer
    cdef public object _init_rect
    # cdef public dict __dict__

    def __cinit__(self, *sprites, **kwargs):
        """initialize an instance of LayeredUpdates with the given attributes

        You can set the default layer through kwargs using 'default_layer'
        and an integer for the layer. The default layer is 0.

        If the sprite you add has an attribute _layer, then that layer will be
        used. If **kwarg contains 'layer', then the passed sprites will be
        added to that layer (overriding the sprite._layer attribute). If
        neither the sprite nor **kwarg has a 'layer', then the default layer is
        used to add the sprites.

        """

        self._init_rect    = Rect(0, 0, 0, 0)
        self._spritelayers = {}
        self._spritelist   = []
        AbstractGroup.__init__(self)
        self._default_layer = kwargs.get('default_layer', 0)

        self.add(*sprites, **kwargs)


    cpdef void add_internal(self, sprite, layer_=None):
        """Do not use this method directly.

        It is used by the group to add a sprite internally.

        """

        self.spritedict[sprite] = self._init_rect

        cdef int layer

        if layer_ is None:
            # TRY EXCEPT IS FASTER THAN IF ELSE
            try:
                layer = sprite._layer
            except AttributeError:
                layer = sprite._layer = self._default_layer

        # UPDATE SPRITE LAYER
        elif PyObject_HasAttr(sprite, '_layer'):
            layer = sprite._layer = layer_

        cdef list sprites = self._spritelist
        cdef dict sprites_layers = self._spritelayers
        PyDict_SetItem(sprites_layers, sprite, layer)

        # add the sprite at the right position
        # bisect algorithmus
        cdef int leng = PyList_Size(sprites)
        cdef int low = 0, mid = 0, high = leng -1

        while low <= high:
            mid = low + ((high - low) >> 1)
            if sprites_layers[sprites[mid]] <= layer:
                low = mid + 1
            else:
                high = mid - 1
        # linear search to find final position
        while mid < leng and sprites_layers[sprites[mid]] <= layer:
            mid += 1
        sprites.insert(mid, sprite)

    def add(self, *sprites, **kwargs):
        """add a sprite or sequence of sprites to a group

        LayeredUpdates.add(*sprites, **kwargs): return None

        If the sprite you add has an attribute _layer, then that layer will be
        used. If **kwarg contains 'layer', then the passed sprites will be
        added to that layer (overriding the sprite._layer attribute). If
        neither the sprite nor **kwarg has a 'layer', then the default layer is
        used to add the sprites.

        """

        if not sprites:
            return

        if 'layer' in kwargs:
            layer = kwargs['layer']
        else:
            layer = None

        cdef has_internal = self.has_internal
        cdef add_internal = self.add_internal
        cdef add          = self.add

        for sprite in sprites:
            # It's possible that some sprite is also an iterator.
            # If this is the case, we should add the sprite itself,
            # and not the iterator obj.
            if PyObject_IsInstance(sprite, Sprite):
                if not has_internal(sprite):
                    add_internal(sprite, layer)
                    sprite.add_internal(self)
            else:
                try:
                    # See if sprite is an iterator, like a list or sprite
                    # group.
                    add(*sprite, **kwargs)
                except (TypeError, AttributeError):
                    # Not iterable. This is probably a sprite that is not an
                    # instance of the Sprite class or is not an instance of a
                    # subclass of the Sprite class. Alternately, it could be an
                    # old-style sprite group.
                    if PyObject_HasAttr(sprite, '_spritegroup'):
                        for spr in sprite.sprites():
                            if not has_internal(spr):
                                add_internal(spr, layer)
                                spr.add_internal(self)
                    elif not has_internal(sprite):
                        add_internal(sprite, layer)
                        sprite.add_internal(self)


    cpdef void remove_internal(self, sprite):
        """Do not use this method directly.

        The group uses it to add a sprite.

        """
        self._spritelist.remove(sprite)
        # these dirty rects are suboptimal for one frame
        r = <object>PyDict_GetItem(self.spritedict, sprite)
        if r is not self._init_rect:
            PyList_Append(self.lostsprites, r)
        if PyObject_HasAttr(sprite, 'rect'):
            PyList_Append(self.lostsprites,sprite.rect)

        PyDict_DelItem(self.spritedict, sprite)
        PyDict_DelItem(self._spritelayers, sprite)


    cpdef list sprites(self):
        """return a ordered list of sprites (first back, last top).

        LayeredUpdates.sprites(): return sprites

        """
        return list(self._spritelist)


    def draw(self, surface):
        """draw all sprites in the right order onto the passed surface

        LayeredUpdates.draw(surface): return Rect_list

        """
        cdef:
            dict spritedict = self.spritedict
            dict dirty = self.lostsprites

        self.lostsprites = []
        cdef object init_rect = self._init_rect

        for spr in self.sprites():
            rec = <object>PyDict_GetItem(spritedict, spr)
            newrect = surface.blit(spr.image, spr.rect)
            if rec is init_rect:
                PyList_Append(dirty, newrect)
            else:
                if newrect.colliderect(rec):
                    PyList_Append(dirty, newrect.union(rec))
                else:
                    PyList_Append(dirty, newrect)
                    PyList_Append(dirty, rec)
            PyDict_SetItem(spritedict, spr, newrect)
        return dirty

    cpdef get_sprites_at(self, pos):
        """return a list with all sprites at that position

        LayeredUpdates.get_sprites_at(pos): return colliding_sprites

        Bottom sprites are listed first; the top ones are listed last.

        """
        cdef list _sprites = self._spritelist
        rect = Rect(pos, (0, 0))
        cdef list colliding_list = rect.collidelistall(_sprites)
        cdef list colliding = [_sprites[i] for i in colliding_list]
        return colliding

    cpdef get_sprite(self, int idx):
        """return the sprite at the index idx from the groups sprites

        LayeredUpdates.get_sprite(idx): return sprite

        Raises IndexOutOfBounds if the idx is not within range.

        """
        return <object>PyList_GetItem(self._spritelist, idx)

    cpdef remove_sprites_of_layer(self, int layer_nr):
        """remove all sprites from a layer and return them as a list

        LayeredUpdates.remove_sprites_of_layer(layer_nr): return sprites

        """
        sprites = [self.get_sprites_from_layer(layer_nr)]
        self.remove(sprites)
        return sprites

    #---# layer methods
    cpdef layers(self):
        """return a list of unique defined layers defined.

        LayeredUpdates.layers(): return layers

        """
        return sorted(set(PyDict_Values(self._spritelayers)))

    cpdef change_layer(self, sprite, new_layer):
        """change the layer of the sprite

        LayeredUpdates.change_layer(sprite, new_layer): return None

        The sprite must have been added to the renderer already. This is not
        checked.

        """
        cdef list sprites = self._spritelist # speedup
        cdef dict sprites_layers = self._spritelayers # speedup

        sprites.remove(sprite)
        sprites_layers.pop(sprite)

        # add the sprite at the right position
        # bisect algorithmus
        cdef:
            int leng = PyList_Size(sprites)
            int low = 0, mid = 0
            int high = leng -1

        while low <= high:
            mid = low + ((high - low) >> 1)
            if sprites_layers[sprites[mid]] <= new_layer:
                low = mid + 1
            else:
                high = mid - 1
        # linear search to find final position
        while mid < leng and sprites_layers[sprites[mid]] <= new_layer:
            mid += 1
        sprites.insert(mid, sprite)
        if PyObject_HasAttr(sprite, 'layer'):
            sprite.layer = new_layer

        # add layer info
        sprites_layers[sprite] = new_layer

    cpdef get_layer_of_sprite(self, sprite):
        """return the layer that sprite is currently in

        If the sprite is not found, then it will return the default layer.

        """
        return self._spritelayers.get(sprite, self._default_layer)

    cpdef get_top_layer(self):
        """return the top layer

        LayeredUpdates.get_top_layer(): return layer

        """
        # todo this might crash @cython.boundscheck
        return self._spritelayers[self._spritelist[-1]]

    cpdef get_bottom_layer(self):
        """return the bottom layer

        LayeredUpdates.get_bottom_layer(): return layer

        """
        return self._spritelayers[self._spritelist[0]]

    cpdef move_to_front(self, sprite):
        """bring the sprite to front layer

        LayeredUpdates.move_to_front(sprite): return None

        Brings the sprite to front by changing the sprite layer to the top-most
        layer. The sprite is added at the end of the list of sprites in that
        top-most layer.

        """
        self.change_layer(sprite, self.get_top_layer())

    cpdef move_to_back(self, sprite):
        """move the sprite to the bottom layer

        LayeredUpdates.move_to_back(sprite): return None

        Moves the sprite to the bottom layer by moving it to a new layer below
        the current bottom layer.

        """
        self.change_layer(sprite, self.get_bottom_layer() - 1)

    cpdef get_top_sprite(self):
        """return the topmost sprite

        LayeredUpdates.get_top_sprite(): return Sprite

        """
        # todo this might crash @cython.boundscheck
        return self._spritelist[-1]

    cpdef get_sprites_from_layer(self, layer):
        """return all sprites from a layer ordered as they where added

        LayeredUpdates.get_sprites_from_layer(layer): return sprites

        Returns all sprites from a layer. The sprites are ordered in the
        sequence that they where added. (The sprites are not removed from the
        layer.

        """
        cdef list sprites = []
        sprites_append = sprites.append
        sprite_layers = self._spritelayers
        for spr in self._spritelist:
            if <object>PyDict_GetItem(sprite_layers, spr) == layer:
                sprites_append(spr)
            elif <object>PyDict_GetItem(sprite_layers, spr) > layer:    # break after because no other will
                                                                # follow with same layer
                break
        return sprites

    cpdef switch_layer(self, layer1_nr, layer2_nr):
        """switch the sprites from layer1_nr to layer2_nr

        LayeredUpdates.switch_layer(layer1_nr, layer2_nr): return None

        The layers number must exist. This method does not check for the
        existence of the given layers.

        """
        sprites1 = self.remove_sprites_of_layer(layer1_nr)
        for spr in self.get_sprites_from_layer(layer2_nr):
            self.change_layer(spr, layer1_nr)
        self.add(sprites1, *sprites1)

# TODO CYTHON UNTESTED

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class LayeredDirty(LayeredUpdates):
    """LayeredDirty Group is for DirtySprites; subclasses LayeredUpdates

    pygame.sprite.LayeredDirty(*spites, **kwargs): return LayeredDirty

    This group requires pygame.sprite.DirtySprite or any sprite that
    has the following attributes:
        image, rect, dirty, visible, blendmode (see doc of DirtySprite).

    It uses the dirty flag technique and is therefore faster than
    pygame.sprite.RenderUpdates if you have many static sprites.  It
    also switches automatically between dirty rect updating and full
    SCREEN drawing, so you do no have to worry which would be faster.

    As with the pygame.sprite.Group, you can specify some additional attributes
    through kwargs:
        _use_update: True/False   (default is False)
        _default_layer: default layer where the sprites without a layer are
            added
        _time_threshold: threshold time for switching between dirty rect mode
            and fullscreen mode; defaults to updating at 80 frames per second,
            which is equal to 1000.0 / 80.0

    New in pygame 1.8.0

    """
    cdef public bint _use_update
    cdef object _clip
    cdef public float _time_threshold
    cdef public object _bgd

    def __cinit__(self, *sprites, **kwargs):
        """initialize group.

        pygame.sprite.LayeredDirty(*spites, **kwargs): return LayeredDirty

        You can specify some additional attributes through kwargs:
            _use_update: True/False   (default is False)
            _default_layer: default layer where the sprites without a layer are
                added
            _time_threshold: treshold time for switching between dirty rect
                mode and fullscreen mode; defaults to updating at 80 frames per
                second, which is equal to 1000.0 / 80.0

        """
        LayeredUpdates.__init__(self, *sprites, **kwargs)
        self._clip = None
        self._use_update = False
        self._time_threshold = 1000.0 / 80.0 # 1000.0 / fps
        self._bgd = None

        for key, val in PyDict_Items(kwargs):
            if key in ['_use_update', '_time_threshold', '_default_layer']:
                if PyObject_HasAttr(self, key):
                    PyObject_SetAttr(self, key, val)

    def add_internal(self, sprite, layer=None):
        """Do not use this method directly.

        It is used by the group to add a sprite internally.

        """
        # check if all needed attributes are set
        if not PyObject_HasAttr(sprite, 'dirty'):
            raise AttributeError()
        if not PyObject_HasAttr(sprite, 'visible'):
            raise AttributeError()
        if not PyObject_HasAttr(sprite, 'blendmode'):
            raise AttributeError()

        if not PyObject_IsInstance(sprite, DirtySprite):
            raise TypeError()

        if sprite.dirty == 0: # set it dirty if it is not
            sprite.dirty = 1

        LayeredUpdates.add_internal(self, sprite, layer)

    def draw(self, surface, bgd=None):
        """draw all sprites in the right order onto the given surface

        LayeredDirty.draw(surface, bgd=None): return Rect_list

        You can pass the background too. If a self.bgd is already set to some
        value that is not None, then the bgd argument has no effect.

        """
        # speedups
        _orig_clip = surface.get_clip()
        _clip = self._clip
        if _clip is None:
            _clip = _orig_clip

        _surf = surface
        cdef:
            list _sprites = self._spritelist
            dict _old_rect = self.spritedict
            list _update = self.lostsprites
        _update_append = _update.append
        _ret = None
        _surf_blit = _surf.blit
        _rect = Rect
        if bgd is not None:
            self._bgd = bgd
        _bgd = self._bgd
        init_rect = self._init_rect

        _surf.set_clip(_clip)
        # -------
        # 0. decide whether to render with update or flip
        cdef int start_time = get_ticks()
        if self._use_update: # dirty rects mode
            # 1. find dirty area on SCREEN and put the rects into _update
            # still not happy with that part
            for spr in _sprites:
                if 0 < spr.dirty:
                    # chose the right rect
                    if spr.source_rect:
                        _union_rect = _rect(spr.rect.topleft,
                                            spr.source_rect.size)
                    else:
                        _union_rect = _rect(spr.rect)

                    _union_rect_collidelist = _union_rect.collidelist
                    _union_rect_union_ip = _union_rect.union_ip
                    i = _union_rect_collidelist(_update)
                    while -1 < i:
                        _union_rect_union_ip(_update[i])
                        del _update[i]
                        i = _union_rect_collidelist(_update)
                    _update_append(_union_rect.clip(_clip))

                    if _old_rect[spr] is not init_rect:
                        _union_rect = _rect(_old_rect[spr])
                        _union_rect_collidelist = _union_rect.collidelist
                        _union_rect_union_ip = _union_rect.union_ip
                        i = _union_rect_collidelist(_update)
                        while -1 < i:
                            _union_rect_union_ip(_update[i])
                            del _update[i]
                            i = _union_rect_collidelist(_update)
                        _update_append(_union_rect.clip(_clip))
            # can it be done better? because that is an O(n**2) algorithm in
            # worst case

            # clear using background
            if _bgd is not None:
                for rec in _update:
                    _surf_blit(_bgd, rec, rec)

            # 2. draw
            for spr in _sprites:
                if 1 > spr.dirty:
                    if spr._visible:
                        # sprite not dirty; blit only the intersecting part
                        if spr.source_rect is not None:
                            # For possible future speed up, source_rect's data
                            # can be prefetched outside of this loop.
                            _spr_rect = _rect(spr.rect.topleft,
                                              spr.source_rect.size)
                            rect_offset_x = spr.source_rect[0] - _spr_rect[0]
                            rect_offset_y = spr.source_rect[1] - _spr_rect[1]
                        else:
                            _spr_rect = spr.rect
                            rect_offset_x = -_spr_rect[0]
                            rect_offset_y = -_spr_rect[1]

                        _spr_rect_clip = _spr_rect.clip

                        for idx in _spr_rect.collidelistall(_update):
                            # clip
                            clip = _spr_rect_clip(_update[idx])
                            _surf_blit(spr.image,
                                       clip,
                                       (clip[0] + rect_offset_x,
                                        clip[1] + rect_offset_y,
                                        clip[2],
                                        clip[3]),
                                       spr.blendmode)
                else: # dirty sprite
                    if spr._visible:
                        _old_rect[spr] = _surf_blit(spr.image,
                                                    spr.rect,
                                                    spr.source_rect,
                                                    spr.blendmode)
                    if spr.dirty == 1:
                        spr.dirty = 0
            _ret = list(_update)
        else: # flip, full SCREEN mode
            if _bgd is not None:
                _surf_blit(_bgd, (0, 0))
            for spr in _sprites:
                if spr._visible:
                    _old_rect[spr] = _surf_blit(spr.image,
                                                spr.rect,
                                                spr.source_rect,
                                                spr.blendmode)
            _ret = [_rect(_clip)] # return only the part of the SCREEN changed


        # timing for switching modes
        # How may a good threshold be found? It depends on the hardware.
        end_time = get_ticks()
        if end_time-start_time > self._time_threshold:
            self._use_update = False
        else:
            self._use_update = True

##        # debug
##        print "               check: using dirty rects:", self._use_update

        # emtpy dirty rects list
        _update[:] = []

        # -------
        # restore original clip
        _surf.set_clip(_orig_clip)
        return _ret

    def clear(self, surface, bgd):
        """use to set background

        Group.clear(surface, bgd): return None

        """
        self._bgd = bgd

    def repaint_rect(self, screen_rect):
        """repaint the given area

        LayeredDirty.repaint_rect(screen_rect): return None

        screen_rect is in SCREEN coordinates.

        """
        if self._clip:
            PyList_Append(self.lostsprites, screen_rect.clip(self._clip))
        else:
            PyList_Append(self.lostsprites, Rect(screen_rect))

    def set_clip(self, screen_rect=None):
        """clip the area where to draw; pass None (default) to reset the clip

        LayeredDirty.set_clip(screen_rect=None): return None

        """
        if screen_rect is None:
            self._clip = display.get_surface().get_rect()
        else:
            self._clip = screen_rect
        self._use_update = False

    def get_clip(self):
        """get the area where drawing will occur

        LayeredDirty.get_clip(): return Rect

        """
        return self._clip

    def change_layer(self, sprite, new_layer):
        """change the layer of the sprite

        LayeredUpdates.change_layer(sprite, new_layer): return None

        The sprite must have been added to the renderer already. This is not
        checked.

        """
        LayeredUpdates.change_layer(self, sprite, new_layer)
        if sprite.dirty == 0:
            sprite.dirty = 1

    cpdef set_timing_treshold(self, float time_ms):
        """set the treshold in milliseconds

        set_timing_treshold(time_ms): return None

        Defaults to 1000.0 / 80.0. This means that the SCREEN will be painted
        using the flip method rather than the update method if the update
        method is taking so long to update the SCREEN that the frame rate falls
        below 80 frames per second.

        """
        self._time_threshold = time_ms



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class GroupSingle(AbstractGroup):
    """A group container that holds a single most recent item.

    This class works just like a regular group, but it only keeps a single
    sprite in the group. Whatever sprite has been added to the group last will
    be the only sprite in the group.

    You can access its one sprite as the .sprite attribute.  Assigning to this
    attribute will properly remove the old sprite and then add the new one.

    """

    cdef public object __sprite

    def __init__(self, object sprite=None):

        AbstractGroup.__init__(self)
        self.__sprite = None
        if sprite is not None:
            self.add(sprite)

    cpdef copy(self):
        return GroupSingle(self.__sprite)

    cpdef list sprites(self):
        if self.__sprite is not None:
            return [self.__sprite]
        else:
            return []

    cpdef void add_internal(self, sprite):
        if self.__sprite is not None:
            self.__sprite.remove_internal(self)
            self.remove_internal(self.__sprite)
        self.__sprite = sprite

    def __nonzero__(self):
        """
        Called to implement truth value testing and the built-in operation bool();
         should return False or True, or their integer equivalents 0 or 1.
         When this method is not defined, __len__() is called, if it is defined,
         and the obj is considered true if its result is nonzero.
         If a class defines neither __len__() nor __nonzero__(), all its instances
         are considered true.
        :return:
        """
        print('toto', self.__sprite)
        return self.__sprite is not None

    # CANNOT BE CDEF DUE TO PROPERTY
    cpdef _get_sprite(self):
        return self.__sprite

    # CANNOT BE CDEF DUE TO PROPERTY
    cpdef _set_sprite(self, sprite):
        self.add_internal(sprite)
        sprite.add_internal(self)
        return sprite

    sprite = property(_get_sprite,
                      _set_sprite,
                      None,
                      "The sprite contained in this group")

    # OVERRIDE AbstractGroup remove_internal
    cpdef void remove_internal(self, sprite):
        if sprite is self.__sprite:
            self.__sprite = None
        if sprite in self.spritedict:
            AbstractGroup.remove_internal(self, sprite)

    # OVERRIDE AbstractGroup has_internal method
    cpdef bint has_internal(self, sprite):
        return self.__sprite is sprite

    # Optimizations...
    def __contains__(self, sprite):
        return self.__sprite is sprite




@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
# Some different collision detection functions that could be used.
cpdef collide_rect(left, right):
    """collision detection between two sprites, using rects.

    pygame.sprite.collide_rect(left, right): return bool

    Tests for collision between two sprites. Uses the pygame.Rect colliderect
    function to calculate the collision. It is intended to be passed as a
    collided callback function to the *collide functions. Sprites must have
    "rect" attributes.

    New in pygame 1.8.0    
    :param left: Sprite; must contains Pygame.Rect 
    :param right: Sprite; must contains pygame.Rect
    :return: Returns true if any portion of either rectangle 
    overlap (except the top+bottom or left+right edges).
    
    """
    return left.rect.colliderect(right.rect)



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class collide_rect_ratio(object):
    """A callable class that checks for collisions using scaled rects

    The class checks for collisions between two sprites using a scaled version
    of the sprites' rects. Is created with a ratio; the instance is then
    intended to be passed as a collided callback function to the *collide
    functions.

    New in pygame 1.8.1

    """
    cdef double ratio

    def __cinit__(self, double ratio):
        """create a new collide_rect_ratio callable

        Ratio is expected to be a floating overlap value used to scale
        the underlying sprite rect before checking for collisions.

        """
        self.ratio = ratio

    def __call__(self, left, right):
        """detect collision between two sprites using scaled rects

        pygame.sprite.collide_rect_ratio(ratio)(left, right): return bool

        Tests for collision between two sprites. Uses the pygame.Rect
        colliderect function to calculate the collision after scaling the rects
        by the stored ratio. Sprites must have "rect" attributes.

        :param left: sprite; must have attribute rect
        :param right: sprite; must have attribute rect
        :return:
        """

        cdef double ratio = self.ratio

        leftrect = left.rect
        cdef:
            int lw = leftrect.width
            int lh = leftrect.height
        leftrect = leftrect.inflate(lw * ratio - lw,
                                    lh * ratio - lh)

        rightrect = right.rect
        cdef:
            int rw = rightrect.width
            int rh = rightrect.height
        rightrect = rightrect.inflate(rw * ratio - rw,
                                      rh * ratio - rh)

        return leftrect.colliderect(rightrect)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef collide_circle(left, right):
    """detect collision between two sprites using circles

    pygame.sprite.collide_circle(left, right): return bool

    Tests for collision between two sprites by testing whether two circles
    centered on the sprites overlap. If the sprites have a "radius" attribute,
    then that radius is used to create the circle; otherwise, a circle is
    created that is big enough to completely enclose the sprite's rect as
    given by the "rect" attribute. This function is intended to be passed as
    a collided callback function to the *collide functions. Sprites must have a
    "rect" and an optional "radius" attribute.

    New in pygame 1.8.0

    :param left: sprite; must have attribute rect
    :param right: sprite; must have attribute rect
    :return:
    """
    cdef:
        object leftrect = left.rect, rightrect = right.rect
        int lw = leftrect.width
        int lh = leftrect.height
        int rw = rightrect.width
        int rh = rightrect.height
        int xdistance = leftrect.centerx - rightrect.centerx
        int ydistance = leftrect.centery - rightrect.centery
        int distancesquared = xdistance * xdistance + ydistance * ydistance
        double leftradius, rightradius, sum

    if PyObject_HasAttr(left, 'radius'):
        leftradius = left.radius
    else:
        # approximating the radius of a square by using half of the diagonal,
        # might give false positives (especially if its a long small rect)
        leftradius = 0.5 * sqrt(lw * lw + lh * lh)
        # store the radius on the sprite for next time
        PyObject_SetAttr(left, 'radius', leftradius)

    if PyObject_HasAttr(right, 'radius'):
        rightradius = right.radius
    else:
        # approximating the radius of a square by using half of the diagonal
        # might give false positives (especially if its a long small rect)
        rightradius = 0.5 * sqrt(rw * rw + rh * rh)
        # store the radius on the sprite for next time
        PyObject_SetAttr(right, 'radius', rightradius)
    sum = leftradius + rightradius
    return distancesquared <= (sum * sum)



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class collide_circle_ratio(object):
    """detect collision between two sprites using scaled circles

    This callable class checks for collisions between two sprites using a
    scaled version of a sprite's radius. It is created with a ratio as the
    argument to the constructor. The instance is then intended to be passed as
    a collided callback function to the *collide functions.

    New in pygame 1.8.1

    """
    cdef double ratio

    def __cinit__(self, double ratio):
        """creates a new collide_circle_ratio callable instance

        The given ratio is expected to be a floating overlap value used to scale
        the underlying sprite radius before checking for collisions.

        When the ratio is ratio=1.0, then it behaves exactly like the
        collide_circle method.

        """
        self.ratio = ratio


    def __call__(self, left, right):
        """detect collision between two sprites using scaled circles

        pygame.sprite.collide_circle_radio(ratio)(left, right): return bool

        Tests for collision between two sprites by testing whether two circles
        centered on the sprites overlap after scaling the circle's radius by
        the stored ratio. If the sprites have a "radius" attribute, that is
        used to create the circle; otherwise, a circle is created that is big
        enough to completely enclose the sprite's rect as given by the "rect"
        attribute. Intended to be passed as a collided callback function to the
        *collide functions. Sprites must have a "rect" and an optional "radius"
        attribute.

        :param left: sprite; must have attribute rect
        :param right: sprite; must have attribute rect
        :return:
        """

        cdef:
            double ratio = self.ratio
            leftrect = left.rect
            rightrect = right.rect
            int xdistance = leftrect.centerx - rightrect.centerx
            int ydistance = leftrect.centery - rightrect.centery
            int distancesquared = xdistance * xdistance + ydistance * ydistance
            int lw = leftrect.width
            int lh = leftrect.height
            int rw = rightrect.width
            int rh = rightrect.height
            double r = ratio * 0.5, sum

        if PyObject_HasAttr(left, "radius"):
            leftradius = left.radius * ratio
        else:
            leftradius = r * sqrt((lw * lw + lh * lh))
            # store the radius on the sprite for next time
            PyObject_SetAttr(left, 'radius', leftradius)

        if PyObject_HasAttr(right, "radius"):
            rightradius = right.radius * ratio
        else:
            rightradius = r * sqrt((rw * rw + rh * rh))
            # store the radius on the sprite for next time
            PyObject_SetAttr(right, 'radius', rightradius)
        sum = leftradius + rightradius
        return distancesquared <= (sum * sum)



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef bint collide_mask(left, right):
    """collision detection between two sprites, using masks.

    pygame.sprite.collide_mask(SpriteLeft, SpriteRight): bool

    Tests for collision between two sprites by testing if their bitmasks
    overlap. If the sprites have a "mask" attribute, that is used as the mask;
    otherwise, a mask is created from the sprite image. Intended to be passed
    as a collided callback function to the *collide functions. Sprites must
    have a "rect" and an optional "mask" attribute.

    New in pygame 1.8.0
    
    :param left: sprite; must have attribute rect
    :param right: sprite; must have attribute rect
    :return: bool; 
    """

    cdef:
        int xoffset = right.rect[0] - left.rect[0]
        int yoffset = right.rect[1] - left.rect[1]
    try:
        leftmask = left.mask
    except AttributeError:
        leftmask = from_surface(left.image)
    try:
        rightmask = right.mask
    except AttributeError:
        rightmask = from_surface(right.image)
    return leftmask.overlap(rightmask, (xoffset, yoffset))



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef list spritecollide(sprite, group, bint dokill, collided=None):
    """find Sprites in a Group that intersect another Sprite

    pygame.sprite.spritecollide(sprite, group, dokill, collided=None):
        return Sprite_list

    Return a list containing all Sprites in a Group that intersect with another
    Sprite. Intersection is determined by comparing the Sprite.rect attribute
    of each Sprite.

    The dokill argument is a bool. If set to True, all Sprites that collide
    will be removed from the Group.

    The collided argument is a callback function used to calculate if two
    sprites are colliding. it should take two sprites as values, and return a
    bool value indicating if they are colliding. If collided is not passed, all
    sprites must have a "rect" value, which is a rectangle of the sprite area,
    which will be used to calculate the collision.

    """

    cdef list crashed
    if dokill:
        crashed = []
        if collided:
            for s in group.sprites():
                if collided(sprite, s):
                    s.kill()
                    PyList_Append(crashed, s)
        else:
            spritecollide = sprite.rect.colliderect
            for s in group.sprites():
                if spritecollide(s.rect):
                    s.kill()
                    PyList_Append(crashed, s)

        return crashed

    elif collided:
        return [s for s in group if collided(sprite, s)]
    else:
        spritecollide = sprite.rect.colliderect
        return [s for s in group if spritecollide(s.rect)]



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef dict groupcollide(groupa, groupb, bint dokilla, bint dokillb, collided=None):
    """detect collision between a group and another group

    pygame.sprite.groupcollide(groupa, groupb, dokilla, dokillb):
        return dict

    Given two groups, this will find the intersections between all sprites in
    each group. It returns a dictionary of all sprites in the first group that
    collide. The value for each item in the dictionary is a list of the sprites
    in the second group it collides with. The two dokill arguments control if
    the sprites from either group will be automatically removed from all
    groups. Collided is a callback function used to calculate if two sprites
    are colliding. it should take two sprites as values, and return a bool
    value indicating if they are colliding. If collided is not passed, all
    sprites must have a "rect" value, which is a rectangle of the sprite area
    that will be used to calculate the collision.

    """
    cdef dict crashed = {}
    SC = spritecollide
    if dokilla:
        for s in groupa.sprites():
            c = SC(s, groupb, dokillb, collided)
            if c:
                PyDict_SetItem(crashed, s, c)
                s.kill()
    else:
        for s in groupa:
            c = SC(s, groupb, dokillb, collided)
            if c:
                PyDict_SetItem(crashed, s, c)
    return crashed


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cpdef spritecollideany(sprite, group, collided=None):
    """finds any sprites in a group that collide with the given sprite

    spritecollideany(sprite, group): return sprite

    Given a sprite and a group of sprites, this will return return any single
    sprite that collides with with the given sprite. If there are no
    collisions, then this returns None.

    If you don't need all the features of the spritecollide function, this
    function will be a bit quicker.

    Collided is a callback function used to calculate if two sprites are
    colliding. It should take two sprites as values and return a bool value
    indicating if they are colliding. If collided is not passed, then all
    sprites must have a "rect" value, which is a rectangle of the sprite area,
    which will be used to calculate the collision.

    """
    if collided:
        for s in group:
            if collided(sprite, s):
                return s
    else:
        # Special case old behaviour for speed.
        spritecollide = sprite.rect.colliderect
        for s in group:
            if spritecollide(s.rect):
                return s
    return None



@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef class LayeredUpdatesModified(LayeredUpdates):
    """
    Pygame Class LayerUpdates modified
    This class introduce the pygame flag RGB_BLEND_ADD.
    When instantiating a pygame sprites, use the class attribute _blend to use
    the sprite additive mode.
    e.g
    s = sprite()
    s._blend = pygame.BLEND_RGB_ADD
    """

    def __cinit__(self):
        LayeredUpdates.__init__(self)

    cpdef draw(self, surface_):

        cdef:
            dict spritedict = self.spritedict
            list dirty = self.lostsprites
            list l = self.sprites()
            int i, t = PyList_Size(l)
            surfaceblit = surface_.blit
            init_rect = self._init_rect

        self.lostsprites = []

        for i in range(0, t):
            spr = <object>PyList_GetItem(l, i)              # sprite instance
            rec = <object>PyDict_GetItem(spritedict, spr)   # sprite rect

            try:
                newrect = PyObject_CallFunctionObjArgs(surfaceblit,
                                                       <PyObject*>spr.image,          # image
                                                       <PyObject*>spr.rect,           # destination
                                                       <PyObject*>None,               # Area
                                                       <PyObject*>spr._blend,         # special_flags
                                                       NULL)


            except (TypeError, AttributeError):
                newrect = PyObject_CallFunctionObjArgs(surfaceblit,
                                                           <PyObject*>spr.image,          # image
                                                           <PyObject*>spr.rect,           # destination
                                                           NULL)


            if rec is init_rect:
                PyList_Append(dirty, newrect)
            else:
                if newrect.colliderect(rec):
                    PyList_Append(dirty, newrect.union(rec))
                else:
                    PyList_Append(dirty, newrect)
                    PyList_Append(dirty, rec)
            PyDict_SetItem(spritedict, spr, newrect)
        return dirty
