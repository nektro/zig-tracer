const std = @import("std");
const tracer = @import("tracer");
pub const build_options = @import("build_options");

pub const tracer_impl = tracer.spall;

pub fn main() !void {
    try tracer.init();
    defer tracer.deinit();

    // main loop
    var go = false;
    while (go) {
        try tracer.init2();
        defer tracer.deinit2();

        handler();
    }
}

fn handler() void {
    const t = tracer.trace(@src());
    defer t.end();
}
