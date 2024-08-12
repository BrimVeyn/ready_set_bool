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

pub const evalSetErrors = error {
    wrongNumberOfSets,
    valueNotAccepted,
};

fn formulaIsWrong(formula: []const u8, setLen: usize) !void {
    for (formula) |token| {
        if (Variable.getVariable(token)) |_| {
            if (token - 'A' + 1 > setLen) return evalSetErrors.wrongNumberOfSets;
        }
        if (Value.getValue(token)) |_| return evalSetErrors.valueNotAccepted;
    }
}

pub fn eval_set(allocator: *std.mem.Allocator, formula: []const u8, sets: ArrayList(ArrayList(i32))) !ArrayList(i32) {
    _ = formula; // autofix
    _ = sets; // autofix
    var stack = try Stack(ArrayList(i32)).init(allocator);
    var resultSet = ArrayList(i32).init(allocator.*);
    try resultSet.append(32);
    defer stack.deinit();

    formulaIsWrong() catch |e| return e;
    return resultSet;

    // var i: usize = 0;
    //
    // while (i < formula.len) : (i += 1) {
    //     if (Value.getValue(formula[i])) |value| {
    //         try stack.push(value.getBool());
    //     } else if (Operator.getOp(formula[i])) |operator| {
    //         if (operator == Operator.@"!") {
    //             // std.debug.print("~{d}\n", .{stack.data.items[stack.data.items.len - 1]});
    //             try stack.push(~stack.pop());
    //             continue;
    //         }
    //
    //         if (stack.size < 2) return ParsingError.wrongFormat;
    //
    //         const a = stack.pop();
    //         const b = stack.pop();
    //
    //         try stack.push(operator.doOp(a, b));
    //     } else return ParsingError.invalidCharacter;
    // }
    // stack.print();
    // return if (stack.pop() == 0) false else true;
}

pub fn ESTest(allocator: *std.mem.Allocator, formula: []const u8, sets: ArrayList(ArrayList(i32))) !void {
    defer for (sets.items) |item| item.deinit();
    std.debug.print("Input Sets :\n", .{});
    for (sets.items) |Set| {
        defer Set.deinit();
        std.debug.print("{any}\n", .{Set.items});
    }
    const result = try eval_set(allocator, formula, sets);
    defer result.deinit();
    std.debug.print("-----------------------------\n", .{});
}

test "Evalset tests" {
    //From subject tests
    var allocator = std.testing.allocator;

    var vect = ArrayList(i32).init(allocator);
    var setA = [5]i32{ 1, 2, 3 };
    var setB = [3]i32{ 1, 2, 3 };

    try vect.appendSlice(&slice);
    try PSTest(&allocator, vect);

}
