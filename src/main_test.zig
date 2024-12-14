const std = @import("std");
const root = @import("root.zig");
const OpCode = root.OpCode;
const Chunk = root.Chunk;
const VM = root.VM;
const Value = root.Value;
const vm_mod = @import("vm.zig");
const InterpretResult = vm_mod.InterpretResult;
const utils = @import("utils.zig");


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

test "conditional jumps" {
    const allocator = std.testing.allocator;
    const ex_hdr ="Conditional Jumps";
    const ex_name = "conditional jumps";

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    // Test with false boolean (should jump)
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);  // MSB of jump offset
    try chunk.writeByte(1, 1);  // LSB of jump offset (skip next instruction)
    try chunk.writeOpcode(OpCode.TRUE, 1);  // This should be skipped
    try chunk.writeOpcode(OpCode.FALSE, 1); // We should jump here

    // Test with another false boolean (should jump)
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);  // MSB of jump offset
    try chunk.writeByte(1, 1);  // LSB of jump offset (skip next instruction)
    try chunk.writeOpcode(OpCode.TRUE, 1);  // This should be skipped
    try chunk.writeOpcode(OpCode.FALSE, 1); // We should jump here

    // Test with true boolean (should not jump)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);  // MSB of jump offset
    try chunk.writeByte(1, 1);  // LSB of jump offset (skip next instruction)
    try chunk.writeOpcode(OpCode.TRUE, 1);  // This should NOT be skipped
    try chunk.writeOpcode(OpCode.FALSE, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Disassemble the chunk to see its contents
    const ex_header = try std.fmt.allocPrint(allocator, "{s}{s}", .{ ex_hdr, ex_name });
    defer allocator.free(ex_header);
    std.debug.print("\nChunk Disassembly:\n", .{});
    chunk.disassemble(ex_header);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain the results of our jumps
    // [false, false, true, false]
    const result4 = try vm.peek(0);  // Last pushed value
    const result3 = try vm.peek(1);  // Result of true test (should be true)
    const result2 = try vm.peek(2);  // Result of false test (should be false)
    const result1 = try vm.peek(3);  // Result of false test (should be false)

    try std.testing.expectEqual(Value.boolean(false), result1);  // false test jumped
    try std.testing.expectEqual(Value.boolean(true), result2);  // false test jumped
    try std.testing.expectEqual(Value.boolean(true), result3);   // true didn't jump
    try std.testing.expectEqual(Value.boolean(false), result4);  // last value pushed
}


test "if gt than" {
    // Initialize with testing allocator
    const allocator = std.testing.allocator;

    var chunk = Chunk.init(allocator);
    defer {
        utils.debugPrintln(@src(),"Deinit Chunk...", .{});
        chunk.deinit();
    }

    // Add constants
    const c1 = try chunk.addConstant(Value.number(3.0));
    const c2 = try chunk.addConstant(Value.number(7.0));

    const yes = try Value.createString(allocator, "Yes");
    const no = try Value.createString(allocator, "No");

    const cyes = try chunk.addConstant(yes);
    const cno = try chunk.addConstant(no);


    // Setup instructions for: if (3.0 > 7.0) then print("yes") else print("no")
    try chunk.writeOpcode(OpCode.CONSTANT, 10);
    try chunk.writeByte(@intCast(c1), 10);

    try chunk.writeOpcode(OpCode.CONSTANT, 10);
    try chunk.writeByte(@intCast(c2), 10);

    try chunk.writeOpcode(OpCode.GREATER, 10);

    // If False, jump 7 bytes: (POP + CONSTANT + byte + PRINT +JUMP + 2 bytes)
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 10);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(7, 1);            // LSB of jump offset

    // Load the string "yes", print it, jump to the end of the if expression
    // Jump 4 bytes: (POP + CONSTANT + byte + PRINT)
    try chunk.writeOpcode(OpCode.POP, 10);
    try chunk.writeOpcode(OpCode.CONSTANT, 11);
    try chunk.writeByte(@intCast(cyes), 11);
    try chunk.writeOpcode(OpCode.PRINT, 11);
    try chunk.writeOpcode(OpCode.JUMP, 11);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(4, 1);            // LSB of jump offset

    // Load the string "no" onto the stack
    try chunk.writeOpcode(OpCode.POP, 10);
    try chunk.writeOpcode(OpCode.CONSTANT, 12);
    try chunk.writeByte(@intCast(cno), 12);
    try chunk.writeOpcode(OpCode.PRINT, 12);

    try chunk.writeOpcode(OpCode.RETURN, 12);

    // Create and initialize a VM with tracing enabled
    var vm = VM.init(&chunk, false, allocator);
    defer {
        utils.debugPrintln(@src(),"Deinit VM...", .{});
        vm.deinit();
    }

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());
}
