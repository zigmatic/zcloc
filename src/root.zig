//! Module entry point for zcloc library.
//! Re-exports the counter and language registry for use by the benchmark
//! and other consumers that import zcloc as a module.

pub const counter = @import("counter/counter.zig");
pub const registry = @import("languages/registry.zig");
