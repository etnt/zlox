const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const utils = @import("utils.zig");
const Value = @import("value.zig").Value;

/// ObjectType represents different kinds of heap-allocated objects
pub const ObjectType = enum {
    string,
    function,
    native_function,
    // More object types will be added later (class, instance, etc.)
};

/// Object represents any heap-allocated value
pub const Object = struct {
    type: ObjectType,
    // Add garbage collection fields later

    pub const NativeFunction = struct {
        obj: Object,
        function: *const fn([]Value) Value,
        name: []const u8,
        arity: usize,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, function: *const fn([]Value) Value, arity: usize) !*NativeFunction {
            const native = try allocator.create(NativeFunction);
            native.* = .{
                .obj = .{ .type = .native_function },
                .function = function,
                .name = try allocator.dupe(u8, name),
                .arity = arity,
            };
            return native;
        }

        pub fn deinit(self: *NativeFunction, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.destroy(self);
        }
    };

    pub const Function = struct {
        obj: Object,
        arity: usize,
        chunk: Chunk,
        name: []const u8,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, arity: usize, chunk: Chunk) !*Function {
            // Create a new function object
            const function = try allocator.create(Function);
            function.obj = .{ .type = .function };
            function.arity = arity;
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

    /// String object type
    pub const String = struct {
        obj: Object,
        length: usize,
        chars: []u8,

        pub fn init(allocator: std.mem.Allocator, chars: []const u8) !*String {
            // Initialize the intern pool if it doesn't exist
            initInternPool(allocator);

            // Check if this string is already interned
            if (string_intern_pool.?.get(chars)) |existing| {
                return existing;
            }

            // Create a new string object
            const string = try allocator.create(String);
            string.obj = .{ .type = .string };
            string.length = chars.len;
            string.chars = try allocator.dupe(u8, chars);

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
    };
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
