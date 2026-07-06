const std = @import("std");
const builtin = @import("builtin");
const native = @import("../native.zig");

const Io = std.Io;

pub const default_output_dir_name = "build";
pub const bundle_marker = ".scrapbot-build-bundle";
pub const project_dir = "project";
pub const bin_dir = "bin";
pub const lib_dir = "lib";
pub const manifest_path = "scrapbot-build.json";
pub const native_artifact_dir = ".scrapbot/build/native";
pub const web_manifest_path = "scrapbot-web.json";
pub const web_player_script_path = "player.js";
pub const web_entrypoint_path = "index.html";
pub const web_wasm_path = "scrapbot-web-player.wasm";
pub const web_project_data_path = "project-data.json";

pub fn defaultBuildBundleName(allocator: std.mem.Allocator, project_name: []const u8) ![]u8 {
    const sanitized = try sanitizeBundleSegment(allocator, project_name);
    defer allocator.free(sanitized);
    return std.fmt.allocPrint(allocator, "{s}-{s}", .{ sanitized, hostTriple() });
}

pub fn defaultWebBuildBundleName(allocator: std.mem.Allocator, project_name: []const u8) ![]u8 {
    const sanitized = try sanitizeBundleSegment(allocator, project_name);
    defer allocator.free(sanitized);
    return std.fmt.allocPrint(allocator, "{s}-web", .{sanitized});
}

pub fn buildNativeArtifactProjectPath(allocator: std.mem.Allocator) ![]u8 {
    return std.mem.join(allocator, "/", &.{ native_artifact_dir, native.dynamicLibraryFileName() });
}

fn sanitizeBundleSegment(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var last_dash = false;
    for (value) |byte| {
        const next = if (std.ascii.isAlphanumeric(byte))
            std.ascii.toLower(byte)
        else if (byte == '.' or byte == '_')
            byte
        else
            '-';
        if (next == '-') {
            if (last_dash) {
                continue;
            }
            last_dash = true;
        } else {
            last_dash = false;
        }
        try out.append(allocator, next);
    }

    while (out.items.len > 0 and out.items[out.items.len - 1] == '-') {
        _ = out.pop();
    }
    while (out.items.len > 0 and out.items[0] == '-') {
        _ = out.orderedRemove(0);
    }
    if (out.items.len == 0) {
        try out.appendSlice(allocator, "scrapbot-project");
    }
    return out.toOwnedSlice(allocator);
}

fn hostTriple() []const u8 {
    return switch (builtin.os.tag) {
        .windows => switch (builtin.abi) {
            .msvc => switch (builtin.cpu.arch) {
                .x86_64 => "x86_64-windows-msvc",
                .aarch64 => "aarch64-windows-msvc",
                else => "windows-msvc",
            },
            else => switch (builtin.cpu.arch) {
                .x86_64 => "x86_64-windows-gnu",
                else => "windows",
            },
        },
        else => switch (builtin.cpu.arch) {
            .aarch64 => switch (builtin.os.tag) {
                .macos => "aarch64-macos",
                .linux => "aarch64-linux",
                else => "aarch64",
            },
            .x86_64 => switch (builtin.os.tag) {
                .macos => "x86_64-macos",
                .linux => "x86_64-linux",
                else => "x86_64",
            },
            else => @tagName(builtin.os.tag),
        },
    };
}

pub fn isSafeBundleName(name: []const u8) bool {
    if (name.len == 0 or std.fs.path.isAbsolute(name) or std.mem.indexOfScalar(u8, name, '/') != null or std.mem.indexOfScalar(u8, name, '\\') != null) {
        return false;
    }
    return !std.mem.eql(u8, name, ".") and !std.mem.eql(u8, name, "..");
}

pub fn isScrapbotBuildBundle(io: Io, cwd: Io.Dir, bundle_path: []const u8) bool {
    const marker_path = std.fs.path.join(std.heap.smp_allocator, &.{ bundle_path, bundle_marker }) catch return false;
    defer std.heap.smp_allocator.free(marker_path);
    return fileExists(io, cwd, marker_path);
}

pub fn absoluteCwdPath(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    if (std.fs.path.isAbsolute(path)) {
        return std.fs.path.resolve(allocator, &.{path});
    }
    const cwd_path = try std.process.currentPathAlloc(io, allocator);
    defer allocator.free(cwd_path);
    return std.fs.path.resolve(allocator, &.{ cwd_path, path });
}

pub fn outputRootEntryToSkip(
    allocator: std.mem.Allocator,
    io: Io,
    project_root_path: []const u8,
    output_root: []const u8,
    bundle_path: []const u8,
) !?[]u8 {
    const project_abs = try absoluteCwdPath(allocator, io, project_root_path);
    defer allocator.free(project_abs);
    const output_abs = try absoluteCwdPath(allocator, io, output_root);
    defer allocator.free(output_abs);
    const bundle_abs = try absoluteCwdPath(allocator, io, bundle_path);
    defer allocator.free(bundle_abs);

    const project_clean = trimTrailingPathSeparators(project_abs);
    const output_clean = trimTrailingPathSeparators(output_abs);
    const bundle_clean = trimTrailingPathSeparators(bundle_abs);

    if (!pathIsInside(bundle_clean, project_clean)) {
        return null;
    }

    if (pathsEqual(output_clean, project_clean)) {
        const bundle_inside_project = bundle_clean[project_clean.len + 1 ..];
        const first_separator = std.mem.indexOfAny(u8, bundle_inside_project, "/\\") orelse bundle_inside_project.len;
        if (first_separator == 0) {
            return null;
        }
        return try allocator.dupe(u8, bundle_inside_project[0..first_separator]);
    }

    if (!pathIsInside(output_clean, project_clean)) {
        return null;
    }

    const inside_project = output_clean[project_clean.len + 1 ..];
    const first_separator = std.mem.indexOfAny(u8, inside_project, "/\\") orelse inside_project.len;
    if (first_separator == 0) {
        return null;
    }
    if (first_separator != inside_project.len) {
        return error.InvalidBuildOutput;
    }
    return try allocator.dupe(u8, inside_project[0..first_separator]);
}

fn pathsEqual(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn pathIsInside(path: []const u8, parent: []const u8) bool {
    return path.len > parent.len and
        std.mem.startsWith(u8, path, parent) and
        isPathSeparator(path[parent.len]);
}

fn trimTrailingPathSeparators(path: []const u8) []const u8 {
    var end = path.len;
    while (end > 1 and isPathSeparator(path[end - 1])) {
        end -= 1;
    }
    return path[0..end];
}

fn isPathSeparator(byte: u8) bool {
    return byte == '/' or byte == '\\';
}

pub fn copyProjectTree(io: Io, allocator: std.mem.Allocator, source_root_path: []const u8, dest_root_path: []const u8, skip_root_entry: ?[]const u8) !void {
    const cwd = Io.Dir.cwd();
    const source_root = try cwd.openDir(io, source_root_path, .{ .iterate = true });
    defer source_root.close(io);
    try cwd.createDirPath(io, dest_root_path);
    const dest_root = try cwd.openDir(io, dest_root_path, .{});
    defer dest_root.close(io);
    try copyProjectDirContents(io, allocator, source_root, dest_root, skip_root_entry, true);
}

fn copyProjectDirContents(
    io: Io,
    allocator: std.mem.Allocator,
    source_dir: Io.Dir,
    dest_dir: Io.Dir,
    skip_root_entry: ?[]const u8,
    root_level: bool,
) !void {
    var iterator = source_dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (root_level and shouldSkipProjectRootEntry(entry.name, skip_root_entry)) {
            continue;
        }
        switch (entry.kind) {
            .directory => {
                try dest_dir.createDirPath(io, entry.name);
                const child_source = try source_dir.openDir(io, entry.name, .{ .iterate = true });
                defer child_source.close(io);
                const child_dest = try dest_dir.openDir(io, entry.name, .{});
                defer child_dest.close(io);
                try copyProjectDirContents(io, allocator, child_source, child_dest, skip_root_entry, false);
            },
            .file => try source_dir.copyFile(entry.name, dest_dir, entry.name, io, .{ .replace = true }),
            else => {},
        }
    }
}

fn shouldSkipProjectRootEntry(name: []const u8, skip_root_entry: ?[]const u8) bool {
    if (skip_root_entry) |entry| {
        if (std.mem.eql(u8, name, entry)) {
            return true;
        }
    }
    return std.mem.eql(u8, name, ".scrapbot") or
        std.mem.eql(u8, name, ".git") or
        std.mem.eql(u8, name, ".zig-cache") or
        std.mem.eql(u8, name, "zig-cache") or
        std.mem.eql(u8, name, "zig-out");
}

pub fn copyPackagedNativeArtifact(
    io: Io,
    allocator: std.mem.Allocator,
    cwd: Io.Dir,
    project_root_path: []const u8,
    project_bundle_path: []const u8,
    artifact_path: []const u8,
) !void {
    const source_path = try std.fs.path.join(allocator, &.{ project_root_path, artifact_path });
    defer allocator.free(source_path);
    const dest_path = try std.fs.path.join(allocator, &.{ project_bundle_path, artifact_path });
    defer allocator.free(dest_path);

    if (std.fs.path.dirname(dest_path)) |dest_dir_path| {
        try cwd.createDirPath(io, dest_dir_path);
    }
    try cwd.copyFile(source_path, cwd, dest_path, io, .{ .make_path = true, .replace = true });
}

pub fn executableFileName() []const u8 {
    return switch (builtin.os.tag) {
        .windows => "scrapbot.exe",
        else => "scrapbot",
    };
}

pub fn launcherFileName() []const u8 {
    return switch (builtin.os.tag) {
        .windows => "run.cmd",
        else => "run",
    };
}

pub fn webPlayerWasmFileName() []const u8 {
    return web_wasm_path;
}

pub fn writeLauncher(io: Io, bundle_dir: Io.Dir, launcher_name: []const u8) !void {
    const contents = switch (builtin.os.tag) {
        .windows =>
        \\@echo off
        \\set "SCRIPT_DIR=%~dp0"
        \\set "PATH=%SCRIPT_DIR%lib;%SCRIPT_DIR%bin;%PATH%"
        \\"%SCRIPT_DIR%bin\scrapbot.exe" run "%SCRIPT_DIR%project" %*
        \\
        ,
        .macos =>
        \\#!/bin/sh
        \\set -eu
        \\DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
        \\export DYLD_LIBRARY_PATH="$DIR/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
        \\exec "$DIR/bin/scrapbot" run "$DIR/project" "$@"
        \\
        ,
        .linux =>
        \\#!/bin/sh
        \\set -eu
        \\DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
        \\export LD_LIBRARY_PATH="$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        \\exec "$DIR/bin/scrapbot" run "$DIR/project" "$@"
        \\
        ,
        else =>
        \\#!/bin/sh
        \\set -eu
        \\DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
        \\exec "$DIR/bin/scrapbot" run "$DIR/project" "$@"
        \\
        ,
    };
    const flags: Io.Dir.CreateFileOptions = switch (builtin.os.tag) {
        .windows => .{},
        else => .{ .permissions = .fromMode(0o755) },
    };
    try bundle_dir.writeFile(io, .{
        .sub_path = launcher_name,
        .data = contents,
        .flags = flags,
    });
}

pub fn copyDiscoverableSdl3(io: Io, cwd: Io.Dir, bundle_dir: Io.Dir) !bool {
    var copied = false;
    for (sdl3CandidatePaths()) |candidate| {
        if (std.fs.path.basename(candidate).len == 0) {
            continue;
        }
        if (!fileExists(io, cwd, candidate)) {
            continue;
        }
        const dest_path = try std.fs.path.join(std.heap.smp_allocator, &.{ lib_dir, std.fs.path.basename(candidate) });
        defer std.heap.smp_allocator.free(dest_path);
        try cwd.copyFile(candidate, bundle_dir, dest_path, io, .{ .make_path = true, .replace = true });
        copied = true;
    }
    return copied;
}

fn sdl3CandidatePaths() []const []const u8 {
    return switch (builtin.os.tag) {
        .macos => &.{
            "/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib",
            "/opt/homebrew/opt/sdl3/lib/libSDL3.dylib",
            "/opt/homebrew/lib/libSDL3.0.dylib",
            "/opt/homebrew/lib/libSDL3.dylib",
            "/usr/local/opt/sdl3/lib/libSDL3.0.dylib",
            "/usr/local/opt/sdl3/lib/libSDL3.dylib",
            "/usr/local/lib/libSDL3.0.dylib",
            "/usr/local/lib/libSDL3.dylib",
        },
        .linux => &.{
            "/usr/lib/libSDL3.so.0",
            "/usr/lib/libSDL3.so",
            "/usr/lib/x86_64-linux-gnu/libSDL3.so.0",
            "/usr/lib/x86_64-linux-gnu/libSDL3.so",
            "/usr/lib/aarch64-linux-gnu/libSDL3.so.0",
            "/usr/lib/aarch64-linux-gnu/libSDL3.so",
        },
        .windows => &.{
            "SDL3.dll",
        },
        else => &.{},
    };
}

pub const BuildManifestInput = struct {
    project_name: []const u8,
    bundle_path: []const u8,
    runtime_path: []const u8,
    project_path: []const u8,
    native_artifact: ?[]const u8,
    sdl3_bundled: bool,
    sdl3_warning: ?[]const u8,
};

pub fn writeBuildManifest(io: Io, allocator: std.mem.Allocator, bundle_dir: Io.Dir, input: BuildManifestInput) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    try out.appendSlice(allocator, "{\n");
    try out.appendSlice(allocator, "  \"schema\": \"scrapbot.build.v1\",\n");
    try out.appendSlice(allocator, "  \"target\": \"host\",\n");
    try out.appendSlice(allocator, "  \"project\": ");
    try appendJsonString(allocator, &out, input.project_name);
    try out.appendSlice(allocator, ",\n  \"host\": ");
    try appendJsonString(allocator, &out, hostTriple());
    try out.appendSlice(allocator, ",\n  \"bundle_path\": ");
    try appendJsonString(allocator, &out, input.bundle_path);
    try out.appendSlice(allocator, ",\n  \"runtime_path\": ");
    try appendJsonString(allocator, &out, input.runtime_path);
    try out.appendSlice(allocator, ",\n  \"project_path\": ");
    try appendJsonString(allocator, &out, input.project_path);
    try out.appendSlice(allocator, ",\n  \"native_artifact\": ");
    if (input.native_artifact) |path| {
        try appendJsonString(allocator, &out, path);
    } else {
        try out.appendSlice(allocator, "null");
    }
    try out.print(allocator, ",\n  \"sdl3_bundled\": {},\n  \"sdl3_warning\": ", .{input.sdl3_bundled});
    if (input.sdl3_warning) |message| {
        try appendJsonString(allocator, &out, message);
    } else {
        try out.appendSlice(allocator, "null");
    }
    try out.appendSlice(allocator, "\n}\n");

    try bundle_dir.writeFile(io, .{
        .sub_path = manifest_path,
        .data = out.items,
    });
}

pub const WebManifestInput = struct {
    project_name: []const u8,
    default_scene: []const u8,
    scripts: []const []const u8,
    engine_version: []const u8,
};

pub fn writeWebManifest(io: Io, allocator: std.mem.Allocator, bundle_dir: Io.Dir, input: WebManifestInput) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    try out.appendSlice(allocator, "{\n");
    try out.appendSlice(allocator, "  \"schema\": \"scrapbot.web-build.v1\",\n");
    try out.appendSlice(allocator, "  \"target\": \"web\",\n");
    try out.appendSlice(allocator, "  \"render_backend\": \"web_poc\",\n");
    try out.appendSlice(allocator, "  \"backend_status\": \"canvas2d_preview\",\n");
    try out.appendSlice(allocator, "  \"wasm\": \"");
    try out.appendSlice(allocator, web_wasm_path);
    try out.appendSlice(allocator, "\",\n  \"project_data\": \"");
    try out.appendSlice(allocator, web_project_data_path);
    try out.appendSlice(allocator, "\",\n");
    try out.appendSlice(allocator, "  \"engine_version\": ");
    try appendJsonString(allocator, &out, input.engine_version);
    try out.appendSlice(allocator, ",\n  \"project\": ");
    try appendJsonString(allocator, &out, input.project_name);
    try out.appendSlice(allocator, ",\n  \"default_scene\": ");
    try appendJsonString(allocator, &out, input.default_scene);
    try out.appendSlice(allocator, ",\n  \"project_root\": \"project\",\n");
    try out.appendSlice(allocator, "  \"scripts\": [");
    for (input.scripts, 0..) |script_path, index| {
        if (index != 0) {
            try out.appendSlice(allocator, ", ");
        }
        try appendJsonString(allocator, &out, script_path);
    }
    try out.appendSlice(allocator, "],\n");
    try out.appendSlice(allocator, "  \"notes\": \"This web export runs the headless Scrapbot wasm runtime and draws a Canvas2D preview. Browser WebGPU rendering is not implemented yet.\"\n");
    try out.appendSlice(allocator, "}\n");

    try bundle_dir.writeFile(io, .{
        .sub_path = web_manifest_path,
        .data = out.items,
    });
}

pub fn writeWebEntrypoint(io: Io, bundle_dir: Io.Dir) !void {
    try bundle_dir.writeFile(io, .{ .sub_path = web_entrypoint_path, .data =
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\  <meta charset="utf-8">
        \\  <meta name="viewport" content="width=device-width, initial-scale=1">
        \\  <title>Scrapbot Web Player</title>
        \\  <style>
        \\    :root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #101418; color: #eef2f6; }
        \\    * { box-sizing: border-box; }
        \\    body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 24px; }
        \\    main { width: min(100%, 960px); display: grid; gap: 16px; }
        \\    canvas { width: 100%; aspect-ratio: 16 / 9; display: block; border: 1px solid #44515f; background: #151b22; }
        \\    h1 { margin: 0; font-size: 24px; line-height: 1.2; }
        \\    p { margin: 0; color: #b8c2cc; line-height: 1.5; }
        \\    dl { margin: 0; display: grid; grid-template-columns: max-content 1fr; gap: 8px 16px; color: #d7dee6; }
        \\    dt { color: #8fa0b2; }
        \\    dd { margin: 0; word-break: break-word; }
        \\  </style>
        \\</head>
        \\<body>
        \\  <main>
        \\    <canvas id="scrapbot-canvas" width="960" height="540" aria-label="Scrapbot web player viewport"></canvas>
        \\    <h1 id="project-name">Scrapbot Web Player</h1>
        \\    <p id="status">Loading packaged project manifest...</p>
        \\    <dl>
        \\      <dt>Scene</dt><dd id="scene">unknown</dd>
        \\      <dt>Backend</dt><dd id="backend">web_poc</dd>
        \\      <dt>Runtime</dt><dd id="runtime">loading</dd>
        \\      <dt>Entities</dt><dd id="entities">0</dd>
        \\      <dt>Systems</dt><dd id="systems">0</dd>
        \\      <dt>Frames</dt><dd id="frames">0</dd>
        \\    </dl>
        \\  </main>
        \\  <script src="player.js"></script>
        \\</body>
        \\</html>
        \\
    });
}

pub fn writeWebPlayerScript(io: Io, bundle_dir: Io.Dir) !void {
    try bundle_dir.writeFile(io, .{ .sub_path = web_player_script_path, .data =
        \\"use strict";
        \\
        \\const statusEl = document.getElementById("status");
        \\const projectEl = document.getElementById("project-name");
        \\const sceneEl = document.getElementById("scene");
        \\const backendEl = document.getElementById("backend");
        \\const runtimeEl = document.getElementById("runtime");
        \\const entitiesEl = document.getElementById("entities");
        \\const systemsEl = document.getElementById("systems");
        \\const framesEl = document.getElementById("frames");
        \\const canvas = document.getElementById("scrapbot-canvas");
        \\const ctx = canvas.getContext("2d");
        \\const encoder = new TextEncoder();
        \\const decoder = new TextDecoder();
        \\
        \\function drawLoadingScene(message = "Loading Scrapbot wasm runtime...") {
        \\  const width = canvas.width;
        \\  const height = canvas.height;
        \\  ctx.fillStyle = "#151b22";
        \\  ctx.fillRect(0, 0, width, height);
        \\  ctx.strokeStyle = "#4f6478";
        \\  ctx.lineWidth = 2;
        \\  ctx.strokeRect(24, 24, width - 48, height - 48);
        \\  ctx.fillStyle = "#eef2f6";
        \\  ctx.font = "24px system-ui, sans-serif";
        \\  ctx.fillText("Scrapbot web export PoC", 48, 72);
        \\  ctx.fillStyle = "#9fb0c1";
        \\  ctx.font = "16px system-ui, sans-serif";
        \\  ctx.fillText(message, 48, 104);
        \\}
        \\
        \\function rotateX(vector, angle) {
        \\  const c = Math.cos(angle);
        \\  const s = Math.sin(angle);
        \\  return [vector[0], vector[1] * c - vector[2] * s, vector[1] * s + vector[2] * c];
        \\}
        \\
        \\function rotateY(vector, angle) {
        \\  const c = Math.cos(angle);
        \\  const s = Math.sin(angle);
        \\  return [vector[0] * c + vector[2] * s, vector[1], -vector[0] * s + vector[2] * c];
        \\}
        \\
        \\function rotateZ(vector, angle) {
        \\  const c = Math.cos(angle);
        \\  const s = Math.sin(angle);
        \\  return [vector[0] * c - vector[1] * s, vector[0] * s + vector[1] * c, vector[2]];
        \\}
        \\
        \\function readCamera() {
        \\  if (!wasm) return { position: [0, 0, 4.8], rotation: [0, 0, 0], fov: 48 };
        \\  const ptr = wasm.exports.scrapbot_camera_snapshot_ptr();
        \\  const len = wasm.exports.scrapbot_camera_snapshot_len();
        \\  const values = new Float32Array(wasm.exports.memory.buffer, ptr, len);
        \\  return {
        \\    position: [values[0], values[1], values[2]],
        \\    rotation: [values[3], values[4], values[5]],
        \\    fov: values[6] || 48,
        \\  };
        \\}
        \\
        \\function worldToCamera(position, camera) {
        \\  let vector = [
        \\    position[0] - camera.position[0],
        \\    position[1] - camera.position[1],
        \\    position[2] - camera.position[2],
        \\  ];
        \\  vector = rotateZ(vector, -camera.rotation[2]);
        \\  vector = rotateY(vector, -camera.rotation[1]);
        \\  vector = rotateX(vector, -camera.rotation[0]);
        \\  return vector;
        \\}
        \\
        \\function project(position, camera, focalLength) {
        \\  const view = worldToCamera(position, camera);
        \\  const depth = -view[2];
        \\  if (depth <= 0.05) return null;
        \\  return {
        \\    x: canvas.width * 0.5 + view[0] * focalLength / depth,
        \\    y: canvas.height * 0.52 - view[1] * focalLength / depth,
        \\    depth,
        \\  };
        \\}
        \\
        \\function colorFromHdr(r, g, b, alpha = 1) {
        \\  const tone = value => Math.max(0, Math.min(255, Math.round((value / (1 + Math.max(0, value))) * 255)));
        \\  return `rgba(${tone(r)}, ${tone(g)}, ${tone(b)}, ${alpha})`;
        \\}
        \\
        \\function drawBackground() {
        \\  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
        \\  gradient.addColorStop(0, "#101820");
        \\  gradient.addColorStop(0.58, "#131a22");
        \\  gradient.addColorStop(1, "#0b0f14");
        \\  ctx.fillStyle = gradient;
        \\  ctx.fillRect(0, 0, canvas.width, canvas.height);
        \\  ctx.strokeStyle = "rgba(143, 160, 178, 0.14)";
        \\  ctx.lineWidth = 1;
        \\  for (let y = canvas.height * 0.58; y < canvas.height; y += 24) {
        \\    ctx.beginPath();
        \\    ctx.moveTo(0, y);
        \\    ctx.lineTo(canvas.width, y);
        \\    ctx.stroke();
        \\  }
        \\}
        \\
        \\function drawPlane(item) {
        \\  ctx.save();
        \\  ctx.translate(item.x, item.y);
        \\  ctx.rotate(item.rotation);
        \\  ctx.fillStyle = item.color;
        \\  ctx.strokeStyle = "rgba(220, 230, 240, 0.16)";
        \\  ctx.lineWidth = 1;
        \\  ctx.beginPath();
        \\  ctx.ellipse(0, 0, item.width, item.height, 0, 0, Math.PI * 2);
        \\  ctx.fill();
        \\  ctx.stroke();
        \\  ctx.restore();
        \\}
        \\
        \\function drawMesh(item) {
        \\  ctx.save();
        \\  ctx.translate(item.x, item.y);
        \\  ctx.rotate(item.rotation);
        \\  ctx.fillStyle = item.color;
        \\  ctx.strokeStyle = "rgba(255, 255, 255, 0.28)";
        \\  ctx.lineWidth = Math.max(1, item.size * 0.08);
        \\  if (item.kind === 1) {
        \\    ctx.beginPath();
        \\    ctx.arc(0, 0, item.size, 0, Math.PI * 2);
        \\    ctx.fill();
        \\    ctx.stroke();
        \\    ctx.fillStyle = "rgba(255, 255, 255, 0.24)";
        \\    ctx.beginPath();
        \\    ctx.arc(-item.size * 0.32, -item.size * 0.36, Math.max(1.5, item.size * 0.22), 0, Math.PI * 2);
        \\    ctx.fill();
        \\  } else {
        \\    const size = item.size;
        \\    ctx.beginPath();
        \\    ctx.moveTo(-size, -size * 0.72);
        \\    ctx.lineTo(size * 0.78, -size);
        \\    ctx.lineTo(size, size * 0.72);
        \\    ctx.lineTo(-size * 0.78, size);
        \\    ctx.closePath();
        \\    ctx.fill();
        \\    ctx.stroke();
        \\    ctx.fillStyle = "rgba(255, 255, 255, 0.18)";
        \\    ctx.beginPath();
        \\    ctx.moveTo(-size, -size * 0.72);
        \\    ctx.lineTo(size * 0.78, -size);
        \\    ctx.lineTo(0, -size * 0.18);
        \\    ctx.closePath();
        \\    ctx.fill();
        \\  }
        \\  ctx.restore();
        \\}
        \\
        \\function drawScene(frameCount = 0) {
        \\  if (!wasm || wasm.exports.scrapbot_initialized() === 0) {
        \\    drawLoadingScene();
        \\    return;
        \\  }
        \\  const ptr = wasm.exports.scrapbot_renderable_snapshot_ptr();
        \\  const len = wasm.exports.scrapbot_renderable_snapshot_len();
        \\  const stride = wasm.exports.scrapbot_renderable_snapshot_stride();
        \\  const camera = readCamera();
        \\  const fov = Math.max(1, Math.min(140, camera.fov)) * Math.PI / 180;
        \\  const focalLength = canvas.height / (2 * Math.tan(fov * 0.5));
        \\  drawBackground();
        \\  if (ptr === 0 || len === 0 || stride === 0) {
        \\    drawLoadingScene("Runtime is stepping, but no renderables are visible.");
        \\    return;
        \\  }
        \\  const values = new Float32Array(wasm.exports.memory.buffer, ptr, len);
        \\  const items = [];
        \\  for (let offset = 0; offset + stride <= values.length; offset += stride) {
        \\    const position = [values[offset], values[offset + 1], values[offset + 2]];
        \\    const projected = project(position, camera, focalLength);
        \\    if (!projected) continue;
        \\    const scale = [Math.abs(values[offset + 6]), Math.abs(values[offset + 7]), Math.abs(values[offset + 8])];
        \\    const averageScale = Math.max(0.025, (scale[0] + scale[1] + scale[2]) / 3);
        \\    const kind = Math.round(values[offset + 12]);
        \\    const size = Math.max(kind === 2 ? 8 : 3, averageScale * focalLength / projected.depth * 1.55);
        \\    items.push({
        \\      x: projected.x,
        \\      y: projected.y,
        \\      depth: projected.depth,
        \\      kind,
        \\      size,
        \\      width: Math.max(12, scale[0] * focalLength / projected.depth),
        \\      height: Math.max(5, scale[2] * focalLength / projected.depth * 0.32),
        \\      rotation: values[offset + 5],
        \\      color: colorFromHdr(values[offset + 9], values[offset + 10], values[offset + 11], kind === 2 ? 0.82 : 0.96),
        \\    });
        \\  }
        \\  items.sort((a, b) => b.depth - a.depth);
        \\  for (const item of items) {
        \\    if (item.kind === 2) drawPlane(item);
        \\    else drawMesh(item);
        \\  }
        \\  ctx.fillStyle = "rgba(238, 242, 246, 0.9)";
        \\  ctx.font = "14px system-ui, sans-serif";
        \\  ctx.fillText(`Canvas2D preview · renderables ${items.length} · frames ${frameCount}`, 18, 28);
        \\}
        \\
        \\function makeWasiImports() {
        \\  return {
        \\    args_get: () => 0,
        \\    args_sizes_get: (argcPtr, argvBufSizePtr) => {
        \\      const view = new DataView(wasm.exports.memory.buffer);
        \\      view.setUint32(argcPtr, 0, true);
        \\      view.setUint32(argvBufSizePtr, 0, true);
        \\      return 0;
        \\    },
        \\    clock_time_get: (_clockId, _precision, timePtr) => {
        \\      const view = new DataView(wasm.exports.memory.buffer);
        \\      view.setBigUint64(timePtr, BigInt(Date.now()) * 1000000n, true);
        \\      return 0;
        \\    },
        \\    fd_close: () => 0,
        \\    fd_fdstat_get: (_fd, statPtr) => {
        \\      new Uint8Array(wasm.exports.memory.buffer, statPtr, 24).fill(0);
        \\      return 0;
        \\    },
        \\    fd_seek: () => 0,
        \\    fd_write: (_fd, iovsPtr, iovsLen, nwrittenPtr) => {
        \\      const view = new DataView(wasm.exports.memory.buffer);
        \\      let written = 0;
        \\      for (let index = 0; index < iovsLen; index += 1) {
        \\        const len = view.getUint32(iovsPtr + index * 8 + 4, true);
        \\        written += len;
        \\      }
        \\      view.setUint32(nwrittenPtr, written, true);
        \\      return 0;
        \\    },
        \\    proc_exit: code => { throw new Error(`wasm proc_exit(${code})`); },
        \\  };
        \\}
        \\
        \\let wasm = null;
        \\function writeString(value) {
        \\  const bytes = encoder.encode(value);
        \\  const ptr = wasm.exports.scrapbot_alloc(bytes.length);
        \\  if (ptr === 0 && bytes.length !== 0) throw new Error("wasm allocation failed");
        \\  new Uint8Array(wasm.exports.memory.buffer, ptr, bytes.length).set(bytes);
        \\  return { ptr, len: bytes.length };
        \\}
        \\
        \\function callWithString(value, callback) {
        \\  const memory = writeString(value);
        \\  try {
        \\    return callback(memory.ptr, memory.len);
        \\  } finally {
        \\    wasm.exports.scrapbot_free(memory.ptr, memory.len);
        \\  }
        \\}
        \\
        \\function lastError() {
        \\  const ptr = wasm.exports.scrapbot_error_ptr();
        \\  const len = wasm.exports.scrapbot_error_len();
        \\  if (len === 0) return "";
        \\  return decoder.decode(new Uint8Array(wasm.exports.memory.buffer, ptr, len));
        \\}
        \\
        \\function updateStats() {
        \\  const frames = wasm.exports.scrapbot_frame_count();
        \\  entitiesEl.textContent = String(wasm.exports.scrapbot_entity_count());
        \\  systemsEl.textContent = String(wasm.exports.scrapbot_system_count());
        \\  framesEl.textContent = String(frames);
        \\  drawScene(frames);
        \\}
        \\
        \\async function loadPlayer() {
        \\  drawLoadingScene();
        \\  try {
        \\    const [manifestResponse, dataResponse, wasmResponse] = await Promise.all([
        \\      fetch("scrapbot-web.json", { cache: "no-store" }),
        \\      fetch("project-data.json", { cache: "no-store" }),
        \\      fetch("scrapbot-web-player.wasm", { cache: "no-store" }),
        \\    ]);
        \\    if (!manifestResponse.ok) throw new Error(`manifest HTTP ${manifestResponse.status}`);
        \\    if (!dataResponse.ok) throw new Error(`project data HTTP ${dataResponse.status}`);
        \\    if (!wasmResponse.ok) throw new Error(`wasm HTTP ${wasmResponse.status}`);
        \\    const manifest = await manifestResponse.json();
        \\    const projectData = await dataResponse.json();
        \\    const wasmBytes = await wasmResponse.arrayBuffer();
        \\    const instance = await WebAssembly.instantiate(wasmBytes, {
        \\      wasi_snapshot_preview1: makeWasiImports(),
        \\    });
        \\    wasm = instance.instance;
        \\    wasm.exports._initialize?.();
        \\    projectEl.textContent = manifest.project || "Scrapbot Web Player";
        \\    sceneEl.textContent = manifest.default_scene || "unknown";
        \\    backendEl.textContent = `${manifest.render_backend || "web_poc"} (${manifest.backend_status || "canvas2d_preview"})`;
        \\    callWithString(projectData.project || manifest.project || "Scrapbot", (namePtr, nameLen) => {
        \\      callWithString(projectData.default_scene || manifest.default_scene || "scene.toml", (scenePtr, sceneLen) => {
        \\        if (wasm.exports.scrapbot_set_project(namePtr, nameLen, scenePtr, sceneLen) === 0) throw new Error(lastError());
        \\      });
        \\    });
        \\    callWithString(projectData.scene_source || "", (ptr, len) => {
        \\      if (wasm.exports.scrapbot_set_scene(ptr, len) === 0) throw new Error(lastError());
        \\    });
        \\    for (const script of projectData.scripts || []) {
        \\      callWithString(script.path || "script.luau", (pathPtr, pathLen) => {
        \\        callWithString(script.source || "", (sourcePtr, sourceLen) => {
        \\          if (wasm.exports.scrapbot_add_script(pathPtr, pathLen, sourcePtr, sourceLen) === 0) throw new Error(lastError());
        \\        });
        \\      });
        \\    }
        \\    if (wasm.exports.scrapbot_init() === 0) throw new Error(lastError());
        \\    runtimeEl.textContent = "wasm runtime loaded";
        \\    statusEl.textContent = manifest.notes || "Headless wasm runtime loaded; drawing Canvas2D preview.";
        \\    function frame() {
        \\      if (wasm.exports.scrapbot_step(1 / 60) === 0) {
        \\        statusEl.textContent = `Runtime error: ${lastError()}`;
        \\        return;
        \\      }
        \\      updateStats();
        \\      requestAnimationFrame(frame);
        \\    }
        \\    updateStats();
        \\    requestAnimationFrame(frame);
        \\  } catch (error) {
        \\    runtimeEl.textContent = "failed";
        \\    statusEl.textContent = `Open this bundle through a local web server. ${error.message}`;
        \\  }
        \\}
        \\
        \\loadPlayer();
        \\
    });
}

fn fileExists(io: Io, dir: Io.Dir, path: []const u8) bool {
    dir.access(io, path, .{}) catch return false;
    return true;
}

pub fn appendJsonString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: []const u8) !void {
    try out.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '"' => try out.appendSlice(allocator, "\\\""),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => try out.append(allocator, byte),
        }
    }
    try out.append(allocator, '"');
}
