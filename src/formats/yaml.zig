//! YAML output formatter.
//!
//! Produces a simple YAML structure with per-language and summary results.

const std = @import("std");
const stats = @import("../counter/statistics.zig");
const commands = @import("../cli/commands.zig");

pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    try writer.print("# zcloc {s}\n", .{commands.version_string});
    try writer.writeAll("---\n");
    try writer.writeAll("header:\n");
    try writer.writeAll("  cloc_url: https://github.com/zcloc/zcloc\n");
    try writer.print("  cloc_version: \"{s}\"\n", .{commands.version_string});
    try writer.writeAll("languages:\n");

    for (summary.by_language) |lang| {
        try writer.print("  {s}:\n", .{lang.language});
        try writer.print("    files: {d}\n", .{lang.files});
        try writer.print("    blank: {d}\n", .{lang.blank});
        try writer.print("    comment: {d}\n", .{lang.comment});
        try writer.print("    code: {d}\n", .{lang.code});
    }

    try writer.writeAll("sum:\n");
    try writer.print("  files: {d}\n", .{summary.total_files});
    try writer.print("  blank: {d}\n", .{summary.total_blank});
    try writer.print("  comment: {d}\n", .{summary.total_comment});
    try writer.print("  code: {d}\n", .{summary.total_code});

    if (summary.by_file) |files| {
        try writer.writeAll("by_file:\n");
        for (files) |f| {
            try writer.print("  - path: \"{s}\"\n", .{f.path});
            try writer.print("    language: \"{s}\"\n", .{f.language});
            try writer.print("    blank: {d}\n", .{f.blank});
            try writer.print("    comment: {d}\n", .{f.comment});
            try writer.print("    code: {d}\n", .{f.code});
        }
    }
}

test "write produces YAML" {
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
    try std.testing.expect(std.mem.indexOf(u8, output, "languages:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Zig:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "sum:") != null);
}
