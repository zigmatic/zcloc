//! Line counting engine.
//!
//! Counts blank, comment, and code lines in a byte buffer using a
//! data-driven `LanguageDefinition`. The algorithm is a single-pass state
//! machine that handles line comments, block comments (including nested
//! for Zig/Rust), strings, and blank lines.
//!
//! Complexity: O(n) in file size, single pass.
//! Memory: O(1) — no heap allocation during counting.

const std = @import("std");
const reg = @import("../languages/registry.zig");

/// Per-file line counts.
pub const Counts = struct {
    blank: u64 = 0,
    comment: u64 = 0,
    code: u64 = 0,
};

/// Counts lines in `content` using the language definition `lang`.
/// Returns the number of blank, comment, and code lines.
pub fn count(content: []const u8, lang: *const reg.LanguageDefinition) Counts {
    var counts = Counts{};

    if (content.len == 0) return counts;

    var in_block_comment = false;
    var block_depth: u32 = 0;

    const content_ends_with_newline = content[content.len - 1] == '\n';

    var line_it = std.mem.splitScalar(u8, content, '\n');

    while (line_it.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");

        if (in_block_comment) {
            const line_type = processBlockContent(line, lang, &in_block_comment, &block_depth);
            switch (line_type) {
                .comment => counts.comment += 1,
                .code => counts.code += 1,
                .blank => counts.blank += 1,
            }
            continue;
        }

        const trimmed = std.mem.trimStart(u8, line, " \t");

        if (trimmed.len == 0) {
            if (line_it.peek() != null or !content_ends_with_newline) {
                counts.blank += 1;
            }
            continue;
        }

        // Check if line starts with a block comment
        if (lang.block_comment_start.len > 0 and startsWith(trimmed, lang.block_comment_start)) {
            block_depth = 1;
            in_block_comment = true;
            const after_start = trimmed[lang.block_comment_start.len..];
            const line_type = processBlockContent(after_start, lang, &in_block_comment, &block_depth);
            switch (line_type) {
                .comment => counts.comment += 1,
                .code => counts.code += 1,
                .blank => counts.blank += 1,
            }
            continue;
        }

        // Check if line starts with a line comment
        if (lang.line_comment.len > 0 and startsWith(trimmed, lang.line_comment)) {
            counts.comment += 1;
            continue;
        }

        if (lang.doc_line_comment.len > 0 and startsWith(trimmed, lang.doc_line_comment)) {
            counts.comment += 1;
            continue;
        }

        // Line has content. Scan for inline comments to classify correctly.
        // A line is "code" if it has any non-comment, non-whitespace content.
        // A line that is entirely an inline block comment is "comment".
        const classification = classifyLine(trimmed, lang);
        switch (classification) {
            .code => counts.code += 1,
            .comment => counts.comment += 1,
            .blank => counts.blank += 1,
        }
    }

    return counts;
}

const LineType = enum { code, comment, blank };

/// Classifies a line that doesn't start with a comment marker.
/// Scans for inline block comments and strings to determine whether
/// the line is code, comment, or blank.
fn classifyLine(line: []const u8, lang: *const reg.LanguageDefinition) LineType {
    if (lang.block_comment_start.len == 0) {
        // No block comments possible — any non-blank line is code
        return .code;
    }

    var pos: usize = 0;
    var has_code = false;
    var in_string = false;
    var string_char: u8 = 0;
    var in_inline_block = false;
    var block_depth: u32 = 0;

    while (pos < line.len) {
        if (in_string) {
            if (line[pos] == '\\' and pos + 1 < line.len) {
                pos += 2;
                continue;
            }
            if (line[pos] == string_char) {
                in_string = false;
            }
            pos += 1;
            continue;
        }

        if (in_inline_block) {
            if (lang.block_comment_end.len > 0 and startsAt(line, pos, lang.block_comment_end)) {
                block_depth -= 1;
                pos += lang.block_comment_end.len;
                if (block_depth == 0) {
                    in_inline_block = false;
                }
                continue;
            }
            pos += 1;
            continue;
        }

        // Check for string start
        if (line[pos] == '"' or line[pos] == '\'') {
            in_string = true;
            string_char = line[pos];
            has_code = true;
            pos += 1;
            continue;
        }

        // Check for block comment start
        if (lang.block_comment_start.len > 0 and startsAt(line, pos, lang.block_comment_start)) {
            in_inline_block = true;
            block_depth = 1;
            pos += lang.block_comment_start.len;
            continue;
        }

        // Check for line comment (rest of line is comment)
        if (lang.line_comment.len > 0 and startsAt(line, pos, lang.line_comment)) {
            break;
        }

        has_code = true;
        pos += 1;
    }

    if (has_code) return .code;
    return .comment;
}

/// Processes a line while inside a block comment. Returns the line type.
fn processBlockContent(line: []const u8, lang: *const reg.LanguageDefinition, in_block: *bool, depth: *u32) LineType {
    var pos: usize = 0;
    const supports_nesting = lang.nested_block_comment_start.len > 0;

    while (pos < line.len) {
        if (lang.block_comment_end.len > 0 and startsAt(line, pos, lang.block_comment_end)) {
            depth.* -= 1;
            pos += lang.block_comment_end.len;
            if (depth.* == 0) {
                in_block.* = false;
                // Check if there's code after the block comment ends
                const remaining = std.mem.trim(u8, line[pos..], " \t");
                if (remaining.len > 0) {
                    return .code;
                }
                return .comment;
            }
            continue;
        }

        if (supports_nesting and startsAt(line, pos, lang.nested_block_comment_start)) {
            depth.* += 1;
            pos += lang.nested_block_comment_start.len;
            continue;
        }

        if (!supports_nesting and lang.block_comment_start.len > 0 and startsAt(line, pos, lang.block_comment_start)) {
            pos += lang.block_comment_start.len;
            continue;
        }

        pos += 1;
    }

    return .comment;
}

fn startsAt(s: []const u8, pos: usize, prefix: []const u8) bool {
    if (pos + prefix.len > s.len) return false;
    return std.mem.eql(u8, s[pos .. pos + prefix.len], prefix);
}

fn startsWith(s: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, s, prefix);
}

test "count simple code lines" {
    const lang = reg.Registry.detect("test.zig").?;
    const content = "const x = 1;\nconst y = 2;\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 2), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.blank);
    try std.testing.expectEqual(@as(u64, 0), c.comment);
}

test "count blank lines" {
    const lang = reg.Registry.detect("test.zig").?;
    const content = "const x = 1;\n\n\nconst y = 2;\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 2), c.code);
    try std.testing.expectEqual(@as(u64, 2), c.blank);
}

test "count line comments" {
    const lang = reg.Registry.detect("test.zig").?;
    const content = "// a comment\nconst x = 1;\n// another\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 2), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.code);
}

test "count doc comments" {
    const lang = reg.Registry.detect("test.zig").?;
    const content = "/// doc comment\n/// another doc\nconst x = 1;\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 2), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.code);
}

test "count block comments" {
    const lang = reg.Registry.detect("test.c").?;
    const content = "/* block\ncomment\n*/\nconst x = 1;\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 3), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.code);
}

test "count inline block comment then code" {
    const lang = reg.Registry.detect("test.c").?;
    const content = "/* comment */ code here\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 1), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.comment);
}

test "count python comments" {
    const lang = reg.Registry.detect("test.py").?;
    const content = "# a comment\nx = 1\n# another\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 2), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.code);
}

test "count python block comments" {
    const lang = reg.Registry.detect("test.py").?;
    const content = "\"\"\"docstring\nmulti-line\n\"\"\"\nx = 1\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 3), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.code);
}

test "count mixed content" {
    const lang = reg.Registry.detect("test.zig").?;
    const content =
        \\const std = @import("std");
        \\
        \\/// Documentation
        \\pub fn main() void {
        \\    // inline comment
        \\    std.debug.print("hello", .{});
        \\}
        \\
    ;
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 4), c.code);
    try std.testing.expectEqual(@as(u64, 2), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.blank);
}

test "count handles CRLF" {
    const lang = reg.Registry.detect("test.zig").?;
    const content = "const x = 1;\r\n\r\nconst y = 2;\r\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 2), c.code);
    try std.testing.expectEqual(@as(u64, 1), c.blank);
}

test "count handles empty file" {
    const lang = reg.Registry.detect("test.zig").?;
    const c = count("", lang);
    try std.testing.expectEqual(@as(u64, 0), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.blank);
    try std.testing.expectEqual(@as(u64, 0), c.comment);
}

test "count no trailing newline" {
    const lang = reg.Registry.detect("test.zig").?;
    const content = "const x = 1;\nconst y = 2;";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 2), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.blank);
}

test "count block comment spanning multiple lines with code after" {
    const lang = reg.Registry.detect("test.c").?;
    const content = "/* start\nmiddle\nend */ int x = 1;\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 1), c.code);
    try std.testing.expectEqual(@as(u64, 2), c.comment);
}

test "count code with string containing comment marker" {
    const lang = reg.Registry.detect("test.js").?;
    const content = "const s = \"hello // world\";\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 1), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.comment);
}

test "count code with block comment start inside string" {
    const lang = reg.Registry.detect("test.js").?;
    const content = "const s = \"not a /* comment */\";\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 1), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.comment);
}

test "count inline comment at end of code line" {
    const lang = reg.Registry.detect("test.js").?;
    const content = "const x = 1; // comment\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 1), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.comment);
}

test "count entire line is inline block comment" {
    const lang = reg.Registry.detect("test.js").?;
    const content = "code(); /* just a comment */\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 1), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.comment);
}

test "count blank line inside block comment" {
    const lang = reg.Registry.detect("test.c").?;
    const content = "/* start\n\nend */\n";
    const c = count(content, lang);
    try std.testing.expectEqual(@as(u64, 0), c.code);
    try std.testing.expectEqual(@as(u64, 0), c.blank);
    try std.testing.expectEqual(@as(u64, 3), c.comment);
}
