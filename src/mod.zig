const std = @import("std");
const root = @import("root");
const extras = @import("extras");
const nfs = @import("nfs");
const impl = extras.globalOption("tracer_impl", type) orelse none;

threadlocal var started = false;

pub const none = @import("./none.zig");
pub const log = @import("./log.zig");
pub const chrome = @import("./chrome.zig");
pub const spall = @import("./spall.zig");

pub fn init(args: @typeInfo(@TypeOf(impl.init)).@"fn".params[0].type.?) !void {
    try impl.init(args);
}

pub fn deinit() void {
    impl.deinit();
}

pub fn init_thread(args: @typeInfo(@TypeOf(impl.init_thread)).@"fn".params[0].type.?) !void {
    try impl.init_thread(args);
    started = true;
}

pub fn deinit_thread() void {
    impl.deinit_thread();
    started = false;
}

pub inline fn trace(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) Ctx {
    const ctx = Ctx{
        .src = src,
    };
    if (started) impl.trace_begin(ctx, fmt, args);
    return ctx;
}

pub const Ctx = struct {
    src: std.builtin.SourceLocation,

    pub inline fn end(self: Ctx) void {
        if (started) impl.trace_end(self);
    }
};
