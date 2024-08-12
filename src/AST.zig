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
        // try self.print(self.allocator);
        for (0..100) |_| {
            const oldTree = try dup(self.root);
            defer freeTree(self.allocator, oldTree);
            try removeMultipleNot(self.root);
            try replaceIMP(self.root);
            try replaceEQL(self.root);
            try replaceXOR(self.root);
            try applyDeMorgan(self.root);
            try removeMultipleNot(self.root);
            if (treeEql(oldTree, self.root)) break;
            // try self.print(self.allocator);
        }
    }

    pub fn toCNF(self: *Self) !void {
        for (0..100) |_| {
            const treeIsCNF = try self.isCNF();
            const oldTree = try dup(self.root);
            try distributeORs(self.allocator, self.root);
            defer freeTree(self.allocator, oldTree);
            try applyIdentity(self.allocator, self.root);
            try applyAnnulment(self.allocator, self.root);
            try flattenAndReorder(self.allocator, self.root, Operator.@"|", treeIsCNF);
            try flattenAndReorder(self.allocator, self.root, Operator.@"&", treeIsCNF);
            // try self.print(self.allocator);
            if (treeEql(oldTree, self.root)) break;
            // std.debug.print("IS CNF ? {}\n", .{treeIsCNF});
        }
    }

    fn collectORs(stack: *Stack(*Node), maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            if (eql(u8, node.kind.toTagname(), "|")) {
                try stack.push(node);
            }
            try collectORs(stack, node.left);
            try collectORs(stack, node.right);
        }
    }

    fn isCNF(self: *Self) !bool {
        var stack = try Stack(*Node).init(self.allocator);
        defer stack.deinit();
        try collectORs(&stack, self.root);
        for (stack.data.items) |item| {
            //To be in CNF OR cannot have a OR to its left, neither a AND (NNF basic)
            if (item.left) |lhs| {
                switch (lhs.kind) {
                    .operator => switch (lhs.kind.operator) {
                        .@"&", .@"|" => return false,
                        else => {},
                    },
                    else => {},
                }
            }
            //Same applies here except that OR can have OR has a right child
            if (item.right) |rhs| {
                switch (rhs.kind) {
                    .operator => switch (rhs.kind.operator) {
                        .@"&" => return false,
                        else => {},
                    },
                    else => {},
                }
            }
        }
        return true;
    }

    fn applyAnnulment(allocator: *std.mem.Allocator, maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            //Annulment law --> A ^ 0 <=> 0 || A V 1 <=> 1
            const isTokenOR = eql(u8, node.kind.toStr(), "OR");
            const isTokenAND = eql(u8, node.kind.toStr(), "AND");
            const replaceBy = if (isTokenOR) "1" else "0";
            if (isTokenOR or isTokenAND) {
                if (node.left == null or node.right == null) return;
                const isOneOfChildsBool = eql(u8, node.left.?.kind.toStr(), replaceBy) or eql(u8, node.right.?.kind.toStr(), replaceBy);

                if (isOneOfChildsBool) {
                    freeTree(allocator, node.left);
                    freeTree(allocator, node.right);
                    node.left = null;
                    node.right = null;
                    node.kind = Kind{ .value = @enumFromInt(replaceBy[0]) };
                }
            }
            try applyAnnulment(allocator, node.left);
            try applyAnnulment(allocator, node.right);
        }
    }

    fn applyComplementLaw(allocator: *std.mem.Allocator, stack: *Stack(*Node), operator: Operator) !void {
        var it: usize = 0;
        const value = if (operator == Operator.@"&") Value.@"0" else Value.@"1";
        for (stack.data.items) |maybe_not| {
            var inner_it: usize = 0;
            if (switch (maybe_not.kind) {
                .value => true,
                .variable => true,
                .operator => switch (maybe_not.kind.operator) {
                    .@"!" => true,
                    else => false,
                },
            }) {
                for (stack.data.items) |maybe_self| {
                    if (switch (maybe_self.kind) {
                        .value => true,
                        .variable => true,
                        .operator => switch (maybe_self.kind.operator) {
                            .@"!" => true,
                            else => false,
                        },
                    }) {
                        if (eql(u8, maybe_not.kind.toTagname(), maybe_self.kind.toTagname()) and (it != inner_it)) {
                            if (eql(u8, maybe_not.kind.toTagname(), "!")) {
                                const value1 = maybe_not.left.?;
                                const value2 = maybe_self.left.?;

                                if (eql(u8, value1.kind.toTagname(), value2.kind.toTagname())) {
                                    // std.debug.print("found {} {}\n", .{ value1, value2 });
                                    freeTree(allocator, stack.popIndex(inner_it));
                                    try applyComplementLaw(allocator, stack, operator);
                                    return;
                                }
                            } else {
                                freeTree(allocator, stack.popIndex(inner_it));
                                try applyComplementLaw(allocator, stack, operator);
                                return;
                            }
                        }
                    }
                    inner_it += 1;
                }
            }
            if (eql(u8, maybe_not.kind.toTagname(), "!")) {
                const nottedValue = maybe_not.left.?;
                for (stack.data.items) |item| {
                    if (eql(u8, nottedValue.kind.toTagname(), item.kind.toTagname())) {
                        // std.debug.print("replacing {}\nand {}\nby {}\n", .{ nottedValue, item, value });
                        item.kind = Kind{ .value = value };
                        freeTree(allocator, stack.popIndex(it));
                        try applyComplementLaw(allocator, stack, operator);
                        return;
                    }
                }
            }
            it += 1;
        }
    }

    fn isNotted(allocator: *std.mem.Allocator, item: *Node, stack: *Stack(*Node)) !bool {
        var isNtGenerative = false;
        for (stack.data.items) |maybenotted| {
            switch (maybenotted.kind) {
                .operator => switch (maybenotted.kind.operator) {
                    .@"!" => {
                        const mn_lhs = maybenotted.left.?;
                        if (eql(u8, item.kind.toTagname(), mn_lhs.kind.toTagname())) {
                            // std.debug.print("replacing {}\nand {}\nby {}\n", .{ item, maybenotted, 0 });
                            freeTree(allocator, maybenotted.left);
                            maybenotted.left = null;
                            maybenotted.right = null;
                            maybenotted.kind = Kind{ .value = .@"0" };
                            isNtGenerative = true;
                        }
                    },
                    else => {},
                },
                else => {},
            }
        }
        if (isNtGenerative) return false else return true;
    }

    fn inclusionTheorem(allocator: *std.mem.Allocator, stack: *Stack(*Node)) !void {
        for (stack.data.items) |item| {
            var isGenerative = true;
            switch (item.kind) {
                .variable => {
                    isGenerative = try isNotted(allocator, item, stack);
                },
                else => {},
            }
            if (!isGenerative) try annulVariable(stack, item.kind.toTagname());
        }
    }

    fn annulVariable(stack: *Stack(*Node), tagName: []const u8) !void {
        for (stack.data.items) |item| {
            if (eql(u8, tagName, item.kind.toTagname())) {
                item.kind = Kind{ .value = .@"0" };
            }
        }
    }

    fn collectVariable(node: *Node, variableStack: *Stack(*Node)) !void {
        if (node.left) |lhs| {
            switch (lhs.kind) {
                .variable => try variableStack.push(lhs),
                .operator => switch (lhs.kind.operator) {
                    .@"!" => try variableStack.push(lhs),
                    else => try collectVariable(lhs, variableStack),
                },
                else => {},
            }
        }
        if (node.right) |rhs| {
            switch (rhs.kind) {
                .variable => try variableStack.push(rhs),
                .operator => switch (rhs.kind.operator) {
                    .@"!" => try variableStack.push(rhs),
                    else => try collectVariable(rhs, variableStack),
                },
                else => {},
            }
        }
    }

    fn collectOPVariable(stack: *Stack(*Node), variableStack: *Stack(*Node)) !void {
        for (stack.data.items) |item| {
            try collectVariable(item, variableStack);
        }
    }

    fn flattenAndReorder(allocator: *std.mem.Allocator, maybe_node: ?*Node, operator: Operator, CNF: bool) !void {
        if (maybe_node) |node| {
            var stack = try Stack(*Node).init(allocator);
            defer stack.deinit();
            try collectOP(allocator, &stack, node, operator);

            var current = maybe_node;
            if (stack.size >= 2) {
                //Complement law ---> (A & !A) = 0 || (A + !A) = 1
                //Idempotent law ---> (A + A) = A || (A & A) = A
                //Idemportent law ---> (!A + !A) = !A || (!A & !A) = !A
                // std.debug.print("before----------------\n", .{});
                // stack.print();
                // std.debug.print("after----------------\n", .{});
                try applyComplementLaw(allocator, &stack, operator);
                // stack.print();
                // std.debug.print("---------------------\n", .{});
                //Inclusion theorem ---> (A + B) & (A + !B) & (A + B)... (+)&(+)&... = A
                if (CNF and operator == Operator.@"&") {
                    var variableStack = try Stack(*Node).init(allocator);
                    defer variableStack.deinit();
                    try collectOPVariable(&stack, &variableStack);

                    try inclusionTheorem(allocator, &variableStack);
                }

                freeTree(allocator, current.?.left);
                freeTree(allocator, current.?.right);

                while (stack.size > 2) {
                    current.?.left = stack.popFront();
                    current.?.right = try Node.init(Kind{ .operator = operator }, null, null);
                    current = current.?.right;
                }

                if (stack.size == 2) {
                    current.?.left = stack.popFront();
                    current.?.right = stack.popFront();
                } else if (stack.size == 1) {
                    const toFree = stack.popFront();
                    current.?.* = toFree.*;
                    // current.?.kind = toFree.kind;
                    // current.?.left = toFree.left;
                    // current.?.right = toFree.right;

                    allocator.destroy(toFree);
                }
            } else for (0..stack.size) |i| freeTree(allocator, stack.data.items.ptr[i]);

            try flattenAndReorder(allocator, node.left, operator, CNF);
            try flattenAndReorder(allocator, node.right, operator, CNF);
        }
    }

    fn pushNode(node: *Node, stack: *Stack(*Node)) !void {
        const nodeDup = try dup(node);
        if (nodeDup) |newNode| {
            try stack.push(newNode);
        }
    }

    fn collectOP(allocator: *std.mem.Allocator, stack: *Stack(*Node), maybe_node: ?*Node, operator: Operator) !void {
        if (maybe_node) |node| {
            switch (node.kind) {
                .operator => {
                    if (node.kind.operator == operator) {
                        if (node.left) |lhs| try collectOP(allocator, stack, lhs, operator);
                        if (node.right) |rhs| try collectOP(allocator, stack, rhs, operator);
                    } else try pushNode(node, stack);
                },
                else => try pushNode(node, stack),
            }
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

    fn distributeORs(allocator: *std.mem.Allocator, maybe_node: ?*Node) !void {
        if (maybe_node) |node| {
            if (eql(u8, node.kind.toStr(), "OR")) {
                if (node.left == null or node.right == null) return;

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
            try distributeORs(allocator, node.left);
            try distributeORs(allocator, node.right);
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

    fn treeEql(maybe_tree1: ?*Node, maybe_tree2: ?*Node) bool {
        if (maybe_tree1) |T1| {
            if (maybe_tree2) |T2| {
                if (eql(u8, T1.kind.toTagname(), T2.kind.toTagname())) {
                    return treeEql(T1.left, T2.left) and treeEql(T1.right, T2.right);
                } else return false;
            } else return false;
        }
        return true;
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
