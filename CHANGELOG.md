# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# Aug 18 - v1.0.2

feat: added TSX, JSX, MDX, Less, and SVG language definitions
feat: string-aware comment counting — comment markers inside string literals no longer misclassified
feat: inline block comment classification — lines with mixed code and block comments correctly categorized
feat: increased max file size from 8MB to 100MB to stop silently skipping large files
feat: added file extensions — .json5, .jsonc, .mjs, .cjs, .mts, .cts, .pyw, .zsh, .sass, .less, .svg, .plist, .resx
feat: separated SVG from XML as its own language entry
feat: percentage reporting with --percent flag — shows % code, % comment, % blank per language and in total row across all output formats (table, JSON, CSV, YAML, Markdown)
feat: added todo.json for feature tracking
fix: fixed benchmark module imports to use library module instead of relative paths outside module root
fix: replaced removed std.time.Timer with clock_gettime syscall for Zig 0.16.0 compatibility

changed/added files:

src/languages/definitions.zig - changed, added TSX/JSX/MDX/Less/SVG languages, added missing extensions, added string_delimiters field
src/counter/counter.zig - changed, rewrote with string-aware classifyLine function, inline block comment handling, blank-line-in-block-comment fix
src/counter/reader.zig - changed, increased default_max_size from 8MB to 100MB
src/counter/statistics.zig - changed, added percent field to Summary, added pct() helper and totalLines() method
src/root.zig - changed, now re-exports counter and registry as module entry point for benchmark
src/benchmarks/benchmark.zig - changed, uses zcloc module import, replaced std.time.Timer with clock_gettime syscall
src/cli/parser.zig - changed, added --percent flag to Options and parser
src/cli/commands.zig - changed, added --percent to help text
src/formats/table.zig - changed, added percentage column layout when percent is enabled
src/formats/json.zig - changed, added pct_code/pct_comment/pct_blank/pct_of_total fields when percent is enabled
src/formats/csv.zig - changed, added percentage columns when percent is enabled
src/formats/yaml.zig - changed, added percentage fields when percent is enabled
src/formats/markdown.zig - changed, added percentage columns when percent is enabled
src/main.zig - changed, wires percent flag from options to summary
build.zig - changed, added lib_mod for benchmark module dependency
todo.json - added, tracks feature status and planned work

## [1.0.1] - 2026-07-23

### Added

- Add TSX, JSX, MDX languages to definitions.zig
- Increase max file size from 8MB to 100MB in reader.zig
- Fix counter to handle inline block comments mid-line
- Add more missing extensions (json5, less, etc.)

## [1.0.0] - 2026-07-22

### Added

- Initial release of zcloc
- cloc-compatible CLI flags: `--by-file`, `--by-file-by-lang`, `--include-lang`, `--exclude-lang`, `--exclude-dir`, `--match-f`, `--not-match-f`, `--json`, `--csv`, `--yaml`, `--md`, `--quiet`, `--version`, `--help`
- Git-aware counting with `--tracked` flag using `git ls-files`
- `.gitignore` support with glob patterns and negation
- `.clocignore` project-specific ignore files
- Global configuration via `~/.config/zcloc/config.toml` or `~/.clocrc`
- Configuration priority: CLI > local > global > defaults
- Data-driven language registry with 60+ languages
- Single-pass counting state machine handling line comments, block comments, nested block comments, doc comments, and blank lines
- Five output formats: table, JSON, YAML, CSV, Markdown
- Streaming file reader with 4KB chunks and 8MB max file size
- Bounded-memory directory walker with exclude/include filtering
- Comprehensive test suite covering all modules
- Benchmark tool for measuring counting throughput
- README, ARCHITECTURE, and CHANGELOG documentation
