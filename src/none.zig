const std = @import("std");
const tracer = @import("./mod.zig");
const log = std.log.scoped(.tracer);

pub fn init(args: struct {}) !void {
    _ = args;
}

pub fn deinit() void {}

pub fn init_thread(args: struct {}) !void {
    _ = args;
}

pub fn deinit_thread() void {}

pub inline fn trace_begin(src: std.builtin.SourceLocation, comptime ifmt: []const u8, iargs: anytype) void {
    _ = src;
    _ = ifmt;
    _ = iargs;
}

pub inline fn trace_end(ctx: tracer.Ctx) void {
    _ = ctx;
}

pub const Data = void;
