const std = @import("std");
const ziez = @import("ziez");
const compression = @import("compression.zig");

pub const CompressionConfig = compression.CompressionConfig;
pub const Algorithm = compression.Algorithm;
pub const CompressionLevel = compression.CompressionLevel;

/// Registers compression on the app. Uses `registerCompression` internally.
pub fn setup(app: *ziez.App, config: CompressionConfig) !void {
    const owned = try app.allocator.create(compression.CompressionConfig);
    owned.* = config;
    app.registerCompression(owned, compression.applyFn, compression.freeConfigFn);
}
