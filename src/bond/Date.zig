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
