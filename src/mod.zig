const std = @import("std");
const root = @import("root");
const impl = std.meta.globalOption("tracer_impl", type) orelse none;

var started = false;

pub const none = @import("./none.zig");
pub const log = @import("./log.zig");
pub const spall = @import("./spall.zig");

pub fn init() !void {
    impl.init();
}

pub fn deinit() void {
    impl.deinit();
}

pub fn init2() !void {
    impl.init2();
    started = true;
}

pub fn deinit2() void {
    impl.deinit2();
}

pub inline fn trace(src: std.builtin.SourceLocation) Ctx {
    const ctx = Ctx{
        .src = src,
    };
    if (started) impl.trace_begin(ctx);
    return ctx;
}

pub const Ctx = struct {
    src: std.builtin.SourceLocation,

    pub inline fn end(self: Ctx) void {
        if (started) impl.trace_end(self);
    }
};
