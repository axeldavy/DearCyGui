#pragma once

#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
#include <mutex>

struct mvViewportData
{
    GLFWwindow* handle = nullptr;
    std::mutex gl_context;
};
