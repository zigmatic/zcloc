//! CLI command text: version, help, and usage strings.

const std = @import("std");

pub const version_string = "zcloc 0.1.0";

pub const help_text =
    \\Usage: zcloc [options] [target...]
    \\
    \\Count lines of code, comments, and blanks in files.
    \\
    \\Options:
    \\  --by-file              Count lines per file.
    \\  --by-file-by-lang      Count lines per file, grouped by language.
    \\  --include-lang=L1,L2   Only count these languages.
    \\  --exclude-lang=L1,L2   Exclude these languages.
    \\  --exclude-dir=D1,D2    Exclude these directories.
    \\  --match-f=PATTERN      Only count files matching this regex.
    \\  --not-match-f=PATTERN  Exclude files matching this regex.
    \\  --json                 Output in JSON format.
    \\  --csv                  Output in CSV format.
    \\  --yaml                 Output in YAML format.
    \\  --md                   Output in Markdown format.
    \\  --quiet                Suppress non-essential output.
    \\  --version              Show version and exit.
    \\  --help                 Show this help and exit.
    \\
    \\Extended options:
    \\  --tracked              Only count git-tracked files.
    \\  --no-gitignore         Ignore .gitignore files.
    \\  --no-clocignore        Ignore .clocignore files.
    \\  --strict               No fallback when git is unavailable.
    \\  --jobs=N               Number of worker threads (0 = auto).
    \\
    \\Configuration files (in priority order):
    \\  CLI flags              Highest priority
    \\  .clocignore            Project-specific ignores
    \\  ~/.config/zcloc/config.toml  Global config
    \\  ~/.clocrc              Global config (legacy)
    \\
    \\Examples:
    \\  zcloc .                Count current directory
    \\  zcloc src --by-file    Per-file results for src/
    \\  zcloc --json --quiet   JSON output, no extra text
    \\  zcloc --tracked        Only git-tracked files
    \\
;

pub fn printVersion(writer: anytype) !void {
    try writer.print("{s}\n", .{version_string});
}

pub fn printHelp(writer: anytype) !void {
    try writer.writeAll(help_text);
}

test "help text is non-empty" {
    try std.testing.expect(help_text.len > 100);
}

test "version string contains zcloc" {
    try std.testing.expect(std.mem.indexOf(u8, version_string, "zcloc") != null);
}
