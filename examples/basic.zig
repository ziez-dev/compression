const std = @import("std");
const ziez = @import("ziez");
const comp = @import("ziez_compression");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();

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

    try app.listen(io, "0.0.0.0:3000");
}
