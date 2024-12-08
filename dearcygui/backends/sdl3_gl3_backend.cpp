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

static std::unordered_map<GLuint, GLuint> PBO_ids;
static std::unordered_set<GLuint> Allocated_ids;

bool platformViewport::fastActivityCheck() {
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

// Move prepare_present implementation into class method
void SDLViewport::preparePresentFrame() {
    SDL_GetWindowPosition(windowHandle, &positionX, &positionY);

    // Rendering
    ImGui::Render();
    renderContextLock.lock();
    SDL_GL_MakeCurrent(windowHandle, glContext);
    if (hasResized) {
        SDL_GetWindowSizeInPixels(windowHandle, &frameWidth, &frameHeight);
        SDL_GetWindowSize(windowHandle, &windowWidth, &windowHeight);
        hasResized = false;
        resizeCallback(callbackData);
    }

    int current_interval, desired_interval;
    SDL_GL_GetSwapInterval(&current_interval);
    desired_interval = hasVSync ? 1 : 0;
    if (desired_interval != current_interval)
        SDL_GL_SetSwapInterval(desired_interval);
    glViewport(0, 0, frameWidth, frameHeight);
    glClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
    glClear(GL_COLOR_BUFFER_BIT);
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();
}

// Move texture management implementations into SDLViewport static methods
void* SDLViewport::allocateTexture(unsigned width, unsigned height, unsigned num_chans, 
                                 unsigned dynamic, unsigned type, unsigned filtering_mode) {
    // Making the sure the context is current
    // is the responsibility of the caller
    // But if we were to change this,
    // here is commented out code to do it.
    //makeUploadContextCurrent();
    GLuint image_texture;
    GLuint pboid;
    unsigned type_size = (type == 1) ? 1 : 4;
    (void)type_size;

    glGenTextures(1, &image_texture);
    if (glGetError() != GL_NO_ERROR) {
        //releaseUploadContext();
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
        //releaseUploadContext();
        return NULL;
    }
    PBO_ids[image_texture] = pboid;
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pboid);
    if (glGetError() != GL_NO_ERROR) {
        freeTexture((void*)(size_t)(GLuint)image_texture);
        //releaseUploadContext();
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
    //releaseUploadContext();
    return (void*)(size_t)(GLuint)image_texture;
}

void SDLViewport::freeTexture(void* texture) {
    //makeUploadContextCurrent();
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
    //releaseUploadContext();
}

bool SDLViewport::updateDynamicTexture(void* texture, unsigned width, unsigned height,
                                    unsigned num_chans, unsigned type, void* data,
                                    unsigned src_stride) {
    //makeUploadContextCurrent();
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

    //releaseUploadContext();
    return true;
error:
    //releaseUploadContext();
    // We don't free the texture as it might be used
    // for rendering in another thread, but maybe we should ?
    return false;
}

bool SDLViewport::updateStaticTexture(void* texture, unsigned width, unsigned height,
                                   unsigned num_chans, unsigned type, void* data,
                                   unsigned src_stride) {
    return updateDynamicTexture(texture, width, height, num_chans, type, data, src_stride);
}

SDLViewport* SDLViewport::create(render_fun render,
                             on_resize_fun on_resize,
                             on_close_fun on_close,
                             void* callback_data) {
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
        printf("Error: SDL_Init(): %s\n", SDL_GetError());
        return nullptr;
    }
    
    auto viewport = new SDLViewport();
    viewport->renderCallback = render;
    viewport->resizeCallback = on_resize;
    viewport->closeCallback = on_close;
    viewport->callbackData = callback_data;
    
    // Create secondary window/context
    viewport->uploadWindowHandle = SDL_CreateWindow("DearCyGui upload context", 
        640, 480, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | SDL_WINDOW_UTILITY);
    if (viewport->uploadWindowHandle == nullptr)
        return nullptr;

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // Always required on Mac
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    viewport->uploadGLContext = SDL_GL_CreateContext(viewport->uploadWindowHandle);
    if (viewport->uploadGLContext == nullptr)
        return nullptr;
    if (gl3wInit() != GL3W_OK)
        return nullptr;
    // All our uploads have no holes
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    SDL_GL_MakeCurrent(viewport->uploadWindowHandle, NULL);
    auto primary_display = SDL_GetPrimaryDisplay();
    viewport->dpiScale = SDL_GetDisplayContentScale(primary_display);
    return viewport;
}

// Implementation of SDLViewport methods
void SDLViewport::cleanup() {
    // Only cleanup if initialization was successful
    if (hasOpenGL3Init) {
        renderContextLock.lock();
        SDL_GL_MakeCurrent(windowHandle, glContext);
        ImGui_ImplOpenGL3_Shutdown();
        SDL_GL_MakeCurrent(windowHandle, NULL);
        renderContextLock.unlock();
    }

    if (hasSDL3Init) {
        ImGui_ImplSDL3_Shutdown();
    }

    SDL_GL_DestroyContext(glContext);
    SDL_GL_DestroyContext(uploadGLContext);
    SDL_DestroyWindow(windowHandle);
    SDL_DestroyWindow(uploadWindowHandle);
    SDL_Quit();
}

bool SDLViewport::initialize(bool start_minimized, bool start_maximized) {
    const char* glsl_version = "#version 150";

    SDL_WindowFlags creation_flags = 0;
    if (windowResizable)
        creation_flags |= SDL_WINDOW_RESIZABLE;
    if (windowAlwaysOnTop)
        creation_flags |= SDL_WINDOW_ALWAYS_ON_TOP;
    if (start_maximized)
        creation_flags |= SDL_WINDOW_MAXIMIZED;
    else if (start_minimized)
        creation_flags |= SDL_WINDOW_MINIMIZED;
    if (!windowDecorated)
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
    uploadContextLock.lock();
    // Set current to allow sharing
    SDL_GL_MakeCurrent(uploadWindowHandle, uploadGLContext);
    
    windowHandle = SDL_CreateWindow(windowTitle.c_str(), frameWidth, frameHeight,
        creation_flags | SDL_WINDOW_OPENGL | SDL_WINDOW_HIGH_PIXEL_DENSITY | SDL_WINDOW_HIDDEN);
    if (windowHandle == nullptr) {
        SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
        uploadContextLock.unlock();
        return false;
    }

    glContext = SDL_GL_CreateContext(windowHandle);
    if (glContext == nullptr) {
        SDL_DestroyWindow(windowHandle);
        SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
        uploadContextLock.unlock();
        return false;
    }

    SDL_GL_MakeCurrent(windowHandle, NULL);
    SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
    uploadContextLock.unlock();
    //glfwSetWindowPos(sdlViewport->handle, viewport.xpos, viewport.ypos); // SDL_SetWindowPosition
    dpiScale = SDL_GetWindowDisplayScale(windowHandle);
    float logical_to_pixel_factor = SDL_GetWindowPixelDensity(windowHandle);
    float factor = dpiScale / logical_to_pixel_factor;
    SDL_SetWindowSize(windowHandle, (int)(frameWidth * factor), (int)(frameHeight * factor));
    SDL_SetWindowMaximumSize(windowHandle, (int)(maxWidth * factor), (int)(maxHeight * factor));
    SDL_SetWindowMinimumSize(windowHandle, (int)(minWidth * factor), (int)(minHeight * factor));
    SDL_ShowWindow(windowHandle);

    dpiScale = SDL_GetWindowDisplayScale(windowHandle);
    logical_to_pixel_factor = SDL_GetWindowPixelDensity(windowHandle);
    float updated_factor = dpiScale / logical_to_pixel_factor;
    if (factor != updated_factor) {
        SDL_SetWindowSize(windowHandle, (int)(frameWidth * factor), (int)(frameHeight * factor));
        SDL_SetWindowMaximumSize(windowHandle, (int)(maxWidth * factor), (int)(maxHeight * factor));
        SDL_SetWindowMinimumSize(windowHandle, (int)(minWidth * factor), (int)(minHeight * factor));
    }

    SDL_GetWindowSizeInPixels(windowHandle, &frameWidth, &frameHeight);
    SDL_GetWindowSize(windowHandle, &windowWidth, &windowHeight);

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
        glfwSetWindowIcon(sdlViewport->handle, images.size(), images.data());
    */

    // A single thread can use a context at a time
    renderContextLock.lock();

    SDL_GL_MakeCurrent(windowHandle, glContext);

    // Setup Platform/Renderer bindings 
    hasSDL3Init = ImGui_ImplSDL3_InitForOpenGL(windowHandle, glContext);
    if (!hasSDL3Init) {
        SDL_GL_DestroyContext(glContext);
        SDL_DestroyWindow(windowHandle);
        return false;
    }

    // Setup rendering
    hasOpenGL3Init = ImGui_ImplOpenGL3_Init(glsl_version);
    if (!hasOpenGL3Init) {
        ImGui_ImplSDL3_Shutdown();
        hasSDL3Init = false;
        SDL_GL_DestroyContext(glContext);
        SDL_DestroyWindow(windowHandle);
        return false;
    }

    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();

    return true;
}

void SDLViewport::maximize() {
    SDL_MaximizeWindow(windowHandle);
}

void SDLViewport::minimize() {
    SDL_MinimizeWindow(windowHandle);
}

void SDLViewport::restore() {
    SDL_RestoreWindow(windowHandle);
}

void SDLViewport::processEvents() {
    // Move implementation from mvProcessEvents here
    // Replace viewport. with this->
    if (positionChangeRequested)
    {
        SDL_SetWindowPosition(windowHandle, positionX, positionY);
        positionChangeRequested = false;
    }

    if (sizeChangeRequested)
    {
        float logical_to_pixel_factor = SDL_GetWindowPixelDensity(windowHandle);
        float factor = dpiScale / logical_to_pixel_factor;
        SDL_SetWindowMaximumSize(windowHandle, (int)(maxWidth * factor), (int)(maxHeight * factor));
        SDL_SetWindowMinimumSize(windowHandle, (int)(minWidth * factor), (int)(minHeight * factor));
        SDL_SetWindowSize(windowHandle, (int)(frameWidth * factor), (int)(frameHeight * factor));
        sizeChangeRequested = false;
    }

    if (windowPropertyChangeRequested)
    {
        SDL_SetWindowResizable(windowHandle, windowResizable);
        SDL_SetWindowBordered(windowHandle, windowDecorated);
        SDL_SetWindowAlwaysOnTop(windowHandle, windowAlwaysOnTop);
        windowPropertyChangeRequested = false;
    }

    if (titleChangeRequested)
    {
        SDL_SetWindowTitle(windowHandle, windowTitle.c_str());
        titleChangeRequested = false;
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
            if (!waitForEvents)
                break;
            if(activityDetected.load() || needsRefresh.load())
                break;
            SDL_WaitEventTimeout(NULL, 1);
        }

        ImGui_ImplSDL3_ProcessEvent(&event);
        switch (event.type) {
            case SDL_EVENT_WINDOW_MOUSE_ENTER:
            case SDL_EVENT_WINDOW_FOCUS_GAINED:
            case SDL_EVENT_WINDOW_FOCUS_LOST:
            case SDL_EVENT_WINDOW_MOVED:
            case SDL_EVENT_WINDOW_SHOWN:
            case SDL_EVENT_MOUSE_MOTION:
                activityDetected.store(true);
                break;
            case SDL_EVENT_WINDOW_ENTER_FULLSCREEN:
                isFullScreen = true;
                needsRefresh.store(true);
                break;
            case SDL_EVENT_WINDOW_LEAVE_FULLSCREEN:
                isFullScreen = false;
                needsRefresh.store(true);
                break;
            case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
            case SDL_EVENT_WINDOW_RESIZED:
                hasResized = true;
                needsRefresh.store(true);
                break;
            case SDL_EVENT_MOUSE_WHEEL:
            case SDL_EVENT_MOUSE_BUTTON_DOWN:
            case SDL_EVENT_MOUSE_BUTTON_UP:
            case SDL_EVENT_TEXT_EDITING:
            case SDL_EVENT_TEXT_INPUT:
            case SDL_EVENT_KEY_DOWN:
            case SDL_EVENT_KEY_UP:
            case SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
            case SDL_EVENT_WINDOW_EXPOSED:
            case SDL_EVENT_WINDOW_DESTROYED:
                needsRefresh.store(true);
                break;
            case SDL_EVENT_WINDOW_MINIMIZED:
                activityDetected.store(true);
                isMinimized = true;
                break;
            case SDL_EVENT_WINDOW_MAXIMIZED:
                activityDetected.store(true);
                isMaximized = true;
                break;
            case SDL_EVENT_WINDOW_RESTORED:
                activityDetected.store(true);
                isMinimized = true;
                isMaximized = true;
                break;
            case SDL_EVENT_QUIT:
            case SDL_EVENT_WINDOW_CLOSE_REQUESTED: // && event.window.windowID == SDL_GetWindowID(handle)
                closeCallback(callbackData);
                activityDetected.store(true);
            /* TODO: drag&drop, etc*/
            default:
                break;
        }
    }
    //if (waitForEvents || glfwGetWindowAttrib(handle, GLFW_ICONIFIED))
    //    while (!activityDetected.load() && !needs_refresh.load())
    //        glfwWaitEventsTimeout(0.001);
    activityDetected.store(false);
}

// Update renderFrame to use member prepare_present
bool SDLViewport::renderFrame(bool can_skip_presenting) {
    renderContextLock.lock();
    SDL_GL_MakeCurrent(windowHandle, glContext);

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();
    ImGui_ImplSDL3_NewFrame();
    ImGui::NewFrame();

    if (GImGui->CurrentWindow == nullptr)
        return false;

    bool does_needs_refresh = needsRefresh.load();
    needsRefresh.store(false);

    renderCallback(callbackData);

    // Updates during the frame
    // Not all might have been made into rendering
    // thus we don't reset needs_refresh
    does_needs_refresh |= needsRefresh.load();

    if (fastActivityCheck()) {
        does_needs_refresh = true;
        /* Refresh next frame in case of activity.
         * For instance click release might open
         * a menu */
        needsRefresh.store(true);
    }

    static bool prev_needs_refresh = true;

    // shouldSkipPresenting: When we need to redraw in order
    // to improve positioning, and avoid bad frames.
    // We still return in render_frame as the user
    // might want that to handle callbacks right away.
    // The advantage of shouldSkipPresenting though,
    // is that we are not limited by vsync to
    // do the recomputation.
    if (!can_skip_presenting)
        shouldSkipPresenting = false;

    // Maybe we could use some statistics like number of vertices
    can_skip_presenting &= !does_needs_refresh && !prev_needs_refresh;

    // The frame just after an activity might trigger some visual changes
    prev_needs_refresh = does_needs_refresh;
    if (does_needs_refresh)
        activityDetected.store(true);

    if (can_skip_presenting || shouldSkipPresenting) {
        shouldSkipPresenting = false;
        ImGui::EndFrame();
        return false;
    }

    preparePresentFrame();  // Updated to use member function
    return true;
}

void SDLViewport::present() {
    // Move implementation from mvPresent here
    // Replace viewport. with this->
    renderContextLock.lock();
    SDL_GL_MakeCurrent(windowHandle, glContext);
    SDL_GL_SwapWindow(windowHandle);
    dpiScale = SDL_GetWindowDisplayScale(windowHandle);
    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();
}

void SDLViewport::toggleFullScreen() {
    SDL_SetWindowFullscreen(windowHandle, !isFullScreen);
}

void SDLViewport::wakeRendering() {
    needsRefresh.store(true);
    SDL_Event user_event;
    user_event.type = SDL_EVENT_USER;
    user_event.user.code = 2;
    user_event.user.data1 = NULL;
    user_event.user.data2 = NULL;
    SDL_PushEvent(&user_event);
}

void SDLViewport::makeUploadContextCurrent() {
    uploadContextLock.lock();
    SDL_GL_MakeCurrent(uploadWindowHandle, uploadGLContext);
}

void SDLViewport::releaseUploadContext() {
    glFlush();
    SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
    uploadContextLock.unlock();
    needsRefresh.store(true);
}
