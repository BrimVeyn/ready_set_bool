const std = @import("std");
const math = std.math;
const AST = @import("AST.zig");
const BoolAST = AST.BoolAST;
const Variable = AST.Variable;
const ArrayList = std.ArrayList;
const bit_set = std.bit_set;
const evalFormula = @import("eval_formula.zig").evalFormula;
const StringStream = @import("StringStream.zig").StringStream;
const print_truth_tabel = @import("print_truth_table.zig").print_truth_table;

pub fn negation_normal_form(allocator: *std.mem.Allocator, formula: []const u8) ![]const u8 {
    var ast = BoolAST.init(allocator, formula) catch |e| return e;
    defer ast.deinit();
    // try ast.print(allocator);
    try ast.toNNF();
    // try ast.print(allocator);
    return try ast.toRPN();
}

pub fn computeCNF(rpn: []const u8) !void {
    var allocator = std.testing.allocator;
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 1" {
    try computeCNF("01>");
    try computeCNF("AB=");
    try computeCNF("AB&CD&=");
    try computeCNF("01&1!0||10!|0110&=|&>");
    try computeCNF("AB^");
    try computeCNF("AB&!");
    try computeCNF("AB|!");
    try computeCNF("AB&!!!");
    try computeCNF("AB|C&!");

    //Errors
    _ = try std.testing.expectError(error.wrongFormat, computeCNF("ABC!!"));
    _ = try std.testing.expectError(error.invalidCharacter, computeCNF("A !"));
    _ = try std.testing.expectError(error.wrongFormat, computeCNF("&A !"));
}
