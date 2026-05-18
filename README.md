# ziez-compression

gzip/deflate/brotli response compression middleware for [ziez](https://github.com/ziez-dev/ziez).

## Requirements

- Zig 0.16.0+
- `libc-dev` on Linux (required for brotli C bindings)

## Installation

In `build.zig.zon`:

```zig
.dependencies = .{
    .ziez = .{
        .url = "https://github.com/ziez-dev/ziez/archive/refs/tags/v0.0.1.tar.gz",
        .hash = "ziez-0.0.1-zH20Gh1jAwADi2a_88hnfVHclInMW1YPLF_y7SS7CJ5Y",
    },
    .@"ziez-compression" = .{
        .url = "https://github.com/ziez-dev/compression/archive/refs/tags/v0.0.1.tar.gz",
        .hash = "1220b1fe03d61a1cc83ee28e918e1a2e4f0e0d6d1e23844e0c0e28194a8bbbe9d2e8",
    },
},
```

In `build.zig`:

```zig
const comp_dep = b.dependency("ziez-compression", .{
    .target = target,
    .optimize = optimize,
});
exe_mod.addImport("ziez_compression", comp_dep.module("ziez-compression"));
```

## Quick Start

```zig
const std = @import("std");
const ziez = @import("ziez");
const comp = @import("ziez_compression");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();


    var app = ziez.init(allocator);
    defer app.deinit();

    try comp.setup(&app, .{
        .threshold = 512,
        .algorithms = &.{ .gzip, .brotli },
    });

    app.get("/", struct {
        fn h(_: *ziez.Request, res: *ziez.Response) !void {
            res.json(.{ .message = "This response will be compressed!" });
        }
    }.h);

    try app.listen( "0.0.0.0:3000");
}
```

## Configuration

**CompressionConfig:**

| Option | Type | Default | Description |
|---|---|---|---|
| `enabled` | `bool` | `true` | Enable/disable compression |
| `threshold` | `usize` | `1024` | Minimum response size to compress (bytes) |
| `level` | `CompressionLevel` | `.default` | Compression level (`.fast`, `.default`, `.best`) |
| `algorithms` | `[]const Algorithm` | `&.{ .gzip, .deflate }` | Supported algorithms (`.gzip`, `.deflate`, `.brotli`) |
| `mime_types` | `[]const []const u8` | *(text/html, text/css, application/json, etc.)* | MIME types eligible for compression |

## License

MIT
