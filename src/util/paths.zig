//! Path manipulation utilities.
//!
//! Provides helpers for normalizing paths, splitting comma-separated lists,
//! and extracting file extensions. All functions operate on byte slices and
//! avoid heap allocation unless explicitly stated.

const std = @import("std");

/// Returns the lowercase file extension (without the dot) for a path,
/// or `null` if there is no extension.
pub fn extension(path: []const u8) ?[]const u8 {
    const basename = std.fs.path.basename(path);
    const dot = std.mem.lastIndexOfScalar(u8, basename, '.') orelse return null;
    if (dot == 0) return null;
    return basename[dot + 1 ..];
}

/// Splits a comma-separated string into a list of trimmed slices.
/// Caller owns the returned slice (the outer array); inner slices point into `input`.
pub fn splitComma(allocator: std.mem.Allocator, input: []const u8) ![][]const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    defer list.deinit(allocator);

    var it = std.mem.splitScalar(u8, input, ',');
    while (it.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t");
        if (trimmed.len > 0) {
            try list.append(allocator, trimmed);
        }
    }

    return try list.toOwnedSlice(allocator);
}

/// Joins path components using the platform separator.
/// Caller owns the returned slice.
pub fn join(allocator: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    return std.fs.path.join(allocator, parts);
}

/// Returns true if `path` ends with `suffix`.
pub fn endsWith(path: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, path, suffix);
}

/// Returns true if `path` contains `component` as a directory component.
pub fn containsComponent(path: []const u8, component: []const u8) bool {
    var it = std.mem.splitScalar(u8, path, std.fs.path.sep);
    while (it.next()) |part| {
        if (std.mem.eql(u8, part, component)) return true;
    }
    return false;
}

test "extension extracts file extension" {
    try std.testing.expectEqualStrings("zig", extension("src/main.zig").?);
    try std.testing.expectEqualStrings("go", extension("foo.go").?);
    try std.testing.expect(extension("Makefile") == null);
    try std.testing.expect(extension(".gitignore") == null);
}

test "splitComma splits and trims" {
    const allocator = std.testing.allocator;
    const parts = try splitComma(allocator, "Go, Rust ,, Zig");
    defer allocator.free(parts);
    try std.testing.expectEqual(@as(usize, 3), parts.len);
    try std.testing.expectEqualStrings("Go", parts[0]);
    try std.testing.expectEqualStrings("Rust", parts[1]);
    try std.testing.expectEqualStrings("Zig", parts[2]);
}

test "containsComponent finds directory" {
    try std.testing.expect(containsComponent("src/node_modules/foo", "node_modules"));
    try std.testing.expect(!containsComponent("src/foo", "node_modules"));
}
