const std = @import("std");
const root = @import("root.zig");
const OpCode = root.OpCode;
const Chunk = root.Chunk;
const VM = root.VM;
const vm_mod = @import("vm.zig");
const InterpretResult = vm_mod.InterpretResult;

pub fn main() !void {
    // Get a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new chunk that can store both opcodes and constants
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    // Add some constants to our chunk
    const const1 = try chunk.addConstant(2.0);
    const const2 = try chunk.addConstant(3.4);

    // Write a sequence of opcodes with line numbers that demonstrate run-length encoding:
    // Line 1234: Two instructions (CONSTANT 1.2)
    try chunk.writeOpcode(OpCode.CONSTANT, 1234);
    try chunk.writeByte(@intCast(const1), 1234);

    // Line 4567: Three instructions (CONSTANT 3.4)
    try chunk.writeOpcode(OpCode.CONSTANT, 4567);
    try chunk.writeByte(@intCast(const2), 4567);

    // Still line 4567: (CONSTANT 5.6)
    try chunk.writeOpcode(OpCode.NEGATE, 4567);

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

    // ---------------------------------------------------------------------------------------------
    // Test VM interpretation
    // ---------------------------------------------------------------------------------------------

    // Create a new chunk that can store both opcodes and constants
    var code = Chunk.init(allocator);
    defer code.deinit();

    // Add some constants to our code
    const c1 = try code.addConstant(2.0);
    const c2 = try code.addConstant(3.4);
    const c3 = try code.addConstant(2.6);

    // Setup: (X + Y) * Z
    try code.writeOpcode(OpCode.CONSTANT, 2020);
    try code.writeByte(@intCast(c2), 2020);

    try code.writeOpcode(OpCode.CONSTANT, 2020);
    try code.writeByte(@intCast(c3), 2020);

    try code.writeOpcode(OpCode.ADD, 2020);

    try code.writeOpcode(OpCode.CONSTANT, 2020);
    try code.writeByte(@intCast(c1), 2020);

    try code.writeOpcode(OpCode.MUL, 2020);

    try code.writeOpcode(OpCode.CONSTANT, 2020);
    try code.writeByte(@intCast(c1), 2020);

    try code.writeOpcode(OpCode.SUB, 2020);

    try code.writeOpcode(OpCode.RETURN, 2021);

    // Disassemble the chunk to see its contents
    std.debug.print("\nCode Disassembly:\n", .{});
    code.disassemble("main");

    // Create and initialize a VM with tracing enabled
    var vm = VM.init(&code, true, allocator);
    defer vm.deinit();

    // Interpret the code
    std.debug.print("\nInterpreting Code:\n", .{});
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
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());
}

test "arithmetic calculation" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add constants: 2.0, 3.4, 2.6
    const c1 = try chunk.addConstant(2.0);
    const c2 = try chunk.addConstant(3.4);
    const c3 = try chunk.addConstant(2.6);

    // Setup: (3.4 + 2.6) * 2.0
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c3), 1);

    try chunk.writeOpcode(OpCode.ADD, 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);

    try chunk.writeOpcode(OpCode.MUL, 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);

    try chunk.writeOpcode(OpCode.SUB, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain the result: (3.4 + 2.6) * 2.0 - 2.0 = 10.0
    const result = try vm.peek(0);
    try std.testing.expectEqual(@as(f64, 10.0), result);
}

test "arithmetic calculation with unary minus" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add constants: 2.0, 3.4, 2.6
    const c1 = try chunk.addConstant(2.0);
    const c2 = try chunk.addConstant(3.4);

    // Setup: -2.0
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);

    try chunk.writeOpcode(OpCode.NEGATE, 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    try chunk.writeOpcode(OpCode.ADD, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain the result: -2.0 + 3.4 = 1.4
    const result = try vm.peek(0);
    try std.testing.expectEqual(@as(f64, 1.4), result);
}
