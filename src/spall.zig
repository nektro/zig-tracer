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

    path = try std.fmt.allocPrint(alloc, "/data/trace.{d}.{d}.spall", .{ pid, tid });
    file = try std.fs.cwd().createFile(path, .{});
    buffered_writer = std.io.bufferedWriter(file.writer());

    try buffered_writer.writer().writeStruct(Header{});
}

pub fn deinit_thread() void {
    defer alloc.free(path);
    defer file.close();

    buffered_writer.flush() catch {};
    log.debug("{s}", .{path});
}

pub inline fn trace_begin(ctx: tracer.Ctx, comptime ifmt: []const u8, iargs: anytype) void {
    const fmt = "{s}:{d}:{d} ({s})" ++ ifmt;
    const args = .{
        if (ctx.src.file[0] == '/') ctx.src.file[trim_count..] else ctx.src.file,
        ctx.src.line,
        ctx.src.column,
        ctx.src.fn_name,
    };
    buffered_writer.writer().writeStruct(BeginEvent{
        .pid = @intCast(pid),
        .tid = @intCast(tid),
        .time = @floatFromInt(std.time.microTimestamp()),
        .name_len = @intCast(std.fmt.count(fmt, args ++ iargs)),
        .args_len = 0,
    }) catch return;
    buffered_writer.writer().print(fmt, args ++ iargs) catch return;
}

pub inline fn trace_end(ctx: tracer.Ctx) void {
    _ = ctx;
    buffered_writer.writer().writeStruct(EndEvent{
        .pid = @intCast(pid),
        .tid = @intCast(tid),
        .time = @floatFromInt(std.time.microTimestamp()),
    }) catch return;
}

// https://github.com/colrdavidson/spall-web/blob/1d4610a1fe9aaaf2e071327a1142a498f3436bdc/formats/spall/spall.odin
// https://github.com/colrdavidson/spall-web/blob/1d4610a1fe9aaaf2e071327a1142a498f3436bdc/tools/json2bin/json2bin.odin
// https://github.com/colrdavidson/spall-web/blob/1d4610a1fe9aaaf2e071327a1142a498f3436bdc/tools/upconvert/main.odin

// package spall

// MAGIC :: u64(0x0BADF00D)
const magic: u64 = 0x0BADF00D;

// V1_Header :: struct #packed {
//     magic:          u64,
//     version:        u64,
//     timestamp_unit: f64,
//     must_be_0:      u64,
// }
const Header = extern struct {
    magic: u64 align(1) = magic,
    version: u64 align(1) = 1,
    timestamp_unit: f64 align(1) = 1.0,
    must_be_0: u64 align(1) = 0,
};

// V1_Event_Type :: enum u8 {
//     Invalid             = 0,
//     Custom_Data         = 1, // Basic readers can skip this.
//     StreamOver          = 2,
//     Begin               = 3,
//     End                 = 4,
//     Instant             = 5,
//     Overwrite_Timestamp = 6, // Retroactively change timestamp units - useful for incrementally improving RDTSC frequency.
// }
const EventType = enum(u8) {
    invalid = 0,
    custom_data = 1,
    stream_over = 2,
    begin = 3,
    end = 4,
    instant = 5,
    overwrite_timestamp = 6,
};

// V1_Begin_Event :: struct #packed {
//     type:     V1_Event_Type,
//     category: u8,
//     pid:      u32,
//     tid:      u32,
//     time:     f64,
//     name_len: u8,
//     args_len: u8,
// }
const BeginEvent = extern struct {
    type: EventType align(1) = .begin,
    category: u8 align(1) = 0,
    pid: u32 align(1),
    tid: u32 align(1),
    time: f64 align(1),
    name_len: u8 align(1),
    args_len: u8 align(1),
};

// V1_End_Event :: struct #packed {
//     type: V1_Event_Type,
//     pid:  u32,
//     tid:  u32,
//     time: f64,
// }
const EndEvent = extern struct {
    type: EventType align(1) = .end,
    pid: u32 align(1),
    tid: u32 align(1),
    time: f64 align(1),
};
