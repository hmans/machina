const std = @import("std");
const runtime = @import("runtime.zig");
const scene_loader = @import("project/scene_loader.zig");
const script = @import("script.zig");

const allocator = std.heap.wasm_allocator;
const renderable_snapshot_stride = 13;

const PlayerState = struct {
    project_name: ?[]u8 = null,
    scene_path: ?[]u8 = null,
    scene_source: ?[]u8 = null,
    scripts: std.ArrayList(OwnedScript) = .empty,
    program: ?script.Program = null,
    scene: ?scene_loader.Scene = null,
    initialized: bool = false,
    phase: u32 = 0,
    frames: u32 = 0,
    renderable_snapshot: std.ArrayList(f32) = .empty,
    camera_snapshot: [7]f32 = .{ 0.0, 0.0, 4.8, 0.0, 0.0, 0.0, 48.0 },
    last_error: []u8 = &.{},

    fn reset(self: *PlayerState) void {
        if (self.scene) |scene| {
            scene_loader.freeScene(allocator, scene);
            self.scene = null;
        }
        if (self.program) |*program| {
            program.deinit();
            self.program = null;
        }
        for (self.scripts.items) |*owned| {
            owned.deinit();
        }
        self.scripts.deinit(allocator);
        self.scripts = .empty;
        self.renderable_snapshot.deinit(allocator);
        if (self.scene_source) |value| allocator.free(value);
        if (self.scene_path) |value| allocator.free(value);
        if (self.project_name) |value| allocator.free(value);
        allocator.free(self.last_error);
        self.* = .{};
    }

    fn setError(self: *PlayerState, message: []const u8) void {
        allocator.free(self.last_error);
        self.last_error = allocator.dupe(u8, message) catch &.{};
    }

    fn setErrorName(self: *PlayerState, comptime prefix: []const u8, err: anyerror) void {
        allocator.free(self.last_error);
        self.last_error = std.fmt.allocPrint(allocator, prefix ++ ": {s}", .{@errorName(err)}) catch &.{};
    }
};

const OwnedScript = struct {
    path: []u8,
    contents: []u8,

    fn deinit(self: *OwnedScript) void {
        allocator.free(self.path);
        allocator.free(self.contents);
        self.* = undefined;
    }

    fn source(self: OwnedScript) script.MemorySource {
        return .{
            .path = self.path,
            .contents = self.contents,
        };
    }
};

var player: PlayerState = .{};

export fn scrapbot_alloc(len: usize) usize {
    if (len == 0) {
        return 0;
    }
    const memory = allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(memory.ptr);
}

export fn scrapbot_free(ptr: usize, len: usize) void {
    if (ptr == 0 or len == 0) {
        return;
    }
    const memory: [*]u8 = @ptrFromInt(ptr);
    allocator.free(memory[0..len]);
}

export fn scrapbot_reset() void {
    player.reset();
}

export fn scrapbot_set_project(name_ptr: usize, name_len: usize, scene_path_ptr: usize, scene_path_len: usize) u32 {
    if (player.initialized) {
        player.setError("cannot set project after initialization");
        return 0;
    }
    replaceOwned(&player.project_name, name_ptr, name_len) catch |err| {
        player.setErrorName("project name", err);
        return 0;
    };
    replaceOwned(&player.scene_path, scene_path_ptr, scene_path_len) catch |err| {
        player.setErrorName("scene path", err);
        return 0;
    };
    player.phase = 1;
    return 1;
}

export fn scrapbot_set_scene(source_ptr: usize, source_len: usize) u32 {
    if (player.initialized) {
        player.setError("cannot set scene after initialization");
        return 0;
    }
    replaceOwned(&player.scene_source, source_ptr, source_len) catch |err| {
        player.setErrorName("scene source", err);
        return 0;
    };
    return 1;
}

export fn scrapbot_add_script(path_ptr: usize, path_len: usize, source_ptr: usize, source_len: usize) u32 {
    if (player.initialized) {
        player.setError("cannot add script after initialization");
        return 0;
    }
    const path = dupFromMemory(path_ptr, path_len) catch |err| {
        player.setErrorName("script path", err);
        return 0;
    };
    errdefer allocator.free(path);
    const contents = dupFromMemory(source_ptr, source_len) catch |err| {
        player.setErrorName("script source", err);
        return 0;
    };
    errdefer allocator.free(contents);
    player.scripts.append(allocator, .{
        .path = path,
        .contents = contents,
    }) catch |err| {
        player.setErrorName("script list", err);
        return 0;
    };
    return 1;
}

export fn scrapbot_init() u32 {
    if (player.initialized) {
        player.setError("already initialized");
        return 0;
    }
    if (player.scene_source == null) {
        player.setError("missing scene source");
        return 0;
    }

    const sources = allocator.alloc(script.MemorySource, player.scripts.items.len) catch |err| {
        player.setErrorName("script sources", err);
        return 0;
    };
    defer allocator.free(sources);
    for (player.scripts.items, 0..) |owned, index| {
        sources[index] = owned.source();
    }

    player.phase = 2;
    const loaded = script.loadMemoryProgramDetailed(allocator, sources) catch |err| {
        player.setErrorName("script load", err);
        return 0;
    };
    var program = switch (loaded) {
        .program => |program| program,
        .diagnostic => |diagnostic| {
            setDiagnosticError(&player, diagnostic);
            var owned_diagnostic = diagnostic;
            owned_diagnostic.deinit(allocator);
            return 0;
        },
    };
    errdefer program.deinit();

    player.phase = 3;
    var scene = scene_loader.loadSceneText(allocator, player.scene_source.?, program.registry) catch |err| {
        player.setErrorName("scene load", err);
        return 0;
    };
    errdefer scene_loader.freeScene(allocator, scene);

    player.phase = 4;
    if (!program.startup(&scene.world)) {
        if (program.last_diagnostic) |diagnostic| {
            setDiagnosticError(&player, diagnostic);
        } else {
            player.setError("script startup failed");
        }
        return 0;
    }

    player.program = program;
    player.scene = scene;
    player.initialized = true;
    player.phase = 5;
    player.frames = 0;
    player.setError("");
    return 1;
}

export fn scrapbot_step(delta_seconds: f32) u32 {
    if (!player.initialized) {
        player.setError("not initialized");
        return 0;
    }
    const program = if (player.program) |*program|
        program
    else {
        player.setError("missing program");
        return 0;
    };
    const scene = if (player.scene) |*scene|
        scene
    else {
        player.setError("missing scene");
        return 0;
    };
    player.phase = 6;
    if (!program.update(&scene.world, delta_seconds)) {
        if (program.last_diagnostic) |diagnostic| {
            setDiagnosticError(&player, diagnostic);
        } else {
            player.setError("script update failed");
        }
        return 0;
    }
    player.phase = 5;
    player.frames += 1;
    return 1;
}

export fn scrapbot_initialized() u32 {
    return @intFromBool(player.initialized);
}

export fn scrapbot_phase() u32 {
    return player.phase;
}

export fn scrapbot_frame_count() u32 {
    return player.frames;
}

export fn scrapbot_entity_count() u32 {
    if (player.scene) |scene| {
        return @intCast(@min(scene.entityCount(), std.math.maxInt(u32)));
    }
    return 0;
}

export fn scrapbot_component_instance_count() u32 {
    if (player.scene) |scene| {
        return @intCast(@min(scene.componentInstanceCount(), std.math.maxInt(u32)));
    }
    return 0;
}

export fn scrapbot_system_count() u32 {
    if (player.program) |program| {
        return @intCast(@min(program.schedule.systemCount(), std.math.maxInt(u32)));
    }
    return 0;
}

export fn scrapbot_renderable_count() u32 {
    if (player.scene) |scene| {
        return @intCast(@min(scene.renderableMeshCount(), std.math.maxInt(u32)));
    }
    return 0;
}

export fn scrapbot_renderable_snapshot_stride() u32 {
    return renderable_snapshot_stride;
}

export fn scrapbot_renderable_snapshot_ptr() usize {
    refreshRenderableSnapshot() catch |err| {
        player.setErrorName("renderable snapshot", err);
        return 0;
    };
    if (player.renderable_snapshot.items.len == 0) {
        return 0;
    }
    return @intFromPtr(player.renderable_snapshot.items.ptr);
}

export fn scrapbot_renderable_snapshot_len() u32 {
    return @intCast(@min(player.renderable_snapshot.items.len, std.math.maxInt(u32)));
}

export fn scrapbot_camera_snapshot_ptr() usize {
    refreshCameraSnapshot();
    return @intFromPtr(&player.camera_snapshot);
}

export fn scrapbot_camera_snapshot_len() u32 {
    return player.camera_snapshot.len;
}

export fn scrapbot_error_ptr() usize {
    return @intFromPtr(player.last_error.ptr);
}

export fn scrapbot_error_len() usize {
    return player.last_error.len;
}

fn replaceOwned(slot: *?[]u8, ptr: usize, len: usize) !void {
    const next = try dupFromMemory(ptr, len);
    if (slot.*) |value| {
        allocator.free(value);
    }
    slot.* = next;
}

fn dupFromMemory(ptr: usize, len: usize) ![]u8 {
    if (len == 0) {
        return allocator.dupe(u8, "");
    }
    if (ptr == 0) {
        return error.InvalidInput;
    }
    const memory: [*]const u8 = @ptrFromInt(ptr);
    return allocator.dupe(u8, memory[0..len]);
}

fn setDiagnosticError(state: *PlayerState, diagnostic: script.Diagnostic) void {
    allocator.free(state.last_error);
    state.last_error = if (diagnostic.path) |path|
        std.fmt.allocPrint(allocator, "{s}: {s}: {s}", .{ @tagName(diagnostic.stage), path, diagnostic.message }) catch &.{}
    else
        std.fmt.allocPrint(allocator, "{s}: {s}", .{ @tagName(diagnostic.stage), diagnostic.message }) catch &.{};
}

fn refreshRenderableSnapshot() !void {
    player.renderable_snapshot.clearRetainingCapacity();
    const scene = if (player.scene) |*scene| scene else return;
    var meshes = scene.world.renderableMeshes();
    while (meshes.next()) |mesh| {
        try appendVec3(&player.renderable_snapshot, mesh.position);
        try appendVec3(&player.renderable_snapshot, mesh.rotation);
        try appendVec3(&player.renderable_snapshot, mesh.scale);
        try appendVec3(&player.renderable_snapshot, mesh.base_color);
        try player.renderable_snapshot.append(allocator, primitiveKind(mesh.primitive));
    }
}

fn refreshCameraSnapshot() void {
    player.camera_snapshot = .{ 0.0, 0.0, 4.8, 0.0, 0.0, 0.0, 48.0 };
    const scene = if (player.scene) |*scene| scene else return;
    const camera = scene.world.renderCamera() orelse return;
    player.camera_snapshot = .{
        camera.transform.position[0],
        camera.transform.position[1],
        camera.transform.position[2],
        camera.transform.rotation[0],
        camera.transform.rotation[1],
        camera.transform.rotation[2],
        camera.fov_y_degrees,
    };
}

fn appendVec3(out: *std.ArrayList(f32), value: [3]f32) !void {
    try out.append(allocator, value[0]);
    try out.append(allocator, value[1]);
    try out.append(allocator, value[2]);
}

fn primitiveKind(primitive: []const u8) f32 {
    if (std.mem.eql(u8, primitive, "plane")) {
        return 2.0;
    }
    if (std.mem.endsWith(u8, primitive, "_sphere")) {
        return 1.0;
    }
    return 0.0;
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    player.setError(message);
    while (true) {}
}
