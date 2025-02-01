const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Reader = std.io.AnyReader;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const result = try solve(allocator, "input.txt");
    std.debug.print("result:{d}\n", .{result});
}
pub fn solve(allocator: std.mem.Allocator, filename: []const u8) !usize {
    //读取文件
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    var m = try Monitor.init(allocator, file.reader().any());
    defer m.deinit();
    // return m.search1();
    return m.search2();
}

const Direction = enum {
    up,
    up_right,
    right,
    down_right,
    down,
    down_left,
    left,
    up_left,
};

const Point = struct {
    r: usize,
    c: usize,
    max_r: usize,
    max_c: usize,

    fn move_row(p: *Point, incre: bool) !void {
        if ((incre and (p.r + 1) >= p.max_r) or (!incre and p.r == 0)) {
            return error.out_of_range;
        }
        if (incre) p.r += 1 else p.r -= 1;
    }
    fn move_col(p: *Point, incre: bool) !void {
        if ((incre and (p.c + 1) >= p.max_c) or (!incre and p.c == 0)) {
            return error.out_of_range;
        }

        if (incre) p.c += 1 else p.c -= 1;
    }

    pub fn move_to(p: *Point, d: Direction) !void {
        switch (d) {
            .up => {
                try p.move_row(false);
            },
            .down => {
                try p.move_row(true);
            },
            .up_right => {
                try p.move_row(false);
                try p.move_col(true);
            },
            .right => {
                try p.move_col(true);
            },
            .down_right => {
                try p.move_row(true);
                try p.move_col(true);
            },
            .down_left => {
                try p.move_row(true);
                try p.move_col(false);
            },
            .left => {
                try p.move_col(false);
            },
            .up_left => {
                try p.move_row(false);
                try p.move_col(false);
            },
        }
    }
    pub fn move(p: Point, d: Direction) !Point {
        var po = p.clone();
        try po.move_to(d);
        return po;
    }
    pub fn clone(p: Point) Point {
        return .{
            .r = p.r,
            .c = p.c,
            .max_r = p.max_r,
            .max_c = p.max_c,
        };
    }
};

const STR: []const u8 = "XMAS";
const STR2: []const u8 = "MAS";

const Monitor = struct {
    buffer: [][]u8,
    allocator: Allocator,
    height: usize,
    width: usize,
    pub fn debug_display(m: Monitor) void {
        std.debug.print("height:{} width:{}\n", .{ m.height, m.width });
        for (m.buffer) |line| {
            std.debug.print("{s}\n", .{line});
        }
    }
    pub fn init(allocator: Allocator, reader: Reader) !Monitor {
        var rows = std.ArrayList([]u8).init(allocator);
        while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 255)) |line| {
            try rows.append(line);
        }
        const buffer = try rows.toOwnedSlice();
        const height = buffer.len;
        const width = buffer[0].len;
        return .{
            .buffer = buffer,
            .allocator = allocator,
            .height = height,
            .width = width,
        };
    }
    pub fn deinit(m: *Monitor) void {
        for (0..m.height) |i| {
            m.allocator.free(m.buffer[i]);
        }
        m.allocator.free(m.buffer);
        m.* = undefined;
    }
    pub fn char(m: Monitor, p: Point) u8 {
        return m.buffer[p.r][p.c];
    }
    pub fn text_check(m: Monitor, p: Point, d: Direction, target: []const u8) bool {
        var po = p;
        for (0..target.len) |i| {
            if (target[i] != m.char(po)) return false;
            if (i == target.len - 1) return true;
            po.move_to(d) catch return false;
        }
        return true;
    }
    pub fn point(m: Monitor, row: usize, col: usize) Point {
        return .{
            .r = row,
            .c = col,
            .max_r = m.height,
            .max_c = m.width,
        };
    }
    pub fn search1(m: *Monitor) usize {
        var number: usize = 0;
        for (0..m.height) |i| {
            for (0..m.width) |j| {
                const p = m.point(i, j);
                if (m.char(p) != STR[0]) continue;
                for (0..8) |d_int| {
                    if (m.text_check(p, @enumFromInt(d_int), STR)) {
                        number += 1;
                    }
                }
            }
        }
        return number;
    }
    pub fn search2(m: *Monitor) usize {
        var number: usize = 0;
        for (0..m.height) |i| {
            for (0..m.width) |j| {
                const p = m.point(i, j);
                if (m.char(p) != STR2[1]) continue;
                if (!m.text_check(p.move(.up_left) catch continue, .down_right, STR2) and !m.text_check(p.move(.down_right) catch continue, .up_left, STR2)) continue;
                if (m.text_check(p.move(.up_right) catch continue, .down_left, STR2) or m.text_check(p.move(.down_left) catch continue, .up_right, STR2)) number += 1;
            }
        }
        return number;
    }
};

const testing = std.testing;

test solve {
    // try testing.expectEqual(18, try solve(testing.allocator, "test.txt"));
    try testing.expectEqual(9, try solve(testing.allocator, "test.txt"));
}
