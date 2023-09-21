# zig-tracer

Generic tracing library for Zig, supports multiple backends.

## Install

- Supports Zigmod
- Supports Zig package manager

## Usage

in your program:

```zig
const std = @import("std");
const tracer = @import("tracer");
pub const build_options = @import("build_options");

pub const tracer_impl = tracer.spall; // supports none, log, spall out of the box

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

`@src()` values are absolute paths so backends use this value to trim it to only log relative paths

```zig
exe_options.addOption(usize, "src_file_trimlen", std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?.len);
```

## License

MIT
