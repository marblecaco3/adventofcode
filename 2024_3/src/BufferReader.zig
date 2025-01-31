const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.io.AnyReader;
const BufferReader = @This();
const Buffer = @import("./Buffer.zig");
const DEFAULT_BUFFER_SIZE: usize = 4096;
const assert = std.debug.assert;

unbuffered_reader: Reader,
buffer: Buffer,

pub fn init(allocator: Allocator, reader: Reader) Allocator.Error!BufferReader {
    return .{
        .buffer = try Buffer.initCapacity(allocator, DEFAULT_BUFFER_SIZE),
        .unbuffered_reader = reader,
    };
}

pub fn initCapacity(allocator: Allocator, reader: Reader, size: usize) Allocator.Error!BufferReader {
    return .{
        .buffer = try Buffer.initCapacity(allocator, size),
        .unbuffered_reader = reader,
    };
}

pub fn deinit(self: *BufferReader) void {
    self.buffer.deinit();
    self.* = undefined;
}
pub fn consume(self: *BufferReader, n: usize) void {
    self.buffer.consume(n);
}

pub fn peek(self: *BufferReader, n: usize) ![]u8 {
    assert(n <= self.capacity());
    while (n > self.buffer.buffered().len) {
        if (self.buffer.pos() > 0) {
            self.buffer.backshift();
        }
        const new = try self.buffer.read_more(&self.unbuffered_reader);
        if (new == 0) {
            return self.buffer.buffered()[0..];
        }
    }
    return self.buffer.buffered()[0..n];
}
pub fn unconsume(self: *BufferReader, n: usize) void {
    self.buffer.unconsume(n);
}

pub fn capacity(self: BufferReader) usize {
    return self.buffer.capacity();
}
pub fn read(self: *BufferReader, buf: []u8) !usize {
    if (self.buffered().len == 0 and buf.len >= self.capacity()) {
        self.discard_buffer();
        return self.unbuffered_reader.read(buf);
    }
    const rem = try self.buffer.fill_buf(&self.unbuffered_reader);
    const n = @min(buf.len, rem.len);
    std.mem.copyForwards(u8, buf, rem[0..n]);
    self.consume(1);
    return n;
}
pub fn discard_buffer(self: *BufferReader) void {
    self.buffer.discard_buffer();
}
pub fn readByte(self: *BufferReader) !u8 {
    const rem = try self.buffer.fill_buf(&self.unbuffered_reader);
    const c = rem[0];
    self.consume(1);
    return c;
}

const testing = std.testing;

test "one byte" {
    const OneByteReader = struct {
        str: []const u8,
        curr: usize = 0,
        const Error = error{NoError};
        const OneByteReader = @This();
        const Reader = std.io.Reader(*OneByteReader, Error, @This().read);
        pub fn init(str: []const u8) OneByteReader {
            return .{ .str = str };
        }
        pub fn read(self: *OneByteReader, buf: []u8) Error!usize {
            if (self.str.len <= self.curr or buf.len == 0)
                return 0;

            buf[0] = self.str[self.curr];
            self.curr += 1;
            return 1;
        }

        pub fn reader(self: *OneByteReader) @This().Reader {
            return .{ .context = self };
        }
    };
    const str = "This is a test";
    var one_byte_stream = OneByteReader.init(str);
    var buf_reader = try BufferReader.init(testing.allocator, one_byte_stream.reader().any());
    defer buf_reader.deinit();

    const res = try buf_reader.peek(str.len + 1);
    try testing.expectEqualSlices(u8, str, res);
}
