const std = @import("std");

/// Value represents a constant value in our bytecode
/// For now, we'll start with just numbers, but this can be extended
/// to support other types like strings, booleans, etc.
pub const Value = f64;

/// ValueArray provides a dynamic array implementation for constant values
pub const ValueArray = struct {
    values: std.ArrayList(Value),

    /// Initialize a new ValueArray with the given allocator
    pub fn init(allocator: std.mem.Allocator) ValueArray {
        return ValueArray{
            .values = std.ArrayList(Value).init(allocator),
        };
    }

    /// Free the memory used by the ValueArray
    pub fn deinit(self: *ValueArray) void {
        self.values.deinit();
    }

    /// Add a value to the array and return its index
    pub fn add(self: *ValueArray, value: Value) !usize {
        const index = self.values.items.len;
        try self.values.append(value);
        return index;
    }

    /// Get a value at a specific index
    pub fn at(self: *const ValueArray, index: usize) ?Value {
        if (index >= self.values.items.len) return null;
        return self.values.items[index];
    }

    /// Get the current length of the array
    pub fn len(self: *const ValueArray) usize {
        return self.values.items.len;
    }

    /// Print the contents of the array
    pub fn print(self: *const ValueArray) void {
        std.debug.print("[ ", .{});
        for (self.values.items) |value| {
            std.debug.print("{d} ", .{value});
        }
        std.debug.print("]\n", .{});
    }
};

test "ValueArray - basic operations" {
    var array = ValueArray.init(std.testing.allocator);
    defer array.deinit();

    // Test adding values
    const idx1 = try array.add(1.5);
    const idx2 = try array.add(2.7);
    try std.testing.expectEqual(@as(usize, 0), idx1);
    try std.testing.expectEqual(@as(usize, 1), idx2);

    // Test retrieving values
    try std.testing.expectEqual(@as(Value, 1.5), array.at(0).?);
    try std.testing.expectEqual(@as(Value, 2.7), array.at(1).?);
    try std.testing.expectEqual(@as(?Value, null), array.at(2));

    // Test length
    try std.testing.expectEqual(@as(usize, 2), array.len());
}
