const std = @import("std");
const tracer = @import("tracer");
pub const build_options = @import("build_options");

pub const tracer_impl = switch (build_options.backend) {
    0 => tracer.none,
    1 => tracer.log,
    2 => tracer.spall,
    3 => tracer.chrome,
    else => unreachable,
};

pub fn main() !void {
    try tracer.init();
    defer tracer.deinit();

    // main loop
    var go = false;
    while (go) {
        try tracer.init_thread(std.fs.cwd());
        defer tracer.deinit_thread();

        handler();
    }
}

fn handler() void {
    const t = tracer.trace(@src(), "", .{});
    defer t.end();
}
