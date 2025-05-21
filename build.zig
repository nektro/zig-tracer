const std = @import("std");
const deps = @import("./deps.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.Mode, "mode", "") orelse .Debug;
    const disable_llvm = b.option(bool, "disable_llvm", "use the non-llvm zig codegen") orelse false;

    const mod = b.addModule("tracer", .{ .root_source_file = b.path("src/mod.zig") });

    addTest(b, target, mode, disable_llvm, mod, 0);
    addTest(b, target, mode, disable_llvm, mod, 1);
    addTest(b, target, mode, disable_llvm, mod, 2);
    addTest(b, target, mode, disable_llvm, mod, 3);

    const test_step = b.step("test", "Run all library tests");
    test_step.dependOn(b.getInstallStep());
}

fn addTest(b: *std.Build, target: std.Build.ResolvedTarget, mode: std.builtin.Mode, disable_llvm: bool, mod: *std.Build.Module, comptime backend: u8) void {
    _ = mod;
    const options = b.addOptions();
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
    exe.use_llvm = !disable_llvm;
    exe.use_lld = !disable_llvm;
    b.installArtifact(exe);
}
