const std = @import("std");

/// U32Array provides a dynamic array implementation for u32 values
pub const U32Array = struct {
    values: std.ArrayList(u32),

    /// Initialize a new U32Array with the given allocator
    pub fn init(allocator: std.mem.Allocator) U32Array {
        return U32Array{
            .values = std.ArrayList(u32).init(allocator),
        };
    }

    /// Free the memory used by the U32Array
    pub fn deinit(self: *U32Array) void {
        self.values.deinit();
    }

    /// Push a value onto the array
    pub fn push(self: *U32Array, value: u32) !void {
        try self.values.append(value);
    }

    /// Pop a value from the array, returns null if empty
    pub fn pop(self: *U32Array) ?u32 {
        if (self.values.items.len == 0) return null;
        return self.values.pop();
    }

    /// Get the current length of the array
    pub fn len(self: *const U32Array) usize {
        return self.values.items.len;
    }

    /// Get a value at a specific index
    pub fn at(self: *const U32Array, index: usize) ?u32 {
        if (index >= self.values.items.len) return null;
        return self.values.items[index];
    }
};

test "U32Array - push values" {
    var array = U32Array.init(std.testing.allocator);
    defer array.deinit();

    try array.push(42);
    try std.testing.expectEqual(@as(usize, 1), array.len());
    try std.testing.expectEqual(@as(u32, 42), array.at(0).?);

    try array.push(65535);
    try std.testing.expectEqual(@as(usize, 2), array.len());
    try std.testing.expectEqual(@as(u32, 65535), array.at(1).?);
}

test "U32Array - pop values" {
    var array = U32Array.init(std.testing.allocator);
    defer array.deinit();

    try array.push(1000);
    try array.push(2000);

    const popped1 = array.pop();
    try std.testing.expectEqual(@as(u32, 2000), popped1.?);
    try std.testing.expectEqual(@as(usize, 1), array.len());

    const popped2 = array.pop();
    try std.testing.expectEqual(@as(u32, 1000), popped2.?);
    try std.testing.expectEqual(@as(usize, 0), array.len());
}

test "U32Array - pop empty array" {
    var array = U32Array.init(std.testing.allocator);
    defer array.deinit();

    const popped = array.pop();
    try std.testing.expectEqual(@as(?u32, null), popped);
}

test "U32Array - multiple operations" {
    var array = U32Array.init(std.testing.allocator);
    defer array.deinit();

    try array.push(100);
    try array.push(200);
    try array.push(300);
    try std.testing.expectEqual(@as(usize, 3), array.len());

    try std.testing.expectEqual(@as(u32, 300), array.pop().?);
    try std.testing.expectEqual(@as(u32, 200), array.pop().?);
    try std.testing.expectEqual(@as(usize, 1), array.len());

    try array.push(400);
    try std.testing.expectEqual(@as(usize, 2), array.len());
    try std.testing.expectEqual(@as(u32, 100), array.at(0).?);
    try std.testing.expectEqual(@as(u32, 400), array.at(1).?);
}
