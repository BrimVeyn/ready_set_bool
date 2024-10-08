const std = @import("std");
const math = std.math;
const AST = @import("AST.zig");
const BoolAST = AST.BoolAST;

pub fn conjunctive_normal_form(allocator: *std.mem.Allocator, formula: []const u8) ![]const u8 {
    var ast = BoolAST.init(allocator, formula) catch |e| return e;
    defer ast.deinit();
    // try ast.print(allocator);
    try ast.toNNF();
    // try ast.print(allocator);
    try ast.toCNF();
    // try ast.print(allocator);
    return try ast.toRPN();
}

pub fn CNFTest(rpn: []const u8) !void {
    var allocator = std.testing.allocator;
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try conjunctive_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("CNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "CNF basic 1" {
    //From subject tests
    try CNFTest("AB&!");
    try CNFTest("AB|!");
    try CNFTest("AB|C&");
    try CNFTest("AB|C|D|");
    try CNFTest("AB&C&D&");
    try CNFTest("AB&!C!|");
    try CNFTest("AB|!C!&");

    //Advanced tests
    try CNFTest("AA!|");
    try CNFTest("A!B|ABCD|A&>&BC&!&|1>");
    try CNFTest("A!B|ABCD|A&>&BC&!&|D>");
    try CNFTest("DD&");
    try CNFTest("D!D!&");
    try CNFTest("DA|DB!|DBA!B|||DBA!A!C!||||DBA!A!D!||||DCA!B|||DCA!A!C!||||DCA!A!D!||||&&&&&&&DA|DB!|DBA!B|||DBA!A!C!||||DBA!A!D!||||DCA!B|||DCA!A!C!||||DCA!A!D!||||&&&&&&&&");

    //Errors
    // _ = try std.testing.expectError(error.wrongFormat, CNFTest("ABC!!"));
    // _ = try std.testing.expectError(error.invalidCharacter, CNFTest("A !"));
    // _ = try std.testing.expectError(error.wrongFormat, CNFTest("&A !"));
}
