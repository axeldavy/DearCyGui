from setuptools import setup, find_packages, Distribution
from setuptools.command import build_py
from setuptools.extension import Extension
from Cython.Build import cythonize
import distutils.cmd
from codecs import open
import os
from os import path
import textwrap
import sys
import shutil
import subprocess

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
                    "thirdparty/gl3w",
                    "thirdparty/stb"]
    #"thirdparty/glfw/include",
    cpp_sources = [
        "mvContext.cpp",
        "mvMath.cpp",
        "mvProfiler.cpp",
        "dearpygui.cpp",
        "mvPyUtils.cpp",
        "mvCustomTypes.cpp",
        "mvBasicWidgets.cpp",
        "mvTables.cpp",
        "mvThemes.cpp",
        "mvNodes.cpp",
        "mvDrawings.cpp",
        "mvGlobalHandlers.cpp",
        "mvItemHandlers.cpp",
        "mvValues.cpp",
        "mvTextureItems.cpp",
        "mvFontItems.cpp",
        "mvColors.cpp",
        "mvPlotting.cpp",
        "mvContainers.cpp",
        "mvCallbackRegistry.cpp",
        "mvLoadingIndicatorCustom.cpp",
        "mvFontManager.cpp",
        "mvToolManager.cpp",
        "mvToolWindow.cpp",
        "mvAboutWindow.cpp",
        "mvDocWindow.cpp",
        "mvMetricsWindow.cpp",
        "mvStackWindow.cpp",
        "mvStyleWindow.cpp",
        "mvDebugWindow.cpp",
        "mvLayoutWindow.cpp",
        "mvAppItemState.cpp",
        "mvAppItem.cpp",
        "mvItemRegistry.cpp",
        "mvDatePicker.cpp",
        "mvTimePicker.cpp",
        "mvSlider3D.cpp",
        "mvLoadingIndicator.cpp",
        "mvFileDialog.cpp",
        "mvFileExtension.cpp",
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
        "thirdparty/imgui/imgui_tables.cpp"          
    ]

    compile_args = ["-DIMGUI_DEFINE_MATH_OPERATORS",
                    "-DMVDIST_ONLY",
                    "-D_CRT_SECURE_NO_WARNINGS",
                    "-D_USE_MATH_DEFINES",
                    "-DMV_DPG_MAJOR_VERSION=1",
                    "-DMV_DPG_MINOR_VERSION=0",
                    "-DMV_SANDBOX_VERSION=\"master\""]
    linking_args = []
    libraries = []


    if get_platform() == "Windows":
        cpp_sources += [
            "thirdparty/imgui/misc/freetype/imgui_freetype.cpp",
            "thirdparty/imgui/backends/imgui_impl_win32.cpp",
            "thirdparty/imgui/backends/imgui_impl_dx11.cpp",
            "mvViewport_win32.cpp",
            "mvUtilities_win32.cpp",
            "mvGraphics_win32.cpp"
        ]
        compile_args += ["-DMV_PLATFORM=\"windows\"", "-DIMGUI_USER_CONFIG=\"mvImGuiConfig.h\""]
        libraries += ["d3d11", "dxgi", "dwmapi", "freetype"]
    elif get_platform() == "Linux":
        cpp_sources += [
            "thirdparty/imgui/backends/imgui_impl_glfw.cpp",
            "thirdparty/imgui/backends/imgui_impl_opengl3.cpp",
            "thirdparty/gl3w/GL/gl3w.c",
            "mvUtilities_linux.cpp",
            "mvViewport_linux.cpp",
            "mvGraphics_linux.cpp"
        ]
        compile_args += ["-DNDEBUG", "-fwrapv", "-O3", "-DUNIX", "-DLINUX",\
                         "-DIMGUI_IMPL_OPENGL_LOADER_GL3W", "-DMV_PLATFORM=\"linux\"",\
                         "-DIMGUI_USER_CONFIG=\"mvImGuiLinuxConfig.h\"",\
                         "-DCUSTOM_IMGUIFILEDIALOG_CONFIG=\"ImGuiFileDialogConfigUnix.h\""]
        libraries += ["crypt", "pthread", "dl", "util", "m", "GL", "glfw"]
    elif get_platform() == "OS X":
        cpp_sources += [
            "thirdparty/imgui/backends/imgui_impl_metal.mm",
            "thirdparty/imgui/backends/imgui_impl_glfw.cpp",
            "mvViewport_apple.mm",
            "mvUtilities_apple.mm",
            "mvGraphics_apple.mm"
        ]
        compile_args += ["-fobjc-arc", "-fno-common", "-dynamic", "-DNDEBUG",\
                         "-fwrapv" ,"-O3", "-DAPPLE", "-DMV_PLATFORM=\"apple\"", \
                         "-DIMGUI_USER_CONFIG=\"mvImGuiLinuxConfig.h\"",\
                         "-DCUSTOM_IMGUIFILEDIALOG_CONFIG=\"ImGuiFileDialogConfigUnix.h\""]
        linking_args += [
            "-lglfw",
			"-undefined dynamic_lookup",
			"-framework Metal",
			"-framework MetalKit",
			"-framework Cocoa",
			"-framework CoreVideo",
			"-framework IOKit",
			"-framework QuartzCore"
        ]
        
    else:
        raise ValueError("Unsupported plateform")

        
    cpp_sources = [p if "thirdparty" in p else ("src/" + p) for p in cpp_sources]
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
                libraries=libraries,
                depends=["dearcygui._dearcygui"],
                extra_link_args=linking_args
            )
        )
    print(extensions)

    metadata = dict(
        name='dearcygui',                                      # Required
        version=version_number(),                              # Required
        author="Jonathan Hoffstadt, Preston Cothren and Axel Davy",       # Optional
        author_email="jonathanhoffstadt@yahoo.com",            # Optional
        description='DearCyGui: A simple Python GUI Toolkit',  # Required
        long_description=long_description,                     # Optional
        long_description_content_type='text/markdown',         # Optional
        url='https://github.com/axeldavy/DearCyGui',          # Optional
        license = 'MIT',
        python_requires='>=3.10',
        classifiers=[
                'Development Status :: 5 - Production/Stable',
                'Intended Audience :: Education',
                'Intended Audience :: Developers',
                'Intended Audience :: Science/Research',
                'License :: OSI Approved :: MIT License',
                'Operating System :: MacOS',
                'Operating System :: Microsoft :: Windows :: Windows 10',
                'Operating System :: POSIX',
                'Operating System :: Unix',
                'Programming Language :: Python :: 3.7',
                'Programming Language :: Python :: 3.8',
                'Programming Language :: Python :: 3.9',
                'Programming Language :: Python :: 3.10',
                'Programming Language :: Python :: 3.11',
                'Programming Language :: Python :: 3.12',
                'Programming Language :: Python :: Implementation :: CPython',
                'Programming Language :: Python :: 3 :: Only',
                'Topic :: Software Development :: User Interfaces',
                'Topic :: Software Development :: Libraries :: Python Modules',
            ],
        packages=['dearcygui'],
        ext_modules = cythonize(extensions, language_level=3)
    )
    metadata["package_data"] = {}
    metadata["package_data"]['dearcygui'] = ['*.pxd', '*.py']

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
