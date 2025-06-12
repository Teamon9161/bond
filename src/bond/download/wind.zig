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

// VT constants matching Python WindPy
const VT_EMPTY = 0;
const VT_NULL = 1;
const VT_I8 = 2;
const VT_I4 = 3;
const VT_I2 = 4;
const VT_I1 = 5;
const VT_R4 = 6;
const VT_R8 = 7;
const VT_DATE = 8;
const VT_VARIANT = 9;
const VT_CSTR = 10;
const VT_BSTR = 11;
const VT_ARRAY = 0x100;
const VT_BYREF = 0x200;

// SafeArray union matching Python c_safearray_union
const SafeArrayUnion = extern union {
    pbVal: [*]u8,
    piVal: [*]i16,
    plVal: [*]i32,
    pllVal: [*]i64,
    pyref: ?*anyopaque,
    pfltVal: [*]f32,
    pdblVal: [*]f64,
    pdate: [*]f64,
    pcstrVal: [*][*:0]const u8,
    pbstrVal: [*][*:0]const u16,
    pvarVal: [*]WindVariant,
};

// SafeArray structure matching Python c_safearray
const SafeArray = extern struct {
    cDims: u16,
    fFeatures: u16,
    cbElements: u32,
    cLocks: u32,
    pvData: SafeArrayUnion,
    rgsabound: [*]u32,
};

// WindPy API structure matching Python c_var_union
const WindVariantUnion = extern union {
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
    pbVal: [*]u8,
    piVal: [*]i16,
    plVal: [*]i32,
    pllVal: [*]i64,
    pfltVal: [*]f32,
    pdlVal: [*]f64,
    pdate: [*]f64,
    pcstrVal: [*][*:0]const u8,
    pbstrVal: [*][*:0]const u16,
    parray: [*]SafeArray,
    pvarVal: [*]WindVariant,
};

// WindVariant structure matching Python c_variant
const WindVariant = extern struct {
    vt: u16,
    val: WindVariantUnion,
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
const WIND_LIB_PATH = if (builtin.os.tag == .linux)
    "/opt/apps/com.wind.wft/files/com.wind.api/lib/libWind.QuantData.so"
else
    "/Applications/Wind API.app/Contents/Frameworks/libWind.QuantData.dylib";

const WIND_QUANT_LIB_PATH = if (builtin.os.tag == .linux)
    "/opt/apps/com.wind.wft/files/com.wind.api/lib/libWind.Cosmos.QuantData.so"
else
    "/Applications/Wind API.app/Contents/Frameworks/libWind.Cosmos.QuantData.dylib";

// Wrapper for Wind library
pub const Wind = struct {
    // Library handles
    wind_lib: ?*anyopaque = null,
    wind_quant_lib: ?*anyopaque = null,

    // Function pointers
    setLongValue: ?*const fn (i32, i32) callconv(.C) void = null,
    start: ?*const fn ([*:0]const u8, i32, i32) callconv(.C) i32 = null,
    quantstart: ?*const fn ([*:0]const u8, i32, i32) callconv(.C) i32 = null,
    stop: ?*const fn () callconv(.C) i32 = null,
    isConnected: ?*const fn () callconv(.C) i32 = null,
    wss: ?*const fn ([*:0]const u8, [*:0]const u8, [*:0]const u8) callconv(.C) *WindApiOut = null,
    free_data: ?*const fn (*WindApiOut) callconv(.C) void = null,

    // Initialize the Wind library
    pub fn init() !Wind {
        var wind = Wind{};

        wind.wind_lib = c.dlopen(WIND_LIB_PATH, c.RTLD_NOW);
        wind.wind_quant_lib = c.dlopen(WIND_QUANT_LIB_PATH, c.RTLD_NOW);
        wind.setLongValue = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "setLongValue")));
        wind.start = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "start")));
        wind.stop = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "stop")));
        wind.quantstart = @ptrCast(@alignCast(c.dlsym(wind.wind_quant_lib.?, "start")));
        wind.isConnected = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "isConnectionOK")));
        wind.wss = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "wss")));
        wind.free_data = @ptrCast(@alignCast(c.dlsym(wind.wind_lib.?, "free_data")));
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
        std.debug.print("Starting wind login process...\n", .{});
        // First call setLongValue like in Python does before w.start()
        if (self.setLongValue) |setLongValue_fn| {
            setLongValue_fn(6433, 94645);
        } else {
            std.debug.print("Warning: setLongValue function not available, but continuing anyway\n", .{});
        }

        if (self.start) |start_fn| {
            const options = "";
            const timeout_ms = 60 * 1000;
            const result = start_fn(options, timeout_ms, 94645);
            if (result != 0) {
                std.debug.print("Start failed with error code {d}\n", .{result});
                return error.LoginFailed;
            }

            if (self.quantstart != null) {
                const quant_result = self.quantstart.?(options, timeout_ms, 94645);
                if (quant_result != 0) {
                    std.debug.print("Quantstart failed with error code {d}\n", .{quant_result});
                }
            }
        } else {
            return error.StartFunctionNotLoaded;
        }

        std.debug.print("Login process completed successfully\n", .{});
    }

    // Disconnect from Wind API
    pub fn logout(self: *Wind) !void {
        std.debug.print("Starting logout process...\n", .{});
        if (!self.isConnectedToWind()) {
            std.debug.print("Not connected to Wind, skipping logout\n", .{});
            return;
        }

        if (self.stop) |stop_fn| {
            _ = stop_fn();

            // In Python, after w.stop, it calls w.c_quantstop
            if (self.wind_quant_lib != null) {
                const StopFnType = *const fn () callconv(.C) i32;
                const quantstop_fn: ?StopFnType = @ptrCast(@alignCast(c.dlsym(self.wind_quant_lib.?, "stop")));
                if (quantstop_fn != null) {
                    _ = quantstop_fn.?();
                }
            }

            std.debug.print("Logout completed\n", .{});
        } else {
            return error.FunctionNotLoaded;
        }
    }

    // Check if connected to Wind API
    pub fn isConnectedToWind(self: *Wind) bool {
        if (self.isConnected) |is_connected_fn| {
            const result = is_connected_fn() != 0;
            return result;
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
    fn getCouponType(typ: []const u8) !enums.CouponType {
        if (std.mem.eql(u8, typ, "附息")) {
            return .coupon_bear;
        } else if (std.mem.eql(u8, typ, "到期一次还本付息")) {
            return .one_time;
        } else if (std.mem.eql(u8, typ, "贴现")) {
            return .zero_coupon;
        } else {
            std.debug.print("Unknown coupon type: {s}\n", .{typ});
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

    // Helper function to get total count from SafeArray (matching Python __getTotalCount)
    fn getTotalCount(variant: *const WindVariant) usize {
        if ((variant.vt & VT_ARRAY) == 0) {
            return 0;
        }

        // Check if parray is valid
        const parray = variant.val.parray;
        if (@intFromPtr(parray) == 0) {
            return 0;
        }

        // Access the first SafeArray element safely
        const safearray = &parray[0];
        if (safearray.cDims == 0) {
            return 0;
        }

        var totalCount: usize = 1;
        for (0..safearray.cDims) |i| {
            totalCount = totalCount * safearray.rgsabound[i];
        }
        return totalCount;
    }

    // Helper to extract string from WindVariant at specific index
    // For Wind API, data is organized as data[field_index * symbol_count + symbol_index]
    fn extractString(variant: *const WindVariant, field_index: usize, symbol_index: usize, symbol_count: usize) ![]const u8 {
        if ((variant.vt & VT_ARRAY) == 0 or @intFromPtr(variant.val.parray) == 0) {
            return error.InvalidData;
        }

        const safearray = &variant.val.parray[0];
        const ltype = variant.vt & (~@as(u16, VT_ARRAY));
        const index = field_index * symbol_count + symbol_index;

        if (ltype == VT_VARIANT) {
            const variants = safearray.pvData.pvarVal;
            const target_variant = &variants[index];

            switch (target_variant.vt) {
                VT_CSTR => {
                    return std.mem.span(target_variant.val.cstrVal);
                },
                VT_NULL, VT_EMPTY => {
                    return try ALLOC.dupe(u8, "");
                },
                else => {
                    std.debug.print("Unsupported string variant type in VT_VARIANT: {d} at field_index={d}, symbol_index={d}\n", .{ target_variant.vt, field_index, symbol_index });
                    return error.UnsupportedStringVariantType;
                },
            }
        } else {
            switch (ltype) {
                VT_CSTR => {
                    const data = safearray.pvData.pcstrVal;
                    return std.mem.span(data[index]);
                },
                VT_BSTR => {
                    const data = safearray.pvData.pbstrVal;
                    const wide_str = data[index];
                    var result = std.ArrayList(u8).init(ALLOC);
                    var i: usize = 0;
                    while (wide_str[i] != 0) : (i += 1) {
                        if (wide_str[i] < 128) { // ASCII range
                            try result.append(@intCast(wide_str[i]));
                        } else {
                            try result.append('?'); // Replace non-ASCII with '?'
                        }
                    }
                    return result.toOwnedSlice();
                },
                else => {
                    std.debug.print("Unsupported string array type: {d} at field_index={d}, symbol_index={d}\n", .{ ltype, field_index, symbol_index });
                    return error.UnsupportedStringVariantType;
                },
            }
        }
    }

    // Helper to extract int from WindVariant at specific index
    fn extractInt(variant: *const WindVariant, field_index: usize, symbol_index: usize, symbol_count: usize) !i64 {
        if ((variant.vt & VT_ARRAY) == 0 or @intFromPtr(variant.val.parray) == 0) {
            return error.InvalidData;
        }

        const safearray = &variant.val.parray[0];
        const ltype = variant.vt & (~@as(u16, VT_ARRAY));
        const index = field_index * symbol_count + symbol_index;

        if (ltype == VT_VARIANT) {
            const variants = safearray.pvData.pvarVal;
            const target_variant = &variants[index];

            switch (target_variant.vt) {
                VT_I8 => return target_variant.val.llVal,
                VT_I4 => return @intCast(target_variant.val.lVal),
                VT_I2 => return @intCast(target_variant.val.iVal),
                VT_I1 => return @intCast(target_variant.val.bVal),
                VT_R8 => return @intFromFloat(target_variant.val.dblVal), // Sometimes integers come as doubles
                VT_R4 => return @intFromFloat(target_variant.val.fltVal),
                VT_NULL, VT_EMPTY => return 0,
                else => {
                    std.debug.print("Unsupported int variant type in VT_VARIANT: {d} at field_index={d}, symbol_index={d}\n", .{ target_variant.vt, field_index, symbol_index });
                    return error.UnsupportedIntVariantType;
                },
            }
        } else {
            switch (ltype) {
                VT_I8 => {
                    const data = safearray.pvData.pllVal;
                    return data[index];
                },
                VT_I4 => {
                    const data = safearray.pvData.plVal;
                    return @intCast(data[index]);
                },
                VT_I2 => {
                    const data = safearray.pvData.piVal;
                    return @intCast(data[index]);
                },
                VT_R8 => {
                    const data = safearray.pvData.pdblVal;
                    return @intFromFloat(data[index]);
                },
                VT_R4 => {
                    const data = safearray.pvData.pfltVal;
                    return @intFromFloat(data[index]);
                },
                else => {
                    std.debug.print("Unsupported int array type: {d} at field_index={d}, symbol_index={d}\n", .{ ltype, field_index, symbol_index });
                    return error.UnsupportedIntVariantType;
                },
            }
        }
    }

    // Helper to extract double from WindVariant at specific index
    fn extractDouble(variant: *const WindVariant, field_index: usize, symbol_index: usize, symbol_count: usize) !f64 {
        if ((variant.vt & VT_ARRAY) == 0 or @intFromPtr(variant.val.parray) == 0) {
            return error.InvalidData;
        }

        const safearray = &variant.val.parray[0];
        const ltype = variant.vt & (~@as(u16, VT_ARRAY));
        const index = field_index * symbol_count + symbol_index;

        if (ltype == VT_VARIANT) {
            const variants = safearray.pvData.pvarVal;
            const target_variant = &variants[index];

            switch (target_variant.vt) {
                VT_R8 => {
                    return target_variant.val.dblVal;
                },
                VT_R4 => {
                    return @floatCast(target_variant.val.fltVal);
                },
                VT_I4 => {
                    return @floatFromInt(target_variant.val.lVal);
                },
                VT_I8 => {
                    return @floatFromInt(target_variant.val.llVal);
                },
                VT_I2 => {
                    return @floatFromInt(target_variant.val.iVal);
                },
                VT_NULL, VT_EMPTY => {
                    return 0.0;
                },
                else => {
                    std.debug.print("Unsupported double variant type in VT_VARIANT: {d} at field_index={d}, symbol_index={d}\n", .{ target_variant.vt, field_index, symbol_index });
                    return error.UnsupportedDoubleVariantType;
                },
            }
        } else {
            switch (ltype) {
                VT_R8 => {
                    const data = safearray.pvData.pdblVal;
                    return data[index];
                },
                VT_R4 => {
                    const data = safearray.pvData.pfltVal;
                    return @floatCast(data[index]);
                },
                VT_I4 => {
                    const data = safearray.pvData.plVal;
                    return @floatFromInt(data[index]);
                },
                VT_I8 => {
                    const data = safearray.pvData.pllVal;
                    return @floatFromInt(data[index]);
                },
                else => {
                    std.debug.print("Unsupported double array type: {d} at field_index={d}, symbol_index={d}\n", .{ ltype, field_index, symbol_index });
                    return error.UnsupportedDoubleVariantType;
                },
            }
        }
    }

    // Helper to extract date from WindVariant at specific index
    fn extractDate(variant: *const WindVariant, field_index: usize, symbol_index: usize, symbol_count: usize) !Date {
        if ((variant.vt & VT_ARRAY) == 0 or @intFromPtr(variant.val.parray) == 0) {
            return error.InvalidData;
        }

        const safearray = &variant.val.parray[0];
        const ltype = variant.vt & (~@as(u16, VT_ARRAY));
        const index = field_index * symbol_count + symbol_index;

        if (ltype == VT_VARIANT) {
            const variants = safearray.pvData.pvarVal;
            const target_variant = &variants[index];

            switch (target_variant.vt) {
                VT_DATE => {
                    const date_value = target_variant.val.date;
                    // Wind日期存储为自1899-12-30以来的天数
                    const epoch_date = try Date.create(1899, 12, 30);
                    return epoch_date.shiftDays(@intFromFloat(date_value));
                },
                VT_R8 => {
                    const date_value = target_variant.val.dblVal;
                    // Wind日期存储为自1899-12-30以来的天数
                    const epoch_date = try Date.create(1899, 12, 30);
                    return epoch_date.shiftDays(@intFromFloat(date_value));
                },
                VT_R4 => {
                    const date_value = target_variant.val.fltVal;
                    // Wind日期存储为自1899-12-30以来的天数
                    const epoch_date = try Date.create(1899, 12, 30);
                    return epoch_date.shiftDays(@intFromFloat(date_value));
                },
                VT_NULL, VT_EMPTY => {
                    // Return epoch date for null/empty dates
                    return try Date.create(1970, 1, 1);
                },
                else => {
                    std.debug.print("Unsupported date variant type in VT_VARIANT: {d} at field_index={d}, symbol_index={d}\n", .{ target_variant.vt, field_index, symbol_index });
                    return error.UnsupportedDateVariantType;
                },
            }
        } else {
            switch (ltype) {
                VT_DATE => {
                    const data = safearray.pvData.pdate;
                    const date_value = data[index];
                    // Wind日期存储为自1899-12-30以来的天数
                    const epoch_date = try Date.create(1899, 12, 30);
                    return epoch_date.shiftDays(@intFromFloat(date_value));
                },
                VT_R8 => {
                    const data = safearray.pvData.pdblVal;
                    const date_value = data[index];
                    // Wind日期存储为自1899-12-30以来的天数
                    const epoch_date = try Date.create(1899, 12, 30);
                    return epoch_date.shiftDays(@intFromFloat(date_value));
                },
                VT_R4 => {
                    const data = safearray.pvData.pfltVal;
                    const date_value = data[index];
                    // Wind日期存储为自1899-12-30以来的天数
                    const epoch_date = try Date.create(1899, 12, 30);
                    return epoch_date.shiftDays(@intFromFloat(date_value));
                },
                else => {
                    std.debug.print("Unsupported date array type: {d} at field_index={d}, symbol_index={d}\n", .{ ltype, field_index, symbol_index });
                    return error.UnsupportedDateVariantType;
                },
            }
        }
    }

    // Fetch bond information from Wind
    pub fn fetchSymbols(self: *Wind, symbols: []const []const u8, save_folder: ?[]const u8) ![]Bond {
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

        const today = Date.now();
        var buf: [16]u8 = undefined;
        const today_str = try today.formatIsoBuf(buf[0..]);

        // Create options string with today's date
        var options_buf = std.ArrayList(u8).init(ALLOC);
        defer options_buf.deinit();
        try options_buf.appendSlice("tradeDate=");
        try options_buf.appendSlice(today_str);
        try options_buf.append(0); // Null-terminate the string

        if (self.wss) |wss_fn| {

            // CRITICAL SECTION: Here's where we call into the Wind API
            const result = wss_fn(@ptrCast(symbols_buf.items.ptr), @ptrCast(fields.ptr), @ptrCast(options_buf.items.ptr));

            defer {
                if (self.free_data) |free_fn| {
                    free_fn(result);
                }
            }

            if (result.*.ErrorCode != 0) {
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

                // Extract each field from the data array using correct indexing
                // Data is organized as data[field_index * symbol_count + symbol_index]
                var bond = Bond{
                    .bond_code = try ALLOC.dupe(u8, symbol),
                    .abbr = try ALLOC.dupe(u8, try Wind.extractString(&result.*.Data, 0, i, symbols.len)), // sec_name
                    .cp_rate_1st = std.math.round(try Wind.extractDouble(&result.*.Data, 4, i, symbols.len) * 100) / 10000, // couponrate, convert percentage to decimal
                    .inst_freq = @intCast(try Wind.extractInt(&result.*.Data, 8, i, symbols.len)), // interestfrequency
                    .carry_date = try Wind.extractDate(&result.*.Data, 1, i, symbols.len), // carrydate
                    .maturity_date = try Wind.extractDate(&result.*.Data, 2, i, symbols.len), // maturitydate
                    .mkt = try enums.Market.parse(symbol[symbol.len - 2 ..]),
                    .par_value = try Wind.extractDouble(&result.*.Data, 9, i, symbols.len), // latestpar
                    .cp_type = try Wind.getCouponType(try Wind.extractString(&result.*.Data, 7, i, symbols.len)), // coupon (cp_type)
                    .interest_type = try Wind.getInterestType(try Wind.extractString(&result.*.Data, 3, i, symbols.len)), // interesttype
                    .base_rate = null,
                    .rate_spread = null,
                    .day_count = try Wind.getBondDayCount(try Wind.extractString(&result.*.Data, 6, i, symbols.len)), // actualbenchmark
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

pub var WIND: ?Wind = null;

// Helper function to ensure WIND is connected
fn ensureWindConnected() !void {
    if (WIND == null) {
        WIND = try Wind.init();
    }
    // try WIND.?.login();
    if (!WIND.?.isConnectedToWind()) {
        try WIND.?.login();
    }
}

// Utility function to download bond data
pub fn downloadBonds(symbols: []const []const u8, save_folder: ?[]const u8) ![]Bond {
    try ensureWindConnected();
    return try WIND.?.fetchSymbols(symbols, save_folder);
}

pub fn closeWind() void {
    if (WIND) |*wind| {
        wind.logout() catch {};
        wind.deinit();
        WIND = null;
    }
}

// test "global wind" {
//     try ensureWindConnected();
//     defer closeWind();
// }

comptime {
    std.testing.refAllDecls(@This());
}
