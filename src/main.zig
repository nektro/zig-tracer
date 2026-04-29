const std = @import("std");
const tracer = @import("tracer");
const nfs = @import("nfs");

pub const build_options = @import("build_options");

pub const tracer_backend: tracer.Backend = @enumFromInt(build_options.backend);

pub fn main() !void {
    try tracer.init(.{});
    defer tracer.deinit();

    // main loop
    var go = false;
    _ = &go;
    while (go) {
        try tracer.init_thread(switch (build_options.backend) {
            0, 1 => .{},
            2, 3 => .{nfs.cwd()},
            else => comptime unreachable,
        });
        defer tracer.deinit_thread();

        handler();
    }
}

fn handler() void {
    const t = tracer.trace(@src(), "", .{});
    defer t.end();
}
