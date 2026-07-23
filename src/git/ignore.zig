//! `.gitignore` support.
//!
//! Parses `.gitignore` files and matches paths against the patterns.
//! Supports the most common gitignore syntax: `#` comments, trailing `/`
//! for directories, `*` and `?` wildcards, and `!` negation.

const std = @import("std");

/// A single gitignore pattern.
pub const Pattern = struct {
    text: []const u8,
    negated: bool = false,
    is_dir: bool = false,
    match_basename: bool = false,
};

/// A set of gitignore patterns.
pub const GitIgnore = struct {
    patterns: []Pattern,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *GitIgnore) void {
        for (self.patterns) |p| self.allocator.free(p.text);
        self.allocator.free(self.patterns);
    }

    /// Returns true if `path` is ignored by these patterns.
    /// `is_dir` indicates whether the path being tested is a directory.
    pub fn isIgnored(self: *const GitIgnore, path: []const u8, is_dir: bool) bool {
        const basename = std.fs.path.basename(path);
        var ignored = false;

        for (self.patterns) |p| {
            if (p.is_dir and !is_dir) continue;

            const matched = if (p.match_basename)
                globMatch(p.text, basename)
            else
                globMatch(p.text, path) or globMatch(p.text, basename);

            if (matched) {
                ignored = !p.negated;
            }
        }

        return ignored;
    }
};

/// Loads a `.gitignore` file from the given directory path.
/// Returns `null` if the file does not exist.
pub fn load(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8) !?GitIgnore {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.gitignore", .{dir_path}) catch return null;

    var file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return null;
    defer file.close(io);

    var buf: [8192]u8 = undefined;
    var content_list: std.ArrayList(u8) = .empty;
    defer content_list.deinit(allocator);

    while (true) {
        const n = file.readStreaming(io, &.{&buf}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return null,
        };
        if (n == 0) break;
        try content_list.appendSlice(allocator, buf[0..n]);
    }

    return try parse(allocator, content_list.items);
}

/// Parses `.gitignore` content into a `GitIgnore`.
pub fn parse(allocator: std.mem.Allocator, content: []const u8) !GitIgnore {
    var list: std.ArrayList(Pattern) = .empty;
    defer list.deinit(allocator);

    var line_it = std.mem.splitScalar(u8, content, '\n');
    while (line_it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        var text = line;
        var negated = false;

        if (text[0] == '!') {
            negated = true;
            text = text[1..];
        }

        const is_dir = text[text.len - 1] == '/';
        if (is_dir) text = text[0 .. text.len - 1];

        if (text.len > 0 and text[0] == '/') {
            text = text[1..];
        }

        const match_basename = !std.mem.containsAtLeast(u8, text, 1, "/");

        try list.append(allocator, .{
            .text = try allocator.dupe(u8, text),
            .negated = negated,
            .is_dir = is_dir,
            .match_basename = match_basename,
        });
    }

    return .{
        .patterns = try list.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

/// Simple glob matcher supporting `*` (any sequence) and `?` (any single char).
fn globMatch(pattern: []const u8, text: []const u8) bool {
    return globMatchRec(pattern, 0, text, 0);
}

fn globMatchRec(pattern: []const u8, pi: usize, text: []const u8, ti: usize) bool {
    if (pi == pattern.len) return ti == text.len;
    if (pattern[pi] == '*') {
        if (pi + 1 == pattern.len) return true;
        var i = ti;
        while (i <= text.len) : (i += 1) {
            if (globMatchRec(pattern, pi + 1, text, i)) return true;
        }
        return false;
    }
    if (ti == text.len) return false;
    if (pattern[pi] == '?' or pattern[pi] == text[ti]) {
        return globMatchRec(pattern, pi + 1, text, ti + 1);
    }
    return false;
}

test "parse basic patterns" {
    const allocator = std.testing.allocator;
    const content =
        \\# comment
        \\node_modules/
        \\*.log
        \\!important.log
        \\dist
    ;
    var gi = try parse(allocator, content);
    defer gi.deinit();

    try std.testing.expectEqual(@as(usize, 4), gi.patterns.len);
    try std.testing.expect(gi.patterns[0].is_dir);
    try std.testing.expectEqualStrings("node_modules", gi.patterns[0].text);
    try std.testing.expect(gi.patterns[2].negated);
    try std.testing.expectEqualStrings("important.log", gi.patterns[2].text);
}

test "isIgnored matches directory" {
    const allocator = std.testing.allocator;
    var gi = try parse(allocator, "node_modules/\n");
    defer gi.deinit();

    try std.testing.expect(gi.isIgnored("node_modules", true));
    try std.testing.expect(!gi.isIgnored("node_modules", false));
}

test "isIgnored matches glob" {
    const allocator = std.testing.allocator;
    var gi = try parse(allocator, "*.log\n");
    defer gi.deinit();

    try std.testing.expect(gi.isIgnored("debug.log", false));
    try std.testing.expect(!gi.isIgnored("debug.txt", false));
}

test "isIgnored respects negation" {
    const allocator = std.testing.allocator;
    var gi = try parse(allocator, "*.log\n!important.log\n");
    defer gi.deinit();

    try std.testing.expect(gi.isIgnored("debug.log", false));
    try std.testing.expect(!gi.isIgnored("important.log", false));
}

test "globMatch basic" {
    try std.testing.expect(globMatch("*.zig", "main.zig"));
    try std.testing.expect(!globMatch("*.zig", "main.go"));
    try std.testing.expect(globMatch("test?file", "test_file"));
}
