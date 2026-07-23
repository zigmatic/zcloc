//! Error types and diagnostics for zcloc.
//!
//! Provides structured error reporting so callers can surface useful
//! diagnostics instead of crashing. All errors carry enough context for
//! the caller to produce a human-readable message.

const std = @import("std");

/// Errors that can occur while walking and reading files.
pub const WalkError = error{
    PermissionDenied,
    BrokenSymlink,
    FileTooLarge,
    IoError,
    OutOfMemory,
};

/// Errors that can occur while parsing CLI arguments.
pub const ParseError = error{
    UnknownFlag,
    MissingValue,
    InvalidValue,
    OutOfMemory,
};

/// Errors that can occur while loading configuration files.
pub const ConfigError = error{
    MalformedConfig,
    FileNotFound,
    OutOfMemory,
};

/// Errors that can occur during git operations.
pub const GitError = error{
    NotARepository,
    GitCommandFailed,
    OutOfMemory,
};

/// Prints a diagnostic message to the given writer in a consistent format.
pub fn report(writer: anytype, err: anyerror, context: []const u8) !void {
    const msg = errorMessage(err);
    try writer.print("zcloc: {s}: {s}\n", .{ msg, context });
}

/// Maps an error to a human-readable description.
pub fn errorMessage(err: anyerror) []const u8 {
    return switch (err) {
        error.PermissionDenied => "permission denied",
        error.BrokenSymlink => "broken symlink",
        error.FileTooLarge => "file too large",
        error.IoError => "I/O error",
        error.OutOfMemory => "out of memory",
        error.UnknownFlag => "unknown flag",
        error.MissingValue => "missing value",
        error.InvalidValue => "invalid value",
        error.MalformedConfig => "malformed config",
        error.FileNotFound => "file not found",
        error.NotARepository => "not a git repository",
        error.GitCommandFailed => "git command failed",
        else => @errorName(err),
    };
}

test "errorMessage maps known errors" {
    try std.testing.expectEqualStrings("permission denied", errorMessage(error.PermissionDenied));
    try std.testing.expectEqualStrings("unknown flag", errorMessage(error.UnknownFlag));
}

test "errorMessage falls back for unknown errors" {
    try std.testing.expectEqualStrings("BufferTooSmall", errorMessage(error.BufferTooSmall));
}
