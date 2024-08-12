const std = @import("std");
const AST = @import("AST.zig");
const Stack = @import("Stack.zig").Stack;
const color = @import("Colors.zig").ansi;
const ArrayList = std.ArrayList;

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
        // std.debug.print("{d} {c} {d}\n", .{ b, @intFromEnum(self), a });
        return switch (self) {
            .@"&" => b & a,
            .@"|" => b | a,
            .@"^" => b ^ a,
            .@">" => (~b) | a,
            .@"=" => if (b == a) 1 else 0,
            else => 0,
        };
    }

    pub fn doSetOp(self: Self, allocator: *std.mem.Allocator, a: ArrayList(i32), b: ArrayList(i32)) !ArrayList(i32) {
        return switch (self) {
            .@"&" => try doIntersection(allocator, a, b),
            .@"|" => try doUnion(allocator, a, b),
            .@"^" => try doDifference(allocator, a, b),
            .@">" => try doMaterialImplication(allocator, a, b),
            else => return ArrayList(i32).init(std.testing.allocator),
            // .@"=" => doLogicalEquivalence(a, b),
            // .@"!" => doNegate(a, b),
        };
    }

    fn doIntersection(allocator: *std.mem.Allocator, a: ArrayList(i32), b: ArrayList(i32)) !ArrayList(i32) {
        var result = ArrayList(i32).init(allocator.*);
        for (a.items) |itemA| {
            for (b.items) |itemB| {
                if (itemB == itemA) try result.append(itemA);
            }
        }
        return result;
    }

    fn doMaterialImplication(allocator: *std.mem.Allocator, a: ArrayList(i32), b: ArrayList(i32)) !ArrayList(i32) {
        _ = a; // autofix
        _ = b; // autofix
        const result = ArrayList(i32).init(allocator.*);
        return result;
    }

    fn doDifference(allocator: *std.mem.Allocator, a: ArrayList(i32), b: ArrayList(i32)) !ArrayList(i32) {
        var result = ArrayList(i32).init(allocator.*);
        for (a.items) |itemA| {
            var found: bool = false;
            for (b.items) |itemB| {
                if (itemB == itemA) found = true;
            }
            if (!found) try result.append(itemA);
        }
        return result;
    }

    fn doUnion(allocator: *std.mem.Allocator, a: ArrayList(i32), b: ArrayList(i32)) !ArrayList(i32) {
        var result = ArrayList(i32).init(allocator.*);
        for (a.items) |item| try result.append(item);
        for (b.items) |item| {
            var found: bool = false;
            for (result.items) |ritem| {
                if (ritem == item) found = true;
            }
            if (!found) try result.append(item);
        }
        return result;
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

pub const ParsingError = error{
    wrongFormat,
    invalidCharacter,
};

pub fn evalFormula(allocator: *std.mem.Allocator, formula: []const u8) !bool {
    var stack = try Stack(u1).init(allocator);
    defer stack.deinit();

    var i: usize = 0;

    while (i < formula.len) : (i += 1) {
        if (Value.getValue(formula[i])) |value| {
            try stack.push(value.getBool());
        } else if (Operator.getOp(formula[i])) |operator| {
            if (operator == Operator.@"!") {
                // std.debug.print("~{d}\n", .{stack.data.items[stack.data.items.len - 1]});
                try stack.push(~stack.pop());
                continue;
            }

            if (stack.size < 2) return ParsingError.wrongFormat;

            const a = stack.pop();
            const b = stack.pop();

            try stack.push(operator.doOp(a, b));
        } else return ParsingError.invalidCharacter;
    }
    // stack.print();
    return if (stack.pop() == 0) false else true;
}

pub fn computeFormula(str: []const u8) !void {
    var allocator = std.testing.allocator;
    std.debug.print("{s}Formula = {s}{s}{s}\n", .{ color.green, color.yellow, str, color.reset });
    const res = try evalFormula(&allocator, str);
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

test "expr14" {
    const str = "1!0|1011|1&>&11&!&|";
    try computeFormula(str);
}

test "more than one item in stack" {
    const str = "001|";
    try computeFormula(str);
}

test "error wrongFormat" {
    const str = "11||";
    try std.testing.expectError(ParsingError.wrongFormat, computeFormula(str));
    std.log.err("{}", .{ParsingError.wrongFormat});
}

test "error invalidCharacter" {
    const str = "1 1|";
    try std.testing.expectError(ParsingError.invalidCharacter, computeFormula(str));
    std.log.err("{}", .{ParsingError.invalidCharacter});
}
