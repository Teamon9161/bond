pub const enums = @import("enums.zig");
pub const Date = @import("date.zig").Date;
pub const Market = enums.Market;
pub const CouponType = enums.CouponType;
pub const InterestType = enums.InterestType;
pub const BondDayCount = enums.BondDayCount;
pub const allocator = @import("../root.zig").allocator;
const std = @import("std");
const json = std.json;

/// 债券结构体
pub const Bond = struct {
    bond_code: []const u8, // 债券代码
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

    /// 获取债券代码（不包含交易所后缀）
    pub fn code(self: *const Bond) []const u8 {
        if (std.mem.indexOf(u8, self.bond_code, ".")) |dot_index| {
            return self.bond_code[0..dot_index];
        }
        return self.bond_code;
    }

    /// 释放分配的内存
    pub fn deinit(self: *Bond) void {
        allocator.free(self.bond_code);
        allocator.free(self.abbr);
    }

    pub fn from_json(json_str: []const u8) !Bond {
        const parsed = try json.parseFromSlice(@This(), allocator, json_str, .{});
        defer parsed.deinit();

        var bond = parsed.value;

        // 复制字符串字段到持久内存
        bond.bond_code = try allocator.dupe(u8, bond.bond_code);
        bond.abbr = try allocator.dupe(u8, bond.abbr);

        return bond;
    }
};

test "bond_init" {
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

test "bond_from_json" {
    const json_str =
        \\{
        \\    "bond_code": "2400006.IB",
        \\    "mkt": "IB",
        \\    "abbr": "24特别国债06",
        \\    "par_value": 100.0,
        \\    "cp_type": "Coupon_Bear",
        \\    "interest_type": "Fixed",
        \\    "cp_rate_1st": 0.0219,
        \\    "base_rate": null,
        \\    "rate_spread": null,
        \\    "inst_freq": 2,
        \\    "carry_date": "2024-09-25",
        \\    "maturity_date": "2054-09-25",
        \\    "day_count": "ACT/ACT"
        \\}
    ;

    var bond = try Bond.from_json(json_str);
    defer bond.deinit();

    try std.testing.expectEqualStrings("2400006.IB", bond.bond_code);
    try std.testing.expectEqualStrings("2400006", bond.code());
    try std.testing.expectEqualStrings("24特别国债06", bond.abbr);
    try std.testing.expectEqual(@as(f64, 0.0219), bond.cp_rate_1st);
    try std.testing.expectEqual(@as(i32, 2), bond.inst_freq);
    try std.testing.expectEqual(Market.ib, bond.mkt);
    try std.testing.expectEqual(@as(f64, 100.0), bond.par_value);
    try std.testing.expectEqual(CouponType.coupon_bear, bond.cp_type);
    try std.testing.expectEqual(InterestType.fixed, bond.interest_type);
    try std.testing.expectEqual(@as(?f64, null), bond.base_rate);
    try std.testing.expectEqual(@as(?f64, null), bond.rate_spread);
    try std.testing.expectEqual(BondDayCount.act_act, bond.day_count);

    // 测试日期解析
    try std.testing.expectEqual(@as(i32, 2024), bond.carry_date.year);
    try std.testing.expectEqual(@as(u4, 9), bond.carry_date.month);
    try std.testing.expectEqual(@as(u5, 25), bond.carry_date.day);

    try std.testing.expectEqual(@as(i32, 2054), bond.maturity_date.year);
    try std.testing.expectEqual(@as(u4, 9), bond.maturity_date.month);
    try std.testing.expectEqual(@as(u5, 25), bond.maturity_date.day);
}
