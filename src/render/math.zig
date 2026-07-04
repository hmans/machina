const std = @import("std");
const runtime = @import("../runtime.zig");

pub fn cameraViewMatrix(transform_value: runtime.Transform) [16]f32 {
    const inverse_translation = translation(
        -transform_value.position[0],
        -transform_value.position[1],
        -transform_value.position[2],
    );
    return matMul(
        rotationX(-transform_value.rotation[0]),
        matMul(
            rotationY(-transform_value.rotation[1]),
            matMul(rotationZ(-transform_value.rotation[2]), inverse_translation),
        ),
    );
}

pub fn lookAt(eye: [3]f32, target: [3]f32, up: [3]f32) [16]f32 {
    const z = normalizeVec3(subtractVec3(eye, target));
    const x = normalizeVec3(crossVec3(up, z));
    const y = crossVec3(z, x);

    return .{
        x[0],             y[0],             z[0],             0.0,
        x[1],             y[1],             z[1],             0.0,
        x[2],             y[2],             z[2],             0.0,
        -dotVec3(x, eye), -dotVec3(y, eye), -dotVec3(z, eye), 1.0,
    };
}

pub fn isFiniteVec3(value: [3]f32) bool {
    return std.math.isFinite(value[0]) and std.math.isFinite(value[1]) and std.math.isFinite(value[2]);
}

pub fn addVec3(left: [3]f32, right: [3]f32) [3]f32 {
    return .{ left[0] + right[0], left[1] + right[1], left[2] + right[2] };
}

pub fn subtractVec3(left: [3]f32, right: [3]f32) [3]f32 {
    return .{ left[0] - right[0], left[1] - right[1], left[2] - right[2] };
}

pub fn scaleVec3(value: [3]f32, scalar: f32) [3]f32 {
    return .{ value[0] * scalar, value[1] * scalar, value[2] * scalar };
}

pub fn dotVec3(left: [3]f32, right: [3]f32) f32 {
    return left[0] * right[0] + left[1] * right[1] + left[2] * right[2];
}

pub fn crossVec3(left: [3]f32, right: [3]f32) [3]f32 {
    return .{
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    };
}

pub fn normalizeVec3(value: [3]f32) [3]f32 {
    const length = vec3Length(value);
    if (length == 0.0) {
        return .{ 0.0, 0.0, 1.0 };
    }
    return .{ value[0] / length, value[1] / length, value[2] / length };
}

pub fn vec3Length(value: [3]f32) f32 {
    return @sqrt(value[0] * value[0] + value[1] * value[1] + value[2] * value[2]);
}

pub fn addVec2(left: [2]f32, right: [2]f32) [2]f32 {
    return .{ left[0] + right[0], left[1] + right[1] };
}

pub fn subtractVec2(left: [2]f32, right: [2]f32) [2]f32 {
    return .{ left[0] - right[0], left[1] - right[1] };
}

pub fn scaleVec2(value: [2]f32, scalar: f32) [2]f32 {
    return .{ value[0] * scalar, value[1] * scalar };
}

pub fn dotVec2(left: [2]f32, right: [2]f32) f32 {
    return left[0] * right[0] + left[1] * right[1];
}

pub fn vec2Length(value: [2]f32) f32 {
    return @sqrt(value[0] * value[0] + value[1] * value[1]);
}

pub fn distancePointToScreenSegment(point: [2]f32, start: [2]f32, end: [2]f32) f32 {
    const segment = subtractVec2(end, start);
    const segment_len_sq = dotVec2(segment, segment);
    if (segment_len_sq <= 0.00001) {
        return vec2Length(subtractVec2(point, start));
    }
    const raw_t = dotVec2(subtractVec2(point, start), segment) / segment_len_sq;
    const t = @max(0.0, @min(1.0, raw_t));
    const closest = addVec2(start, scaleVec2(segment, t));
    return vec2Length(subtractVec2(point, closest));
}

pub fn rotateDirection(rotation: [3]f32, direction: [3]f32) [3]f32 {
    const matrix = matMul(
        rotationZ(rotation[2]),
        matMul(
            rotationY(rotation[1]),
            rotationX(rotation[0]),
        ),
    );
    const rotated = transformPoint(matrix, .{ direction[0], direction[1], direction[2], 0.0 });
    return normalizeVec3(.{ rotated[0], rotated[1], rotated[2] });
}

pub fn transformPoint(matrix: [16]f32, point: [4]f32) [4]f32 {
    return .{
        matrix[0] * point[0] + matrix[4] * point[1] + matrix[8] * point[2] + matrix[12] * point[3],
        matrix[1] * point[0] + matrix[5] * point[1] + matrix[9] * point[2] + matrix[13] * point[3],
        matrix[2] * point[0] + matrix[6] * point[1] + matrix[10] * point[2] + matrix[14] * point[3],
        matrix[3] * point[0] + matrix[7] * point[1] + matrix[11] * point[2] + matrix[15] * point[3],
    };
}

pub fn perspective(fovy_radians: f32, aspect: f32, near: f32, far: f32) [16]f32 {
    const f = 1.0 / @tan(fovy_radians * 0.5);
    return .{
        f / aspect, 0.0, 0.0,                         0.0,
        0.0,        f,   0.0,                         0.0,
        0.0,        0.0, far / (near - far),          -1.0,
        0.0,        0.0, (far * near) / (near - far), 0.0,
    };
}

pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) [16]f32 {
    return .{
        2.0 / (right - left),             0.0,                              0.0,                 0.0,
        0.0,                              2.0 / (top - bottom),             0.0,                 0.0,
        0.0,                              0.0,                              1.0 / (near - far),  0.0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), near / (near - far), 1.0,
    };
}

pub fn translation(x: f32, y: f32, z: f32) [16]f32 {
    return .{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        x,   y,   z,   1.0,
    };
}

pub fn scaling(x: f32, y: f32, z: f32) [16]f32 {
    return .{
        x,   0.0, 0.0, 0.0,
        0.0, y,   0.0, 0.0,
        0.0, 0.0, z,   0.0,
        0.0, 0.0, 0.0, 1.0,
    };
}

pub fn rotationX(angle: f32) [16]f32 {
    const c = @cos(angle);
    const s = @sin(angle);
    return .{
        1.0, 0.0, 0.0, 0.0,
        0.0, c,   s,   0.0,
        0.0, -s,  c,   0.0,
        0.0, 0.0, 0.0, 1.0,
    };
}

pub fn rotationY(angle: f32) [16]f32 {
    const c = @cos(angle);
    const s = @sin(angle);
    return .{
        c,   0.0, -s,  0.0,
        0.0, 1.0, 0.0, 0.0,
        s,   0.0, c,   0.0,
        0.0, 0.0, 0.0, 1.0,
    };
}

pub fn rotationZ(angle: f32) [16]f32 {
    const c = @cos(angle);
    const s = @sin(angle);
    return .{
        c,   s,   0.0, 0.0,
        -s,  c,   0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    };
}

pub fn matMul(a: [16]f32, b: [16]f32) [16]f32 {
    var out: [16]f32 = undefined;
    for (0..4) |column| {
        for (0..4) |row| {
            var sum: f32 = 0.0;
            for (0..4) |k| {
                sum += a[k * 4 + row] * b[column * 4 + k];
            }
            out[column * 4 + row] = sum;
        }
    }
    return out;
}
