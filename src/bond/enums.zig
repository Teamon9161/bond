const std = @import("std");

fn makeJsonParse(comptime T: type) fn (std.mem.Allocator, anytype, std.json.ParseOptions) anyerror!T {
    return struct {
        fn impl(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !T {
            const str = try std.json.innerParse([]const u8, allocator, source, options);
            return T.parse(str) catch {
                return error.InvalidEnumTag;
            };
        }
    }.impl;
}
/// 市场类型
pub const Market = enum(u8) {
    /// 银行间
    ib = 0,
    /// 上交所
    sse = 1,
    /// 上交所（同义词）
    sh = 2,
    /// 深交所
    sze = 3,
    /// 深交所（同义词）
    sz = 4,

    pub const jsonParse = makeJsonParse(@This());

    pub fn parse(str: []const u8) !@This() {
        if (std.mem.eql(u8, str, "IB")) {
            return .ib;
        } else if (std.mem.eql(u8, str, "SSE") or std.mem.eql(u8, str, "SH")) {
            return .sse;
        } else if (std.mem.eql(u8, str, "SZE") or std.mem.eql(u8, str, "SZ")) {
            return .sze;
        } else {
            return error.InvalidMarket;
        }
    }
};

test "Market.jsonParse" {
    const bytes =
        \\ {
        \\    "mkt": "SH"
        \\}
    ;
    const res = try std.json.parseFromSlice(struct { mkt: Market }, std.testing.allocator, bytes, .{});
    defer res.deinit();
    try std.testing.expectEqual(res.value.mkt, .sse);
}

/// 息票品种
pub const CouponType = enum(u8) {
    /// 附息债券
    coupon_bear = 0,
    /// 零息债券
    zero_coupon = 1,
    /// 一次性付息
    one_time = 2,

    pub const jsonParse = makeJsonParse(@This());

    pub fn parse(str: []const u8) !@This() {
        if (std.mem.eql(u8, str, "Coupon_Bear")) {
            return .coupon_bear;
        } else if (std.mem.eql(u8, str, "Zero_Coupon")) {
            return .zero_coupon;
        } else if (std.mem.eql(u8, str, "One_Time")) {
            return .one_time;
        } else {
            return error.InvalidCouponType;
        }
    }
};

/// 息票利率类型
pub const InterestType = enum(u8) {
    /// 固定利率
    fixed = 0,
    /// 浮动利率
    floating = 1,
    /// 累进利率
    progressive = 2,
    /// 零息
    zero = 3,

    pub const jsonParse = makeJsonParse(@This());

    pub fn parse(str: []const u8) !@This() {
        if (std.mem.eql(u8, str, "Fixed")) {
            return .fixed;
        } else if (std.mem.eql(u8, str, "Floating")) {
            return .floating;
        } else if (std.mem.eql(u8, str, "Progressive")) {
            return .progressive;
        } else if (std.mem.eql(u8, str, "Zero")) {
            return .zero;
        } else {
            return error.InvalidInterestType;
        }
    }
};

/// 计息基准
pub const BondDayCount = enum(u8) {
    /// 实际天数/实际天数
    act_act = 0,
    /// 实际天数/365
    act_365 = 1,
    /// 实际天数/360
    act_360 = 2,
    /// 实际天数/365F
    act_365f = 3,
    /// 30/365
    thirty_365 = 4,
    /// 30/360
    thirty_360 = 5,
    /// 工作日
    bus = 6,
    /// 银行间工作日
    bus_ib = 7,
    /// 上交所工作日
    bus_sse = 8,

    pub fn parse(str: []const u8) !@This() {
        if (std.mem.eql(u8, str, "ACT/ACT")) {
            return .act_act;
        } else if (std.mem.eql(u8, str, "A/365")) {
            return .act_365;
        } else if (std.mem.eql(u8, str, "A/360")) {
            return .act_360;
        } else if (std.mem.eql(u8, str, "A/365F")) {
            return .act_365f;
        } else if (std.mem.eql(u8, str, "T/365")) {
            return .thirty_365;
        } else if (std.mem.eql(u8, str, "T/360")) {
            return .thirty_360;
        } else if (std.mem.eql(u8, str, "Bus")) {
            return .bus;
        } else if (std.mem.eql(u8, str, "BUSIB")) {
            return .bus_ib;
        } else if (std.mem.eql(u8, str, "BUSSSE")) {
            return .bus_sse;
        } else {
            return error.InvalidBondDayCount;
        }
    }

    pub const jsonParse = makeJsonParse(@This());
};
