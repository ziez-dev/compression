const std = @import("std");
const comp = @import("ziez_compression");

test "setup function exists" {
    // setup() requires a real App, so just verify the config type works
    const config = comp.CompressionConfig{};
    try std.testing.expect(config.enabled == true);
}

test "Algorithm.encodingName" {
    try std.testing.expectEqualStrings("gzip", comp.Algorithm.gzip.encodingName());
    try std.testing.expectEqualStrings("deflate", comp.Algorithm.deflate.encodingName());
    try std.testing.expectEqualStrings("br", comp.Algorithm.brotli.encodingName());
}

test "CompressionConfig defaults" {
    const config = comp.CompressionConfig{};
    try std.testing.expect(config.enabled == true);
    try std.testing.expect(config.threshold == 1024);
    try std.testing.expect(config.algorithms.len == 2);
    try std.testing.expect(config.mime_types.len == 9);
}

test "CompressionLevel.toBrotliQuality" {
    try std.testing.expect(comp.CompressionLevel.fastest.toBrotliQuality() == 1);
    try std.testing.expect(comp.CompressionLevel.default.toBrotliQuality() == 6);
    try std.testing.expect(comp.CompressionLevel.best.toBrotliQuality() == 11);
}

test "CompressionLevel.toOptions" {
    _ = comp.CompressionLevel.level_1.toOptions();
    _ = comp.CompressionLevel.default.toOptions();
    _ = comp.CompressionLevel.best.toOptions();
}
