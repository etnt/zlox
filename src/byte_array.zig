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

    /// Print the contents of the array
    pub fn print(self: *const ByteArray) void {
        std.debug.print("[ ", .{});
        for (self.bytes.items) |byte| {
            std.debug.print("{d} ", .{byte});
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

    try array.push(42);
    try std.testing.expectEqual(@as(usize, 1), array.len());
    try std.testing.expectEqual(@as(u8, 42), array.at(0).?);

    try array.push(255);
    try std.testing.expectEqual(@as(usize, 2), array.len());
    try std.testing.expectEqual(@as(u8, 255), array.at(1).?);
}

test "ByteArray - pop bytes" {
    var array = ByteArray.init(std.testing.allocator);
    defer array.deinit();

    try array.push(10);
    try array.push(20);

    const popped1 = array.pop();
    try std.testing.expectEqual(@as(u8, 20), popped1.?);
    try std.testing.expectEqual(@as(usize, 1), array.len());

    const popped2 = array.pop();
    try std.testing.expectEqual(@as(u8, 10), popped2.?);
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

    // Test sequence of pushes
    try array.push(1);
    try array.push(2);
    try array.push(3);
    try std.testing.expectEqual(@as(usize, 3), array.len());

    // Test sequence of pops
    try std.testing.expectEqual(@as(u8, 3), array.pop().?);
    try std.testing.expectEqual(@as(u8, 2), array.pop().?);
    try std.testing.expectEqual(@as(usize, 1), array.len());

    // Push more after pop
    try array.push(4);
    try std.testing.expectEqual(@as(usize, 2), array.len());
    try std.testing.expectEqual(@as(u8, 1), array.at(0).?);
    try std.testing.expectEqual(@as(u8, 4), array.at(1).?);
}
