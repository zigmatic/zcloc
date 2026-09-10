//! Parallel file counting using worker threads.
//!
//! Distributes file entries across N worker threads. Each thread has its
//! own arena allocator for file content. Results are collected and merged
//! into the shared StatsBuilder after all threads complete.

const std = @import("std");
const walker = @import("walker.zig");
const reader = @import("reader.zig");
const counter = @import("counter.zig");
const reg = @import("../languages/registry.zig");
const stats = @import("statistics.zig");

/// Per-file result produced by a worker thread.
const FileCounts = struct {
    path: []const u8,
    language: []const u8,
    blank: u64,
    comment: u64,
    code: u64,
};

/// Counts all files in `entries` using up to `jobs` worker threads.
/// Results are added to `builder`. Falls back to single-threaded if
/// jobs <= 1 or if there are fewer than 2 files.
pub fn countFiles(
    allocator: std.mem.Allocator,
    io: std.Io,
    entries: []const walker.Entry,
    jobs: u32,
    builder: *stats.StatsBuilder,
) !void {
    if (jobs <= 1 or entries.len < 2) {
        for (entries) |entry| {
            const lang = entry.language orelse continue;
            const counts = reader.countFile(allocator, io, entry.path, lang, reader.default_max_size) catch continue;
            try builder.addFile(entry.path, lang.name, counts.blank, counts.comment, counts.code);
        }
        return;
    }

    const num_threads = @min(@as(u32, @intCast(entries.len)), jobs);

    var results: std.ArrayList(FileCounts) = .empty;
    defer results.deinit(allocator);

    var errors_count: u32 = 0;

    var jobq = JobQueue.init(allocator, entries, num_threads);
    defer jobq.deinit();

    const threads = try allocator.alloc(std.Thread, num_threads);
    defer allocator.free(threads);

    var ctx = WorkerCtx{
        .io = io,
        .jobq = &jobq,
        .results = &results,
        .results_mutex = .init,
        .errors_count = &errors_count,
    };

    for (threads) |*t| {
        t.* = try std.Thread.spawn(.{}, workerThread, .{ &ctx, allocator });
    }
    for (threads) |t| t.join();

    for (results.items) |fc| {
        try builder.addFile(fc.path, fc.language, fc.blank, fc.comment, fc.code);
    }
}

/// Simple atomic job queue: each worker pops the next file index.
const JobQueue = struct {
    entries: []const walker.Entry,
    next: std.atomic.Value(u32),
    total: u32,

    fn init(_: std.mem.Allocator, entries: []const walker.Entry, num_threads: u32) JobQueue {
        _ = num_threads;
        return .{
            .entries = entries,
            .next = std.atomic.Value(u32).init(0),
            .total = @intCast(entries.len),
        };
    }

    fn deinit(_: *JobQueue) void {}

    fn nextJob(self: *JobQueue) ?usize {
        const idx = self.next.fetchAdd(1, .monotonic);
        if (idx >= self.total) return null;
        return @intCast(idx);
    }
};

const WorkerCtx = struct {
    io: std.Io,
    jobq: *JobQueue,
    results: *std.ArrayList(FileCounts),
    results_mutex: std.Io.Mutex,
    errors_count: *u32,
};

fn workerThread(ctx: *WorkerCtx, allocator: std.mem.Allocator) void {
    while (ctx.jobq.nextJob()) |idx| {
        const entry = ctx.jobq.entries[idx];
        const lang = entry.language orelse continue;

        const counts = reader.countFile(allocator, ctx.io, entry.path, lang, reader.default_max_size) catch {
            _ = ctx.errors_count.*;
            continue;
        };

        ctx.results_mutex.lockUncancelable(ctx.io);
        ctx.results.append(allocator, .{
            .path = entry.path,
            .language = lang.name,
            .blank = counts.blank,
            .comment = counts.comment,
            .code = counts.code,
        }) catch {};
        ctx.results_mutex.unlock(ctx.io);
    }
}

test "JobQueue distributes indices" {
    const allocator = std.testing.allocator;
    const lang = reg.Registry.detect("a.zig").?;
    const entries = [_]walker.Entry{
        .{ .path = "a.zig", .language = lang },
        .{ .path = "b.zig", .language = lang },
        .{ .path = "c.zig", .language = lang },
    };

    var jobq = JobQueue.init(allocator, &entries, 3);

    var seen: [3]bool = .{ false, false, false };
    var count: u32 = 0;
    while (jobq.nextJob()) |idx| {
        seen[idx] = true;
        count += 1;
    }

    try std.testing.expectEqual(@as(u32, 3), count);
    try std.testing.expect(seen[0]);
    try std.testing.expect(seen[1]);
    try std.testing.expect(seen[2]);
}

test "parallel with jobs=1 falls back to single-threaded" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    const lang = reg.Registry.detect("test.zig").?;
    const entries = [_]walker.Entry{
        .{ .path = "/nonexistent/a.zig", .language = lang },
        .{ .path = "/nonexistent/b.zig", .language = lang },
    };

    var builder = stats.StatsBuilder.init(allocator);
    defer builder.deinit();

    try countFiles(allocator, io, &entries, 1, &builder);

    var summary = try builder.build(false);
    defer summary.deinit();

    try std.testing.expectEqual(@as(u64, 0), summary.total_files);
}
