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
            const string = try allocator.create(String);
            string.obj = .{ .type = .string };
            string.length = chars.len;
            string.chars = try allocator.dupe(u8, chars);
            return string;
        }

        pub fn deinit(self: *String, allocator: std.mem.Allocator) void {
            allocator.free(self.chars);
            allocator.destroy(self);
        }
    };
};

test "Object - string operations" {
    const allocator = std.testing.allocator;

    // Test string creation
    const str = try Object.String.init(allocator, "test");
    defer str.deinit(allocator);

    try std.testing.expectEqual(ObjectType.string, str.obj.type);
    try std.testing.expectEqualStrings("test", str.chars);
}
