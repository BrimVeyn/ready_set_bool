const std = @import("std");
const formula = @import("eval_formula.zig");
const Operator = formula.Operator;
const Value = formula.Value;
const ArrayList = std.ArrayList;

const Stack = @import("Stack.zig").Stack;
const StringStream = @import("StringStream.zig").StringStream;
const eql = std.mem.eql;

pub const Variable = enum(u8) {
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,

    pub fn getVariable(c: u8) ?Variable {
        return switch (c) {
            'A'...'Z' => @enumFromInt(c - 'A'),
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
            .value => @tagName(self.value),
            .operator => return switch (self.operator) {
                Operator.@"!" => "NOT",
                Operator.@"&" => "AND",
                Operator.@"^" => "XOR",
                Operator.@"|" => "OR",
                Operator.@">" => "IMP",
                Operator.@"=" => "EQL",
            },
            .variable => @tagName(self.variable),
        };
    }

    pub fn toTagname(self: Self) []const u8 {
        return switch (self) {
            .value => @tagName(self.value),
            .variable => @tagName(self.variable),
            .operator => @tagName(self.operator),
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

    fn clearNodeStack(allocator: *std.mem.Allocator, stack: Stack(*Node)) void {
        for (0..stack.size) |it| {
            freeTree(allocator, stack.data.items.ptr[it]);
        }
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
                if (operator == Operator.@"!" and stack.size >= 1) {
                    const left = stack.pop();
                    const node = try Node.init(Kind{ .operator = operator }, left, null);
                    try stack.push(node);
                } else if (stack.size >= 2) {
                    const right = stack.pop();
                    const left = stack.pop();
                    const node = try Node.init(Kind{ .operator = operator }, left, right);
                    try stack.push(node);
                } else {
                    clearNodeStack(allocator, stack);
                    return error.wrongFormat;
                }
            } else {
                clearNodeStack(allocator, stack);
                return error.invalidCharacter;
            }
        }

        if (stack.size >= 2) {
            clearNodeStack(allocator, stack);
            return error.wrongFormat;
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
        try removeMultipleNot(self.root);
        try replaceIMP(self.root);
        try replaceEQL(self.root);
        try replaceXOR(self.root);
        try applyDeMorgan(self.root);
        try removeMultipleNot(self.root);
    }

    pub fn toCNF(self: *Self) !void {
        try distribute(self.allocator, self.root);
        try applyComplement(self.allocator, self.root);
        try applyIdentity(self.allocator, self.root);
        try flattenAndReorder(self.allocator, self.root);
    }

    fn flattenAndReorder(allocator: *std.mem.Allocator, maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            var stack = try Stack(*Node).init(allocator);
            try collectANDs(allocator, &stack, node);
            defer stack.deinit();
            var current = maybe_node;
            if (stack.size > 2) {
                while (stack.size > 2) {
                    current.?.left = try dup(stack.popFront());
                    current.?.right = try Node.init(Kind{ .operator = .@"&" }, null, null);
                    current = current.?.right;
                }
            }
            stack.print();
        }
    }

    fn collectANDs(allocator: *std.mem.Allocator, stack: *Stack(*Node), node: *Node) !void {
        if (eql(u8, node.kind.toStr(), "AND")) {
            if (node.left) |lhs| {
                try collectANDs(allocator, stack, lhs);
            }
            if (node.right) |rhs| {
                try collectANDs(allocator, stack, rhs);
            }
        } else {
            try stack.push(node);
        }
    }

    fn applyIdentity(allocator: *std.mem.Allocator, maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            //Identity law --> A V 0 <=> A || A ^ 1 <=> A
            const token = node.kind.toStr();
            const isTokenAND = eql(u8, token, "AND");
            const isTokenOR = eql(u8, token, "OR");
            if (isTokenAND or isTokenOR) {
                const operand = if (isTokenOR) "0" else "1";
                if (node.left) |lhs| {
                    if (node.right) |rhs| {
                        const AisBool = eql(u8, lhs.kind.toStr(), operand);
                        const BisBool = eql(u8, rhs.kind.toStr(), operand);
                        const toDup = if (AisBool) node.right else if (BisBool) node.left else null;
                        const toRemove = if (AisBool) node.left else if (BisBool) node.right else null;

                        if (AisBool or BisBool) {
                            const new_node = try dup(toDup);
                            defer allocator.destroy(new_node.?);

                            freeTree(allocator, toRemove);
                            freeTree(allocator, toDup);
                            node.left = null;
                            node.right = null;

                            node.* = new_node.?.*;
                        }
                    }
                }
            }
            try applyIdentity(allocator, node.left);
            try applyIdentity(allocator, node.right);
        }
    }

    fn applyComplement(allocator: *std.mem.Allocator, maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            //Complement law --> A & !A <=> 0 || A + !A = 1
            const token = node.kind.toStr();
            const isTokenAND = eql(u8, token, "AND");
            const isTokenOR = eql(u8, token, "OR");

            if (isTokenOR or isTokenAND) {
                const isLhsNOT = eql(u8, node.left.?.kind.toStr(), "NOT");
                const isRhsNOT = eql(u8, node.right.?.kind.toStr(), "NOT");

                if ((isLhsNOT and !isRhsNOT) or (!isLhsNOT and isRhsNOT)) {
                    const newValue = if (isTokenAND) Value.@"0" else Value.@"1";
                    var A = if (isLhsNOT) node.left.?.left else node.right.?.left;
                    var B = if (isLhsNOT) node.right else node.left;

                    if (eql(u8, A.?.kind.toStr(), B.?.kind.toStr())) {
                        freeTree(allocator, node.left);
                        freeTree(allocator, node.right);
                        node.kind = Kind{ .value = newValue };
                        node.left = null;
                        node.right = null;
                    }
                }
            }

            try applyComplement(allocator, node.left);
            try applyComplement(allocator, node.right);
        }
    }

    fn distribute(allocator: *std.mem.Allocator, maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            if (eql(u8, node.kind.toStr(), "OR")) {
                const isLhsAND = eql(u8, node.left.?.kind.toStr(), "AND");
                const isRhsAND = eql(u8, node.right.?.kind.toStr(), "AND");

                if (isLhsAND or isRhsAND) {
                    node.kind = Kind{ .operator = .@"&" };
                    //Distributivity law --> A V (B & C) <=> (A V B) & (A V C);
                    //Commutative law --> A V B <=> B V A || A & B <=> B & A;
                    var A: StringStream = undefined;
                    var B: StringStream = undefined;
                    var C: StringStream = undefined;
                    defer A.deinit();
                    defer B.deinit();
                    defer C.deinit();

                    if (isRhsAND) {
                        A = try nodeToRPN(allocator, node.left);
                        B = try nodeToRPN(allocator, node.right.?.left);
                        C = try nodeToRPN(allocator, node.right.?.right);
                    } else if (isLhsAND and !isRhsAND) {
                        A = try nodeToRPN(allocator, node.right);
                        B = try nodeToRPN(allocator, node.left.?.left);
                        C = try nodeToRPN(allocator, node.left.?.right);
                    }

                    var new_lhs = try StringStream.concat(allocator, &A, &B);
                    defer new_lhs.deinit();
                    try new_lhs.appendChar('|');
                    const new_lhs_str = try new_lhs.toStr();
                    defer allocator.free(new_lhs_str);

                    var new_rhs = try StringStream.concat(allocator, &A, &C);
                    defer new_rhs.deinit();
                    try new_rhs.appendChar('|');
                    const new_rhs_str = try new_rhs.toStr();
                    defer allocator.free(new_rhs_str);

                    freeTree(allocator, node.left);
                    freeTree(allocator, node.right);

                    node.left = try genAST(allocator, new_lhs_str);
                    node.right = try genAST(allocator, new_rhs_str);
                }
            }
            try distribute(allocator, node.left);
            try distribute(allocator, node.right);
        }
    }

    fn nodeToRPN(allocator: *std.mem.Allocator, node: ?*Node) !StringStream {
        var ss = StringStream.init(allocator);
        var stack = try Stack(*Node).init(allocator);
        defer stack.deinit();

        try treeToStack(&stack, node.?.left);
        try treeToStack(&stack, node.?.right);
        try stack.push(node.?);

        for (0..stack.size) |it| {
            try ss.append(stack.data.items.ptr[it].kind.toTagname());
        }
        return ss;
    }

    pub fn toRPN(self: *Self) ![]const u8 {
        var ss = StringStream.init(self.allocator);
        defer ss.deinit();
        var stack = try Stack(*Node).init(self.allocator);
        defer stack.deinit();

        try treeToStack(&stack, self.root.left);
        try treeToStack(&stack, self.root.right);
        try stack.push(self.root);

        for (0..stack.size) |it| {
            try ss.append(stack.data.items.ptr[it].kind.toTagname());
        }
        return ss.toStr();
    }

    fn treeToStack(stack: *Stack(*Node), maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            try treeToStack(stack, node.left);
            try treeToStack(stack, node.right);
            try stack.*.push(node);
        }
    }

    fn removeMultipleNot(maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            while (eql(u8, node.kind.toStr(), "NOT") and eql(u8, node.left.?.kind.toStr(), "NOT")) {
                const tmp = node.left.?.left.?.*;
                std.testing.allocator.destroy(node.left.?.left.?);
                std.testing.allocator.destroy(node.left.?);
                node.* = tmp;
            }
            try removeMultipleNot(node.left);
            try removeMultipleNot(node.right);
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
                        lhs.left = try Node.init(Kind{ .operator = .@"!" }, tmp_lhs, null);
                        lhs.right = try Node.init(Kind{ .operator = .@"!" }, tmp_rhs, null);

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
                node.kind = Kind{ .operator = .@"|" };
                const tmp_lhs = node.left;
                const tmp_rhs = node.right;

                node.left = try Node.init(Kind{ .operator = .@"&" }, tmp_lhs, null);
                node.left.?.right = try Node.init(Kind{ .operator = .@"!" }, tmp_rhs, null);

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
                node.kind = Kind{ .operator = .@"|" };
                const tmp_lhs = node.left;
                const tmp_rhs = node.right;

                node.left = try Node.init(Kind{ .operator = .@"&" }, tmp_lhs, tmp_rhs);

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

test "SandBox 2" {
    const str = "AB&C&D&";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}

test "SandBox 3" {
    const str = "AB&CD&&";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}

test "SandBox" {
    const str = "ABCD&&&";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.init(&allocator, str);
    try AST.print(&allocator);
    AST.deinit();
    std.debug.print("------------------\n", .{});
}
