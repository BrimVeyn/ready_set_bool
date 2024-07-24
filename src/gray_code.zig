const std = @import("std");

fn gray_code(n: u32) u32 {
    const n_copy: u64 = n;
    const operand: u64 = 1;
    var result: u64 = 0;

    var i: u6 = 32;

    for (0..32) |_| {
        const BitI: bool = ((n_copy & (operand << i)) > 0);
        const BitI1: bool = ((n_copy & (operand << i - 1)) > 0);
        const BothREql: bool = (BitI == BitI1);

        if (!BothREql) {
            result |= (operand << i - 1);
        }

        i -%= 1;
    }
    return @intCast(result);
}

test "gray 0" {
    const num: u32 = 0;
    const expected: u32 = 0;
    const got: u32 = gray_code(num);

    if (expected != got) {
        std.debug.print("Failed /!\\\n{d} --> {d}, got {d}\n", .{ num, expected, got });
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "gray 217837283" {
    const num: u32 = 217837283;
    const expected: u32 = 176560530;
    const got: u32 = gray_code(num);

    if (expected != got) {
        std.debug.print("Failed /!\\\n{d} --> {d}, got {d}\n", .{ num, expected, got });
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "gray 145" {
    const num: u32 = 145;
    const expected: u32 = 217;
    const got: u32 = gray_code(num);

    if (expected != got) {
        std.debug.print("Failed /!\\\n{d} --> {d}, got {d}\n", .{ num, expected, got });
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "gray 4" {
    const num: u32 = 4;
    const expected: u32 = 6;
    const got: u32 = gray_code(num);

    if (expected != got) {
        std.debug.print("Failed /!\\\n{d} --> {d}, got {d}\n", .{ num, expected, got });
    } else {
        std.debug.print("Ok !\n", .{});
    }
}

test "gray 4_294_967_295" {
    const num: u32 = 4_294_967_295;
    const expected: u32 = 2147483648;
    const got: u32 = gray_code(num);

    if (expected != got) {
        std.debug.print("Failed /!\\\n{d} --> {d}, got {d}\n", .{ num, expected, got });
    } else {
        std.debug.print("Ok !\n", .{});
    }
}
