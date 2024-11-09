#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <GL/gl3w.h>
#include <SDL3/SDL.h>
#include "backend.h"

#include "implot.h"
#include "imgui.h"
#include "imnodes.h"
#include "imgui_internal.h"
#include "imgui_impl_sdl3.h"
#include "imgui_impl_opengl3.h"
#include <stdio.h>

#include <functional>
#include <mutex>

struct mvViewportData
{
    SDL_Window* handle = nullptr;
    SDL_Window* secondary_handle = nullptr;
    SDL_GLContext gl_handle = nullptr;
    SDL_GLContext secondary_gl_handle = nullptr;
    std::mutex primary_gl_context;
    std::mutex secondary_gl_context;
};

mvGraphics
setup_graphics(mvViewport& viewport)
{
    mvGraphics graphics{};
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    const char* glsl_version = "#version 150";
    viewportData->primary_gl_context.lock();
    SDL_GL_MakeCurrent(viewportData->handle, viewportData->gl_handle);
    ImGui_ImplOpenGL3_Init(glsl_version);
    SDL_GL_MakeCurrent(viewportData->handle, NULL);
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

    SDL_GetWindowPosition(viewportData->handle, &viewport->xpos, &viewport->ypos);

    // Rendering
    ImGui::Render();
    int display_w, display_h, w, h;
    viewportData->primary_gl_context.lock();
    SDL_GL_MakeCurrent(viewportData->handle, viewportData->gl_handle);
    SDL_GetWindowSizeInPixels(viewportData->handle, &display_w, &display_h);
    SDL_GetWindowSize(viewportData->handle, &w, &h);
    viewport->actualWidth = display_w;
    viewport->actualHeight = display_h;
    viewport->clientWidth = w;
    viewport->clientHeight = h;

    int current_interval, desired_interval;
    SDL_GL_GetSwapInterval(&current_interval);
    desired_interval = viewport->vsync ? 1 : 0;
    if (desired_interval != current_interval)
        SDL_GL_SetSwapInterval(desired_interval);
    glViewport(0, 0, display_w, display_h);
    glClearColor(viewport->clearColor.r, viewport->clearColor.g, viewport->clearColor.b, viewport->clearColor.a);
    glClear(GL_COLOR_BUFFER_BIT);
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    SDL_GL_MakeCurrent(viewportData->handle, NULL);
    viewportData->primary_gl_context.unlock();
}

void mvPresent(mvViewport* viewport)
{
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;
    viewportData->primary_gl_context.lock();
    SDL_GL_MakeCurrent(viewportData->handle, viewportData->gl_handle);
    SDL_GL_SwapWindow(viewportData->handle);
    viewport->dpi = SDL_GetWindowDisplayScale(viewportData->handle);
    SDL_GL_MakeCurrent(viewportData->handle, NULL);
    viewportData->primary_gl_context.unlock();
}

void
mvProcessEvents(mvViewport* viewport)
{
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;

    if (viewport->posDirty)
    {
        SDL_SetWindowPosition(viewportData->handle, viewport->xpos, viewport->ypos);
        viewport->posDirty = false;
    }

    if (viewport->sizeDirty)
    {
        float logical_to_pixel_factor = SDL_GetWindowPixelDensity(viewportData->handle);
        float factor = viewport->dpi / logical_to_pixel_factor;
        SDL_SetWindowMaximumSize(viewportData->handle, (int)(viewport->maxwidth * factor), (int)(viewport->maxheight * factor));
        SDL_SetWindowMinimumSize(viewportData->handle, (int)(viewport->minwidth * factor), (int)(viewport->minheight * factor));
        SDL_SetWindowSize(viewportData->handle, (int)(viewport->actualWidth * factor), (int)(viewport->actualHeight * factor));
        viewport->sizeDirty = false;
    }

    if (viewport->modesDirty)
    {
        SDL_SetWindowResizable(viewportData->handle, viewport->resizable);
        SDL_SetWindowBordered(viewportData->handle, viewport->decorated);
        SDL_SetWindowAlwaysOnTop(viewportData->handle, viewport->alwaysOnTop);
        viewport->modesDirty = false;
    }

    if (viewport->titleDirty)
    {
        SDL_SetWindowTitle(viewportData->handle, viewport->title.c_str());
        viewport->titleDirty = false;
    }

    // Poll and handle events (inputs, window resize, etc.)
    // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
    // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
    // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
    // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.

    // Activity: input activity. Needs to render to check impact
    // Needs refresh: if the content has likely changed and we must render and present
    SDL_Event event;
    while (true) {
        bool new_events = SDL_PollEvent(&event);
        if (!new_events) {
            if(viewport->activity.load() || viewport->needs_refresh.load())
                break;
            else
                SDL_WaitEventTimeout(NULL, 0.001);
        }

        ImGui_ImplSDL3_ProcessEvent(&event);
        switch (event.type) {
            case SDL_EVENT_WINDOW_MOUSE_ENTER:
            case SDL_EVENT_WINDOW_FOCUS_GAINED:
            case SDL_EVENT_WINDOW_FOCUS_LOST:
            case SDL_EVENT_WINDOW_MOVED:
            case SDL_EVENT_WINDOW_SHOWN:
            case SDL_EVENT_MOUSE_MOTION:
                viewport->activity.store(true);
                break;
            case SDL_EVENT_WINDOW_RESIZED:
                //viewport->on_resize(...) TODO
            case SDL_EVENT_MOUSE_WHEEL:
            case SDL_EVENT_MOUSE_BUTTON_DOWN:
            case SDL_EVENT_MOUSE_BUTTON_UP:
            case SDL_EVENT_TEXT_EDITING:
            case SDL_EVENT_TEXT_INPUT:
            case SDL_EVENT_KEY_DOWN:
            case SDL_EVENT_KEY_UP:
            case SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
            case SDL_EVENT_WINDOW_ENTER_FULLSCREEN:
            case SDL_EVENT_WINDOW_LEAVE_FULLSCREEN:
            case SDL_EVENT_WINDOW_EXPOSED:
            case SDL_EVENT_WINDOW_DESTROYED:
                viewport->needs_refresh.store(true);
                break;
            case SDL_EVENT_WINDOW_MINIMIZED:
                viewport->activity.store(true);
                //viewport->minimized = true;
                break;
            case SDL_EVENT_WINDOW_MAXIMIZED:
                 viewport->activity.store(true);
                //viewport->maximized = true;
                break;
            case SDL_EVENT_WINDOW_RESTORED:
                 viewport->activity.store(true);
                break;
                //viewport->minimized = false;
                //viewport->maximized = false;
            case SDL_EVENT_QUIT:
            case SDL_EVENT_WINDOW_CLOSE_REQUESTED: // && event.window.windowID == SDL_GetWindowID(viewportData->handle)
                viewport->running = false;
                viewport->on_close(viewport->callback_data);
                viewport->activity.store(true);
            /* TODO: drag&drop, etc*/
            default:
                break;
        }
    }
    //if (viewport->waitForEvents || glfwGetWindowAttrib(viewportData->handle, GLFW_ICONIFIED))
    //    while (!viewport->activity.load() && !viewport->needs_refresh.load())
    //        glfwWaitEventsTimeout(0.001);
    viewport->activity.store(false);
}

 mvViewport*
mvCreateViewport(render_fun render,
				 on_resize_fun on_resize,
		         on_close_fun on_close,
				 void *callback_data)
{
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD))
    {
        printf("Error: SDL_Init(): %s\n", SDL_GetError());
        return nullptr;
    }
    // Setup window
    /* The secondary handle enables multithreading and
     * Starting uploading textures right away*/
    auto secondary_handle = SDL_CreateWindow("DearCyGui upload context", 640, 480, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | SDL_WINDOW_UTILITY);
    if (secondary_handle == nullptr)
        return nullptr;
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // Always required on Mac
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    auto secondary_gl_handle = SDL_GL_CreateContext(secondary_handle);
    if (secondary_gl_handle == nullptr)
        return nullptr;
    if (gl3wInit() != GL3W_OK)
        return nullptr;
    // All our uploads have no holes
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    SDL_GL_MakeCurrent(secondary_handle, NULL);
    mvViewport* viewport = new mvViewport();
    viewport->render = render;
    viewport->on_resize = on_resize;
    viewport->on_close = on_close;
    viewport->callback_data = callback_data;
    viewport->platformSpecifics = new mvViewportData();
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;
    viewportData->secondary_handle = secondary_handle;
    viewportData->secondary_gl_handle = secondary_gl_handle;
    auto primary_display = SDL_GetPrimaryDisplay();
    viewport->dpi = SDL_GetDisplayContentScale(primary_display);
    return viewport;
}

 void
mvCleanupViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;

    // Cleanup
    viewportData->primary_gl_context.lock();
    SDL_GL_MakeCurrent(viewportData->handle, viewportData->gl_handle);
    ImGui_ImplOpenGL3_Shutdown();
    SDL_GL_MakeCurrent(viewportData->handle, NULL);
    viewportData->primary_gl_context.unlock();
    ImGui_ImplSDL3_Shutdown();

    SDL_GL_DestroyContext(viewportData->gl_handle);
    SDL_GL_DestroyContext(viewportData->secondary_gl_handle);
    SDL_DestroyWindow(viewportData->handle);
    SDL_DestroyWindow(viewportData->secondary_handle);
    SDL_Quit();

    delete viewportData;
    viewportData = nullptr;
}

void
mvShowViewport(mvViewport& viewport,
               bool minimized,
               bool maximized)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;

    SDL_WindowFlags creation_flags = 0;
    if (viewport.resizable)
        creation_flags |= SDL_WINDOW_RESIZABLE;
    if (viewport.alwaysOnTop)
        creation_flags |= SDL_WINDOW_ALWAYS_ON_TOP;
    if (maximized)
        creation_flags |= SDL_WINDOW_MAXIMIZED;
    else if (minimized)
        creation_flags |= SDL_WINDOW_MINIMIZED;
    if (!viewport.decorated)
        creation_flags |= SDL_WINDOW_BORDERLESS;

    // Create window with graphics context
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // Always required on Mac
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
    viewportData->secondary_gl_context.lock();
    // Set current to allow sharing
    SDL_GL_MakeCurrent(viewportData->secondary_handle, viewportData->secondary_gl_handle);
    viewportData->handle = SDL_CreateWindow(viewport.title.c_str(), viewport.actualWidth, viewport.actualHeight,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY | SDL_WINDOW_HIDDEN);
    viewportData->gl_handle = SDL_GL_CreateContext(viewportData->handle);
    SDL_GL_MakeCurrent(viewportData->handle, NULL);
    SDL_GL_MakeCurrent(viewportData->secondary_handle, NULL);
    viewportData->secondary_gl_context.unlock();
    //glfwSetWindowPos(viewportData->handle, viewport.xpos, viewport.ypos); // SDL_SetWindowPosition
    viewport.dpi = SDL_GetWindowDisplayScale(viewportData->handle);
    float logical_to_pixel_factor = SDL_GetWindowPixelDensity(viewportData->handle);
    float factor = viewport.dpi / logical_to_pixel_factor;
    SDL_SetWindowSize(viewportData->handle, (int)(viewport.actualWidth * factor), (int)(viewport.actualHeight * factor));
    SDL_SetWindowMaximumSize(viewportData->handle, (int)(viewport.maxwidth * factor), (int)(viewport.maxheight * factor));
    SDL_SetWindowMinimumSize(viewportData->handle, (int)(viewport.minwidth * factor), (int)(viewport.minheight * factor));
    SDL_ShowWindow(viewportData->handle);

    viewport.dpi = SDL_GetWindowDisplayScale(viewportData->handle);
    logical_to_pixel_factor = SDL_GetWindowPixelDensity(viewportData->handle);
    float updated_factor = viewport.dpi / logical_to_pixel_factor;
    if (factor != updated_factor) {
        SDL_SetWindowSize(viewportData->handle, (int)(viewport.actualWidth * factor), (int)(viewport.actualHeight * factor));
        SDL_SetWindowMaximumSize(viewportData->handle, (int)(viewport.maxwidth * factor), (int)(viewport.maxheight * factor));
        SDL_SetWindowMinimumSize(viewportData->handle, (int)(viewport.minwidth * factor), (int)(viewport.minheight * factor));
    }

    SDL_GetWindowSizeInPixels(viewportData->handle, &viewport.actualWidth, &viewport.actualHeight);
    SDL_GetWindowSize(viewportData->handle, &viewport.clientWidth, &viewport.clientHeight);

    //std::vector<GLFWimage> images;

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

    SDL_GL_MakeCurrent(viewportData->handle, viewportData->gl_handle);

    // Setup Platform/Renderer bindings
    ImGui_ImplSDL3_InitForOpenGL(viewportData->handle, viewportData->gl_handle);

    SDL_GL_MakeCurrent(viewportData->handle, NULL);
    viewportData->primary_gl_context.unlock();
}
    
void
mvMaximizeViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    SDL_MaximizeWindow(viewportData->handle);
}

void
mvMinimizeViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    SDL_MinimizeWindow(viewportData->handle);
}

void
mvRestoreViewport(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    SDL_RestoreWindow(viewportData->handle);
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

    viewportData->primary_gl_context.lock();
    SDL_GL_MakeCurrent(viewportData->handle, viewportData->gl_handle);

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
    SDL_GL_MakeCurrent(viewportData->handle, NULL);
    viewportData->primary_gl_context.unlock();
    ImGui_ImplSDL3_NewFrame();
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
    SDL_SetWindowFullscreen(viewportData->handle, viewport.fullScreen);
    /*
        storedWidth = (size_t)viewport.actualWidth;
        storedHeight = (size_t)viewport.actualHeight;
        storedXPos = viewport.xpos;
        storedYPos = viewport.ypos;
    */
}

void mvWakeRendering(mvViewport& viewport)
{
    viewport.needs_refresh.store(true);
    SDL_Event user_event;
    user_event.type = SDL_EVENT_USER;
    user_event.user.code = 2;
    user_event.user.data1 = NULL;
    user_event.user.data2 = NULL;
    SDL_PushEvent(&user_event);
}

void mvMakeUploadContextCurrent(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    viewportData->secondary_gl_context.lock();
    SDL_GL_MakeCurrent(viewportData->secondary_handle, viewportData->secondary_gl_handle);
}

void mvReleaseUploadContext(mvViewport& viewport)
{
    auto viewportData = (mvViewportData*)viewport.platformSpecifics;
    glFlush();
    SDL_GL_MakeCurrent(viewportData->secondary_handle, NULL);
    viewportData->secondary_gl_context.unlock();
    viewport.needs_refresh.store(true);
}

// TODO this should probably be part of viewport structure, not static.
static std::unordered_map<GLuint, GLuint> PBO_ids;
static std::unordered_set<GLuint> Allocated_ids;

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
    // Allocate a PBO with the texture
    // Doing glBufferData only here gives significant speed gains
    // Note we could be sharing PBOs between textures,
    // Here we simplify buffer management (no offset and alignment
    // management) but double memory usage.
    glBufferData(GL_PIXEL_UNPACK_BUFFER, width * height * num_chans * type_size, 0, GL_STREAM_DRAW);

    // Unbind texture and PBO
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
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
    if (Allocated_ids.find(out_srv) != Allocated_ids.end())
        Allocated_ids.erase(out_srv);

    glDeleteTextures(1, &out_srv);
}

bool mvUpdateDynamicTexture(void* texture,
                            unsigned width,
                            unsigned height,
                            unsigned num_chans,
                            unsigned type,
                            void* data,
                            unsigned src_stride)
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

    // Request access to the buffer
    // We get significant speed gains compared to using glBufferData/glMapBuffer
    ptr = (GLubyte*)glMapBufferRange(GL_PIXEL_UNPACK_BUFFER, 0,
                                     width * height * num_chans * type_size,
                                     GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_RANGE_BIT);
    if (ptr)
    {
        // write data directly on the mapped buffer
        if (src_stride == (width * num_chans * type_size))
            memcpy(ptr, data, width * height * num_chans * type_size);
        else {
            for (unsigned row = 0; row < height; row++) {
                memcpy(ptr, data, width * num_chans * type_size);
                ptr = (GLubyte*)(((unsigned char*)ptr) + width * num_chans * type_size);
                data = (void*)(((unsigned char*)data) + src_stride);
            }
        }
        glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);  // release pointer to mapping buffer
    } else
        goto error;

    // bind the texture
    glBindTexture(GL_TEXTURE_2D, textureId);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    // copy pixels from PBO to texture object
    if (Allocated_ids.find(textureId) == Allocated_ids.end()) {
        glTexImage2D(GL_TEXTURE_2D, 0, gl_format, width, height, 0, gl_format, gl_type, NULL);
        Allocated_ids.insert(textureId);
    } else {
        // Reuse previous allocation. Slightly faster.
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, gl_format, gl_type, NULL);
    }

    if (glGetError() != GL_NO_ERROR)
        goto error;

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    // Unbind the texture
    glBindTexture(GL_TEXTURE_2D, 0);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    return true;
error:
    // We don't free the texture as it might be used
    // for rendering in another thread, but maybe we should ?
    return false;
}

bool mvUpdateStaticTexture(void* texture, unsigned width, unsigned height, unsigned num_chans, unsigned type, void* data, unsigned src_stride)
{
    return mvUpdateDynamicTexture(texture, width, height, num_chans, type, data, src_stride);
}
