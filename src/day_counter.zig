const std = @import("std");
const Date = @import("Date.zig");

pub const Actual = struct {
    pub fn countDays(start: Date, end: Date) !u32 {
        const start_ordinal = start.toOrdinal();
        const end_ordinal = end.toOrdinal();
        if (end_ordinal < start_ordinal) {
            return error.CountDaysEndBeforeStart;
        }
        return end_ordinal - start_ordinal;
    }
};
