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

// export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
// export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
// export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces

// https://github.com/open-telemetry/opentelemetry-proto/tree/v1.10.0/opentelemetry/proto

pub fn init(args: struct {}) !void {
    _ = args;
}

pub fn deinit() void {
    _ = {};
}

threadlocal var allocator: std.mem.Allocator = undefined;
threadlocal var traces_endpoint: std.Uri = undefined;
threadlocal var trace_id: [16]u8 = undefined;
threadlocal var prev_span_id: ?[8]u8 = undefined;
threadlocal var spans: std.ArrayListUnmanaged([]const u8) = .empty;

pub fn init_thread(args: struct { std.mem.Allocator, std.Uri }) !void {
    allocator, traces_endpoint = args;
    trace_id = extras.randomBytes(16);
    prev_span_id = null;
}

pub fn deinit_thread() void {
    deinit_thread_inner() catch {};
    spans.clearAndFree(allocator);
}
fn deinit_thread_inner() !void {
    var instrumentation_scope: std.ArrayListUnmanaged(u8) = .empty;
    defer instrumentation_scope.deinit(allocator);
    {
        const w = instrumentation_scope.writer(allocator);
        try writef_string(w, 1, "github.com/nektro/zig-tracer");
        try writef_string(w, 2, "(hash)");
        try writef_len(w, 3, 0);
        try writef_varint(w, 4, 0);
    }
    var scope_spans: std.ArrayListUnmanaged(u8) = .empty;
    defer scope_spans.deinit(allocator);
    {
        const w = scope_spans.writer(allocator);
        try writef_len(w, 1, instrumentation_scope.items.len);
        try w.writeAll(instrumentation_scope.items);
        instrumentation_scope.clearAndFree(allocator);
        for (spans.items) |sp| {
            try writef_len(w, 2, sp.len);
            try w.writeAll(sp);
        }
    }
    var resource: std.ArrayListUnmanaged(u8) = .empty;
    defer resource.deinit(allocator);
    {
        const w = resource.writer(allocator);
        try writef_kv(w, 1, .{
            .@"telemetry.sdk.name" = "github.com/nektro/zig-tracer",
            .@"telemetry.sdk.version" = "(hash)",
            .@"telemetry.sdk.language" = "zig",
            .@"service.name" = root.otel_service_name,
            .@"os.type" = "linux",
        });
        try writef_varint(w, 2, 0);
    }
    var resource_spans: std.ArrayListUnmanaged(u8) = .empty;
    defer resource_spans.deinit(allocator);
    {
        const w = resource_spans.writer(allocator);
        try writef_len(w, 1, resource.items.len);
        try w.writeAll(resource.items);
        resource.clearAndFree(allocator);
        try writef_len(w, 2, scope_spans.items.len);
        try w.writeAll(scope_spans.items);
        scope_spans.clearAndFree(allocator);
    }
    var export_request: std.ArrayListUnmanaged(u8) = .empty;
    defer export_request.deinit(allocator);
    {
        const w = export_request.writer(allocator);
        try writef_len(w, 1, resource_spans.items.len);
        try w.writeAll(resource_spans.items);
        resource_spans.clearAndFree(allocator);
    }
    {
        var client: std.http.Client = .{ .allocator = allocator };
        defer client.deinit();
        var buf: [4096]u8 = @splat(0);
        var req = try client.open(.POST, traces_endpoint, .{
            .server_header_buffer = &buf,
            .headers = .{
                .content_type = .{ .override = "application/x-protobuf" },
            },
            .redirect_behavior = .not_allowed,
        });
        defer req.deinit();
        req.transfer_encoding = .{ .content_length = export_request.items.len };
        try req.send();
        try req.writeAll(export_request.items);
        try req.finish();
        try req.wait();
        if (req.response.status != .ok) std.log.scoped(.tracer).warn("otel: {s} {d}", .{ &trace_id, req.response.status });
    }
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
    const w = temp.writer(allocator);
    defer if (ctx.data.name.len > 0) allocator.free(ctx.data.name);
    try writef_bytes(w, 1, &trace_id);
    try writef_bytes(w, 2, &ctx.data.span_id);
    try writef_string(w, 3, "");
    if (ctx.data.parent_id) |*pi| try writef_bytes(w, 4, pi);
    try writef_string(w, 5, ctx.data.name);
    try writef_varint(w, 6, 2);
    try writef_i64(w, 7, @floatFromInt(ctx.data.time_start_ns));
    try writef_i64(w, 8, @floatFromInt(time.nanoTimestamp()));
    try spans.append(allocator, temp.items);
}

pub const Data = struct {
    span_id: [8]u8,
    parent_id: ?[8]u8,
    name: []const u8,
    time_start_ns: u64,
};

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

fn writef_len(w: anytype, nr: u64, l: u64) !void {
    try write_tag(w, nr, .len);
    try write_varint(w, l);
}

// https://opentelemetry.io/docs/specs/semconv/registry/attributes/
fn writef_kv(w: anytype, nr: u64, kvs: anytype) !void {
    var temp: std.ArrayListUnmanaged(u8) = .empty;
    defer temp.deinit(allocator);
    const x = temp.writer(allocator);

    var temp2: std.ArrayListUnmanaged(u8) = .empty;
    defer temp2.deinit(allocator);
    const y = temp2.writer(allocator);

    inline for (comptime std.meta.fields(@TypeOf(kvs))) |field| {
        try writef_string(x, 1, field.name);

        try writef_string(y, 1, @field(kvs, field.name));
        try writef_len(x, 2, temp2.items.len);
        try x.writeAll(temp2.items);
        temp2.clearRetainingCapacity();

        try writef_len(w, nr, temp.items.len);
        try w.writeAll(temp.items);
        temp.clearRetainingCapacity();
    }
}

fn writef_i64(w: anytype, nr: u64, i: f64) !void {
    try write_tag(w, nr, .i64);
    try w.writeAll(&std.mem.toBytes((i)));
}
