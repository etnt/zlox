const std = @import("std");

/// ValueType represents the different types of values our VM can handle
pub const ValueType = enum {
    number,
    boolean,
};

/// Value represents a constant value in our bytecode
pub const Value = union(ValueType) {
    number: f64,
    boolean: bool,

    /// Print a value
    pub fn print(self: Value) void {
        switch (self) {
            .number => |n| std.debug.print("{d}", .{n}),
            .boolean => |b| std.debug.print("{}", .{b}),
        }
    }

    /// Create a number value
    pub fn number(n: f64) Value {
        return Value{ .number = n };
    }

    /// Create a boolean value
    pub fn boolean(b: bool) Value {
        return Value{ .boolean = b };
    }

    /// Add two values
    pub fn add(a: Value, b: Value) ?Value {
        if (a == .number and b == .number) {
            return Value.number(a.number + b.number);
        }
        return null;
    }

    /// Subtract two values
    pub fn sub(a: Value, b: Value) ?Value {
        if (a == .number and b == .number) {
            return Value.number(a.number - b.number);
        }
        return null;
    }

    /// Multiply two values
    pub fn mul(a: Value, b: Value) ?Value {
        if (a == .number and b == .number) {
            return Value.number(a.number * b.number);
        }
        return null;
    }

    /// Divide two values
    pub fn div(a: Value, b: Value) ?Value {
        if (a == .number and b == .number) {
            return Value.number(a.number / b.number);
        }
        return null;
    }

    /// Negate a value
    pub fn negate(self: Value) ?Value {
        return switch (self) {
            .number => |n| Value.number(-n),
            .boolean => null,
        };
    }

    /// Logical AND operation
    pub fn logicalAnd(a: Value, b: Value) ?Value {
        if (a == .boolean and b == .boolean) {
            return Value.boolean(a.boolean and b.boolean);
        }
        return null;
    }

    /// Logical OR operation
    pub fn logicalOr(a: Value, b: Value) ?Value {
        if (a == .boolean and b == .boolean) {
            return Value.boolean(a.boolean or b.boolean);
        }
        return null;
    }

    /// Logical NOT operation
    pub fn not(self: Value) ?Value {
        return switch (self) {
            .boolean => |b| Value.boolean(!b),
            .number => null,
        };
    }
};

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
            value.print();
            std.debug.print(" ", .{});
        }
        std.debug.print("]\n", .{});
    }
};

test "ValueArray - basic operations" {
    var array = ValueArray.init(std.testing.allocator);
    defer array.deinit();

    // Test adding number values
    const idx1 = try array.add(Value.number(1.5));
    const idx2 = try array.add(Value.number(2.7));
    try std.testing.expectEqual(@as(usize, 0), idx1);
    try std.testing.expectEqual(@as(usize, 1), idx2);

    // Test adding boolean values
    const idx3 = try array.add(Value.boolean(true));
    try std.testing.expectEqual(@as(usize, 2), idx3);

    // Test retrieving values
    if (array.at(0)) |val| {
        try std.testing.expectEqual(ValueType.number, @as(ValueType, val));
        try std.testing.expectEqual(@as(f64, 1.5), val.number);
    }
    if (array.at(2)) |val| {
        try std.testing.expectEqual(ValueType.boolean, @as(ValueType, val));
        try std.testing.expectEqual(true, val.boolean);
    }
    try std.testing.expectEqual(@as(?Value, null), array.at(3));

    // Test length
    try std.testing.expectEqual(@as(usize, 3), array.len());
}

test "Value - arithmetic operations" {
    // Test number operations
    const a = Value.number(5.0);
    const b = Value.number(2.5);
    
    if (Value.add(a, b)) |result| {
        try std.testing.expectEqual(@as(f64, 7.5), result.number);
    }
    if (Value.sub(a, b)) |result| {
        try std.testing.expectEqual(@as(f64, 2.5), result.number);
    }
    if (Value.mul(a, b)) |result| {
        try std.testing.expectEqual(@as(f64, 12.5), result.number);
    }
    if (Value.div(a, b)) |result| {
        try std.testing.expectEqual(@as(f64, 2.0), result.number);
    }
    if (Value.negate(a)) |result| {
        try std.testing.expectEqual(@as(f64, -5.0), result.number);
    }

    // Test operations with booleans (should return null)
    const c = Value.boolean(true);
    try std.testing.expectEqual(@as(?Value, null), Value.add(a, c));
    try std.testing.expectEqual(@as(?Value, null), Value.sub(a, c));
    try std.testing.expectEqual(@as(?Value, null), Value.mul(a, c));
    try std.testing.expectEqual(@as(?Value, null), Value.div(a, c));
    try std.testing.expectEqual(@as(?Value, null), Value.negate(c));
}

test "Value - boolean operations" {
    const t = Value.boolean(true);
    const f = Value.boolean(false);
    const n = Value.number(1.0);

    // Test AND
    if (Value.logicalAnd(t, t)) |result| {
        try std.testing.expectEqual(true, result.boolean);
    }
    if (Value.logicalAnd(t, f)) |result| {
        try std.testing.expectEqual(false, result.boolean);
    }
    if (Value.logicalAnd(f, f)) |result| {
        try std.testing.expectEqual(false, result.boolean);
    }
    try std.testing.expectEqual(@as(?Value, null), Value.logicalAnd(t, n));

    // Test OR
    if (Value.logicalOr(t, t)) |result| {
        try std.testing.expectEqual(true, result.boolean);
    }
    if (Value.logicalOr(t, f)) |result| {
        try std.testing.expectEqual(true, result.boolean);
    }
    if (Value.logicalOr(f, f)) |result| {
        try std.testing.expectEqual(false, result.boolean);
    }
    try std.testing.expectEqual(@as(?Value, null), Value.logicalOr(t, n));

    // Test NOT
    if (Value.not(t)) |result| {
        try std.testing.expectEqual(false, result.boolean);
    }
    if (Value.not(f)) |result| {
        try std.testing.expectEqual(true, result.boolean);
    }
    try std.testing.expectEqual(@as(?Value, null), Value.not(n));
}
