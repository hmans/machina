const machina = @import("machina_native");

const motion_fields = [_]machina.ComponentField{
    .{ .name = "origin", .field_type = .vec3 },
    .{ .name = "amplitude", .field_type = .vec3 },
    .{ .name = "phase", .field_type = .float },
    .{ .name = "speed", .field_type = .float },
};

const native_move_reads = [_][*:0]const u8{ "motion", "boost" };
const native_move_writes = [_][*:0]const u8{"machina.transform"};
var elapsed_seconds: f32 = 0.0;

export fn machina_register(api: *const machina.RegisterApi) callconv(.c) c_int {
    machina.registerComponent(api, .{
        .id = "motion",
        .fields = motion_fields[0..],
    }) catch return 0;

    machina.registerSystem(api, .{
        .id = "native_move",
        .phase = .update,
        .reads = native_move_reads[0..],
        .writes = native_move_writes[0..],
        .run = nativeMove,
    }) catch return 0;

    return 1;
}

fn nativeMove(context: *machina.SystemContext) callconv(.c) c_int {
    elapsed_seconds += context.delta_seconds;

    const query = [_][*:0]const u8{ "machina.transform", "motion", "boost" };
    var cursor: usize = 0;
    while (machina.queryNext(context, query[0..], &cursor) catch return 0) |entity| {
        const origin = machina.getVec3(context, entity, "motion", "origin") catch return 0;
        const amplitude = machina.getVec3(context, entity, "motion", "amplitude") catch return 0;
        const phase = machina.getF32(context, entity, "motion", "phase") catch return 0;
        const speed = machina.getF32(context, entity, "motion", "speed") catch return 0;
        const boost = machina.getF32(context, entity, "boost", "amount") catch return 0;
        const t = elapsed_seconds * speed * boost + phase;
        machina.setVec3(context, entity, "machina.transform", "position", .{
            .x = origin.x + amplitude.x * @sin(t),
            .y = origin.y + amplitude.y * @cos(t * 1.17),
            .z = origin.z + amplitude.z * @sin(t * 0.73),
        }) catch return 0;
    }
    return 1;
}
