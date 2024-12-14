const std = @import("std");
const utils = @import("utils.zig");

/// ObjectType represents different kinds of heap-allocated objects
pub const ObjectType = enum {
    string,
    // More object types will be added later (function, class, instance, etc.)
};

/// Object represents any heap-allocated value
pub const Object = struct {
    type: ObjectType,
    // Add garbage collection fields later

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

