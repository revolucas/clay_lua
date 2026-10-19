#define RGFW_IMPLEMENTATION
#define RGFW_EXPORT
#include "RGFW.h"

#include <stdint.h>
#include <string.h>

#if defined(_WIN32)
#define CLAY_RGFW_API __declspec(dllexport)
#include <windows.h>
#elif defined(__APPLE__)
#define CLAY_RGFW_API __attribute__((visibility("default")))
#include <mach/mach_time.h>
#else
#define CLAY_RGFW_API __attribute__((visibility("default")))
#include <time.h>
#endif

enum ClayRGFWEventType {
	CLAY_RGFW_EVENT_NONE = 0,
	CLAY_RGFW_EVENT_MOVED,
	CLAY_RGFW_EVENT_RESIZED,
	CLAY_RGFW_EVENT_CLOSE,
	CLAY_RGFW_EVENT_REFRESH,
	CLAY_RGFW_EVENT_FOCUS,
	CLAY_RGFW_EVENT_ICONIFY,
	CLAY_RGFW_EVENT_MAXIMIZED,
	CLAY_RGFW_EVENT_RESTORED,
	CLAY_RGFW_EVENT_SCALE,
	CLAY_RGFW_EVENT_KEY,
	CLAY_RGFW_EVENT_MOUSE_BUTTON,
	CLAY_RGFW_EVENT_MOUSE_POSITION,
	CLAY_RGFW_EVENT_MOUSE_ENTER,
	CLAY_RGFW_EVENT_SCROLL,
	CLAY_RGFW_EVENT_DROP
};

typedef struct ClayRGFWEvent {
	int type;
	int a, b, c, d;
	float x, y;
	int codepoint;
	const char** paths;
	size_t count;
} ClayRGFWEvent;

static int clay_rgfw_key_to_lua(RGFW_key key) {
	if (key >= RGFW_a && key <= RGFW_z)
		return (int)key - ('a' - 'A');
	if (key >= RGFW_0 && key <= RGFW_9)
		return (int)key;
	if (key >= RGFW_F1 && key <= RGFW_F25)
		return 290 + (int)key - (int)RGFW_F1;
	if (key >= RGFW_kp1 && key <= RGFW_kp0) {
		if (key == RGFW_kp0) return 320;
		return 320 + (int)key - (int)RGFW_kp1 + 1;
	}

	if (key >= 32 && key <= 126)
		return (int)key;

	switch (key) {
		case RGFW_escape: return 256;
		case RGFW_return: return 257;
		case RGFW_tab: return 258;
		case RGFW_backSpace: return 259;
		case RGFW_insert: return 260;
		case RGFW_delete: return 261;
		case RGFW_right: return 262;
		case RGFW_left: return 263;
		case RGFW_down: return 264;
		case RGFW_up: return 265;
		case RGFW_pageUp: return 266;
		case RGFW_pageDown: return 267;
		case RGFW_home: return 268;
		case RGFW_end: return 269;
		case RGFW_capsLock: return 280;
		case RGFW_scrollLock: return 281;
		case RGFW_numLock: return 282;
		case RGFW_printScreen: return 283;
		case RGFW_pause: return 284;
		case RGFW_kpPeriod: return 330;
		case RGFW_kpSlash: return 331;
		case RGFW_kpMultiply: return 332;
		case RGFW_kpMinus: return 333;
		case RGFW_kpPlus: return 334;
		case RGFW_kpReturn: return 335;
		case RGFW_kpEqual: return 336;
		case RGFW_shiftL: return 340;
		case RGFW_controlL: return 341;
		case RGFW_altL: return 342;
		case RGFW_superL: return 343;
		case RGFW_shiftR: return 344;
		case RGFW_controlR: return 345;
		case RGFW_altR: return 346;
		case RGFW_superR: return 347;
		case RGFW_menu: return 348;
		case RGFW_world1: return 161;
		case RGFW_world2: return 162;
		default: return -1;
	}
}

static RGFW_key clay_rgfw_key_from_lua(int key) {
	if (key >= 'A' && key <= 'Z')
		return (RGFW_key)(key + ('a' - 'A'));
	if ((key >= '0' && key <= '9') || (key >= 32 && key <= 126))
		return (RGFW_key)key;
	if (key >= 290 && key <= 314)
		return (RGFW_key)(RGFW_F1 + key - 290);
	if (key >= 320 && key <= 329)
		return (RGFW_key)(RGFW_kp1 + (key == 320 ? 9 : key - 321));

	switch (key) {
		case 256: return RGFW_escape;
		case 257: return RGFW_return;
		case 258: return RGFW_tab;
		case 259: return RGFW_backSpace;
		case 260: return RGFW_insert;
		case 261: return RGFW_delete;
		case 262: return RGFW_right;
		case 263: return RGFW_left;
		case 264: return RGFW_down;
		case 265: return RGFW_up;
		case 266: return RGFW_pageUp;
		case 267: return RGFW_pageDown;
		case 268: return RGFW_home;
		case 269: return RGFW_end;
		case 280: return RGFW_capsLock;
		case 281: return RGFW_scrollLock;
		case 282: return RGFW_numLock;
		case 283: return RGFW_printScreen;
		case 284: return RGFW_pause;
		case 330: return RGFW_kpPeriod;
		case 331: return RGFW_kpSlash;
		case 332: return RGFW_kpMultiply;
		case 333: return RGFW_kpMinus;
		case 334: return RGFW_kpPlus;
		case 335: return RGFW_kpReturn;
		case 336: return RGFW_kpEqual;
		case 340: return RGFW_shiftL;
		case 341: return RGFW_controlL;
		case 342: return RGFW_altL;
		case 343: return RGFW_superL;
		case 344: return RGFW_shiftR;
		case 345: return RGFW_controlR;
		case 346: return RGFW_altR;
		case 347: return RGFW_superR;
		case 348: return RGFW_menu;
		case 161: return RGFW_world1;
		case 162: return RGFW_world2;
		default: return RGFW_keyNULL;
	}
}

static int clay_rgfw_mods_to_lua(RGFW_keymod mods) {
	int result = 0;
	if (mods & RGFW_modShift) result |= 0x0001;
	if (mods & RGFW_modControl) result |= 0x0002;
	if (mods & RGFW_modAlt) result |= 0x0004;
	if (mods & RGFW_modSuper) result |= 0x0008;
	if (mods & RGFW_modCapsLock) result |= 0x0010;
	if (mods & RGFW_modNumLock) result |= 0x0020;
	return result;
}

static RGFW_mouseButton clay_rgfw_mouse_from_lua(int button) {
	switch (button) {
		case 0: return RGFW_mouseLeft;
		case 1: return RGFW_mouseRight;
		case 2: return RGFW_mouseMiddle;
		case 3: return RGFW_mouseMisc1;
		case 4: return RGFW_mouseMisc2;
		case 5: return RGFW_mouseMisc3;
		case 6: return RGFW_mouseMisc4;
		case 7: return RGFW_mouseMisc5;
		default: return RGFW_mouseFinal;
	}
}

CLAY_RGFW_API void* clay_rgfw_create(const char* title, int x, int y, int width, int height, int fullscreen, int centered) {
	RGFW_windowFlags flags = (RGFW_windowFlags)RGFW_windowAllowDND;
	if (fullscreen) flags |= RGFW_windowFullscreen;
	if (centered && !fullscreen) flags |= RGFW_windowCenter;

	RGFW_window* win = RGFW_createWindow(title, x, y, width, height, flags);
	if (win != NULL)
		RGFW_window_setExitKey(win, RGFW_keyNULL);
	return win;
}

CLAY_RGFW_API int clay_rgfw_next_event(void* handle, ClayRGFWEvent* out) {
	RGFW_event event;
	RGFW_window* win = (RGFW_window*)handle;
	if (win == NULL || out == NULL || !RGFW_window_checkEvent(win, &event))
		return 0;

	memset(out, 0, sizeof(*out));
	switch (event.type) {
		case RGFW_windowMoved:
			out->type = CLAY_RGFW_EVENT_MOVED;
			out->a = win->x; out->b = win->y;
			break;
		case RGFW_windowResized:
			out->type = CLAY_RGFW_EVENT_RESIZED;
			out->a = win->w; out->b = win->h;
			break;
		case RGFW_quit:
			out->type = CLAY_RGFW_EVENT_CLOSE;
			break;
		case RGFW_windowRefresh:
			out->type = CLAY_RGFW_EVENT_REFRESH;
			break;
		case RGFW_focusIn:
		case RGFW_focusOut:
			out->type = CLAY_RGFW_EVENT_FOCUS;
			out->a = event.type == RGFW_focusIn;
			break;
		case RGFW_windowMinimized:
			out->type = CLAY_RGFW_EVENT_ICONIFY;
			out->a = 1;
			break;
		case RGFW_windowMaximized:
			out->type = CLAY_RGFW_EVENT_MAXIMIZED;
			out->a = 1;
			break;
		case RGFW_windowRestored:
			out->type = CLAY_RGFW_EVENT_RESTORED;
			break;
		case RGFW_scaleUpdated:
			out->type = CLAY_RGFW_EVENT_SCALE;
			out->x = event.scale.x; out->y = event.scale.y;
			break;
		case RGFW_keyPressed:
		case RGFW_keyReleased: {
			int pressed = event.type == RGFW_keyPressed;
			out->type = CLAY_RGFW_EVENT_KEY;
			out->a = clay_rgfw_key_to_lua(event.key.value);
			out->b = (int)event.key.value;
			out->c = pressed ? (event.key.repeat ? 2 : 1) : 0;
			out->d = clay_rgfw_mods_to_lua(event.key.mod);
			out->codepoint = event.key.sym;
			break;
		}
		case RGFW_mouseButtonPressed:
		case RGFW_mouseButtonReleased:
			out->type = CLAY_RGFW_EVENT_MOUSE_BUTTON;
			out->a = event.button.value == RGFW_mouseLeft ? 0 :
				event.button.value == RGFW_mouseRight ? 1 :
				event.button.value == RGFW_mouseMiddle ? 2 : 3 + (int)event.button.value - (int)RGFW_mouseMisc1;
			out->b = event.type == RGFW_mouseButtonPressed;
			break;
		case RGFW_mousePosChanged:
			out->type = CLAY_RGFW_EVENT_MOUSE_POSITION;
			out->x = (float)event.mouse.x; out->y = (float)event.mouse.y;
			break;
		case RGFW_mouseEnter:
		case RGFW_mouseLeave:
			out->type = CLAY_RGFW_EVENT_MOUSE_ENTER;
			out->a = event.type == RGFW_mouseEnter;
			break;
		case RGFW_mouseScroll:
			out->type = CLAY_RGFW_EVENT_SCROLL;
			out->x = event.scroll.x; out->y = event.scroll.y;
			break;
		case RGFW_dataDrop:
			out->type = CLAY_RGFW_EVENT_DROP;
			out->paths = (const char**)event.drop.files;
			out->count = event.drop.count;
			break;
		default:
			out->type = CLAY_RGFW_EVENT_NONE;
			break;
	}
	return 1;
}

CLAY_RGFW_API int clay_rgfw_key_down(void* handle, int key) {
	RGFW_key rgfw_key = clay_rgfw_key_from_lua(key);
	return handle != NULL && rgfw_key != RGFW_keyNULL && RGFW_window_isKeyDown((RGFW_window*)handle, rgfw_key);
}

CLAY_RGFW_API int clay_rgfw_mouse_down(void* handle, int button) {
	RGFW_mouseButton rgfw_button = clay_rgfw_mouse_from_lua(button);
	return handle != NULL && rgfw_button != RGFW_mouseFinal && RGFW_window_isMouseDown((RGFW_window*)handle, rgfw_button);
}

CLAY_RGFW_API void clay_rgfw_mouse_position(void* handle, int* x, int* y) {
	if (handle != NULL) RGFW_window_getMouse((RGFW_window*)handle, x, y);
}

CLAY_RGFW_API void clay_rgfw_get_size(void* handle, int* width, int* height) {
	if (handle != NULL) RGFW_window_getSize((RGFW_window*)handle, width, height);
}

CLAY_RGFW_API void clay_rgfw_get_position(void* handle, int* x, int* y) {
	if (handle != NULL) RGFW_window_getPosition((RGFW_window*)handle, x, y);
}

CLAY_RGFW_API int clay_rgfw_platform_data(void* handle, void** nwh, void** ndt, int* type) {
	if (handle == NULL || nwh == NULL || ndt == NULL || type == NULL) return 0;
	*nwh = NULL; *ndt = NULL; *type = 0;
#if defined(_WIN32)
	*nwh = RGFW_window_getHWND((RGFW_window*)handle);
#elif defined(__APPLE__)
	*nwh = RGFW_window_getWindow_OSX((RGFW_window*)handle);
#elif defined(RGFW_WAYLAND) && !defined(RGFW_X11)
	*nwh = (void*)RGFW_window_getWindow_Wayland((RGFW_window*)handle);
	*ndt = (void*)RGFW_getDisplay_Wayland();
	*type = 1;
#elif defined(RGFW_X11)
	*nwh = (void*)(uintptr_t)RGFW_window_getWindow_X11((RGFW_window*)handle);
	*ndt = RGFW_getDisplay_X11();
#else
	return 0;
#endif
	return *nwh != NULL;
}

CLAY_RGFW_API void clay_rgfw_set_title(void* handle, const char* title) {
	if (handle != NULL) RGFW_window_setName((RGFW_window*)handle, title);
}

CLAY_RGFW_API void clay_rgfw_set_size(void* handle, int width, int height) {
	if (handle != NULL) RGFW_window_resize((RGFW_window*)handle, width, height);
}

CLAY_RGFW_API void clay_rgfw_set_position(void* handle, int x, int y) {
	if (handle != NULL) RGFW_window_move((RGFW_window*)handle, x, y);
}

CLAY_RGFW_API void clay_rgfw_show(void* handle) {
	if (handle != NULL) RGFW_window_show((RGFW_window*)handle);
}

CLAY_RGFW_API void clay_rgfw_hide(void* handle) {
	if (handle != NULL) RGFW_window_hide((RGFW_window*)handle);
}

CLAY_RGFW_API int clay_rgfw_should_close(void* handle) {
	return handle == NULL || RGFW_window_shouldClose((RGFW_window*)handle);
}

CLAY_RGFW_API void clay_rgfw_set_should_close(void* handle, int should_close) {
	if (handle != NULL) RGFW_window_setShouldClose((RGFW_window*)handle, RGFW_BOOL(should_close));
}

CLAY_RGFW_API void clay_rgfw_close(void* handle) {
	if (handle != NULL) RGFW_window_close((RGFW_window*)handle);
}

CLAY_RGFW_API const char* clay_rgfw_clipboard_get(void) {
	return RGFW_readClipboard(NULL);
}

CLAY_RGFW_API void clay_rgfw_clipboard_set(const char* text, uint32_t length) {
	if (text != NULL) RGFW_writeClipboard(text, length);
}

CLAY_RGFW_API double clay_rgfw_time(void) {
#if defined(_WIN32)
	static LARGE_INTEGER frequency;
	LARGE_INTEGER counter;
	if (frequency.QuadPart == 0) QueryPerformanceFrequency(&frequency);
	QueryPerformanceCounter(&counter);
	return (double)counter.QuadPart / (double)frequency.QuadPart;
#elif defined(__APPLE__)
	static mach_timebase_info_data_t info;
	if (info.denom == 0) mach_timebase_info(&info);
	return (double)mach_absolute_time() * (double)info.numer / (double)info.denom / 1.0e9;
#else
	struct timespec now;
	if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return 0.0;
	return (double)now.tv_sec + (double)now.tv_nsec / 1.0e9;
#endif
}
