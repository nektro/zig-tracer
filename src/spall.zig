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

pub fn init() void {
    pid = std.os.linux.getpid();
}

pub fn deinit() void {
    //
}

pub fn init2() void {
    tid = std.os.linux.gettid();

    path = std.fmt.allocPrint(alloc, "/data/trace.{d}.{d}.spall.jsonl", .{ pid, tid }) catch @panic("oom");
    file = std.fs.cwd().createFile(path, .{}) catch @panic("create fail");
    file.writer().writeAll("[\n") catch @panic("[");
}

pub fn deinit2() void {
    defer alloc.free(path);
    defer file.close();

    file.writer().writeAll("]\n") catch {};
    log.debug("{s}", .{path});
}

pub inline fn trace_begin(ctx: tracer.Ctx) void {
    file.writer().print(
        \\{{"cat":"function", "name":"{s}:{d}:{d} ({s})", "ph": "B", "pid": {d}, "tid": {d}, "ts": {d}}},
        \\
    ,
        .{
            if (ctx.src.file[0] == '/') ctx.src.file[trim_count..] else ctx.src.file,
            ctx.src.line,
            ctx.src.column,
            ctx.src.fn_name,
            pid,
            tid,
            std.time.microTimestamp(),
        },
    ) catch {};
}

pub inline fn trace_end(ctx: tracer.Ctx) void {
    _ = ctx;
    file.writer().print(
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
