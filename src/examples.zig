const std = @import("std");
const root = @import("root.zig");
const Chunk = root.Chunk;
const OpCode = root.OpCode;
const Value = root.Value;

pub fn local_variables(allocator: std.mem.Allocator) !Chunk {
    // Create a new chunk
    var chunk = Chunk.init(allocator);

    const pi = try chunk.addConstant(Value.number(3.14159));
    const two = try chunk.addConstant(Value.number(2.0));

    // Define a local variable: let a = π * π
    try chunk.writeOpcode(OpCode.NIL, 100);            // in slot 0, the value is initially null

    try chunk.writeOpcode(OpCode.CONSTANT, 100);       // push the value (π) on the stack
    try chunk.writeByte(@intCast(pi), 100);          // here comes a value (π)

    try chunk.writeOpcode(OpCode.CONSTANT, 100);       // push the value (π) on the stack
    try chunk.writeByte(@intCast(pi), 100);          // here comes a value (π)

    try chunk.writeOpcode(OpCode.MUL, 100);            // multiply the two valuesw

    try chunk.writeOpcode(OpCode.SET_LOCAL, 100);      // the local variable at slot 0 to the result
    try chunk.writeByte(@intCast(0), 100);           // here comes the slot value 0

    // NOTE: SET_LOCAL does not pop the value from the stack
    //       so we need to do that manually here.
    try chunk.writeOpcode(OpCode.POP, 100);

    // Setup: a + 2.0
    try chunk.writeOpcode(OpCode.CONSTANT, 100);       // push the value (2) on the stack
    try chunk.writeByte(@intCast(two), 100);

    try chunk.writeOpcode(OpCode.GET_LOCAL, 100);      // push the local variable at slot 0 onto the stack
    try chunk.writeByte(@intCast(0), 100);

    try chunk.writeOpcode(OpCode.ADD, 100); 
    try chunk.writeOpcode(OpCode.PRINT, 100); 

    try chunk.writeOpcode(OpCode.RETURN, 101);

    return chunk;
}


pub fn assignment(allocator: std.mem.Allocator) !Chunk {
    // Create a new chunk
    var chunk = Chunk.init(allocator);

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