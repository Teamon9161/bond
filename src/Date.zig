const std = @import("std");

const _Date = @import("datetime").datetime.Date;

const Date = @This();

year: u16,
month: u4 = 1, // Month of year
day: u8 = 1, // Day of month

pub inline fn fromInner(inner: _Date) Date {
    return Date{
        .year = inner.year,
        .month = inner.month,
        .day = inner.day,
    };
}

pub inline fn toInner(self: Date) _Date {
    return _Date{
        .year = self.year,
        .month = self.month,
        .day = self.day,
    };
}

pub fn create(year: u32, month: u32, day: u32) !Date {
    const date = try _Date.create(year, month, day);
    return @This().fromInner(date);
}

pub fn fromOrdinal(ordinal: u32) !Date {
    const date = _Date.fromOrdinal(ordinal);
    return @This().fromInner(date);
}

pub fn toOrdinal(self: Date) u32 {
    return self.toInner().toOrdinal();
}

// === Parse ===

pub fn parseIso(str: []const u8) !Date {
    const date = try _Date.parseIso(str);
    return @This().fromInner(date);
}

// === Json Support ===
pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Date {
    const str = try std.json.innerParse([]const u8, allocator, source, options);
    return Date.parseIso(str) catch {
        return error.SyntaxError;
    };
}

pub fn jsonStringify(self: Date, jws: anytype) !void {
    const str = try self.formatIso(null);
    defer @import("root.zig").ALLOC.free(str);
    return try jws.print("\"{s}\"", .{str});
}

test "date jsonParse" {
    const bytes =
        \\ {
        \\    "date": "2024-09-25"
        \\}
    ;
    const res = try std.json.parseFromSlice(struct { date: Date }, std.testing.allocator, bytes, .{});
    defer res.deinit();
    try std.testing.expectEqual(res.value.date.year, 2024);
}

// Return date in ISO format YYYY-MM-DD
const ISO_DATE_FMT = "{:0>4}-{:0>2}-{:0>2}";

pub fn formatIso(self: Date, allocator: ?std.mem.Allocator) ![]u8 {
    const alloc = allocator orelse @import("root.zig").ALLOC;
    return std.fmt.allocPrint(alloc, ISO_DATE_FMT, .{ self.year, self.month, self.day });
}

pub fn formatIsoBuf(self: Date, buf: []u8) ![]u8 {
    return std.fmt.bufPrint(buf, ISO_DATE_FMT, .{ self.year, self.month, self.day });
}

pub fn writeIso(self: Date, writer: anytype) !void {
    try std.fmt.format(writer, ISO_DATE_FMT, .{ self.year, self.month, self.day });
}

test "date formatIso" {
    var buf: [11]u8 = undefined;
    const date = try Date.create(2024, 9, 25);
    try std.testing.expectEqualStrings("2024-09-25", try date.formatIsoBuf(buf[0..]));
}

// === Shift ===

/// Different from datetime.Date.shiftYears, this function will not consider leap year
/// if you want to shift years and consider leap year, you should use datetime.Date.shiftYears
pub fn shiftYears(self: Date, years: i16) !Date {
    var year = self.year;
    if (years < 0) {
        year -= @intCast(-years);
    } else {
        year += @intCast(years);
    }
    return Date.create(year, self.month, self.day);
}

pub fn shiftMonths(date: Date, months: i32) !Date {
    var new_year = date.year;
    var new_month: i32 = @intCast(date.month);

    new_month += months;

    while (new_month > 12) {
        new_month -= 12;
        new_year += 1;
    }

    while (new_month <= 0) {
        new_month += 12;
        new_year -= 1;
    }

    return Date.create(new_year, @intCast(new_month), date.day);
}

test "date shiftMonths" {
    const date = try Date.create(2024, 9, 25);
    const new_date = try date.shiftMonths(1);
    try std.testing.expectEqual(new_date, try Date.create(2024, 10, 25));
    const new_date2 = try date.shiftMonths(-1);
    try std.testing.expectEqual(new_date2, try Date.create(2024, 8, 25));
    const new_date3 = try date.shiftMonths(13);
    try std.testing.expectEqual(new_date3, try Date.create(2025, 10, 25));
    const new_date4 = try date.shiftMonths(-33);
    try std.testing.expectEqual(new_date4, try Date.create(2021, 12, 25));
}

pub fn shiftDays(self: Date, days: i32) Date {
    const date = self.toInner().shiftDays(days);
    return @This().fromInner(date);
}

// === Comparison ===

pub fn cmp(self: Date, other: Date) std.math.Order {
    if (self.year > other.year) return .gt;
    if (self.year < other.year) return .lt;
    if (self.month > other.month) return .gt;
    if (self.month < other.month) return .lt;
    if (self.day > other.day) return .gt;
    if (self.day < other.day) return .lt;
    return .eq;
}

pub fn eq(self: Date, other: Date) bool {
    return self.cmp(other) == .eq;
}

pub fn lt(self: Date, other: Date) bool {
    return self.cmp(other) == .lt;
}

pub fn lte(self: Date, other: Date) bool {
    const r = self.cmp(other);
    return r == .eq or r == .lt;
}

pub fn gt(self: Date, other: Date) bool {
    return self.cmp(other) == .gt;
}

pub fn gte(self: Date, other: Date) bool {
    const r = self.cmp(other);
    return r == .eq or r == .gt;
}

comptime {
    std.testing.refAllDecls(@This());
}
