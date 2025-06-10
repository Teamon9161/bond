const std = @import("std");

fn F64(x: anytype) f64 {
    return @as(f64, @floatFromInt(x));
}

/// 通用二分法求根函数
/// F: 函数类型 fn(f64) f64
/// f: 目标函数
/// lower: 下界
/// upper: 上界
/// degree: 精度（默认15位小数）
pub fn bisectionFindRoot(f: anytype, lower: f64, upper: f64, degree: ?i32, context: anytype) f64 {
    const epsilon = std.math.pow(f64, 10.0, -F64(degree orelse 15));
    std.debug.assert(upper > lower);

    var lower_bound = lower;
    var upper_bound = upper;
    const f_lower = f(lower_bound, context);
    const f_upper = f(upper_bound, context);
    const sign = f_upper >= f_lower;

    if (sign) {
        while (upper_bound - lower_bound > epsilon) {
            const mid = (lower_bound + upper_bound) / 2.0;
            const f_mid = f(mid, context);
            if (f_mid == 0.0) {
                return mid;
            } else if (f_mid < 0.0) {
                lower_bound = mid;
            } else {
                upper_bound = mid;
            }
        }
    } else {
        while (upper_bound - lower_bound > epsilon) {
            const mid = (lower_bound + upper_bound) / 2.0;
            const f_mid = f(mid, context);
            if (f_mid == 0.0) {
                return mid;
            } else if (f_mid < 0.0) {
                upper_bound = mid;
            } else {
                lower_bound = mid;
            }
        }
    }

    return (lower_bound + upper_bound) * 0.5;
}

// 测试函数
test "bisection find root" {
    // 测试求解 x^2 - 4 = 0 (答案应该是 2)
    const TestFunction = struct {
        pub fn call(x: f64, _: anytype) f64 {
            return x * x - 4.0;
        }
    };

    const result = bisectionFindRoot(TestFunction.call, 0.0, 5.0, 10, null);
    try std.testing.expectApproxEqAbs(result, 2.0, 1e-10);
}
