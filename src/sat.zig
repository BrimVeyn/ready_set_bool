const std = @import("std");
const math = std.math;
const AST = @import("AST.zig");
const BoolAST = AST.BoolAST;
const Variable = AST.Variable;
const ArrayList = std.ArrayList;
const bit_set = std.bit_set;
const evalFormula = @import("eval_formula.zig").evalFormula;
const StringStream = @import("StringStream.zig").StringStream;
const truth_table = @import("print_truth_table.zig");
const countVar = truth_table.countVar;
const checkSetIntegrity = truth_table.checkSetIntegrity;
const usizeToBitSet = truth_table.usizeToBitSet;
const replaceVariable = truth_table.replaceVariable;
const getValueBitSet = truth_table.getValueBitSet;

fn sat(allocator: *std.mem.Allocator, formula: []const u8) !bool {
    var ast = BoolAST.init(allocator, formula) catch |e| return e;
    defer ast.deinit();
    try ast.toNNF();
    try ast.toCNF();
    // try ast.print(allocator);

    const CNF_formula = try ast.toRPN();
    defer allocator.free(CNF_formula);

    if (CNF_formula.len == 1) {
        if (CNF_formula[0] == '0') return false;
        if (CNF_formula[0] == '1') return true;
    }

    const activeVariableBitSet = countVar(CNF_formula);
    const nbVar: u6 = @intCast(activeVariableBitSet.count());
    if (nbVar == 0) return error.NoVariable;

    const nbIterations: usize = @as(usize, 1) << (nbVar);

    for (0..nbIterations) |it| {
        const itBitSet = usizeToBitSet(it);
        const valueBitSet = getValueBitSet(itBitSet, activeVariableBitSet);

        const newFormula = try replaceVariable(allocator, formula, valueBitSet);
        defer allocator.free(newFormula);

        const result = try evalFormula(allocator, newFormula);
        if (result == true) return true;
    }
    return false;
}

pub fn SATTest(rpn: []const u8) !void {
    var allocator = std.testing.allocator;
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const result = try sat(&allocator, rpn);
    std.debug.print("Is formula satisfiable ? {}\n", .{result});
    std.debug.print("-----------------------------\n", .{});
}

test "SAT tests" {
    //From subject tests
    try SATTest("AB&!");
    try SATTest("AB|!");
    try SATTest("AB|C&");
    try SATTest("AB|C|D|");
    try SATTest("AB&C&D&");
    try SATTest("AB&!C!|");
    try SATTest("AB|!C!&");
    try SATTest("AA!&");
    try SATTest("AB&");
    try SATTest("AB|");
    try SATTest("AA^");
    try SATTest("A");
    try SATTest("DA|DB!|DBA!B|||DBA!A!C!||||DBA!A!D!||||DCA!B|||DCA!A!C!||||DCA!A!D!||||&&&&&&&DA|DB!|DBA!B|||DBA!A!C!||||DBA!A!D!||||DCA!B|||DCA!A!C!||||DCA!A!D!||||&&&&&&&&");
    try SATTest("Z!Z&");

    //Errors
    // _ = try std.testing.expectError(error.wrongFormat, SATTest("ABC!!"));
    // _ = try std.testing.expectError(error.invalidCharacter, SATTest("A !"));
    // _ = try std.testing.expectError(error.wrongFormat, SATTest("&A !"));
}
