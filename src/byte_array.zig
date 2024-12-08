const std = @import("std");

/// ByteArray provides a dynamic array implementation for bytes
pub const ByteArray = struct {
    bytes: std.ArrayList(u8),

    /// Initialize a new ByteArray with the given allocator
    pub fn init(allocator: std.mem.Allocator) ByteArray {
        return ByteArray{
            .bytes = std.ArrayList(u8).init(allocator),
        };
    }

    /// Free the memory used by the ByteArray
    pub fn deinit(self: *ByteArray) void {
        self.bytes.deinit();
    }

    /// Push a byte onto the array
    pub fn push(self: *ByteArray, value: u8) !void {
        try self.bytes.append(value);
    }

    /// Pop a byte from the array, returns null if empty
    pub fn pop(self: *ByteArray) ?u8 {
        if (self.bytes.items.len == 0) return null;
        return self.bytes.pop();
    }

    /// Print the contents of the array in hexadecimal format
    pub fn print(self: *const ByteArray) void {
        std.debug.print("[ ", .{});
        for (self.bytes.items) |byte| {
            std.debug.print("0x{X:0>2} ", .{byte});
        }
        std.debug.print("]\n", .{});
    }

    /// Print the contents of the array with opcode names
    pub fn printOpcodes(self: *const ByteArray, getOpcodeName: fn(u8) []const u8) void {
        std.debug.print("[\n", .{});
        for (self.bytes.items) |byte| {
            const name = getOpcodeName(byte);
            std.debug.print("  0x{X:0>2} ({s})\n", .{byte, name});
        }
        std.debug.print("]\n", .{});
    }

    /// Get the current length of the array
    pub fn len(self: *const ByteArray) usize {
        return self.bytes.items.len;
    }

    /// Get a byte at a specific index
    pub fn at(self: *const ByteArray, index: usize) ?u8 {
        if (index >= self.bytes.items.len) return null;
        return self.bytes.items[index];
    }
};

test "ByteArray - push bytes" {
    var array = ByteArray.init(std.testing.allocator);
    defer array.deinit();

    try array.push(0x42);
    try std.testing.expectEqual(@as(usize, 1), array.len());
    try std.testing.expectEqual(@as(u8, 0x42), array.at(0).?);

    try array.push(0xFF);
    try std.testing.expectEqual(@as(usize, 2), array.len());
    try std.testing.expectEqual(@as(u8, 0xFF), array.at(1).?);
}

test "ByteArray - pop bytes" {
    var array = ByteArray.init(std.testing.allocator);
    defer array.deinit();

    try array.push(0x10);
    try array.push(0x20);

    const popped1 = array.pop();
    try std.testing.expectEqual(@as(u8, 0x20), popped1.?);
    try std.testing.expectEqual(@as(usize, 1), array.len());

    const popped2 = array.pop();
    try std.testing.expectEqual(@as(u8, 0x10), popped2.?);
    try std.testing.expectEqual(@as(usize, 0), array.len());
}

test "ByteArray - pop empty array" {
    var array = ByteArray.init(std.testing.allocator);
    defer array.deinit();

    const popped = array.pop();
    try std.testing.expectEqual(@as(?u8, null), popped);
}

test "ByteArray - multiple operations" {
    var array = ByteArray.init(std.testing.allocator);
    defer array.deinit();

    try array.push(0x01);
    try array.push(0x02);
    try array.push(0x03);
    try std.testing.expectEqual(@as(usize, 3), array.len());

    try std.testing.expectEqual(@as(u8, 0x03), array.pop().?);
    try std.testing.expectEqual(@as(u8, 0x02), array.pop().?);
    try std.testing.expectEqual(@as(usize, 1), array.len());

    try array.push(0x04);
    try std.testing.expectEqual(@as(usize, 2), array.len());
    try std.testing.expectEqual(@as(u8, 0x01), array.at(0).?);
    try std.testing.expectEqual(@as(u8, 0x04), array.at(1).?);
}
