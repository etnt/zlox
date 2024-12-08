const std = @import("std");
const ByteArray = @import("byte_array.zig").ByteArray;
const OpCode = @import("opcodes.zig").OpCode;

pub fn main() !void {
    // Get a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new byte array for chunk of opcodes
    var chunk = ByteArray.init(allocator);
    defer chunk.deinit();

    // Push some operation codes
    try chunk.push(OpCode.PUSH);  // 0x01
    try chunk.push(OpCode.ADD);   // 0x03
    try chunk.push(OpCode.RETURN); // 0x00

    // Print current state with opcode names
    std.debug.print("After pushing chunk:\n", .{});
    chunk.printOpcodes(OpCode.getName);

    // Pop an opcode
    if (chunk.pop()) |opcode| {
        std.debug.print("\nPopped opcode: 0x{X:0>2} ({s})\n\n", .{opcode, OpCode.getName(opcode)});
    }

    // Print final state with opcode names
    std.debug.print("Final state:\n", .{});
    chunk.printOpcodes(OpCode.getName);
}

test "chunk operations" {
    var chunk = ByteArray.init(std.testing.allocator);
    defer chunk.deinit();

    try chunk.push(OpCode.PUSH);
    try chunk.push(OpCode.ADD);
    try std.testing.expectEqual(@as(usize, 2), chunk.len());
    try std.testing.expectEqual(OpCode.ADD, chunk.pop().?);
    try std.testing.expectEqual(OpCode.PUSH, chunk.pop().?);
}
