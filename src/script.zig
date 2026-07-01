const std = @import("std");
const Io = std.Io;
const runtime = @import("runtime.zig");

const c = @cImport({
    @cInclude("luau_bridge.h");
});

pub const ScriptError = runtime.RegistryError || runtime.ScheduleError || std.mem.Allocator.Error || error{
    InvalidScript,
    UnknownFieldType,
    UnknownSystemPhase,
};

pub const Program = struct {
    allocator: std.mem.Allocator,
    registry: runtime.ComponentRegistry,
    schedule: runtime.SystemSchedule,
    vm: *c.machina_luau,
    active_system: ?*const runtime.ScheduledSystem = null,

    pub fn deinit(self: *Program) void {
        self.schedule.deinit();
        self.registry.deinit();
        c.machina_luau_destroy(self.vm);
        self.* = undefined;
    }

    pub fn update(self: *Program, world: *runtime.World, delta_seconds: f32) bool {
        c.machina_luau_set_callback_context(self.vm, self);

        var ok = true;
        for (self.schedule.batches) |batch| {
            if (batch.phase != .update) {
                continue;
            }

            for (batch.systems) |*system| {
                switch (system.runner) {
                    .none => {},
                    .luau => |runner_ref| {
                        self.active_system = system;
                        const system_ok = c.machina_luau_call_system(self.vm, runner_ref, world, delta_seconds) != 0;
                        self.active_system = null;
                        ok = ok and system_ok;
                    },
                }
            }
        }
        return ok;
    }

    fn activeSystemAllowsRotate(self: Program, transform_component_id_value: []const u8, spin_component_id_value: []const u8) bool {
        const active_system = self.active_system orelse return false;
        if (active_system.registry_index >= self.registry.systems.items.len) {
            return false;
        }

        const definition = self.registry.systems.items[active_system.registry_index];
        return containsString(definition.reads, spin_component_id_value) and
            containsString(definition.writes, transform_component_id_value);
    }
};

pub fn loadProjectProgram(
    io: Io,
    allocator: std.mem.Allocator,
    root_dir: Io.Dir,
    script_paths: []const []const u8,
) !Program {
    var program = try initProgram(allocator);
    errdefer program.deinit();

    for (script_paths) |script_path| {
        const contents = try root_dir.readFileAlloc(io, script_path, allocator, .limited(256 * 1024));
        defer allocator.free(contents);
        try loadChunk(&program, script_path, contents);
    }

    try registerDeclaredTypes(&program);
    program.schedule = try buildUpdateSchedule(allocator, program.registry);
    return program;
}

pub fn loadSourceProgram(
    allocator: std.mem.Allocator,
    chunk_name: []const u8,
    source: []const u8,
) !Program {
    var program = try initProgram(allocator);
    errdefer program.deinit();
    try loadChunk(&program, chunk_name, source);
    try registerDeclaredTypes(&program);
    program.schedule = try buildUpdateSchedule(allocator, program.registry);
    return program;
}

pub fn buildUpdateSchedule(
    allocator: std.mem.Allocator,
    registry: runtime.ComponentRegistry,
) !runtime.SystemSchedule {
    return registry.buildSchedule(allocator, .update);
}

fn initProgram(allocator: std.mem.Allocator) !Program {
    const callbacks = c.machina_luau_callbacks{
        .rotate = rotateCallback,
    };
    const vm = c.machina_luau_create(callbacks) orelse return ScriptError.InvalidScript;

    var registry = runtime.ComponentRegistry.init(allocator);
    errdefer {
        registry.deinit();
        c.machina_luau_destroy(vm);
    }
    try registerEngineTypes(&registry);

    return .{
        .allocator = allocator,
        .registry = registry,
        .schedule = .{ .allocator = allocator, .batches = &.{} },
        .vm = vm,
    };
}

fn loadChunk(program: *Program, chunk_name: []const u8, source: []const u8) !void {
    const chunk_name_z = try program.allocator.dupeZ(u8, chunk_name);
    defer program.allocator.free(chunk_name_z);

    if (c.machina_luau_load(program.vm, chunk_name_z.ptr, source.ptr, source.len) == 0) {
        return ScriptError.InvalidScript;
    }
}

fn registerEngineTypes(registry: *runtime.ComponentRegistry) !void {
    const transform_fields = [_]runtime.ComponentFieldDefinition{
        .{ .name = "position", .value_type = .float },
        .{ .name = "rotation", .value_type = .float },
        .{ .name = "scale", .value_type = .float },
    };
    try registry.registerEngineComponent(.{
        .id = runtime.transform_component_id,
        .version = 1,
        .fields = &transform_fields,
    });

    const cube_fields = [_]runtime.ComponentFieldDefinition{
        .{ .name = "color", .value_type = .float },
    };
    try registry.registerEngineComponent(.{
        .id = runtime.cube_renderer_component_id,
        .version = 1,
        .fields = &cube_fields,
    });

    const spin_fields = [_]runtime.ComponentFieldDefinition{
        .{ .name = "angular_velocity", .value_type = .float },
    };
    try registry.registerEngineComponent(.{
        .id = runtime.spin_component_id,
        .version = 1,
        .fields = &spin_fields,
    });
}

fn registerDeclaredTypes(program: *Program) ScriptError!void {
    const component_count = c.machina_luau_component_count(program.vm);
    for (0..component_count) |component_index| {
        var fields: std.ArrayList(runtime.ComponentFieldDefinition) = .empty;
        defer fields.deinit(program.allocator);

        const field_count = c.machina_luau_component_field_count(program.vm, component_index);
        for (0..field_count) |field_index| {
            try fields.append(program.allocator, .{
                .name = try spanC(c.machina_luau_component_field_name(program.vm, component_index, field_index)),
                .value_type = try parseFieldType(try spanC(c.machina_luau_component_field_type(program.vm, component_index, field_index))),
            });
        }

        try program.registry.registerProjectComponent(.{
            .id = try spanC(c.machina_luau_component_id(program.vm, component_index)),
            .version = c.machina_luau_component_version(program.vm, component_index),
            .fields = fields.items,
        });
    }

    const system_count = c.machina_luau_system_count(program.vm);
    for (0..system_count) |system_index| {
        var reads = try readSystemReads(program.allocator, program.vm, system_index);
        defer reads.deinit(program.allocator);
        var writes = try readSystemWrites(program.allocator, program.vm, system_index);
        defer writes.deinit(program.allocator);
        var before = try readSystemBefore(program.allocator, program.vm, system_index);
        defer before.deinit(program.allocator);
        var after = try readSystemAfter(program.allocator, program.vm, system_index);
        defer after.deinit(program.allocator);

        const runner_ref = c.machina_luau_system_runner_ref(program.vm, system_index);
        try program.registry.registerProjectSystem(.{
            .id = try spanC(c.machina_luau_system_id(program.vm, system_index)),
            .phase = try parseSystemPhase(try spanC(c.machina_luau_system_phase(program.vm, system_index))),
            .reads = reads.items,
            .writes = writes.items,
            .before = before.items,
            .after = after.items,
            .runner = if (runner_ref == 0) .none else .{ .luau = runner_ref },
        });
    }
}

fn readSystemReads(allocator: std.mem.Allocator, vm: *c.machina_luau, system_index: usize) !std.ArrayList([]const u8) {
    var values: std.ArrayList([]const u8) = .empty;
    errdefer values.deinit(allocator);
    for (0..c.machina_luau_system_reads_count(vm, system_index)) |item_index| {
        try values.append(allocator, try spanC(c.machina_luau_system_reads_item(vm, system_index, item_index)));
    }
    return values;
}

fn readSystemWrites(allocator: std.mem.Allocator, vm: *c.machina_luau, system_index: usize) !std.ArrayList([]const u8) {
    var values: std.ArrayList([]const u8) = .empty;
    errdefer values.deinit(allocator);
    for (0..c.machina_luau_system_writes_count(vm, system_index)) |item_index| {
        try values.append(allocator, try spanC(c.machina_luau_system_writes_item(vm, system_index, item_index)));
    }
    return values;
}

fn readSystemBefore(allocator: std.mem.Allocator, vm: *c.machina_luau, system_index: usize) !std.ArrayList([]const u8) {
    var values: std.ArrayList([]const u8) = .empty;
    errdefer values.deinit(allocator);
    for (0..c.machina_luau_system_before_count(vm, system_index)) |item_index| {
        try values.append(allocator, try spanC(c.machina_luau_system_before_item(vm, system_index, item_index)));
    }
    return values;
}

fn readSystemAfter(allocator: std.mem.Allocator, vm: *c.machina_luau, system_index: usize) !std.ArrayList([]const u8) {
    var values: std.ArrayList([]const u8) = .empty;
    errdefer values.deinit(allocator);
    for (0..c.machina_luau_system_after_count(vm, system_index)) |item_index| {
        try values.append(allocator, try spanC(c.machina_luau_system_after_item(vm, system_index, item_index)));
    }
    return values;
}

fn spanC(value: ?[*:0]const u8) ScriptError![]const u8 {
    return std.mem.span(value orelse return ScriptError.InvalidScript);
}

fn rotateCallback(
    raw_context: ?*anyopaque,
    raw_world: ?*anyopaque,
    transform_id: ?[*:0]const u8,
    spin_id: ?[*:0]const u8,
    delta_seconds: f64,
) callconv(.c) c_int {
    const program: *Program = @ptrCast(@alignCast(raw_context orelse return 0));
    const world: *runtime.World = @ptrCast(@alignCast(raw_world orelse return 0));
    const transform_component_id_value = std.mem.span(transform_id orelse return 0);
    const spin_component_id_value = std.mem.span(spin_id orelse return 0);
    if (!program.activeSystemAllowsRotate(transform_component_id_value, spin_component_id_value)) {
        return 0;
    }
    return if (world.rotateBySpin(transform_component_id_value, spin_component_id_value, @floatCast(delta_seconds))) 1 else 0;
}

fn parseFieldType(value: []const u8) ScriptError!runtime.FieldType {
    if (std.mem.eql(u8, value, "boolean") or std.mem.eql(u8, value, "bool")) {
        return .boolean;
    }
    if (std.mem.eql(u8, value, "int") or std.mem.eql(u8, value, "i32")) {
        return .int;
    }
    if (std.mem.eql(u8, value, "float") or std.mem.eql(u8, value, "f32")) {
        return .float;
    }
    if (std.mem.eql(u8, value, "string")) {
        return .string;
    }
    return ScriptError.UnknownFieldType;
}

fn parseSystemPhase(value: []const u8) ScriptError!runtime.SystemPhase {
    if (std.mem.eql(u8, value, "startup")) {
        return .startup;
    }
    if (std.mem.eql(u8, value, "update")) {
        return .update;
    }
    if (std.mem.eql(u8, value, "fixed_update")) {
        return .fixed_update;
    }
    if (std.mem.eql(u8, value, "render")) {
        return .render;
    }
    return ScriptError.UnknownSystemPhase;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) {
            return true;
        }
    }
    return false;
}

test "luau declarations register components and executable systems" {
    var program = try loadSourceProgram(std.testing.allocator, "test.luau",
        \\ecs.component("health", {
        \\  fields = {
        \\    current = "f32",
        \\    max = "f32",
        \\  },
        \\})
        \\
        \\ecs.system("rotate_cubes", {
        \\  phase = "update",
        \\  reads = { "machina.spin" },
        \\  writes = { "machina.transform" },
        \\  run = function(world, dt)
        \\    world.rotate("machina.transform", "machina.spin", dt * (1 + 1.5))
        \\  end,
        \\})
    );
    defer program.deinit();

    try std.testing.expect(program.registry.findComponent("health") != null);
    const system = program.registry.findSystem("rotate_cubes") orelse return error.TestExpectedEqual;
    try std.testing.expect(system.runner.luau != 0);

    var world = runtime.World.init(std.testing.allocator);
    defer world.deinit();
    const entity = try world.createEntity("spinner", "Spinner");
    try world.setTransform(entity, .{});
    try world.setSpin(entity, .{ .angular_velocity = .{ 1.0, 0.0, 0.0 } });

    try std.testing.expect(program.update(&world, 0.5));
    const transform = (try world.getTransform(entity)) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(f32, 1.25), transform.rotation[0]);
}

test "luau world mutation requires declared system access" {
    var program = try loadSourceProgram(std.testing.allocator, "test.luau",
        \\ecs.component("health", {
        \\  fields = {
        \\    current = "f32",
        \\  },
        \\})
        \\
        \\ecs.system("bad_rotate", {
        \\  reads = { "machina.spin" },
        \\  writes = { "health" },
        \\  run = function(world, dt)
        \\    world.rotate("machina.transform", "machina.spin", dt)
        \\  end,
        \\})
    );
    defer program.deinit();

    var world = runtime.World.init(std.testing.allocator);
    defer world.deinit();
    const entity = try world.createEntity("spinner", "Spinner");
    try world.setTransform(entity, .{});
    try world.setSpin(entity, .{ .angular_velocity = .{ 1.0, 0.0, 0.0 } });

    try std.testing.expect(!program.update(&world, 1.0));
    const transform = (try world.getTransform(entity)) orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(f32, 0.0), transform.rotation[0]);
}

test "update schedule batches read-only systems and separates write conflicts" {
    var registry = runtime.ComponentRegistry.init(std.testing.allocator);
    defer registry.deinit();
    try registerEngineTypes(&registry);

    try registry.registerProjectComponent(.{ .id = "health" });
    try registry.registerProjectSystem(.{
        .id = "read_transform",
        .reads = &.{"machina.transform"},
    });
    try registry.registerProjectSystem(.{
        .id = "observe_health",
        .reads = &.{"health"},
    });
    try registry.registerProjectSystem(.{
        .id = "regen_health",
        .reads = &.{"machina.transform"},
        .writes = &.{"health"},
    });

    var schedule = try buildUpdateSchedule(std.testing.allocator, registry);
    defer schedule.deinit();

    try std.testing.expectEqual(@as(usize, 2), schedule.batchCount());
    try std.testing.expectEqual(@as(usize, 3), schedule.systemCount());
    try std.testing.expectEqual(@as(usize, 2), schedule.batches[0].systems.len);
    try std.testing.expectEqual(@as(usize, 1), schedule.batches[1].systems.len);
}
