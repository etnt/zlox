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
    const const3 = try chunk.addConstant(2.71828);

    // Write a sequence of opcodes that will:
    // 1. Load first constant (1.2)
    // 2. Load second constant (3.4)
    // 3. Return
    try chunk.writeOpcode(OpCode.CONSTANT, 1234);
    try chunk.writeByte(@intCast(const1), 1234); // Index of first constant
    try chunk.writeOpcode(OpCode.CONSTANT, 1234);
    try chunk.writeByte(@intCast(const3), 1234); // Index of third constant
    try chunk.writeOpcode(OpCode.CONSTANT, 5678);
    try chunk.writeByte(@intCast(const2), 5678); // Index of second constant
    try chunk.writeOpcode(OpCode.RETURN, 5678);

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

    // Write opcodes with their operands
    try chunk.writeOpcode(OpCode.CONSTANT, 1234);
    try chunk.writeByte(@intCast(const1), 1234);
    try chunk.writeOpcode(OpCode.CONSTANT, 5678);
    try chunk.writeByte(@intCast(const2), 5678);
    try chunk.writeOpcode(OpCode.RETURN, 5678);

    // Verify code length (5 bytes total: CONSTANT + index1 + CONSTANT + index2 + RETURN)
    try std.testing.expectEqual(@as(usize, 5), chunk.code.len());
    try std.testing.expectEqual(@as(usize, 5), chunk.lines.len());

    // Verify constants
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.at(0).?);
    try std.testing.expectEqual(@as(f64, 3.4), chunk.constants.at(1).?);

    // Verify line numbers
    try std.testing.expectEqual(@as(u32, 1234), chunk.lines.at(0).?);
    try std.testing.expectEqual(@as(u32, 1234), chunk.lines.at(1).?);
    try std.testing.expectEqual(@as(u32, 5678), chunk.lines.at(2).?);
    try std.testing.expectEqual(@as(u32, 5678), chunk.lines.at(3).?);
    try std.testing.expectEqual(@as(u32, 5678), chunk.lines.at(4).?);
}
