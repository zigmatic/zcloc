//! zcloc - a modern cloc-compatible code counter written in Zig.
//!
//! Entry point for the command-line application. Orchestrates CLI parsing,
//! configuration loading, directory walking, counting, and output formatting.

const std = @import("std");

const parser = @import("cli/parser.zig");
const commands = @import("cli/commands.zig");
const config_loader = @import("config/loader.zig");
const global_config = @import("config/global.zig");
const tracked = @import("git/tracked.zig");
const gitignore_mod = @import("git/ignore.zig");
const repository = @import("git/repository.zig");
const walker = @import("counter/walker.zig");
const reader = @import("counter/reader.zig");
const counter = @import("counter/counter.zig");
const stats = @import("counter/statistics.zig");
const reg = @import("languages/registry.zig");
const table_fmt = @import("formats/table.zig");
const json_fmt = @import("formats/json.zig");
const yaml_fmt = @import("formats/yaml.zig");
const csv_fmt = @import("formats/csv.zig");
const md_fmt = @import("formats/markdown.zig");
const errors = @import("util/errors.zig");
const paths_util = @import("util/paths.zig");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_file_writer: std.Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    const stderr_writer = &stderr_file_writer.interface;

    const cli_args = try init.minimal.args.toSlice(arena);

    run(arena, io, init.environ_map, stdout_writer, stderr_writer, cli_args) catch |err| {
        try errors.report(stderr_writer, err, "fatal error");
        try stderr_writer.flush();
        std.process.exit(1);
    };

    try stdout_writer.flush();
}

fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: ?*const std.process.Environ.Map,
    stdout_writer: *std.Io.Writer,
    stderr_writer: *std.Io.Writer,
    cli_args: []const []const u8,
) !void {
    var cfg = try config_loader.load(allocator, io, environ_map, cli_args);
    defer cfg.deinit(allocator);

    if (cfg.options.version) {
        try commands.printVersion(stdout_writer);
        return;
    }

    if (cfg.options.help) {
        try commands.printHelp(stdout_writer);
        return;
    }

    var exclude_dirs: std.ArrayList([]const u8) = .empty;
    defer exclude_dirs.deinit(allocator);

    if (cfg.options.exclude_dir) |dirs| {
        for (dirs) |d| try exclude_dirs.append(allocator, d);
    }
    if (cfg.global_config.exclude_dirs) |dirs| {
        for (dirs) |d| try exclude_dirs.append(allocator, d);
    }

    var exclude_exts: []const []const u8 = &.{};
    if (cfg.global_config.exclude_extensions) |exts| {
        exclude_exts = exts;
    }

    var builder = stats.StatsBuilder.init(allocator);
    defer builder.deinit();

    for (cfg.options.targets) |target| {
        try countTarget(
            allocator,
            io,
            &builder,
            target,
            cfg.options,
            exclude_dirs.items,
            exclude_exts,
            stderr_writer,
        );
    }

    var summary = try builder.build(cfg.options.by_file or cfg.options.by_file_by_lang);
    defer summary.deinit();

    switch (cfg.options.format) {
        .table => try table_fmt.write(stdout_writer, &summary),
        .json => try json_fmt.write(stdout_writer, &summary),
        .yaml => try yaml_fmt.write(stdout_writer, &summary),
        .csv => try csv_fmt.write(stdout_writer, &summary),
        .markdown => try md_fmt.write(stdout_writer, &summary),
    }
}

fn countTarget(
    allocator: std.mem.Allocator,
    io: std.Io,
    builder: *stats.StatsBuilder,
    target: []const u8,
    options: parser.Options,
    exclude_dirs: []const []const u8,
    exclude_exts: []const []const u8,
    stderr_writer: *std.Io.Writer,
) !void {
    var gitignore_ptr: ?*const gitignore_mod.GitIgnore = null;
    if (options.respect_gitignore) {
        if (gitignore_mod.load(allocator, io, target)) |maybe_gi| {
            if (maybe_gi) |*gi| {
                gitignore_ptr = gi;
            }
        } else |_| {}
    }

    var clocignore_ptr: ?*const @import("config/local.zig").LocalIgnore = null;
    if (options.respect_clocignore) {
        if (@import("config/local.zig").load(allocator, io, target)) |maybe_ci| {
            if (maybe_ci) |*ci| {
                clocignore_ptr = ci;
            }
        } else |_| {}
    }

    const walk_config = walker.WalkerConfig{
        .exclude_dirs = exclude_dirs,
        .exclude_extensions = exclude_exts,
        .include_lang = options.include_lang,
        .exclude_lang = options.exclude_lang,
        .match_f = options.match_f,
        .not_match_f = options.not_match_f,
        .gitignore = gitignore_ptr,
        .clocignore = clocignore_ptr,
    };

    if (options.tracked) {
        countTracked(allocator, io, builder, target, options, walk_config, stderr_writer) catch |err| {
            if (options.strict) {
                return err;
            }
            try errors.report(stderr_writer, err, target);
            try stderr_writer.flush();
            try countWalked(allocator, io, builder, target, walk_config);
        };
    } else {
        try countWalked(allocator, io, builder, target, walk_config);
    }
}

fn countTracked(
    allocator: std.mem.Allocator,
    io: std.Io,
    builder: *stats.StatsBuilder,
    target: []const u8,
    options: parser.Options,
    walk_config: walker.WalkerConfig,
    stderr_writer: *std.Io.Writer,
) !void {
    _ = stderr_writer;
    const files = try tracked.listTracked(allocator, io, target);

    for (files) |rel_path| {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ target, rel_path }) catch continue;

        const lang = reg.Registry.detect(rel_path) orelse {
            allocator.free(@constCast(rel_path));
            continue;
        };

        if (!shouldIncludeLang(lang.name, options)) {
            allocator.free(@constCast(rel_path));
            continue;
        }

        const counts = reader.countFile(allocator, io, full_path, lang, reader.default_max_size) catch |err| {
            if (err == error.FileTooLarge) continue;
            continue;
        };

        try builder.addFile(full_path, lang.name, counts.blank, counts.comment, counts.code);
        allocator.free(@constCast(rel_path));
    }

    allocator.free(files);
    _ = walk_config;
}

fn countWalked(
    allocator: std.mem.Allocator,
    io: std.Io,
    builder: *stats.StatsBuilder,
    target: []const u8,
    walk_config: walker.WalkerConfig,
) !void {
    const entries = try walker.walk(allocator, io, target, walk_config);
    defer {
        for (entries) |e| allocator.free(e.path);
        allocator.free(entries);
    }

    for (entries) |entry| {
        const lang = entry.language orelse continue;

        const counts = reader.countFile(allocator, io, entry.path, lang, reader.default_max_size) catch |err| {
            if (err == error.FileTooLarge) continue;
            continue;
        };

        try builder.addFile(entry.path, lang.name, counts.blank, counts.comment, counts.code);
    }
}

fn shouldIncludeLang(lang_name: []const u8, options: parser.Options) bool {
    if (options.include_lang) |includes| {
        var found = false;
        for (includes) |inc| {
            if (std.ascii.eqlIgnoreCase(lang_name, inc)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }

    if (options.exclude_lang) |excludes| {
        for (excludes) |exc| {
            if (std.ascii.eqlIgnoreCase(lang_name, exc)) return false;
        }
    }

    return true;
}

test "main module compiles" {
    try std.testing.expect(true);
}
