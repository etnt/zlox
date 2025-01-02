const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const utils = @import("utils.zig");
const Value = @import("value.zig").Value;

/// ObjectType represents different kinds of heap-allocated objects
pub const ObjectType = enum {
    string,
    function,
    native_function,
    closure,
    upvalue,
    // More object types will be added later (class, instance, etc.)
};

/// Object represents any heap-allocated value
pub const Object = struct {
    type: ObjectType,
    data: union(ObjectType) {
        string: *String,
        function: *Function,
        native_function: *NativeFunction,
        closure: *Closure,
        upvalue: *Upvalue,
    },
    // Add garbage collection fields later

    pub const Upvalue = struct {
        obj: Object,
        location: *Value,  // a location field points to the closed-over variable

        pub fn init(allocator: std.mem.Allocator, slot: *Value) !*Upvalue {
            const upvalue = try allocator.create(Upvalue);
            upvalue.obj = .{
                .type = .upvalue,
                .data = .{ .upvalue = upvalue },
            };
            upvalue.location = slot;
            return upvalue;
        }

        pub fn deinit(self: *Upvalue, allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }
    };

    // Type-safe helper method
    pub fn asUpvalue(self: *Object) *Upvalue {
        return self.data.upvalue;
    }

    pub const Closure = struct {
        obj: Object,
        function: *Function,
        upvalues: []Value,

        pub fn init(allocator: std.mem.Allocator, function: *Function, upvalues: []Value) !*Closure {
            const closure = try allocator.create(Closure);
            closure.obj = .{ 
                .type = .closure,
                .data = .{ .closure = closure },
            };
            closure.function = function;
            closure.upvalues = upvalues;  // FIXME: Should we copy the upvalues?
            return closure;
        }

        pub fn deinit(self: *Closure, allocator: std.mem.Allocator) void {
            // We free only the Closure itself, not the Function.
            // That’s because the closure doesn’t own the function.
            // There may be multiple closures that all reference the same function.
            allocator.destroy(self);
        }
    };

    // Type-safe helper method
    pub fn asClosure(self: *Object) *Closure {
        return self.data.closure;
    }

    pub const NativeFunction = struct {
        obj: Object,
        function: *const fn([]Value) Value,
        name: []const u8,
        arity: usize,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, function: *const fn([]Value) Value, arity: usize) !*NativeFunction {
            const native = try allocator.create(NativeFunction);
            native.obj = .{ 
                .type = .native_function,
                .data = .{ .native_function = native },
            };
            native.function = function;
            native.name = try allocator.dupe(u8, name);
            native.arity = arity;
            return native;
        }

        pub fn deinit(self: *NativeFunction, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.destroy(self);
        }
    };

    // Type-safe helper method
    pub fn asNativeFunction(self: *Object) *NativeFunction {
        return self.data.native_function;
    }

    pub const Function = struct {
        obj: Object,
        arity: usize,
        upvalueCount: usize,
        chunk: Chunk,
        name: []const u8,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, arity: usize, chunk: Chunk) !*Function {
            // Create a new function object
            const function = try allocator.create(Function);
            function.obj = .{ 
                .type = .function,
                .data = .{ .function = function },
            };
            function.arity = arity;
            function.upvalueCount = 0;
            function.chunk = chunk;
            function.name = try allocator.dupe(u8, name);
            return function;
        }

        pub fn deinit(self: *Function, allocator: std.mem.Allocator) void {
            //utils.debugPrintln(@src(), "Freeing Function: {s}", .{self.name});
            allocator.free(self.name);
            self.chunk.deinit();
            allocator.destroy(self);
        }

        pub fn set_name(self: *Function, allocator: std.mem.Allocator, name: []const u8) void {
            self.name = try allocator.dupe(u8, name);
        }

        pub fn set_arity(self: *Function, arity: usize) void {
            self.arity = arity;
        }

        pub fn set_chunk(self: *Function, chunk: *Chunk) void {
            self.chunk = chunk;
        }
    };

    // Type-safe helper method
    pub fn asFunction(self: *Object) *Function {
        return self.data.function;
    }

    /// String object type
    pub const String = struct {
        obj: Object,
        chars: []const u8,

        pub fn init(allocator: std.mem.Allocator, cs: []const u8) !*String {
            // Initialize the intern pool if it doesn't exist
            initInternPool(allocator);

            // Check if this string is already interned
            if (string_intern_pool.?.get(cs)) |existing| {
                return existing;
            }

            // Create a new string object
            const string = try allocator.create(String);
            string.obj = .{ 
                .type = .string,
                .data = .{ .string = string },
            };
            string.chars = try allocator.dupe(u8, cs);

            // Add to intern pool
            try string_intern_pool.?.put(string.chars, string);

            return string;
        }

        pub fn deinit(self: *String, allocator: std.mem.Allocator) void {
            //utils.debugPrintln(@src(), "Freeing String: {s}", .{self.chars});
            // Remove from intern pool if it exists
            if (string_intern_pool) |*pool| {
                _ = pool.remove(self.chars);
            }
            allocator.free(self.chars);
            allocator.destroy(self);
        }

        pub fn length(self: *String) usize {
            return self.chars.len;
        }

        pub fn get_chars(self: *String) []const u8 {
            return self.chars;
        }
    };

    // Type-safe helper method
    pub fn asString(self: *Object) *String {
        return self.data.string;
    }
};

/// Global string interning state
pub var string_intern_pool: ?std.StringHashMap(*Object.String) = null;
pub var intern_pool_allocator: ?std.mem.Allocator = null;

/// Initialize the global string intern pool
pub fn initInternPool(allocator: std.mem.Allocator) void {
    if (string_intern_pool == null) {
        string_intern_pool = std.StringHashMap(*Object.String).init(allocator);
        intern_pool_allocator = allocator;
    }
}

/// Clean up the global string intern pool - should be called when shutting down
pub fn deinitInternPool() void {
    //utils.debugPrintln(@src(),"Freeing Intern Pool...0", .{});
    if (string_intern_pool) |*pool| {
        //utils.debugPrintln(@src(),"Freeing Intern Pool...1", .{});
        // The strings themselves are cleaned up by their owners
        pool.deinit();
        string_intern_pool = null;
        intern_pool_allocator = null;
    }
    //utils.debugPrintln(@src(),"Freeing Intern Pool...OK", .{});
}
