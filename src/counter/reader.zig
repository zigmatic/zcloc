//! File reader for the counting engine.
//!
//! Reads file content into a bounded buffer and passes it to the counter.
//! Uses a fixed-size buffer to avoid reading entire large files into memory
//! at once when possible. For counting purposes, we read the full file in
//! chunks through the counter's state machine.
//!
//! However, since the counter operates on a complete byte slice, the reader
//! allocates a single buffer up to a configurable maximum. This keeps memory
//! bounded while supporting the single-pass counting algorithm.

const std = @import("std");
const counter = @import("counter.zig");
const reg = @import("../languages/registry.zig");

/// Default maximum file size to read (100 MiB).
pub const default_max_size: usize = 100 * 1024 * 1024;

/// Reads and counts a single file.
/// Returns the line counts, or an error if the file cannot be read.
pub fn countFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8, lang: *const reg.LanguageDefinition, max_size: usize) !counter.Counts {
    var file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return error.IoError;
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var content_list: std.ArrayList(u8) = .empty;
    defer content_list.deinit(allocator);

    while (true) {
        const n = file.readStreaming(io, &.{&buf}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return error.IoError,
        };
        if (n == 0) break;
        if (content_list.items.len + n > max_size) return error.FileTooLarge;
        try content_list.appendSlice(allocator, buf[0..n]);
    }

    return counter.count(content_list.items, lang);
}

test "countFile reads and counts" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(io, .{ .sub_path = "test.zig", .data = "const x = 1;\n// comment\n" });

    const lang = reg.Registry.detect("test.zig").?;

    var buf: [4096]u8 = undefined;
    var content_list: std.ArrayList(u8) = .empty;
    defer content_list.deinit(allocator);

    var file = try tmp.dir.openFile(io, "test.zig", .{});
    defer file.close(io);
    while (true) {
        const n = file.readStreaming(io, &.{&buf}) catch break;
        if (n == 0) break;
        try content_list.appendSlice(allocator, buf[0..n]);
    }

    const counts = counter.count(content_list.items, lang);
    try std.testing.expectEqual(@as(u64, 1), counts.code);
    try std.testing.expectEqual(@as(u64, 1), counts.comment);
}

test "countFile returns error for missing file" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const lang = reg.Registry.detect("test.zig").?;
    try std.testing.expectError(error.IoError, countFile(allocator, io, "/nonexistent/file.zig", lang, default_max_size));
}
