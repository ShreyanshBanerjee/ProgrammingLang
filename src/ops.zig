const Value = @import("core.zig").Value;
const std = @import("std");

//behold: wall of boilerplate (but what can you do...)
pub fn _and(a: i32, b: i32) Value { return Value{.int=(a & b)}; }
pub fn _or(a: i32, b: i32) Value { return Value{.int=(a | b)}; }
pub fn _xor(a: i32, b: i32) Value { return Value{.int=(a ^ b)}; }

pub fn add_i(a: i32, b: i32) Value { return Value{.int=a+b}; }
pub fn add_f(a: f32, b: f32) Value { return Value{.float=a+b}; }
pub fn sub_i(a: i32, b: i32) Value { return Value{.int=a-b}; }
pub fn sub_f(a: f32, b: f32) Value { return Value{.float=a-b}; }
pub fn mult_i(a: i32, b: i32) Value { return Value{.int=a*b}; }
pub fn mult_f(a: f32, b: f32) Value { return Value{.float=a*b}; }
pub fn div_i(a: i32, b: i32) Value { return Value{.int=@divTrunc(a,b)}; }
pub fn div_f(a: f32, b: f32) Value { return Value{.float=a/b}; }
pub fn mod_i(a: i32, b: i32) Value { return Value{.int=@rem(a,b)}; }
pub fn mod_f(a: f32, b: f32) Value {
    const result = std.math.rem(f32, a, b) catch { return Value{.nan={}}; };
    return Value{.float=result};
}
pub fn pow_i(a: i32, b: i32) Value {
    const result = std.math.powi(i32, a, b) catch return Value{.nan={}};
    return Value{.int=result};
}
pub fn pow_f(a: f32, b: f32) Value { return Value{.float=std.math.pow(f32, a, b)}; }

pub fn lt_i(a: i32, b: i32) Value { return Value{.int=if (a<b) 1 else 0}; }
pub fn lt_f(a: f32, b: f32) Value { return Value{.int=if (a<b) 1 else 0}; }
pub fn gt_i(a: i32, b: i32) Value { return Value{.int=if (a>b) 1 else 0}; }
pub fn gt_f(a: f32, b: f32) Value { return Value{.int=if (a>b) 1 else 0}; }
pub fn lteq_i(a: i32, b: i32) Value { return Value{.int=if (a<=b) 1 else 0}; }
pub fn lteq_f(a: f32, b: f32) Value { return Value{.int=if (a<=b) 1 else 0}; }
pub fn gteq_i(a: i32, b: i32) Value { return Value{.int=if (a>=b) 1 else 0}; }
pub fn gteq_f(a: f32, b: f32) Value { return Value{.int=if (a>=b) 1 else 0}; }

pub fn eqeq(a: Value, b: Value) Value { return Value{.int=if (std.meta.eql(a, b)) 1 else 0}; }
pub fn neq(a: Value, b: Value) Value { return Value{.int=if (std.meta.eql(a, b)) 0 else 1}; }


