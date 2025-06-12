const std = @import("std");
const json = std.json;

const Date = @import("../Date.zig");
const ALLOC = @import("../root.zig").ALLOC;

pub const enums = @import("enums.zig");
const Market = enums.Market;
const CouponType = enums.CouponType;
const InterestType = enums.InterestType;
const BondDayCount = enums.BondDayCount;
/// attribute methods
const attr = @import("methods/attr.zig");
/// calculation methods
const calc = @import("methods/calc.zig");
/// io methods
const io = @import("methods/io.zig");

const wind_download = @import("download/wind.zig");

const Bond = @This();
bond_code: []const u8 = "", // 债券代码（包含交易所后缀）
abbr: []const u8 = "", // 债券简称
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
pub usingnamespace calc;

pub const DownloadSource = enum(u8) {
    wind = 0,
    pub fn close(self: DownloadSource) void {
        switch (self) {
            .wind => wind_download.closeWind(),
        }
    }
};
const CloseFn = fn () void;

pub fn download(code: []const u8, options: struct {
    save_folder: ?[]const u8 = null,
    source: DownloadSource = .wind,
}) !Bond {
    const save_folder = options.save_folder orelse "bonds_info";
    switch (options.source) {
        .wind => {
            const bonds = try wind_download.downloadBonds(&[_][]const u8{code}, save_folder);
            defer ALLOC.free(bonds);
            return bonds[0];
        },
    }
}

test "bond download" {
    const code = "250205.IB";
    std.debug.print("Starting bond download test...\n", .{});
    var bond = try download(code, .{
        .source = .wind,
    });
    DownloadSource.wind.close();
    defer bond.deinit(null);
    std.debug.print("Download completed, got bond: {s}\n", .{bond.abbr});
    try std.testing.expectEqualStrings(bond.abbr, "25国开05");
}

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
pub fn deinit(self: Bond, allocator: ?std.mem.Allocator) void {
    const alloc = allocator orelse ALLOC;
    alloc.free(self.bond_code);
    alloc.free(self.abbr);
}

comptime {
    std.testing.refAllDecls(@This());
}
