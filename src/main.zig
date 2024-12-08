const std = @import("std");
const root = @import("root.zig");
const OpCode = root.OpCode;
const Chunk = root.Chunk;
const VM = root.VM;

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
    const const3 = try chunk.addConstant(5.6);

    // Write a sequence of opcodes with line numbers that demonstrate run-length encoding:
    // Line 1234: Two instructions (CONSTANT 1.2)
    try chunk.writeOpcode(OpCode.CONSTANT, 1234);
    try chunk.writeByte(@intCast(const1), 1234);

    // Line 4567: Three instructions (CONSTANT 3.4)
    try chunk.writeOpcode(OpCode.CONSTANT, 4567);
    try chunk.writeByte(@intCast(const2), 4567);

    // Still line 4567: (CONSTANT 5.6)
    try chunk.writeOpcode(OpCode.CONSTANT, 4567);
    try chunk.writeByte(@intCast(const3), 4567);

    // Back to line 1234: One instruction (RETURN)
    try chunk.writeOpcode(OpCode.RETURN, 1234);

    // Disassemble the chunk to see its contents
    std.debug.print("\nChunk Disassembly:\n", .{});
    chunk.disassemble("main");

    // Print information about the run-length encoding
    std.debug.print("\nRun-Length Encoding Info:\n", .{});
    std.debug.print("Total instructions: {d}\n", .{chunk.lines.count()});
    std.debug.print("Number of runs: {d}\n", .{chunk.lines.runs.items.len});
    for (chunk.lines.runs.items, 0..) |run, i| {
        std.debug.print("Run {d}: {d} instructions from line {d}\n", .{ i + 1, run.count, run.line });
    }

    // Create and initialize a VM with tracing enabled
    var vm = VM.init(&chunk, true);
    defer vm.deinit();

    // Interpret the chunk
    std.debug.print("\nInterpreting Chunk:\n", .{});
    const result = vm.interpret();
    std.debug.print("\nInterpretation result: {}\n", .{result});
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
    try chunk.writeOpcode(OpCode.CONSTANT, 123);
    try chunk.writeByte(@intCast(const1), 123);
    try chunk.writeOpcode(OpCode.CONSTANT, 456);
    try chunk.writeByte(@intCast(const2), 456);
    try chunk.writeOpcode(OpCode.RETURN, 456);

    // Verify code length (5 bytes total: CONSTANT + index1 + CONSTANT + index2 + RETURN)
    try std.testing.expectEqual(@as(usize, 5), chunk.code.len());
    try std.testing.expectEqual(@as(u32, 5), chunk.lines.count());

    // Verify constants
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.at(0).?);
    try std.testing.expectEqual(@as(f64, 3.4), chunk.constants.at(1).?);

    // Verify line numbers
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(0).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(1).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(2).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(3).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(4).?);

    // Verify run-length encoding
    try std.testing.expectEqual(@as(usize, 2), chunk.lines.runs.items.len);
    try std.testing.expectEqual(@as(u32, 2), chunk.lines.runs.items[0].count);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.runs.items[0].line);
    try std.testing.expectEqual(@as(u32, 3), chunk.lines.runs.items[1].count);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.runs.items[1].line);

    // Test VM interpretation
    var vm = VM.init(&chunk, false);
    defer vm.deinit();
    try std.testing.expectEqual(root.InterpretResult.INTERPRET_OK, vm.interpret());
}
