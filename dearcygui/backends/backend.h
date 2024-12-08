#include <atomic>
#include <vector>
#include <string>

#include <imgui.h>

typedef void (*on_resize_fun)(void*, int width, int height);
typedef void (*on_close_fun)(void*);
typedef void (*render_fun)(void*);

struct mvViewport
{
	bool running = true;
	bool shown = false;
	bool resized = false;

	std::string title = "DearCyGui Window";
	std::string small_icon;
	std::string large_icon;
	float clear_color[4] = { 0., 0., 0., 1. };
		
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
	bool shouldSkipPresenting = false;
	std::atomic<bool> activity{true};
	std::atomic<bool> needs_refresh{true};

	// position/size
	bool  sizeDirty    = false;
	bool  posDirty     = false;
	unsigned minwidth     = 250;
	unsigned minheight    = 250;
	unsigned maxwidth     = 10000;
	unsigned maxheight    = 10000;
	int actualWidth  = 1280; // frame buffer size
	int actualHeight = 800;
	int clientWidth  = 1280; // windows size
	int clientHeight = 800;
	int xpos         = 100;
	int ypos         = 100;
	float dpi        = 1.;

	render_fun render;
	on_resize_fun on_resize;
	on_close_fun on_close;
	void *callback_data;

	void* platformSpecifics = nullptr; // platform specifics
};

typedef void (*on_resize_fun)(void*, int width, int height);
typedef void (*on_close_fun)(void*);
typedef void (*render_fun)(void*);

mvViewport* mvCreateViewport  (render_fun render,
							   on_resize_fun on_resize,
							   on_close_fun on_close,
							   void *callback_data);
void        mvCleanupViewport (mvViewport& viewport);
bool        InitializeViewportWindow    (mvViewport& viewport,
							   bool start_minimized,
							   bool start_maximized);
void        mvMaximizeViewport(mvViewport& viewport);
void        mvMinimizeViewport(mvViewport& viewport);
void        mvRestoreViewport (mvViewport& viewport);
void        mvProcessEvents(mvViewport* viewport);
bool        mvRenderFrame(mvViewport& viewport,
						  bool can_skip_presenting);
void		mvPresent(mvViewport* viewport);
void        mvToggleFullScreen(mvViewport& viewport);
void        mvWakeRendering(mvViewport& viewport);
void        mvMakeUploadContextCurrent(mvViewport& viewport);
void        mvReleaseUploadContext(mvViewport& viewport);

void* mvAllocateTexture(unsigned width, unsigned height, unsigned num_chans, unsigned dynamic, unsigned type, unsigned filtering_mode);
void mvFreeTexture(void* texture);

bool mvUpdateDynamicTexture(void* texture, unsigned width, unsigned height, unsigned num_chans, unsigned type, void* data, unsigned src_stride);
bool mvUpdateStaticTexture(void* texture, unsigned width, unsigned height, unsigned num_chans, unsigned type, void* data, unsigned src_stride);