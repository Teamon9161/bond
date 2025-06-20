//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const builtin = @import("builtin");

pub const Bond = @import("bond/Bond.zig");
pub const enums = @import("bond/enums.zig");
pub const Date = @import("Date.zig");

pub fn date(year: u32, month: u32, day: u32) Date {
    return Date.create(year, month, day) catch unreachable;
}

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub const ALLOC = if (@import("builtin").is_test)
    std.testing.allocator
else switch (builtin.mode) {
    .Debug, .ReleaseSafe => debug_allocator.allocator(),
    .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
};

// pub const test_allocator = if (@import("builtin").is_test) std.testing.allocator else null;

comptime {
    std.testing.refAllDecls(@This());
}
