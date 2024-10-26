from setuptools import setup, find_packages, Distribution
from setuptools.command import build_py
from setuptools.extension import Extension
from Cython.Build import cythonize
import distutils.cmd
from codecs import open
import os
from os import path
import sys
from glob import glob
import numpy as np

wip_version = "0.0.1"

def version_number():
    """This function reads the version number which is populated by github actions"""

    if os.environ.get('READTHEDOCS') == 'True':
        return wip_version
    try:
        with open('version_number.txt', encoding='utf-8') as f:
            version = f.readline().rstrip()

            # temporary fix fox CI issues with windows
            if(version.startswith("ECHO")):
                return "0.0.1"

            return version

    except IOError:
        return wip_version

def get_platform():

    platforms = {
        'linux' : 'Linux',
        'linux1' : 'Linux',
        'linux2' : 'Linux',
        'darwin' : 'OS X',
        'win32' : 'Windows'
    }
    if sys.platform not in platforms:
        return sys.platform
    
    return platforms[sys.platform]

def setup_package():

    src_path = os.path.dirname(os.path.abspath(__file__))
    old_path = os.getcwd()
    os.chdir(src_path)
    sys.path.insert(0, src_path)

    # import readme content
    with open("./README.md", encoding='utf-8') as f:
        long_description = f.read()

    include_dirs = ["src",
                    "thirdparty/imgui",
                    "thirdparty/imgui/backends",
                    "thirdparty/ImGuiFileDialog",
                    "thirdparty/imnodes",
                    "thirdparty/implot",
                    "thirdparty/gl3w"]
    include_dirs += [np.get_include()]
    include_dirs += ["/usr/include/freetype2/"] # TODO

    cpp_sources = [
        "dearcygui/backends/glfw_gl3_backend.cpp",
        "thirdparty/imnodes/imnodes.cpp",
        "thirdparty/implot/implot.cpp",
        "thirdparty/implot/implot_items.cpp",
        "thirdparty/implot/implot_demo.cpp",
        "thirdparty/ImGuiFileDialog/ImGuiFileDialog.cpp",
        "thirdparty/imgui/misc/cpp/imgui_stdlib.cpp",
        "thirdparty/imgui/imgui.cpp",
        "thirdparty/imgui/imgui_demo.cpp",
        "thirdparty/imgui/imgui_draw.cpp",
        "thirdparty/imgui/imgui_widgets.cpp",
        "thirdparty/imgui/imgui_tables.cpp",
        "thirdparty/imgui/backends/imgui_impl_glfw.cpp",
        "thirdparty/imgui/backends/imgui_impl_opengl3.cpp",
        "thirdparty/imgui/misc/freetype/imgui_freetype.cpp",
        "thirdparty/gl3w/GL/gl3w.c"
    ]

    compile_args = ["-DIMGUI_DEFINE_MATH_OPERATORS",
                    "-DMVDIST_ONLY",
                    "-D_CRT_SECURE_NO_WARNINGS",
                    "-D_USE_MATH_DEFINES",
                    "-DMV_DPG_MAJOR_VERSION=1",
                    "-DMV_DPG_MINOR_VERSION=0",
                    "-DIMGUI_IMPL_OPENGL_LOADER_GL3W",
                    "-DIMGUI_USER_CONFIG=\"mvImGuiLinuxConfig.h\"",
                    "-DMV_SANDBOX_VERSION=\"master\""]
    linking_args = ['-O3']
    libraries = ['freetype']

    if get_platform() == "Linux":
        compile_args += ["-DNDEBUG", "-fwrapv", "-O3", "-DUNIX", "-DLINUX",\
                         "-DCUSTOM_IMGUIFILEDIALOG_CONFIG=\"ImGuiFileDialogConfigUnix.h\""]
        libraries += ["crypt", "pthread", "dl", "util", "m", "GL", "glfw"]
    elif get_platform() == "OS X":
        compile_args += ["-fobjc-arc", "-fno-common", "-dynamic", "-DNDEBUG",\
                         "-fwrapv" ,"-O3", "-DAPPLE", "-DMV_PLATFORM=\"apple\"", \
                         "-DCUSTOM_IMGUIFILEDIALOG_CONFIG=\"ImGuiFileDialogConfigUnix.h\""]
        linking_args += [
            "-lglfw"
        ]

    else:
        raise ValueError("Unsupported plateform")

    extensions = [
        Extension(
            "dearcygui.core",
            ["dearcygui/core.pyx"] + cpp_sources,
            language="c++",
            include_dirs=include_dirs,
            extra_compile_args=compile_args,
            libraries=libraries,
            extra_link_args=linking_args
        )
    ]
    secondary_cython_sources = [
        "dearcygui/constants.pyx",
        "dearcygui/draw.pyx",
        "dearcygui/handler.pyx",
        "dearcygui/theme.pyx"
    ]
    for cython_source in secondary_cython_sources:
        extension_name = cython_source.split("/")[-1].split(".")[0]
        extensions.append(
            Extension(
                "dearcygui."+extension_name,
                [cython_source],
                language="c++",
                include_dirs=include_dirs,
                extra_compile_args=compile_args,
            )
        )
    print(extensions)

    metadata = dict(
        name='dearcygui',                                      # Required
        version=version_number(),                              # Required
        author="Axel Davy",                                    # Optional
        description='DearCyGui: A simple and customizable Python GUI Toolkit coded in Cython',  # Required
        long_description=long_description,                     # Optional
        long_description_content_type='text/markdown',         # Optional
        url='https://github.com/axeldavy/DearCyGui',          # Optional
        license = 'MIT',
        python_requires='>=3.10',
        classifiers=[
                'Development Status :: 2 - Pre-Alpha',
                'Intended Audience :: Education',
                'Intended Audience :: Developers',
                'Intended Audience :: Science/Research',
                'License :: OSI Approved :: MIT License',
                'Operating System :: MacOS',
                'Operating System :: Microsoft :: Windows :: Windows 10',
                'Operating System :: POSIX',
                'Operating System :: Unix',
                'Programming Language :: Cython',
                'Programming Language :: Python :: 3',
                'Topic :: Software Development :: User Interfaces',
                'Topic :: Software Development :: Libraries :: Python Modules',
            ],
        packages=['dearcygui'],
        ext_modules = cythonize(extensions, compiler_directives={'language_level' : "3"}, nthreads=4)
    )
    metadata["package_data"] = {}
    metadata["package_data"]['dearcygui'] = ['*.pxd', '*.py', '*.pyi', '*ttf']

    if "--force" in sys.argv:
        sys.argv.remove('--force')

    try:
        setup(**metadata)
    finally:
        del sys.path[0]
        os.chdir(old_path)
    return


if __name__ == '__main__':
    setup_package()
