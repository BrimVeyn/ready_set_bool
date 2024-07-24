const std = @import("std");

const Symbol = enum(u8) {
    None = 0,
    @"0" = '0',
    @"1" = '1',
    @"!" = '!',
    @"&" = '&',
    @"|" = '|',
    @"^" = '^',
    @">" = '>',
    @"=" = '=',

    pub fn isSymbol(c: u8) Symbol {
        return switch (c) {
            '0' => .@"0",
            else => .None,
        };
    }
};

fn eval_formula(str: []const u8) bool {
    if (Symbol.isSymbol(str[0]) != Symbol.None) {
        std.debug.print("yes\n", .{});
    }
    return true;
}

test "10& ⊤ ∧ ⊥" {
    const str = "10&";
    _ = eval_formula(str);
}
