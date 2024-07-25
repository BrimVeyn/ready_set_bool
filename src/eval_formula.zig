const std = @import("std");

pub const Operator = enum(u8) {
    None = 0,
    @"!" = '!',
    @"&" = '&',
    @"|" = '|',
    @"^" = '^',
    @">" = '>',
    @"=" = '=',

    pub fn isOp(c: u8) Operator {
        return switch (c) {
            '!' => .@"!",
            '&' => .@"&",
            '|' => .@"|",
            '^' => .@"^",
            '>' => .@">",
            '=' => .@"=",
            else => .None,
        };
    }
};

pub const Value = enum(u8) {
    None = 0,
    @"0" = '0',
    @"1" = '1',

    pub fn isValue(c: u8) Value {
        return switch (c) {
            '0' => .@"0",
            '1' => .@"1",
            else => .None,
        };
    }
};

fn eval_formula(str: []const u8) bool {
    _ = str; // autofix
    return true;
}

test "10& ⊤ ∧ ⊥" {
    const str = "10&";
    _ = eval_formula(str);
}
