const std = @import("std");
const runtime = @import("runtime.zig");
const ui_font = @import("ui_font.zig");

pub const Error = runtime.WorldError || error{InvalidLayout};

pub const ClipRect = struct {
    position: [3]f32,
    size: [3]f32,
};

pub const ResolvedLayout = struct {
    position: [3]f32,
    clip: ?ClipRect = null,
};

pub const Target = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32,
    height: f32,

    pub fn position(self: Target) [3]f32 {
        return .{ self.x, self.y, 0.0 };
    }
};

pub const CanvasTransform = struct {
    offset: [2]f32 = .{ 0.0, 0.0 },
    scale: f32 = 1.0,
};

pub const LayoutItem = struct {
    parent: []const u8,
    order: i32,
    min_size: [3]f32,
    grow: f32,
    @"align": []const u8,
    margin: [3]f32,
};

pub const Canvas = struct {
    design_size: [3]f32,
    scale_mode: []const u8,
};

pub const ScrollView = struct {
    position: [3]f32,
    size: [3]f32,
    content_offset: [3]f32,
};

pub const VBox = struct {
    position: [3]f32,
    spacing: f32,
};

pub const Stack = struct {
    position: [3]f32,
    spacing: f32,
    direction: []const u8,
    padding: [3]f32,
};

const TextBlock = struct {
    size: [3]f32,
    horizontal_align: []const u8,
    vertical_align: []const u8,
};

pub fn scrollView(world: *const runtime.World, entity: runtime.EntityHandle) Error!?ScrollView {
    if (!(try world.hasComponent(entity, runtime.ui_scroll_view_component_id))) {
        return null;
    }
    return .{
        .position = try world.getVec3(entity, runtime.ui_scroll_view_component_id, "position"),
        .size = try world.getVec3(entity, runtime.ui_scroll_view_component_id, "size"),
        .content_offset = try world.getVec3(entity, runtime.ui_scroll_view_component_id, "content_offset"),
    };
}

pub fn vbox(world: *const runtime.World, entity: runtime.EntityHandle) Error!?VBox {
    if (!(try world.hasComponent(entity, runtime.ui_vbox_component_id))) {
        return null;
    }
    return .{
        .position = try world.getVec3(entity, runtime.ui_vbox_component_id, "position"),
        .spacing = try world.getFloat(entity, runtime.ui_vbox_component_id, "spacing"),
    };
}

pub fn stack(world: *const runtime.World, entity: runtime.EntityHandle) Error!?Stack {
    if (!(try world.hasComponent(entity, runtime.ui_stack_component_id))) {
        return null;
    }
    return .{
        .position = try world.getVec3(entity, runtime.ui_stack_component_id, "position"),
        .spacing = try world.getFloat(entity, runtime.ui_stack_component_id, "spacing"),
        .direction = try world.getString(entity, runtime.ui_stack_component_id, "direction"),
        .padding = try world.getVec3(entity, runtime.ui_stack_component_id, "padding"),
    };
}

pub fn layoutItem(world: *const runtime.World, entity: runtime.EntityHandle) Error!?LayoutItem {
    if (!(try world.hasComponent(entity, runtime.ui_layout_item_component_id))) {
        return null;
    }
    return .{
        .parent = try world.getString(entity, runtime.ui_layout_item_component_id, "parent"),
        .order = try world.getInt(entity, runtime.ui_layout_item_component_id, "order"),
        .min_size = try world.getVec3(entity, runtime.ui_layout_item_component_id, "min_size"),
        .grow = try world.getFloat(entity, runtime.ui_layout_item_component_id, "grow"),
        .@"align" = try world.getString(entity, runtime.ui_layout_item_component_id, "align"),
        .margin = try world.getVec3(entity, runtime.ui_layout_item_component_id, "margin"),
    };
}

pub fn canvas(world: *const runtime.World, entity: runtime.EntityHandle) Error!?Canvas {
    if (!(try world.hasComponent(entity, runtime.ui_canvas_component_id))) {
        return null;
    }
    return .{
        .design_size = try world.getVec3(entity, runtime.ui_canvas_component_id, "design_size"),
        .scale_mode = try world.getString(entity, runtime.ui_canvas_component_id, "scale_mode"),
    };
}

fn textBlock(world: *const runtime.World, entity: runtime.EntityHandle) Error!?TextBlock {
    if (!(try world.hasComponent(entity, runtime.ui_text_block_component_id))) {
        return null;
    }
    return .{
        .size = try world.getVec3(entity, runtime.ui_text_block_component_id, "size"),
        .horizontal_align = try world.getString(entity, runtime.ui_text_block_component_id, "horizontal_align"),
        .vertical_align = try world.getString(entity, runtime.ui_text_block_component_id, "vertical_align"),
    };
}

pub fn resolve(world: *const runtime.World, entity: runtime.EntityHandle, local_position: [3]f32) Error!ResolvedLayout {
    var resolved: ResolvedLayout = .{ .position = local_position };
    var child = entity;

    const max_depth = 32;
    for (0..max_depth) |_| {
        const item = (try layoutItem(world, child)) orelse return resolved;
        const parent = world.findEntityById(item.parent) orelse return error.InvalidLayout;

        if (!isFiniteVec3(item.margin) or item.margin[0] < 0.0 or item.margin[1] < 0.0 or item.margin[2] < 0.0) {
            return error.InvalidLayout;
        }
        resolved.position[0] += item.margin[0];
        resolved.position[1] += item.margin[1];
        resolved.position[2] += item.margin[2];

        if (try vbox(world, parent)) |box| {
            resolved.position[0] += box.position[0];
            resolved.position[1] += box.position[1] + try vboxChildOffsetY(world, parent, child, item);
            resolved.position[2] += box.position[2];
        }

        if (try stack(world, parent)) |stack_value| {
            const stack_offset = try stackChildOffset(world, parent, child, item, stack_value);
            resolved.position[0] += stack_value.position[0] + stack_value.padding[0] + stack_offset[0];
            resolved.position[1] += stack_value.position[1] + stack_value.padding[1] + stack_offset[1];
            resolved.position[2] += stack_value.position[2] + stack_offset[2];
        }

        if (try scrollView(world, parent)) |scroll_view| {
            if (!isFiniteVec3(scroll_view.position) or !isFiniteVec3(scroll_view.size) or !isFiniteVec3(scroll_view.content_offset)) {
                return error.InvalidLayout;
            }
            resolved.position[0] += scroll_view.position[0] - scroll_view.content_offset[0];
            resolved.position[1] += scroll_view.position[1] - scroll_view.content_offset[1];
            resolved.position[2] += scroll_view.position[2] - scroll_view.content_offset[2];
            resolved.clip = try combineClip(resolved.clip, .{
                .position = scroll_view.position,
                .size = scroll_view.size,
            });
        }

        child = parent;
    }
    return error.InvalidLayout;
}

pub fn combineClip(a: ?ClipRect, b: ?ClipRect) Error!?ClipRect {
    if (a == null) return b;
    if (b == null) return a;
    const left = @max(a.?.position[0], b.?.position[0]);
    const top = @max(a.?.position[1], b.?.position[1]);
    const right = @min(a.?.position[0] + a.?.size[0], b.?.position[0] + b.?.size[0]);
    const bottom = @min(a.?.position[1] + a.?.size[1], b.?.position[1] + b.?.size[1]);
    if (right <= left or bottom <= top) {
        return .{ .position = .{ 0.0, 0.0, 0.0 }, .size = .{ 0.0, 0.0, 0.0 } };
    }
    return .{
        .position = .{ left, top, 0.0 },
        .size = .{ right - left, bottom - top, 0.0 },
    };
}

pub fn pointInsideClip(point: [2]f32, clip: ?ClipRect) bool {
    if (clip) |clip_rect| {
        return runtime.pointInsideUiRect(point, clip_rect.position, clip_rect.size);
    }
    return true;
}

pub fn pointerToDesign(world: *const runtime.World, target: Target, pointer_position: [2]f32) Error![2]f32 {
    const transform = try canvasTransform(world, target);
    return .{
        (pointer_position[0] - transform.offset[0]) / transform.scale,
        (pointer_position[1] - transform.offset[1]) / transform.scale,
    };
}

pub fn canvasTransform(world: *const runtime.World, target: Target) Error!CanvasTransform {
    if (target.width <= 0.0 or target.height <= 0.0) {
        return .{};
    }

    for (0..world.entityCount()) |index| {
        const entity = runtime.EntityHandle{ .index = @intCast(index) };
        const canvas_value = (try canvas(world, entity)) orelse continue;
        var transform = try resolveCanvasTransform(canvas_value, target.width, target.height);
        transform.offset[0] += target.x;
        transform.offset[1] += target.y;
        return transform;
    }
    return .{ .offset = .{ target.x, target.y } };
}

pub fn resolveCanvasTransform(canvas_value: Canvas, width: f32, height: f32) Error!CanvasTransform {
    if (std.mem.eql(u8, canvas_value.scale_mode, "none")) {
        return .{};
    }
    if (!isFiniteVec3(canvas_value.design_size) or canvas_value.design_size[0] <= 0.0 or canvas_value.design_size[1] <= 0.0) {
        return error.InvalidLayout;
    }

    const scale = if (std.mem.eql(u8, canvas_value.scale_mode, "fit"))
        @min(width / canvas_value.design_size[0], height / canvas_value.design_size[1])
    else if (std.mem.eql(u8, canvas_value.scale_mode, "fill"))
        @max(width / canvas_value.design_size[0], height / canvas_value.design_size[1])
    else
        return error.InvalidLayout;

    return .{
        .offset = .{
            (width - canvas_value.design_size[0] * scale) * 0.5,
            (height - canvas_value.design_size[1] * scale) * 0.5,
        },
        .scale = scale,
    };
}

pub fn applyCanvasTransform(transform: CanvasTransform, layout: ResolvedLayout) ResolvedLayout {
    var out = layout;
    out.position = scaleVec3(transform, out.position);
    out.clip = scaleClip(transform, out.clip);
    return out;
}

pub fn clipToTarget(layout: ResolvedLayout, target: Target, item_size: [3]f32) Error!ResolvedLayout {
    var out = layout;
    out.clip = try combineClip(out.clip, .{
        .position = target.position(),
        .size = .{ target.width, target.height, item_size[2] },
    });
    return out;
}

pub fn scaleVec3(transform: CanvasTransform, value: [3]f32) [3]f32 {
    return .{
        transform.offset[0] + value[0] * transform.scale,
        transform.offset[1] + value[1] * transform.scale,
        value[2],
    };
}

pub fn scaleSize(transform: CanvasTransform, value: [3]f32) [3]f32 {
    return .{ value[0] * transform.scale, value[1] * transform.scale, value[2] };
}

pub fn scaleClip(transform: CanvasTransform, clip: ?ClipRect) ?ClipRect {
    if (clip) |clip_rect| {
        return .{
            .position = scaleVec3(transform, clip_rect.position),
            .size = scaleSize(transform, clip_rect.size),
        };
    }
    return null;
}

pub fn scrollMaxY(world: *const runtime.World, scroll_entity: runtime.EntityHandle, scroll_view: ScrollView) Error!f32 {
    const content_size = try containerContentSize(world, scroll_entity, false);
    return @max(content_size[1] - scroll_view.size[1], 0.0);
}

pub fn itemSize(world: *const runtime.World, entity: runtime.EntityHandle) Error![3]f32 {
    var size = try itemNaturalSize(world, entity);
    if (try layoutItem(world, entity)) |item| {
        if (!isFiniteVec3(item.min_size) or !isFiniteVec3(item.margin) or
            !std.math.isFinite(item.grow) or item.grow < 0.0 or
            item.margin[0] < 0.0 or item.margin[1] < 0.0 or item.margin[2] < 0.0)
        {
            return error.InvalidLayout;
        }
        size[0] = @max(size[0], item.min_size[0]);
        size[1] = @max(size[1], item.min_size[1]);
        size[2] = @max(size[2], item.min_size[2]);
        size[0] += item.margin[0] * 2.0;
        size[1] += item.margin[1] * 2.0;
        size[2] += item.margin[2] * 2.0;
    }
    return size;
}

fn itemNaturalSize(world: *const runtime.World, entity: runtime.EntityHandle) Error![3]f32 {
    if (try world.hasComponent(entity, runtime.ui_rect_component_id)) {
        return try world.getVec3(entity, runtime.ui_rect_component_id, "size");
    }
    if (try world.hasComponent(entity, runtime.ui_separator_component_id)) {
        return try world.getVec3(entity, runtime.ui_separator_component_id, "size");
    }
    if (try world.hasComponent(entity, runtime.ui_spacer_component_id)) {
        return try world.getVec3(entity, runtime.ui_spacer_component_id, "size");
    }
    if (try world.hasComponent(entity, runtime.ui_scroll_view_component_id)) {
        return try world.getVec3(entity, runtime.ui_scroll_view_component_id, "size");
    }
    if (try world.hasComponent(entity, runtime.ui_vbox_component_id)) {
        return try containerContentSize(world, entity, false);
    }
    if (try world.hasComponent(entity, runtime.ui_stack_component_id)) {
        const stack_value = (try stack(world, entity)) orelse return .{ 0.0, 0.0, 0.0 };
        return try containerContentSize(world, entity, try stackDirectionIsHorizontal(stack_value.direction));
    }
    if (try world.hasComponent(entity, runtime.ui_text_block_component_id)) {
        return try world.getVec3(entity, runtime.ui_text_block_component_id, "size");
    }
    if (try world.hasComponent(entity, runtime.ui_text_component_id)) {
        const size = try world.getFloat(entity, runtime.ui_text_component_id, "size");
        const value = try world.getString(entity, runtime.ui_text_component_id, "value");
        return textPixelSize(value, size);
    }
    return .{ 0.0, 0.0, 0.0 };
}

fn containerContentSize(world: *const runtime.World, parent: runtime.EntityHandle, horizontal: bool) Error![3]f32 {
    const parent_entity = try world.entity(parent);
    var main_size: f32 = 0.0;
    var cross_size: f32 = 0.0;
    var child_count: usize = 0;
    var spacing: f32 = 0.0;
    var padding = [3]f32{ 0.0, 0.0, 0.0 };

    if (try vbox(world, parent)) |box| {
        spacing = box.spacing;
    }
    if (try stack(world, parent)) |stack_value| {
        spacing = stack_value.spacing;
        padding = stack_value.padding;
    }

    const main_axis: usize = if (horizontal) 0 else 1;
    const cross_axis: usize = if (horizontal) 1 else 0;
    for (0..world.entityCount()) |index| {
        const child = runtime.EntityHandle{ .index = @intCast(index) };
        const item = (try layoutItem(world, child)) orelse continue;
        if (!std.mem.eql(u8, item.parent, parent_entity.id)) {
            continue;
        }
        const child_size = try itemSize(world, child);
        main_size += child_size[main_axis];
        cross_size = @max(cross_size, child_size[cross_axis]);
        child_count += 1;
    }
    if (child_count > 1) {
        main_size += spacing * @as(f32, @floatFromInt(child_count - 1));
    }

    var out = [3]f32{ 0.0, 0.0, 0.0 };
    out[main_axis] = main_size + padding[main_axis] * 2.0;
    out[cross_axis] = cross_size + padding[cross_axis] * 2.0;
    return out;
}

pub fn textPixelSize(value: []const u8, size: f32) [3]f32 {
    var line_width: usize = 0;
    var max_width: usize = 0;
    var line_count: usize = 1;
    for (value) |byte| {
        if (byte == '\n') {
            max_width = @max(max_width, line_width);
            line_width = 0;
            line_count += 1;
        } else {
            line_width += 1;
        }
    }
    max_width = @max(max_width, line_width);
    return .{
        @as(f32, @floatFromInt(max_width * ui_font.advance)) * size,
        @as(f32, @floatFromInt(line_count * ui_font.height)) * size,
        0.0,
    };
}

pub fn resolveTextPosition(world: *const runtime.World, entity: runtime.EntityHandle, text: runtime.UiText, position: [3]f32) Error![3]f32 {
    const block = (try textBlock(world, entity)) orelse return position;
    if (!isFiniteVec3(block.size)) {
        return error.InvalidLayout;
    }
    const text_size = textPixelSize(text.value, text.size);
    var resolved = position;
    if (std.mem.eql(u8, block.horizontal_align, "center")) {
        resolved[0] += @max((block.size[0] - text_size[0]) * 0.5, 0.0);
    } else if (std.mem.eql(u8, block.horizontal_align, "end")) {
        resolved[0] += @max(block.size[0] - text_size[0], 0.0);
    } else if (!std.mem.eql(u8, block.horizontal_align, "start")) {
        return error.InvalidLayout;
    }

    if (std.mem.eql(u8, block.vertical_align, "center")) {
        resolved[1] += @max((block.size[1] - text_size[1]) * 0.5, 0.0);
    } else if (std.mem.eql(u8, block.vertical_align, "end")) {
        resolved[1] += @max(block.size[1] - text_size[1], 0.0);
    } else if (!std.mem.eql(u8, block.vertical_align, "start")) {
        return error.InvalidLayout;
    }
    return resolved;
}

fn vboxChildOffsetY(world: *const runtime.World, parent: runtime.EntityHandle, child: runtime.EntityHandle, child_item: LayoutItem) Error!f32 {
    const parent_entity = try world.entity(parent);
    const box = (try vbox(world, parent)) orelse return 0.0;
    if (!std.math.isFinite(box.spacing)) {
        return error.InvalidLayout;
    }

    var offset: f32 = 0.0;
    for (0..world.entityCount()) |index| {
        const sibling = runtime.EntityHandle{ .index = @intCast(index) };
        const sibling_item = (try layoutItem(world, sibling)) orelse continue;
        if (!std.mem.eql(u8, sibling_item.parent, parent_entity.id)) {
            continue;
        }
        const before_child = sibling_item.order < child_item.order or
            (sibling_item.order == child_item.order and sibling.index < child.index);
        if (!before_child) {
            continue;
        }
        offset += (try itemSize(world, sibling))[1];
        offset += box.spacing;
    }
    return offset;
}

fn stackChildOffset(world: *const runtime.World, parent: runtime.EntityHandle, child: runtime.EntityHandle, child_item: LayoutItem, stack_value: Stack) Error![3]f32 {
    const parent_entity = try world.entity(parent);
    if (!isFiniteVec3(stack_value.position) or !isFiniteVec3(stack_value.padding) or !std.math.isFinite(stack_value.spacing)) {
        return error.InvalidLayout;
    }
    const horizontal = try stackDirectionIsHorizontal(stack_value.direction);
    const main_axis: usize = if (horizontal) 0 else 1;
    const cross_axis: usize = if (horizontal) 1 else 0;
    var offset = [3]f32{ 0.0, 0.0, 0.0 };

    for (0..world.entityCount()) |index| {
        const sibling = runtime.EntityHandle{ .index = @intCast(index) };
        const sibling_item = (try layoutItem(world, sibling)) orelse continue;
        if (!std.mem.eql(u8, sibling_item.parent, parent_entity.id)) {
            continue;
        }
        const before_child = sibling_item.order < child_item.order or
            (sibling_item.order == child_item.order and sibling.index < child.index);
        if (!before_child) {
            continue;
        }
        offset[main_axis] += (try itemSize(world, sibling))[main_axis];
        offset[main_axis] += stack_value.spacing;
    }

    const parent_size = try itemSize(world, parent);
    const child_size = try itemSize(world, child);
    const inner_cross_size = @max(parent_size[cross_axis] - stack_value.padding[cross_axis] * 2.0, 0.0);
    if (std.mem.eql(u8, child_item.@"align", "center")) {
        offset[cross_axis] += @max((inner_cross_size - child_size[cross_axis]) * 0.5, 0.0);
    } else if (std.mem.eql(u8, child_item.@"align", "end")) {
        offset[cross_axis] += @max(inner_cross_size - child_size[cross_axis], 0.0);
    } else if (!std.mem.eql(u8, child_item.@"align", "start") and !std.mem.eql(u8, child_item.@"align", "fill")) {
        return error.InvalidLayout;
    }

    return offset;
}

fn stackDirectionIsHorizontal(direction: []const u8) Error!bool {
    if (std.mem.eql(u8, direction, "horizontal") or std.mem.eql(u8, direction, "row")) {
        return true;
    }
    if (std.mem.eql(u8, direction, "vertical") or std.mem.eql(u8, direction, "column")) {
        return false;
    }
    return error.InvalidLayout;
}

fn isFiniteVec3(value: [3]f32) bool {
    return std.math.isFinite(value[0]) and std.math.isFinite(value[1]) and std.math.isFinite(value[2]);
}
