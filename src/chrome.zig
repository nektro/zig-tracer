const std = @import("std");
const tracer = @import("./mod.zig");
const alloc = std.heap.c_allocator;
const log = std.log.scoped(.tracer);
const root = @import("root");
const trim_count = root.build_options.src_file_trimlen;

var pid: std.os.linux.pid_t = undefined;
threadlocal var tid: std.os.linux.pid_t = undefined;
threadlocal var path: []const u8 = undefined;
threadlocal var file: std.fs.File = undefined;
threadlocal var buffered_writer: std.io.BufferedWriter(4096, std.fs.File.Writer) = undefined;

pub fn init() !void {
    pid = std.os.linux.getpid();
}

pub fn deinit() void {
    //
}

pub fn init_thread() !void {
    tid = std.os.linux.gettid();

    path = try std.fmt.allocPrint(alloc, "/data/trace.{d}.{d}.chrome.json", .{ pid, tid });
    file = try std.fs.cwd().createFile(path, .{});
    buffered_writer = std.io.bufferedWriter(file.writer());

    try buffered_writer.writer().writeAll("[\n");
}

pub fn deinit_thread() void {
    defer alloc.free(path);
    defer file.close();

    buffered_writer.writer().writeAll("]\n") catch {};
    buffered_writer.flush() catch {};
    log.debug("{s}", .{path});
}

pub inline fn trace_begin(ctx: tracer.Ctx, comptime ifmt: []const u8, iargs: anytype) void {
    buffered_writer.writer().print(
        \\{{"cat":"function", "name":"{s}:{d}:{d} ({s})
        ++ ifmt ++
            \\", "ph": "B", "pid": {d}, "tid": {d}, "ts": {d}}},
            \\
    ,
        .{
            if (ctx.src.file[0] == '/') ctx.src.file[trim_count..] else ctx.src.file,
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
