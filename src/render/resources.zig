const std = @import("std");
const wgpu = @import("wgpu");

pub const Error = error{
    NoAdapter,
    NoDevice,
};

const depth_format = wgpu.TextureFormat.depth24_plus;
const shadow_depth_format = wgpu.TextureFormat.depth32_float;
const shadow_map_size = 1024;

pub const GpuContext = struct {
    adapter: *wgpu.Adapter,
    device: *wgpu.Device,
    queue: *wgpu.Queue,

    pub fn deinit(self: *GpuContext) void {
        self.queue.release();
        self.device.release();
        self.adapter.release();
    }
};

pub const DepthTarget = struct {
    texture: ?*wgpu.Texture = null,
    view: ?*wgpu.TextureView = null,
    width: u32 = 0,
    height: u32 = 0,

    pub fn create(device: *wgpu.Device, width: u32, height: u32) Error!DepthTarget {
        var target = DepthTarget{};
        try target.ensure(device, width, height);
        return target;
    }

    pub fn ensure(self: *DepthTarget, device: *wgpu.Device, width: u32, height: u32) Error!void {
        if (self.view != null and self.width == width and self.height == height) {
            return;
        }

        self.deinit();

        const texture = device.createTexture(&wgpu.TextureDescriptor{
            .label = wgpu.StringView.fromSlice("Scrapbot mesh depth texture"),
            .size = .{
                .width = width,
                .height = height,
                .depth_or_array_layers = 1,
            },
            .format = depth_format,
            .usage = wgpu.TextureUsages.render_attachment,
        }) orelse return Error.NoDevice;
        errdefer texture.release();

        const view = texture.createView(&wgpu.TextureViewDescriptor{
            .label = wgpu.StringView.fromSlice("Scrapbot mesh depth view"),
            .mip_level_count = 1,
            .array_layer_count = 1,
        }) orelse return Error.NoDevice;

        self.texture = texture;
        self.view = view;
        self.width = width;
        self.height = height;
    }

    pub fn deinit(self: *DepthTarget) void {
        if (self.view) |view| {
            view.release();
        }
        if (self.texture) |texture| {
            texture.release();
        }
        self.* = .{};
    }
};

pub const PostProcessTarget = struct {
    texture: ?*wgpu.Texture = null,
    view: ?*wgpu.TextureView = null,
    width: u32 = 0,
    height: u32 = 0,

    pub fn ensure(
        self: *PostProcessTarget,
        device: *wgpu.Device,
        width: u32,
        height: u32,
        format: wgpu.TextureFormat,
    ) Error!void {
        if (self.texture != null and self.width == width and self.height == height) {
            return;
        }

        self.deinit();
        const texture = device.createTexture(&wgpu.TextureDescriptor{
            .label = wgpu.StringView.fromSlice("Scrapbot postprocess scene texture"),
            .size = .{
                .width = width,
                .height = height,
                .depth_or_array_layers = 1,
            },
            .format = format,
            .usage = wgpu.TextureUsages.render_attachment | wgpu.TextureUsages.texture_binding,
        }) orelse return Error.NoDevice;
        errdefer texture.release();

        const view = texture.createView(&wgpu.TextureViewDescriptor{
            .label = wgpu.StringView.fromSlice("Scrapbot postprocess scene view"),
            .mip_level_count = 1,
            .array_layer_count = 1,
        }) orelse return Error.NoDevice;
        errdefer view.release();

        self.* = .{
            .texture = texture,
            .view = view,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *PostProcessTarget) void {
        if (self.view) |view| {
            view.release();
        }
        if (self.texture) |texture| {
            texture.release();
        }
        self.* = .{};
    }
};

pub const ShadowTarget = struct {
    texture: ?*wgpu.Texture = null,
    view: ?*wgpu.TextureView = null,

    pub fn create(device: *wgpu.Device) Error!ShadowTarget {
        const texture = device.createTexture(&wgpu.TextureDescriptor{
            .label = wgpu.StringView.fromSlice("Scrapbot shadow map texture"),
            .size = .{
                .width = shadow_map_size,
                .height = shadow_map_size,
                .depth_or_array_layers = 1,
            },
            .format = shadow_depth_format,
            .usage = wgpu.TextureUsages.render_attachment | wgpu.TextureUsages.texture_binding,
        }) orelse return Error.NoDevice;
        errdefer texture.release();

        const view = texture.createView(&wgpu.TextureViewDescriptor{
            .label = wgpu.StringView.fromSlice("Scrapbot shadow map view"),
            .mip_level_count = 1,
            .array_layer_count = 1,
            .aspect = .depth_only,
        }) orelse return Error.NoDevice;

        return .{
            .texture = texture,
            .view = view,
        };
    }

    pub fn deinit(self: *ShadowTarget) void {
        if (self.view) |view| {
            view.release();
        }
        if (self.texture) |texture| {
            texture.release();
        }
        self.* = .{};
    }
};

pub fn openGpu(instance: *wgpu.Instance, compatible_surface: ?*wgpu.Surface) Error!GpuContext {
    const adapter_response = instance.requestAdapterSync(&wgpu.RequestAdapterOptions{
        .compatible_surface = compatible_surface,
    }, 200_000_000);
    const adapter = switch (adapter_response.status) {
        .success => adapter_response.adapter orelse return Error.NoAdapter,
        else => return Error.NoAdapter,
    };
    errdefer adapter.release();

    const device_response = adapter.requestDeviceSync(instance, &wgpu.DeviceDescriptor{
        .required_limits = null,
    }, 200_000_000);
    const device = switch (device_response.status) {
        .success => device_response.device orelse return Error.NoDevice,
        else => return Error.NoDevice,
    };
    errdefer device.release();

    const queue = device.getQueue() orelse return Error.NoDevice;
    errdefer queue.release();

    return .{
        .adapter = adapter,
        .device = device,
        .queue = queue,
    };
}

pub fn chooseSurfaceFormat(capabilities: wgpu.SurfaceCapabilities) ?wgpu.TextureFormat {
    for (capabilities.formats[0..capabilities.format_count]) |format| {
        if (format == .bgra8_unorm_srgb) {
            return format;
        }
    }

    if (capabilities.format_count == 0) {
        return null;
    }
    return capabilities.formats[0];
}

pub fn createStaticBuffer(device: *wgpu.Device, label: []const u8, usage: wgpu.BufferUsage, data: []const u8) Error!*wgpu.Buffer {
    const buffer = device.createBuffer(&wgpu.BufferDescriptor{
        .label = wgpu.StringView.fromSlice(label),
        .usage = usage,
        .size = data.len,
        .mapped_at_creation = @as(u32, @intFromBool(true)),
    }) orelse return Error.NoDevice;
    errdefer buffer.release();

    const mapped: [*]u8 = @ptrCast(@alignCast(buffer.getMappedRange(0, data.len) orelse return Error.NoDevice));
    @memcpy(mapped[0..data.len], data);
    buffer.unmap();
    return buffer;
}

pub fn writeUniforms(queue: *wgpu.Queue, buffer: *wgpu.Buffer, uniforms: anytype) void {
    const bytes = std.mem.asBytes(uniforms);
    queue.writeBuffer(buffer, 0, bytes.ptr, bytes.len);
}
