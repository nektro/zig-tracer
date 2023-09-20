const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;

    const mod = b.addModule("tracer", .{ .source_file = .{ .path = "src/mod.zig" } });

    const options = b.addOptions();
    options.addOption(usize, "src_file_trimlen", std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?.len);

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });
    exe.linkLibC();
    exe.addModule("tracer", mod);
    exe.addOptions("build_options", options);
    b.installArtifact(exe);
}
