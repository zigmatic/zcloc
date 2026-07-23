//! Local ignore configuration (`.clocignore`).
//!
//! Reads project-specific ignore patterns from a `.clocignore` file.
//! Patterns follow gitignore-style syntax: one pattern per line, `#` for
//! comments, trailing `/` for directories, `*` wildcards.

const std = @import("std");

/// A single ignore pattern.
pub const Pattern = struct {
    text: []const u8,
    is_dir: bool = false,
};

/// A set of ignore patterns loaded from a `.clocignore` file.
pub const LocalIgnore = struct {
    patterns: []Pattern,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LocalIgnore) void {
        for (self.patterns) |p| self.allocator.free(p.text);
        self.allocator.free(self.patterns);
    }

    /// Returns true if `path` matches any pattern.
    pub fn matches(self: *const LocalIgnore, path: []const u8, is_dir: bool) bool {
        const basename = std.fs.path.basename(path);
        for (self.patterns) |p| {
            if (p.is_dir and !is_dir) continue;
            if (globMatch(p.text, basename) or globMatch(p.text, path)) return true;
        }
        return false;
    }
};

/// Loads a `.clocignore` file from the given directory.
/// Returns `null` if the file does not exist.
/// Caller must call `deinit` on the result.
pub fn load(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8) !?LocalIgnore {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.clocignore", .{dir_path}) catch return null;

    var file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return null;
    defer file.close(io);

    var buf: [4096]u8 = undefined;
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

/// Parses `.clocignore` content into a `LocalIgnore`.
pub fn parse(allocator: std.mem.Allocator, content: []const u8) !LocalIgnore {
    var list: std.ArrayList(Pattern) = .empty;
    defer list.deinit(allocator);

    var line_it = std.mem.splitScalar(u8, content, '\n');
    while (line_it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        const is_dir = line[line.len - 1] == '/';
        const text = if (is_dir) line[0 .. line.len - 1] else line;

        try list.append(allocator, .{
            .text = try allocator.dupe(u8, text),
            .is_dir = is_dir,
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
        \\coverage/
        \\dist/
        \\*.lock
        \\generated
    ;
    var li = try parse(allocator, content);
    defer li.deinit();

    try std.testing.expectEqual(@as(usize, 4), li.patterns.len);
    try std.testing.expect(li.patterns[0].is_dir);
    try std.testing.expectEqualStrings("coverage", li.patterns[0].text);
    try std.testing.expect(!li.patterns[3].is_dir);
    try std.testing.expectEqualStrings("generated", li.patterns[3].text);
}

test "matches directory pattern" {
    const allocator = std.testing.allocator;
    var li = try parse(allocator, "dist/\n");
    defer li.deinit();

    try std.testing.expect(li.matches("dist", true));
    try std.testing.expect(!li.matches("dist", false));
    try std.testing.expect(!li.matches("src", true));
}

test "matches glob pattern" {
    const allocator = std.testing.allocator;
    var li = try parse(allocator, "*.lock\n");
    defer li.deinit();

    try std.testing.expect(li.matches("package-lock.lock", false));
    try std.testing.expect(!li.matches("package.json", false));
}

test "globMatch basic" {
    try std.testing.expect(globMatch("*.zig", "main.zig"));
    try std.testing.expect(globMatch("*.zig", "main.zig"));
    try std.testing.expect(!globMatch("*.zig", "main.go"));
    try std.testing.expect(globMatch("test?file", "test_file"));
    try std.testing.expect(globMatch("*", "anything"));
}
