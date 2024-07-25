const std = @import("std");
const formula = @import("eval_formula.zig");
const Operator = formula.Operator;
const Value = formula.Value;

const Variable = struct {};

const Kind = union(enum) {
    const Self = @This();

    operator: Operator,
    value: Value,
    variable: Variable,

    pub fn toStr(self: Self) []const u8 {
        switch (self) {
            self.value => return switch (self.value) {
                Value.@"0" => "F",
                Value.@"1" => "T",
                else => "PD",
            },
        }
    }
};

const Node = struct {
    kind: Kind,
    left: ?*Node = null,
    right: ?*Node = null,
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
};

test "generate ast from string" {
    const str = "10";
    _ = str; // autofix
}

test "by hand ast" {
    var n1 = Node{
        .kind = Kind{
            .operator = Operator.@"|",
        },
    };

    var n2 = Node{
        .kind = Kind{
            .value = Value.@"0",
        },
    };

    var n3 = Node{
        .kind = Kind{
            .value = Value.@"1",
        },
    };

    var n4 = Node{
        .kind = Kind{
            .operator = Operator.@"|",
        },
    };

    const ast = BoolAST{
        .root = &n1,
    };

    n4.left = &n2;
    n4.right = &n3;
    ast.root.left = &n4;

    ast.print();
}
