//! Directory walker.
//!
//! Recursively walks directories and yields file paths. Applies filtering
//! based on exclude directories, gitignore, and clocignore patterns.
//! Supports both full directory walks and git-tracked-file mode.

const std = @import("std");
const reg = @import("../languages/registry.zig");
const gitignore = @import("../git/ignore.zig");
const clocignore = @import("../config/local.zig");
const paths_util = @import("../util/paths.zig");

/// A file entry discovered by the walker.
pub const Entry = struct {
    path: []const u8,
    language: ?*const reg.LanguageDefinition,
};

/// Walker configuration.
pub const WalkerConfig = struct {
    exclude_dirs: []const []const u8 = &.{},
    exclude_extensions: []const []const u8 = &.{},
    include_lang: ?[]const []const u8 = null,
    exclude_lang: ?[]const []const u8 = null,
    match_f: ?[]const u8 = null,
    not_match_f: ?[]const u8 = null,
    gitignore: ?*const gitignore.GitIgnore = null,
    clocignore: ?*const clocignore.LocalIgnore = null,
};

/// Recursively walks `root` and returns all matching file entries.
/// Caller owns the returned slice; each entry's `path` is also owned.
pub fn walk(allocator: std.mem.Allocator, io: std.Io, root: []const u8, config: WalkerConfig) ![]Entry {
    var entries: std.ArrayList(Entry) = .empty;
    defer entries.deinit(allocator);

    try walkDir(allocator, io, root, root, config, &entries);

    return try entries.toOwnedSlice(allocator);
}

/// Recursively walks a single directory.
fn walkDir(allocator: std.mem.Allocator, io: std.Io, root: []const u8, current: []const u8, config: WalkerConfig, entries: *std.ArrayList(Entry)) !void {
    var dir = std.Io.Dir.cwd().openDir(io, current, .{ .iterate = true }) catch return;
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |fs_entry| {
        if (std.mem.eql(u8, fs_entry.name, ".") or std.mem.eql(u8, fs_entry.name, "..")) continue;

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ current, fs_entry.name }) catch continue;

        const rel_path = if (std.mem.startsWith(u8, full_path, root))
            full_path[root.len..]
        else
            full_path;

        if (fs_entry.kind == .directory) {
            if (shouldExcludeDir(fs_entry.name, rel_path, config)) continue;
            if (config.gitignore) |gi| {
                if (gi.isIgnored(rel_path, true)) continue;
            }
            if (config.clocignore) |ci| {
                if (ci.matches(rel_path, true)) continue;
            }
            try walkDir(allocator, io, root, full_path, config, entries);
        } else if (fs_entry.kind == .file or fs_entry.kind == .sym_link) {
            if (config.gitignore) |gi| {
                if (gi.isIgnored(rel_path, false)) continue;
            }
            if (config.clocignore) |ci| {
                if (ci.matches(rel_path, false)) continue;
            }

            const lang = reg.Registry.detect(fs_entry.name) orelse continue;
            if (!shouldIncludeLang(lang.name, config)) continue;
            if (shouldExcludeExt(fs_entry.name, config)) continue;
            if (!shouldMatchFile(rel_path, config)) continue;

            const path_copy = try allocator.dupe(u8, full_path);
            try entries.append(allocator, .{
                .path = path_copy,
                .language = lang,
            });
        }
    }
}

/// Returns true if a directory should be excluded.
fn shouldExcludeDir(name: []const u8, rel_path: []const u8, config: WalkerConfig) bool {
    for (config.exclude_dirs) |dir| {
        if (std.mem.eql(u8, name, dir)) return true;
        if (paths_util.containsComponent(rel_path, dir)) return true;
    }
    if (std.mem.eql(u8, name, ".git")) return true;
    return false;
}

/// Returns true if a language should be included.
fn shouldIncludeLang(lang_name: []const u8, config: WalkerConfig) bool {
    if (config.include_lang) |includes| {
        var found = false;
        for (includes) |inc| {
            if (std.ascii.eqlIgnoreCase(lang_name, inc)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }

    if (config.exclude_lang) |excludes| {
        for (excludes) |exc| {
            if (std.ascii.eqlIgnoreCase(lang_name, exc)) return false;
        }
    }

    return true;
}

/// Returns true if a file should be excluded by extension.
fn shouldExcludeExt(filename: []const u8, config: WalkerConfig) bool {
    if (config.exclude_extensions.len == 0) return false;

    const ext = paths_util.extension(filename) orelse return false;

    for (config.exclude_extensions) |exc_ext| {
        var exc = exc_ext;
        if (exc.len > 0 and exc[0] == '.') exc = exc[1..];
        if (std.ascii.eqlIgnoreCase(ext, exc)) return true;
    }
    return false;
}

/// Returns true if a file matches the regex filters.
/// Note: this is a simplified glob match, not full regex.
fn shouldMatchFile(rel_path: []const u8, config: WalkerConfig) bool {
    if (config.match_f) |pattern| {
        if (!simpleMatch(pattern, rel_path)) return false;
    }
    if (config.not_match_f) |pattern| {
        if (simpleMatch(pattern, rel_path)) return false;
    }
    return true;
}

/// Simplified pattern matcher: supports `*` and `?` wildcards.
fn simpleMatch(pattern: []const u8, text: []const u8) bool {
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

test "walk finds files in a directory" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(io, .{ .sub_path = "a.zig", .data = "const x = 1;\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "b.go", .data = "package main\n" });
    try tmp.dir.createDir(io, "sub", .default_dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "sub/c.zig", .data = "const y = 2;\n" });

    const path = ".zig-cache/tmp";

    const entries = try walk(allocator, io, path, .{});
    defer {
        for (entries) |e| allocator.free(e.path);
        allocator.free(entries);
    }

    try std.testing.expect(entries.len >= 3);
}

test "walk respects exclude_dirs" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(io, .{ .sub_path = "a.zig", .data = "const x = 1;\n" });
    try tmp.dir.createDir(io, "exclude_me", .default_dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "exclude_me/b.zig", .data = "const y = 2;\n" });

    const path = ".zig-cache/tmp";

    const entries = try walk(allocator, io, path, .{
        .exclude_dirs = &.{"exclude_me"},
    });
    defer {
        for (entries) |e| allocator.free(e.path);
        allocator.free(entries);
    }

    var found_excluded = false;
    for (entries) |e| {
        if (std.mem.indexOf(u8, e.path, "exclude_me") != null) {
            found_excluded = true;
        }
    }
    try std.testing.expect(!found_excluded);
}

test "shouldIncludeLang respects include_lang" {
    const config = WalkerConfig{
        .include_lang = &.{"Zig"},
    };
    try std.testing.expect(shouldIncludeLang("Zig", config));
    try std.testing.expect(!shouldIncludeLang("Go", config));
}

test "shouldIncludeLang respects exclude_lang" {
    const config = WalkerConfig{
        .exclude_lang = &.{"Go"},
    };
    try std.testing.expect(shouldIncludeLang("Zig", config));
    try std.testing.expect(!shouldIncludeLang("Go", config));
}

test "shouldExcludeDir checks .git" {
    const config = WalkerConfig{};
    try std.testing.expect(shouldExcludeDir(".git", ".git", config));
    try std.testing.expect(!shouldExcludeDir("src", "src", config));
}

test "simpleMatch wildcard" {
    try std.testing.expect(simpleMatch("*.zig", "main.zig"));
    try std.testing.expect(!simpleMatch("*.zig", "main.go"));
}
