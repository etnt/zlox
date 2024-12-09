const std = @import("std");
const root = @import("root.zig");
const OpCode = root.OpCode;
const Chunk = root.Chunk;
const VM = root.VM;
const Value = @import("value.zig").Value;
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
    const const1 = try chunk.addConstant(Value.number(2.0));
    const const2 = try chunk.addConstant(Value.number(3.4));
    const const3 = try chunk.addConstant(Value.boolean(true));

    // Write a sequence of opcodes with line numbers that demonstrate run-length encoding:
    try chunk.writeOpcode(OpCode.CONSTANT, 1234);
    try chunk.writeByte(@intCast(const1), 1234);

    try chunk.writeOpcode(OpCode.CONSTANT, 4567);
    try chunk.writeByte(@intCast(const2), 4567);

    try chunk.writeOpcode(OpCode.NEGATE, 4567);

    try chunk.writeOpcode(OpCode.CONSTANT, 4567);
    try chunk.writeByte(@intCast(const3), 4567);

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
    var vm = VM.init(&chunk, true, allocator);
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
    const const1 = try chunk.addConstant(Value.number(1.2));
    const const2 = try chunk.addConstant(Value.number(3.4));
    const const3 = try chunk.addConstant(Value.boolean(true));
    try std.testing.expectEqual(@as(usize, 0), const1);
    try std.testing.expectEqual(@as(usize, 1), const2);
    try std.testing.expectEqual(@as(usize, 2), const3);

    // Write opcodes with their operands
    try chunk.writeOpcode(OpCode.CONSTANT, 123);
    try chunk.writeByte(@intCast(const1), 123);
    try chunk.writeOpcode(OpCode.CONSTANT, 456);
    try chunk.writeByte(@intCast(const2), 456);
    try chunk.writeOpcode(OpCode.CONSTANT, 456);
    try chunk.writeByte(@intCast(const3), 456);
    try chunk.writeOpcode(OpCode.RETURN, 456);

    // Verify code length (7 bytes total)
    try std.testing.expectEqual(@as(usize, 7), chunk.code.len());
    try std.testing.expectEqual(@as(u32, 7), chunk.lines.count());

    // Verify constants
    if (chunk.constants.at(0)) |val| {
        try std.testing.expectEqual(Value.number(1.2), val);
    }
    if (chunk.constants.at(1)) |val| {
        try std.testing.expectEqual(Value.number(3.4), val);
    }
    if (chunk.constants.at(2)) |val| {
        try std.testing.expectEqual(Value.boolean(true), val);
    }

    // Verify line numbers
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(0).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(1).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(2).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(3).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(4).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(5).?);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.getLine(6).?);

    // Verify run-length encoding
    try std.testing.expectEqual(@as(usize, 2), chunk.lines.runs.items.len);
    try std.testing.expectEqual(@as(u32, 2), chunk.lines.runs.items[0].count);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.runs.items[0].line);
    try std.testing.expectEqual(@as(u32, 5), chunk.lines.runs.items[1].count);
    try std.testing.expectEqual(@as(u32, 456), chunk.lines.runs.items[1].line);

    // Test VM interpretation
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());
}

test "arithmetic calculation" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add constants
    const c1 = try chunk.addConstant(Value.number(2.0));
    const c2 = try chunk.addConstant(Value.number(3.4));
    const c3 = try chunk.addConstant(Value.number(2.6));

    // Setup: (3.4 + 2.6) * 2.0
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c3), 1);

    try chunk.writeOpcode(OpCode.ADD, 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);

    try chunk.writeOpcode(OpCode.MUL, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain the result: (3.4 + 2.6) * 2.0 = 12.0
    const result = try vm.peek(0);
    try std.testing.expectEqual(Value.number(12.0), result);
}

test "arithmetic calculation with unary minus" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add constants
    const c1 = try chunk.addConstant(Value.number(2.0));
    const c2 = try chunk.addConstant(Value.number(3.4));

    // Setup: -2.0 + 3.4
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
    try std.testing.expectEqual(Value.number(1.4), result);
}

test "boolean operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add constants
    const c1 = try chunk.addConstant(Value.boolean(true));
    const c2 = try chunk.addConstant(Value.number(1.0));

    // Load boolean
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);

    // Load number
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain both values
    const bool_val = try vm.peek(1);
    const num_val = try vm.peek(0);
    try std.testing.expectEqual(Value.boolean(true), bool_val);
    try std.testing.expectEqual(Value.number(1.0), num_val);
}
