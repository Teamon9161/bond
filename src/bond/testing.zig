const Bond = @import("Bond.zig");

pub const TEST_BOND_PATH = "test/data";
const BOND_JSON_STR =
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

pub fn createBond() Bond {
    return Bond.fromJson(BOND_JSON_STR, null) catch unreachable;
}
