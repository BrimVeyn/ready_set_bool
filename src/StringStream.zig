const std = @import("std");
const ArrayList = std.ArrayList;

pub const StringStream = struct {
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

    pub fn appendChar(self: *Self, c: u8) !void {
        try self.buffer.append(c);
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }
};
