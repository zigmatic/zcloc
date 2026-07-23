# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-23

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

## [1.0.1] - 2026-07-23

### Added

- Add TSX, JSX, MDX languages to definitions.zig
- Increase max file size from 8MB to 100MB in reader.zig
- Fix counter to handle inline block comments mid-line
- Add more missing extensions (json5, less, etc.)