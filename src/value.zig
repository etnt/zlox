const std = @import("std");
const obj = @import("object.zig");

pub const ObjectType = obj.ObjectType;
pub const Object = obj.Object;
pub const String = obj.Object.String;

/// ValueType represents the different types of values our VM can handle
pub const ValueType = enum { nil, number, boolean, object, string };

/// Value represents a constant value in our bytecode
pub const Value = union(ValueType) {
    nil: void,
    number: f64,
    boolean: bool,
    object: ?*Object,
    string: ?*String,

    /// Print a value
    pub fn print(self: Value) void {
        switch (self) {
            .nil => std.debug.print("nil", .{}),
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
                            if (@alignOf(String) <= @alignOf(Object)) {
                                const string_data: *String = @alignCast(obj_ptr);
                                std.debug.print("{s}", .{string_data.chars});
                            } else {
                                std.debug.print("Alignment error: Cannot cast to String\n", .{});
                            }
                        },
                    }
                } else {
                    std.debug.print("null object", .{});
                }
            },
        }
    }

    /// Create a null value
    pub fn nil() Value {
        return .{ .nil = {} };
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
    pub fn add(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        // Handle number addition
        if (a == .number and b == .number) {
            return Value.number(a.number + b.number);
        }

        // Handle string concatenation
        if (a == .string and b == .string) {
            const str_a = a.string orelse return null;
            const str_b = b.string orelse return null;

            // Create a new buffer for the concatenated string
            var result = try allocator.alloc(u8, str_a.length + str_b.length);
            defer allocator.free(result); // Free the temporary buffer after we're done with it

            @memcpy(result[0..str_a.length], str_a.chars);
            @memcpy(result[str_a.length..], str_b.chars);

            // Create a new string object with the concatenated result
            return try createString(allocator, result);
        }

        return null;
    }

    /// Subtract two values
    pub fn sub(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        _ = allocator;
        if (a == .number and b == .number) {
            return Value.number(a.number - b.number);
        }
        return null;
    }

    /// Multiply two values
    pub fn mul(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        _ = allocator;
        if (a == .number and b == .number) {
            return Value.number(a.number * b.number);
        }
        return null;
    }

    /// Divide two values
    pub fn div(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        _ = allocator;
        if (a == .number and b == .number) {
            return Value.number(a.number / b.number);
        }
        return null;
    }

    /// Negate a value
    pub fn negate(self: Value) ?Value {
        return switch (self) {
            .number => |n| Value.number(-n),
            .nil, 
            .boolean, .string, .object => null,
        };
    }

    /// Logical AND operation
    pub fn logicalAnd(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        _ = allocator;
        if (a == .boolean and b == .boolean) {
            return Value.boolean(a.boolean and b.boolean);
        }
        return null;
    }

    /// Logical OR operation
    pub fn logicalOr(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        _ = allocator;
        if (a == .boolean and b == .boolean) {
            return Value.boolean(a.boolean or b.boolean);
        }
        return null;
    }

    /// Logical NOT operation
    pub fn not(self: Value) ?Value {
        return switch (self) {
            .boolean => |b| Value.boolean(!b),
            .nil, .number, .string, .object => null,
        };
    }

    /// Check if two values are equal
    pub fn equals(a: Value, b: Value) bool {
        if (@as(ValueType, a) != @as(ValueType, b)) return false;
        return switch (a) {
            .nil => b.nil == {},
            .number => |n| b.number == n,
            .boolean => |bool_a| b.boolean == bool_a,
            .string => |str_a| {
                const str_b = b.string;
                // Handle null cases
                if (str_a == null and str_b == null) return true;
                if (str_a == null or str_b == null) return false;
                // Since strings are interned, we can just compare pointers
                return str_a == str_b;
            },
            .object => |obj_a| b.object == obj_a,
        };
    }

    /// Clone a value
    pub fn clone(self: Value, allocator: std.mem.Allocator) !Value {
        return switch (self) {
            .nil => Value{ .nil = {} },
            .number => |n| Value{ .number = n },
            .boolean => |b| Value{ .boolean = b },
            .string => |s| if (s) |str| try createString(allocator, str.chars) else Value{ .string = null },
            .object => |o| Value{ .object = o },
        };
    }
};

/// ValueArray provides a dynamic array implementation for constant values
pub const ValueArray = struct {
    values: std.ArrayList(Value),
    allocator: std.mem.Allocator,

    /// Initialize a new ValueArray with the given allocator
    pub fn init(allocator: std.mem.Allocator) ValueArray {
        return ValueArray{
            .values = std.ArrayList(Value).init(allocator),
            .allocator = allocator,
        };
    }

    /// Free the memory used by the ValueArray
    pub fn deinit(self: *ValueArray) void {
        // Clean up any string objects before freeing the array
        for (self.values.items) |value| {
            switch (value) {
                .string => |str| {
                    if (str) |str_ptr| {
                        str_ptr.deinit(self.allocator);
                    }
                },
                else => {},
            }
        }
        self.values.deinit();
    }

    /// Add a value to the array and return its index
    pub fn add(self: *ValueArray, value: Value) !usize {
        const index = self.values.items.len;
        // Clone the value before adding it to ensure we own it
        const cloned = try value.clone(self.allocator);
        try self.values.append(cloned);
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

    /// Check if a value exists in the array
    pub fn contains(self: *const ValueArray, value: Value) bool {
        for (self.values.items) |item| {
            if (Value.equals(item, value)) {
                return true;
            }
        }
        return false;
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

    if (Value.add(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 7.5);
        }
    } else |_| {}
    if (Value.sub(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 2.5);
        }
    } else |_| {}
    if (Value.mul(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 12.5);
        }
    } else |_| {}
    if (Value.div(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 2.0);
        }
    } else |_| {}
    if (Value.negate(a)) |result| {
        try std.testing.expectEqual(result.number, -5.0);
    }

    // Test operations with booleans (should return null)
    const c = Value.boolean(true);
    if (Value.add(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    if (Value.sub(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    if (Value.mul(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    if (Value.div(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    try std.testing.expectEqual(Value.negate(c), null);
}

test "Value - boolean operations" {
    const t = Value.boolean(true);
    const f = Value.boolean(false);
    const n = Value.number(1.0);

    // Test AND
    if (Value.logicalAnd(t, t, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, true);
        }
    } else |_| {}
    if (Value.logicalAnd(t, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, false);
        }
    } else |_| {}
    if (Value.logicalAnd(f, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, false);
        }
    } else |_| {}
    if (Value.logicalAnd(t, n, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}

    // Test OR
    if (Value.logicalOr(t, t, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, true);
        }
    } else |_| {}
    if (Value.logicalOr(t, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, true);
        }
    } else |_| {}
    if (Value.logicalOr(f, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, false);
        }
    } else |_| {}
    if (Value.logicalOr(t, n, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}

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

    // Test string creation and equality with interning
    const str_val1 = try Value.createString(allocator, "hello");
    defer if (str_val1.string) |str_ptr| {
        str_ptr.deinit(allocator);
    };

    const str_val2 = try Value.createString(allocator, "hello");
    // Don't need to defer deinit for str_val2 since it's the same string as str_val1

    // Test that we got the same string back (pointer equality)
    try std.testing.expect(Value.equals(str_val1, str_val2));
    if (str_val1.string) |str1| {
        if (str_val2.string) |str2| {
            try std.testing.expectEqual(str1, str2);
        }
    }

    // Test different strings
    const str_val3 = try Value.createString(allocator, "world");
    defer if (str_val3.string) |str_ptr3| {
        str_ptr3.deinit(allocator);
    };

    try std.testing.expect(!Value.equals(str_val1, str_val3));

    // Test string concatenation
    if (try Value.add(str_val1, str_val3, allocator)) |result| {
        defer if (result.string) |str_ptr| {
            str_ptr.deinit(allocator);
        };
        try std.testing.expect(result == .string);
        if (result.string) |str_ptr| {
            try std.testing.expectEqualStrings("helloworld", str_ptr.chars);
        }
    }

    // Clean up the intern pool after all strings are freed
    defer obj.deinitInternPool();
}

test "ValueArray - contains" {
    const allocator = std.testing.allocator;

    const num = Value.number(1.5);
    const bool_val = Value.boolean(true);
    const str = try Value.createString(allocator, "test");

    var array = ValueArray.init(allocator);
    defer {
        // First deinit the array which will free the strings
        array.deinit();
        // Then clean up the intern pool
        obj.deinitInternPool();
    }

    // Add values to array
    _ = try array.add(num);
    _ = try array.add(bool_val);
    _ = try array.add(str);

    // Test contains
    try std.testing.expect(array.contains(num));
    try std.testing.expect(array.contains(bool_val));
    try std.testing.expect(array.contains(str));
    try std.testing.expect(!array.contains(Value.number(2.0)));
    try std.testing.expect(!array.contains(Value.boolean(false)));
}
