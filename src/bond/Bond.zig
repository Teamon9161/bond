const std = @import("std");
const json = std.json;

pub const enums = @import("enums.zig");
const Date = @import("Date.zig");
const Bond = @This();

const Market = enums.Market;
const CouponType = enums.CouponType;
const InterestType = enums.InterestType;
const BondDayCount = enums.BondDayCount;
const ALLOC = @import("../root.zig").ALLOC;
const TEST_BOND_PATH = "test/data";

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

test "bond init" {
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

pub fn fromJson(json_str: []const u8, allocator: ?std.mem.Allocator) !Bond {
    const alloc = allocator orelse ALLOC;
    const parsed = try json.parseFromSlice(@This(), alloc, json_str, .{});
    defer parsed.deinit();

    var bond = parsed.value;

    // 复制字符串字段到持久内存
    bond.bond_code = try alloc.dupe(u8, bond.bond_code);
    bond.abbr = try alloc.dupe(u8, bond.abbr);

    return bond;
}

test "bond from_json" {
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

    var bond = try Bond.fromJson(json_str, null);
    defer bond.deinit(null);

    try std.testing.expectEqualStrings("2400006.IB", bond.bond_code);
    try std.testing.expectEqualStrings("2400006", bond.code());
    try std.testing.expectEqualStrings("24特别国债06", bond.abbr);
    try std.testing.expectEqual(@as(f64, 0.0219), bond.cp_rate_1st);
    try std.testing.expectEqual(@as(i32, 2), bond.inst_freq);
    try std.testing.expectEqual(Market.ib, bond.mkt);
    try std.testing.expectEqual(@as(f64, 100.0), bond.par_value);
    try std.testing.expectEqual(.coupon_bear, bond.cp_type);
    try std.testing.expectEqual(.fixed, bond.interest_type);
    try std.testing.expectEqual(@as(?f64, null), bond.base_rate);
    try std.testing.expectEqual(@as(?f64, null), bond.rate_spread);
    try std.testing.expectEqual(.act_act, bond.day_count);

    // 测试日期解析
    try std.testing.expectEqual(@as(i32, 2024), bond.carry_date.year);
    try std.testing.expectEqual(@as(u4, 9), bond.carry_date.month);
    try std.testing.expectEqual(@as(u5, 25), bond.carry_date.day);

    try std.testing.expectEqual(@as(i32, 2054), bond.maturity_date.year);
    try std.testing.expectEqual(@as(u4, 9), bond.maturity_date.month);
    try std.testing.expectEqual(@as(u5, 25), bond.maturity_date.day);
}

pub fn readPath(path: []const u8, allocator: ?std.mem.Allocator) !Bond {
    const alloc = allocator orelse ALLOC;
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const contents = try file.readToEndAlloc(alloc, 512);
    defer alloc.free(contents);

    return try Bond.fromJson(contents, alloc);
}

test "bond readPath" {
    var bond = try Bond.readPath("test/data/2400006.IB.json", null);
    defer bond.deinit(null);

    try std.testing.expectEqualStrings("2400006.IB", bond.bond_code);
    try std.testing.expectEqualStrings("2400006", bond.code());
    try std.testing.expectEqualStrings("24特别国债06", bond.abbr);
}

pub fn getSavePath(code_str: []const u8, path: ?[]const u8, allocator: ?std.mem.Allocator) ![]const u8 {
    const alloc = allocator orelse ALLOC;
    const file_name = try std.mem.concat(alloc, u8, &.{ code_str, ".json" });
    defer alloc.free(file_name);
    if (path) |p| {
        return try std.fs.path.join(alloc, &.{ p, file_name });
    } else {
        return try std.fs.path.join(alloc, &.{ "bonds_info", file_name });
    }
}

test "bond getSavePath" {
    const path = try Bond.getSavePath("2400006.IB", null, null);
    defer ALLOC.free(path);
    try std.testing.expectEqualStrings("bonds_info/2400006.IB.json", path);
    const path2 = try Bond.getSavePath("2400006.IB", TEST_BOND_PATH, null);
    defer ALLOC.free(path2);
    try std.testing.expectEqualStrings(TEST_BOND_PATH ++ "/2400006.IB.json", path2);
    const path3 = try Bond.getSavePath("2400006.IB", "bonds_info/", null);
    defer ALLOC.free(path3);
    try std.testing.expectEqualStrings("bonds_info/2400006.IB.json", path3);
}

pub fn init(code_str: []const u8, path: ?[]const u8, allocator: ?std.mem.Allocator) !Bond {
    const alloc = allocator orelse ALLOC;
    const empty_source_flag = std.mem.indexOf(u8, code_str, ".") == null;
    const file_name = if (empty_source_flag) blk: {
        break :blk try std.mem.concat(alloc, u8, &.{ code_str, ".IB" });
    } else code_str;
    defer if (empty_source_flag) alloc.free(file_name);
    const file_path = try Bond.getSavePath(file_name, path, alloc);
    defer alloc.free(file_path);
    const bond = try Bond.readPath(file_path, alloc);
    return bond;
}

test "read bond from file" {
    var bond = try Bond.init("2400006.IB", TEST_BOND_PATH, null);
    defer bond.deinit(null);
    try std.testing.expectEqualStrings("2400006.IB", bond.bond_code);
    try std.testing.expectEqualStrings("2400006", bond.code());
    try std.testing.expectEqualStrings("24特别国债06", bond.abbr);
    try std.testing.expectEqual(@as(f64, 0.0219), bond.cp_rate_1st);
}

pub fn isZeroCoupon(self: *const Bond) bool {
    return self.cp_type == .zero_coupon;
}

test "bond isZeroCoupon" {
    var bond = try Bond.init("2400006.IB", TEST_BOND_PATH, null);
    defer bond.deinit(null);
    try std.testing.expectEqual(false, bond.isZeroCoupon());
}

pub fn remainYear(self: *const Bond, date: Date) f64 {
    const year_diff: f64 = @floatFromInt(@as(i32, self.maturity_date.year) - @as(i32, date.year));
    const month_diff: f64 = @floatFromInt(@as(i32, self.maturity_date.month) - @as(i32, date.month));
    const day_diff: f64 = @floatFromInt(@as(i32, self.maturity_date.day) - @as(i32, date.day));
    return year_diff + month_diff / 12.0 + day_diff / 365.0;
}

test "bond remainYear" {
    var bond = try Bond.init("2400006.IB", TEST_BOND_PATH, null);
    defer bond.deinit(null);
    try std.testing.expectEqual(@as(f64, 30.0), bond.remainYear(try Date.create(2024, 9, 25)));
    try std.testing.expectEqual(@as(f64, 1.5 + 5.0 / 365.0), bond.remainYear(try Date.create(2053, 3, 20)));
}

comptime {
    std.testing.refAllDecls(@This());
}
