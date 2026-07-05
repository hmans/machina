const std = @import("std");
const runtime = @import("../runtime.zig");
const editor_state = @import("../editor/state.zig");

pub const PointerInput = struct {
    position: [2]f32 = .{ 0.0, 0.0 },
    delta: [2]f32 = .{ 0.0, 0.0 },
    has_position: bool = false,
    primary_down: bool = false,
    primary_pressed: bool = false,
    primary_released: bool = false,
    secondary_down: bool = false,
    secondary_pressed: bool = false,
    secondary_released: bool = false,
    wheel_delta: [2]f32 = .{ 0.0, 0.0 },

    pub fn beginFrame(self: *PointerInput) void {
        self.primary_pressed = false;
        self.primary_released = false;
        self.secondary_pressed = false;
        self.secondary_released = false;
        self.delta = .{ 0.0, 0.0 };
        self.wheel_delta = .{ 0.0, 0.0 };
    }
};

pub const KeyboardInput = struct {
    ctrl_down: bool = false,
    shift_down: bool = false,
    alt_down: bool = false,
    super_down: bool = false,
    move_forward: bool = false,
    move_back: bool = false,
    move_left: bool = false,
    move_right: bool = false,
    move_up: bool = false,
    move_down: bool = false,
    editor_toggle_pressed: bool = false,
    editor_undo_pressed: bool = false,
    editor_redo_pressed: bool = false,
    editor_left_pressed: bool = false,
    editor_right_pressed: bool = false,
    editor_home_pressed: bool = false,
    editor_end_pressed: bool = false,
    editor_backspace_pressed: bool = false,
    editor_delete_pressed: bool = false,
    editor_enter_pressed: bool = false,
    editor_select_all_pressed: bool = false,

    pub fn beginFrame(self: *KeyboardInput) void {
        self.editor_toggle_pressed = false;
        self.editor_undo_pressed = false;
        self.editor_redo_pressed = false;
        self.editor_left_pressed = false;
        self.editor_right_pressed = false;
        self.editor_home_pressed = false;
        self.editor_end_pressed = false;
        self.editor_backspace_pressed = false;
        self.editor_delete_pressed = false;
        self.editor_enter_pressed = false;
        self.editor_select_all_pressed = false;
    }
};

pub const FrameInput = struct {
    pointer: PointerInput = .{},
    keyboard: KeyboardInput = .{},
    ui_visible: bool = true,
    debug_overlay_visible: bool = false,
    fps: f32 = 0.0,
    delta_seconds: f32 = 0.0,
    viewport_width: f32 = 0.0,
    viewport_height: f32 = 0.0,
    pixel_scale: f32 = 1.0,
    camera_override: ?runtime.Transform = null,
    editor: editor_state.EditorFrameState = .{},
    system_profiles: []const runtime.SystemProfileSnapshot = &.{},
    system_profile_count_hint: usize = 0,
    text_input: [editor_state.input_text_buffer_len]u8 = [_]u8{0} ** editor_state.input_text_buffer_len,
    text_input_len: usize = 0,

    pub fn beginFrame(self: *FrameInput) void {
        self.pointer.beginFrame();
        self.keyboard.beginFrame();
        self.system_profile_count_hint = 0;
        self.text_input_len = 0;
        @memset(self.text_input[0..], 0);
    }

    pub fn appendTextInput(self: *FrameInput, value: []const u8) void {
        for (value) |byte| {
            if (self.text_input_len >= self.text_input.len) {
                break;
            }
            if (byte >= 32 and byte < 127) {
                self.text_input[self.text_input_len] = byte;
                self.text_input_len += 1;
            }
        }
    }

    pub fn textInput(self: *const FrameInput) []const u8 {
        return self.text_input[0..self.text_input_len];
    }
};

pub fn normalizedPixelScale(pixel_scale: f32) f32 {
    if (!std.math.isFinite(pixel_scale) or pixel_scale <= 0.0) {
        return 1.0;
    }
    return pixel_scale;
}

pub fn framePixelScale(input: FrameInput) f32 {
    return normalizedPixelScale(input.pixel_scale);
}

pub fn logicalPixelsFromPhysical(physical_pixels: u32, pixel_scale: f32) f32 {
    return @as(f32, @floatFromInt(physical_pixels)) / normalizedPixelScale(pixel_scale);
}

pub fn frameInputWithOutputMetrics(input: FrameInput, physical_width: u32, physical_height: u32, pixel_scale: f32) FrameInput {
    var next = input;
    next.pixel_scale = normalizedPixelScale(pixel_scale);
    next.viewport_width = logicalPixelsFromPhysical(physical_width, next.pixel_scale);
    next.viewport_height = logicalPixelsFromPhysical(physical_height, next.pixel_scale);
    return next;
}

pub fn frameInputWithDefaultOutputMetrics(input: FrameInput, physical_width: u32, physical_height: u32) FrameInput {
    var next = input;
    next.pixel_scale = framePixelScale(input);
    if (next.viewport_width <= 0.0) {
        next.viewport_width = logicalPixelsFromPhysical(physical_width, next.pixel_scale);
    }
    if (next.viewport_height <= 0.0) {
        next.viewport_height = logicalPixelsFromPhysical(physical_height, next.pixel_scale);
    }
    return next;
}

pub fn toggleDebugOverlay(input: *FrameInput) void {
    input.debug_overlay_visible = !input.debug_overlay_visible;
    input.keyboard.editor_toggle_pressed = true;
}
