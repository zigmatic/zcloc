//! JSON output formatter.
//!
//! Produces output compatible with `cloc --json`:
//!
//! ```json
//! {
//!   "header": {
//!     "cloc_url": "...",
//!     "cloc_version": "0.1.0"
//!   },
//!   "Zig": {
//!     "files": 2,
//!     "blank": 5,
//!     "comment": 3,
//!     "code": 20
//!   },
//!   "SUM": {
//!     "files": 3,
//!     "blank": 6,
//!     "comment": 3,
//!     "code": 30
//!   }
//! }
//! ```
//!
//! With `--percent`, each entry also includes `pct_code`, `pct_comment`,
//! `pct_blank`, and `pct_language` (share of total code).

const std = @import("std");
const stats = @import("../counter/statistics.zig");
const commands = @import("../cli/commands.zig");

pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    try writer.writeAll("{\n");
    try writer.writeAll("  \"header\": {\n");
    try writer.writeAll("    \"cloc_url\": \"https://github.com/zcloc/zcloc\",\n");
    try writer.print("    \"cloc_version\": \"{s}\"\n", .{commands.version_string});
    try writer.writeAll("  },\n");

    const total_code = summary.total_code;

    for (summary.by_language) |lang| {
        try writeLang(writer, lang, summary.percent, total_code);
        try writer.writeAll(",\n");
    }

    try writeSum(writer, summary);
    try writer.writeAll("\n");

    if (summary.by_file) |files| {
        try writer.writeAll(",\n  \"by_file\": [\n");
        for (files, 0..) |f, i| {
            try writer.print("    {{\"path\": \"{s}\", \"language\": \"{s}\", \"blank\": {d}, \"comment\": {d}, \"code\": {d}}}", .{
                f.path, f.language, f.blank, f.comment, f.code,
            });
            if (i < files.len - 1) try writer.writeAll(",\n") else try writer.writeAll("\n");
        }
        try writer.writeAll("  ]\n");
    }

    try writer.writeAll("}\n");
}

fn writeLang(writer: anytype, lang: stats.LangResult, percent: bool, total_code: u64) !void {
    try writer.print("  \"{s}\": {{\n", .{lang.language});
    try writer.print("    \"files\": {d},\n", .{lang.files});
    try writer.print("    \"blank\": {d},\n", .{lang.blank});
    try writer.print("    \"comment\": {d},\n", .{lang.comment});
    try writer.print("    \"code\": {d}", .{lang.code});
    if (percent) {
        const lang_total = lang.code + lang.comment + lang.blank;
        try writer.print(",\n    \"pct_code\": {d:.1},\n", .{stats.pct(lang.code, lang_total)});
        try writer.print("    \"pct_comment\": {d:.1},\n", .{stats.pct(lang.comment, lang_total)});
        try writer.print("    \"pct_blank\": {d:.1},\n", .{stats.pct(lang.blank, lang_total)});
        try writer.print("    \"pct_of_total\": {d:.1}", .{stats.pct(lang.code, total_code)});
    }
    try writer.writeAll("\n  }");
}

fn writeSum(writer: anytype, summary: *const stats.Summary) !void {
    try writer.writeAll("  \"SUM\": {\n");
    try writer.print("    \"files\": {d},\n", .{summary.total_files});
    try writer.print("    \"blank\": {d},\n", .{summary.total_blank});
    try writer.print("    \"comment\": {d},\n", .{summary.total_comment});
    try writer.print("    \"code\": {d}", .{summary.total_code});
    if (summary.percent) {
        const total_lines = summary.totalLines();
        try writer.print(",\n    \"pct_code\": {d:.1},\n", .{stats.pct(summary.total_code, total_lines)});
        try writer.print("    \"pct_comment\": {d:.1},\n", .{stats.pct(summary.total_comment, total_lines)});
        try writer.print("    \"pct_blank\": {d:.1}", .{stats.pct(summary.total_blank, total_lines)});
    }
    try writer.writeAll("\n  }");
}

test "write produces JSON" {
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
    try std.testing.expect(std.mem.indexOf(u8, output, "\"header\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"Zig\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"SUM\"") != null);
}

test "write produces JSON with percentages" {
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
    try std.testing.expect(std.mem.indexOf(u8, output, "pct_code") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "pct_comment") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "pct_blank") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "pct_of_total") != null);
}
