const Bond = @import("Bond.zig");
const Date = @import("../Date.zig");
const std = @import("std");
const attr = @This();

/// 判断债券是否为零息债券
pub fn isZeroCoupon(self: *const Bond) bool {
    return self.cp_type == .zero_coupon;
}

test "bond isZeroCoupon" {
    var bond = @import("testing.zig").createBond();
    defer bond.deinit(null);
    try std.testing.expectEqual(false, bond.isZeroCoupon());
}

/// 获取债券代码（不包含交易所后缀）
pub fn code(self: *const Bond) []const u8 {
    if (std.mem.indexOf(u8, self.bond_code, ".")) |dot_index| {
        return self.bond_code[0..dot_index];
    }
    return self.bond_code;
}

/// 获取债券发行年限
pub fn issueYear(self: *const Bond) i32 {
    return @intCast(self.maturity_date.year - self.carry_date.year);
}

test "bond issueYear" {
    var bond = @import("testing.zig").createBond();
    defer bond.deinit(null);
    try std.testing.expectEqual(@as(i32, 30), bond.issueYear());
}

/// 计算债券剩余年数
pub fn remainYear(self: *const Bond, date: Date) f64 {
    const year_diff: f64 = @floatFromInt(@as(i32, self.maturity_date.year) - @as(i32, date.year));
    const month_diff: f64 = @floatFromInt(@as(i32, self.maturity_date.month) - @as(i32, date.month));
    const day_diff: f64 = @floatFromInt(@as(i32, self.maturity_date.day) - @as(i32, date.day));
    return year_diff + month_diff / 12.0 + day_diff / 365.0;
}

test "bond remainYear" {
    var bond = @import("testing.zig").createBond();
    defer bond.deinit(null);
    try std.testing.expectEqual(@as(f64, 30.0), bond.remainYear(try Date.create(2024, 9, 25)));
    try std.testing.expectEqual(@as(f64, 1.5 + 5.0 / 365.0), bond.remainYear(try Date.create(2053, 3, 20)));
}

/// 获取区间付息（单个付息周期的利息金额）
pub fn coupon(self: *const Bond) f64 {
    return self.cp_rate_1st * self.par_value / @as(f64, @floatFromInt(self.inst_freq));
}

test "bond coupon" {
    var bond = @import("testing.zig").createBond();
    defer bond.deinit(null);
    try std.testing.expectEqual(@as(f64, 0.0219 * 100.0 / 2.0), bond.coupon());
}

/// 获取付息间隔（月数）
pub fn cpOffset(self: *const Bond) !u32 {
    return switch (self.inst_freq) {
        0 => 0,
        1 => 12,
        2 => 6,
        else => error.InvalidInstFreq,
    };
}

test "bond cpOffset" {
    var bond = @import("testing.zig").createBond();
    defer bond.deinit(null);
    try std.testing.expectEqual(6, try bond.cpOffset());
}

/// 确保日期在有效范围内
pub fn ensureDateValid(self: *const Bond, date: Date) !Date {
    if (date.lt(self.carry_date)) {
        // std.debug.print("计算日期 {}-{}-{} 早于债券 {s} 的起息日 {}-{}-{}, 调整为起息日\n", .{
        //     date.year,           date.month,           date.day,
        //     self.code(),         self.carry_date.year, self.carry_date.month,
        //     self.carry_date.day,
        // });
        return self.carry_date;
    } else if (date.gt(self.maturity_date)) {
        return error.DateAfterMaturityDate;
    }
    return date;
}

test "bond ensureDateValid" {
    var bond = @import("testing.zig").createBond();
    defer bond.deinit(null);
    var date = try Date.create(2024, 9, 23);
    try std.testing.expectEqual(try Date.create(2024, 9, 25), try bond.ensureDateValid(date));
    date = try Date.create(2058, 9, 25);
    try std.testing.expectError(error.DateAfterMaturityDate, bond.ensureDateValid(date));
    date = try Date.create(2028, 4, 25);
    try std.testing.expectEqual(date, try bond.ensureDateValid(date));
}

comptime {
    std.testing.refAllDecls(@This());
}
