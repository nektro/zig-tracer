const std = @import("std");
const tracer = @import("./mod.zig");
const alloc = std.heap.c_allocator;
const log = std.log.scoped(.tracer);
const root = @import("root");
const linux = @import("sys-linux");

var pid: linux.pid_t = undefined;
threadlocal var tid: linux.pid_t = undefined;
threadlocal var path: []const u8 = undefined;
threadlocal var file: std.fs.File = undefined;
threadlocal var buffered_writer: std.io.BufferedWriter(4096, std.fs.File.Writer) = undefined;

pub fn init() !void {
    pid = linux.getpid();
}

pub fn deinit() void {
    //
}

pub fn init_thread(dir: std.fs.Dir) !void {
    tid = linux.gettid();

    path = try std.fmt.allocPrint(alloc, "trace.{d}.{d}.chrome.json", .{ pid, tid });
    file = try dir.createFile(path, .{});
    buffered_writer = std.io.bufferedWriter(file.writer());

    try buffered_writer.writer().writeAll("[\n");
}

pub fn deinit_thread() void {
    defer alloc.free(path);
    defer file.close();

    buffered_writer.writer().writeAll("]\n") catch {};
    buffered_writer.flush() catch {};
}

pub inline fn trace_begin(ctx: tracer.Ctx, comptime ifmt: []const u8, iargs: anytype) void {
    buffered_writer.writer().print(
        \\{{"cat":"function", "name":"{s}:{d}:{d} ({s})
    ++ ifmt ++
        \\", "ph": "B", "pid": {d}, "tid": {d}, "ts": {d}}},
        \\
    ,
        .{
            ctx.src.file,
            ctx.src.line,
            ctx.src.column,
            ctx.src.fn_name,
        } ++ iargs ++ .{
            pid,
            tid,
            std.time.microTimestamp(),
        },
    ) catch {};
}

pub inline fn trace_end(ctx: tracer.Ctx) void {
    _ = ctx;
    buffered_writer.writer().print(
        \\{{"cat":"function", "ph": "E", "pid": {d}, "tid": {d}, "ts": {d}}},
        \\
    ,
        .{
            pid,
            tid,
            std.time.microTimestamp(),
        },
    ) catch {};
}
