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

fn unionOfSets(allocator: *std.mem.Allocator, sets: ArrayList(ArrayList(i32))) !ArrayList(i32) {
    var empty_set = ArrayList(i32).init(allocator.*);
    for (0..sets.items.len) |it| {
        const tmp = try Operator.doUnion(allocator, empty_set, sets.items.ptr[it]);
        empty_set.deinit();
        empty_set = tmp;
    }
    return empty_set;
}

pub fn eval_set(allocator: *std.mem.Allocator, formula: []const u8, sets: ArrayList(ArrayList(i32))) !ArrayList(i32) {
    var stack = try Stack(ArrayList(i32)).init(allocator);
    defer stack.deinit();

    const U = try unionOfSets(allocator, sets);
    defer U.deinit();
    // std.debug.print("U = {any}\n", .{U.items});

    formulaIsWrong(formula, sets.items.len) catch |e| {
        return e;
    };

    for (formula) |token| {
        if (Operator.getOp(token)) |operator| {
            if (operator == Operator.@"!") {
                const a = stack.pop();
                const new_set = try operator.doSetOp(allocator, a, U, U);

                a.deinit();
                try stack.push(new_set);
                continue;
            }
            if (stack.size < 2) return error.wrongFormat;

            const b = stack.pop();
            const a = stack.pop();
            const new_set = try operator.doSetOp(allocator, a, b, U);
            a.deinit();
            b.deinit();

            try stack.push(new_set);
        } else try stack.push(try sets.items.ptr[token - 'A'].clone());
    }
    if (stack.size > 1) for (0..stack.size - 1) |it| stack.data.items.ptr[it].deinit();
    return stack.pop();
}

const Color = @import("Colors.zig").ansi;

pub fn ESTest(allocator: *std.mem.Allocator, formula: []const u8, sets: ArrayList(ArrayList(i32))) !void {
    std.debug.print("Input Sets :\n", .{});
    for (sets.items) |Set| {
        std.debug.print("{s}{any}{s}\n", .{ Color.yellow, Set.items, Color.reset });
    }
    std.debug.print("Formula : {s}{s}{s}\n", .{ Color.red, formula, Color.reset });

    const result = eval_set(allocator, formula, sets) catch |e| {
        for (sets.items) |item| item.deinit();
        sets.deinit();
        return e;
    };

    std.debug.print("Result set = {s}{any}{s}\n", .{ Color.green, result.items, Color.reset });
    defer result.deinit();

    for (sets.items) |item| item.deinit();
    sets.deinit();

    std.debug.print("-----------------------------\n", .{});
}

test "Evalset test 1" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);

    var setA = ArrayList(i32).init(allocator);
    var setB = ArrayList(i32).init(allocator);
    var sliceA = [3]i32{ 0, 1, 2 };
    var sliceB = [3]i32{ 0, 3, 4 };
    try setA.appendSlice(&sliceA);
    try setB.appendSlice(&sliceB);

    try sets.append(setA);
    try sets.append(setB);

    try ESTest(&allocator, "AB&", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}

test "Evalset test 2" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);

    var setA = ArrayList(i32).init(allocator);
    var setB = ArrayList(i32).init(allocator);
    var sliceA = [3]i32{ 0, 1, 2 };
    var sliceB = [3]i32{ 3, 4, 5 };
    try setA.appendSlice(&sliceA);
    try setB.appendSlice(&sliceB);

    try sets.append(setA);
    try sets.append(setB);

    try ESTest(&allocator, "AB|", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}

test "Evalset test 3" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);

    var setA = ArrayList(i32).init(allocator);
    var sliceA = [3]i32{ 3, 4, 5 };
    try setA.appendSlice(&sliceA);

    try sets.append(setA);

    try ESTest(&allocator, "A!", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}

test "Evalset test 4" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);

    var setA = ArrayList(i32).init(allocator);
    var setB = ArrayList(i32).init(allocator);
    var sliceA = [3]i32{ 0, 1, 2 };
    var sliceB = [3]i32{ 3, 4, 5 };
    try setA.appendSlice(&sliceA);
    try setB.appendSlice(&sliceB);

    try sets.append(setA);
    try sets.append(setB);

    try ESTest(&allocator, "A!", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}

test "Evalset test 5" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);

    var setA = ArrayList(i32).init(allocator);
    var setB = ArrayList(i32).init(allocator);
    var setC = ArrayList(i32).init(allocator);
    var sliceA = [3]i32{ 1, 2, 3 };
    var sliceB = [3]i32{ 3, 4, 5 };
    var sliceC = [3]i32{ 6, 7, 8 };
    try setA.appendSlice(&sliceA);
    try setB.appendSlice(&sliceB);
    try setC.appendSlice(&sliceC);

    try sets.append(setA);
    try sets.append(setB);
    try sets.append(setC);

    try ESTest(&allocator, "AB>", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}

test "Evalset test 6" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);

    var setA = ArrayList(i32).init(allocator);
    var setB = ArrayList(i32).init(allocator);
    var setC = ArrayList(i32).init(allocator);
    var sliceA = [3]i32{ 0, 1, 2 };
    var sliceB = [3]i32{ 0, 1, 3 };
    var sliceC = [3]i32{ 6, 7, 8 };
    try setA.appendSlice(&sliceA);
    try setB.appendSlice(&sliceB);
    try setC.appendSlice(&sliceC);

    try sets.append(setA);
    try sets.append(setB);
    try sets.append(setC);

    try ESTest(&allocator, "AB=", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}

test "Evalset test 7" {
    //From subject tests
    var allocator = std.testing.allocator;

    var sets = ArrayList(ArrayList(i32)).init(allocator);

    var setA = ArrayList(i32).init(allocator);
    var setB = ArrayList(i32).init(allocator);
    var setC = ArrayList(i32).init(allocator);
    var sliceA = [3]i32{ 0, 1, 2 };
    var sliceB = [3]i32{ 0, 1, 3 };
    var sliceC = [3]i32{ 6, 7, 8 };
    try setA.appendSlice(&sliceA);
    try setB.appendSlice(&sliceB);
    try setC.appendSlice(&sliceC);

    try sets.append(setA);
    try sets.append(setB);
    try sets.append(setC);

    try ESTest(&allocator, "AB&", sets);
    // _ = try std.testing.expectError(evalSetErrors.wrongNumberOfSets, ESTest(&allocator, "ABC|", setsClone));
}
