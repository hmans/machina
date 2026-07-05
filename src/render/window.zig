const builtin = @import("builtin");
const render_input = @import("input.zig");
const platform = @import("platform.zig");
const wgpu = @import("wgpu");

const PointerInput = render_input.PointerInput;
const sdl = platform.sdl;

pub const Error = error{
    NoSurface,
    SurfaceFailed,
    WindowingUnsupported,
    MetalViewCreateFailed,
    MetalLayerMissing,
    NativeWindowHandleMissing,
};

pub const Surface = switch (builtin.os.tag) {
    .macos => MacSurface,
    .linux => LinuxSurface,
    .windows => WindowsSurface,
    else => UnsupportedSurface,
};

const UnsupportedSurface = struct {
    surface: *wgpu.Surface,

    pub fn create(_: *wgpu.Instance, _: *anyopaque) Error!UnsupportedSurface {
        return Error.WindowingUnsupported;
    }

    pub fn deinit(_: *UnsupportedSurface) void {}
};

const MacSurface = struct {
    surface: *wgpu.Surface,
    metal_view: *anyopaque,

    pub fn create(instance: *wgpu.Instance, window: *anyopaque) Error!MacSurface {
        const metal_view = sdl.scrapbot_sdl_create_metal_view(window) orelse return Error.MetalViewCreateFailed;
        errdefer sdl.scrapbot_sdl_destroy_metal_view(metal_view);

        const metal_layer = sdl.scrapbot_sdl_get_metal_layer(metal_view) orelse return Error.MetalLayerMissing;
        var surface_descriptor = wgpu.surfaceDescriptorFromMetalLayer(.{
            .label = "Scrapbot window surface",
            .layer = metal_layer,
        });
        const surface = instance.createSurface(&surface_descriptor) orelse return Error.NoSurface;
        return .{
            .surface = surface,
            .metal_view = metal_view,
        };
    }

    pub fn deinit(self: *MacSurface) void {
        self.surface.unconfigure();
        self.surface.release();
        sdl.scrapbot_sdl_destroy_metal_view(self.metal_view);
        self.* = undefined;
    }
};

const LinuxSurface = struct {
    surface: *wgpu.Surface,

    pub fn create(instance: *wgpu.Instance, window: *anyopaque) Error!LinuxSurface {
        var wayland_display: ?*anyopaque = null;
        var wayland_surface: ?*anyopaque = null;
        if (sdl.scrapbot_sdl_get_wayland_handles(window, &wayland_display, &wayland_surface) != 0) {
            var surface_descriptor = wgpu.surfaceDescriptorFromWaylandSurface(.{
                .label = "Scrapbot window surface",
                .display = wayland_display orelse return Error.NativeWindowHandleMissing,
                .surface = wayland_surface orelse return Error.NativeWindowHandleMissing,
            });
            const surface = instance.createSurface(&surface_descriptor) orelse return Error.NoSurface;
            return .{ .surface = surface };
        }

        var x11_display: ?*anyopaque = null;
        var x11_window: u64 = 0;
        if (sdl.scrapbot_sdl_get_x11_handles(window, &x11_display, &x11_window) != 0) {
            var surface_descriptor = wgpu.surfaceDescriptorFromXlibWindow(.{
                .label = "Scrapbot window surface",
                .display = x11_display orelse return Error.NativeWindowHandleMissing,
                .window = x11_window,
            });
            const surface = instance.createSurface(&surface_descriptor) orelse return Error.NoSurface;
            return .{ .surface = surface };
        }

        return Error.NativeWindowHandleMissing;
    }

    pub fn deinit(self: *LinuxSurface) void {
        self.surface.unconfigure();
        self.surface.release();
        self.* = undefined;
    }
};

const WindowsSurface = struct {
    surface: *wgpu.Surface,

    pub fn create(instance: *wgpu.Instance, window: *anyopaque) Error!WindowsSurface {
        var hinstance: ?*anyopaque = null;
        var hwnd: ?*anyopaque = null;
        if (sdl.scrapbot_sdl_get_win32_handles(window, &hinstance, &hwnd) == 0) {
            return Error.NativeWindowHandleMissing;
        }
        var surface_descriptor = wgpu.surfaceDescriptorFromWindowsHWND(.{
            .label = "Scrapbot window surface",
            .hinstance = hinstance orelse return Error.NativeWindowHandleMissing,
            .hwnd = hwnd orelse return Error.NativeWindowHandleMissing,
        });
        const surface = instance.createSurface(&surface_descriptor) orelse return Error.NoSurface;
        return .{ .surface = surface };
    }

    pub fn deinit(self: *WindowsSurface) void {
        self.surface.unconfigure();
        self.surface.release();
        self.* = undefined;
    }
};

pub fn updatePointerFromWindow(pointer: *PointerInput, window: *anyopaque, x: f32, y: f32) void {
    var window_width: c_int = 0;
    var window_height: c_int = 0;
    var pixel_width: c_int = 0;
    var pixel_height: c_int = 0;

    const has_window_size = sdl.scrapbot_sdl_get_window_size(window, &window_width, &window_height);
    const has_pixel_size = sdl.scrapbot_sdl_get_window_size_in_pixels(window, &pixel_width, &pixel_height);
    if (has_window_size == 0 or has_pixel_size == 0 or window_width <= 0 or window_height <= 0) {
        pointer.position = .{ x, y };
        pointer.has_position = true;
        return;
    }

    const scale_x = @as(f32, @floatFromInt(@max(pixel_width, 1))) / @as(f32, @floatFromInt(window_width));
    const scale_y = @as(f32, @floatFromInt(@max(pixel_height, 1))) / @as(f32, @floatFromInt(window_height));
    pointer.position = .{ x * scale_x, y * scale_y };
    pointer.has_position = true;
}

pub fn configureSurfaceFromWindow(
    surface: *wgpu.Surface,
    device: *wgpu.Device,
    window: *anyopaque,
    format: wgpu.TextureFormat,
    current_width: *u32,
    current_height: *u32,
) Error!void {
    var pixel_width: c_int = 0;
    var pixel_height: c_int = 0;
    if (sdl.scrapbot_sdl_get_window_size_in_pixels(window, &pixel_width, &pixel_height) == 0) {
        return Error.SurfaceFailed;
    }

    const width: u32 = @intCast(@max(pixel_width, 1));
    const height: u32 = @intCast(@max(pixel_height, 1));
    if (width == current_width.* and height == current_height.*) {
        return;
    }

    surface.configure(&wgpu.SurfaceConfiguration{
        .device = device,
        .format = format,
        .width = width,
        .height = height,
        .present_mode = .fifo,
    });
    current_width.* = width;
    current_height.* = height;
}
