#include "mvUtilities.h"

#include <string>
#include <vector>
#include <unordered_map>
#include <GL/gl3w.h>
#include <GLFW/glfw3.h>
#include "mvContext.h"
#include "mvLinuxSpecifics.h"
#include "mvViewport.h"
#include "mvPyUtils.h"
#include "mvCustomTypes.h"

static std::unordered_map<GLuint, GLuint> PBO_ids;

/*
 void
OutputFrameBufferArray(PymvBuffer* out)
{
    mvViewport* viewport = GContext->viewport;
    auto viewportData = (mvViewportData*)viewport->platformSpecifics;

    int display_w, display_h;
    glfwGetFramebufferSize(viewportData->handle, &display_w, &display_h);

    stbi_flip_vertically_on_write(true);
    GLint ReadType = GL_UNSIGNED_BYTE;
    GLint ReadFormat = GL_RGBA;
    glGetIntegerv(GL_IMPLEMENTATION_COLOR_READ_TYPE, &ReadType);
    glGetIntegerv(GL_IMPLEMENTATION_COLOR_READ_FORMAT, &ReadFormat);
    auto data = (GLubyte*)malloc(4 * display_w * display_h);
    if (data)
    {
        glReadPixels(0, 0, display_w, display_h, ReadFormat, ReadType, data);
        out->arr.length = display_w * display_h * 4;
        f32* tdata = new f32[out->arr.length];
        out->arr.width = display_w;
        out->arr.height = display_h;
        for (int row = 0; row < out->arr.height; row++)
        {
            for (int col = 0; col < out->arr.width * 4; col++)
            {
                tdata[row * out->arr.width * 4 + col] = (f32)data[(out->arr.height - 1 - row) * out->arr.width * 4 + col] / 255.0f;
            }
        }
        out->arr.data = tdata;
        free(data);
    }
}
*/

void* mvAllocateTexture(u32 width, u32 height, u32 num_chans, u32 dynamic, u32 type, u32 filtering_mode)
{
    GLuint image_texture;
    GLuint pboid;
    unsigned type_size = (type == 1) ? 1 : 4;

    glGenTextures(1, &image_texture);
    glBindTexture(GL_TEXTURE_2D, image_texture);

    // Setup filtering parameters for display
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (filtering_mode == 0) ? GL_LINEAR : GL_NEAREST);

    // Duplicate the first channel on g and b to display as gray
    if (num_chans == 1) {
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_G, GL_RED);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_B, GL_RED);
    }

    glGenBuffers(1, &pboid);
    PBO_ids[image_texture] = pboid;
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pboid);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
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

void mvUpdateDynamicTexture(void* texture, u32 width, u32 height, u32 num_chans, u32 type, void* data)
{
    auto textureId = (GLuint)(size_t)texture;
    unsigned gl_format = GL_RGBA;
    unsigned gl_type = GL_FLOAT;
    unsigned type_size = 4;

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

    // allocate a new buffer
    glBufferData(GL_PIXEL_UNPACK_BUFFER, width * height * num_chans * type_size, 0, GL_STREAM_DRAW);

    // tequest access to the buffer
    GLubyte* ptr = (GLubyte*)glMapBuffer(GL_PIXEL_UNPACK_BUFFER, GL_WRITE_ONLY);
    if (ptr)
    {
        // update data directly on the mapped buffer
        memcpy(ptr, data, width * height * num_chans * type_size);

        glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);  // release pointer to mapping buffer
    }

    // bind the texture
    glBindTexture(GL_TEXTURE_2D, textureId);

    // copy pixels from PBO to texture object
    glTexImage2D(GL_TEXTURE_2D, 0, gl_format, width, height, 0, gl_format, gl_type, NULL);

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
}

void mvUpdateStaticTexture(void* texture, u32 width, u32 height, u32 num_chans, u32 type, void* data)
{
    mvUpdateDynamicTexture(texture, width, height, num_chans, type, data);
}