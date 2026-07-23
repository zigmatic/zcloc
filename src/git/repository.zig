//! Git repository detection.
//!
//! Checks whether a path is inside a git repository by walking up the
//! directory tree looking for a `.git` entry.

const std = @import("std");

/// Walks up from `start_path` looking for `.git`. Returns true on first match.
pub fn isRepositoryRecursive(io: std.Io, start_path: []const u8) bool {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var current: []const u8 = start_path;

    while (true) {
        const git_path = std.fmt.bufPrint(&path_buf, "{s}/.git", .{current}) catch return false;
        std.Io.Dir.cwd().access(io, git_path, .{}) catch {
            if (std.mem.eql(u8, current, "/") or std.mem.eql(u8, current, ".")) {
                return false;
            }
            const parent = std.fs.path.dirname(current) orelse return false;
            if (std.mem.eql(u8, parent, current)) return false;
            current = parent;
            continue;
        };
        return true;
    }
}

/// Returns true if `start_path` itself contains a `.git` entry.
pub fn isRepository(io: std.Io, start_path: []const u8) bool {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const git_path = std.fmt.bufPrint(&path_buf, "{s}/.git", .{start_path}) catch return false;
    std.Io.Dir.cwd().access(io, git_path, .{}) catch return false;
    return true;
}

test "isRepositoryRecursive returns false for nonexistent" {
    const io = std.testing.io;
    try std.testing.expect(!isRepositoryRecursive(io, "/tmp/nonexistent_path_12345"));
}

test "isRepository returns false for nonexistent" {
    const io = std.testing.io;
    try std.testing.expect(!isRepository(io, "/tmp/nonexistent_path_12345"));
}
