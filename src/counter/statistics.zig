//! Statistics tracking for counting results.
//!
//! Aggregates per-file and per-language line counts. Provides summary
//! views for the formatters.

const std = @import("std");

/// Per-file counting result.
pub const FileResult = struct {
    path: []const u8,
    language: []const u8,
    blank: u64 = 0,
    comment: u64 = 0,
    code: u64 = 0,
};

/// Per-language aggregated result.
pub const LangResult = struct {
    language: []const u8,
    files: u64 = 0,
    blank: u64 = 0,
    comment: u64 = 0,
    code: u64 = 0,
};

/// Top-level summary containing all results.
pub const Summary = struct {
    by_language: []const LangResult,
    by_file: ?[]const FileResult = null,
    total_files: u64 = 0,
    total_blank: u64 = 0,
    total_comment: u64 = 0,
    total_code: u64 = 0,
    percent: bool = false,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Summary) void {
        self.allocator.free(self.by_language);
        if (self.by_file) |bf| {
            for (bf) |f| self.allocator.free(f.path);
            self.allocator.free(bf);
        }
    }

    /// Returns the total line count (code + comment + blank).
    pub fn totalLines(self: *const Summary) u64 {
        return self.total_code + self.total_comment + self.total_blank;
    }
};

/// Returns the percentage of `part` relative to `total`, or 0.0 if total is 0.
pub fn pct(part: u64, total: u64) f64 {
    if (total == 0) return 0.0;
    return (@as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(total))) * 100.0;
}

/// Builder that accumulates results incrementally.
pub const StatsBuilder = struct {
    allocator: std.mem.Allocator,
    lang_map: std.StringHashMap(LangResult),
    file_list: std.ArrayList(FileResult),

    /// Creates a new builder. Call `deinit` when done.
    pub fn init(allocator: std.mem.Allocator) StatsBuilder {
        return .{
            .allocator = allocator,
            .lang_map = std.StringHashMap(LangResult).init(allocator),
            .file_list = .empty,
        };
    }

    pub fn deinit(self: *StatsBuilder) void {
        self.lang_map.deinit();
        self.file_list.deinit(self.allocator);
    }

    /// Adds a single file's counting result.
    pub fn addFile(self: *StatsBuilder, path: []const u8, language: []const u8, blank: u64, comment: u64, code: u64) !void {
        const path_copy = try self.allocator.dupe(u8, path);
        try self.file_list.append(self.allocator, .{
            .path = path_copy,
            .language = language,
            .blank = blank,
            .comment = comment,
            .code = code,
        });

        const gop = try self.lang_map.getOrPut(language);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{
                .language = language,
                .files = 0,
                .blank = 0,
                .comment = 0,
                .code = 0,
            };
        }
        gop.value_ptr.files += 1;
        gop.value_ptr.blank += blank;
        gop.value_ptr.comment += comment;
        gop.value_ptr.code += code;
    }

    /// Builds the final `Summary`. Caller must call `deinit` on it.
    /// After calling this, the builder is consumed and should not be used.
    pub fn build(self: *StatsBuilder, include_files: bool) !Summary {
        var lang_list: std.ArrayList(LangResult) = .empty;
        defer lang_list.deinit(self.allocator);

        var it = self.lang_map.iterator();
        while (it.next()) |entry| {
            try lang_list.append(self.allocator, entry.value_ptr.*);
        }

        std.mem.sort(LangResult, lang_list.items, {}, struct {
            fn lt(_: void, a: LangResult, b: LangResult) bool {
                if (a.code != b.code) return a.code > b.code;
                return std.mem.lessThan(u8, a.language, b.language);
            }
        }.lt);

        const by_language = try lang_list.toOwnedSlice(self.allocator);

        var total_files: u64 = 0;
        var total_blank: u64 = 0;
        var total_comment: u64 = 0;
        var total_code: u64 = 0;

        for (by_language) |lang| {
            total_files += lang.files;
            total_blank += lang.blank;
            total_comment += lang.comment;
            total_code += lang.code;
        }

        var by_file: ?[]FileResult = null;
        if (include_files) {
            std.mem.sort(FileResult, self.file_list.items, {}, struct {
                fn lt(_: void, a: FileResult, b: FileResult) bool {
                    return std.mem.lessThan(u8, a.path, b.path);
                }
            }.lt);
            by_file = try self.file_list.toOwnedSlice(self.allocator);
        } else {
            for (self.file_list.items) |f| self.allocator.free(f.path);
        }

        return .{
            .by_language = by_language,
            .by_file = by_file,
            .total_files = total_files,
            .total_blank = total_blank,
            .total_comment = total_comment,
            .total_code = total_code,
            .percent = false,
            .allocator = self.allocator,
        };
    }
};

test "StatsBuilder accumulates per language" {
    const allocator = std.testing.allocator;
    var builder = StatsBuilder.init(allocator);
    defer builder.deinit();

    try builder.addFile("a.zig", "Zig", 1, 2, 10);
    try builder.addFile("b.zig", "Zig", 0, 1, 5);
    try builder.addFile("c.go", "Go", 2, 0, 8);

    var summary = try builder.build(false);
    defer summary.deinit();

    try std.testing.expectEqual(@as(usize, 2), summary.by_language.len);
    try std.testing.expectEqual(@as(u64, 3), summary.total_files);
    try std.testing.expectEqual(@as(u64, 23), summary.total_code);
    try std.testing.expectEqual(@as(u64, 3), summary.total_comment);
    try std.testing.expectEqual(@as(u64, 3), summary.total_blank);
}

test "StatsBuilder includes files when requested" {
    const allocator = std.testing.allocator;
    var builder = StatsBuilder.init(allocator);
    defer builder.deinit();

    try builder.addFile("a.zig", "Zig", 1, 2, 10);
    try builder.addFile("b.zig", "Zig", 0, 1, 5);

    var summary = try builder.build(true);
    defer summary.deinit();

    try std.testing.expect(summary.by_file != null);
    try std.testing.expectEqual(@as(usize, 2), summary.by_file.?.len);
}

test "StatsBuilder sorts by code descending" {
    const allocator = std.testing.allocator;
    var builder = StatsBuilder.init(allocator);
    defer builder.deinit();

    try builder.addFile("a.zig", "Zig", 0, 0, 10);
    try builder.addFile("b.go", "Go", 0, 0, 50);
    try builder.addFile("c.py", "Python", 0, 0, 30);

    var summary = try builder.build(false);
    defer summary.deinit();

    try std.testing.expectEqualStrings("Go", summary.by_language[0].language);
    try std.testing.expectEqualStrings("Python", summary.by_language[1].language);
    try std.testing.expectEqualStrings("Zig", summary.by_language[2].language);
}
