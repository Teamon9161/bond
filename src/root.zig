//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");

const bond = @import("bond/bond.zig");

// var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// pub const allocator = gpa.allocator();

pub const allocator = std.testing.allocator;

pub const Bond = bond.Bond;
pub const enums = bond.enums;
pub const Date = bond.Date;

comptime {
    std.testing.refAllDecls(@This());
}
