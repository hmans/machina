const std = @import("std");
const Io = std.Io;
const machina = @import("machina");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), init.io, &stderr_buffer);
    const stderr = &stderr_file_writer.interface;

    const exit_code = try run(init.io, allocator, args, stdout, stderr);

    try stdout.flush();
    try stderr.flush();

    if (exit_code != 0) {
        std.process.exit(exit_code);
    }
}

fn run(
    io: Io,
    allocator: std.mem.Allocator,
    args: []const []const u8,
    stdout: *Io.Writer,
    stderr: *Io.Writer,
) !u8 {
    if (args.len <= 1) {
        try printHelp(stdout);
        return 0;
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "version")) {
        try stdout.print("machina {s}\n", .{machina.version});
        return 0;
    }

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "help")) {
        try printHelp(stdout);
        return 0;
    }

    if (std.mem.eql(u8, command, "init")) {
        const target_path = if (args.len >= 3) args[2] else ".";
        const name = projectNameFromPath(target_path);
        machina.initProject(io, allocator, target_path, name) catch |err| {
            try printProjectError(stderr, target_path, err);
            return 1;
        };
        try stdout.print("Initialized Machina project at {s}\n", .{target_path});
        return 0;
    }

    if (std.mem.eql(u8, command, "check")) {
        return try checkCommand(io, allocator, args[2..], stdout, stderr);
    }

    if (std.mem.eql(u8, command, "step")) {
        return try stepCommand(io, allocator, args[2..], stdout, stderr);
    }

    if (std.mem.eql(u8, command, "run")) {
        const target_path = if (args.len >= 3) args[2] else ".";
        var window_options = parseWindowOptions(args[3..]) catch |err| {
            try printArgumentError(stderr, err);
            return 1;
        };
        const result = try checkProjectForCommand(io, allocator, target_path, stderr) orelse return 1;
        defer machina.freeCheckResult(allocator, result);
        var live_project = machina.LiveProject.init(io, std.heap.smp_allocator, target_path) catch |err| {
            try printProjectError(stderr, target_path, err);
            return 1;
        };
        defer live_project.deinit();

        var reload_context = SceneReloadContext{
            .live_project = &live_project,
            .stderr = stderr,
            .target_path = target_path,
        };
        window_options.scene_reload = .{
            .context = &reload_context,
            .poll = pollSceneReload,
        };
        window_options.frame_update = .{
            .context = &reload_context,
            .step = stepLiveProject,
        };

        try stdout.print("Loaded project {s}\n", .{result.project.name});
        try stdout.print("Selected scene: {s}\n", .{result.project.default_scene});
        try stdout.print("Scene entities: {d}\n", .{live_project.scene.entityCount()});
        try stdout.print("Scripts: {d}, update batches: {d}\n", .{
            live_project.project.scripts.len,
            live_project.scripts.schedule.batchCount(),
        });

        machina.runDemoWindow(allocator, result.project.name, window_options, live_project.renderScene()) catch |err| {
            try stderr.print("run failed: {s}\n", .{@errorName(err)});
            return 1;
        };
        return 0;
    }

    if (std.mem.eql(u8, command, "render")) {
        const target_path = if (args.len >= 3) args[2] else ".";
        const output_path = if (args.len >= 4) args[3] else "zig-out/machina-cube.bmp";
        const result = try checkProjectForCommand(io, allocator, target_path, stderr) orelse return 1;
        defer machina.freeCheckResult(allocator, result);
        const scene = machina.loadDefaultScene(io, allocator, result.project) catch |err| {
            try printProjectError(stderr, target_path, err);
            return 1;
        };
        defer machina.freeScene(allocator, scene);

        machina.renderDemoBmp(io, allocator, output_path, scene.renderScene()) catch |err| {
            try stderr.print("render failed: {s}\n", .{@errorName(err)});
            return 1;
        };

        try stdout.print("Rendered cube: {s}\n", .{output_path});
        return 0;
    }

    if (std.mem.eql(u8, command, "render-test")) {
        const target_path = if (args.len >= 3) args[2] else ".";
        const output_path = if (args.len >= 4) args[3] else "zig-out/machina-render-test.bmp";
        const result = try checkProjectForCommand(io, allocator, target_path, stderr) orelse return 1;
        defer machina.freeCheckResult(allocator, result);
        const scene = machina.loadDefaultScene(io, allocator, result.project) catch |err| {
            try printProjectError(stderr, target_path, err);
            return 1;
        };
        defer machina.freeScene(allocator, scene);

        machina.renderDemoBmp(io, allocator, output_path, scene.renderScene()) catch |err| {
            try stderr.print("render-test render failed: {s}\n", .{@errorName(err)});
            return 1;
        };

        const verification = machina.verifyRenderBmp(io, allocator, output_path, .{
            .min_visible_components = 1,
            .min_color_groups = expectedColorGroups(scene),
        }) catch |err| {
            try stderr.print("render-test verification failed: {s}\n", .{@errorName(err)});
            return 1;
        };

        try stdout.print(
            "Render test OK: {d}x{d}, foreground pixels: {d}, visible components: {d}, color groups: {d}\n",
            .{
                verification.width,
                verification.height,
                verification.foreground_pixels,
                verification.visible_components,
                verification.color_groups,
            },
        );
        try stdout.print("Rendered artifact: {s}\n", .{output_path});
        return 0;
    }

    try stderr.print("Unknown command: {s}\n\n", .{command});
    try printHelp(stderr);
    return 1;
}

const CheckOutputFormat = enum {
    text,
    json,
};

const CheckOptions = struct {
    target_path: []const u8 = ".",
    format: CheckOutputFormat = .text,
};

const StepCommandOptions = struct {
    target_path: []const u8 = ".",
    frames: u32 = 1,
    delta_seconds: f32 = 1.0 / 60.0,
    format: CheckOutputFormat = .text,
};

fn checkCommand(
    io: Io,
    allocator: std.mem.Allocator,
    args: []const []const u8,
    stdout: *Io.Writer,
    stderr: *Io.Writer,
) !u8 {
    const options = parseCheckOptions(args) catch |err| {
        try printArgumentError(stderr, err);
        return 1;
    };

    var result = machina.checkProjectDetailed(io, allocator, options.target_path) catch |err| {
        switch (options.format) {
            .text => try printProjectError(stderr, options.target_path, err),
            .json => try printProjectErrorJson(stdout, options.target_path, err),
        }
        return 1;
    };

    switch (result) {
        .ok => |ok| {
            defer machina.freeCheckResult(allocator, ok);
            switch (options.format) {
                .text => {
                    try stdout.print("Project OK: {s}\n", .{ok.project.name});
                    try stdout.print("Default scene: {s}\n", .{ok.project.default_scene});
                    try stdout.print("Scripts: {d}\n", .{ok.project.scripts.len});
                    try stdout.print("Update batches: {d}, systems: {d}\n", .{
                        ok.schedule.batchCount(),
                        ok.schedule.systemCount(),
                    });
                },
                .json => try printCheckOkJson(stdout, ok),
            }
            return 0;
        },
        .invalid => |*diagnostic| {
            defer diagnostic.deinit(allocator);
            switch (options.format) {
                .text => try printScriptDiagnostic(stderr, options.target_path, diagnostic.*),
                .json => try printScriptDiagnosticJson(stdout, options.target_path, diagnostic.*),
            }
            return 1;
        },
    }
}

fn stepCommand(
    io: Io,
    allocator: std.mem.Allocator,
    args: []const []const u8,
    stdout: *Io.Writer,
    stderr: *Io.Writer,
) !u8 {
    const options = parseStepOptions(args) catch |err| {
        try printArgumentError(stderr, err);
        return 1;
    };

    const result = machina.stepProjectDetailed(io, allocator, options.target_path, .{
        .frames = options.frames,
        .delta_seconds = options.delta_seconds,
    }) catch |err| {
        switch (options.format) {
            .text => try printProjectError(stderr, options.target_path, err),
            .json => try printProjectErrorJson(stdout, options.target_path, err),
        }
        return 1;
    };
    defer machina.freeStepDetailedResult(allocator, result);

    switch (result) {
        .ok => |ok| {
            switch (options.format) {
                .text => try printStepOkText(stdout, ok),
                .json => try printStepOkJson(stdout, ok),
            }
            return 0;
        },
        .runtime_error => |failure| {
            switch (options.format) {
                .text => {
                    try printStepFailureText(stderr, options.target_path, failure);
                    try printScriptDiagnostic(stderr, options.target_path, failure.diagnostic);
                },
                .json => try printStepFailureJson(stdout, options.target_path, failure),
            }
            return 1;
        },
        .invalid => |diagnostic| {
            switch (options.format) {
                .text => try printScriptDiagnostic(stderr, options.target_path, diagnostic),
                .json => try printScriptDiagnosticJson(stdout, options.target_path, diagnostic),
            }
            return 1;
        },
    }
}

fn checkProjectForCommand(
    io: Io,
    allocator: std.mem.Allocator,
    target_path: []const u8,
    stderr: *Io.Writer,
) !?machina.CheckResult {
    var result = machina.checkProjectDetailed(io, allocator, target_path) catch |err| {
        try printProjectError(stderr, target_path, err);
        return null;
    };
    switch (result) {
        .ok => |ok| return ok,
        .invalid => |*diagnostic| {
            defer diagnostic.deinit(allocator);
            try printScriptDiagnostic(stderr, target_path, diagnostic.*);
            return null;
        },
    }
}

fn printHelp(writer: *Io.Writer) !void {
    try writer.writeAll(
        \\machina - agent-native game engine
        \\
        \\Usage:
        \\  machina --version
        \\  machina help
        \\  machina init [path]
        \\  machina check [path] [--format text|json]
        \\  machina step [path] [--frames N] [--dt seconds] [--format text|json]
        \\  machina run [path] [--frames N]
        \\  machina render [path] [output.bmp]
        \\  machina render-test [path] [output.bmp]
        \\
    );
}

const ArgumentError = error{
    InvalidDelta,
    InvalidFrames,
    InvalidFormat,
    UnknownArgument,
};

const SceneReloadContext = struct {
    live_project: *machina.LiveProject,
    stderr: *Io.Writer,
    target_path: []const u8,
};

fn pollSceneReload(raw_context: *anyopaque) ?machina.RenderScene {
    const context: *SceneReloadContext = @ptrCast(@alignCast(raw_context));
    const result = context.live_project.pollLoadedSources() catch |err| {
        printProjectError(context.stderr, context.target_path, err) catch {};
        if (context.live_project.lastDiagnostic()) |diagnostic| {
            printScriptDiagnostic(context.stderr, context.target_path, diagnostic.*) catch {};
        }
        context.stderr.flush() catch {};
        return null;
    };

    switch (result) {
        .unchanged => return null,
        .reloaded => |info| {
            context.stderr.print(
                "Reloaded {s}{s}{s}: {s}, {d} entities, {d} renderable cubes, {d} scripts, {d} update batches\n",
                .{
                    if (info.project_reloaded) "project" else "",
                    if (info.scene_reloaded) if (info.project_reloaded) " and scene" else "scene" else "",
                    if (info.scripts_reloaded) if (info.project_reloaded or info.scene_reloaded) " and scripts" else "scripts" else "",
                    info.scene_path,
                    info.entity_count,
                    info.renderable_cube_count,
                    info.script_count,
                    info.system_batch_count,
                },
            ) catch {};
            context.stderr.flush() catch {};
            return context.live_project.renderScene();
        },
    }
}

fn stepLiveProject(raw_context: *anyopaque, delta_seconds: f32) void {
    const context: *SceneReloadContext = @ptrCast(@alignCast(raw_context));
    context.live_project.update(delta_seconds);
    if (context.live_project.lastDiagnostic()) |diagnostic| {
        printScriptDiagnostic(context.stderr, context.target_path, diagnostic.*) catch {};
        context.stderr.flush() catch {};
    }
}

fn parseWindowOptions(args: []const []const u8) ArgumentError!machina.WindowOptions {
    var options = machina.WindowOptions{};
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--frames")) {
            index += 1;
            if (index >= args.len) {
                return ArgumentError.InvalidFrames;
            }
            options.max_frames = std.fmt.parseInt(u32, args[index], 10) catch return ArgumentError.InvalidFrames;
            if (options.max_frames.? == 0) {
                return ArgumentError.InvalidFrames;
            }
            continue;
        }

        return ArgumentError.UnknownArgument;
    }

    return options;
}

fn parseCheckOptions(args: []const []const u8) ArgumentError!CheckOptions {
    var options = CheckOptions{};
    var saw_path = false;
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--format")) {
            index += 1;
            if (index >= args.len) {
                return ArgumentError.InvalidFormat;
            }
            options.format = try parseCheckOutputFormat(args[index]);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--format=")) {
            options.format = try parseCheckOutputFormat(arg["--format=".len..]);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--")) {
            return ArgumentError.UnknownArgument;
        }
        if (saw_path) {
            return ArgumentError.UnknownArgument;
        }
        options.target_path = arg;
        saw_path = true;
    }
    return options;
}

fn parseStepOptions(args: []const []const u8) ArgumentError!StepCommandOptions {
    var options = StepCommandOptions{};
    var saw_path = false;
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--frames")) {
            index += 1;
            if (index >= args.len) {
                return ArgumentError.InvalidFrames;
            }
            options.frames = try parseFrameCount(args[index]);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--frames=")) {
            options.frames = try parseFrameCount(arg["--frames=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--dt")) {
            index += 1;
            if (index >= args.len) {
                return ArgumentError.InvalidDelta;
            }
            options.delta_seconds = try parseDeltaSeconds(args[index]);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--dt=")) {
            options.delta_seconds = try parseDeltaSeconds(arg["--dt=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--format")) {
            index += 1;
            if (index >= args.len) {
                return ArgumentError.InvalidFormat;
            }
            options.format = try parseCheckOutputFormat(args[index]);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--format=")) {
            options.format = try parseCheckOutputFormat(arg["--format=".len..]);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--")) {
            return ArgumentError.UnknownArgument;
        }
        if (saw_path) {
            return ArgumentError.UnknownArgument;
        }
        options.target_path = arg;
        saw_path = true;
    }
    return options;
}

fn parseFrameCount(value: []const u8) ArgumentError!u32 {
    const frames = std.fmt.parseInt(u32, value, 10) catch return ArgumentError.InvalidFrames;
    if (frames == 0) {
        return ArgumentError.InvalidFrames;
    }
    return frames;
}

fn parseDeltaSeconds(value: []const u8) ArgumentError!f32 {
    const delta_seconds = std.fmt.parseFloat(f32, value) catch return ArgumentError.InvalidDelta;
    if (!std.math.isFinite(delta_seconds) or delta_seconds <= 0.0) {
        return ArgumentError.InvalidDelta;
    }
    return delta_seconds;
}

fn parseCheckOutputFormat(value: []const u8) ArgumentError!CheckOutputFormat {
    if (std.mem.eql(u8, value, "text")) {
        return .text;
    }
    if (std.mem.eql(u8, value, "json")) {
        return .json;
    }
    return ArgumentError.InvalidFormat;
}

fn printArgumentError(writer: *Io.Writer, err: ArgumentError) !void {
    const message = switch (err) {
        ArgumentError.InvalidDelta => "--dt expects a positive finite number",
        ArgumentError.InvalidFrames => "--frames expects a positive integer",
        ArgumentError.InvalidFormat => "--format expects text or json",
        ArgumentError.UnknownArgument => "unknown argument",
    };
    try writer.print("{s}\n", .{message});
}

fn expectedColorGroups(scene: machina.Scene) usize {
    var has_warm = false;
    var has_cool = false;
    var cubes = scene.world.renderableCubes();
    while (cubes.next()) |cube| {
        if (cube.color[0] > cube.color[2] + 0.1) {
            has_warm = true;
        }
        if (cube.color[2] > cube.color[0] + 0.1) {
            has_cool = true;
        }
    }
    const groups = @as(usize, @intFromBool(has_warm)) + @as(usize, @intFromBool(has_cool));
    return @max(groups, 1);
}

fn printProjectError(writer: *Io.Writer, root_path: []const u8, err: anyerror) !void {
    try writer.print("{s}: {s}\n", .{ root_path, projectErrorMessage(err) });
}

fn projectErrorMessage(err: anyerror) []const u8 {
    return switch (err) {
        machina.ProjectError.AlreadyExists => "project already exists",
        machina.ProjectError.InvalidProject => "not a valid Machina project",
        machina.ProjectError.MissingProjectFile => "missing project.machina.toml",
        machina.ProjectError.MissingDefaultScene => "missing default scene",
        machina.ProjectError.UnsupportedProjectVersion => "unsupported project version",
        machina.ProjectError.InvalidProjectName => "invalid project name",
        machina.ProjectError.InvalidDefaultScene => "invalid default scene",
        machina.ProjectError.InvalidSceneEntity => "invalid scene entity",
        machina.ProjectError.DuplicateSceneEntityId => "duplicate scene entity id",
        machina.ProjectError.InvalidSceneNumber => "invalid scene number",
        machina.ProjectError.MissingSceneContent => "missing scene content",
        machina.ProjectError.MissingScript => "missing script",
        machina.ProjectError.InvalidScript => "invalid script",
        else => "unexpected project error",
    };
}

fn printScriptDiagnostic(writer: *Io.Writer, root_path: []const u8, diagnostic: machina.ScriptDiagnostic) !void {
    try writer.print("{s}: {s}", .{ root_path, diagnostic.stage.label() });
    if (diagnostic.path) |path| {
        try writer.print(" in {s}", .{path});
    }
    if (diagnostic.system_id) |system_id| {
        try writer.print(" system {s}", .{system_id});
    }
    if (diagnostic.start) |start| {
        try writer.print(":{d}", .{start.line});
        if (start.column) |column| {
            try writer.print(":{d}", .{column});
        }
    }
    try writer.print(": {s}\n", .{diagnostic.message});
}

fn printStepOkText(writer: *Io.Writer, ok: machina.StepOk) !void {
    try writer.print("Step OK: {s}\n", .{ok.project.name});
    try writer.print("Scene: {s}\n", .{ok.scene.name});
    try writer.print("Frames: {d}/{d}, dt: {d}\n", .{
        ok.summary.completed_frames,
        ok.summary.frames,
        ok.summary.delta_seconds,
    });
    try writer.print("Entities: {d}, components: {d}, renderable cubes: {d}\n", .{
        ok.scene.entityCount(),
        ok.scene.componentInstanceCount(),
        ok.scene.renderableCubeCount(),
    });
    try writer.print("Update batches: {d}, systems: {d}\n", .{
        ok.schedule.batchCount(),
        ok.schedule.systemCount(),
    });
}

fn printStepFailureText(writer: *Io.Writer, root_path: []const u8, failure: machina.StepRuntimeError) !void {
    try writer.print("{s}: step failed after {d}/{d} frames, dt: {d}\n", .{
        root_path,
        failure.summary.completed_frames,
        failure.summary.frames,
        failure.summary.delta_seconds,
    });
}

fn printCheckOkJson(writer: *Io.Writer, result: machina.CheckResult) !void {
    try writer.writeAll("{\"ok\":true,\"project\":");
    try printProjectSummaryJson(writer, result.project);
    try writer.writeAll(",\"schedule\":");
    try printCheckScheduleJson(writer, result.schedule);
    try writer.writeAll("}\n");
}

fn printStepOkJson(writer: *Io.Writer, ok: machina.StepOk) !void {
    try writer.writeAll("{\"ok\":true,\"project\":");
    try printProjectSummaryJson(writer, ok.project);
    try writer.writeAll(",\"scene\":");
    try printSceneSummaryJson(writer, ok.scene);
    try writer.writeAll(",\"simulation\":");
    try printStepSummaryJson(writer, ok.summary);
    try writer.writeAll(",\"schedule\":");
    try printCheckScheduleJson(writer, ok.schedule);
    try writer.writeAll("}\n");
}

fn printStepFailureJson(writer: *Io.Writer, root_path: []const u8, failure: machina.StepRuntimeError) !void {
    try writer.writeAll("{\"ok\":false,\"project\":");
    try printProjectSummaryJson(writer, failure.project);
    try writer.writeAll(",\"scene\":");
    try printSceneSummaryJson(writer, failure.scene);
    try writer.writeAll(",\"simulation\":");
    try printStepSummaryJson(writer, failure.summary);
    try writer.writeAll(",\"schedule\":");
    try printCheckScheduleJson(writer, failure.schedule);
    try writer.writeAll(",\"diagnostic\":");
    try printScriptDiagnosticObjectJson(writer, root_path, failure.diagnostic);
    try writer.writeAll("}\n");
}

fn printProjectSummaryJson(writer: *Io.Writer, project: machina.Project) !void {
    try writer.writeAll("{\"name\":");
    try writeJsonString(writer, project.name);
    try writer.writeAll(",\"default_scene\":");
    try writeJsonString(writer, project.default_scene);
    try writer.print(",\"scripts\":{d}", .{project.scripts.len});
    try writer.writeAll("}");
}

fn printSceneSummaryJson(writer: *Io.Writer, scene: machina.Scene) !void {
    try writer.writeAll("{\"name\":");
    try writeJsonString(writer, scene.name);
    try writer.print(",\"entities\":{d},\"component_instances\":{d},\"renderable_cubes\":{d}}}", .{
        scene.entityCount(),
        scene.componentInstanceCount(),
        scene.renderableCubeCount(),
    });
}

fn printStepSummaryJson(writer: *Io.Writer, summary: machina.StepSummary) !void {
    try writer.print("{{\"frames\":{d},\"completed_frames\":{d},\"dt\":{d}}}", .{
        summary.frames,
        summary.completed_frames,
        summary.delta_seconds,
    });
}

fn printCheckScheduleJson(writer: *Io.Writer, schedule: machina.CheckSchedule) !void {
    try writer.writeAll("{\"batches\":[");
    for (schedule.batches, 0..) |batch, batch_index| {
        if (batch_index != 0) {
            try writer.writeByte(',');
        }
        try writer.writeAll("{\"phase\":");
        try writeJsonString(writer, @tagName(batch.phase));
        try writer.writeAll(",\"systems\":[");
        for (batch.systems, 0..) |system, system_index| {
            if (system_index != 0) {
                try writer.writeByte(',');
            }
            try printCheckSystemJson(writer, system);
        }
        try writer.writeAll("]}");
    }
    try writer.writeAll("]}");
}

fn printCheckSystemJson(writer: *Io.Writer, system: machina.CheckSystemSummary) !void {
    try writer.writeAll("{\"id\":");
    try writeJsonString(writer, system.id);
    try writer.writeAll(",\"phase\":");
    try writeJsonString(writer, @tagName(system.phase));
    try writer.writeAll(",\"runner\":");
    try writeJsonString(writer, @tagName(system.runner));
    try writer.writeAll(",\"reads\":");
    try writeJsonStringList(writer, system.reads);
    try writer.writeAll(",\"writes\":");
    try writeJsonStringList(writer, system.writes);
    try writer.writeAll(",\"before\":");
    try writeJsonStringList(writer, system.before);
    try writer.writeAll(",\"after\":");
    try writeJsonStringList(writer, system.after);
    try writer.writeAll("}");
}

fn writeJsonStringList(writer: *Io.Writer, values: []const []const u8) !void {
    try writer.writeByte('[');
    for (values, 0..) |value, index| {
        if (index != 0) {
            try writer.writeByte(',');
        }
        try writeJsonString(writer, value);
    }
    try writer.writeByte(']');
}

fn printProjectErrorJson(writer: *Io.Writer, root_path: []const u8, err: anyerror) !void {
    try writer.writeAll("{\"ok\":false,\"error\":");
    try writeJsonString(writer, @errorName(err));
    try writer.writeAll(",\"root\":");
    try writeJsonString(writer, root_path);
    try writer.writeAll(",\"message\":");
    try writeJsonString(writer, projectErrorMessage(err));
    try writer.writeAll("}\n");
}

fn printScriptDiagnosticJson(writer: *Io.Writer, root_path: []const u8, diagnostic: machina.ScriptDiagnostic) !void {
    try writer.writeAll("{\"ok\":false,\"diagnostic\":");
    try printScriptDiagnosticObjectJson(writer, root_path, diagnostic);
    try writer.writeAll("}\n");
}

fn printScriptDiagnosticObjectJson(writer: *Io.Writer, root_path: []const u8, diagnostic: machina.ScriptDiagnostic) !void {
    try writer.writeAll("{");
    try writer.writeAll("\"stage\":");
    try writeJsonString(writer, @tagName(diagnostic.stage));
    try writer.writeAll(",\"root\":");
    try writeJsonString(writer, root_path);
    if (diagnostic.path) |path| {
        try writer.writeAll(",\"path\":");
        try writeJsonString(writer, path);
    }
    if (diagnostic.system_id) |system_id| {
        try writer.writeAll(",\"system_id\":");
        try writeJsonString(writer, system_id);
    }
    if (diagnostic.start) |start| {
        try writer.writeAll(",\"start\":");
        try printDiagnosticPositionJson(writer, start);
    }
    if (diagnostic.end) |end| {
        try writer.writeAll(",\"end\":");
        try printDiagnosticPositionJson(writer, end);
    }
    try writer.writeAll(",\"message\":");
    try writeJsonString(writer, diagnostic.message);
    try writer.writeAll("}");
}

fn printDiagnosticPositionJson(writer: *Io.Writer, position: machina.ScriptDiagnosticPosition) !void {
    try writer.print("{{\"line\":{d}", .{position.line});
    if (position.column) |column| {
        try writer.print(",\"column\":{d}", .{column});
    }
    try writer.writeAll("}");
}

fn writeJsonString(writer: *Io.Writer, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (byte < 0x20) {
                    try writer.print("\\u{x:0>4}", .{byte});
                } else {
                    try writer.writeByte(byte);
                }
            },
        }
    }
    try writer.writeByte('"');
}

fn projectNameFromPath(path: []const u8) []const u8 {
    const trimmed = trimTrailingSlashes(path);
    if (trimmed.len == 0 or std.mem.eql(u8, trimmed, ".")) {
        return "Machina Project";
    }
    return std.fs.path.basename(trimmed);
}

fn trimTrailingSlashes(path: []const u8) []const u8 {
    var end = path.len;
    while (end > 0 and path[end - 1] == '/') {
        end -= 1;
    }
    return path[0..end];
}

test "projectNameFromPath uses final path segment" {
    try std.testing.expectEqualStrings("demo", projectNameFromPath("games/demo"));
    try std.testing.expectEqualStrings("demo", projectNameFromPath("games/demo/"));
    try std.testing.expectEqualStrings("Machina Project", projectNameFromPath("."));
}

test "parseCheckOptions accepts path and json format" {
    const args = [_][]const u8{ "examples/minimal", "--format=json" };
    const options = try parseCheckOptions(&args);
    try std.testing.expectEqualStrings("examples/minimal", options.target_path);
    try std.testing.expectEqual(CheckOutputFormat.json, options.format);
}

test "parseCheckOptions accepts format before path" {
    const args = [_][]const u8{ "--format", "json", "examples/minimal" };
    const options = try parseCheckOptions(&args);
    try std.testing.expectEqualStrings("examples/minimal", options.target_path);
    try std.testing.expectEqual(CheckOutputFormat.json, options.format);
}

test "parseCheckOptions rejects unknown format" {
    const args = [_][]const u8{"--format=yaml"};
    try std.testing.expectError(ArgumentError.InvalidFormat, parseCheckOptions(&args));
}

test "parseStepOptions accepts path frames dt and json format" {
    const args = [_][]const u8{ "examples/minimal", "--frames=60", "--dt", "0.016", "--format=json" };
    const options = try parseStepOptions(&args);
    try std.testing.expectEqualStrings("examples/minimal", options.target_path);
    try std.testing.expectEqual(@as(u32, 60), options.frames);
    try std.testing.expectApproxEqAbs(@as(f32, 0.016), options.delta_seconds, 0.000001);
    try std.testing.expectEqual(CheckOutputFormat.json, options.format);
}

test "parseStepOptions rejects invalid dt" {
    const args = [_][]const u8{ "--dt", "inf" };
    try std.testing.expectError(ArgumentError.InvalidDelta, parseStepOptions(&args));
}

test "printCheckOkJson includes schedule summary" {
    var buffer: [1024]u8 = undefined;
    var writer = Io.Writer.fixed(&buffer);

    const scripts = [_][]const u8{"scripts/gameplay.luau"};
    const reads = [_][]const u8{"spin"};
    const writes = [_][]const u8{"machina.transform"};
    const system = machina.CheckSystemSummary{
        .id = "autorotate",
        .phase = .update,
        .runner = .luau,
        .reads = &reads,
        .writes = &writes,
    };
    const systems = [_]machina.CheckSystemSummary{system};
    const batch = machina.CheckScheduleBatch{
        .phase = .update,
        .systems = &systems,
    };
    const batches = [_]machina.CheckScheduleBatch{batch};
    const result = machina.CheckResult{
        .project = .{
            .root_path = "examples/minimal",
            .name = "Minimal",
            .default_scene = "scenes/main.scene.toml",
            .scripts = &scripts,
        },
        .schedule = .{ .batches = &batches },
    };

    try printCheckOkJson(&writer, result);

    try std.testing.expectEqualStrings(
        "{\"ok\":true,\"project\":{\"name\":\"Minimal\",\"default_scene\":\"scenes/main.scene.toml\",\"scripts\":1},\"schedule\":{\"batches\":[{\"phase\":\"update\",\"systems\":[{\"id\":\"autorotate\",\"phase\":\"update\",\"runner\":\"luau\",\"reads\":[\"spin\"],\"writes\":[\"machina.transform\"],\"before\":[],\"after\":[]}]}]}}\n",
        writer.buffered(),
    );
}

test "printStepOkJson includes simulation and scene summary" {
    var output_buffer: [1536]u8 = undefined;
    var writer = Io.Writer.fixed(&output_buffer);

    var scene = machina.Scene{
        .name = "Main",
        .world = machina.World.init(std.testing.allocator),
    };
    defer scene.world.deinit();
    const entity = try scene.world.createEntity("entity-1", "Entity");
    try scene.world.setTransform(entity, .{});
    try scene.world.setSpin(entity, .{ .angular_velocity = .{ 1.0, 0.0, 0.0 } });

    const scripts = [_][]const u8{"scripts/gameplay.luau"};
    const reads = [_][]const u8{"spin"};
    const writes = [_][]const u8{"machina.transform"};
    const system = machina.CheckSystemSummary{
        .id = "autorotate",
        .phase = .update,
        .runner = .luau,
        .reads = &reads,
        .writes = &writes,
    };
    const systems = [_]machina.CheckSystemSummary{system};
    const batch = machina.CheckScheduleBatch{
        .phase = .update,
        .systems = &systems,
    };
    const batches = [_]machina.CheckScheduleBatch{batch};
    const ok = machina.StepOk{
        .project = .{
            .root_path = "examples/minimal",
            .name = "Minimal",
            .default_scene = "scenes/main.scene.toml",
            .scripts = &scripts,
        },
        .scene = scene,
        .schedule = .{ .batches = &batches },
        .summary = .{
            .frames = 2,
            .completed_frames = 2,
            .delta_seconds = 0.5,
        },
    };

    try printStepOkJson(&writer, ok);

    try std.testing.expectEqualStrings(
        "{\"ok\":true,\"project\":{\"name\":\"Minimal\",\"default_scene\":\"scenes/main.scene.toml\",\"scripts\":1},\"scene\":{\"name\":\"Main\",\"entities\":1,\"component_instances\":2,\"renderable_cubes\":0},\"simulation\":{\"frames\":2,\"completed_frames\":2,\"dt\":0.5},\"schedule\":{\"batches\":[{\"phase\":\"update\",\"systems\":[{\"id\":\"autorotate\",\"phase\":\"update\",\"runner\":\"luau\",\"reads\":[\"spin\"],\"writes\":[\"machina.transform\"],\"before\":[],\"after\":[]}]}]}}\n",
        writer.buffered(),
    );
}
