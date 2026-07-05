const std = @import("std");
const Io = std.Io;
const png = @import("../png.zig");
const wgpu = @import("wgpu");

pub const Error = error{
    UnsupportedImageFormat,
    BufferMapFailed,
};

pub const OutputFormat = enum {
    bmp,
    png,
};

pub fn imageFormatFromPath(path: []const u8) Error!OutputFormat {
    const extension = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(extension, ".bmp")) return .bmp;
    if (std.ascii.eqlIgnoreCase(extension, ".png")) return .png;
    return Error.UnsupportedImageFormat;
}

pub fn handleBufferMap(status: wgpu.MapAsyncStatus, _: wgpu.StringView, userdata1: ?*anyopaque, userdata2: ?*anyopaque) callconv(.c) void {
    const complete: *bool = @ptrCast(@alignCast(userdata1));
    complete.* = true;

    const map_status: *wgpu.MapAsyncStatus = @ptrCast(@alignCast(userdata2));
    map_status.* = status;
}

pub fn write24BitBmp(io: Io, allocator: std.mem.Allocator, output_path: []const u8, bgra_data: []const u8, width: u32, height: u32, source_bytes_per_row: usize) !void {
    const width_usize = @as(usize, width);
    const height_usize = @as(usize, height);
    const file_size = bmpFileSize(width, height);
    const bytes = try allocator.alloc(u8, file_size);
    defer allocator.free(bytes);
    @memset(bytes, 0);

    var cursor: usize = 0;
    putBytes(bytes, &cursor, "BM");
    putInt(u32, bytes, &cursor, file_size);
    putInt(u32, bytes, &cursor, 0);
    putInt(u32, bytes, &cursor, 54);
    putInt(u32, bytes, &cursor, 40);
    putInt(u32, bytes, &cursor, width);
    putInt(u32, bytes, &cursor, height);
    putInt(u16, bytes, &cursor, 1);
    putInt(u16, bytes, &cursor, 24);
    cursor += 4 * 6;

    const bytes_per_line = bmpBytesPerLine(width);
    const line_buffer = try allocator.alloc(u8, bytes_per_line);
    defer allocator.free(line_buffer);
    for (0..height_usize) |i_y| {
        @memset(line_buffer, 0);
        const y = height_usize - i_y - 1;
        const line_offset = y * source_bytes_per_row;
        for (0..width_usize) |x| {
            const bgr_pixel_offset = x * 3;
            const bgra_pixel_offset = line_offset + (x * 4);
            line_buffer[bgr_pixel_offset] = bgra_data[bgra_pixel_offset];
            line_buffer[bgr_pixel_offset + 1] = bgra_data[bgra_pixel_offset + 1];
            line_buffer[bgr_pixel_offset + 2] = bgra_data[bgra_pixel_offset + 2];
        }
        putBytes(bytes, &cursor, line_buffer);
    }

    try Io.Dir.cwd().writeFile(io, .{
        .sub_path = output_path,
        .data = bytes,
    });
}

pub fn write24BitPng(io: Io, allocator: std.mem.Allocator, output_path: []const u8, bgra_data: []const u8, width: u32, height: u32, source_bytes_per_row: usize) !void {
    const width_usize = @as(usize, width);
    const height_usize = @as(usize, height);
    const rgb_data = try allocator.alloc(u8, width_usize * height_usize * 3);
    defer allocator.free(rgb_data);

    const rgb_pixels_per_line = width_usize * 3;
    for (0..height_usize) |y| {
        const bgra_line_offset = y * source_bytes_per_row;
        const rgb_line_offset = y * rgb_pixels_per_line;
        for (0..width_usize) |x| {
            const bgra_pixel_offset = bgra_line_offset + x * 4;
            const rgb_pixel_offset = rgb_line_offset + x * 3;
            rgb_data[rgb_pixel_offset] = bgra_data[bgra_pixel_offset + 2];
            rgb_data[rgb_pixel_offset + 1] = bgra_data[bgra_pixel_offset + 1];
            rgb_data[rgb_pixel_offset + 2] = bgra_data[bgra_pixel_offset];
        }
    }

    try png.writeRgb24(io, allocator, output_path, width, height, rgb_data);
}

pub fn alignedOutputBytesPerRow(width: u32) usize {
    return std.mem.alignForward(usize, @as(usize, width) * 4, 256);
}

fn putBytes(output: []u8, cursor: *usize, bytes: []const u8) void {
    @memcpy(output[cursor.*..][0..bytes.len], bytes);
    cursor.* += bytes.len;
}

fn putInt(comptime T: type, output: []u8, cursor: *usize, value: anytype) void {
    const size = @sizeOf(T);
    std.mem.writeInt(T, output[cursor.*..][0..size], @intCast(value), .little);
    cursor.* += size;
}

fn bmpBytesPerLine(width: u32) usize {
    const colors_per_line = @as(usize, width) * 3;
    return if (colors_per_line & 0x00000003 == 0)
        colors_per_line
    else
        (colors_per_line | 0x00000003) + 1;
}

fn bmpFileSize(width: u32, height: u32) usize {
    return 54 + (bmpBytesPerLine(width) * @as(usize, height));
}
