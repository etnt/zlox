const std = @import("std");
const root = @import("root.zig");
const Chunk = root.Chunk;
const OpCode = root.OpCode;
const Value = root.Value;
const VM = root.VM;
const vm_mod = @import("vm.zig");

const InterpretResult = vm_mod.InterpretResult;

pub fn local_variables(allocator: std.mem.Allocator) !Chunk {
    // Create a new chunk
    var chunk = Chunk.init(allocator);

    const pi = try chunk.addConstant(Value.number(3.14159));
    const two = try chunk.addConstant(Value.number(2.0));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Define a local variable: let a = π * π
    try chunk.writeOpcode(OpCode.NIL, 100);            // in slot 1, the value is initially null

    try chunk.writeOpcode(OpCode.CONSTANT, 100);       // push the value (π) on the stack
    try chunk.writeByte(@intCast(pi), 100);          // here comes a value (π)

    try chunk.writeOpcode(OpCode.CONSTANT, 100);       // push the value (π) on the stack
    try chunk.writeByte(@intCast(pi), 100);          // here comes a value (π)

    try chunk.writeOpcode(OpCode.MUL, 100);            // multiply the two valuesw

    try chunk.writeOpcode(OpCode.SET_LOCAL, 100);      // the local variable at slot 1 to the result
    try chunk.writeByte(@intCast(1), 100);           // here comes the slot value 1

    // NOTE: SET_LOCAL does not pop the value from the stack
    //       so we need to do that manually here.
    try chunk.writeOpcode(OpCode.POP, 100);

    // Setup: a + 2.0
    try chunk.writeOpcode(OpCode.CONSTANT, 100);       // push the value (2) on the stack
    try chunk.writeByte(@intCast(two), 100);

    try chunk.writeOpcode(OpCode.GET_LOCAL, 100);      // push the local variable at slot 1 onto the stack
    try chunk.writeByte(@intCast(1), 100);

    try chunk.writeOpcode(OpCode.ADD, 100); 
    try chunk.writeOpcode(OpCode.PRINT, 100); 

    try chunk.writeOpcode(OpCode.RETURN, 101);

    return chunk;
}


pub fn assignment(allocator: std.mem.Allocator) !Chunk {
    // Create a new chunk
    var chunk = Chunk.init(allocator);

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Global variable: myvar = 2.71828
    const myvar = try chunk.addConstant(try Value.createString(allocator, "myvar"));
    const e = try chunk.addConstant(Value.number(2.71828));
    try chunk.writeOpcode(OpCode.NIL, 100);             // the value is null
    try chunk.writeOpcode(OpCode.CONSTANT, 100);        // the name is a constant
    try chunk.writeByte(@intCast(myvar), 100);        // the name of the variable
    try chunk.writeOpcode(OpCode.DEFINE_GLOBAL, 100);   // define the global variable

    // Assign value to the global variable: myvar = 2.71828
    try chunk.writeOpcode(OpCode.CONSTANT, 114);
    try chunk.writeByte(@intCast(e), 114);
    try chunk.writeOpcode(OpCode.CONSTANT, 114);
    try chunk.writeByte(@intCast(myvar), 114);
    try chunk.writeOpcode(OpCode.SET_GLOBAL, 114);

    // Print the value of the global variable: print(myvar)
    try chunk.writeOpcode(OpCode.CONSTANT, 115);
    try chunk.writeByte(@intCast(myvar), 115);
    try chunk.writeOpcode(OpCode.GET_GLOBAL, 115);
    try chunk.writeOpcode(OpCode.PRINT, 116);

    try chunk.writeOpcode(OpCode.RETURN, 117);

    return chunk;
}


pub fn concatenate(allocator: std.mem.Allocator) !Chunk {
    // Create a new chunk
    var chunk = Chunk.init(allocator);

    const hello = try chunk.addConstant(try Value.createString(allocator, "Hello"));
    const world = try chunk.addConstant(try Value.createString(allocator, " World!"));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Concatenate two strings: "Hello" + " World!"
    // and print the result.
    try chunk.writeOpcode(OpCode.CONSTANT, 100);
    try chunk.writeByte(@intCast(hello), 100);
    try chunk.writeOpcode(OpCode.CONSTANT, 100);
    try chunk.writeByte(@intCast(world), 100);
    try chunk.writeOpcode(OpCode.ADD, 100);
    try chunk.writeOpcode(OpCode.PRINT, 101);

    try chunk.writeOpcode(OpCode.RETURN, 101);

    return chunk;
}

pub fn arithmetics(allocator: std.mem.Allocator) !Chunk {
    // Create a new chunk
    var chunk = Chunk.init(allocator);

    // Add constants
    const c1 = try chunk.addConstant(Value.number(2.0));
    const c2 = try chunk.addConstant(Value.number(3.4));
    const c3 = try chunk.addConstant(Value.number(2.6));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Compute: (3.4 + 2.6) * 2.0
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c3), 1);

    try chunk.writeOpcode(OpCode.ADD, 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);

    try chunk.writeOpcode(OpCode.MUL, 1);
    try chunk.writeOpcode(OpCode.PRINT, 1);

    try chunk.writeOpcode(OpCode.RETURN, 2);

    return chunk;
}

pub fn if_then_else(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);

    // Add constants
    const c1 = try chunk.addConstant(Value.number(3.0));
    const c2 = try chunk.addConstant(Value.number(7.0));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Setup instructions
    try chunk.writeOpcode(OpCode.FALSE, 1);

    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(5, 1);            // LSB of jump offset (skip next 6 instructions)

    // Do Jump over this part (5 instructions: CONSTANT + byte + JUMP + 2 bytes)
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);
    try chunk.writeOpcode(OpCode.JUMP, 1);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(2, 1);            // LSB of jump offset (skip next 3 instructions)

    // We should land here
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    // Print the result!
    try chunk.writeOpcode(OpCode.PRINT, 1);


    // Now test JUMP_IF_FALSE with different falsey values
    try chunk.writeOpcode(OpCode.TRUE, 1);

    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(5, 1);            // LSB of jump offset (skip next 6 instructions)

    // Do *not* Jump over this part (5 instructions: CONSTANT + byte + JUMP + 2 bytes)
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);
    try chunk.writeOpcode(OpCode.JUMP, 1);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(2, 1);            // LSB of jump offset (skip next 2 instructions)

    // We should jump over these instructions (2 instructions: CONSTANT + byte)
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    // We should land here; print the result!
    try chunk.writeOpcode(OpCode.PRINT, 1);

    try chunk.writeOpcode(OpCode.RETURN, 2);

    return chunk;
}

pub fn if_gt(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);

    // Add constants
    const c1 = try chunk.addConstant(Value.number(3.0));
    const c2 = try chunk.addConstant(Value.number(7.0));

    const yes = try chunk.addConstant(try Value.createString(allocator, "Yes"));
    const no = try chunk.addConstant(try Value.createString(allocator, "No"));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

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
    try chunk.writeByte(@intCast(yes), 11);
    try chunk.writeOpcode(OpCode.PRINT, 11);
    try chunk.writeOpcode(OpCode.JUMP, 11);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(4, 1);            // LSB of jump offset

    // Load the string "no" onto the stack
    try chunk.writeOpcode(OpCode.POP, 10);
    try chunk.writeOpcode(OpCode.CONSTANT, 12);
    try chunk.writeByte(@intCast(no), 12);
    try chunk.writeOpcode(OpCode.PRINT, 12);

    try chunk.writeOpcode(OpCode.RETURN, 12);

    return chunk;
}

pub fn if_lt(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);

    // Add constants
    const c1 = try chunk.addConstant(Value.number(3.0));
    const c2 = try chunk.addConstant(Value.number(7.0));

    const yes = try chunk.addConstant(try Value.createString(allocator, "Yes"));
    const no = try chunk.addConstant(try Value.createString(allocator, "No"));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Setup instructions for: if (3.0 > 7.0) then print("yes") else print("no")
    try chunk.writeOpcode(OpCode.CONSTANT, 10);
    try chunk.writeByte(@intCast(c1), 10);

    try chunk.writeOpcode(OpCode.CONSTANT, 10);
    try chunk.writeByte(@intCast(c2), 10);

    try chunk.writeOpcode(OpCode.LESS, 10);

    // If False, jump 7 bytes: (POP + CONSTANT + byte + PRINT +JUMP + 2 bytes)
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 10);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(7, 1);            // LSB of jump offset

    // Load the string "yes", print it, jump to the end of the if expression
    // Jump 4 bytes: (POP + CONSTANT + byte + PRINT)
    try chunk.writeOpcode(OpCode.POP, 10);
    try chunk.writeOpcode(OpCode.CONSTANT, 11);
    try chunk.writeByte(@intCast(yes), 11);
    try chunk.writeOpcode(OpCode.PRINT, 11);
    try chunk.writeOpcode(OpCode.JUMP, 11);
    try chunk.writeByte(0, 1);            // MSB of jump offset
    try chunk.writeByte(4, 1);            // LSB of jump offset

    // Load the string "no" onto the stack
    try chunk.writeOpcode(OpCode.POP, 10);
    try chunk.writeOpcode(OpCode.CONSTANT, 12);
    try chunk.writeByte(@intCast(no), 12);
    try chunk.writeOpcode(OpCode.PRINT, 12);

    try chunk.writeOpcode(OpCode.RETURN, 12);

    return chunk;
}

pub fn while_loop(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);

    // This example implements a simple loop:
    // a = 3
    // while (a > 0) {
    //     a = a - 1
    //     print a
    // }
    // print "Done!"

    // Add constants
    const three = try chunk.addConstant(Value.number(3.0));
    const one = try chunk.addConstant(Value.number(1.0));
    const zero = try chunk.addConstant(Value.number(0.0));
    const done = try chunk.addConstant(try Value.createString(allocator, "Done!"));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Initialize a = 3 in slot 0
    try chunk.writeOpcode(OpCode.NIL, 1);            // Initialize slot 0
    try chunk.writeOpcode(OpCode.CONSTANT, 1);       // Push 3.0
    try chunk.writeByte(@intCast(three), 1);
    try chunk.writeOpcode(OpCode.SET_LOCAL, 1);      // Set local variable in slot 0
    try chunk.writeByte(@intCast(0), 1);
    try chunk.writeOpcode(OpCode.POP, 1);            // Clean up stack

    // Start of loop (we'll jump back here)
    // Compare a > 0
    const loop_start = chunk.code.len();             // Remember where loop starts
    try chunk.writeOpcode(OpCode.GET_LOCAL, 2);      // Push a
    try chunk.writeByte(@intCast(0), 2);
    try chunk.writeOpcode(OpCode.CONSTANT, 2);       // Push 0
    try chunk.writeByte(@intCast(zero), 2);
    try chunk.writeOpcode(OpCode.GREATER, 2);        // Compare a > 0

    // If false, jump to end of loop
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 2);
    try chunk.writeByte(0, 2);                      // MSB of jump offset
    try chunk.writeByte(15, 2);                     // LSB of jump offset (skip the loop body)
    try chunk.writeOpcode(OpCode.POP, 3);             // Clean up stack

    // Loop body: a = a - 1, print a
    try chunk.writeOpcode(OpCode.GET_LOCAL, 3);      // Push a
    try chunk.writeByte(@intCast(0), 3);
    try chunk.writeOpcode(OpCode.CONSTANT, 3);       // Push 1
    try chunk.writeByte(@intCast(one), 3);
    try chunk.writeOpcode(OpCode.SUB, 3);            // Subtract
    try chunk.writeOpcode(OpCode.SET_LOCAL, 3);      // Store back in a
    try chunk.writeByte(@intCast(0), 3);
    try chunk.writeOpcode(OpCode.GET_LOCAL, 3);      // Push a for printing
    try chunk.writeByte(@intCast(0), 3);
    try chunk.writeOpcode(OpCode.PRINT, 3);          // Print a
    try chunk.writeOpcode(OpCode.POP, 3);            // Clean up stack

    // Jump back to start of loop
    const offset = chunk.code.len() - loop_start + 3;  // +3 for the LOOP instruction and its operands
    try chunk.writeOpcode(OpCode.LOOP, 3);
    try chunk.writeByte(@intCast(offset >> 8), 3);   // MSB of offset
    try chunk.writeByte(@intCast(offset & 0xff), 3); // LSB of offset

    // End of loop: print "Done!"
    try chunk.writeOpcode(OpCode.POP, 4);            // Clean up comparison result
    try chunk.writeOpcode(OpCode.CONSTANT, 4);       // Push "Done!"
    try chunk.writeByte(@intCast(done), 4);
    try chunk.writeOpcode(OpCode.PRINT, 4);          // Print "Done!"

    try chunk.writeOpcode(OpCode.RETURN, 5);

    return chunk;
}

pub fn for_loop(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);

    // This example implements a simple for loop:
    // for (i = 0; i < 3; i = i + 1) {
    //     print i
    // }
    // print "Done!"

    // Add constants
    const zero = try chunk.addConstant(Value.number(0.0));
    const one = try chunk.addConstant(Value.number(1.0));
    const three = try chunk.addConstant(Value.number(3.0));
    const done = try chunk.addConstant(try Value.createString(allocator, "Done!"));

    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Initialize i = 0 in slot 0
    try chunk.writeOpcode(OpCode.NIL, 1);            // Initialize slot 1
    try chunk.writeOpcode(OpCode.CONSTANT, 1);       // Push 0.0
    try chunk.writeByte(@intCast(zero), 1);
    try chunk.writeOpcode(OpCode.SET_LOCAL, 1);      // Set local variable in slot 1
    try chunk.writeByte(@intCast(1), 1);
    try chunk.writeOpcode(OpCode.POP, 1);            // Clean up stack

    // Start of loop (we'll jump back here)
    // Compare i < 10
    const loop_start = chunk.code.len();             // Remember where loop starts
    try chunk.writeOpcode(OpCode.GET_LOCAL, 2);      // Push i
    try chunk.writeByte(@intCast(1), 2);
    try chunk.writeOpcode(OpCode.CONSTANT, 2);       // Push 3
    try chunk.writeByte(@intCast(three), 2);
    try chunk.writeOpcode(OpCode.LESS, 2);           // Compare i < 3

    // If false, jump to end of loop
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 2);
    try chunk.writeByte(0, 2);                      // MSB of jump offset
    try chunk.writeByte(15, 2);                     // LSB of jump offset (skip the loop body)
    try chunk.writeOpcode(OpCode.POP, 3);             // Clean up stack

    // Loop body: print i, i = i + 1
    try chunk.writeOpcode(OpCode.GET_LOCAL, 3);      // Push i for printing
    try chunk.writeByte(@intCast(1), 3);
    try chunk.writeOpcode(OpCode.PRINT, 3);          // Print i
    try chunk.writeOpcode(OpCode.GET_LOCAL, 3);      // Push i
    try chunk.writeByte(@intCast(1), 3);
    try chunk.writeOpcode(OpCode.CONSTANT, 3);       // Push 1
    try chunk.writeByte(@intCast(one), 3);
    try chunk.writeOpcode(OpCode.ADD, 3);            // Add
    try chunk.writeOpcode(OpCode.SET_LOCAL, 3);      // Store back in i
    try chunk.writeByte(@intCast(1), 3);
    try chunk.writeOpcode(OpCode.POP, 3);            // Clean up stack

    // Jump back to start of loop
    const offset = chunk.code.len() - loop_start + 3;  // +3 for the LOOP instruction and its operands
    try chunk.writeOpcode(OpCode.LOOP, 3);
    try chunk.writeByte(@intCast(offset >> 8), 3);   // MSB of offset
    try chunk.writeByte(@intCast(offset & 0xff), 3); // LSB of offset

    // End of loop: print "Done!"
    try chunk.writeOpcode(OpCode.POP, 4);            // Clean up comparison result
    try chunk.writeOpcode(OpCode.CONSTANT, 4);       // Push "Done!"
    try chunk.writeByte(@intCast(done), 4);
    try chunk.writeOpcode(OpCode.PRINT, 4);          // Print "Done!"

    try chunk.writeOpcode(OpCode.RETURN, 5);

    return chunk;
}


test "local variable assignment" {
    var chunk = try local_variables(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "assignment" {
    var chunk = try assignment(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "concatenate" {
    var chunk = try concatenate(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "arithmetics" {
    var chunk = try arithmetics(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "if then else" {
    var chunk = try if_then_else(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "if greater than" {
    var chunk = try if_gt(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "if less than" {
    var chunk = try if_lt(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "while loop" {
    var chunk = try while_loop(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "for loop" {
    var chunk = try for_loop(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
} 
