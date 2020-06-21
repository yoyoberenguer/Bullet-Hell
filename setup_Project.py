# distutils: extra_compile_args = -fopenmp
# distutils: extra_link_args = -fopenmp


# USE :
# python setup_Project.py build_ext --inplace

from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
import numpy
from Cython.Compiler.Main import default_options

ext_modules = [

    Extension("BLOOM", ["BLOOM.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),

    Extension("Sprites", ["Sprites.pyx"],
                  include_dirs=[numpy.get_include()],
                  extra_compile_args=['/openmp'],
                  extra_link_args=['/openmp']),

    Extension("Constants", ["Constants.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("SoundServer", ["SoundServer.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("Textures", ["Textures.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("Sounds", ["Sounds.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("PlayerClass", ["PlayerClass.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("BindSprites", ["BindSprites.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("SpriteSheet", ["SpriteSheet.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("EnemyBossClass", ["EnemyBossClass.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("Halo", ["Halo.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("HSV", ["hsv.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),

    Extension("Surface_tools", ["Surface_tools.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),

    Extension("rand", ["rand.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp']),
    Extension("xml_parsing", ["XML_parsing.pyx"],
              include_dirs=[numpy.get_include()],
              extra_compile_args=['/openmp'],
              extra_link_args=['/openmp'])


]

setup(
    name="HOMING_MISSILE",
    cmdclass={"build_ext": build_ext},
    ext_modules=ext_modules,
    include_dirs=[numpy.get_include()]
)
