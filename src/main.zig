const std = @import("std");
const ByteArray = @import("byte_array.zig").ByteArray;

pub fn main() !void {
    // Get a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new byte array
    var array = ByteArray.init(allocator);
    defer array.deinit();

    // Push some bytes
    try array.push(10);
    try array.push(20);
    try array.push(30);

    // Print current state
    std.debug.print("After pushing: ", .{});
    array.print();

    // Pop a byte
    // If array.pop() returns null (the array was empty), the code within the if block is skipped.
    // If array.pop() returns a value (the last byte), that value is assigned to the byte variable,
    // and the code inside the if block executes.
    if (array.pop()) |byte| {
        std.debug.print("Popped byte: {d}\n", .{byte});
    }

    // Print final state
    std.debug.print("Final state: ", .{});
    array.print();
}

test "main functionality" {
    // This test ensures the main file compiles and imports work correctly
    var array = ByteArray.init(std.testing.allocator);
    defer array.deinit();
    try array.push(42);
    try std.testing.expectEqual(@as(usize, 1), array.len());
}
