//! CLI argument parser.
//!
//! Parses command-line arguments into a structured `Options` object.
//! Designed to be compatible with the most commonly used `cloc` flags.
//! Unknown flags produce `error.UnknownFlag` with the flag name as context.

const std = @import("std");
const paths = @import("../util/paths.zig");

/// Output format selection.
pub const Format = enum {
    table,
    json,
    yaml,
    csv,
    markdown,
};

/// All parsed command-line options.
pub const Options = struct {
    /// Target directories/files to count.
    targets: [][]const u8 = &.{},
    /// Count per-file results.
    by_file: bool = false,
    /// Count per-file, grouped by language.
    by_file_by_lang: bool = false,
    /// Only count these languages (by name).
    include_lang: ?[][]const u8 = null,
    /// Exclude these languages (by name).
    exclude_lang: ?[][]const u8 = null,
    /// Exclude these directories.
    exclude_dir: ?[][]const u8 = null,
    /// Include only files matching this regex.
    match_f: ?[]const u8 = null,
    /// Exclude files matching this regex.
    not_match_f: ?[]const u8 = null,
    /// Output format.
    format: Format = .table,
    /// Suppress non-essential output.
    quiet: bool = false,
    /// Show version and exit.
    version: bool = false,
    /// Show help and exit.
    help: bool = false,
    /// Only count git-tracked files.
    tracked: bool = false,
    /// Respect .gitignore files.
    respect_gitignore: bool = true,
    /// Respect .clocignore files.
    respect_clocignore: bool = true,
    /// Number of worker threads (0 = auto).
    jobs: u32 = 0,
    /// Strict mode: no fallback when git is unavailable.
    strict: bool = false,
    /// Show percentage breakdown of code/comment/blank.
    percent: bool = false,

    pub fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        for (self.targets) |t| allocator.free(t);
        allocator.free(self.targets);
        if (self.include_lang) |v| {
            allocator.free(v);
        }
        if (self.exclude_lang) |v| {
            allocator.free(v);
        }
        if (self.exclude_dir) |v| {
            allocator.free(v);
        }
    }
};

/// Parses raw argument strings into `Options`.
/// Caller must call `deinit` on the returned options.
pub fn parse(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    var opts: Options = .{};
    var targets: std.ArrayList([]const u8) = .empty;
    defer targets.deinit(allocator);

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (eql(arg, "--by-file")) {
            opts.by_file = true;
        } else if (eql(arg, "--by-file-by-lang")) {
            opts.by_file_by_lang = true;
        } else if (eql(arg, "--json")) {
            opts.format = .json;
        } else if (eql(arg, "--csv")) {
            opts.format = .csv;
        } else if (eql(arg, "--yaml") or eql(arg, "--yml")) {
            opts.format = .yaml;
        } else if (eql(arg, "--md") or eql(arg, "--markdown")) {
            opts.format = .markdown;
        } else if (eql(arg, "--quiet") or eql(arg, "-q")) {
            opts.quiet = true;
        } else if (eql(arg, "--version") or eql(arg, "-v")) {
            opts.version = true;
        } else if (eql(arg, "--help") or eql(arg, "-h")) {
            opts.help = true;
        } else if (eql(arg, "--tracked")) {
            opts.tracked = true;
        } else if (eql(arg, "--no-gitignore")) {
            opts.respect_gitignore = false;
        } else if (eql(arg, "--no-clocignore")) {
            opts.respect_clocignore = false;
        } else if (eql(arg, "--strict")) {
            opts.strict = true;
        } else if (eql(arg, "--percent")) {
            opts.percent = true;
        } else if (startsWith(arg, "--include-lang=")) {
            opts.include_lang = try paths.splitComma(allocator, arg["--include-lang=".len..]);
        } else if (startsWith(arg, "--exclude-lang=")) {
            opts.exclude_lang = try paths.splitComma(allocator, arg["--exclude-lang=".len..]);
        } else if (startsWith(arg, "--exclude-dir=")) {
            opts.exclude_dir = try paths.splitComma(allocator, arg["--exclude-dir=".len..]);
        } else if (startsWith(arg, "--match-f=")) {
            opts.match_f = arg["--match-f=".len..];
        } else if (startsWith(arg, "--not-match-f=")) {
            opts.not_match_f = arg["--not-match-f=".len..];
        } else if (startsWith(arg, "--jobs=")) {
            opts.jobs = std.fmt.parseInt(u32, arg["--jobs=".len..], 10) catch {
                return error.InvalidValue;
            };
        } else if (eql(arg, "--include-lang") or eql(arg, "--exclude-lang") or
            eql(arg, "--exclude-dir") or eql(arg, "--match-f") or
            eql(arg, "--not-match-f") or eql(arg, "--jobs"))
        {
            i += 1;
            if (i >= args.len) return error.MissingValue;
            const val = args[i];
            if (eql(arg, "--include-lang")) {
                opts.include_lang = try paths.splitComma(allocator, val);
            } else if (eql(arg, "--exclude-lang")) {
                opts.exclude_lang = try paths.splitComma(allocator, val);
            } else if (eql(arg, "--exclude-dir")) {
                opts.exclude_dir = try paths.splitComma(allocator, val);
            } else if (eql(arg, "--match-f")) {
                opts.match_f = val;
            } else if (eql(arg, "--not-match-f")) {
                opts.not_match_f = val;
            } else if (eql(arg, "--jobs")) {
                opts.jobs = std.fmt.parseInt(u32, val, 10) catch return error.InvalidValue;
            }
        } else if (startsWith(arg, "--")) {
            return error.UnknownFlag;
        } else if (startsWith(arg, "-") and arg.len > 1) {
            return error.UnknownFlag;
        } else {
            try targets.append(allocator, try allocator.dupe(u8, arg));
        }
    }

    if (targets.items.len == 0) {
        const dot = try allocator.dupe(u8, ".");
        opts.targets = try allocator.alloc([]const u8, 1);
        opts.targets[0] = dot;
    } else {
        opts.targets = try targets.toOwnedSlice(allocator);
    }

    return opts;
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn startsWith(s: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, s, prefix);
}

test "parse basic flags" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{ "--json", "--quiet", "src" });
    defer opts.deinit(allocator);

    try std.testing.expectEqual(Format.json, opts.format);
    try std.testing.expect(opts.quiet);
    try std.testing.expectEqual(@as(usize, 1), opts.targets.len);
    try std.testing.expectEqualStrings("src", opts.targets[0]);
}

test "parse default target is dot" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{});
    defer opts.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), opts.targets.len);
    try std.testing.expectEqualStrings(".", opts.targets[0]);
}

test "parse include-lang with equals" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{ "--include-lang=Go,Rust" });
    defer opts.deinit(allocator);

    try std.testing.expect(opts.include_lang != null);
    try std.testing.expectEqual(@as(usize, 2), opts.include_lang.?.len);
    try std.testing.expectEqualStrings("Go", opts.include_lang.?[0]);
    try std.testing.expectEqualStrings("Rust", opts.include_lang.?[1]);
}

test "parse include-lang with space" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{ "--include-lang", "Go,Rust" });
    defer opts.deinit(allocator);

    try std.testing.expect(opts.include_lang != null);
    try std.testing.expectEqual(@as(usize, 2), opts.include_lang.?.len);
}

test "parse unknown flag errors" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.UnknownFlag, parse(allocator, &.{"--bogus-flag"}));
}

test "parse missing value errors" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.MissingValue, parse(allocator, &.{"--include-lang"}));
}

test "parse version and help" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{"--version"});
    defer opts.deinit(allocator);
    try std.testing.expect(opts.version);

    var opts2 = try parse(allocator, &.{"--help"});
    defer opts2.deinit(allocator);
    try std.testing.expect(opts2.help);
}

test "parse multiple targets" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{ "src", "lib", "tests" });
    defer opts.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), opts.targets.len);
    try std.testing.expectEqualStrings("src", opts.targets[0]);
    try std.testing.expectEqualStrings("lib", opts.targets[1]);
    try std.testing.expectEqualStrings("tests", opts.targets[2]);
}

test "parse tracked flag" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{"--tracked"});
    defer opts.deinit(allocator);
    try std.testing.expect(opts.tracked);
}

test "parse percent flag" {
    const allocator = std.testing.allocator;
    var opts = try parse(allocator, &.{"--percent"});
    defer opts.deinit(allocator);
    try std.testing.expect(opts.percent);
}
