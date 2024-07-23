const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;

fn adder(a: u32, b: u32) u32 {
    var result: u32 = 0;
    var carry: u32 = 0;
    var i: u5 = 0;
    const operand: u32 = 1;

    while (i < 31) : (i += 1) {
        const AOn: bool = ((a & (operand << i)) > 0);
        const BOn: bool = ((b & (operand << i)) > 0);
        const COn: bool = (carry & (operand << i) > 0);
        const BothROn: bool = (AOn and BOn);
        const OneIsOn: bool = (!AOn and BOn) or (AOn and !BOn);

        if (COn) {
            if (BothROn) {
                result |= (operand << i);
            } else if (OneIsOn) {
                carry |= (operand << (i + 1));
            } else {
                result |= (operand << i);
            }
        }

        if (BothROn) {
            carry |= (operand << (i + 1));
        } else if (OneIsOn and !COn) {
            result |= (operand << (i));
        }
    }
    return result;
}

fn toBinary(d: u32) void {
    var i: u5 = 31;
    const operand: u32 = 1;

    while (i > 0) : (i -= 1) {
        const res: u2 = if ((d & operand << i) > 0) 1 else 0;
        std.debug.print("{d}", .{res});
    }
}

fn debug(a: u32, b: u32, expected: u32, got: u32) void {
    std.debug.print("binary_a: ", .{});
    toBinary(a);
    std.debug.print(" +\n", .{});
    std.debug.print("binary_b: ", .{});
    toBinary(b);
    std.debug.print(" =\n", .{});
    std.debug.print("expected: ", .{});
    toBinary(expected);
    std.debug.print("\n", .{});
    std.debug.print("got:      ", .{});
    toBinary(got);
    std.debug.print("\n", .{});
}

pub fn main() !void {
    std.debug.print("Run zig test main.zig\n", .{});
}

test "257 + 256" {
    const a: u32 = 257;
    const b: u32 = 256;
    const expected: u32 = 513;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "110 + 10" {
    const a: u32 = 110;
    const b: u32 = 10;
    const expected: u32 = 120;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "2000 + 2000" {
    const a: u32 = 2000;
    const b: u32 = 2000;
    const expected: u32 = 4000;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "2001 + 2001" {
    const a: u32 = 2001;
    const b: u32 = 2001;
    const expected: u32 = 4002;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "4_294_967_295 + 1" {
    const a: u32 = 4_294_967_295;
    const b: u32 = 50;
    const expected: u32 = 49;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "4 + 42" {
    const a: u32 = 4;
    const b: u32 = 41;
    const expected: u32 = 45;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "0 + 0" {
    const a: u32 = 0;
    const b: u32 = 0;
    const expected: u32 = 0;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "17 + 17" {
    const a: u32 = 17;
    const b: u32 = 17;
    const expected: u32 = 34;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "254 + 254" {
    const a: u32 = 254;
    const b: u32 = 254;
    const expected: u32 = 508;
    const got: u32 = adder(a, b);
    std.debug.print("TEST : {d} + {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}
