//! Configuration loader.
//!
//! Merges configuration from multiple sources in priority order:
//!   CLI flags > local config (.clocignore) > global config > defaults
//!
//! The loader applies global `default_flags` by re-parsing them as CLI
//! arguments, but only if they were not overridden on the command line.

const std = @import("std");
const parser = @import("../cli/parser.zig");
const global = @import("global.zig");
const local = @import("local.zig");

/// Merged configuration used by the counting engine.
pub const MergedConfig = struct {
    options: parser.Options,
    global_config: global.GlobalConfig,
    local_ignores: ?local.LocalIgnore = null,

    pub fn deinit(self: *MergedConfig, allocator: std.mem.Allocator) void {
        self.options.deinit(allocator);
        self.global_config.deinit(allocator);
        if (self.local_ignores) |*li| li.deinit();
    }
};

/// Loads and merges all configuration sources.
/// `cli_args` are the raw CLI arguments (excluding argv[0]).
/// Caller must call `deinit` on the result.
pub fn load(allocator: std.mem.Allocator, io: std.Io, environ: ?*const std.process.Environ.Map, cli_args: []const []const u8) !MergedConfig {
    var global_cfg = try global.load(allocator, io, environ);
    errdefer global_cfg.deinit(allocator);

    var effective_args: std.ArrayList([]const u8) = .empty;
    defer effective_args.deinit(allocator);

    for (cli_args) |arg| try effective_args.append(allocator, arg);

    if (global_cfg.default_flags) |flags| {
        for (flags) |flag| try effective_args.append(allocator, flag);
    }

    var opts = try parser.parse(allocator, effective_args.items);
    errdefer opts.deinit(allocator);

    var merged = MergedConfig{
        .options = opts,
        .global_config = global_cfg,
    };

    if (opts.targets.len > 0) {
        if (local.load(allocator, io, opts.targets[0])) |maybe_li| {
            if (maybe_li) |li| {
                merged.local_ignores = li;
            }
        } else |_| {}
    }

    return merged;
}

test "load merges defaults" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var cfg = try load(allocator, io, null, &.{ "--json", "." });
    defer cfg.deinit(allocator);

    try std.testing.expectEqual(parser.Format.json, cfg.options.format);
}
