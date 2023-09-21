const std = @import("std");
const tracer = @import("./mod.zig");
const log = std.log.scoped(.tracer);

pub fn init() !void {}

pub fn deinit() void {}

pub fn init_thread() !void {}

pub fn deinit_thread() void {}

pub inline fn trace_begin(ctx: tracer.Ctx) void {
    log.debug("{s}:{d}:{d} ({s})", .{ ctx.src.file, ctx.src.line, ctx.src.column, ctx.src.fn_name });
}

pub inline fn trace_end(ctx: tracer.Ctx) void {
    _ = ctx;
}
