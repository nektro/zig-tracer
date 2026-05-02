const std = @import("std");
const root = @import("root");
const extras = @import("extras");
const nfs = @import("nfs");
const backend: Backend = extras.globalOption("tracer_backend", Backend) orelse .none;
const impl = switch (backend) {
    .none => none,
    .log => log,
    .chrome => chrome,
    .spall => spall,
    .otel => otel,
};

pub const none = @import("./none.zig");
pub const log = @import("./log.zig");
pub const chrome = @import("./chrome.zig");
pub const spall = @import("./spall.zig");
pub const otel = @import("./otel.zig");

pub const Backend = enum {
    none,
    log,
    chrome,
    spall,
    otel,
};

threadlocal var started = false;

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
    return .{
        .src = src,
        .data = if (!started) undefined else impl.trace_begin(src, fmt, args),
    };
}

pub const Ctx = struct {
    src: std.builtin.SourceLocation,
    data: impl.Data,

    pub inline fn end(self: Ctx) void {
        if (!started) return;
        impl.trace_end(self);
    }
};
