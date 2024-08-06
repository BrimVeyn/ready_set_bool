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

test "NNF basic 1" {
    var allocator = std.testing.allocator;
    const rpn = "01>";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 2" {
    var allocator = std.testing.allocator;
    const rpn = "AB=";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 3" {
    var allocator = std.testing.allocator;
    const rpn = "AB&CD&=";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 4" {
    var allocator = std.testing.allocator;
    const rpn = "01&1!0||10!|0110&=|&>";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 5" {
    var allocator = std.testing.allocator;
    const rpn = "AB^";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 6" {
    var allocator = std.testing.allocator;
    const rpn = "AB=";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 7" {
    var allocator = std.testing.allocator;
    const rpn = "AB&!";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 8" {
    var allocator = std.testing.allocator;
    const rpn = "AB|!";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 9" {
    var allocator = std.testing.allocator;
    const rpn = "AB&!!!";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF basic 10" {
    var allocator = std.testing.allocator;
    const rpn = "AB|C&!";
    std.debug.print("RPN Formula: {s}\n", .{rpn});
    const new_rpn = try negation_normal_form(&allocator, rpn);
    defer allocator.free(new_rpn);
    std.debug.print("NNF RPN Formula: {s}\n", .{new_rpn});
    std.debug.print("-----------------------------\n", .{});
}

test "NNF Error 1" {
    var allocator = std.testing.allocator;
    const rpn = "ABC!!";
    const Err = negation_normal_form(&allocator, rpn);
    _ = try std.testing.expectError(error.wrongFormat, Err);
    std.debug.print("-----------------------------\n", .{});
}

test "NNF Error 2" {
    var allocator = std.testing.allocator;
    const rpn = "A !";
    const Err = negation_normal_form(&allocator, rpn);
    _ = try std.testing.expectError(error.invalidCharacter, Err);
    std.debug.print("-----------------------------\n", .{});
}

test "NNF Error 3" {
    var allocator = std.testing.allocator;
    const rpn = "&A !";
    const Err = negation_normal_form(&allocator, rpn);
    _ = try std.testing.expectError(error.wrongFormat, Err);
    std.debug.print("-----------------------------\n", .{});
}
