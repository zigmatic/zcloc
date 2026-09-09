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
//!
//! With `--percent`, adds three percentage columns:
//!
//! ```text
//! ----------------------------------------------------------------------------------------------------
//! Language                     files          blank        comment           code      %code   %comment    %blank
//! ----------------------------------------------------------------------------------------------------
//! ```

const std = @import("std");
const stats = @import("../counter/statistics.zig");

pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    if (summary.percent) {
        try writePercent(writer, summary);
    } else {
        try writePlain(writer, summary);
    }
}

fn writePlain(writer: anytype, summary: *const stats.Summary) !void {
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

fn writePercent(writer: anytype, summary: *const stats.Summary) !void {
    const sep = "----------------------------------------------------------------------------------------------------\n";

    try writer.writeAll(sep);
    try writer.print("{s:<24}{s:>12}{s:>12}{s:>12}{s:>14}{s:>10}{s:>10}{s:>10}\n", .{
        "Language", "files", "blank", "comment", "code", "%code", "%comment", "%blank",
    });
    try writer.writeAll(sep);

    for (summary.by_language) |lang| {
        const lang_total = lang.code + lang.comment + lang.blank;
        try writer.print("{s:<24}{d:>12}{d:>12}{d:>12}{d:>14}{d:>9.1}%{d:>9.1}%{d:>9.1}%\n", .{
            lang.language, lang.files, lang.blank, lang.comment, lang.code,
            stats.pct(lang.code, lang_total),
            stats.pct(lang.comment, lang_total),
            stats.pct(lang.blank, lang_total),
        });
    }

    try writer.writeAll(sep);
    const total_lines = summary.totalLines();
    try writer.print("{s:<24}{d:>12}{d:>12}{d:>12}{d:>14}{d:>9.1}%{d:>9.1}%{d:>9.1}%\n", .{
        "SUM:", summary.total_files, summary.total_blank, summary.total_comment, summary.total_code,
        stats.pct(summary.total_code, total_lines),
        stats.pct(summary.total_comment, total_lines),
        stats.pct(summary.total_blank, total_lines),
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

test "write produces table with percentages" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const lang_results = [_]stats.LangResult{
        .{ .language = "Zig", .files = 2, .blank = 5, .comment = 3, .code = 20 },
    };

    var summary = stats.Summary{
        .by_language = &lang_results,
        .total_files = 2,
        .total_blank = 5,
        .total_comment = 3,
        .total_code = 20,
        .percent = true,
        .allocator = std.testing.allocator,
    };

    try write(&writer, &summary);

    const output = writer.buffer[0..writer.end];
    try std.testing.expect(std.mem.indexOf(u8, output, "%code") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "%comment") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "%blank") != null);
}
