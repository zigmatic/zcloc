//! CSV output formatter.
//!
//! Produces a CSV with columns: language, files, blank, comment, code.

const std = @import("std");
const stats = @import("../counter/statistics.zig");

pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    try writer.writeAll("language,files,blank,comment,code\n");

    for (summary.by_language) |lang| {
        try writer.print("{s},{d},{d},{d},{d}\n", .{
            lang.language, lang.files, lang.blank, lang.comment, lang.code,
        });
    }

    try writer.print("SUM,{d},{d},{d},{d}\n", .{
        summary.total_files, summary.total_blank, summary.total_comment, summary.total_code,
    });

    if (summary.by_file) |files| {
        try writer.writeAll("\npath,language,blank,comment,code\n");
        for (files) |f| {
            try writer.print("{s},{s},{d},{d},{d}\n", .{
                f.path, f.language, f.blank, f.comment, f.code,
            });
        }
    }
}

test "write produces CSV" {
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
    try std.testing.expect(std.mem.indexOf(u8, output, "language,files") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Zig,2,5,3,20") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "SUM,2,5,3,20") != null);
}
