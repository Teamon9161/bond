const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cDefine("_GNU_SOURCE", "1");
    @cInclude("dlfcn.h");
});

const Bond = @import("../Bond.zig");
const Date = @import("../../Date.zig");
const ALLOC = @import("../../root.zig").ALLOC;
const enums = @import("../enums.zig");

// WindPy API structure
const WindVariant = extern struct {
    vt: u16,
    // This is a simplification of the union in C code
    val: extern union {
        llVal: i64,
        lVal: i32,
        iVal: i16,
        bVal: u8,
        fltVal: f32,
        dblVal: f64,
        date: f64,
        cstrVal: [*:0]const u8,
        bstrVal: [*:0]const u16,
        pyref: ?*anyopaque,
        // Pointer types omitted for simplicity
        pbVal: [*]u8,
        piVal: [*]i16,
        plVal: [*]i32,
        pllVal: [*]i64,
        pfltVal: [*]f32,
        pdblVal: [*]f64,
        pdate: [*]f64,
        pcstrVal: [*][*:0]const u8,
        pbstrVal: [*][*:0]const u16,
    },
};

const WindApiOut = extern struct {
    ErrorCode: i32,
    StateCode: i32,
    RequestID: i64,
    Codes: WindVariant,
    Fields: WindVariant,
    Times: WindVariant,
    Data: WindVariant,
};

// Library paths from WindPy
const WIND_QUANT_LIB_PATH = if (builtin.os.tag == .linux)
    "/opt/apps/com.wind.wft/files/com.wind.api/lib/libWind.QuantData.so"
else
    "/Applications/Wind API.app/Contents/Frameworks/libWind.QuantData.dylib";

const WIND_LIB_PATH = if (builtin.os.tag == .linux)
    "/opt/apps/com.wind.wft/files/com.wind.api/lib/libWind.QuantData.so"
else
    "/Applications/Wind API.app/Contents/Frameworks/libWind.QuantData.dylib";

// Wrapper for Wind library
pub const Wind = struct {
    // Library handles
    wind_lib: ?*anyopaque = null,
    wind_quant_lib: ?*anyopaque = null,

    // Function pointers
    setLongValue: ?*const fn (i32, i32) callconv(.C) void = null,
    start: ?*const fn ([*:0]const u8, i32, i32) callconv(.C) i32 = null,
    stop: ?*const fn () callconv(.C) i32 = null,
    isConnected: ?*const fn () callconv(.C) i32 = null,
    wss: ?*const fn ([*:0]const u8, [*:0]const u8, [*:0]const u8) callconv(.C) *WindApiOut = null,
    free_data: ?*const fn (*WindApiOut) callconv(.C) void = null,

    // Initialize the Wind library
    pub fn init() !Wind {
        var wind = Wind{};

        // Load the Wind libraries
        wind.wind_lib = c.dlopen(WIND_LIB_PATH, c.RTLD_LAZY);
        if (wind.wind_lib == null) {
            std.debug.print("Failed to load Wind library: {s}\n", .{c.dlerror()});
            return error.LibraryLoadFailed;
        }

        wind.wind_quant_lib = c.dlopen(WIND_QUANT_LIB_PATH, c.RTLD_LAZY);
        if (wind.wind_quant_lib == null) {
            std.debug.print("Failed to load Wind Quant library: {s}\n", .{c.dlerror()});
            _ = c.dlclose(wind.wind_lib.?);
            return error.LibraryLoadFailed;
        }

        wind.setLongValue = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "setLongValue")));
        if (wind.setLongValue == null) {
            std.debug.print("Failed to load 'setLongValue' function: {s}\n", .{c.dlerror()});
        }

        // Load function pointers
        wind.start = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "start")));
        if (wind.start == null) {
            std.debug.print("Failed to load 'start' function: {s}\n", .{c.dlerror()});
            wind.deinit();
            return error.FunctionLoadFailed;
        }

        wind.stop = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "stop")));
        if (wind.stop == null) {
            std.debug.print("Failed to load 'stop' function: {s}\n", .{c.dlerror()});
            wind.deinit();
            return error.FunctionLoadFailed;
        }

        wind.isConnected = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "isConnectionOK")));
        if (wind.isConnected == null) {
            std.debug.print("Failed to load 'isConnectionOK' function: {s}\n", .{c.dlerror()});
            wind.deinit();
            return error.FunctionLoadFailed;
        }

        wind.wss = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "wss")));
        if (wind.wss == null) {
            std.debug.print("Failed to load 'wss' function: {s}\n", .{c.dlerror()});
            wind.deinit();
            return error.FunctionLoadFailed;
        }

        wind.free_data = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "free_data")));
        if (wind.free_data == null) {
            std.debug.print("Failed to load 'free_data' function: {s}\n", .{c.dlerror()});
            wind.deinit();
            return error.FunctionLoadFailed;
        }

        return wind;
    }

    // Clean up resources
    pub fn deinit(self: *Wind) void {
        if (self.wind_quant_lib != null) {
            _ = c.dlclose(self.wind_quant_lib.?);
            self.wind_quant_lib = null;
        }

        if (self.wind_lib != null) {
            _ = c.dlclose(self.wind_lib.?);
            self.wind_lib = null;
        }

        self.start = null;
        self.stop = null;
        self.isConnected = null;
        self.wss = null;
        self.free_data = null;
    }

    // Connect to Wind API
    pub fn login(self: *Wind) !void {
        if (self.start) |start_fn| {
            if (self.setLongValue) |setLongValue_fn| {
                setLongValue_fn(6433, 94645);
            } else {
                return error.setLongValueNotLoaded;
            }
            const options = "";
            const result = start_fn(options, 120, 94645);
            if (result != 0) {
                return error.LoginFailed;
            }
        } else {
            return error.FunctionNotLoaded;
        }
    }

    // Disconnect from Wind API
    pub fn logout(self: *Wind) !void {
        if (self.stop) |stop_fn| {
            _ = stop_fn();
        } else {
            return error.FunctionNotLoaded;
        }
    }

    // Check if connected to Wind API
    pub fn isConnectedToWind(self: *Wind) bool {
        if (self.isConnected) |is_connected_fn| {
            return is_connected_fn() != 0;
        } else {
            return false;
        }
    }

    // Helper function to get interest type from Wind string
    fn getInterestType(typ: []const u8) !enums.InterestType {
        if (std.mem.eql(u8, typ, "固定利率")) {
            return .fixed;
        } else if (std.mem.eql(u8, typ, "浮动利率")) {
            return .floating;
        } else if (std.mem.eql(u8, typ, "累进利率")) {
            return .progressive;
        } else if (std.mem.eql(u8, typ, "零息")) {
            return .zero;
        } else {
            std.debug.print("Unknown interest type: {s}\n", .{typ});
            return error.UnknownInterestType;
        }
    }

    // Helper function to get payment type from Wind string
    fn getPaymentType(typ: []const u8) !enums.CouponType {
        if (std.mem.eql(u8, typ, "附息")) {
            return .coupon_bear;
        } else if (std.mem.eql(u8, typ, "到期一次还本付息")) {
            return .one_time;
        } else if (std.mem.eql(u8, typ, "贴现")) {
            return .zero_coupon;
        } else {
            std.debug.print("Unknown payment type: {s}\n", .{typ});
            return error.UnknownPaymentType;
        }
    }

    // Helper function to get bond day count from Wind string
    fn getBondDayCount(day_count: []const u8) !enums.BondDayCount {
        return enums.BondDayCount.parse(day_count) catch {
            std.debug.print("Unknown day count: {s}\n", .{day_count});
            return error.UnknownDayCount;
        };
    }

    // Helper function to parse date string from Wind
    fn parseDate(date_str: []const u8) !Date {
        // Wind date format: YYYY-MM-DD
        return Date.parseIso(date_str);
    }

    // Helper to extract string from WindVariant
    fn extractString(variant: *const WindVariant, index: usize) ![]const u8 {
        const vt = variant.vt;
        if (vt == 10) { // VT_CSTR
            // 访问字符串数组中的第index个元素
            const str_array = @as([*][*:0]const u8, @ptrCast(@alignCast(variant.val.pcstrVal)))[index];
            return std.mem.span(str_array);
        } else if (vt == 11) { // VT_BSTR
            // 处理宽字符串如果需要
            return error.UnsupportedVariantType;
        }
        return error.UnsupportedVariantType;
    }

    fn extractInt(variant: *const WindVariant, index: usize) !i64 {
        const vt = variant.vt;
        if (vt == 4) { // VT_I4
            const int_array = @as([*]i32, @ptrCast(@alignCast(variant.val.piVal)))[index];
            return @intCast(int_array);
        } else if (vt == 6) { // VT_I8
            const int_array = @as([*]i64, @ptrCast(@alignCast(variant.val.pllVal)))[index];
            return int_array;
        }
        return error.UnsupportedVariantType;
    }

    // Helper to extract double from WindVariant
    fn extractDouble(variant: *const WindVariant, index: usize) !f64 {
        const vt = variant.vt;
        if (vt == 7) { // VT_R8
            // 访问double数组中的第index个元素
            const double_array = @as([*]f64, @ptrCast(@alignCast(variant.val.pdblVal)))[index];
            return double_array;
        }
        return error.UnsupportedVariantType;
    }

    // Helper to extract date from WindVariant
    fn extractDate(variant: *const WindVariant, index: usize) !Date {
        const vt = variant.vt;
        if (vt == 8) { // VT_DATE
            // 访问日期数组中的第index个元素
            const date_value = @as([*]f64, @ptrCast(@alignCast(variant.val.pdate)))[index];

            // Wind日期存储为自1899-12-30以来的天数
            const epoch_date = try Date.create(1899, 12, 30);
            return epoch_date.shiftDays(@intFromFloat(date_value));
        }
        return error.UnsupportedVariantType;
    }

    // Fetch bond information from Wind
    pub fn fetchSymbols(self: *Wind, symbols: []const []const u8, save_folder: ?[]const u8) ![]Bond {
        if (!self.isConnectedToWind()) {
            try self.login();
            defer self.logout() catch {};
        }

        var bonds = std.ArrayList(Bond).init(ALLOC);
        errdefer {
            for (bonds.items) |*bond| {
                bond.deinit(null);
            }
            bonds.deinit();
        }

        // Convert symbols array to comma-separated string
        var symbols_buf = std.ArrayList(u8).init(ALLOC);
        defer symbols_buf.deinit();

        for (symbols, 0..) |symbol, i| {
            try symbols_buf.appendSlice(symbol);
            if (i < symbols.len - 1) {
                try symbols_buf.append(',');
            }
        }
        try symbols_buf.append(0); // Null-terminate the string

        // Fields to fetch from Wind
        const fields = "sec_name,carrydate,maturitydate,interesttype,couponrate,paymenttype,actualbenchmark,coupon,interestfrequency,latestpar\u{0}";

        // Get today's date for options
        var today_buf: [16]u8 = undefined;
        const today = Date.now();
        const today_str = try today.formatIsoBuf(&today_buf);

        // Create options string with today's date
        var options_buf = std.ArrayList(u8).init(ALLOC);
        defer options_buf.deinit();
        try options_buf.appendSlice("tradeDate=");
        try options_buf.appendSlice(today_str);
        try options_buf.append(0); // Null-terminate the string

        if (self.wss) |wss_fn| {
            const result = wss_fn(@ptrCast(symbols_buf.items.ptr), @ptrCast(fields.ptr), @ptrCast(options_buf.items.ptr));
            defer if (self.free_data) |free_fn| free_fn(result);

            if (result.*.ErrorCode != 0) {
                std.debug.print("Wind API Error: {d}\n", .{result.*.ErrorCode});
                return error.WindApiError;
            }

            // Based on WindPy.py and download.py, we need to extract:
            // data[0][i] -> sec_name (abbr)
            // data[1][i] -> carrydate
            // data[2][i] -> maturitydate
            // data[3][i] -> interesttype
            // data[4][i] -> couponrate
            // data[5][i] -> paymenttype
            // data[6][i] -> actualbenchmark (day_count)
            // data[7][i] -> coupon (cp_type)
            // data[8][i] -> interestfrequency (inst_freq)
            // data[9][i] -> latestpar (par_value)

            for (0..symbols.len) |i| {
                const symbol = symbols[i];

                // Extract each field from the data array
                // This will depend on the actual structure of the WindApiOut data
                var bond = Bond{
                    .bond_code = try ALLOC.dupe(u8, symbol),
                    .abbr = try ALLOC.dupe(u8, try extractString(&result.*.Data, i * 10 + 0)),
                    .cp_rate_1st = try extractDouble(&result.*.Data, i * 10 + 4) / 100.0, // Convert percentage to decimal
                    .inst_freq = @intCast(try extractInt(&result.*.Data, i * 10 + 8)),
                    .carry_date = try extractDate(&result.*.Data, i * 10 + 1),
                    .maturity_date = try extractDate(&result.*.Data, i * 10 + 2),
                    .mkt = try enums.Market.parse(symbol[symbol.len - 2 ..]),
                    .par_value = try extractDouble(&result.*.Data, i * 10 + 9),
                    .cp_type = try getPaymentType(try extractString(&result.*.Data, i * 10 + 5)),
                    .interest_type = try getInterestType(try extractString(&result.*.Data, i * 10 + 3)),
                    .base_rate = null,
                    .rate_spread = null,
                    .day_count = try getBondDayCount(try extractString(&result.*.Data, i * 10 + 6)),
                };

                // Determine inst_freq based on cp_type
                if (bond.cp_type == .coupon_bear) {
                    // Already set from data
                } else if (bond.cp_type == .one_time) {
                    bond.inst_freq = 1;
                } else if (bond.cp_type == .zero_coupon) {
                    bond.inst_freq = 0;
                }

                try bonds.append(bond);

                // Save bond data if requested
                if (save_folder != null) {
                    try bond.save(save_folder.?, null);
                }
            }
        } else {
            return error.FunctionNotLoaded;
        }

        return bonds.toOwnedSlice();
    }
};

// Utility function to download bond data
pub fn downloadBonds(symbols: []const []const u8, save_folder: ?[]const u8) ![]Bond {
    std.debug.print("Begin download bonds\n", .{});
    var wind = try Wind.init();
    try wind.login();
    std.debug.print("Connected to Wind\n", .{});

    const out = try wind.fetchSymbols(symbols, save_folder);
    try wind.logout();
    wind.deinit();
    return out;
}

test "wind initialization" {
    var wind = try Wind.init();
    try wind.login();
    // defer wind.logout();
    defer wind.deinit();
}

// test "wind download" {
//     const symbols = [_][]const u8{"250205.IB"};
//     const bonds = try downloadBonds(&symbols, null);
//     defer {
//         for (bonds) |*bond| {
//             bond.save("test/download", null) catch {};
//             bond.deinit(null);
//         }
//     }
// }

comptime {
    std.testing.refAllDecls(@This());
}
