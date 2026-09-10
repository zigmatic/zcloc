//! Diff engine for comparing line counts between two directories.
//!
//! Counts both directories independently, then computes per-language
//! and total deltas (added, removed, modified).

const std = @import("std");
const stats = @import("statistics.zig");

/// Per-language diff result.
pub const LangDiff = struct {
    language: []const u8,
    added: u64 = 0,
    removed: u64 = 0,
    files_added: u64 = 0,
    files_removed: u64 = 0,
};

/// Top-level diff summary.
pub const DiffSummary = struct {
    by_language: []LangDiff,
    total_added: u64 = 0,
    total_removed: u64 = 0,
    total_files_added: u64 = 0,
    total_files_removed: u64 = 0,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DiffSummary) void {
        for (self.by_language) |ld| self.allocator.free(ld.language);
        self.allocator.free(self.by_language);
    }
};

/// Computes a diff between two summaries.
/// Caller must call `deinit` on the returned DiffSummary.
pub fn computeDiff(allocator: std.mem.Allocator, before: *const stats.Summary, after: *const stats.Summary) !DiffSummary {
    var lang_map = std.StringHashMap(LangDiff).init(allocator);
    defer lang_map.deinit();

    for (before.by_language) |lang| {
        const gop = try lang_map.getOrPut(lang.language);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{
                .language = try allocator.dupe(u8, lang.language),
            };
        }
        gop.value_ptr.removed += lang.code + lang.comment + lang.blank;
        gop.value_ptr.files_removed += lang.files;
    }

    for (after.by_language) |lang| {
        const gop = try lang_map.getOrPut(lang.language);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{
                .language = try allocator.dupe(u8, lang.language),
            };
        }
        gop.value_ptr.added += lang.code + lang.comment + lang.blank;
        gop.value_ptr.files_added += lang.files;
    }

    var lang_list: std.ArrayList(LangDiff) = .empty;
    defer lang_list.deinit(allocator);

    var it = lang_map.iterator();
    while (it.next()) |entry| {
        const ld = entry.value_ptr.*;
        const net = @as(i64, @intCast(ld.added)) - @as(i64, @intCast(ld.removed));
        if (net == 0 and ld.files_added == ld.files_removed) {
            allocator.free(ld.language);
            continue;
        }
        try lang_list.append(allocator, ld);
    }

    std.mem.sort(LangDiff, lang_list.items, {}, struct {
        fn lt(_: void, a: LangDiff, b: LangDiff) bool {
            const a_net = @as(i64, @intCast(a.added)) - @as(i64, @intCast(a.removed));
            const b_net = @as(i64, @intCast(b.added)) - @as(i64, @intCast(b.removed));
            const a_abs = if (a_net < 0) -a_net else a_net;
            const b_abs = if (b_net < 0) -b_net else b_net;
            if (a_abs != b_abs) return a_abs > b_abs;
            return std.mem.lessThan(u8, a.language, b.language);
        }
    }.lt);

    const by_language = try lang_list.toOwnedSlice(allocator);

    var total_added: u64 = 0;
    var total_removed: u64 = 0;
    var total_files_added: u64 = 0;
    var total_files_removed: u64 = 0;

    for (by_language) |ld| {
        total_added += ld.added;
        total_removed += ld.removed;
        total_files_added += ld.files_added;
        total_files_removed += ld.files_removed;
    }

    return .{
        .by_language = by_language,
        .total_added = total_added,
        .total_removed = total_removed,
        .total_files_added = total_files_added,
        .total_files_removed = total_files_removed,
        .allocator = allocator,
    };
}

test "computeDiff shows added language" {
    const allocator = std.testing.allocator;

    const before_langs = [_]stats.LangResult{};
    const before = stats.Summary{
        .by_language = &before_langs,
        .allocator = allocator,
    };

    const after_langs = [_]stats.LangResult{
        .{ .language = "Zig", .files = 2, .blank = 1, .comment = 1, .code = 10 },
    };
    const after = stats.Summary{
        .by_language = &after_langs,
        .total_files = 2,
        .total_blank = 1,
        .total_comment = 1,
        .total_code = 10,
        .allocator = allocator,
    };

    var diff = try computeDiff(allocator, &before, &after);
    defer diff.deinit();

    try std.testing.expectEqual(@as(usize, 1), diff.by_language.len);
    try std.testing.expectEqualStrings("Zig", diff.by_language[0].language);
    try std.testing.expectEqual(@as(u64, 12), diff.by_language[0].added);
    try std.testing.expectEqual(@as(u64, 0), diff.by_language[0].removed);
    try std.testing.expectEqual(@as(u64, 12), diff.total_added);
    try std.testing.expectEqual(@as(u64, 0), diff.total_removed);
}

test "computeDiff shows removed language" {
    const allocator = std.testing.allocator;

    const before_langs = [_]stats.LangResult{
        .{ .language = "Go", .files = 1, .blank = 0, .comment = 0, .code = 5 },
    };
    const before = stats.Summary{
        .by_language = &before_langs,
        .total_files = 1,
        .total_code = 5,
        .allocator = allocator,
    };

    const after_langs = [_]stats.LangResult{};
    const after = stats.Summary{
        .by_language = &after_langs,
        .allocator = allocator,
    };

    var diff = try computeDiff(allocator, &before, &after);
    defer diff.deinit();

    try std.testing.expectEqual(@as(usize, 1), diff.by_language.len);
    try std.testing.expectEqualStrings("Go", diff.by_language[0].language);
    try std.testing.expectEqual(@as(u64, 0), diff.by_language[0].added);
    try std.testing.expectEqual(@as(u64, 5), diff.by_language[0].removed);
}

test "computeDiff skips unchanged languages" {
    const allocator = std.testing.allocator;

    const before_langs = [_]stats.LangResult{
        .{ .language = "Zig", .files = 1, .blank = 0, .comment = 0, .code = 10 },
        .{ .language = "Go", .files = 1, .blank = 0, .comment = 0, .code = 5 },
    };
    const before = stats.Summary{
        .by_language = &before_langs,
        .total_files = 2,
        .total_code = 15,
        .allocator = allocator,
    };

    const after_langs = [_]stats.LangResult{
        .{ .language = "Zig", .files = 1, .blank = 0, .comment = 0, .code = 10 },
        .{ .language = "Go", .files = 1, .blank = 0, .comment = 0, .code = 8 },
    };
    const after = stats.Summary{
        .by_language = &after_langs,
        .total_files = 2,
        .total_code = 18,
        .allocator = allocator,
    };

    var diff = try computeDiff(allocator, &before, &after);
    defer diff.deinit();

    try std.testing.expectEqual(@as(usize, 1), diff.by_language.len);
    try std.testing.expectEqualStrings("Go", diff.by_language[0].language);
    try std.testing.expectEqual(@as(u64, 8), diff.by_language[0].added);
    try std.testing.expectEqual(@as(u64, 5), diff.by_language[0].removed);
}
