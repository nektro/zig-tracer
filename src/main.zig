const std = @import("std");
const tracer = @import("tracer");
const nfs = @import("nfs");

pub const build_options = @import("build_options");

pub const tracer_backend: tracer.Backend = @enumFromInt(build_options.backend);
pub const otel_service_name = "zig-tracer test";
pub const otel_service_version = build_options.version;

pub fn main() !void {
    try tracer.init(.{});
    defer tracer.deinit();

    // main loop
    var go = true;
    _ = &go;
    while (go) {
        try tracer.init_thread(switch (build_options.backend) {
            0, 1 => .{},
            2, 3 => .{try nfs.mkdtemp()},
            4 => .{ std.heap.c_allocator, try std.Uri.parse("http://localhost:4318/v1/traces") },
            else => comptime unreachable,
        });
        defer tracer.deinit_thread();

        handler();

        break;
    }
}

fn handler() void {
    const t = tracer.trace(@src(), "", .{});
    defer t.end();
}
