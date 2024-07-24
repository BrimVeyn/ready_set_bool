const std = @import("std");
const adder = @import("adder.zig").adder;
const eql = std.mem.eql;
const expect = std.testing.expect;

fn multiplier(a: u32, b: u32) u32 {
    var result: u32 = 0;
    var b_copy: u32 = b;
    const operand: u32 = 1;

    var i: u5 = 0;
    while (b_copy != 0) : (i += 1) {
        if ((b_copy & (operand << i)) > 0) {
            b_copy ^= (operand << i);
            result = adder(result, (a << i));
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
    std.debug.print("{d}", .{@mod(d, 2)});
}

fn debug(a: u32, b: u32, expected: u32, got: u32) void {
    std.debug.print("EXPE : {d} * {d} = {d}\n", .{ a, b, a *% b });
    std.debug.print("binary_a: ", .{});
    toBinary(a);
    std.debug.print(" *\n", .{});
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

test "110 * 10" {
    const a: u32 = 110;
    const b: u32 = 10;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "13 * 16" {
    const a: u32 = 13;
    const b: u32 = 16;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "1 * 1" {
    const a: u32 = 1;
    const b: u32 = 1;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "2000 * 2000" {
    const a: u32 = 2000;
    const b: u32 = 2000;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "2001 * 2001" {
    const a: u32 = 2001;
    const b: u32 = 2001;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "4 * 42" {
    const a: u32 = 4;
    const b: u32 = 41;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "0 * 0" {
    const a: u32 = 0;
    const b: u32 = 0;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "17 * 17" {
    const a: u32 = 17;
    const b: u32 = 17;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "254 * 254" {
    const a: u32 = 254;
    const b: u32 = 254;
    const expected: u32 = a * b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "4_294_967_295 * 1" {
    const a: u32 = 4_294_967_295;
    const b: u32 = 1;
    const expected: u32 = a *% b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "4_294_967_295 * 10" {
    const a: u32 = 4_294_967_295;
    const b: u32 = 10;
    const expected: u32 = a *% b;
    const got: u32 = multiplier(a, b);
    std.debug.print("TEST : {d} * {d} = {d}\n", .{ a, b, got });

    if (expected != got) {
        debug(a, b, expected, got);
    } else {
        std.debug.print("Ok !\n", .{});
    }
}
