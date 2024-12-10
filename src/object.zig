const std = @import("std");

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
    if (string_intern_pool) |*pool| {
        // The strings themselves are cleaned up by their owners
        pool.deinit();
        string_intern_pool = null;
        intern_pool_allocator = null;
    }
}

test "Object - string operations and interning" {
    const allocator = std.testing.allocator;
    defer deinitInternPool();

    // Test basic string creation
    const str1 = try Object.String.init(allocator, "test");
    defer str1.deinit(allocator);

    try std.testing.expectEqual(ObjectType.string, str1.obj.type);
    try std.testing.expectEqualStrings("test", str1.chars);

    // Test string interning - same content should return same pointer
    const str2 = try Object.String.init(allocator, "test");
    // Don't defer deinit for str2 since it's the same as str1
    try std.testing.expectEqual(str1, str2);

    // Test different string creates new object
    const str3 = try Object.String.init(allocator, "different");
    defer str3.deinit(allocator);
    try std.testing.expect(str1 != str3);

    // Test empty string interning
    const empty1 = try Object.String.init(allocator, "");
    defer empty1.deinit(allocator);
    const empty2 = try Object.String.init(allocator, "");
    try std.testing.expectEqual(empty1, empty2);

    // Test string with special characters
    const special1 = try Object.String.init(allocator, "hello\n\t世界");
    defer special1.deinit(allocator);
    const special2 = try Object.String.init(allocator, "hello\n\t世界");
    try std.testing.expectEqual(special1, special2);

    // Verify intern pool state
    try std.testing.expect(string_intern_pool != null);
    try std.testing.expectEqual(intern_pool_allocator.?, allocator);
}
