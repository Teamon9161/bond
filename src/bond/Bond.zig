const std = @import("std");
const json = std.json;

pub const enums = @import("enums.zig");
const Date = @import("../Date.zig");
/// attribute methods
const attr = @import("attr.zig");
/// io methods
const io = @import("io.zig");

const Bond = @This();
const Market = enums.Market;
const CouponType = enums.CouponType;
const InterestType = enums.InterestType;
const BondDayCount = enums.BondDayCount;
const ALLOC = @import("../root.zig").ALLOC;

bond_code: []const u8, // 债券代码（包含交易所后缀）
abbr: []const u8, // 债券简称
cp_rate_1st: f64, // 票面利率
inst_freq: i32, // 年付息次数
carry_date: Date, // 起息日
maturity_date: Date, // 到期日
mkt: Market = .ib, // 市场
par_value: f64 = 100.0, // 债券面值
cp_type: CouponType = .coupon_bear, // 息票品种
interest_type: InterestType = .fixed, // 息票利率类型
base_rate: ?f64 = null, // 基准利率
rate_spread: ?f64 = null, // 固定利差
day_count: BondDayCount = .act_365, // 计息基准

pub usingnamespace io;
pub usingnamespace attr;

test "bond create" {
    // 创建一个债券实例
    const bond = Bond{
        .bond_code = "123456.IB", // 债券代码
        .abbr = "", // 债券简称
        .cp_rate_1st = 0.03, // 票面利率3%
        .inst_freq = 2, // 年付息2次
        .carry_date = try Date.create(2023, 1, 1), // 起息日
        .maturity_date = try Date.create(2025, 1, 1), // 到期日
    };
    try std.testing.expectEqualStrings(bond.bond_code, "123456.IB");
    try std.testing.expectEqualStrings(bond.code(), "123456");
}

/// 释放分配的内存
pub fn deinit(self: *Bond, allocator: ?std.mem.Allocator) void {
    const alloc = allocator orelse ALLOC;
    alloc.free(self.bond_code);
    alloc.free(self.abbr);
}

comptime {
    std.testing.refAllDecls(@This());
}
