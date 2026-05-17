const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .linux) .{ .abi = .musl } else .{},
    });
    const optimize = b.standardOptimizeOption(.{});

    const ziez_dep = b.dependency("ziez", .{
        .target = target,
        .optimize = optimize,
    });
    const ziez_mod = ziez_dep.module("ziez");

    // --- Brotli C library ---
    const brotli_lib = blk: {
        const upstream = b.dependency("brotli", .{});

        const brotli_root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = .off,
        });
        const lib = b.addLibrary(.{
            .name = "brotli_lib",
            .root_module = brotli_root_module,
        });
        lib.root_module.addIncludePath(upstream.path("c/include"));

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        const c_root = upstream.path("c");
        const c_sources = getCSources(arena_alloc, upstream.builder.build_root, b.graph.io, "c", b.allocator);
        defer b.allocator.free(c_sources);

        if (c_sources.len == 0) {
            std.debug.print("Error: no .c source files found in brotli/c\n", .{});
            return;
        }

        lib.root_module.addCSourceFiles(.{
            .root = c_root,
            .files = c_sources,
        });

        switch (target.result.os.tag) {
            .linux => lib.root_module.addCMacro("OS_LINUX", "1"),
            .freebsd => lib.root_module.addCMacro("OS_FREEBSD", "1"),
            .macos => lib.root_module.addCMacro("OS_MACOSX", "1"),
            .windows => lib.root_module.addCMacro("OS_WINDOWS", "1"),
            else => {},
        }

        b.installArtifact(lib);
        break :blk lib;
    };

    // --- Brotli C module (translate-c) ---
    const brotli_c_mod = blk: {
        const upstream = b.dependency("brotli", .{});
        const brotli_translate = b.addTranslateC(.{
            .root_source_file = b.path("include/brotli_c.h"),
            .target = target,
            .optimize = optimize,
        });
        brotli_translate.addIncludePath(upstream.path("c/include"));
        break :blk b.addModule("brotli_c", .{
            .root_source_file = brotli_translate.getOutput(),
        });
    };

    // --- Plugin module ---
    const plugin_mod = b.addModule("ziez-compression", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "ziez", .module = ziez_mod },
            .{ .name = "brotli_c", .module = brotli_c_mod },
        },
    });
    plugin_mod.linkLibrary(brotli_lib);

    // ── Tests (auto-discover tests/*.test.zig) ──────────────────────────────
    const test_step = b.step("test", "Run tests");
    const io = b.graph.io;

    var test_dir = b.build_root.handle.openDir(io, "tests", .{ .iterate = true }) catch return;
    defer test_dir.close(io);

    var walker = test_dir.walk(b.allocator) catch return;
    defer walker.deinit();

    while (walker.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".test.zig")) continue;

        const test_path = std.fmt.allocPrint(b.allocator, "tests/{s}", .{entry.path}) catch continue;

        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ziez", .module = ziez_mod },
                .{ .name = "brotli_c", .module = brotli_c_mod },
                .{ .name = "ziez_compression", .module = b.addModule("ziez_compression_test", .{
                    .root_source_file = b.path("src/root.zig"),
                    .imports = &.{
                        .{ .name = "ziez", .module = ziez_mod },
                        .{ .name = "brotli_c", .module = brotli_c_mod },
                    },
                }) },
            },
        });
        test_mod.linkLibrary(brotli_lib);

        const unit_test = b.addTest(.{
            .root_module = test_mod,
        });

        const run_unit_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_unit_test.step);
    }
}

fn getCSources(arena: std.mem.Allocator, parent: std.Build.Cache.Directory, io: std.Io, dir_path: []const u8, allocator: std.mem.Allocator) [][]const u8 {
    var cr_dir = parent.handle.openDir(io, dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("Error: {}, opening {s}\n", .{ err, dir_path });
        return &[_][]const u8{};
    };
    defer cr_dir.close(io);

    var walker = cr_dir.walk(arena) catch |err| {
        std.debug.print("Error: {}, walking {s}\n", .{ err, dir_path });
        return &[_][]const u8{};
    };
    defer walker.deinit();

    var list: std.ArrayListAligned([]const u8, null) = .empty;
    defer list.deinit(allocator);

    while (walker.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.path, "fuzz/")) continue;
        if (std.mem.startsWith(u8, entry.path, "tools/")) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".c")) continue;
        const duped = arena.dupe(u8, entry.path) catch continue;
        list.append(arena, duped) catch continue;
    }

    return list.toOwnedSlice(allocator) catch &[_][]const u8{};
}
