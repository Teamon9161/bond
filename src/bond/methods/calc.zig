const std = @import("std");

const Date = @import("../../Date.zig");
const Actual = @import("../../day_counter.zig").Actual;
const ALLOC = @import("../../root.zig").ALLOC;
const Bond = @import("../Bond.zig");

const calc = @This();
fn F64(x: anytype) f64 {
    return @as(f64, @floatFromInt(x));
}

/// 获取上一付息日和下一付息日
pub fn nearestCpDate(self: *const Bond, date: Date) !struct { Date, Date } {
    if (self.isZeroCoupon()) {
        return error.ZeroCouponHasNoCouponDates;
    }

    const valid_date = try self.ensureDateValid(date);
    const date_offset = try self.cpOffset();

    var cp_date = self.carry_date;
    var cp_date_next = try cp_date.shiftMonths(date_offset);

    // 最多循环220次（理论上50年债券不会超过这个次数）
    var i: u16 = 0;
    while (i < 220) : (i += 1) {
        if (valid_date.gte(cp_date) and valid_date.lt(cp_date_next)) {
            return .{ cp_date, cp_date_next };
        }
        cp_date = cp_date_next;
        cp_date_next = try cp_date.shiftMonths(date_offset);
    }

    return error.FailedToFindNearestCouponDate;
}

test "bond nearestCpDate" {
    var bond = @import("../testing.zig").createBond();
    const date = @import("../../root.zig").date;
    defer bond.deinit(null);

    // 测试年付息债券
    bond.inst_freq = 1;
    bond.carry_date = date(2014, 6, 15);
    bond.maturity_date = date(2024, 6, 15);

    const date1 = date(2018, 3, 15);
    const cp_dates = try bond.nearestCpDate(date1);

    try std.testing.expectEqual(date(2017, 6, 15), cp_dates[0]);
    try std.testing.expectEqual(date(2018, 6, 15), cp_dates[1]);

    // 测试半年付息债券
    bond.inst_freq = 2;
    const date2 = try Date.create(2018, 9, 15);
    const cp_dates2 = try bond.nearestCpDate(date2);

    try std.testing.expectEqual(try Date.create(2018, 6, 15), cp_dates2[0]);
    try std.testing.expectEqual(try Date.create(2018, 12, 15), cp_dates2[1]);
}

/// 剩余的付息次数
pub fn remainCpNum(self: *const Bond, date: Date, next_cp_date: ?Date) !i32 {
    const next_cp = next_cp_date orelse (try self.nearestCpDate(date))[1];
    var cp_num: i32 = 0;
    var current_cp_date = next_cp;
    const offset = try self.cpOffset();
    // TODO: 数据是否确实存在到期日不同于发行日的情况？如果存在，是后延还是提前？
    // 当下一付息日正好等于到期日时，目前正好返回1，也是正确的
    const maturity_date = self.maturity_date.shiftDays(3); // 减去3天避免节假日导致的计算偏差
    while (current_cp_date.lte(maturity_date)) {
        cp_num += 1;
        current_cp_date = try current_cp_date.shiftMonths(offset);
    }

    return cp_num;
}

test "bond remainCpNum" {
    var bond = @import("../testing.zig").createBond();
    const date = @import("../../root.zig").date;

    defer bond.deinit(null);

    // 测试年付息债券
    bond.inst_freq = 1;
    bond.carry_date = date(2014, 6, 15);
    bond.maturity_date = date(2024, 6, 15);

    const date1 = date(2018, 3, 15);
    const remain_num = try bond.remainCpNum(date1, null);
    try std.testing.expectEqual(@as(i32, 7), remain_num);

    // 测试半年付息债券
    bond.inst_freq = 2;
    const date2 = date(2018, 9, 15);
    const remain_num2 = try bond.remainCpNum(date2, null);
    try std.testing.expectEqual(@as(i32, 12), remain_num2);
}

/// 剩余的付息次数直到指定日期
pub fn remainCpNumUntil(self: *const Bond, date: Date, until_date: Date, next_cp_date: ?Date) !i32 {
    const next_cp = next_cp_date orelse (try self.nearestCpDate(date))[1];

    if (next_cp.gte(until_date)) {
        // 不同于债券到期日的剩余付息次数计算，这种情况可能在截止日期前不会再有付息
        // 参考python代码，目前当期货缴款日正好是付息日时，按0处理
        // TODO: 检查等于的情况是否正确
        return 0;
    }

    var cp_num: i32 = 0;
    var current_cp_date = next_cp;
    const offset = try self.cpOffset();

    while (current_cp_date.lt(until_date)) {
        cp_num += 1;
        current_cp_date = try current_cp_date.shiftMonths(offset);
    }

    return cp_num;
}

/// 获得剩余的付息日期列表(不包含until_date)
pub fn remainCpDatesUntil(self: *const Bond, date: Date, until_date: Date, next_cp_date: ?Date, allocator: ?std.mem.Allocator) ![]Date {
    const alloc = allocator orelse ALLOC;
    const next_cp = next_cp_date orelse (try self.nearestCpDate(date))[1];

    if (next_cp.gte(until_date)) {
        return try alloc.alloc(Date, 0);
    }

    var cp_dates = std.ArrayList(Date).init(alloc);
    defer cp_dates.deinit();

    var current_cp_date = next_cp;
    const offset = try self.cpOffset();

    while (current_cp_date.lt(until_date)) {
        try cp_dates.append(current_cp_date);
        current_cp_date = try current_cp_date.shiftMonths(offset);
    }

    return try cp_dates.toOwnedSlice();
}

/// 最后一个计息年度的天数
pub fn getLastCpYearDays(self: *const Bond) !i64 {
    const offset = try self.cpOffset();
    var cp_date = try self.maturity_date.shiftMonths(-offset);

    while (cp_date.year == self.maturity_date.year) {
        cp_date = try cp_date.shiftMonths(-offset);
    }

    var day_counts = try Actual.countDays(cp_date, self.maturity_date);

    while (day_counts < 360) {
        // 小于360天说明是一年多次付息的情况,排除该付息日继续向前找
        cp_date = try cp_date.shiftMonths(-offset);
        day_counts = try Actual.countDays(cp_date, self.maturity_date);
    }

    if (day_counts >= 380) {
        return error.LastCouponYearDaysTooLong;
    }

    return day_counts;
}

test "bond getLastCpYearDays" {
    var bond = @import("../testing.zig").createBond();
    const date = @import("../../root.zig").date;

    defer bond.deinit(null);

    // 测试年付息债券
    bond.inst_freq = 1;
    bond.carry_date = date(2014, 6, 15);
    bond.maturity_date = date(2024, 6, 15);

    const last_days = try bond.getLastCpYearDays();
    try std.testing.expectEqual(last_days, 366);
}

/// 计算应计利息
pub fn calcAccruedInterest(self: *const Bond, calculating_date: Date, cp_dates: ?struct { Date, Date }) !f64 {
    if (self.isZeroCoupon()) {
        return 0.0;
    }

    const cp_dates_tuple = cp_dates orelse try self.nearestCpDate(calculating_date);
    const pre_cp_date = cp_dates_tuple[0];
    const next_cp_date = cp_dates_tuple[1];

    switch (self.mkt) {
        .ib => {
            // 银行间是算头不算尾，计算实际天数（自然日）
            const inst_accrued_days = try Actual.countDays(pre_cp_date, calculating_date);
            const coupon_value = self.coupon();
            // 当前付息周期实际天数
            const present_cp_period_days = try Actual.countDays(pre_cp_date, next_cp_date);
            return coupon_value * F64(inst_accrued_days) / F64(present_cp_period_days);
        },
        .sse, .sh, .sze, .sz => {
            // 交易所是算头又算尾
            const inst_accrued_days = 1 + try Actual.countDays(pre_cp_date, calculating_date);
            return self.cp_rate_1st * self.par_value * F64(inst_accrued_days) / 365.0;
        },
    }
}

/// 通过ytm计算债券全价
pub fn calcDirtyPriceWithYtm(self: *const Bond, ytm: f64, date: Date, cp_dates: ?struct { Date, Date }, remain_cp_num: ?i32) !f64 {
    const inst_freq = F64(self.inst_freq);
    const coupon_value = self.coupon();
    const cp_dates_tuple = cp_dates orelse try self.nearestCpDate(date);
    const remain_days = F64(try Actual.countDays(date, cp_dates_tuple[1]));
    const n = remain_cp_num orelse try self.remainCpNum(date, null);

    // TODO: take day_count into account
    if (n <= 1) {
        const ty = F64(try self.getLastCpYearDays());
        const forward_value = self.par_value + coupon_value;
        const discount_factor = 1.0 + ytm * remain_days / ty;
        return forward_value / discount_factor;
    } else {
        const ty = F64(try Actual.countDays(cp_dates_tuple[0], cp_dates_tuple[1]));
        var coupon_cf: f64 = 0.0;

        var i: i32 = 0;
        while (i < n) : (i += 1) {
            const discount_factor = std.math.pow(f64, 1.0 + ytm / inst_freq, remain_days / ty + F64(i));
            coupon_cf += coupon_value / discount_factor;
        }

        const discount_factor = std.math.pow(f64, 1.0 + ytm / inst_freq, remain_days / ty + F64(n - 1));
        return self.par_value / discount_factor + coupon_cf;
    }
}

/// 通过ytm计算债券净价
pub fn calcCleanPriceWithYtm(self: *const Bond, ytm: f64, date: Date, cp_dates: ?struct { Date, Date }, remain_cp_num: ?i32) !f64 {
    const cp_dates_tuple = cp_dates orelse try self.nearestCpDate(date);
    const remain_num = remain_cp_num orelse try self.remainCpNum(date, null);

    const dirty_price = try self.calcDirtyPriceWithYtm(ytm, date, cp_dates_tuple, remain_num);
    const accrued_interest = try self.calcAccruedInterest(date, cp_dates_tuple);

    return dirty_price - accrued_interest;
}

/// 通过债券全价计算ytm
pub fn calcYtmWithPrice(self: *const Bond, dirty_price: f64, date: Date, cp_dates: ?struct { Date, Date }, remain_cp_num: ?i32) !f64 {
    switch (self.interest_type) {
        .fixed => {
            const inst_freq = F64(self.inst_freq);
            const coupon_value = self.coupon();
            const cp_dates_tuple = cp_dates orelse try self.nearestCpDate(date);
            const remain_days = F64(try Actual.countDays(date, cp_dates_tuple[1]));

            const n = remain_cp_num orelse try self.remainCpNum(date, null);
            const utils = @import("../utils.zig");
            if (n > 1) {
                const ty = F64(try Actual.countDays(cp_dates_tuple[0], cp_dates_tuple[1]));
                const context = .{ .n = n, .inst_freq = inst_freq, .remain_days = remain_days, .ty = ty, .coupon_value = coupon_value, .par_value = self.par_value, .dirty_price = dirty_price };
                // 直接定义目标函数，捕获需要的变量
                const func = struct {
                    pub fn f(ytm: f64, c: anytype) f64 {
                        // 计算票息现金流的现值
                        var coupon_cf: f64 = 0.0;
                        var i: i32 = 0;
                        while (i < c.n) : (i += 1) {
                            const discount_factor = std.math.pow(f64, 1.0 + ytm / c.inst_freq, c.remain_days / c.ty + F64(i));
                            coupon_cf += c.coupon_value / discount_factor;
                        }
                        // 本金的现值
                        const discount_factor = std.math.pow(f64, 1.0 + ytm / c.inst_freq, c.remain_days / c.ty + F64(c.n - 1));
                        return c.par_value / discount_factor + coupon_cf - c.dirty_price;
                    }
                }.f;

                return utils.bisectionFindRoot(func, 1e-4, 0.3, 12, context);
            } else {
                const ty = F64(try self.getLastCpYearDays());
                const forward_value = self.par_value + coupon_value;
                return (forward_value - dirty_price) / dirty_price / (remain_days / ty);
            }
        },
        else => return error.UnsupportedInterestType,
    }
}

/// 麦考利久期
pub fn calcMacaulayDuration(self: *const Bond, ytm: f64, date: Date, cp_dates: ?struct { Date, Date }, remain_cp_num: ?i32, allocator: ?std.mem.Allocator) !f64 {
    const alloc = allocator orelse ALLOC;
    const inst_freq = F64(self.inst_freq);
    const coupon_value = self.coupon();
    const cp_dates_tuple = cp_dates orelse try self.nearestCpDate(date);
    const pre_cp_date = cp_dates_tuple[0];
    const next_cp_date = cp_dates_tuple[1];
    const remain_days = F64(try Actual.countDays(date, next_cp_date));
    const ty = F64(try Actual.countDays(pre_cp_date, next_cp_date));
    const n = remain_cp_num orelse try self.remainCpNum(date, null);

    var cashflows = std.ArrayList(struct { f64, f64 }).init(alloc);
    defer cashflows.deinit();

    // 添加付息现金流
    var i: i32 = 0;
    while (i < n) : (i += 1) {
        const discount_factor = std.math.pow(f64, 1.0 + ytm / inst_freq, remain_days / ty + F64(i));
        const cashflow = coupon_value / discount_factor;
        const time = remain_days / 365.0 + F64(i) / inst_freq;
        try cashflows.append(.{ cashflow, time });
    }

    // 添加本金偿还现金流
    const principal_discount_factor = std.math.pow(f64, 1.0 + ytm / inst_freq, remain_days / ty + F64(n - 1));
    const principal_cashflow = self.par_value / principal_discount_factor;
    const principal_time = remain_days / 365.0 + F64(n - 1) / inst_freq;
    try cashflows.append(.{ principal_cashflow, principal_time });

    var total_pv: f64 = 0.0;
    var weighted_time: f64 = 0.0;

    for (cashflows.items) |cf| {
        total_pv += cf[0];
        weighted_time += cf[0] * cf[1];
    }

    return weighted_time / total_pv;
}

/// 修正久期
pub fn calcDuration(self: *const Bond, ytm: f64, date: Date, cp_dates: ?struct { Date, Date }, remain_cp_num: ?i32, allocator: ?std.mem.Allocator) !f64 {
    const macaulay_duration = try self.calcMacaulayDuration(ytm, date, cp_dates, remain_cp_num, allocator);
    return macaulay_duration / (1.0 + ytm / F64(self.inst_freq));
}

test "bond calc" {
    const date = @import("../../root.zig").date;
    const expect = std.testing.expectApproxEqAbs;
    var bond = Bond{
        .cp_rate_1st = 0.0228,
        .inst_freq = 1,
        .carry_date = date(2024, 3, 25),
        .maturity_date = date(2031, 3, 25),
    };

    const dt = date(2024, 8, 12);
    try expect(try bond.calcAccruedInterest(dt, null), 0.8745205479452056, 1e-10);
    try expect(try bond.calcDirtyPriceWithYtm(0.02115, dt, null, null), 101.87774695275598, 1e-10);
    try expect(try bond.calcCleanPriceWithYtm(0.02115, dt, null, null), 101.00322640481077, 1e-10);
    try expect(try bond.calcDuration(0.02115, dt, null, null, null), 6.040420842016215, 1e-10);
}

comptime {
    std.testing.refAllDecls(@This());
}
