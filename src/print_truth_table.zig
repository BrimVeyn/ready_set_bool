const std = @import("std");
const math = std.math;
const AST = @import("AST.zig");
const BoolAST = AST.BoolAST;
const Variable = AST.Variable;
const ArrayList = std.ArrayList;
const bit_set = std.bit_set;
const evalFormula = @import("eval_formula.zig").evalFormula;
const StringStream = @import("StringStream.zig").StringStream;

pub fn countVar(formula: []const u8) bit_set.IntegerBitSet(26) {
    var bitSet = bit_set.IntegerBitSet(26).initEmpty();

    for (formula) |token| {
        if (Variable.getVariable(token)) |_| {
            if (!bitSet.isSet(token - 'A'))
                bitSet.set(token - 'A');
        }
    }
    return bitSet;
}

pub fn usizeToBitSet(it: usize) bit_set.IntegerBitSet(26) {
    var bitSet = bit_set.IntegerBitSet(26).initEmpty();
    var i: u6 = 0;

    for (0..64) |_| {
        const isActive = (it & (@as(usize, 1) << i) > 0);

        if (isActive) bitSet.set(i);

        i +%= 1;
    }
    return bitSet;
}

fn getHeader(allocator: *std.mem.Allocator, activeVariableBitSet: bit_set.IntegerBitSet(26)) !StringStream {
    var ss = StringStream.init(allocator);
    try ss.append("|");
    var aVBit = activeVariableBitSet.iterator(.{});
    while (aVBit.next()) |it| {
        try ss.append(" ");
        try ss.appendChar(@as(u8, @intCast(it)) + 'A');
        try ss.append(" |");
    }
    try ss.append(" = |\n|");
    aVBit = activeVariableBitSet.iterator(.{});
    while (aVBit.next()) |_| {
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

pub fn getValueBitSet(itBitSet: bit_set.IntegerBitSet(26), activeVariableBitSet: bit_set.IntegerBitSet(26)) bit_set.IntegerBitSet(26) {
    var valueBitSet = bit_set.IntegerBitSet(26).initEmpty();
    var itBit: usize = 0;
    var variable_it = activeVariableBitSet.iterator(.{ .direction = .reverse });

    while (variable_it.next()) |it| {
        if (itBitSet.isSet(itBit)) {
            valueBitSet.set(it);
        }
        itBit += 1;
    }
    return valueBitSet;
}

pub fn replaceVariable(allocator: *std.mem.Allocator, formula: []const u8, valueBitSet: bit_set.IntegerBitSet(26)) ![]const u8 {
    var newFormula = ArrayList(u8).init(allocator.*);
    for (formula) |token| {
        if (Variable.getVariable(token)) |_| {
            const value: u8 = if (valueBitSet.isSet(@intCast(token - 'A'))) '1' else '0';
            try newFormula.append(value);
        } else {
            try newFormula.append(token);
        }
    }
    return newFormula.toOwnedSlice();
}

pub fn print_truth_table(allocator: *std.mem.Allocator, formula: []const u8) !void {
    const activeVariableBitSet = countVar(formula);
    const nbVar: u6 = @intCast(activeVariableBitSet.count());
    if (nbVar == 0) return error.NoVariable;

    const nbIterations: usize = @as(usize, 1) << (nbVar);

    var ss = try getHeader(allocator, activeVariableBitSet);
    defer ss.deinit();
    for (0..nbIterations) |it| {
        const itBitSet = usizeToBitSet(it);
        const valueBitSet = getValueBitSet(itBitSet, activeVariableBitSet);
        // std.debug.print("{}\n", .{activeVariableBitSet});

        const newFormula = try replaceVariable(allocator, formula, valueBitSet);
        defer allocator.free(newFormula);

        const result: u8 = if (try evalFormula(allocator, newFormula) == true) '1' else '0';

        try addBody(&ss, nbVar, itBitSet, result);
    }
    const ssString = try ss.toStr();
    defer allocator.free(ssString);
    std.debug.print("{s}", .{ssString});
}

pub fn computeTT(rpn: []const u8) !void {
    var allocator = std.testing.allocator;
    std.debug.print("Truth Table for: {s}\n", .{rpn});
    try print_truth_table(&allocator, rpn);
    var ast = try BoolAST.init(&allocator, rpn);
    // try ast.print(&allocator);
    ast.deinit();
    std.debug.print("-----------------------------------------\n", .{});
}

test "truth_table 1222" {
    try computeTT("DA|DB!|DBA!B|||DBA!A!C!||||DBA!A!D!||||DCA!B|||DCA!A!C!||||DCA!A!D!||||&&&&&&&");
    try computeTT("AC&E|");
    try computeTT("ZY|K&");
    try computeTT("A!B|ABCD|A&>&BC&!&|D>");
    try computeTT("AB!&A!BC!D!&A!|&|BC&|&D|");
    try computeTT("DA|DB!|DBA!B|||DBA!A!C!||||DCA!B|||&&&&");
    try computeTT("DA|DB|DC|&&");
    try computeTT("CA|CB!|&");
    try computeTT("AB&C|");
    try computeTT("A!B|");
    try computeTT("A!B|ABCD|A&>&BC&!&|1>");
    try computeTT("AB!&A!B&|");
    try computeTT("CA|CB|&");

    _ = try std.testing.expectError(error.wrongFormat, computeTT("ABC!!"));
    _ = try std.testing.expectError(error.invalidCharacter, computeTT("A !"));
    _ = try std.testing.expectError(error.NoVariable, computeTT("01&"));
}
