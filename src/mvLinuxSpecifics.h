#pragma once

#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
#include <functional>

struct mvViewportData
{
    GLFWwindow* handle = nullptr;
    std::function<void(GLFWwindow*, int, int)> resize_callback;
    std::function<void(GLFWwindow*)> close_callback;
};
