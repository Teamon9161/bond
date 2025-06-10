const std = @import("std");

const ALLOC = @import("../../root.zig").ALLOC;
const Bond = @import("../Bond.zig");

const io = @This();

/// 根据合约代码创建债券, 需要从文件读取合约信息
pub fn init(code_str: []const u8, path: ?[]const u8, allocator: ?std.mem.Allocator) !Bond {
    const alloc = allocator orelse ALLOC;
    const empty_source_flag = std.mem.indexOf(u8, code_str, ".") == null;
    const file_name = if (empty_source_flag) blk: {
        var buf: [16]u8 = undefined;
        break :blk try std.fmt.bufPrint(buf[0..], comptime "{s}.IB", .{code_str});
    } else code_str;
    const file_path = try Bond.getSavePath(file_name, path, alloc);
    defer alloc.free(file_path);
    const bond = try Bond.readPath(file_path, alloc);
    return bond;
}

test "read bond from file" {
    const path = @import("../testing.zig").TEST_BOND_PATH;
    var bond = try Bond.init("2400006.IB", path, null);
    defer bond.deinit(null);
    try std.testing.expectEqualStrings("2400006.IB", bond.bond_code);
    try std.testing.expectEqualStrings("2400006", bond.code());
    try std.testing.expectEqualStrings("24特别国债06", bond.abbr);
    try std.testing.expectEqual(@as(f64, 0.0219), bond.cp_rate_1st);
}

pub fn fromJson(json_str: []const u8, allocator: ?std.mem.Allocator) !Bond {
    const alloc = allocator orelse ALLOC;
    const parsed = try std.json.parseFromSlice(Bond, alloc, json_str, .{});
    defer parsed.deinit();

    var bond = parsed.value;

    // 复制字符串字段到持久内存
    bond.bond_code = try alloc.dupe(u8, bond.bond_code);
    bond.abbr = try alloc.dupe(u8, bond.abbr);

    return bond;
}

test "bond from_json" {
    var bond = @import("../testing.zig").createBond();
    defer bond.deinit(null);

    try std.testing.expectEqualStrings("2400006.IB", bond.bond_code);
    try std.testing.expectEqualStrings("2400006", bond.code());
    try std.testing.expectEqualStrings("24特别国债06", bond.abbr);
    try std.testing.expectEqual(@as(f64, 0.0219), bond.cp_rate_1st);
    try std.testing.expectEqual(@as(i32, 2), bond.inst_freq);
    try std.testing.expectEqual(.ib, bond.mkt);
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
    var buf: [16]u8 = undefined;
    const file_name = try std.fmt.bufPrint(buf[0..], comptime "{s}.json", .{code_str});
    if (path) |p| {
        return try std.fs.path.join(alloc, &.{ p, file_name });
    } else {
        return try std.fs.path.join(alloc, &.{ "bonds_info", file_name });
    }
}

test "bond getSavePath" {
    const TEST_BOND_PATH = @import("../testing.zig").TEST_BOND_PATH;
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

pub fn save(self: *const Bond, path: []const u8, allocator: ?std.mem.Allocator) !void {
    const alloc = allocator orelse ALLOC;

    // 检查路径是目录还是文件
    const path_stat = std.fs.cwd().statFile(path) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };

    var free_path_flag = true;

    // 确定最终的文件路径
    const final_path = if (path_stat) |stat| blk: {
        if (stat.kind == .directory) {
            // 如果是目录，在目录中添加债券代码的JSON文件名
            var buf: [32]u8 = undefined;
            const file_name = try std.fmt.bufPrint(buf[0..], "{s}.json", .{self.bond_code});
            break :blk try std.fs.path.join(alloc, &.{ path, file_name });
        } else {
            // 如果是文件，直接使用该路径
            free_path_flag = false;
            break :blk path;
        }
    } else blk: {
        // 文件不存在，检查路径是否看起来像目录（以'/'结尾）或文件
        if (std.mem.endsWith(u8, path, "/") or std.mem.endsWith(u8, path, "\\")) {
            // 看起来像目录路径
            var buf: [32]u8 = undefined;
            const file_name = try std.fmt.bufPrint(buf[0..], "{s}.json", .{self.bond_code});
            break :blk try std.fs.path.join(alloc, &.{ path, file_name });
        } else {
            // 看起来像文件路径
            free_path_flag = false;
            break :blk path;
        }
    };
    defer if (free_path_flag) alloc.free(final_path);

    // 创建父目录（如果不存在）
    if (std.fs.path.dirname(final_path)) |parent_dir| {
        std.fs.cwd().makePath(parent_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {}, // 目录已存在，忽略错误
            else => return err,
        };
    }

    // 创建文件并写入债券数据
    const file = try std.fs.cwd().createFile(final_path, .{});
    defer file.close();

    // 将债券序列化为JSON
    const json_string = try std.json.stringifyAlloc(alloc, self, .{ .whitespace = .indent_2 });
    defer alloc.free(json_string);

    try file.writeAll(json_string);
}

test "bond save" {
    var bond = @import("../testing.zig").createBond();
    defer bond.deinit(null);
    try bond.save("test/save", null);
}

comptime {
    std.testing.refAllDecls(@This());
}
