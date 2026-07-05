const resources = @import("resources.zig");

pub const Error = resources.Error;
pub const GpuContext = resources.GpuContext;
pub const DepthTarget = resources.DepthTarget;
pub const PostProcessTarget = resources.PostProcessTarget;
pub const ShadowTarget = resources.ShadowTarget;
pub const openGpu = resources.openGpu;
pub const chooseSurfaceFormat = resources.chooseSurfaceFormat;
pub const createStaticBuffer = resources.createStaticBuffer;
pub const writeUniforms = resources.writeUniforms;
