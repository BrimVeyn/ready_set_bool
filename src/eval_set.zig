const std = @import("std");
const math = std.math;
const ArrayList = std.ArrayList;
const Stack = @import("Stack.zig").Stack;
const AST = @import("AST.zig");
const eval_formula = @import("eval_formula.zig");

const Operator = eval_formula.Operator;
const Value = eval_formula.Value;
const Variable = AST.Variable;
const ParsingError = eval_formula.ParsingError;

pub const evalSetErrors = error{
    wrongNumberOfSets,
    valuesNotAccepted,
};

fn formulaIsWrong(formula: []const u8, setLen: usize) !void {
    for (formula) |token| {
        if (Variable.getVariable(token)) |_| {
            if (token - 'A' + 1 > setLen) return evalSetErrors.wrongNumberOfSets;
        }
        if (Value.getValue(token)) |_| return evalSetErrors.valuesNotAccepted;
    }
}

pub fn eval_set(allocator: *std.mem.Allocator, formula: []const u8, sets: ArrayList(ArrayList(i32))) !ArrayList(i32) {
    var stack = try Stack(ArrayList(i32)).init(allocator);

    defer stack.deinit();

    formulaIsWrong(formula, sets.items.len) catch |e| {
        return e;
    };

    for (formula) |token| {
        if (Operator.getOp(token)) |operator| {
            if (stack.size < 2) return error.wrongFormat;

            const b = stack.pop();
            const a = stack.pop();
            const new_set = try operator.doSetOp(allocator, a, b);
            a.deinit();
            b.deinit();

            try stack.push(new_set);
        } else try stack.push(try sets.items.ptr[token - 'A'].clone());
    }

    return stack.pop();
}

pub fn ESTest(allocator: *std.mem.Allocator, formula: []const u8, sets: ArrayList(ArrayList(i32))) !void {
    std.debug.print("Input Sets :\n", .{});
    for (sets.items) |Set| {
        std.debug.print("{any}\n", .{Set.items});
    }

    const result = eval_set(allocator, formula, sets) catch |e| {
        for (sets.items) |item| item.deinit();
        sets.deinit();
        return e;
    };

    std.debug.print("Result set = {any}\n", .{result.items});
    defer result.deinit();

    for (sets.items) |item| item.deinit();
    sets.deinit();

    std.debug.print("-----------------------------\n", .{});
}

test "Evalset tests" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);
    var setA = ArrayList(i32).init(allocator);
    var setB = ArrayList(i32).init(allocator);
    var sliceA = [5]i32{ 1, 2, 3, 4, 5 };
    var sliceB = [3]i32{ 1, 2, 3 };
    try setA.appendSlice(&sliceA);
    try setB.appendSlice(&sliceB);

    try sets.append(setA);
    try sets.append(setB);

    try ESTest(&allocator, "AB^", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}
