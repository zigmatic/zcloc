# Architecture

## Project layout

```
src/
  main.zig              Entry point and orchestration
  all_tests.zig         Test aggregation
  cli/
    parser.zig          CLI argument parsing
    commands.zig        Help/version text
  config/
    global.zig          Global config (~/.config/zcloc/config.toml)
    local.zig           .clocignore parsing
    loader.zig          Merges config sources by priority
  git/
    tracked.zig         git ls-files integration
    ignore.zig          .gitignore parsing and matching
    repository.zig      Git repo detection
  counter/
    walker.zig          Recursive directory walker with filtering
    reader.zig          Streaming file reader
    counter.zig         Line counting state machine
    statistics.zig      Result aggregation
  formats/
    table.zig           Default tabular output
    json.zig            JSON output
    yaml.zig            YAML output
    csv.zig             CSV output
    markdown.zig        Markdown output
  languages/
    definitions.zig     Data-driven language definitions
    registry.zig        Language detection by extension/filename
  util/
    errors.zig          Error types and diagnostics
    paths.zig           Path utilities
    allocator.zig       Allocator helpers
  benchmarks/
    benchmark.zig       Counting throughput benchmark
```

## Counting pipeline

```
CLI args → Config Loader → Walker → Reader → Counter → StatsBuilder → Formatter → stdout
```

1. **CLI parsing**: `cli/parser.zig` converts arguments into `Options`
2. **Config merging**: `config/loader.zig` merges CLI, local, and global config
3. **Walking**: `counter/walker.zig` recursively walks directories, applying filters
4. **Reading**: `counter/reader.zig` streams file content in 4KB chunks
5. **Counting**: `counter/counter.zig` runs a single-pass state machine over content
6. **Aggregation**: `counter/statistics.zig` accumulates per-file and per-language results
7. **Formatting**: `formats/*.zig` renders the summary in the requested format

## Language registry

Languages are defined data-driven in `languages/definitions.zig`. Each `LanguageDefinition` specifies:

- File extensions
- Filenames (for extensionless files like `Makefile`)
- Line comment prefix
- Block comment start/end markers
- Optional nested block comment support
- Optional doc comment prefix

The `Registry.detect()` function matches by filename first, then by extension. Adding a new language requires only adding one struct literal to the `all_languages` array.

## Configuration loading

Priority order (highest first):

1. **CLI flags** — parsed by `cli/parser.zig`
2. **Local config** — `.clocignore` in the target directory
3. **Global config** — `~/.config/zcloc/config.toml` or `~/.clocrc`
4. **Defaults** — hardcoded in `Options`

Global config `default_flags` are appended to CLI args before parsing, so CLI flags take precedence.

## Git integration

- `git/repository.zig`: Walks up the directory tree looking for `.git`
- `git/tracked.zig`: Runs `git ls-files` to enumerate tracked files
- `git/ignore.zig`: Parses `.gitignore` with glob matching and negation

When `--tracked` is used and git is unavailable, the tool falls back to a full directory walk unless `--strict` is set.

## Formatter architecture

Each formatter implements a `write(writer, summary)` function. The `Format` enum in `parser.zig` selects which formatter to call. Adding a new format requires:

1. Create `src/formats/newformat.zig` with a `write` function
2. Add a variant to the `Format` enum
3. Add a CLI flag mapping
4. Add the dispatch call in `main.zig`

## Extension guide

### Adding a language

Add to `src/languages/definitions.zig`:

```zig
.{
    .name = "MyLang",
    .extensions = &.{ "myl" },
    .line_comment = "#",
    .block_comment_start = "/*",
    .block_comment_end = "*/",
},
```

### Adding an output format

1. Create `src/formats/xml.zig`:
```zig
pub fn write(writer: anytype, summary: *const stats.Summary) !void {
    // ...
}
```
2. Add `xml` to the `Format` enum in `cli/parser.zig`
3. Add `--xml` flag parsing
4. Dispatch in `main.zig`
