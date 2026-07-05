const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const parser_mod = b.addModule("parser", .{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Build fuzz target as object file (no entry point)
    const fuzz_obj = b.addObject(.{
        .name = "parse_fuzzer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fuzz/parse_fuzzer.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "parser", .module = parser_mod },
            },
        }),
    });
    b.installArtifact(fuzz_obj);
}
