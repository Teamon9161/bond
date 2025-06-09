const _Date = @import("datetime").datetime.Date;
const std = @import("std");
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

pub fn create(year: u32, month: u32, day: u32) !Date {
    const date = try _Date.create(year, month, day);
    return @This().fromInner(date);
}

pub fn parseIso(str: []const u8) !Date {
    const date = try _Date.parseIso(str);
    return @This().fromInner(date);
}

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Date {
    const str = try std.json.innerParse([]const u8, allocator, source, options);
    return Date.parseIso(str) catch {
        return error.SyntaxError;
    };
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

pub fn formatIso(self: Date, buf: []u8) ![]u8 {
    return std.fmt.bufPrint(buf, "{:0>4}-{:0>2}-{:0>2}", .{ self.year, self.month, self.day });
}

test "date formatIso" {
    var buf: [11]u8 = undefined;
    const date = try Date.create(2024, 9, 25);
    try std.testing.expectEqualStrings("2024-09-25", try date.formatIso(buf[0..]));
}

comptime {
    std.testing.refAllDecls(@This());
}
