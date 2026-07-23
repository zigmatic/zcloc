//! Language definitions for zcloc.
//!
//! Each definition is data-driven: it declares the file extensions, comment
//! markers, and optional filename overrides. The counting engine reads these
//! definitions rather than hardcoding parser logic per language.
//!
//! To add a new language, append a `LanguageDefinition` to `all_languages`
//! below. No other code changes are required.

const std = @import("std");

/// Describes how to identify and count lines for a single programming language.
pub const LanguageDefinition = struct {
    /// Display name (e.g. "Zig", "Go").
    name: []const u8,
    /// File extensions (without the dot), e.g. &.{ "zig" }.
    extensions: []const []const u8,
    /// Filenames that map to this language when extension matching fails
    /// (e.g. "Makefile"). May be empty.
    filenames: []const []const u8 = &.{},
    /// Line comment prefix, e.g. "//". May be empty if the language has none.
    line_comment: []const u8 = "",
    /// Block comment start, e.g. "/*". May be empty.
    block_comment_start: []const u8 = "",
    /// Block comment end, e.g. "*/". May be empty.
    block_comment_end: []const u8 = "",
    /// Nested block comment start (for languages like Zig, Rust). May be empty.
    nested_block_comment_start: []const u8 = "",
    /// Doc comment prefix (counted as comment, not code). May be empty.
    doc_line_comment: []const u8 = "",
    /// String delimiters to skip over (prevents false comment detection
    /// inside strings). Default is double and single quotes.
    string_delimiters: []const []const u8 = &.{ "\"\"", "''" },
};

/// The master list of all supported languages.
/// Order matters only for display; detection uses extensions first.
pub const all_languages = [_]LanguageDefinition{
    .{
        .name = "Zig",
        .extensions = &.{ "zig", "zon" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .doc_line_comment = "///",
        .string_delimiters = &.{ "\"\"", "''" },
    },
    .{
        .name = "C",
        .extensions = &.{ "c", "h" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "C++",
        .extensions = &.{ "cpp", "cxx", "cc", "hpp", "hxx", "hh", "inl" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Go",
        .extensions = &.{ "go" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Rust",
        .extensions = &.{ "rs" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .doc_line_comment = "///",
    },
    .{
        .name = "Python",
        .extensions = &.{ "py", "pyi", "pyw" },
        .line_comment = "#",
        .block_comment_start = "\"\"\"",
        .block_comment_end = "\"\"\"",
    },
    .{
        .name = "JavaScript",
        .extensions = &.{ "js", "mjs", "cjs" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "JSX",
        .extensions = &.{ "jsx" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "TypeScript",
        .extensions = &.{ "ts", "mts", "cts" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "TSX",
        .extensions = &.{ "tsx" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Java",
        .extensions = &.{ "java" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Ruby",
        .extensions = &.{ "rb" },
        .line_comment = "#",
        .block_comment_start = "=begin",
        .block_comment_end = "=end",
    },
    .{
        .name = "Shell",
        .extensions = &.{ "sh", "bash", "zsh" },
        .filenames = &.{ ".bashrc", ".zshrc" },
        .line_comment = "#",
    },
    .{
        .name = "PHP",
        .extensions = &.{ "php", "php3", "php4", "php5", "phtml" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "C#",
        .extensions = &.{ "cs" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Swift",
        .extensions = &.{ "swift" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Kotlin",
        .extensions = &.{ "kt", "kts" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Scala",
        .extensions = &.{ "scala", "sc" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Haskell",
        .extensions = &.{ "hs", "lhs" },
        .line_comment = "--",
        .block_comment_start = "{-",
        .block_comment_end = "-}",
    },
    .{
        .name = "Lua",
        .extensions = &.{ "lua" },
        .line_comment = "--",
        .block_comment_start = "--[[",
        .block_comment_end = "]]",
    },
    .{
        .name = "Perl",
        .extensions = &.{ "pl", "pm" },
        .line_comment = "#",
        .block_comment_start = "=",
        .block_comment_end = "=cut",
    },
    .{
        .name = "R",
        .extensions = &.{ "r", "R" },
        .line_comment = "#",
    },
    .{
        .name = "Dart",
        .extensions = &.{ "dart" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Elixir",
        .extensions = &.{ "ex", "exs" },
        .line_comment = "#",
    },
    .{
        .name = "Erlang",
        .extensions = &.{ "erl", "hrl" },
        .line_comment = "%",
    },
    .{
        .name = "Clojure",
        .extensions = &.{ "clj", "cljs", "cljc", "edn" },
        .line_comment = ";",
    },
    .{
        .name = "F#",
        .extensions = &.{ "fs", "fsx" },
        .line_comment = "//",
        .block_comment_start = "(*",
        .block_comment_end = "*)",
    },
    .{
        .name = "OCaml",
        .extensions = &.{ "ml", "mli" },
        .line_comment = "//",
        .block_comment_start = "(*",
        .block_comment_end = "*)",
    },
    .{
        .name = "Crystal",
        .extensions = &.{ "cr" },
        .line_comment = "#",
    },
    .{
        .name = "Nim",
        .extensions = &.{ "nim" },
        .line_comment = "#",
    },
    .{
        .name = "V",
        .extensions = &.{ "v" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Julia",
        .extensions = &.{ "jl" },
        .line_comment = "#",
        .block_comment_start = "#=",
        .block_comment_end = "=#",
    },
    .{
        .name = "D",
        .extensions = &.{ "d", "di" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Objective-C",
        .extensions = &.{ "m" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Objective-C++",
        .extensions = &.{ "mm" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Fortran",
        .extensions = &.{ "f", "f90", "f95", "f03", "for" },
        .line_comment = "!",
    },
    .{
        .name = "Pascal",
        .extensions = &.{ "pas", "pp" },
        .line_comment = "//",
        .block_comment_start = "{",
        .block_comment_end = "}",
    },
    .{
        .name = "Ada",
        .extensions = &.{ "adb", "ads" },
        .line_comment = "--",
    },
    .{
        .name = "COBOL",
        .extensions = &.{ "cob", "cbl", "COB" },
        .line_comment = "*",
    },
    .{
        .name = "Groovy",
        .extensions = &.{ "groovy", "gradle" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Tcl",
        .extensions = &.{ "tcl" },
        .line_comment = "#",
    },
    .{
        .name = "Vim Script",
        .extensions = &.{ "vim" },
        .filenames = &.{ ".vimrc" },
        .line_comment = "\"",
    },
    .{
        .name = "PowerShell",
        .extensions = &.{ "ps1", "psm1" },
        .line_comment = "#",
        .block_comment_start = "<#",
        .block_comment_end = "#>",
    },
    .{
        .name = "Assembly",
        .extensions = &.{ "asm", "s", "S" },
        .line_comment = ";",
    },
    .{
        .name = "Makefile",
        .extensions = &.{ "mk", "mak" },
        .filenames = &.{ "Makefile", "makefile", "GNUmakefile" },
        .line_comment = "#",
    },
    .{
        .name = "CMake",
        .extensions = &.{ "cmake" },
        .filenames = &.{ "CMakeLists.txt" },
        .line_comment = "#",
    },
    .{
        .name = "YAML",
        .extensions = &.{ "yaml", "yml" },
        .line_comment = "#",
    },
    .{
        .name = "TOML",
        .extensions = &.{ "toml" },
        .line_comment = "#",
    },
    .{
        .name = "JSON",
        .extensions = &.{ "json", "json5", "jsonc" },
    },
    .{
        .name = "Markdown",
        .extensions = &.{ "md", "markdown" },
        .line_comment = "",
    },
    .{
        .name = "MDX",
        .extensions = &.{ "mdx" },
        .line_comment = "",
    },
    .{
        .name = "HTML",
        .extensions = &.{ "html", "htm", "xhtml" },
        .block_comment_start = "<!--",
        .block_comment_end = "-->",
    },
    .{
        .name = "CSS",
        .extensions = &.{ "css" },
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "SCSS",
        .extensions = &.{ "scss", "sass" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Less",
        .extensions = &.{ "less" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "XML",
        .extensions = &.{ "xml", "xsd", "xsl", "xslt", "plist", "resx", "svgz" },
        .block_comment_start = "<!--",
        .block_comment_end = "-->",
    },
    .{
        .name = "SVG",
        .extensions = &.{ "svg" },
        .block_comment_start = "<!--",
        .block_comment_end = "-->",
    },
    .{
        .name = "SQL",
        .extensions = &.{ "sql" },
        .line_comment = "--",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "GraphQL",
        .extensions = &.{ "graphql", "gql" },
        .line_comment = "#",
    },
    .{
        .name = "Protocol Buffers",
        .extensions = &.{ "proto" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Dockerfile",
        .extensions = &.{},
        .filenames = &.{ "Dockerfile", "Containerfile" },
        .line_comment = "#",
    },
    .{
        .name = "CUDA",
        .extensions = &.{ "cu", "cuh" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "GLSL",
        .extensions = &.{ "glsl", "vert", "frag", "comp" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Vue",
        .extensions = &.{ "vue" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Svelte",
        .extensions = &.{ "svelte" },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    },
    .{
        .name = "Text",
        .extensions = &.{ "txt", "text", "log" },
    },
};

test "all_languages has entries" {
    try std.testing.expect(all_languages.len > 10);
}

test "all languages have a name" {
    for (all_languages) |lang| {
        try std.testing.expect(lang.name.len > 0);
    }
}

test "tsx is detected" {
    for (all_languages) |lang| {
        if (std.mem.eql(u8, lang.name, "TSX")) {
            try std.testing.expect(std.mem.eql(u8, lang.extensions[0], "tsx"));
            return;
        }
    }
    try std.testing.expect(false);
}
