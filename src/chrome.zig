const std = @import("std");
const tracer = @import("./mod.zig");
const alloc = std.heap.c_allocator;
const log = std.log.scoped(.tracer);
const root = @import("root");
const nfs = @import("nfs");
const nio = @import("nio");
const linux = @import("sys-linux");

var pid: linux.pid_t = undefined;
threadlocal var tid: linux.pid_t = undefined;
threadlocal var path: [:0]const u8 = undefined;
threadlocal var file: nfs.File = undefined;
threadlocal var buffered_writer: nio.BufferedWriter(4096, nfs.File) = undefined;

pub fn init() !void {
    pid = linux.getpid();
}

pub fn deinit() void {
    //
}

pub fn init_thread(dir: nfs.Dir) !void {
    tid = linux.gettid();

    path = try std.fmt.allocPrintZ(alloc, "trace.{d}.{d}.chrome.json", .{ pid, tid });
    file = try dir.createFile(path, .{});
    buffered_writer = .init(file);

    try buffered_writer.writeAll("[\n");
}

pub fn deinit_thread() void {
    defer alloc.free(path);
    defer file.close();

    buffered_writer.writeAll("]\n") catch {};
    buffered_writer.flush() catch {};
}

pub inline fn trace_begin(ctx: tracer.Ctx, comptime ifmt: []const u8, iargs: anytype) void {
    buffered_writer.print(
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
    buffered_writer.print(
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
