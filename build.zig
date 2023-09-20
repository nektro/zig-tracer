const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;

    const mod = b.addModule("tracer", .{ .source_file = .{ .path = "src/mod.zig" } });

    addTest(b, target, mode, mod, 0);
    addTest(b, target, mode, mod, 1);
    addTest(b, target, mode, mod, 2);
}

fn addTest(b: *std.Build, target: std.zig.CrossTarget, mode: std.builtin.Mode, mod: *std.build.Module, comptime backend: u8) void {
    const options = b.addOptions();
    options.addOption(usize, "src_file_trimlen", std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?.len);
    options.addOption(u8, "backend", backend);

    const exe = b.addExecutable(.{
        .name = "test" ++ std.fmt.comptimePrint("{d}", .{backend}),
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });
    exe.linkLibC();
    exe.addModule("tracer", mod);
    exe.addOptions("build_options", options);
    b.installArtifact(exe);
}
