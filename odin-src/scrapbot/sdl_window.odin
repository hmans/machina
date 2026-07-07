package main

import "core:c"
import sdl3 "vendor:sdl3"

SDL_WINDOW_DEFAULT_TITLE :: "Scrapbot"
SDL_WINDOW_DEFAULT_WIDTH :: 1280
SDL_WINDOW_DEFAULT_HEIGHT :: 720

Sdl_Window_Error :: enum {
	None,
	Init_Failed,
	Create_Failed,
	Properties_Unavailable,
	Native_Handle_Missing,
	Unsupported_Platform,
	Metal_View_Create_Failed,
	Metal_Layer_Missing,
	Size_Unavailable,
}

Sdl_Window_Options :: struct {
	title:  cstring,
	width:  int,
	height: int,
	hidden: bool,
}

Sdl_Window_State :: struct {
	window: ^sdl3.Window,
}

Sdl_Window_Size :: struct {
	width:        int,
	height:       int,
	pixel_width:  int,
	pixel_height: int,
}

Sdl_Surface_Source_Kind :: enum {
	None,
	Metal_Layer,
	Wayland_Surface,
	Xlib_Window,
	Windows_HWND,
}

Sdl_WGPU_Surface_Descriptor :: struct {
	kind:           Sdl_Surface_Source_Kind,
	descriptor:     WGPU_Surface_Descriptor,
	metal_source:   WGPU_Surface_Source_Metal_Layer,
	wayland_source: WGPU_Surface_Source_Wayland_Surface,
	xlib_source:    WGPU_Surface_Source_Xlib_Window,
	windows_source: WGPU_Surface_Source_Windows_HWND,
	metal_view:     sdl3.MetalView,
}

sdl_window_default_options :: proc(hidden := false) -> Sdl_Window_Options {
	return Sdl_Window_Options{
		title = cstring(SDL_WINDOW_DEFAULT_TITLE),
		width = SDL_WINDOW_DEFAULT_WIDTH,
		height = SDL_WINDOW_DEFAULT_HEIGHT,
		hidden = hidden,
	}
}

sdl_window_flags :: proc(hidden: bool) -> sdl3.WindowFlags {
	flags := sdl3.WindowFlags{.RESIZABLE, .HIGH_PIXEL_DENSITY}
	when ODIN_OS == .Darwin {
		flags += {.METAL}
	}
	if hidden {
		flags += {.HIDDEN}
	}
	return flags
}

sdl_video_init :: proc() -> Sdl_Window_Error {
	if !sdl3.Init(sdl3.INIT_VIDEO) {
		return .Init_Failed
	}
	return .None
}

sdl_video_quit :: proc() {
	sdl3.Quit()
}

sdl_window_create :: proc(options: Sdl_Window_Options) -> (Sdl_Window_State, Sdl_Window_Error) {
	width := options.width
	height := options.height
	if width <= 0 {
		width = SDL_WINDOW_DEFAULT_WIDTH
	}
	if height <= 0 {
		height = SDL_WINDOW_DEFAULT_HEIGHT
	}
	title := options.title
	if title == nil {
		title = cstring(SDL_WINDOW_DEFAULT_TITLE)
	}
	window := sdl3.CreateWindow(title, c.int(width), c.int(height), sdl_window_flags(options.hidden))
	if window == nil {
		return Sdl_Window_State{}, .Create_Failed
	}
	return Sdl_Window_State{window = window}, .None
}

sdl_window_destroy :: proc(state: ^Sdl_Window_State) {
	if state.window != nil {
		sdl3.DestroyWindow(state.window)
	}
	state^ = Sdl_Window_State{}
}

sdl_window_get_size :: proc(window: ^sdl3.Window) -> (Sdl_Window_Size, Sdl_Window_Error) {
	width, height: c.int
	pixel_width, pixel_height: c.int
	if !sdl3.GetWindowSize(window, &width, &height) {
		return Sdl_Window_Size{}, .Size_Unavailable
	}
	if !sdl3.GetWindowSizeInPixels(window, &pixel_width, &pixel_height) {
		return Sdl_Window_Size{}, .Size_Unavailable
	}
	return Sdl_Window_Size{
		width = int(width),
		height = int(height),
		pixel_width = int(pixel_width),
		pixel_height = int(pixel_height),
	}, .None
}

sdl_wgpu_surface_descriptor_init_metal_layer :: proc(bundle: ^Sdl_WGPU_Surface_Descriptor, label: WGPU_String_View, layer: rawptr, metal_view: sdl3.MetalView) -> Sdl_Window_Error {
	if layer == nil {
		return .Metal_Layer_Missing
	}
	bundle^ = Sdl_WGPU_Surface_Descriptor{}
	bundle.kind = .Metal_Layer
	bundle.metal_view = metal_view
	bundle.metal_source = wgpu_surface_source_metal_layer(layer)
	bundle.descriptor = wgpu_surface_descriptor_from_metal_layer(label, &bundle.metal_source)
	return .None
}

sdl_wgpu_surface_descriptor_init_wayland :: proc(bundle: ^Sdl_WGPU_Surface_Descriptor, label: WGPU_String_View, display, surface: rawptr) -> Sdl_Window_Error {
	if display == nil || surface == nil {
		return .Native_Handle_Missing
	}
	bundle^ = Sdl_WGPU_Surface_Descriptor{}
	bundle.kind = .Wayland_Surface
	bundle.wayland_source = wgpu_surface_source_wayland_surface(display, surface)
	bundle.descriptor = wgpu_surface_descriptor_from_wayland_surface(label, &bundle.wayland_source)
	return .None
}

sdl_wgpu_surface_descriptor_init_xlib :: proc(bundle: ^Sdl_WGPU_Surface_Descriptor, label: WGPU_String_View, display: rawptr, window: u64) -> Sdl_Window_Error {
	if display == nil || window == 0 {
		return .Native_Handle_Missing
	}
	bundle^ = Sdl_WGPU_Surface_Descriptor{}
	bundle.kind = .Xlib_Window
	bundle.xlib_source = wgpu_surface_source_xlib_window(display, window)
	bundle.descriptor = wgpu_surface_descriptor_from_xlib_window(label, &bundle.xlib_source)
	return .None
}

sdl_wgpu_surface_descriptor_init_windows :: proc(bundle: ^Sdl_WGPU_Surface_Descriptor, label: WGPU_String_View, hinstance, hwnd: rawptr) -> Sdl_Window_Error {
	if hinstance == nil || hwnd == nil {
		return .Native_Handle_Missing
	}
	bundle^ = Sdl_WGPU_Surface_Descriptor{}
	bundle.kind = .Windows_HWND
	bundle.windows_source = wgpu_surface_source_windows_hwnd(hinstance, hwnd)
	bundle.descriptor = wgpu_surface_descriptor_from_windows_hwnd(label, &bundle.windows_source)
	return .None
}

sdl_window_init_surface_descriptor :: proc(bundle: ^Sdl_WGPU_Surface_Descriptor, window: ^sdl3.Window, label: string = "Scrapbot window surface") -> Sdl_Window_Error {
	label_view := wgpu_string_view_from_string(label)
	when ODIN_OS == .Darwin {
		metal_view := sdl3.Metal_CreateView(window)
		if rawptr(metal_view) == nil {
			return .Metal_View_Create_Failed
		}
		layer := sdl3.Metal_GetLayer(metal_view)
		err := sdl_wgpu_surface_descriptor_init_metal_layer(bundle, label_view, layer, metal_view)
		if err != .None {
			sdl3.Metal_DestroyView(metal_view)
		}
		return err
	} else when ODIN_OS == .Linux {
		props := sdl3.GetWindowProperties(window)
		if props == 0 {
			return .Properties_Unavailable
		}
		wayland_display := sdl3.GetPointerProperty(props, sdl3.PROP_WINDOW_WAYLAND_DISPLAY_POINTER, nil)
		wayland_surface := sdl3.GetPointerProperty(props, sdl3.PROP_WINDOW_WAYLAND_SURFACE_POINTER, nil)
		if wayland_display != nil && wayland_surface != nil {
			return sdl_wgpu_surface_descriptor_init_wayland(bundle, label_view, wayland_display, wayland_surface)
		}
		x11_display := sdl3.GetPointerProperty(props, sdl3.PROP_WINDOW_X11_DISPLAY_POINTER, nil)
		x11_window := sdl3.GetNumberProperty(props, sdl3.PROP_WINDOW_X11_WINDOW_NUMBER, 0)
		if x11_display != nil && x11_window != 0 {
			return sdl_wgpu_surface_descriptor_init_xlib(bundle, label_view, x11_display, u64(x11_window))
		}
		return .Native_Handle_Missing
	} else when ODIN_OS == .Windows {
		props := sdl3.GetWindowProperties(window)
		if props == 0 {
			return .Properties_Unavailable
		}
		hinstance := sdl3.GetPointerProperty(props, sdl3.PROP_WINDOW_WIN32_INSTANCE_POINTER, nil)
		hwnd := sdl3.GetPointerProperty(props, sdl3.PROP_WINDOW_WIN32_HWND_POINTER, nil)
		return sdl_wgpu_surface_descriptor_init_windows(bundle, label_view, hinstance, hwnd)
	} else {
		return .Unsupported_Platform
	}
}

sdl_wgpu_surface_descriptor_deinit :: proc(bundle: ^Sdl_WGPU_Surface_Descriptor) {
	when ODIN_OS == .Darwin {
		if rawptr(bundle.metal_view) != nil {
			sdl3.Metal_DestroyView(bundle.metal_view)
		}
	}
	bundle^ = Sdl_WGPU_Surface_Descriptor{}
}

sdl_window_error_message :: proc(err: Sdl_Window_Error) -> string {
	switch err {
	case .None:
		return "none"
	case .Init_Failed:
		return sdl_last_error_or("SDL video initialization failed")
	case .Create_Failed:
		return sdl_last_error_or("SDL window creation failed")
	case .Properties_Unavailable:
		return "SDL window properties unavailable"
	case .Native_Handle_Missing:
		return "native window handle missing"
	case .Unsupported_Platform:
		return "platform window surface unsupported"
	case .Metal_View_Create_Failed:
		return "Metal view creation failed"
	case .Metal_Layer_Missing:
		return "Metal layer missing"
	case .Size_Unavailable:
		return "SDL window size unavailable"
	}
	return "SDL window error"
}

sdl_last_error_or :: proc(fallback: string) -> string {
	return fallback
}

sdl_surface_source_kind_label :: proc(kind: Sdl_Surface_Source_Kind) -> string {
	switch kind {
	case .None:
		return "none"
	case .Metal_Layer:
		return "metal-layer"
	case .Wayland_Surface:
		return "wayland-surface"
	case .Xlib_Window:
		return "xlib-window"
	case .Windows_HWND:
		return "windows-hwnd"
	}
	return "unknown"
}
