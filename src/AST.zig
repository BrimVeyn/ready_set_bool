const std = @import("std");
const formula = @import("eval_formula.zig");
const Operator = formula.Operator;
const Value = formula.Value;
const Stack = @import("Stack.zig").Stack;
const ArrayList = std.ArrayList;

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

const StringStream = struct {
    const Self = @This();
    buffer: ArrayList(u8),
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) StringStream {
        return StringStream{
            .buffer = std.ArrayList(u8).init(allocator.*),
            .allocator = allocator,
        };
    }

    pub fn toStr(self: *Self) ![]const u8 {
        const tmp = try self.buffer.clone();
        const str = self.buffer.toOwnedSlice();
        self.buffer = tmp;
        return str;
    }

    pub fn append(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(str);
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }
};

const BoolAST = struct {
    const Self = @This();
    root: *Node,
    allocator: *std.mem.Allocator,

    pub fn print(self: *Self, allocator: *std.mem.Allocator) !void {
        defer std.testing.allocator.destroy(self.root);
        std.debug.print("{s}", .{self.root.kind.toStr()});

        const pointerRight = "└──";
        const pointerLeft = if (self.root.right != null) "├──" else "└──";
        var ss = StringStream.init(allocator);
        try printAST(self.root.left, &ss, pointerLeft, self.root.right != null);
        try printAST(self.root.right, &ss, pointerRight, false);
        std.debug.print("\n", .{});
        // defer ss.deinit();
    }

    fn printAST(maybe_node: ?*Node, ss: *StringStream, pointer: []const u8, has_rhs: bool) !void {
        if (maybe_node) |node| {
            defer std.testing.allocator.destroy(node);
            const padding = try ss.*.toStr();
            defer std.testing.allocator.free(padding);

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

            try printAST(node.left, &paddingStream, ptr_left, node.right != null);
            try printAST(node.right, &paddingStream, ptr_right, false);
        } else return;
    }

    pub fn generateAST(allocator: *std.mem.Allocator, str: []const u8) !BoolAST {
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
    const str = "11|0&";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.generateAST(&allocator, str);
    try AST.print(&allocator);
    std.debug.print("------------------\n", .{});
}

test "generate ast from string 1" {
    const str = "01&1!0||";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.generateAST(&allocator, str);
    try AST.print(&allocator);
    std.debug.print("------------------\n", .{});
}

test "generate ast from string 2" {
    const str = "01|1!10!&|&01&11!0|=|>";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.generateAST(&allocator, str);
    try AST.print(&allocator);
    std.debug.print("------------------\n", .{});
}

test "generate ast from string 3" {
    const str = "1!0|1011|1&>&11&!&|";
    var allocator = std.testing.allocator;
    var AST = try BoolAST.generateAST(&allocator, str);
    try AST.print(&allocator);
    std.debug.print("------------------\n", .{});
}

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
