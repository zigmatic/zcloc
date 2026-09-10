//! Aggregates all module tests for `zig build test`.

const std = @import("std");

test {
    // Utility modules
    _ = @import("util/errors.zig");
    _ = @import("util/paths.zig");
    _ = @import("util/allocator.zig");

    // CLI
    _ = @import("cli/parser.zig");
    _ = @import("cli/commands.zig");

    // Config
    _ = @import("config/global.zig");
    _ = @import("config/local.zig");
    _ = @import("config/loader.zig");

    // Git
    _ = @import("git/repository.zig");
    _ = @import("git/tracked.zig");
    _ = @import("git/ignore.zig");

    // Counter
    _ = @import("counter/walker.zig");
    _ = @import("counter/reader.zig");
    _ = @import("counter/counter.zig");
    _ = @import("counter/statistics.zig");
    _ = @import("counter/parallel.zig");

    // Formats
    _ = @import("formats/table.zig");
    _ = @import("formats/json.zig");
    _ = @import("formats/yaml.zig");
    _ = @import("formats/csv.zig");
    _ = @import("formats/markdown.zig");

    // Languages
    _ = @import("languages/definitions.zig");
    _ = @import("languages/registry.zig");

    // Main
    _ = @import("main.zig");
}
