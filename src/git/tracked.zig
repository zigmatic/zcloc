//! Git tracked-file detection.
//!
//! Uses `git ls-files` to enumerate files tracked by git. Falls back to
//! the full directory walk if git is not available or not in a repo.

const std = @import("std");
const repo = @import("repository.zig");

/// Returns a list of file paths tracked by git in the given directory.
/// Caller owns the returned slice and all strings within it.
pub fn listTracked(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8) ![][]const u8 {
    if (!repo.isRepositoryRecursive(io, dir_path)) {
        return error.NotARepository;
    }

    const argv: []const []const u8 = &.{ "git", "ls-files", "--cached", "--no-empty-directory" };

    const result = std.process.run(allocator, io, .{
        .argv = argv,
        .cwd = .{ .path = dir_path },
    }) catch return error.GitCommandFailed;

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| {
            if (code != 0) return error.GitCommandFailed;
        },
        else => return error.GitCommandFailed,
    }

    return try parseLsFiles(allocator, result.stdout);
}

/// Parses the output of `git ls-files` into a list of file paths.
fn parseLsFiles(allocator: std.mem.Allocator, output: []const u8) ![][]const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    defer list.deinit(allocator);

    var line_it = std.mem.splitScalar(u8, output, '\n');
    while (line_it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            try list.append(allocator, try allocator.dupe(u8, trimmed));
        }
    }

    return try list.toOwnedSlice(allocator);
}

test "parseLsFiles parses simple output" {
    const allocator = std.testing.allocator;
    const output = "main.zig\nsrc/foo.zig\nsrc/bar.zig\n";
    const files = try parseLsFiles(allocator, output);
    defer {
        for (files) |f| allocator.free(f);
        allocator.free(files);
    }

    try std.testing.expectEqual(@as(usize, 3), files.len);
    try std.testing.expectEqualStrings("main.zig", files[0]);
    try std.testing.expectEqualStrings("src/foo.zig", files[1]);
    try std.testing.expectEqualStrings("src/bar.zig", files[2]);
}

test "parseLsFiles handles empty output" {
    const allocator = std.testing.allocator;
    const files = try parseLsFiles(allocator, "");
    defer allocator.free(files);
    try std.testing.expectEqual(@as(usize, 0), files.len);
}
