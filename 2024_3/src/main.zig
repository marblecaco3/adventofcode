const std = @import("std");
const BufferReader = @import("./BufferReader.zig");

const NumStr = struct { start: usize, end: usize };

const State = enum {
    mul,
    l_bracket,
    r_bracket,
    comma,
    lhs,
    rhs,
    donot,
    do,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const result = try solve(allocator, "input.txt");
    std.debug.print("result {d}\n", .{result});
}

fn solve(allocator: std.mem.Allocator, filename: []const u8) !isize {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    var formula = try BufferReader.init(allocator, file.reader().any());
    defer formula.deinit();

    var state: State = .r_bracket;
    var num_list = std.ArrayList(isize).init(allocator);
    defer num_list.deinit();
    while (formula.readByte()) |c| {
        switch (state) {
            .r_bracket, .do => {
                if (c == 'm') {
                    const s = try formula.peek(2);
                    if (std.mem.eql(u8, s, "ul")) {
                        formula.consume(2);
                        state = .mul;
                    }
                } else if (c == 'd') {
                    const s = try formula.peek(6);
                    if (std.mem.eql(u8, s, "on't()")) {
                        formula.consume(6);
                        state = .donot;
                    }
                }
            },
            .donot => {
                if (c == 'd') {
                    const s = try formula.peek(3);
                    if (std.mem.eql(u8, s, "o()")) {
                        formula.consume(3);
                        state = .do;
                    }
                }
            },
            .mul => {
                if (c == '(') {
                    state = .l_bracket;
                } else {
                    state = .r_bracket;
                }
            },
            .l_bracket => {
                formula.unconsume(1);
                if (readInt(&formula)) |num| {
                    try num_list.append(num);
                    state = .lhs;
                } else |err| {
                    std.debug.print("err {}\n", .{err});
                    state = .r_bracket;
                }
            },
            .lhs => {
                if (c == ',') {
                    state = .comma;
                } else {
                    _ = num_list.pop();
                    state = .r_bracket;
                }
            },
            .comma => {
                formula.unconsume(1);
                if (readInt(&formula)) |num| {
                    try num_list.append(num);
                    state = .rhs;
                } else |err| {
                    std.debug.print("err {}\n", .{err});
                    _ = num_list.pop();
                    state = .r_bracket;
                }
            },
            .rhs => {
                if (c == ')') {
                    state = .r_bracket;
                } else {
                    _ = num_list.pop();
                    _ = num_list.pop();
                    state = .r_bracket;
                }
            },
        }
    } else |err| {
        if (err == error.eof) {} else {
            std.debug.print("readByte err {}\n", .{err});
        }
    }
    var res: isize = 0;
    while (num_list.items.len > 0) {
        const lhs: isize = @intCast(num_list.pop());
        const rhs: isize = @intCast(num_list.pop());
        res += lhs * rhs;
    }
    return res;
}

const testing = std.testing;

test solve {
    try testing.expectEqual(48, try solve(testing.allocator, "test.txt"));
}

fn readInt(reader: *BufferReader) !isize {
    var buf: [1000]u8 = undefined;
    var idx: usize = 0;
    while (reader.readByte()) |c| {
        if (std.ascii.isDigit(c)) {
            buf[idx] = c;
            idx += 1;
        } else {
            reader.unconsume(1);
            break;
        }
    } else |err| {
        return err;
    }
    return std.fmt.parseInt(isize, buf[0..idx], 10);
}
