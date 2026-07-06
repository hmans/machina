pub const RenderBackend = enum {
    native_wgpu,
    web_poc,

    pub fn label(self: RenderBackend) []const u8 {
        return switch (self) {
            .native_wgpu => "native_wgpu",
            .web_poc => "web_poc",
        };
    }
};
