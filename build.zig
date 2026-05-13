const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // internal module definitions
    // const mod_ast = b.addModule("ast", .{
    //     .root_source_file = b.path("src/Ast/Ast.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const mod_ = b.addModule("chips", .{
    //     .root_source_file = b.path("src/chips/chips.zig"),
    //     .target = target,
    //     .optimize = optimize,
    //     .imports = &.{
    //         .{ .name = "common", .module = mod_common },
    //     },
    // });

    const exe = b.addExecutable(.{
        .name = "monkey-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .optimize = optimize,
            .target = target,
            // .imports = &.{
            //     .{
            //         .name = "c",
            //         .module = translate_c.createModule(),
            //     },
            //     },
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
