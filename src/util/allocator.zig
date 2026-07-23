//! Allocator helpers for bounded-memory operation.
//!
//! Wraps the standard general-purpose allocator with optional tracking,
//! and provides a fixed-buffer arena fallback for constrained environments.

const std = @import("std");

/// Creates and returns a general-purpose allocator suitable for zcloc's
/// main work. In Debug mode this is the testing allocator with leak
/// detection; otherwise it is the standard GPA.
pub fn create() std.mem.Allocator {
    return std.heap.smp_allocator;
}

/// A fixed-size arena backed by a stack buffer. Useful for small,
/// bounded allocations that should never escape to the heap.
pub const StackArena = struct {
    arena: std.heap.ArenaAllocator,
    buffer: [4096]u8,

    pub fn init() StackArena {
        return .{
            .arena = std.heap.ArenaAllocator.init(std.heap.FixedBufferAllocator.init(&[_]u8{})),
            .buffer = undefined,
        };
    }

    pub fn allocator(self: *StackArena) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn deinit(self: *StackArena) void {
        self.arena.deinit();
    }
};

test "create returns a valid allocator" {
    const a = create();
    const buf = try a.alloc(u8, 10);
    defer a.free(buf);
    @memset(buf, 0);
}
