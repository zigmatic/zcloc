//! Simple benchmark for the counting engine.
//!
//! Run with: `zig build bench`
//!
//! Generates a large synthetic file and measures counting throughput.

const std = @import("std");
const counter = @import("counter/counter.zig");
const reg = @import("languages/registry.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const w = &stdout_file_writer.interface;

    const lang = reg.Registry.detect("bench.zig").?;

    const sizes = [_]usize{ 10_000, 100_000, 1_000_000 };

    for (sizes) |size| {
        const content = try generateFile(allocator, size);
        defer allocator.free(content);

        var timer = try std.time.Timer.start();

        const counts = counter.count(content, lang);
        const elapsed_ns = timer.read();

        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        const mb = @as(f64, @floatFromInt(content.len)) / (1024.0 * 1024.0);
        const throughput = if (elapsed_ns > 0)
            mb / (elapsed_ms / 1000.0)
        else
            0.0;

        try w.print("Lines: {d:>10} | Size: {d:>10} bytes ({d:.2} MB) | Time: {d:>8.2} ms | Throughput: {d:.2} MB/s | code={d} comment={d} blank={d}\n", .{
            size, content.len, mb, elapsed_ms, throughput, counts.code, counts.comment, counts.blank,
        });
    }

    try w.flush();
}

/// Generates a synthetic Zig file with `lines` lines.
fn generateFile(allocator: std.mem.Allocator, lines: usize) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    var i: usize = 0;
    while (i < lines) : (i += 1) {
        const remainder = i % 10;
        switch (remainder) {
            0 => try buf.appendSlice(allocator, "// comment line\n"),
            1 => try buf.appendSlice(allocator, "\n"),
            2 => try buf.appendSlice(allocator, "/// doc comment\n"),
            3 => try buf.appendSlice(allocator, "    const x = "),
            else => try buf.appendSlice(allocator, "    const v"),
        }
        if (remainder >= 3) {
            try buf.print(allocator, "{d};\n", .{i});
        }
    }

    return try buf.toOwnedSlice(allocator);
}
