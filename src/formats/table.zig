//! Table output formatter.
//!
//! Produces output similar to `cloc`'s default tabular format:
//!
//! ```text
//! -------------------------------------------------------------------------------
//! Language                     files          blank        comment           code
//! -------------------------------------------------------------------------------
//! Zig                              2              5              3             20
//! Go                               1              1              0             10
//! -------------------------------------------------------------------------------
//! SUM:                             3              6              3             30
//! -------------------------------------------------------------------------------
//! ```

const std = @import("std");
const stats = @import("../counter/statistics.zig");

pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    const sep = "-------------------------------------------------------------------------------\n";

    try writer.writeAll(sep);
    try writer.print("{s:<24}{s:>12}{s:>12}{s:>12}{s:>14}\n", .{
        "Language", "files", "blank", "comment", "code",
    });
    try writer.writeAll(sep);

    for (summary.by_language) |lang| {
        try writer.print("{s:<24}{d:>12}{d:>12}{d:>12}{d:>14}\n", .{
            lang.language, lang.files, lang.blank, lang.comment, lang.code,
        });
    }

    try writer.writeAll(sep);
    try writer.print("{s:<24}{d:>12}{d:>12}{d:>12}{d:>14}\n", .{
        "SUM:", summary.total_files, summary.total_blank, summary.total_comment, summary.total_code,
    });
    try writer.writeAll(sep);
}

test "write produces table" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const lang_results = [_]stats.LangResult{
        .{ .language = "Zig", .files = 2, .blank = 5, .comment = 3, .code = 20 },
        .{ .language = "Go", .files = 1, .blank = 1, .comment = 0, .code = 10 },
    };

    var summary = stats.Summary{
        .by_language = &lang_results,
        .total_files = 3,
        .total_blank = 6,
        .total_comment = 3,
        .total_code = 30,
        .allocator = std.testing.allocator,
    };

    try write(&writer, &summary);

    const output = writer.buffer[0..writer.end];
    try std.testing.expect(std.mem.indexOf(u8, output, "Language") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "SUM:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Zig") != null);
}
