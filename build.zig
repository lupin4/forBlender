// build.zig - forBlender build system
// Copyright (C) The Fantastic Planet 2025 - By David Clabaugh
//
// forBlender is the Blender MCP server binary. It imports forAgent (the shared
// agent framework) and implements the Blender adapter with Blender-specific tools.
//
// Build commands:
//   zig build              # Build forBlender binary
//   zig build run          # Run the MCP server
//   zig build test         # Run tests

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // forAgent dependency (shared agent framework)
    const foragent_dep = b.dependency("foragent", .{
        .target = target,
        .optimize = optimize,
    });
    const foragent_module = foragent_dep.module("foragent");

    // Executable
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe_module.addImport("foragent", foragent_module);

    const exe = b.addExecutable(.{
        .name = "forBlender",
        .root_module = exe_module,
    });

    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the forBlender MCP server");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const test_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_module.addImport("foragent", foragent_module);

    const tests = b.addTest(.{
        .root_module = test_module,
    });
    tests.linkLibC();

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
