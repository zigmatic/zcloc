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
//! "code": 20
//!   },
//!   "SUM": {
//!     "files": 3,
//!     "blank": 6,
//!     "comment": 3,
//!     "code": 30
//!   }
//! }
//! ```

const std = @import("std");
const stats = @import("../counter/statistics.zig");
const commands = @import("../cli/commands.zig");

pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    try writer.writeAll("{\n");
    try writer.writeAll("  \"header\": {\n");
    try writer.writeAll("    \"cloc_url\": \"https://github.com/zcloc/zcloc\",\n");
    try writer.print("    \"cloc_version\": \"{s}\"\n", .{commands.version_string});
    try writer.writeAll("  },\n");

    for (summary.by_language, 0..) |lang, i| {
        try writeLang(writer, lang.language, lang.files, lang.blank, lang.comment, lang.code);
        if (i < summary.by_language.len or summary.by_file != null) {
            try writer.writeAll(",\n");
        } else {
            try writer.writeAll("\n");
        }
    }

    try writeLang(writer, "SUM", summary.total_files, summary.total_blank, summary.total_comment, summary.total_code);
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

fn writeLang(writer: anytype, name: []const u8, files: u64, blank: u64, comment: u64, code: u64) !void {
    try writer.print("  \"{s}\": {{\n", .{name});
    try writer.print("    \"files\": {d},\n", .{files});
    try writer.print("    \"blank\": {d},\n", .{blank});
    try writer.print("    \"comment\": {d},\n", .{comment});
    try writer.print("    \"code\": {d}\n", .{code});
    try writer.writeAll("  }");
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
