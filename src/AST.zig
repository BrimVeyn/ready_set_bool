const std = @import("std");
const formula = @import("eval_formula.zig");
const Operator = formula.Operator;
const Value = formula.Value;
const ArrayList = std.ArrayList;

const Stack = @import("Stack.zig").Stack;
const StringStream = @import("StringStream.zig").StringStream;
const eql = std.mem.eql;

pub const Variable = struct {
    const Self = @This();
    char: u8,

    pub fn toStr(self: *const Self) []const u8 {
        var buffer: [1]u8 = [_]u8{self.char};
        const slice = buffer[0..1];
        return slice;
    }

    pub fn getVariable(c: u8) ?Variable {
        return switch (c) {
            'A'...'Z' => Variable{
                .char = c,
            },
            else => null,
        };
    }
};

const Kind = union(enum) {
    const Self = @This();

    operator: Operator,
    value: Value,
    variable: Variable,

    pub fn toStr(self: Self) []const u8 {
        return switch (self) {
            .value => return switch (self.value) {
                Value.@"0" => "0",
                Value.@"1" => "1",
            },
            .operator => return switch (self.operator) {
                Operator.@"!" => "NOT",
                Operator.@"&" => "AND",
                Operator.@"^" => "XOR",
                Operator.@"|" => "OR",
                Operator.@">" => "IMP",
                Operator.@"=" => "EQL",
            },
            .variable => {
                const str = self.variable.toStr();
                return str;
            },
        };
    }
};

const Node = struct {
    const Self = @This();
    kind: Kind,
    left: ?*Node = null,
    right: ?*Node = null,

    pub fn init(kind: Kind, left: ?*Node, right: ?*Node) !*Node {
        const maybe_node = std.testing.allocator.create(Node);
        if (maybe_node) |node| {
            node.kind = kind;
            node.left = left;
            node.right = right;
            return node;
        } else |e| {
            return e;
        }
    }

    pub fn dup(self: *Self) !*Node {
        const maybe_node = std.testing.allocator.create(Node);
        if (maybe_node) |node| {
            node.kind = self.kind;
            node.left = null;
            node.right = null;
            return node;
        } else |e| {
            return e;
        }
    }
};

pub const BoolAST = struct {
    const Self = @This();
    root: *Node,
    allocator: *std.mem.Allocator,

    pub fn print(self: *Self, allocator: *std.mem.Allocator) !void {
        std.debug.print("{s}", .{self.root.kind.toStr()});

        const pointerRight = "└──";
        const pointerLeft = if (self.root.right != null) "├──" else "└──";
        var ss = StringStream.init(allocator);
        try printAST(allocator, self.root.left, &ss, pointerLeft, self.root.right != null);
        try printAST(allocator, self.root.right, &ss, pointerRight, false);
        std.debug.print("\n", .{});
    }

    fn printAST(allocator: *std.mem.Allocator, maybe_node: ?*Node, ss: *StringStream, pointer: []const u8, has_rhs: bool) !void {
        if (maybe_node) |node| {
            const padding = try ss.*.toStr();
            defer allocator.free(padding);

            std.debug.print("\n", .{});
            std.debug.print("{s}", .{padding});
            std.debug.print("{s}", .{pointer});
            std.debug.print("{s}", .{node.kind.toStr()});

            var paddingStream = StringStream.init(ss.allocator);
            defer paddingStream.deinit();
            try paddingStream.append(padding);

            if (has_rhs) {
                try paddingStream.append("│  ");
            } else {
                try paddingStream.append("   ");
            }

            const ptr_left = if (node.right != null) "├──" else "└──";
            const ptr_right = "└──";

            try printAST(allocator, node.left, &paddingStream, ptr_left, node.right != null);
            try printAST(allocator, node.right, &paddingStream, ptr_right, false);
        } else return;
    }

    pub fn init(allocator: *std.mem.Allocator, str: []const u8) !BoolAST {
        const rootNode = try genAST(allocator, str);
        return BoolAST{
            .root = rootNode,
            .allocator = allocator,
        };
    }

    fn genAST(allocator: *std.mem.Allocator, rpn: []const u8) !*Node {
        var stack = try Stack(*Node).init(allocator);
        defer stack.deinit();

        for (rpn) |token| {
            if (Value.getValue(token)) |value| {
                const node = try Node.init(Kind{ .value = value }, null, null);
                try stack.push(node);
            } else if (Variable.getVariable(token)) |variable| {
                const node = try Node.init(Kind{ .variable = variable }, null, null);
                try stack.push(node);
            } else if (Operator.getOp(token)) |operator| {
                if (operator == Operator.@"!") {
                    const left = stack.pop();
                    const node = try Node.init(Kind{ .operator = operator }, left, null);
                    try stack.push(node);
                } else {
                    const right = stack.pop();
                    const left = stack.pop();
                    const node = try Node.init(Kind{ .operator = operator }, left, right);
                    try stack.push(node);
                }
            }
        }
        return stack.pop();
    }

    pub fn dup(maybe_node: ?*Node) !?*Node {
        if (maybe_node) |node| {
            var new_node = try node.dup();
            new_node.left = try dup(node.left);
            new_node.right = try dup(node.right);
            return new_node;
        } else return null;
    }

    pub fn toNNF(self: *Self) !void {
        // try replaceIMP(self.root);
        // try replaceEQL(self.root);
        // try replaceXOR(self.root);
        // try applyDeMorgan(self.root);
        try removeMultipleNot(self.root);
    }

    fn removeMultipleNot(maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            const mb_nodelhs = node.left;
            if (eql(u8, node.kind.toStr(), "NOT")) {
                if (mb_nodelhs) |nodelhs| {
                    if (eql(u8, nodelhs.kind.toStr(), "NOT")) {
                        std.debug.print("YESSS\n", .{});
                        node.* = nodelhs.left.?.*;
                        std.testing.allocator.destroy(nodelhs.left.?);
                        std.testing.allocator.destroy(nodelhs);
                    }
                }
            }
        }
    }

    fn applyDeMorgan(maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            if (eql(u8, node.kind.toStr(), "NOT")) {
                if (node.left) |lhs| {
                    const lhsValue = lhs.kind.toStr();
                    const lhsReverseOperator = if (eql(u8, lhsValue, "AND")) Operator.@"|" else if (eql(u8, lhsValue, "OR")) Operator.@"&" else null;
                    if (lhsReverseOperator) |lhsNewOperator| {
                        defer std.testing.allocator.destroy(lhs);
                        lhs.kind = Kind{ .operator = lhsNewOperator };

                        const tmp_lhs = lhs.left;
                        const tmp_rhs = lhs.right;
                        lhs.left = try Node.init(Kind{ .operator = .@"!" }, null, null);
                        lhs.right = try Node.init(Kind{ .operator = .@"!" }, null, null);
                        lhs.left.?.left = tmp_lhs;
                        lhs.right.?.left = tmp_rhs;

                        node.* = lhs.*;
                    }
                }
            }
            try applyDeMorgan(node.left);
            try applyDeMorgan(node.right);
        }
    }

    fn replaceXOR(maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            if (eql(u8, node.kind.toStr(), "XOR")) {
                std.debug.print("Found XOR\n", .{});
                node.kind = Kind{ .operator = .@"|" };
                const tmp_lhs = node.left;
                const tmp_rhs = node.right;

                node.left = try Node.init(Kind{ .operator = .@"&" }, null, null);
                node.left.?.left = tmp_lhs;
                node.left.?.right = try Node.init(Kind{ .operator = .@"!" }, null, null);
                node.left.?.right.?.left = tmp_rhs;

                node.right = try Node.init(Kind{ .operator = .@"&" }, null, null);
                node.right.?.left = try Node.init(Kind{ .operator = .@"!" }, null, null);
                node.right.?.left.?.left = try BoolAST.dup(tmp_lhs);
                node.right.?.right = try BoolAST.dup(tmp_rhs);
            }
            try replaceXOR(node.left);
            try replaceXOR(node.right);
        }
    }

    fn replaceEQL(maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            if (eql(u8, node.kind.toStr(), "EQL")) {
                std.debug.print("Found EQL\n", .{});
                node.kind = Kind{ .operator = .@"|" };
                const tmp_lhs = node.left;
                const tmp_rhs = node.right;

                node.left = try Node.init(Kind{ .operator = .@"&" }, null, null);
                node.left.?.left = tmp_lhs;
                node.left.?.right = tmp_rhs;

                node.right = try Node.init(Kind{ .operator = .@"&" }, null, null);
                node.right.?.left = try Node.init(Kind{ .operator = .@"!" }, null, null);
                node.right.?.right = try Node.init(Kind{ .operator = .@"!" }, null, null);
                node.right.?.left.?.left = try BoolAST.dup(tmp_lhs);
                node.right.?.right.?.left = try BoolAST.dup(tmp_rhs);
            }
            try replaceEQL(node.left);
            try replaceEQL(node.right);
        }
    }

    fn replaceIMP(maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            if (eql(u8, node.kind.toStr(), "IMP")) {
                node.kind = Kind{ .operator = .@"|" };
                const tmp = node.left;
                node.left = try Node.init(Kind{ .operator = .@"!" }, tmp, null);
                std.debug.print("Found implication\n", .{});
            }
            try replaceIMP(node.left);
            try replaceIMP(node.right);
        }
    }

    pub fn deinit(self: *Self) void {
        freeTree(self.allocator, self.root);
    }

    fn freeTree(allocator: *std.mem.Allocator, maybe_node: ?*Node) void {
        if (maybe_node) |node| {
            defer allocator.destroy(node);
            freeTree(allocator, node.left);
            freeTree(allocator, node.right);
        }
    }
};

test "generate ast from string" {
    const str = "11|0&";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}

test "generate ast from string 1" {
    const str = "01&1!0||";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}

test "generate ast from string 2" {
    const str = "01|1!10!&|&01&11!0|=|>";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}

test "generate ast from string 3" {
    const str = "1!0|1011|1&>&11&!&|";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}

test "generate ast from string with variable" {
    const str = "A!B|CBAA|B&>&AD&!&|";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}
