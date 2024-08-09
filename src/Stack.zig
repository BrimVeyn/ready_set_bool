const std = @import("std");
const ArrayList = std.ArrayList;
const color = @import("Colors.zig").ansi;
const ParsingError = @import("eval_formula.zig").ParsingError;

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        data: ArrayList(T),
        size: usize = 0,

        pub fn init(allocator: *std.mem.Allocator) !Self {
            return Self{
                .data = ArrayList(T).init(allocator.*),
                .size = 0,
            };
        }

        pub fn push(self: *Self, item: T) !void {
            try self.data.append(item);
            self.size += 1;
        }

        pub fn pop(self: *Self) T {
            self.size -= 1;
            return self.data.pop();
        }

        pub fn popFront(self: *Self) T {
            self.size -= 1;
            return self.data.orderedRemove(0);
        }

        pub fn popIndex(self: *Self, index: usize) T {
            self.size -= 1;
            return self.data.orderedRemove(index);
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn print(self: *Self) void {
            var len = self.data.items.len;
            while (len > 0) {
                std.debug.print("{s}stack[{d}] = {any}{s}\n", .{ color.magenta, len - 1, self.data.items[len - 1], color.reset });
                len -%= 1;
            }
        }
    };
}
