//! Global configuration.
//!
//! Reads configuration from `~/.config/zcloc/config.toml` or `~/.clocrc`.
//! Supports a minimal TOML subset: arrays of strings and key = "value".
//! Unknown keys are silently ignored to remain forward-compatible.

const std = @import("std");

/// Global configuration values.
pub const GlobalConfig = struct {
    exclude_dirs: ?[][]const u8 = null,
    exclude_extensions: ?[][]const u8 = null,
    default_flags: ?[][]const u8 = null,

    pub fn deinit(self: *GlobalConfig, allocator: std.mem.Allocator) void {
        if (self.exclude_dirs) |v| {
            for (v) |s| allocator.free(s);
            allocator.free(v);
        }
        if (self.exclude_extensions) |v| {
            for (v) |s| allocator.free(s);
            allocator.free(v);
        }
        if (self.default_flags) |v| {
            for (v) |s| allocator.free(s);
            allocator.free(v);
        }
    }
};

/// Loads global config from the first available config file.
/// Returns an empty config if no file is found.
/// Caller must call `deinit` on the result.
pub fn load(allocator: std.mem.Allocator, io: std.Io, environ: ?*const std.process.Environ.Map) !GlobalConfig {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;

    if (environ) |env| {
        if (env.get("XDG_CONFIG_HOME")) |xdg| {
            const f = std.fmt.bufPrint(&path_buf, "{s}/zcloc/config.toml", .{xdg}) catch return GlobalConfig{};
            if (loadFromFile(allocator, io, f)) |cfg| return cfg else |_| {}
        }

        if (env.get("HOME")) |home| {
            const f = std.fmt.bufPrint(&path_buf, "{s}/.config/zcloc/config.toml", .{home}) catch return GlobalConfig{};
            if (loadFromFile(allocator, io, f)) |cfg| return cfg else |_| {}

            const legacy = std.fmt.bufPrint(&path_buf, "{s}/.clocrc", .{home}) catch return GlobalConfig{};
            if (loadFromFile(allocator, io, legacy)) |cfg| return cfg else |_| {}
        }
    }

    return GlobalConfig{};
}

/// Loads and parses a single config file.
fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !GlobalConfig {
    var file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return error.FileNotFound;
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var content_list: std.ArrayList(u8) = .empty;
    defer content_list.deinit(allocator);

    while (true) {
        const n = file.readStreaming(io, &.{&buf}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return error.FileNotFound,
        };
        if (n == 0) break;
        try content_list.appendSlice(allocator, buf[0..n]);
    }

    return parseToml(allocator, content_list.items);
}

/// Parses a minimal TOML subset.
/// Supports:
///   key = ["a", "b"]
///   key = "value"
fn parseToml(allocator: std.mem.Allocator, content: []const u8) !GlobalConfig {
    var config = GlobalConfig{};

    var line_it = std.mem.splitScalar(u8, content, '\n');
    while (line_it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq_pos], " \t");
        const val = std.mem.trim(u8, line[eq_pos + 1 ..], " \t");

        if (std.mem.eql(u8, key, "exclude_dirs")) {
            config.exclude_dirs = try parseStringArray(allocator, val);
        } else if (std.mem.eql(u8, key, "exclude_extensions")) {
            config.exclude_extensions = try parseStringArray(allocator, val);
        } else if (std.mem.eql(u8, key, "default_flags")) {
            config.default_flags = try parseStringArray(allocator, val);
        }
    }

    return config;
}

/// Parses a TOML array of strings: ["a", "b"] -> &.{ "a", "b" }
/// Caller owns the returned slice and its strings.
fn parseStringArray(allocator: std.mem.Allocator, val: []const u8) ![][]const u8 {
    if (val.len < 2 or val[0] != '[' or val[val.len - 1] != ']') return &.{};

    const inner = val[1 .. val.len - 1];
    var list: std.ArrayList([]const u8) = .empty;
    defer list.deinit(allocator);

    var elem_it = std.mem.splitScalar(u8, inner, ',');
    while (elem_it.next()) |raw_elem| {
        var elem = std.mem.trim(u8, raw_elem, " \t");
        if (elem.len >= 2 and elem[0] == '"' and elem[elem.len - 1] == '"') {
            elem = elem[1 .. elem.len - 1];
        }
        if (elem.len > 0) {
            try list.append(allocator, try allocator.dupe(u8, elem));
        }
    }

    return try list.toOwnedSlice(allocator);
}

test "parseToml parses exclude_dirs" {
    const allocator = std.testing.allocator;
    const content =
        \\exclude_dirs = ["node_modules", ".git", "dist"]
        \\exclude_extensions = [".png", ".jpg"]
    ;
    var cfg = try parseToml(allocator, content);
    defer cfg.deinit(allocator);

    try std.testing.expect(cfg.exclude_dirs != null);
    try std.testing.expectEqual(@as(usize, 3), cfg.exclude_dirs.?.len);
    try std.testing.expectEqualStrings("node_modules", cfg.exclude_dirs.?[0]);
    try std.testing.expectEqualStrings(".git", cfg.exclude_dirs.?[1]);
    try std.testing.expectEqualStrings("dist", cfg.exclude_dirs.?[2]);
}

test "parseToml parses default_flags" {
    const allocator = std.testing.allocator;
    const content = "default_flags = [\"--tracked\"]\n";
    var cfg = try parseToml(allocator, content);
    defer cfg.deinit(allocator);

    try std.testing.expect(cfg.default_flags != null);
    try std.testing.expectEqual(@as(usize, 1), cfg.default_flags.?.len);
    try std.testing.expectEqualStrings("--tracked", cfg.default_flags.?[0]);
}

test "parseToml ignores comments and unknown keys" {
    const allocator = std.testing.allocator;
    const content =
        \\# this is a comment
        \\unknown_key = "foo"
        \\exclude_dirs = ["build"]
    ;
    var cfg = try parseToml(allocator, content);
    defer cfg.deinit(allocator);

    try std.testing.expect(cfg.exclude_dirs != null);
    try std.testing.expectEqual(@as(usize, 1), cfg.exclude_dirs.?.len);
}

test "parseStringArray handles empty array" {
    const allocator = std.testing.allocator;
    const result = try parseStringArray(allocator, "[]");
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}
