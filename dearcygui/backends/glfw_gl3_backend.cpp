#include <string>
#include <vector>
#include <unordered_map>
#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
#include "backend.h"

#include "implot.h"
#include "imgui.h"
#include "imnodes.h"
#include "imgui_internal.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"
#include <stdio.h>

#include <functional>
#include <mutex>

struct mvViewportData
{
    GLFWwindow* handle = nullptr;
    GLFWwindow* secondary_handle = nullptr;
    std::mutex primary_gl_context;
    std::mutex secondary_gl_context;
};

mvGraphics
setup_graphics(mvViewport& viewport)
{
    mvGraphics graphics{};
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    const char* glsl_version = "#version 130";
    viewportData->primary_gl_context.lock();
    glfwMakeContextCurrent(viewportData->handle);
    ImGui_ImplOpenGL3_Init(glsl_version);
    glfwMakeContextCurrent(NULL);
    viewportData->primary_gl_context.unlock();
    return graphics;
}

void
resize_swapchain(mvGraphics& graphics, int width, int height)
{

}

void
cleanup_graphics(mvGraphics& graphics)
{

}

static void
prepare_present(mvGraphics& graphics, mvViewport* viewport, mvColor& clearColor, bool vsync)
{
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;

    //glfwGetWindowPos(viewportData->handle, &viewport->xpos, &viewport->ypos);

    // Rendering
    ImGui::Render();
    int display_w, display_h;
    viewportData->primary_gl_context.lock();
    glfwMakeContextCurrent(viewportData->handle);
    glfwGetFramebufferSize(viewportData->handle, &display_w, &display_h);

    glfwSwapInterval(viewport->vsync ? 1 : 0); // Enable vsync
    glViewport(0, 0, display_w, display_h);
    glClearColor(viewport->clearColor.r, viewport->clearColor.g, viewport->clearColor.b, viewport->clearColor.a);
    glClear(GL_COLOR_BUFFER_BIT);
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    glfwMakeContextCurrent(NULL);
    viewportData->primary_gl_context.unlock();
}

void mvPresent(mvViewport* viewport)
{
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;
    viewportData->primary_gl_context.lock();
    glfwMakeContextCurrent(viewportData->handle);
    glfwSwapBuffers(viewportData->handle);
    glfwMakeContextCurrent(NULL);
    viewportData->primary_gl_context.unlock();
}

static void handle_refresh_request(GLFWwindow* window)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->needs_refresh.store(true);
}

static void handle_window_resize(GLFWwindow *window, int width, int height)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->on_resize(viewport->callback_data, width, height);
    viewport->needs_refresh.store(true);
}

static void handle_window_close(GLFWwindow *window)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->needs_refresh.store(true);
    viewport->on_close(viewport->callback_data);
}


static void handle_mouse_button(GLFWwindow* window, int button, int action, int mods)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    //viewport->activity.store(true);
    viewport->needs_refresh.store(true); // conservative choice
}

static void handle_scroll(GLFWwindow* window, double xoffset, double yoffset)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->needs_refresh.store(true); // Hard to detect when we do not need to render for scroll
}

static void handle_key(GLFWwindow* window, int keycode, int scancode, int action, int mods)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    //viewport->activity.store(true);
    viewport->needs_refresh.store(true); // editable fields, etc might get updated
}

static void handle_focus(GLFWwindow* window, int focused)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->activity.store(true);
}

static void handle_cursor_pos(GLFWwindow* window, double x, double y)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->activity.store(true);
}

static void handle_cursor_enter(GLFWwindow* window, int entered)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->activity.store(true);
}

static void handle_char(GLFWwindow* window, unsigned int c)
{
    mvViewport* viewport = (mvViewport*)glfwGetWindowUserPointer(window);

    viewport->needs_refresh.store(true);
}

static void
glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "Glfw Error %d: %s\n", error, description);
}

void
mvProcessEvents(mvViewport* viewport)
{
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;

    viewport->running = !glfwWindowShouldClose(viewportData->handle);

    if (viewport->posDirty && 0)
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

    // Poll and handle events (inputs, window resize, etc.)
    // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
    // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
    // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
    // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.

    // Activity: input activity. Needs to render to check impact
    // Needs refresh: if the content has likely changed and we must render and present
    if (viewport->waitForEvents || glfwGetWindowAttrib(viewportData->handle, GLFW_ICONIFIED))
        while (!viewport->activity.load() && !viewport->needs_refresh.load())
            glfwWaitEventsTimeout(0.001);
    viewport->activity.store(false);
    glfwPollEvents();
}

 mvViewport*
mvCreateViewport(render_fun render,
				 on_resize_fun on_resize,
		         on_close_fun on_close,
				 void *callback_data)
{
    // Setup window
    glfwSetErrorCallback(glfw_error_callback);
    if (glfwInit() != GLFW_TRUE)
        return nullptr;
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    /* The secondary handle enables multithreading and
     * Starting uploading textures right away*/
    auto secondary_handle = glfwCreateWindow(640, 480, "", NULL, NULL);
    glfwWindowHint(GLFW_VISIBLE, GLFW_TRUE);
    if (secondary_handle == nullptr)
        return nullptr;
    glfwMakeContextCurrent(secondary_handle);
    if (gl3wInit() != GL3W_OK)
        return nullptr;
    glfwMakeContextCurrent(NULL);
    mvViewport* viewport = new mvViewport();
    viewport->render = render;
    viewport->on_resize = on_resize;
    viewport->on_close = on_close;
    viewport->callback_data = callback_data;
    viewport->platformSpecifics = new mvViewportData();
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;
    viewportData->secondary_handle = secondary_handle;
    float xscale, yscale;
    GLFWmonitor* monitor = glfwGetPrimaryMonitor();
    glfwGetMonitorContentScale(monitor, &xscale, &yscale);
    viewport->dpi = xscale;
    return viewport;
}

 void
mvCleanupViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;

    // Cleanup
    viewportData->primary_gl_context.lock();
    glfwMakeContextCurrent(viewportData->handle);
    ImGui_ImplOpenGL3_Shutdown();
    glfwMakeContextCurrent(NULL);
    viewportData->primary_gl_context.unlock();
    ImGui_ImplGlfw_Shutdown();

    glfwDestroyWindow(viewportData->handle);
    glfwDestroyWindow(viewportData->secondary_handle);
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
    // Automated DPI management doesn't look good
    #ifdef GLFW_SCALE_FRAMEBUFFER
    glfwWindowHint(GLFW_SCALE_FRAMEBUFFER, GL_FALSE);
    #endif

    // Create window with graphics context
    // GL 3.0 + GLSL 130
    // const char* glsl_version = "#version 130";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    viewportData->secondary_gl_context.lock();
    viewportData->handle = glfwCreateWindow(viewport.actualWidth, viewport.actualHeight, viewport.title.c_str(), nullptr, viewportData->secondary_handle);
    viewportData->secondary_gl_context.unlock();
    glfwSetWindowUserPointer(viewportData->handle, &viewport);
    //glfwSetWindowPos(viewportData->handle, viewport.xpos, viewport.ypos);
    glfwSetWindowSizeLimits(viewportData->handle, (int)viewport.minwidth, (int)viewport.minheight, (int)viewport.maxwidth, (int)viewport.maxheight);

    // This is only True because we set GLFW_SCALE_FRAMEBUFFER to False
    viewport.clientHeight = viewport.actualHeight;
    viewport.clientWidth = viewport.actualWidth;

    std::vector<GLFWimage> images;

    /*
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
    */

    // A single thread can use a context at a time
    viewportData->primary_gl_context.lock();

    glfwMakeContextCurrent(viewportData->handle);

    // Bind them before imgui does his, as it chains them.
    glfwSetWindowSizeCallback(viewportData->handle,
                              handle_window_resize);
    glfwSetWindowCloseCallback(viewportData->handle,
                               handle_window_close);
    glfwSetWindowRefreshCallback(viewportData->handle,
                               handle_refresh_request);
    glfwSetCharCallback(viewportData->handle, handle_char);
    glfwSetCursorEnterCallback(viewportData->handle, handle_cursor_enter);
    glfwSetCursorPosCallback(viewportData->handle, handle_cursor_pos);
    glfwSetWindowFocusCallback(viewportData->handle, handle_focus);
    glfwSetKeyCallback(viewportData->handle, handle_key);
    glfwSetMouseButtonCallback(viewportData->handle, handle_mouse_button);
    glfwSetScrollCallback(viewportData->handle, handle_scroll);

    // Setup Platform/Renderer bindings
    ImGui_ImplGlfw_InitForOpenGL(viewportData->handle, true);

    glfwMakeContextCurrent(NULL);
    viewportData->primary_gl_context.unlock();
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

static bool FastActivityCheck()
{
    ImGuiContext& g = *GImGui;

    /* Change in active ID or hovered ID might trigger animation */
    if (g.ActiveIdPreviousFrame != g.ActiveId ||
        g.HoveredId != g.HoveredIdPreviousFrame ||
        g.NavJustMovedToId)
        return true;

    for (int button = 0; button < IM_ARRAYSIZE(g.IO.MouseDown); button++) {
        /* Dragging item likely needs refresh */
        if (g.IO.MouseDown[button] && g.IO.MouseDragMaxDistanceSqr[button] > 0)
            return true;
        /* Releasing or clicking mouse might trigger things */
        if (g.IO.MouseReleased[button] || g.IO.MouseClicked[button])
            return true;
    }

    /* Cursor needs redraw */
    if (g.IO.MouseDrawCursor && \
        (g.IO.MouseDelta.x != 0. ||
         g.IO.MouseDelta.y != 0.))
        return true;

    return false;
}

bool
mvRenderFrame(mvViewport& viewport,
 			  mvGraphics& graphics,
              bool can_skip_presenting)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    (void)viewportData;

    viewportData->primary_gl_context.lock();
    glfwMakeContextCurrent(viewportData->handle);

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
    glfwMakeContextCurrent(NULL);
    viewportData->primary_gl_context.unlock();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();

    if (GImGui->CurrentWindow == nullptr)
        return false;

    bool needs_refresh = viewport.needs_refresh.load();
    viewport.needs_refresh.store(false);

    viewport.render(viewport.callback_data);

    // Updates during the frame
    // Not all might have been made into rendering
    // thus we don't reset needs_refresh
    needs_refresh |= viewport.needs_refresh.load();

    if (FastActivityCheck()) {
        needs_refresh = true;
        /* Refresh next frame in case of activity.
         * For instance click release might open
         * a menu */
        viewport.needs_refresh.store(true);
    }

    static bool prev_needs_refresh = true;

    // Maybe we could use some statistics like number of vertices
    can_skip_presenting &= !needs_refresh && !prev_needs_refresh;

    // The frame just after an activity might trigger some visual changes
    prev_needs_refresh = needs_refresh;

    if (can_skip_presenting) {

        ImGui::EndFrame();
        return false;
    }

    prepare_present(graphics, &viewport, viewport.clearColor, viewport.vsync);
    return true;
    
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

void mvWakeRendering(mvViewport& viewport)
{
    viewport.needs_refresh.store(true);
    glfwPostEmptyEvent();
}

void mvMakeUploadContextCurrent(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    viewportData->secondary_gl_context.lock();
    glfwMakeContextCurrent(viewportData->secondary_handle);
}

void mvReleaseUploadContext(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    glFlush();
    glfwMakeContextCurrent(NULL);
    viewportData->secondary_gl_context.unlock();
    viewport.needs_refresh.store(true);
}

static std::unordered_map<GLuint, GLuint> PBO_ids;

void* mvAllocateTexture(unsigned width, unsigned height, unsigned num_chans, unsigned dynamic, unsigned type, unsigned filtering_mode)
{
    GLuint image_texture;
    GLuint pboid;
    unsigned type_size = (type == 1) ? 1 : 4;
    (void)type_size;

    glGenTextures(1, &image_texture);
    if (glGetError() != GL_NO_ERROR) {
        return NULL;
    }
    glBindTexture(GL_TEXTURE_2D, image_texture);

    // Setup filtering parameters for display
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (filtering_mode == 1) ? GL_NEAREST : GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); // Required for fonts
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // Duplicate the first channel on g and b to display as gray
    if (num_chans == 1) {
        if (filtering_mode == 2) {
            /* Font. Load as 111A */
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_R, GL_ONE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_G, GL_ONE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_B, GL_ONE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_A, GL_RED);
        } else {
            /* rrr1 */
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_G, GL_RED);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_B, GL_RED);
        }
    }

    glGenBuffers(1, &pboid);
    if (glGetError() != GL_NO_ERROR) {
        glDeleteTextures(1, &image_texture);
        return NULL;
    }
    PBO_ids[image_texture] = pboid;
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pboid);
    if (glGetError() != GL_NO_ERROR) {
        mvFreeTexture((void*)(size_t)(GLuint)image_texture);
        return NULL;
    }
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    return (void*)(size_t)(GLuint)image_texture;
}

void mvFreeTexture(void* texture)
{
    GLuint out_srv = (GLuint)(size_t)texture;
    GLuint pboid;

    if(PBO_ids.count(out_srv) != 0) {
        pboid = PBO_ids[out_srv];
        glDeleteBuffers(1, &pboid);
        PBO_ids.erase(out_srv);
    }

    glDeleteTextures(1, &out_srv);
}

bool mvUpdateDynamicTexture(void* texture, unsigned width, unsigned height, unsigned num_chans, unsigned type, void* data)
{
    auto textureId = (GLuint)(size_t)texture;
    unsigned gl_format = GL_RGBA;
    unsigned gl_type = GL_FLOAT;
    unsigned type_size = 4;
    GLubyte* ptr;

    switch (num_chans)
    {
    case 4:
        gl_format = GL_RGBA;
        break;
    case 3:
        gl_format = GL_RGB;
        break;
    case 2:
        gl_format = GL_RG;
        break;
    case 1:
    default:
        gl_format = GL_RED;
        break;
    }

    if (type == 1) {
        gl_type = GL_UNSIGNED_BYTE;
        type_size = 1;
    }

    // bind PBO to update pixel values
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, PBO_ids[textureId]);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    // allocate a new buffer
    glBufferData(GL_PIXEL_UNPACK_BUFFER, width * height * num_chans * type_size, 0, GL_STREAM_DRAW);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    // tequest access to the buffer
    ptr = (GLubyte*)glMapBuffer(GL_PIXEL_UNPACK_BUFFER, GL_WRITE_ONLY);
    if (ptr)
    {
        // update data directly on the mapped buffer
        memcpy(ptr, data, width * height * num_chans * type_size);

        glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);  // release pointer to mapping buffer
    } else
        goto error;

    // bind the texture
    glBindTexture(GL_TEXTURE_2D, textureId);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    // copy pixels from PBO to texture object
    glTexImage2D(GL_TEXTURE_2D, 0, gl_format, width, height, 0, gl_format, gl_type, NULL);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    return true;
error:
    // We don't free the texture as it might be used
    // for rendering in another thread, but maybe we should ?
    return false;
}

bool mvUpdateStaticTexture(void* texture, unsigned width, unsigned height, unsigned num_chans, unsigned type, void* data)
{
    return mvUpdateDynamicTexture(texture, width, height, num_chans, type, data);
}
