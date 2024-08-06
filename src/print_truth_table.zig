const std = @import("std");
const math = std.math;
const AST = @import("AST.zig");
const BoolAST = AST.BoolAST;
const Variable = AST.Variable;
const ArrayList = std.ArrayList;
const bit_set = std.bit_set;
const evalFormula = @import("eval_formula.zig").evalFormula;
const StringStream = @import("StringStream.zig").StringStream;

fn countVar(formula: []const u8) bit_set.IntegerBitSet(26) {
    var bitSet = bit_set.IntegerBitSet(26).initEmpty();

    for (formula) |token| {
        if (Variable.getVariable(token)) |_| {
            if (!bitSet.isSet(token - 'A'))
                bitSet.set(token - 'A');
        }
    }
    return bitSet;
}

fn usizeToBitSet(it: usize) bit_set.IntegerBitSet(26) {
    var bitSet = bit_set.IntegerBitSet(26).initEmpty();
    var i: u6 = 0;

    for (0..64) |_| {
        const isActive = (it & (@as(usize, 1) << i) > 0);

        if (isActive) bitSet.set(i);

        i +%= 1;
    }
    return bitSet;
}

fn replaceVariable(allocator: *std.mem.Allocator, formula: []const u8, nbVar: u6, itBitSet: bit_set.IntegerBitSet(26)) ![]const u8 {
    var newFormula = ArrayList(u8).init(allocator.*);
    for (formula) |token| {
        if (Variable.getVariable(token)) |_| {
            const value: u8 = if (itBitSet.isSet(nbVar - 1 - (token - 'A'))) '1' else '0';
            try newFormula.append(value);
        } else {
            try newFormula.append(token);
        }
    }
    return newFormula.toOwnedSlice();
}

fn getHeader(allocator: *std.mem.Allocator, nbVar: u6) !StringStream {
    var ss = StringStream.init(allocator);
    try ss.append("|");
    for (0..nbVar) |it| {
        try ss.append(" ");
        try ss.appendChar(@as(u8, @intCast(it)) + 'A');
        try ss.append(" |");
    }
    try ss.append(" = |\n|");
    for (0..nbVar) |_| {
        try ss.append("---|");
    }
    try ss.append("---|\n");
    return ss;
}

fn addBody(ss: *StringStream, nbVar: usize, itBitSet: bit_set.IntegerBitSet(26), result: u8) !void {
    try ss.*.append("|");
    for (0..nbVar) |curr| {
        const varValue: u8 = if (itBitSet.isSet(nbVar - 1 - curr)) '1' else '0';
        try ss.*.append(" ");
        try ss.*.appendChar(varValue);
        try ss.*.append(" |");
    }
    try ss.*.append(" ");
    try ss.*.appendChar(result);
    try ss.*.append(" |\n");
}

const TruthTableError = error{
    AlphabeticSequenceBroken,
    NoVariable,
};

fn checkSetIntegrity(activeVariableBitSet: bit_set.IntegerBitSet(26), nbVar: u6) !void {
    if (nbVar == 0) {
        return TruthTableError.NoVariable;
    }
    for (nbVar..26) |it| {
        if (activeVariableBitSet.isSet(it)) return TruthTableError.AlphabeticSequenceBroken;
    }
}

pub fn print_truth_table(allocator: *std.mem.Allocator, formula: []const u8) !void {
    const activeVariableBitSet = countVar(formula);
    const nbVar: u6 = @intCast(activeVariableBitSet.count());
    try checkSetIntegrity(activeVariableBitSet, nbVar);
    const nbIterations: usize = @as(usize, 1) << (nbVar);
    var ss = try getHeader(allocator, nbVar);
    defer ss.deinit();
    for (0..nbIterations) |it| {
        const itBitSet = usizeToBitSet(it);
        const newFormula = try replaceVariable(allocator, formula, nbVar, itBitSet);
        defer allocator.free(newFormula);
        const result: u8 = if (try evalFormula(allocator, newFormula) == true) '1' else '0';
        try addBody(&ss, nbVar, itBitSet, result);
    }
    const ssString = try ss.toStr();
    std.debug.print("{s}", .{ssString});
    defer allocator.free(ssString);
}

test "truth_table 1" {
    var allocator = std.testing.allocator;
    const rpn = "AB&C|";
    try print_truth_table(&allocator, rpn);
    var ast = try BoolAST.init(&allocator, rpn);
    try ast.print(&allocator);
    ast.deinit();
    std.debug.print("-----------------------------------------\n", .{});
}

test "truth_table 3" {
    var allocator = std.testing.allocator;
    const rpn = "A!B|";
    try print_truth_table(&allocator, rpn);
    var ast = try BoolAST.init(&allocator, rpn);
    try ast.print(&allocator);
    ast.deinit();
    std.debug.print("-----------------------------------------\n", .{});
}

test "truth_table 2" {
    var allocator = std.testing.allocator;
    const rpn = "A!B|ABCD|A&>&BC&!&|1>";
    try print_truth_table(&allocator, rpn);
    var ast = try BoolAST.init(&allocator, rpn);
    try ast.print(&allocator);
    ast.deinit();
}

test "truth_table 4" {
    var allocator = std.testing.allocator;
    const rpn = "AB!&A!B&|"; //XOR in NNF
    try print_truth_table(&allocator, rpn);
    var ast = try BoolAST.init(&allocator, rpn);
    try ast.print(&allocator);
    ast.deinit();
}

const ParsingError = @import("eval_formula.zig").ParsingError;

test "truth_table error" {
    var allocator = std.testing.allocator;
    const rpn = "AB||";
    try std.testing.expectError(ParsingError.wrongFormat, print_truth_table(&allocator, rpn));
}

test "truth_table error2" {
    var allocator = std.testing.allocator;
    const rpn = "ABD&&";
    try std.testing.expectError(TruthTableError.AlphabeticSequenceBroken, print_truth_table(&allocator, rpn));
}

// test "truth_table 3" {
//     var allocator = std.testing.allocator;
//     const rpn = "AB|C!DE!&|&AB&EC!C|=|FG|H!IJ!&|&KL&MN!O|=|";
//     try print_truth_table(&allocator, rpn);
// }
