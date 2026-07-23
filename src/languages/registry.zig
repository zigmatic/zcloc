//! Language registry.
//!
//! Provides lookup by extension and by filename. The registry is populated
//! at compile time from `definitions.all_languages`, so adding a language
//! to the definitions file automatically makes it discoverable here.
//!
//! Ownership: the registry holds only pointers to static data. No heap
//! allocation is needed for lookups.

const std = @import("std");
const defs = @import("definitions.zig");

pub const LanguageDefinition = defs.LanguageDefinition;

/// The language registry. Built once from the static definitions list.
pub const Registry = struct {
    /// Returns the `LanguageDefinition` matching the given file path, or
    /// `null` if no language recognizes it.
    pub fn detect(path: []const u8) ?*const LanguageDefinition {
        const basename = std.fs.path.basename(path);

        for (&defs.all_languages) |*lang| {
            for (lang.filenames) |fname| {
                if (std.mem.eql(u8, basename, fname)) {
                    return lang;
                }
            }
        }

        const ext = extLowercase(basename) orelse return null;
        for (&defs.all_languages) |*lang| {
            for (lang.extensions) |e| {
                if (std.mem.eql(u8, ext, e)) {
                    return lang;
                }
            }
        }

        return null;
    }

    /// Returns the language name for a given path, or `null`.
    pub fn name(path: []const u8) ?[]const u8 {
        if (detect(path)) |lang| return lang.name;
        return null;
    }

    /// Returns a sorted list of all unique language names.
    /// Caller owns the returned slice.
    pub fn allNames(allocator: std.mem.Allocator) ![][]const u8 {
        var set = std.StringHashMap(void).init(allocator);
        defer set.deinit();

        for (defs.all_languages) |lang| {
            try set.put(lang.name, {});
        }

        var list: std.ArrayList([]const u8) = .empty;
        defer list.deinit(allocator);

        var it = set.iterator();
        while (it.next()) |entry| {
            try list.append(allocator, entry.key_ptr.*);
        }

        std.mem.sort([]const u8, list.items, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.lt);

        return try list.toOwnedSlice(allocator);
    }
};

/// Returns the lowercase extension of a basename, or `null`.
fn extLowercase(basename: []const u8) ?[]const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, basename, '.') orelse return null;
    if (dot == 0) return null;
    const ext = basename[dot + 1 ..];

    for (ext) |c| {
        if (c >= 'A' and c <= 'Z') {
            return ext;
        }
    }
    return ext;
}

test "detect by extension" {
    const lang = Registry.detect("main.zig").?;
    try std.testing.expectEqualStrings("Zig", lang.name);
}

test "detect by filename" {
    const lang = Registry.detect("Makefile").?;
    try std.testing.expectEqualStrings("Makefile", lang.name);
}

test "detect returns null for unknown" {
    try std.testing.expect(Registry.detect("foo.unknownext") == null);
}

test "detect handles no extension" {
    try std.testing.expect(Registry.detect("README") == null);
}

test "allNames returns sorted unique list" {
    const allocator = std.testing.allocator;
    const names = try Registry.allNames(allocator);
    defer allocator.free(names);

    try std.testing.expect(names.len > 0);

    for (names[0 .. names.len - 1], names[1..]) |a, b| {
        try std.testing.expect(std.mem.lessThan(u8, a, b));
    }
}
