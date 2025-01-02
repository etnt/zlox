const std = @import("std");
const obj = @import("object.zig");
const utils = @import("utils.zig");
const Chunk = @import("chunk.zig").Chunk;

pub const ObjectType = obj.ObjectType;
pub const Object = obj.Object;
pub const String = obj.Object.String;
pub const Function = obj.Object.Function;
pub const NativeFunction = obj.Object.NativeFunction;
pub const Closure = obj.Object.Closure;

/// ValueType represents the different types of values our VM can handle
pub const ValueType = enum { 
    nil,
    number,
    boolean,
    object,
    string,
    function,
    native_function,
    closure,
};

/// Value represents a constant value in our bytecode
pub const Value = union(ValueType) {
    nil: void,
    number: f64,
    boolean: bool,
    object: ?*Object,
    string: ?*String,
    function: ?*Function,
    native_function: ?*NativeFunction,
    closure: ?*Closure,

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
            .function => |f| {
                if (f) |func_ptr| {
                    std.debug.print("Function: {s}", .{func_ptr.name});
                } else {
                    std.debug.print("null function", .{});
                }
            },
            .native_function => |f| {
                if (f) |func_ptr| {
                    std.debug.print("Native Function: {s}", .{func_ptr.name});
                } else {
                    std.debug.print("null native function", .{});
                }
            },
            .closure => |f| {
                if (f) |closure_ptr| {
                    const func_ptr = closure_ptr.function;
                    std.debug.print("Closure for function: {s}", .{func_ptr.name});
                } else {
                    std.debug.print("null closure", .{});
                }
            },
            .object => |o| {
                if (o) |obj_ptr| {
                    switch (obj_ptr.type) {
                        .string => { 
                            const string_data: *String = obj_ptr.asString();
                            std.debug.print("{s}", .{string_data.chars});
                        },
                        .function => {
                            // Print function name
                            const function_data: *Function = obj_ptr.asFunction();
                            std.debug.print("{s}", .{function_data.name});
                        },
                        .native_function => {
                            const native_data: *NativeFunction = obj_ptr.asNativeFunction();
                            std.debug.print("Native: {s}", .{native_data.name});
                        },
                        .closure => {
                            const closure_data: *Closure = obj_ptr.asClosure();
                            std.debug.print("Closure: {s}", .{closure_data.function.name});
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

    pub fn createFunction(allocator: std.mem.Allocator, name: []const u8, arity: usize, chunk: Chunk) !Value {
        const func = try Function.init(allocator, name, arity, chunk);
        return Value{ .function = func };
    }

    pub fn createNativeFunction(allocator: std.mem.Allocator, name: []const u8, function: *const fn([]Value) Value, arity: usize) !Value {
        const native = try NativeFunction.init(allocator, name, function, arity);
        return Value{ .native_function = native };
    }

    pub fn createClosure(allocator: std.mem.Allocator, function: *Function, upvalues: []Value) !Value {
        const closure = try Closure.init(allocator, function, upvalues);
        return Value{ .closure = closure };
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
            var result = try allocator.alloc(u8, str_a.length() + str_b.length());
            defer allocator.free(result); // Free the temporary buffer after we're done with it

            @memcpy(result[0..str_a.length()], str_a.get_chars());
            @memcpy(result[str_a.length()..], str_b.get_chars());

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
            .nil, .boolean, .string, .function, .native_function, .closure, .object => null,
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
            .nil, .number, .string, .function, .native_function, .closure, .object => null,
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
            .function => |func_a| b.function == func_a,  // FIXME: compare function pointers?
            .native_function => |func_a| b.native_function == func_a,
            .closure => |closure_a| b.closure == closure_a,  // FIXME: compare closure pointers?
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
            .function => |f| Value{ .function = f },    // FIXME - clone function
            .native_function => |f| Value{ .native_function = f },
            .closure => |f| Value{ .closure = f },      // FIXME - clone closure
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
    pub fn deinit(self: *ValueArray) void {
        // Clean up any Function values before deiniting the array
        for (self.values.items) |value| {
            switch (value) {
                .function => |maybe_func| {
                    if (maybe_func) |func| {
                        func.deinit(self.allocator);
                    }
                },
                .native_function => |maybe_func| {
                    if (maybe_func) |func| {
                        func.deinit(self.allocator);
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

// Export Value's functions at the module level
pub const nil = Value.nil;
pub const number = Value.number;
pub const boolean = Value.boolean;
pub const object = Value.object;
pub const createString = Value.createString;
pub const equals = Value.equals;
