//! Markdown output formatter.
//!
//! Produces a GitHub-flavored Markdown table with results.
//! With `--percent`, adds % Code, % Comment, % Blank columns.

const std = @import("std");
const stats = @import("../counter/statistics.zig");

pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    if (summary.percent) {
        try writer.writeAll("| Language | Files | Blank | Comment | Code | % Code | % Comment | % Blank |\n");
        try writer.writeAll("|----------|-------|-------|---------|------|--------|-----------|---------|\n");
    } else {
        try writer.writeAll("| Language | Files | Blank | Comment | Code |\n");
        try writer.writeAll("|----------|-------|-------|---------|------|\n");
    }

    for (summary.by_language) |lang| {
        if (summary.percent) {
            const lang_total = lang.code + lang.comment + lang.blank;
            try writer.print("| {s} | {d} | {d} | {d} | {d} | {d:.1}% | {d:.1}% | {d:.1}% |\n", .{
                lang.language, lang.files, lang.blank, lang.comment, lang.code,
                stats.pct(lang.code, lang_total),
                stats.pct(lang.comment, lang_total),
                stats.pct(lang.blank, lang_total),
            });
        } else {
            try writer.print("| {s} | {d} | {d} | {d} | {d} |\n", .{
                lang.language, lang.files, lang.blank, lang.comment, lang.code,
            });
        }
    }

    if (summary.percent) {
        try writer.writeAll("|----------|-------|-------|---------|------|--------|-----------|---------|\n");
        const total_lines = summary.totalLines();
        try writer.print("| **SUM** | **{d}** | **{d}** | **{d}** | **{d}** | **{d:.1}%** | **{d:.1}%** | **{d:.1}%** |\n", .{
            summary.total_files, summary.total_blank, summary.total_comment, summary.total_code,
            stats.pct(summary.total_code, total_lines),
            stats.pct(summary.total_comment, total_lines),
            stats.pct(summary.total_blank, total_lines),
        });
    } else {
        try writer.writeAll("|----------|-------|-------|---------|------|\n");
        try writer.print("| **SUM** | **{d}** | **{d}** | **{d}** | **{d}** |\n", .{
            summary.total_files, summary.total_blank, summary.total_comment, summary.total_code,
        });
    }

    if (summary.by_file) |files| {
        try writer.writeAll("\n## Per-file results\n\n");
        try writer.writeAll("| File | Language | Blank | Comment | Code |\n");
        try writer.writeAll("|------|----------|-------|---------|------|\n");
        for (files) |f| {
            try writer.print("| {s} | {s} | {d} | {d} | {d} |\n", .{
                f.path, f.language, f.blank, f.comment, f.code,
            });
        }
    }
}

test "write produces Markdown" {
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
        .allocator = std.testing.allocator,
    };

    try write(&writer, &summary);

    const output = writer.buffer[0..writer.end];
    try std.testing.expect(std.mem.indexOf(u8, output, "| Language |") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "|----------|") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "**SUM**") != null);
}

test "write produces Markdown with percentages" {
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
    try std.testing.expect(std.mem.indexOf(u8, output, "% Code") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "% Comment") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "% Blank") != null);
}
