const std = @import("std");
const builtin = @import("builtin");

pub const PlatformDynLib = switch (builtin.os.tag) {
    .windows => WindowsDynLib,
    .wasi, .freestanding => UnsupportedDynLib,
    else => std.DynLib,
};

const UnsupportedDynLib = struct {
    pub const Error = error{UnsupportedDynamicLibrary};

    pub fn open(_: std.mem.Allocator, _: []const u8) Error!UnsupportedDynLib {
        return error.UnsupportedDynamicLibrary;
    }

    pub fn close(_: *UnsupportedDynLib) void {}

    pub fn lookup(_: *UnsupportedDynLib, comptime T: type, _: [:0]const u8) ?T {
        return null;
    }
};

const WindowsDynLib = struct {
    handle: std.os.windows.HMODULE,

    pub const Error = error{
        LoadLibraryFailed,
        InvalidLibraryPath,
    };

    pub fn open(allocator: std.mem.Allocator, path: []const u8) Error!WindowsDynLib {
        const path_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, path) catch return error.InvalidLibraryPath;
        defer allocator.free(path_w);
        const handle = LoadLibraryW(path_w.ptr) orelse return error.LoadLibraryFailed;
        return .{ .handle = handle };
    }

    pub fn close(self: *WindowsDynLib) void {
        _ = FreeLibrary(self.handle);
    }

    pub fn lookup(self: *WindowsDynLib, comptime T: type, name: [:0]const u8) ?T {
        const symbol = GetProcAddress(self.handle, name.ptr) orelse return null;
        return @ptrCast(symbol);
    }
};

pub const NativeLibrary = struct {
    path: []u8,
    handle: PlatformDynLib,

    pub fn deinit(self: *NativeLibrary, allocator: std.mem.Allocator) void {
        self.handle.close();
        allocator.free(self.path);
        self.* = undefined;
    }
};

extern "kernel32" fn LoadLibraryW(lpLibFileName: [*:0]const u16) callconv(.winapi) ?std.os.windows.HMODULE;
extern "kernel32" fn GetProcAddress(hModule: std.os.windows.HMODULE, lpProcName: [*:0]const u8) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn FreeLibrary(hLibModule: std.os.windows.HMODULE) callconv(.winapi) c_int;
