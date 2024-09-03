#include "mvViewport.h"
#include "mvFontManager.h"
#include "mvLinuxSpecifics.h"
#include "implot.h"
#include "imgui.h"
#include "imnodes.h"
#include "imgui_internal.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include <stdio.h>
#include <stb_image.h>
#include "mvToolManager.h"

#include <functional>

static void handle_window_resize(GLFWwindow *window, int width, int height)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->on_resize(viewport->callback_data, width, height);
}

static void handle_window_close(GLFWwindow *window)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->on_close(viewport->callback_data);
}

static void
glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "Glfw Error %d: %s\n", error, description);
}

static void
mvPrerender(mvViewport* viewport)
{
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;

    viewport->running = !glfwWindowShouldClose(viewportData->handle);

    if (viewport->posDirty)
    {
        glfwSetWindowPos(viewportData->handle, viewport->xpos, viewport->ypos);
        viewport->posDirty = false;
    }

    if (viewport->sizeDirty)
    {
        glfwSetWindowSizeLimits(viewportData->handle, (int)viewport->minwidth, (int)viewport->minheight, (int)viewport->maxwidth, (int)viewport->maxheight);
        glfwSetWindowSize(viewportData->handle, viewport->actualWidth, viewport->actualHeight);
        viewport->sizeDirty = false;
    }

    if (viewport->modesDirty)
    {
        glfwSetWindowAttrib(viewportData->handle, GLFW_RESIZABLE, viewport->resizable ? GLFW_TRUE : GLFW_FALSE);
        glfwSetWindowAttrib(viewportData->handle, GLFW_DECORATED, viewport->decorated ? GLFW_TRUE : GLFW_FALSE);
        glfwSetWindowAttrib(viewportData->handle, GLFW_FLOATING, viewport->alwaysOnTop ? GLFW_TRUE : GLFW_FALSE);
        viewport->modesDirty = false;
    }

    if (viewport->titleDirty)
    {
        glfwSetWindowTitle(viewportData->handle, viewport->title.c_str());
        viewport->titleDirty = false;
    }

    if (glfwGetWindowAttrib(viewportData->handle, GLFW_ICONIFIED))
    {
        glfwWaitEvents();
        return;
    }

    // Poll and handle events (inputs, window resize, etc.)
    // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
    // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
    // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
    // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.

    // TODO if (GContext->IO.waitForInput)
    //    glfwWaitEvents();
    //else
        
    glfwPollEvents();

    if (mvToolManager::GetFontManager().isInvalid())
    {
        mvToolManager::GetFontManager().rebuildAtlas();
        ImGui_ImplOpenGL3_DestroyDeviceObjects();
        mvToolManager::GetFontManager().updateAtlas();
    }

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();

}

 mvViewport*
mvCreateViewport(unsigned width,
                 unsigned height,
                 render_fun render,
				 on_resize_fun on_resize,
		         on_close_fun on_close,
				 void *callback_data)
{
    mvViewport* viewport = new mvViewport();
    viewport->width = width;
    viewport->height = height;
    viewport->render = render;
    viewport->on_resize = on_resize;
    viewport->on_close = on_close;
    viewport->callback_data = callback_data;
    viewport->platformSpecifics = new mvViewportData();
    return viewport;
}

 void
mvCleanupViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;

    // Cleanup
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();

    glfwDestroyWindow(viewportData->handle);
    glfwTerminate();

    delete viewportData;
    viewportData = nullptr;
}

 void
mvShowViewport(mvViewport& viewport,
               bool minimized,
               bool maximized)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;

    // Setup window
    glfwSetErrorCallback(glfw_error_callback);
    glfwInit();

    if (!viewport.resizable)
        glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
    if (viewport.alwaysOnTop)
        glfwWindowHint(GLFW_FLOATING, GLFW_TRUE);
    if (maximized)
        glfwWindowHint(GLFW_MAXIMIZED, GLFW_TRUE);
    else if (minimized)
        glfwWindowHint(GLFW_AUTO_ICONIFY, GLFW_TRUE);
    if (!viewport.decorated)
        glfwWindowHint(GLFW_DECORATED, GLFW_FALSE);

    // Create window with graphics context
    // GL 3.0 + GLSL 130
    const char* glsl_version = "#version 130";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    viewportData->handle = glfwCreateWindow(viewport.actualWidth, viewport.actualHeight, viewport.title.c_str(), nullptr, nullptr);
    glfwSetWindowUserPointer(viewportData->handle, &viewport);
    glfwSetWindowPos(viewportData->handle, viewport.xpos, viewport.ypos);
    glfwSetWindowSizeLimits(viewportData->handle, (int)viewport.minwidth, (int)viewport.minheight, (int)viewport.maxwidth, (int)viewport.maxheight);

    viewport.clientHeight = viewport.actualHeight;
    viewport.clientWidth = viewport.actualWidth;

    std::vector<GLFWimage> images;

    if (!viewport.small_icon.empty())
    {
        int image_width, image_height;
        unsigned char* image_data = stbi_load(viewport.small_icon.c_str(), &image_width, &image_height, nullptr, 4);
        if (image_data)
        {
            images.push_back({ image_width, image_height, image_data });
        }
    }

    if (!viewport.large_icon.empty())
    {
        int image_width, image_height;
        unsigned char* image_data = stbi_load(viewport.large_icon.c_str(), &image_width, &image_height, nullptr, 4);
        if (image_data)
        {
            images.push_back({ image_width, image_height, image_data });
        }
    }

    if (!images.empty())
        glfwSetWindowIcon(viewportData->handle, images.size(), images.data());

    glfwMakeContextCurrent(viewportData->handle);
    gl3wInit();

    // Setup Platform/Renderer bindings
    ImGui_ImplGlfw_InitForOpenGL(viewportData->handle, true);
        

    glfwSetWindowSizeCallback(viewportData->handle,
                              handle_window_resize);
    glfwSetWindowCloseCallback(viewportData->handle,
                               handle_window_close);
}
    
 void
mvMaximizeViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    glfwMaximizeWindow(viewportData->handle);
}

 void
mvMinimizeViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    glfwIconifyWindow(viewportData->handle);
}

 void
mvRestoreViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    glfwRestoreWindow(viewportData->handle);
}

 void
mvRenderFrame(mvViewport& viewport,
 			  mvGraphics& graphics)
{
    mvPrerender(&viewport);

    if (GImGui->CurrentWindow == nullptr)
        return;

    viewport.render(viewport.callback_data);

    present(graphics, &viewport, viewport.clearColor, viewport.vsync);
}

 void
mvToggleFullScreen(mvViewport& viewport)
{
    static size_t storedWidth = 0;
    static size_t storedHeight = 0;
    static int    storedXPos = 0;
    static int    storedYPos = 0;

    auto viewportData = (mvViewportData*)viewport.platformSpecifics;

    GLFWmonitor* monitor = glfwGetPrimaryMonitor();
    const GLFWvidmode* mode = glfwGetVideoMode(monitor);
    int framerate = -1;
    if (viewport.vsync)
    {
        framerate = mode->refreshRate;
    }

    if (viewport.fullScreen)
    {
        glfwSetWindowMonitor(viewportData->handle, nullptr, storedXPos, storedYPos, storedWidth, storedHeight, framerate);
        viewport.fullScreen = false;
    }
    else
    {
        storedWidth = (size_t)viewport.actualWidth;
        storedHeight = (size_t)viewport.actualHeight;
        storedXPos = viewport.xpos;
        storedYPos = viewport.ypos;
        glfwSetWindowMonitor(viewportData->handle, monitor, 0, 0, mode->width, mode->height, framerate);
        viewport.fullScreen = true;
    }
}