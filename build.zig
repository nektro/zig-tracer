const std = @import("std");
const deps = @import("./deps.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;

    const mod = b.addModule("tracer", .{ .root_source_file = b.path("src/mod.zig") });

    addTest(b, target, mode, mod, 0);
    addTest(b, target, mode, mod, 1);
    addTest(b, target, mode, mod, 2);
    addTest(b, target, mode, mod, 3);

    const test_step = b.step("test", "dummy test step to pass CI checks");
    test_step.dependOn(b.default_step);
}

fn addTest(b: *std.Build, target: std.Build.ResolvedTarget, mode: std.builtin.Mode, mod: *std.Build.Module, comptime backend: u8) void {
    _ = mod;
    const options = b.addOptions();
    options.addOption(usize, "src_file_trimlen", std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?.len);
    options.addOption(u8, "backend", backend);

    const exe = b.addExecutable(.{
        .name = "test" ++ std.fmt.comptimePrint("{d}", .{backend}),
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = mode,
    });
    deps.addAllTo(exe);
    exe.linkLibC();
    exe.root_module.addImport("build_options", options.createModule());
    b.installArtifact(exe);
}
