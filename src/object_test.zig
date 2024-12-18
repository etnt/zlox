const std = @import("std");
const Object = @import("object.zig").Object;
const ObjectType = @import("object.zig").ObjectType;
const VM = @import("vm.zig").VM;
const Chunk = @import("chunk.zig").Chunk;

test "Object - string operations and interning" {
    const allocator = std.testing.allocator;

    // Create a VM to own the strings
    var chunk = Chunk.init(allocator);
    var vm = try VM.init(&chunk, false, allocator);
    defer {
        vm.deinit();
        chunk.deinit();
    }

    // Test basic string creation
    const str1 = try Object.String.init(allocator, "test");
    try std.testing.expectEqual(ObjectType.string, str1.obj.type);
    try std.testing.expectEqualStrings("test", str1.chars);

    // Test string interning - same content should return same pointer
    const str2 = try Object.String.init(allocator, "test");
    try std.testing.expectEqual(str1, str2);

    // Test different string creates new object
    const str3 = try Object.String.init(allocator, "different");
    try std.testing.expect(str1 != str3);

    // Test empty string interning
    const empty1 = try Object.String.init(allocator, "");
    const empty2 = try Object.String.init(allocator, "");
    try std.testing.expectEqual(empty1, empty2);

    // Test string with special characters
    const special1 = try Object.String.init(allocator, "hello\n\t世界");
    const special2 = try Object.String.init(allocator, "hello\n\t世界");
    try std.testing.expectEqual(special1, special2);
}
