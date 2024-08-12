const std = @import("std");
const math = std.math;
const ArrayList = std.ArrayList;

fn setCmp(setA: ArrayList(i32), setB: ArrayList(i32)) i32 {
    if (setA.items.len > setB.items.len) {
        return 1;
    } else if (setA.items.len < setB.items.len) {
        return -1;
    }

    for (0..setA.items.len) |it| {
        if (setA.items.ptr[it] < setB.items.ptr[it])
            return -1;
        if (setA.items.ptr[it] > setB.items.ptr[it])
            return 1;
    }

    return 0;
}

fn sortPowerset(PowerSet: *ArrayList(ArrayList(i32))) !void {
    for (0..PowerSet.items.len) |it| {
        for (0..PowerSet.items.len) |inner_it| {
            if (setCmp(PowerSet.items.ptr[it], PowerSet.items.ptr[inner_it]) < 0) {
                const tmp = PowerSet.items.ptr[it];
                PowerSet.items.ptr[it] = PowerSet.items.ptr[inner_it];
                PowerSet.items.ptr[inner_it] = tmp;
            }
        }
    }
}

fn getPowerset(buffer: *ArrayList(i32), set: ArrayList(i32), PowerSet: *ArrayList(ArrayList(i32)), it: usize) !void {
    if (it == set.items.len) {
        try PowerSet.append(try buffer.clone());
        return;
    }

    try buffer.append(set.items.ptr[it]);
    try getPowerset(buffer, set, PowerSet, it + 1);

    _ = buffer.pop();
    try getPowerset(buffer, set, PowerSet, it + 1);
}

fn powerset(allocator: *std.mem.Allocator, set: ArrayList(i32)) !ArrayList(ArrayList(i32)) {
    var PowerSet = ArrayList(ArrayList(i32)).init(allocator.*);
    var buffer = ArrayList(i32).init(allocator.*);
    defer buffer.deinit();
    try getPowerset(&buffer, set, &PowerSet, 0);
    try sortPowerset(&PowerSet);
    return PowerSet;
}

pub fn PSTest(allocator: *std.mem.Allocator, set: ArrayList(i32)) !void {
    defer set.deinit();
    std.debug.print("Set is {any}\n", .{set.items});
    const result = try powerset(allocator, set);
    defer result.deinit();
    std.debug.print("Powerset :\n", .{});
    for (result.items) |Set| {
        defer Set.deinit();
        std.debug.print("{any}\n", .{Set.items});
    }
    std.debug.print("-----------------------------\n", .{});
}

test "Powerset tests" {
    //From subject tests
    var allocator = std.testing.allocator;

    var vect = ArrayList(i32).init(allocator);
    var slice = [3]i32{ 1, 2, 3 };

    try vect.appendSlice(&slice);
    try PSTest(&allocator, vect);

    var vect2 = ArrayList(i32).init(allocator);
    var slice2 = [4]i32{ 1, 2, 3, 4 };

    try vect2.appendSlice(&slice2);
    try PSTest(&allocator, vect2);

    var vect3 = ArrayList(i32).init(allocator);
    var slice3 = [5]i32{ 1, 3, 3, 4, 5 };

    try vect3.appendSlice(&slice3);
    try PSTest(&allocator, vect3);
}
