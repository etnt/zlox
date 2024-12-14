const std = @import("std");
const obj = @import("object.zig");
const utils = @import("utils.zig");

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

    pub const IsFalseyError = error{
        InvalidType,
    };

    /// Check if a value is falsey according to Lox rules
    /// Only boolean values are valid for conditional jumps
    pub fn isFalsey(self: Value) IsFalseyError!u1 {
        return switch (self) {
            .boolean => |b| if (!b) 1 else 0,
            else => IsFalseyError.InvalidType,
        };
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
            const str = try String.init(allocator, result);
            return Value{ .string = str };
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

    // Greater than
    pub fn gt(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        _ = allocator;
        if (a == .number and b == .number) {
            return Value.boolean(a.number > b.number);
        }
        return null;
    }

    // Less than
    pub fn lt(a: Value, b: Value, allocator: std.mem.Allocator) !?Value {
        _ = allocator;
        if (a == .number and b == .number) {
            return Value.boolean(a.number < b.number);
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
            .string => |s| if (s) |str| {
                const new_str = try String.init(allocator, str.chars);
                return Value{ .string = new_str };
            } else Value{ .string = null },
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

    /// Free the memory used by the ValueArray.
    /// Note: Does not free strings as they are owned by the VM's intern pool
    pub fn deinit(self: *ValueArray) void {
        //utils.debugPrintln(@src(),"Freeing ValueArray...0", .{});
        // We don't free strings here as they are owned by the VM's intern pool
        //utils.debugPrintln(@src(),"Freeing ValueArray...1", .{});
        self.values.deinit();
        //utils.debugPrintln(@src(),"Freeing ValueArray...OK", .{});
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

// Export Value's functions at the module level
pub const nil = Value.nil;
pub const number = Value.number;
pub const boolean = Value.boolean;
pub const object = Value.object;
pub const createString = Value.createString;
pub const equals = Value.equals;
