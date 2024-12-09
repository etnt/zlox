const std = @import("std");
const obj = @import("object.zig");

pub const ObjectType = obj.ObjectType;
pub const Object = obj.Object;
pub const String = obj.Object.String; // Assuming String is nested in Object


/// ValueType represents the different types of values our VM can handle
pub const ValueType = enum { number, boolean, object, string };

/// Value represents a constant value in our bytecode
pub const Value = union(ValueType) {
    number: f64,
    boolean: bool,
    object: ?*Object,
    string: ?*String,

    /// Print a value
    pub fn print(self: Value) void {
        switch (self) {
            .number => |n| std.debug.print("{d}", .{n}),
            .boolean => |b| std.debug.print("{}", .{b}),
            .string => |s| {
                if (s) |str_ptr| {
                    std.debug.print("{s}", .{str_ptr.chars});
                } else {
                    std.debug.print("null string", .{});
                }
            },
            .object => |o| {
                if (o) |obj_ptr| {
                    switch (obj_ptr.type) {
                        .string => { 
                            // Safe cast:  Check alignment before casting
                            // Check if String's alignment is less than or equal to Object's alignment.
                            if (@alignOf(String) <= @alignOf(Object)) {
                                const string_data: *String = @alignCast(obj_ptr);
                                std.debug.print("{s}", .{string_data.chars});
                            } else {
                                std.debug.print("Alignment error: Cannot cast to String\n", .{});
                            }
                        },
                        // Add other cases for other object types here
                    }
                } else {
                    std.debug.print("null object", .{});
                }
            },
        }
    }

    /// Create a number value
    pub fn number(n: f64) Value {
        return .{ .number = n };
    }

    /// Create a boolean value
    pub fn boolean(b: bool) Value {
        return .{ .boolean = b };
    }

    /// Create an object value
    pub fn object(o: *obj.Object) Value {
        return .{ .object = o };
    }

    /// Create a string value
    pub fn createString(allocator: std.mem.Allocator, chars: []const u8) !Value {
        const str = try String.init(allocator, chars);
        return Value{ .string = str };
    }

    /// Add two values
    pub fn add(a: Value, b: Value) ?Value {
        if (a == .number and b == .number) {
            return Value.number(a.number + b.number);
        }
        // String concatenation will be added later
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
            .boolean, .string, .object => null,
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
            .number, .string, .object => null,
        };
    }

    /// Check if two values are equal
    pub fn equals(a: Value, b: Value) bool {
        if (a != b) return false;
        return switch (a) {
            .number => |n| n == b.number,
            .boolean => |bool_a| bool_a == b.boolean,
            .object => |obj_a| obj_a == b.object,
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
    try std.testing.expectEqual(idx1, 0);
    try std.testing.expectEqual(idx2, 1);

    // Test adding boolean values
    const idx3 = try array.add(Value.boolean(true));
    try std.testing.expectEqual(idx3, 2);

    // Test retrieving values
    if (array.at(0)) |val| {
        try std.testing.expect(val == .number);
        try std.testing.expectEqual(val.number, 1.5);
    }
    if (array.at(2)) |val| {
        try std.testing.expect(val == .boolean);
        try std.testing.expectEqual(val.boolean, true);
    }
    try std.testing.expectEqual(array.at(3), null);

    // Test length
    try std.testing.expectEqual(array.len(), 3);
}

test "Value - arithmetic operations" {
    // Test number operations
    const a = Value.number(5.0);
    const b = Value.number(2.5);

    if (Value.add(a, b)) |result| {
        try std.testing.expectEqual(result.number, 7.5);
    }
    if (Value.sub(a, b)) |result| {
        try std.testing.expectEqual(result.number, 2.5);
    }
    if (Value.mul(a, b)) |result| {
        try std.testing.expectEqual(result.number, 12.5);
    }
    if (Value.div(a, b)) |result| {
        try std.testing.expectEqual(result.number, 2.0);
    }
    if (Value.negate(a)) |result| {
        try std.testing.expectEqual(result.number, -5.0);
    }

    // Test operations with booleans (should return null)
    const c = Value.boolean(true);
    try std.testing.expectEqual(Value.add(a, c), null);
    try std.testing.expectEqual(Value.sub(a, c), null);
    try std.testing.expectEqual(Value.mul(a, c), null);
    try std.testing.expectEqual(Value.div(a, c), null);
    try std.testing.expectEqual(Value.negate(c), null);
}

test "Value - boolean operations" {
    const t = Value.boolean(true);
    const f = Value.boolean(false);
    const n = Value.number(1.0);

    // Test AND
    if (Value.logicalAnd(t, t)) |result| {
        try std.testing.expectEqual(result.boolean, true);
    }
    if (Value.logicalAnd(t, f)) |result| {
        try std.testing.expectEqual(result.boolean, false);
    }
    if (Value.logicalAnd(f, f)) |result| {
        try std.testing.expectEqual(result.boolean, false);
    }
    try std.testing.expectEqual(Value.logicalAnd(t, n), null);

    // Test OR
    if (Value.logicalOr(t, t)) |result| {
        try std.testing.expectEqual(result.boolean, true);
    }
    if (Value.logicalOr(t, f)) |result| {
        try std.testing.expectEqual(result.boolean, true);
    }
    if (Value.logicalOr(f, f)) |result| {
        try std.testing.expectEqual(result.boolean, false);
    }
    try std.testing.expectEqual(Value.logicalOr(t, n), null);

    // Test NOT
    if (Value.not(t)) |result| {
        try std.testing.expectEqual(result.boolean, false);
    }
    if (Value.not(f)) |result| {
        try std.testing.expectEqual(result.boolean, true);
    }
    try std.testing.expectEqual(Value.not(n), null);
}

test "Value - string operations" {
    const allocator = std.testing.allocator;

    // Test the new string convenience function
    const str_val = try Value.createString(allocator, "hello");
    defer if (str_val.string) |str_ptr| {
        str_ptr.deinit(allocator);
    };

    try std.testing.expect(str_val == .string);
    if (str_val.string) |str_ptr| {
        try std.testing.expectEqualStrings("hello", str_ptr.chars);
    }
}
