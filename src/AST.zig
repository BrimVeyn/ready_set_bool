const std = @import("std");
const formula = @import("eval_formula.zig");
const Operator = formula.Operator;
const Value = formula.Value;
const Stack = @import("Stack.zig").Stack;

const Variable = struct {};

const Kind = union(enum) {
    const Self = @This();

    operator: Operator,
    value: Value,
    variable: Variable,

    pub fn toStr(self: Self) []const u8 {
        return switch (self) {
            .value => return switch (self.value) {
                Value.@"0" => "F",
                Value.@"1" => "T",
            },
            .operator => return switch (self.operator) {
                Operator.@"!" => "NOT",
                Operator.@"&" => "AND",
                Operator.@"^" => "XOR",
                Operator.@"|" => "OR",
                Operator.@">" => "IMP",
                Operator.@"=" => "EQL",
            },
            else => return "",
        };
    }
};

const Node = struct {
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
};

const BoolAST = struct {
    const Self = @This();
    root: *Node,

    pub fn print(self: Self) void {
        printAST(self.root, 0);
    }

    fn padd(indent: usize) void {
        for (0..indent) |_| {
            std.debug.print(" ", .{});
        }
    }

    fn printAST(maybe_node: ?*Node, indent: usize) void {
        if (maybe_node) |node| {
            defer std.testing.allocator.destroy(node);
            if (indent != 0) {
                padd(indent - 4);
                std.debug.print("└──", .{});
            }
            std.debug.print("{s}\n", .{node.kind.toStr()});
            if (node.left) |lhs| {
                printAST(lhs, indent + 4);
            }
            if (node.right) |rhs| {
                printAST(rhs, indent + 4);
            }
        } else return;
    }

    pub fn generateAST(str: []const u8) !BoolAST {
        const rootNode = try genAST(str);
        return BoolAST{
            .root = rootNode,
        };
    }

    fn genAST(rpn: []const u8) !*Node {
        var stack = try Stack(*Node).init(std.testing.allocator);
        defer stack.deinit();

        for (rpn) |token| {
            if (Value.getValue(token)) |value| {
                const node = try Node.init(Kind{ .value = value }, null, null);
                try stack.push(node);
            } else if (Operator.getOp(token)) |operator| {
                if (operator == Operator.@"!") {
                    const left = stack.pop();
                    const node = try Node.init(Kind{ .operator = operator }, left, null);
                    try stack.push(node);
                } else {
                    const left = stack.pop();
                    const right = stack.pop();
                    const node = try Node.init(Kind{ .operator = operator }, left, right);
                    try stack.push(node);
                }
            }
        }
        return stack.pop();
    }
};

test "generate ast from string" {
    const str = "01&1!0||";
    const AST = try BoolAST.generateAST(str);
    AST.print();
}

// test "generate ast from string 2" {
//     const str = "01|1!10!&|&01&11!0|=|>";
//     const AST = try BoolAST.generateAST(str);
//     AST.print();
// }

// test "by hand ast" {
//     var n1 = Node{
//         .kind = Kind{
//             .operator = Operator.@"!",
//         },
//     };
//
//     var n2 = Node{
//         .kind = Kind{
//             .value = Value.@"0",
//         },
//     };
//
//     var n3 = Node{
//         .kind = Kind{
//             .value = Value.@"1",
//         },
//     };
//
//     var n4 = Node{
//         .kind = Kind{
//             .operator = Operator.@"|",
//         },
//     };
//
//     const ast = BoolAST{
//         .root = &n1,
//     };
//
//     n4.left = &n2;
//     n4.right = &n3;
//     ast.root.left = &n4;
//
//     ast.print();
// }
