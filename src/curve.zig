const std = @import("std");
const Array = std.ArrayList;
const math = std.math;

fn Matrix(comptime T: type) type {
    return struct {
        data: [][]T,
        size: usize,
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator, size: usize) !Matrix(T) {
            const rowSlice = try allocator.alloc([]T, size);

            for (rowSlice) |*colSlice| {
                const colSliceAlloc = try allocator.alloc(T, size);
                colSlice.* = colSliceAlloc;
            }

            return .{
                .data = rowSlice,
                .size = size,
                .allocator = allocator,
            };
        }

        pub fn sym45(self: *Matrix(T)) !Matrix(T) {
            const selfSym45 = try Matrix(T).init(self.allocator, self.size);
            for (0..self.size) |x| {
                for (0..self.size) |y| {
                    selfSym45.data[x][y] = self.data[y][x];
                }
            }
            return selfSym45;
        }

        pub fn sym135(self: *Matrix(T)) !Matrix(T) {
            const selfSym45 = try Matrix(T).init(self.allocator, self.size);
            for (0..self.size) |x| {
                for (0..self.size) |y| {
                    selfSym45.data[y][x] = self.data[self.size - x - 1][self.size - y - 1];
                }
            }
            return selfSym45;
        }

        pub fn print(self: *Matrix(T)) void {
            const size = self.size;
            for (0..self.size) |i| {
                std.debug.print("{d} | {any}\n", .{ size - i - 1, self.data[size - i - 1] });
            }
        }

        pub fn deinit(self: *Matrix(T)) void {
            for (0..self.size) |i| {
                self.allocator.free(self.data[i]);
            }
            self.allocator.free(self.data);
        }
    };
}

fn recHilbert(allocator: *std.mem.Allocator, current_order: u16, target_order: u16, hn: *Matrix(u32)) !void {
    if (current_order == target_order) {
        return;
    }

    const hn_size = hn.size;
    const hnp1_size = hn_size * 2;

    var hnSym45 = try hn.sym45();
    defer hnSym45.deinit();
    // hnSym45.print();

    var hnSym135 = try hn.sym135();
    defer hnSym135.deinit();
    // hnSym135.print();

    std.debug.print("hnp1_size: {d}\n", .{hnp1_size});

    var hnp1 = try Matrix(u32).init(allocator, hnp1_size);
    for (0..hnp1_size / 2) |i| {
        for (0..hnp1_size / 2) |j| {
            hnp1.data[i][j] = hnSym45.data[i][j];
            //rotate 45 /
        }
        for (hnp1_size / 2..hnp1_size) |j| {
            const offset_size: u32 = @intCast(math.pow(usize, hn_size, 2) * 3);
            const offset_y: u32 = @intCast(hn_size);
            hnp1.data[i][j] = hnSym135.data[i][j - offset_y] + offset_size;
            //rotate 45 \
        }
    }
    for (hnp1_size / 2..hnp1_size) |i| {
        for (0..hnp1_size / 2) |j| {
            const offset_size: u32 = @intCast(math.pow(usize, hn_size, 2));
            const offset_x: u32 = @intCast(hn_size);
            hnp1.data[i][j] = hn.data[i - offset_x][j] + offset_size;
        }
        for (hnp1_size / 2..hnp1_size) |j| {
            const offset_size: u32 = @intCast(math.pow(usize, hn_size, 2) * 2);
            const offset_y: u32 = @intCast(hn_size);
            const offset_x: u32 = offset_y;
            hnp1.data[i][j] = hn.data[i - offset_x][j - offset_y] + offset_size;
        }
    }
    hn.deinit();
    hn.* = hnp1;
    // hn.print();
    std.debug.print("---------------\n", .{});
    try recHilbert(allocator, current_order + 1, target_order, hn);
}

fn genHilbert(allocator: *std.mem.Allocator, order: u16) !Matrix(u32) {
    var h1 = try Matrix(u32).init(allocator, 2);
    h1.data[0][0] = 0;
    h1.data[0][1] = 3;
    h1.data[1][0] = 1;
    h1.data[1][1] = 2;
    h1.print();

    try recHilbert(allocator, 0, order - 1, &h1);

    return h1;
}

fn map(x: u16, y: u16) f64 {
    const xf: f64 = @floatFromInt(x);
    const yf: f64 = @floatFromInt(y);
    return (xf * 65536 + yf) / 4294967296;
}

fn reverse_map(t: f64) @Vector(2, u16) {
    const x = @as(u32, @intFromFloat((t * 4294967296) / 65536));
    const y = @as(u32, @mod(@as(u32, @intFromFloat(t * 4294967296)), 65536));
    return @Vector(2, u16){ @intCast(x), @intCast(y) };
}

test "Curve mapping" {
    const a = 12531;
    const b = 1890;
    const r1 = map(a, b);
    const r2 = reverse_map(map(a, b));
    const r3 = map(reverse_map(map(a, b))[0], reverse_map(map(a, b))[1]);
    std.debug.print("{d}\n", .{r1});
    std.debug.print("{d}\n", .{r2});
    std.debug.print("{d}\n", .{r3});

    // var allocator = std.testing.allocator;
    // const order = 2; //4 ^ 8 = 65536;
    // var hilbertCurve = try genHilbert(&allocator, order);
    // hilbertCurve.print();
    // defer hilbertCurve.deinit();
}
