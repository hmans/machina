const builtin = @import("builtin");

pub const is_supported_window_platform = builtin.os.tag == .macos or builtin.os.tag == .linux or builtin.os.tag == .windows;
pub const sdl = if (is_supported_window_platform) @cImport({
    @cInclude("sdl_bridge.h");
}) else struct {};
