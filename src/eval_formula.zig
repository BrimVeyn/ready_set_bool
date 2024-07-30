const std = @import("std");
const AST = @import("AST.zig");
const Stack = @import("Stack.zig").Stack;
const color = @import("Colors.zig").ansi;

pub const Operator = enum(u8) {
    const Self = @This();

    @"!" = '!',
    @"&" = '&',
    @"|" = '|',
    @"^" = '^',
    @">" = '>',
    @"=" = '=',

    pub fn getOp(c: u8) ?Operator {
        return switch (c) {
            '!' => .@"!",
            '&' => .@"&",
            '|' => .@"|",
            '^' => .@"^",
            '>' => .@">",
            '=' => .@"=",
            else => null,
        };
    }

    pub fn doOp(self: Self, a: u1, b: u1) u1 {
        std.debug.print("{d} {c} {d}\n", .{ b, @intFromEnum(self), a });
        return switch (self) {
            .@"&" => b & a,
            .@"|" => b | a,
            .@"^" => b ^ a,
            .@">" => (~b) | a,
            .@"=" => if (b == a) 1 else 0,
            else => 0,
        };
    }
};

pub const Value = enum(u8) {
    const Self = @This();

    @"0" = '0',
    @"1" = '1',

    pub fn getValue(c: u8) ?Value {
        return switch (c) {
            '0' => .@"0",
            '1' => .@"1",
            else => null,
        };
    }

    pub fn getBool(self: Self) u1 {
        return switch (self) {
            .@"0" => 0,
            .@"1" => 1,
        };
    }
};

const ParsingError = error{
    notEnoughBool,
    invalidCharacter,
};

fn evalFormula(allocator: std.mem.Allocator, str: []const u8) !bool {
    var stack = try Stack(u1).init(allocator);
    defer stack.deinit();

    var i: usize = 0;

    while (i < str.len) : (i += 1) {
        if (Value.getValue(str[i])) |value| {
            try stack.push(value.getBool());
        } else if (Operator.getOp(str[i])) |operator| {
            if (operator == Operator.@"!") {
                std.debug.print("~{d}\n", .{stack.data.items[stack.data.items.len - 1]});
                try stack.push(~stack.pop());
                continue;
            }
            if (stack.size < 2) return ParsingError.notEnoughBool;
            const a = stack.pop();
            const b = stack.pop();
            try stack.push(operator.doOp(a, b));
        } else return ParsingError.invalidCharacter;
    }
    stack.print();
    return if (stack.pop() == 0) false else true;
}

pub fn computeFormula(str: []const u8) !void {
    const allocator = std.testing.allocator;
    std.debug.print("{s}Formula = {s}{s}{s}\n", .{ color.green, color.yellow, str, color.reset });
    const res = try evalFormula(allocator, str);
    const res_color = if (res == false) color.red else color.green;
    std.debug.print("Result = {s}{}{s}\n", .{ res_color, res, color.reset });
    std.debug.print("----------------------------\n", .{});
}

test "expr1" {
    const str = "10|";
    try computeFormula(str);
}

test "expr2" {
    const str = "11&1^";
    try computeFormula(str);
}

test "expr3" {
    const str = "1011||=";
    try computeFormula(str);
}

test "expr4" {
    const str = "01|1&";
    try computeFormula(str);
}

test "expr5" {
    const str = "0!!";
    try computeFormula(str);
}

test "expr6" {
    const str = "0!!0!1&&";
    try computeFormula(str);
}

test "expr7" {
    const str = "0!0!1|&!";
    try computeFormula(str);
}

test "expr8" {
    const str = "01&1!0||";
    try computeFormula(str);
}

test "expr9" {
    const str = "10!|0110&=|&";
    try computeFormula(str);
}

test "expr10" {
    const str = "01&1!0||10!|0110&=|&>";
    try computeFormula(str);
}

test "expr11" {
    const str = "01|1!10!&|&";
    try computeFormula(str);
}

test "expr12" {
    const str = "01&11!0|=|"; //(0 & 1) | (1 = (!1 | 0))
    try computeFormula(str);
}

test "expr13" {
    const str = "01|1!10!&|&01&11!0|=|>";
    try computeFormula(str);
}

test "more than one item in stack" {
    const str = "001|";
    try computeFormula(str);
}

test "error notEnoughBool" {
    const str = "11||";
    try std.testing.expectError(ParsingError.notEnoughBool, computeFormula(str));
    std.log.err("{}", .{ParsingError.notEnoughBool});
}

test "error invalidCharacter" {
    const str = "1 1|";
    try std.testing.expectError(ParsingError.invalidCharacter, computeFormula(str));
    std.log.err("{}", .{ParsingError.invalidCharacter});
}
