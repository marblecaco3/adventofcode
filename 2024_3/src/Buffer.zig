const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.io.AnyReader;
const Buffer = @This();
const assert = std.debug.assert;

allocator: Allocator,
buffer: []u8,
r: usize = 0,
w: usize = 0,

pub fn initCapacity(allocator: Allocator, size: usize) Allocator.Error!Buffer {
    return .{ .buffer = try allocator.alloc(u8, size), .allocator = allocator };
}
pub fn read_more(self: *Buffer, reader: *Reader) !usize {
    const n = try reader.read(self.buffer[self.w..]);
    self.w += n;
    return n;
}
pub fn discard_buffer(self: *Buffer) void {
    self.r = 0;
    self.w = 0;
}
pub fn backshift(self: *Buffer) void {
    std.mem.copyForwards(u8, self.buffer, self.buffer[self.r..self.w]);
    self.r = 0;
    self.w -= self.r;
}
pub fn fill_buf(self: *Buffer, reader: *Reader) ![]u8 {
    if (self.r >= self.w) {
        const n = try reader.read(self.buffer[0..]);
        self.r = 0;
        self.w = n;
        if (n == 0) return error.eof;
    }
    return self.buffer[self.r..self.w];
}
pub fn consume(self: *Buffer, n: usize) void {
    self.r = @min(self.r + n, self.w);
}
pub fn unconsume(self: *Buffer, n: usize) void {
    self.r -= @min(n, self.r);
}
pub fn capacity(self: Buffer) usize {
    return self.buffer.len;
}
pub fn buffered(self: Buffer) []u8 {
    return self.buffer[self.r..self.w];
}
pub fn pos(self: Buffer) usize {
    return self.r;
}
pub fn filled(self: Buffer) usize {
    return self.w;
}
pub fn deinit(self: *Buffer) void {
    self.allocator.free(self.buffer);
    self.* = undefined;
}
