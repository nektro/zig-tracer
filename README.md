# zig-tracer

![loc](https://sloc.xyz/github/nektro/zig-tracer)
[![license](https://img.shields.io/github/license/nektro/zig-tracer.svg)](https://github.com/nektro/zig-tracer/blob/master/LICENSE)
[![nektro @ github sponsors](https://img.shields.io/badge/sponsors-nektro-purple?logo=github)](https://github.com/sponsors/nektro)
[![Zig](https://img.shields.io/badge/Zig-0.14-f7a41d)](https://ziglang.org/)
[![Zigmod](https://img.shields.io/badge/Zigmod-latest-f7a41d)](https://github.com/nektro/zigmod)

Generic tracing library for Zig, supports multiple backends.

## Usage

in your program:

```zig
const std = @import("std");
const tracer = @import("tracer");
pub const build_options = @import("build_options");

pub const tracer_impl = tracer.spall; // see 'Backends' section below

pub fn main() !void {
    try tracer.init();
    defer tracer.deinit();

    // main loop
    while (true) {
        try tracer.init_thread();
        defer tracer.deinit_thread();

        handler();
    }
}

fn handler() void {
    const t = tracer.trace(@src());
    defer t.end();
}
```

`@src()` values are sometimes absolute paths so backends may use this value to trim it to only log relative paths

```zig
exe_options.addOption(usize, "src_file_trimlen", std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?.len);
```

## Backends

- `none` this is the default and causes tracing calls to become a no-op so that `tracer` can be added to libraries transparently
- `log` uses `std.log` to print on function entrance.
- `chrome` writes a json file in the `chrome://tracing` format described [here](https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview) and [here](https://www.chromium.org/developers/how-tos/trace-event-profiling-tool/).
- `spall` writes a binary file compatible with the [Spall](https://gravitymoth.com/spall/) profiler.
- more? feel free to open an issue with requests!

Any custom backend may also be used that defines the following functions:

- `pub fn init() !void`
- `pub fn deinit() void`
- `pub fn init_thread(dir: std.fs.Dir) !void`
- `pub fn deinit_thread() void`
- `pub inline fn trace_begin(ctx: tracer.Ctx, comptime ifmt: []const u8, iargs: anytype) void`
- `pub inline fn trace_end(ctx: tracer.Ctx) void`
