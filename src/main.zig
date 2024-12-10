const std = @import("std");
const root = @import("root.zig");
const OpCode = root.OpCode;
const Chunk = root.Chunk;
const VM = root.VM;
const Value = @import("value.zig").Value;
const vm_mod = @import("vm.zig");
const InterpretResult = vm_mod.InterpretResult;
const obj = @import("object.zig");

pub fn main() !void {
    // Get a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new chunk that can store both opcodes and constants
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    // Add number constants to our chunk
    const const1 = try chunk.addConstant(Value.number(2.0));
    const const2 = try chunk.addConstant(Value.number(3.4));

    // Create and add string constants
    // Note: Don't deinit strings after adding to chunk - the chunk owns them now
    const hello = try chunk.addConstant(try Value.createString(allocator, "Hello"));
    const world = try chunk.addConstant(try Value.createString(allocator, " World!"));

    // Write a sequence of opcodes with line numbers that demonstrate run-length encoding:
    try chunk.writeOpcode(OpCode.CONSTANT, 1234);
    try chunk.writeByte(@intCast(const1), 1234);

    try chunk.writeOpcode(OpCode.CONSTANT, 4567);
    try chunk.writeByte(@intCast(const2), 4567);

    try chunk.writeOpcode(OpCode.NEGATE, 4567);
    try chunk.writeOpcode(OpCode.ADD, 4567);

    // Use TRUE and FALSE opcodes directly
    try chunk.writeOpcode(OpCode.TRUE, 4567);
    try chunk.writeOpcode(OpCode.FALSE, 4567);
    try chunk.writeOpcode(OpCode.AND, 4567);

    // Concatenate two strings
    try chunk.writeOpcode(OpCode.CONSTANT, 5998);
    try chunk.writeByte(@intCast(hello), 5998);
    try chunk.writeOpcode(OpCode.CONSTANT, 5998);
    try chunk.writeByte(@intCast(world), 5998);
    try chunk.writeOpcode(OpCode.ADD, 5998);
    try chunk.writeOpcode(OpCode.PRINT, 5999);

    // Global variable: myvar = null
    const myvar = try chunk.addConstant(try Value.createString(allocator, "myvar"));
    const e = try chunk.addConstant(Value.number(2.71828));
    try chunk.writeOpcode(OpCode.NIL, 6060);           // the value is null
    try chunk.writeOpcode(OpCode.CONSTANT, 6060);      // the name is a constant
    try chunk.writeByte(@intCast(myvar), 6060);      // the name of the variable
    try chunk.writeOpcode(OpCode.DEFINE_GLOBAL, 6060); // define the global variable
    // Assign value to the global variable: myvar = 2.71828
    try chunk.writeOpcode(OpCode.CONSTANT, 6061);
    try chunk.writeByte(@intCast(e), 6061);
    try chunk.writeOpcode(OpCode.CONSTANT, 6061);
    try chunk.writeByte(@intCast(myvar), 6061);
    try chunk.writeOpcode(OpCode.SET_GLOBAL, 6061);

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

    // Print the global variables
    std.debug.print("\nGlobal Variables:\n", .{});
    vm.printGlobals();
}

test "global variables" {
    // Initialize with testing allocator
    const allocator = std.testing.allocator;

    // Clean up intern pool at the start and end of test
    obj.deinitInternPool();
    defer obj.deinitInternPool();

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    // Global variable: myvar = null
    const myvar = try chunk.addConstant(try Value.createString(allocator, "myvar"));
    const e = try chunk.addConstant(Value.number(2.71828));
    try chunk.writeOpcode(OpCode.NIL, 6060);           // the value is null
    try chunk.writeOpcode(OpCode.CONSTANT, 6060);      // the name is a constant
    try chunk.writeByte(@intCast(myvar), 6060);      // the name of the variable
    try chunk.writeOpcode(OpCode.DEFINE_GLOBAL, 6060); // define the global variable
    // Assign value to the global variable: myvar = 2.71828
    try chunk.writeOpcode(OpCode.CONSTANT, 6061);
    try chunk.writeByte(@intCast(e), 6061);
    try chunk.writeOpcode(OpCode.CONSTANT, 6061);
    try chunk.writeByte(@intCast(myvar), 6061);
    try chunk.writeOpcode(OpCode.SET_GLOBAL, 6061);

    try chunk.writeOpcode(OpCode.RETURN, 6061);

    // Create and initialize a VM with tracing enabled
    var vm = VM.init(&chunk, false, allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());
    try std.testing.expectEqual(Value.number(2.71828), vm.globals.get("myvar").?);
}

test "chunk with constants" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add number constants
    const const1 = try chunk.addConstant(Value.number(1.2));
    const const2 = try chunk.addConstant(Value.number(3.4));
    try std.testing.expectEqual(@as(usize, 0), const1);
    try std.testing.expectEqual(@as(usize, 1), const2);

    // Write opcodes with their operands
    try chunk.writeOpcode(OpCode.CONSTANT, 123);
    try chunk.writeByte(@intCast(const1), 123);
    try chunk.writeOpcode(OpCode.CONSTANT, 456);
    try chunk.writeByte(@intCast(const2), 456);
    try chunk.writeOpcode(OpCode.TRUE, 456);  // Use TRUE opcode directly
    try chunk.writeOpcode(OpCode.RETURN, 456);

    // Verify code length (6 bytes total: 2 for each CONSTANT+idx, 1 for TRUE, 1 for RETURN)
    try std.testing.expectEqual(@as(usize, 6), chunk.code.len());
    try std.testing.expectEqual(@as(u32, 6), chunk.lines.count());

    // Verify constants
    if (chunk.constants.at(0)) |val| {
        try std.testing.expectEqual(Value.number(1.2), val);
    }
    if (chunk.constants.at(1)) |val| {
        try std.testing.expectEqual(Value.number(3.4), val);
    }

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

test "boolean operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Test AND operation (true AND false = false)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.AND, 1);

    // Test OR operation (false OR true = true)
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.OR, 1);

    // Test NOT operation (NOT true = false)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.NOT, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain three results:
    // [false, true, false]
    const not_result = try vm.peek(0);
    const or_result = try vm.peek(1);
    const and_result = try vm.peek(2);

    try std.testing.expectEqual(Value.boolean(false), not_result);
    try std.testing.expectEqual(Value.boolean(true), or_result);
    try std.testing.expectEqual(Value.boolean(false), and_result);
}

// To run only this test: zig test src/main.zig  --test-filter "mixed operations"
test "mixed operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add number constant
    const num = try chunk.addConstant(Value.number(1.0));

    // Try to perform arithmetic on a boolean (should fail)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(num), 1);
    try chunk.writeOpcode(OpCode.ADD, 1);

    // Create VM and interpret
    // NOTE: This may produce some debug output warning about wrong type of operands
    //       but that is what we want to test here, i.e we expect a runtime error.
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_RUNTIME_ERROR, vm.interpret());
}
