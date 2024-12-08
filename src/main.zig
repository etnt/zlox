const std = @import("std");
const root = @import("root.zig");
const OpCode = root.OpCode;
const Chunk = root.Chunk;

pub fn main() !void {
    // Get a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new chunk that can store both opcodes and constants
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    // Add some constants to our chunk
    const const1 = try chunk.addConstant(1.2);
    const const2 = try chunk.addConstant(3.4);

    // Write a sequence of opcodes that will:
    // 1. Push first constant (1.2)
    // 2. Push second constant (3.4)
    // 3. Add them together
    // 4. Return
    try chunk.writeOpcode(OpCode.PUSH);
    try chunk.writeOpcode(@intCast(const1)); // Index of first constant
    try chunk.writeOpcode(OpCode.PUSH);
    try chunk.writeOpcode(@intCast(const2)); // Index of second constant
    try chunk.writeOpcode(OpCode.ADD);
    try chunk.writeOpcode(OpCode.RETURN);

    // Disassemble the chunk to see its contents
    std.debug.print("\nChunk Disassembly:\n", .{});
    chunk.disassemble("main");
}

test "chunk with constants" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add constants
    const const1 = try chunk.addConstant(1.2);
    const const2 = try chunk.addConstant(3.4);
    try std.testing.expectEqual(@as(usize, 0), const1);
    try std.testing.expectEqual(@as(usize, 1), const2);

    // Write opcodes
    try chunk.writeOpcode(OpCode.PUSH);
    try chunk.writeOpcode(@intCast(const1));
    try chunk.writeOpcode(OpCode.PUSH);
    try chunk.writeOpcode(@intCast(const2));
    try chunk.writeOpcode(OpCode.ADD);
    try chunk.writeOpcode(OpCode.RETURN);

    // Verify code length (6 opcodes total)
    try std.testing.expectEqual(@as(usize, 6), chunk.code.len());

    // Verify constants
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.at(0).?);
    try std.testing.expectEqual(@as(f64, 3.4), chunk.constants.at(1).?);
}
