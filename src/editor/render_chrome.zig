const std = @import("std");
const ui_font = @import("../ui_font.zig");
const editor_layout = @import("layout.zig");

const ScreenRect = editor_layout.ScreenRect;

pub const inspector_text_size: f32 = 1.0;
pub const inspector_line_stride: f32 = 32.0;
pub const inspector_field_row_margin_y: f32 = 2.0;
pub const inspector_card_gap: f32 = 4.0;
pub const inspector_separator_height: f32 = 1.0;
pub const inspector_card_padding_x: f32 = 20.0;
pub const inspector_card_padding_y: f32 = 20.0;
pub const inspector_field_column_gap: f32 = 12.0;
pub const inspector_column_min_width: f32 = 140.0;
pub const inspector_input_padding_x: f32 = 2.0;
pub const inspector_input_padding_y: f32 = 2.0;
pub const inspector_input_gap: f32 = 8.0;
pub const inspector_input_border_thickness: f32 = 1.0;
pub const inspector_input_text_offset_x: f32 = inspector_input_border_thickness + inspector_input_padding_x;
pub const inspector_input_text_offset_y: f32 = inspector_input_border_thickness + inspector_input_padding_y;
pub const inspector_input_height: f32 = @as(f32, @floatFromInt(ui_font.height)) * inspector_text_size + inspector_input_text_offset_y * 2.0;
pub const inspector_input_cell_padding: f32 = 2.0;
pub const inspector_field_row_height: f32 = inspector_input_height + inspector_input_cell_padding * 2.0;
pub const inspector_field_row_stride: f32 = inspector_field_row_height + inspector_field_row_margin_y;
pub const inspector_input_corner_radius: f32 = 8.0;
pub const inspector_caret_width: f32 = 2.0;
pub const inspector_field_control_offset_y: f32 = -4.0;
pub const inspector_field_text_offset_y: f32 = -inspector_field_control_offset_y + inspector_input_cell_padding;
pub const inspector_selection_padding_y: f32 = 4.0;
pub const inspector_toggle_width: f32 = 64.0;
pub const inspector_swatch_size: f32 = 32.0;
pub const inspector_lane_label_width: f32 = 16.0;
pub const inspector_lane_label_gap: f32 = 4.0;

pub const InspectorFieldLayout = struct {
    label_x: f32,
    label_width: f32,
    value_x: f32,
    value_width: f32,
};

pub fn textHeight(size: f32) f32 {
    return @as(f32, @floatFromInt(ui_font.height)) * size;
}

pub fn textWidth(value: []const u8, size: f32) f32 {
    return @as(f32, @floatFromInt(value.len * ui_font.advance)) * size;
}

pub fn inspectorFieldLayout(card_width: f32) InspectorFieldLayout {
    const row_width = @max(card_width - inspector_card_padding_x * 2.0, 1.0);
    const available = @max(row_width - inspector_field_column_gap, 0.0);
    const column_width = @max(available * 0.5, inspector_column_min_width);

    return .{
        .label_x = inspector_card_padding_x,
        .label_width = column_width,
        .value_x = inspector_card_padding_x + column_width + inspector_field_column_gap,
        .value_width = column_width,
    };
}

pub fn fitTextToWidth(allocator: std.mem.Allocator, value: []const u8, size: f32, max_width: f32) error{OutOfMemory}![]u8 {
    if (textWidth(value, size) <= max_width) {
        return allocator.dupe(u8, value);
    }

    const suffix = "...";
    const glyph_width = @as(f32, @floatFromInt(ui_font.advance)) * size;
    const suffix_width = textWidth(suffix, size);
    if (max_width <= 0.0 or glyph_width <= 0.0) {
        return allocator.dupe(u8, "");
    }
    if (max_width < suffix_width) {
        const glyph_count = @min(suffix.len, @as(usize, @intFromFloat(@floor(max_width / glyph_width))));
        return allocator.dupe(u8, suffix[0..glyph_count]);
    }
    if (max_width == suffix_width) {
        return allocator.dupe(u8, suffix);
    }

    const available_prefix_width = max_width - suffix_width;
    const prefix_len = @min(value.len, @as(usize, @intFromFloat(@floor(available_prefix_width / glyph_width))));
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ value[0..prefix_len], suffix });
}

pub fn panelTextPosition(panel: ScreenRect, local_y: f32) [3]f32 {
    return .{ panel.x + editor_layout.panel_padding_x, panel.y + local_y, 0.0 };
}

pub fn insetScreenRect(rect: ScreenRect, inset: f32) ScreenRect {
    const clamped = @max(inset, 0.0);
    return .{
        .x = rect.x + clamped,
        .y = rect.y + clamped,
        .width = @max(rect.width - clamped * 2.0, 1.0),
        .height = @max(rect.height - clamped * 2.0, 1.0),
    };
}
