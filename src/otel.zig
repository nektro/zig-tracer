const std = @import("std");
const builtin = @import("builtin");
const tracer = @import("./mod.zig");
const root = @import("root");
const nfs = @import("nfs");
const nio = @import("nio");
const time = @import("time");
const extras = @import("extras");

const sys = switch (builtin.target.os.tag) {
    .linux => @import("sys-linux"),
    else => unreachable,
};

// export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
// export OTEL_EXPORTER_OTLP_PROTOCOL=http/json
// export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
// export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
// export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces

pub fn init(args: struct {}) !void {
    _ = args;
}

pub fn deinit() void {
    _ = {};
}

threadlocal var allocator: std.mem.Allocator = undefined;
threadlocal var memfd: nfs.File = undefined;
threadlocal var buffered_writer: nio.BufferedWriter(4096, nfs.File) = undefined;
threadlocal var trace_id: [16]u8 = undefined;
threadlocal var prev_span_id: ?[8]u8 = undefined;
threadlocal var spans: std.ArrayListUnmanaged([]const u8) = .empty;

pub fn init_thread(args: struct { std.mem.Allocator }) !void {
    std.log.debug("called otel init_thread", .{});
    allocator = args[0];
    memfd = try nfs.memfd_create("zig-tracer", 0);
    buffered_writer = .init(memfd);
    trace_id = extras.randomBytes(16);
    prev_span_id = null;

    // try write_tag(1, .varint);
    // try write_varint(150);
    // 0896 01
    // 1: 150

    // try write_tag(2, .len);
    // try write_varint(7);
    // try buffered_writer.writeAll("testing");
    // 1207 7465 7374 696e 67
    // 2: {"testing"}

    // try write_tag(3, .len);
    // try write_varint(3);
    // try write_tag(1, .varint);
    // try write_varint(150);
    // 1a03 0896 01
    // 3: {1: 150}

    // try write_tag(4, .len);
    // try write_varint(5);
    // try buffered_writer.writeAll("hello");
    // try write_tag(6, .varint);
    // try write_varint(3);
    // try write_tag(6, .varint);
    // try write_varint(270);
    // try write_tag(6, .varint);
    // try write_varint(86942);
    // 2205 6865 6c6c 6f30 0330 8e02 309e a705
    // 4: {"hello"}
    // 6: 3
    // 6: 270
    // 6: 86942

    // try write_tag(3, .sgroup);
    // try write_tag(1, .varint);
    // try write_varint(150);
    // try write_tag(3, .egroup);
    // 1b08 9601 1c
    // 3: !{1: 150}

    // try write_tag(4, .sgroup);
    // try write_tag(3, .sgroup);
    // try write_tag(1, .varint);
    // try write_varint(150);
    // try write_tag(3, .egroup);
    // try write_tag(4, .egroup);
    // 231b 0896 011c 24
    // 4: !{3: !{1: 150}}

}

pub fn deinit_thread() void {
    buffered_writer.flush() catch {};
    memfd.close();
}

pub fn trace_begin(src: std.builtin.SourceLocation, comptime ifmt: []const u8, iargs: anytype) Data {
    const span_id = extras.randomBytes(8);
    const parent_id = prev_span_id;
    prev_span_id = span_id;
    const fmt = "{s}:{d}:{d} ({s})" ++ ifmt;
    const args = .{ src.file, src.line, src.column, src.fn_name } ++ iargs;
    const name = std.fmt.allocPrint(allocator, fmt, args) catch "";
    const time_start_ns: u64 = @intCast(time.nanoTimestamp()); // this will overflow 2554 July 21 23:34:33.709 Z

    return .{
        .span_id = span_id,
        .parent_id = parent_id,
        .name = name,
        .time_start_ns = time_start_ns,
    };
}

pub fn trace_end(ctx: tracer.Ctx) void {
    trace_end_inner(ctx) catch {};
}
fn trace_end_inner(ctx: tracer.Ctx) !void {
    var temp: std.ArrayListUnmanaged(u8) = .empty;
    defer temp.deinit(allocator);
    const w = temp.writer(allocator);
    try writef_bytes(w, 1, &trace_id);
    try writef_bytes(w, 2, &ctx.data.span_id);
    if (ctx.data.parent_id) |*pi| try writef_bytes(w, 4, pi);
    try writef_string(w, 5, ctx.data.name);
    if (ctx.data.name.len > 0) allocator.free(ctx.data.name);
    try writef_varint(w, 6, 2);
    try writef_varint(w, 7, ctx.data.time_start_ns);
    try writef_varint(w, 8, @intCast(time.nanoTimestamp()));
    try spans.append(allocator, temp.items);
}

pub const Data = struct {
    span_id: [8]u8,
    parent_id: ?[8]u8,
    name: []const u8,
    time_start_ns: u64,
};

//
//

// https://github.com/open-telemetry/opentelemetry-proto/tree/v1.10.0/opentelemetry/proto

// message ExportTraceServiceRequest {
//   repeated opentelemetry.proto.trace.v1.ResourceSpans resource_spans = 1;
// }

// message ResourceSpans {
//   reserved 1000;
//   opentelemetry.proto.resource.v1.Resource resource = 1;
//   repeated ScopeSpans scope_spans = 2;
//   string schema_url = 3;
// }

// message Resource {
//   repeated opentelemetry.proto.common.v1.KeyValue attributes = 1;
//   uint32 dropped_attributes_count = 2;
// }

// message KeyValue {
//   string key = 1;
//   AnyValue value = 2;
// }

// message AnyValue {
//   oneof value {
//     string string_value = 1;
//     bool bool_value = 2;
//     int64 int_value = 3;
//     double double_value = 4;
//     ArrayValue array_value = 5;
//     KeyValueList kvlist_value = 6;
//     bytes bytes_value = 7;
//   }
// }

// message ArrayValue {
//   repeated AnyValue values = 1;
// }

// message KeyValueList {
//   repeated KeyValue values = 1;
// }

// message ScopeSpans {
//   opentelemetry.proto.common.v1.InstrumentationScope scope = 1;
//   repeated Span spans = 2;
//   string schema_url = 3;
// }

// message InstrumentationScope {
//   string name = 1;
//   string version = 2;
//   repeated KeyValue attributes = 3;
//   uint32 dropped_attributes_count = 4;
// }

// message Span {
//   bytes trace_id = 1;
//   bytes span_id = 2;
//   string trace_state = 3;
//   bytes parent_span_id = 4;
//   fixed32 flags = 16;
//   string name = 5;
//   SpanKind kind = 6;
//   fixed64 start_time_unix_nano = 7;
//   fixed64 end_time_unix_nano = 8;
//   repeated opentelemetry.proto.common.v1.KeyValue attributes = 9;
//   uint32 dropped_attributes_count = 10;
//   repeated Event events = 11;
//   uint32 dropped_events_count = 12;
//   repeated Link links = 13;
//   uint32 dropped_links_count = 14;
//   Status status = 15;
// }

// enum SpanKind {
//   SPAN_KIND_UNSPECIFIED = 0;
//   SPAN_KIND_INTERNAL = 1;
//   SPAN_KIND_SERVER = 2;
//   SPAN_KIND_CLIENT = 3;
//   SPAN_KIND_PRODUCER = 4;
//   SPAN_KIND_CONSUMER = 5;
// }

// message Event {
//   fixed64 time_unix_nano = 1;
//   string name = 2;
//   repeated opentelemetry.proto.common.v1.KeyValue attributes = 3;
//   uint32 dropped_attributes_count = 4;
// }

// message Link {
//   bytes trace_id = 1;
//   bytes span_id = 2;
//   string trace_state = 3;
//   repeated opentelemetry.proto.common.v1.KeyValue attributes = 4;
//   uint32 dropped_attributes_count = 5;
//   fixed32 flags = 6;
// }

//
//

const WireType = enum {
    varint,
    i64,
    len,
    sgroup,
    egroup,
    i32,
};

fn write_tag(w: anytype, nr: u64, ty: WireType) !void {
    var _nr = nr;
    _nr <<= 3;
    _nr |= @intFromEnum(ty);
    return write_varint(w, _nr);
}

fn write_varint(w: anytype, x: u64) !void {
    var _x = x;
    inline for (0..10) |i| {
        if (x < std.math.powi(u64, 2, 7 * (i + 1)) catch unreachable) {
            var b: [i + 1]u8 = @splat(0);
            for (b[0..i]) |*n| {
                n.* |= 128;
            }
            for (0..b.len) |j| {
                b[j] |= @intCast(_x & 127);
                _x >>= 7;
            }
            std.debug.assert(_x == 0);
            try w.writeAll(&b);
            return;
        }
    }
    unreachable;
}

fn writef_bytes(w: anytype, nr: u64, bs: []const u8) !void {
    try write_tag(w, nr, .len);
    try write_varint(w, bs.len);
    try w.writeAll(bs);
}

fn writef_string(w: anytype, nr: u64, bs: []const u8) !void {
    try write_tag(w, nr, .len);
    try write_varint(w, bs.len);
    try w.writeAll(bs);
}

fn writef_varint(w: anytype, nr: u64, i: u64) !void {
    try write_tag(w, nr, .varint);
    try write_varint(w, i);
}
