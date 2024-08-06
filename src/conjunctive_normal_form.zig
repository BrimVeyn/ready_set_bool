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

pub fn conjunctive_normal_form(allocator: *std.mem.Allocator, formula: []const u8) ![]const u8 {
    var ast = BoolAST.init(allocator, formula) catch |e| return e;
    defer ast.deinit();
    try ast.print(allocator);
    try ast.toNNF();
    try ast.toCNF();
    try ast.print(allocator);
    return try ast.toRPN();
}

test "CNF basic 1" {
    var allocator = std.testing.allocator;
    const rpn = "AB&A!B!&|";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try conjunctive_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("CNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "CNF Error 1" {
    var allocator = std.testing.allocator;
    const rpn = "ABC!!";
    const Err = conjunctive_normal_form(&allocator, rpn);
    _ = try std.testing.expectError(error.wrongFormat, Err);
    std.debug.print("-----------------------------\n", .{});
}

test "CNF Error 2" {
    var allocator = std.testing.allocator;
    const rpn = "A !";
    const Err = conjunctive_normal_form(&allocator, rpn);
    _ = try std.testing.expectError(error.invalidCharacter, Err);
    std.debug.print("-----------------------------\n", .{});
}

test "CNF Error 3" {
    var allocator = std.testing.allocator;
    const rpn = "&A !";
    const Err = conjunctive_normal_form(&allocator, rpn);
    _ = try std.testing.expectError(error.wrongFormat, Err);
    std.debug.print("-----------------------------\n", .{});
}
