const std = @import("std");
const root = @import("root.zig");
const Chunk = root.Chunk;
const OpCode = root.OpCode;
const Value = root.Value;

pub fn function_sum(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);
    var sumChunk = Chunk.init(allocator);

    // ---------------------------
    // fun sum(a, b, c) {
    //   return a + b + c;
    // }
    // print 4 + sum(5, 6, 7);
    // ---------------------------

    // Create the number constants
    const four = try chunk.addConstant(Value.number(4.0));
    const five = try chunk.addConstant(Value.number(5.0));
    const six = try chunk.addConstant(Value.number(6.0));
    const seven = try chunk.addConstant(Value.number(7.0));

    // --- Begin of sum Chunk
    // Load a
    try sumChunk.writeOpcode(OpCode.GET_LOCAL, 1);
    try sumChunk.writeByte(@intCast(1), 1); // Correct slot index for 'a'
    // Load b
    try sumChunk.writeOpcode(OpCode.GET_LOCAL, 1);
    try sumChunk.writeByte(@intCast(2), 1); // Correct slot index for 'b'
    // (a + b)
    try sumChunk.writeOpcode(OpCode.ADD, 1);
    // Load c
    try sumChunk.writeOpcode(OpCode.GET_LOCAL, 1);
    try sumChunk.writeByte(@intCast(3), 1); // Correct slot index for 'c'
    // (a + b) + c
    try sumChunk.writeOpcode(OpCode.ADD, 1);

    // Return from the sum function
    try sumChunk.writeOpcode(OpCode.RETURN, 1);
    // --- End of sum Chunk

    // Create the sum function
    const sumFun = try Value.createFunction(allocator, "sum", 3, sumChunk);
    const sum = try chunk.addConstant(sumFun);


    // --- Begin Top Level Chunk
    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Push the number 4 onto the stack
    try chunk.writeOpcode(OpCode.CONSTANT, 4);
    try chunk.writeByte(@intCast(four), 4);

    // Push the sum function reference onto the stack
    try chunk.writeOpcode(OpCode.CONSTANT, 4);
    try chunk.writeByte(@intCast(sum), 4);

    // Push the function arguments (5,6,7) onto the stack
    try chunk.writeOpcode(OpCode.CONSTANT, 4);
    try chunk.writeByte(@intCast(five), 4);
    try chunk.writeOpcode(OpCode.CONSTANT, 4);
    try chunk.writeByte(@intCast(six), 4);
    try chunk.writeOpcode(OpCode.CONSTANT, 4);
    try chunk.writeByte(@intCast(seven), 4);

    // Call the sum function
    try chunk.writeOpcode(OpCode.CALL, 4);
    try chunk.writeByte(@intCast(3), 4);   // argCount == 3

    // Perform the top-level addition
    try chunk.writeOpcode(OpCode.ADD, 4);

    // Print the result!
    try chunk.writeOpcode(OpCode.PRINT, 4);

    try chunk.writeOpcode(OpCode.RETURN, 4);
    // --- End Top Level Chunk

    return chunk;
}

pub fn function_factorial(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);
    var facChunk = Chunk.init(allocator);

    // ---------------------------
    // fun fac(n) {
    //   if (n == 0) then
    //     return 1
    //   else
    //     return n * fac(n - 1)
    // }
    // print fac(5);
    // ---------------------------

    // Create the number constants for the factorial function
    const zero = try facChunk.addConstant(Value.number(0.0));
    const one = try facChunk.addConstant(Value.number(1.0));

    // --- Begin of factorial Chunk
    // Load n (slot 1 is the argument)
    try facChunk.writeOpcode(OpCode.GET_LOCAL, 1);
    try facChunk.writeByte(@intCast(1), 1);

    // Push 0 for comparison
    try facChunk.writeOpcode(OpCode.CONSTANT, 1);
    try facChunk.writeByte(@intCast(zero), 1);

    // Compare n == 0
    try facChunk.writeOpcode(OpCode.EQUAL, 1);

    // If false (n != 0), jump to else part
    try facChunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try facChunk.writeByte(0, 1);            // MSB of jump offset
    try facChunk.writeByte(4, 1);            // LSB of jump offset (skip the then part)

    // Then part: return 1
    try facChunk.writeOpcode(OpCode.POP, 1);  // Pop the comparison result
    try facChunk.writeOpcode(OpCode.CONSTANT, 1);
    try facChunk.writeByte(@intCast(one), 1);
    try facChunk.writeOpcode(OpCode.RETURN, 1);

    // Else part: return n * fac(n - 1)
    try facChunk.writeOpcode(OpCode.POP, 1);  // Pop the comparison result

    // Get the function
    try facChunk.writeOpcode(OpCode.GET_LOCAL, 1);
    try facChunk.writeByte(@intCast(0), 1);

    // Get n and calculate n-1
    try facChunk.writeOpcode(OpCode.GET_LOCAL, 1);
    try facChunk.writeByte(@intCast(1), 1);
    try facChunk.writeOpcode(OpCode.CONSTANT, 1);
    try facChunk.writeByte(@intCast(one), 1);
    try facChunk.writeOpcode(OpCode.SUB, 1);

    // Call fac(n-1)
    try facChunk.writeOpcode(OpCode.CALL, 1);
    try facChunk.writeByte(@intCast(1), 1);

    // Get n for multiplication
    try facChunk.writeOpcode(OpCode.GET_LOCAL, 1);
    try facChunk.writeByte(@intCast(1), 1);

    // Multiply n * fac(n-1)
    try facChunk.writeOpcode(OpCode.MUL, 1);

    try facChunk.writeOpcode(OpCode.RETURN, 1);
    // --- End of factorial Chunk

    // Create the factorial function
    const facFun = try Value.createFunction(allocator, "fac", 1, facChunk);
    const fac = try chunk.addConstant(facFun);

    // Create constant for test value
    const five = try chunk.addConstant(Value.number(5.0));

    // --- Begin Top Level Chunk
    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Push the factorial function reference onto the stack
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(fac), 1);

    // Push the argument (5) onto the stack
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(five), 1);

    // Call the factorial function
    try chunk.writeOpcode(OpCode.CALL, 1);
    try chunk.writeByte(@intCast(1), 1);   // argCount == 1

    // Print the result!
    try chunk.writeOpcode(OpCode.PRINT, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);
    // --- End Top Level Chunk

    return chunk;
}
