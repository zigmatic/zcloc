//! Diff table output formatter.
//!
//! Produces a table showing line count changes between two directories:
//!
//! ```text
//! Comparing: dir_a -> dir_b
//!
//! ----------------------------------------------------------------------------------------
//! Language                 files added    files removed      lines added     lines removed
//! ----------------------------------------------------------------------------------------
//! Zig                            2                 0               25                0
//! ----------------------------------------------------------------------------------------
//! SUM:                           2                 0               25                0
//! ----------------------------------------------------------------------------------------
//! ```

const std = @import("std");
const diff = @import("../counter/diff.zig");

pub fn write(writer: anytype, ds: *const diff.DiffSummary, label_a: []const u8, label_b: []const u8) !void {
    const sep = "----------------------------------------------------------------------------------------\n";

    try writer.print("Comparing: {s} -> {s}\n\n", .{ label_a, label_b });
    try writer.writeAll(sep);
    try writer.print("{s:<20}{s:>16}{s:>18}{s:>16}{s:>18}\n", .{
        "Language", "files added", "files removed", "lines added", "lines removed",
    });
    try writer.writeAll(sep);

    for (ds.by_language) |ld| {
        try writer.print("{s:<20}{d:>16}{d:>18}{d:>16}{d:>18}\n", .{
            ld.language, ld.files_added, ld.files_removed, ld.added, ld.removed,
        });
    }

    try writer.writeAll(sep);
    try writer.print("{s:<20}{d:>16}{d:>18}{d:>16}{d:>18}\n", .{
        "SUM:", ds.total_files_added, ds.total_files_removed, ds.total_added, ds.total_removed,
    });
    try writer.writeAll(sep);
}

test "write produces diff table" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const lang_diffs = [_]diff.LangDiff{
        .{ .language = "Zig", .added = 25, .removed = 0, .files_added = 2, .files_removed = 0 },
    };

    const ds = diff.DiffSummary{
        .by_language = @constCast(&lang_diffs),
        .total_added = 25,
        .total_removed = 0,
        .total_files_added = 2,
        .total_files_removed = 0,
        .allocator = std.testing.allocator,
    };

    try write(&writer, &ds, "dir_a", "dir_b");

    const output = writer.buffer[0..writer.end];
    try std.testing.expect(std.mem.indexOf(u8, output, "dir_a") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "dir_b") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "files added") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "SUM:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Zig") != null);
}

test "write handles empty diff" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const lang_diffs = [_]diff.LangDiff{};

    const ds = diff.DiffSummary{
        .by_language = @constCast(&lang_diffs),
        .total_added = 0,
        .total_removed = 0,
        .total_files_added = 0,
        .total_files_removed = 0,
        .allocator = std.testing.allocator,
    };

    try write(&writer, &ds, "a", "b");

    const output = writer.buffer[0..writer.end];
    try std.testing.expect(std.mem.indexOf(u8, output, "SUM:") != null);
}
