#include <vector>
#include <string>

#include <imgui.h>

struct GLFWwindow;

typedef void (*on_resize_fun)(void*, int width, int height);
typedef void (*on_close_fun)(void*);
typedef void (*render_fun)(void*);

struct mvColor
{
	static unsigned int ConvertToUnsignedInt(const mvColor& color)
	{
		return ImGui::ColorConvertFloat4ToU32(color.toVec4());
	}
	float r = -1.0f, g = -1.0f, b = -1.0f, a = -1.0f;
	mvColor() = default;
	mvColor(float r, float g, float b, float a)
		: r(r), g(g), b(b), a(a)
	{
	}
	mvColor(int r, int g, int b, int a)
		: r(r/255.0f), g(g/255.0f), b(b/255.0f), a(a/255.0f)
	{
	}
	explicit mvColor(ImVec4 color)
	{
		r = color.x;
		g = color.y;
		b = color.z;
		a = color.w;
	}
	operator ImU32() const
	{
		return ImGui::ColorConvertFloat4ToU32(toVec4());
	}
	operator float* ()
	{
		return &r;
	}
	operator ImVec4() const
	{
		return { r, g, b, a };
	}
	operator ImVec4*()
	{
		return (ImVec4*)&r;
	}
	const ImVec4 toVec4() const
	{
		return { r, g, b, a };
	}
};

struct mvViewport
{
	bool running = true;
	bool shown = false;
	bool resized = false;

	std::string title = "Dear PyGui";
	std::string small_icon;
	std::string large_icon;
	mvColor     clearColor = mvColor(0, 0, 0, 255);
		
	// window modes
	bool titleDirty  = false;
	bool modesDirty  = false;
	bool vsync       = true;
	bool resizable   = true;
	bool alwaysOnTop = false;
	bool decorated   = true;
    bool fullScreen  = false;
	bool disableClose = false;
	bool waitForEvents = false;

	// position/size
	bool  sizeDirty    = false;
	bool  posDirty     = false;
	unsigned width        = 0;
	unsigned height       = 0;
	unsigned minwidth     = 250;
	unsigned minheight    = 250;
	unsigned maxwidth     = 10000;
	unsigned maxheight    = 10000;
	int actualWidth  = 1280;
	int actualHeight = 800;
	int clientWidth  = 1280;
	int clientHeight = 800;
	int xpos         = 100;
	int ypos         = 100;

	render_fun render;
	on_resize_fun on_resize;
	on_close_fun on_close;
	void *callback_data;

	void* platformSpecifics = nullptr; // platform specifics
};

struct mvGraphics
{
    bool           ok = false;
    void* backendSpecifics = nullptr;
};

mvGraphics setup_graphics(mvViewport& viewport);
void       resize_swapchain(mvGraphics& graphics, int width, int height);
void       cleanup_graphics(mvGraphics& graphics);
void       present(mvGraphics& graphics, mvViewport* viewport, mvColor& clearColor, bool vsync);

typedef void (*on_resize_fun)(void*, int width, int height);
typedef void (*on_close_fun)(void*);
typedef void (*render_fun)(void*);

mvViewport* mvCreateViewport  (unsigned width,
							   unsigned height,
							   render_fun render,
							   on_resize_fun on_resize,
							   on_close_fun on_close,
							   void *callback_data);
void        mvCleanupViewport (mvViewport& viewport);
void        mvShowViewport    (mvViewport& viewport,
							   bool minimized,
							   bool maximized);
void        mvMaximizeViewport(mvViewport& viewport);
void        mvMinimizeViewport(mvViewport& viewport);
void        mvRestoreViewport (mvViewport& viewport);
void        mvRenderFrame(mvViewport& viewport,
						  mvGraphics& graphics);
void        mvToggleFullScreen(mvViewport& viewport);
void        mvWakeRendering(mvViewport& viewport);
void        mvMakeRenderingContextCurrent(mvViewport& viewport);
void        mvReleaseRenderingContext(mvViewport& viewport);

void* mvAllocateTexture(unsigned width, unsigned height, unsigned num_chans, unsigned dynamic, unsigned type, unsigned filtering_mode);
void mvFreeTexture(void* texture);

void mvUpdateDynamicTexture(void* texture, unsigned width, unsigned height, unsigned num_chans, unsigned type, void* data);
void mvUpdateStaticTexture(void* texture, unsigned width, unsigned height, unsigned num_chans, unsigned type, void* data);