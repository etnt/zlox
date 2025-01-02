const std = @import("std");
const root = @import("root.zig");
const Chunk = root.Chunk;
const OpCode = root.OpCode;
const Value = root.Value;
const VM = root.VM;
const vm_mod = @import("vm.zig");

const InterpretResult = vm_mod.InterpretResult;

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

    // Create the sum function and wrap it in a closure
    const sumFun = try Value.createFunction(allocator, "sum", 3, sumChunk);
    // Create an empty upvalue array since sum doesn't use any upvalues
    var upvalues = std.ArrayList(Value).init(allocator);
    defer upvalues.deinit();
    const sumClosure = try Value.createClosure(allocator, sumFun.function.?, upvalues.items);
    const sum = try chunk.addConstant(sumClosure);

    // --- Begin Top Level Chunk
    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Push the number 4 onto the stack
    try chunk.writeOpcode(OpCode.CONSTANT, 4);
    try chunk.writeByte(@intCast(four), 4);

    // Push the sum closure reference onto the stack
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
    try chunk.writeByte(@intCast(3), 4); // argCount == 3

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
    try facChunk.writeByte(0, 1); // MSB of jump offset
    try facChunk.writeByte(4, 1); // LSB of jump offset (skip the then part)

    // Then part: return 1
    try facChunk.writeOpcode(OpCode.POP, 1); // Pop the comparison result
    try facChunk.writeOpcode(OpCode.CONSTANT, 1);
    try facChunk.writeByte(@intCast(one), 1);
    try facChunk.writeOpcode(OpCode.RETURN, 1);

    // Else part: return n * fac(n - 1)
    try facChunk.writeOpcode(OpCode.POP, 1); // Pop the comparison result

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
    try facChunk.writeByte(@intCast(1), 1);  // Fixed: use facChunk instead of chunk

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
    try chunk.writeByte(@intCast(1), 1); // argCount == 1

    // Print the result!
    try chunk.writeOpcode(OpCode.PRINT, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);
    // --- End Top Level Chunk

    return chunk;
}

/// Native function that returns the current time in seconds since epoch
fn clock(args: []Value) Value {
    _ = args; // Native function takes no arguments
    const seconds = @as(f64, @floatFromInt(std.time.timestamp()));
    return Value.number(seconds);
}

/// Native function that sleeps for the specified number of seconds
fn sleep(args: []Value) Value {
    if (args.len != 1 or args[0] != .number) {
        return Value.nil();
    }
    const seconds = args[0].number;
    const nanoseconds = @as(u64, @intFromFloat(seconds * std.time.ns_per_s));
    std.time.sleep(nanoseconds);
    return Value.nil();
}

/// Example that demonstrates native function calls
pub fn function_native_clock(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);

    // ---------------------------
    // t1 = clock();
    // sleep(2);
    // t2 = clock();
    // print t2 - t1;
    // ---------------------------

    // Create the native functions
    const clock_native = try Value.createNativeFunction(allocator, "clock", clock, 0);
    const sleep_native = try Value.createNativeFunction(allocator, "sleep", sleep, 1);
    const clock_const = try chunk.addConstant(clock_native);
    const sleep_const = try chunk.addConstant(sleep_native);
    const two = try chunk.addConstant(Value.number(2.0));

    // --- Begin Top Level Chunk
    // Allocate slot 0 (= "script" , i.e the top-level) on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Allocate slot 1 (= "t1") on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Allocate slot 2 (= "t2") on the stack
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Get first timestamp (t1) and store in local variable slot 1
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(clock_const), 1);
    try chunk.writeOpcode(OpCode.CALL, 1);
    try chunk.writeByte(@intCast(0), 1);  // 0 arguments
    try chunk.writeOpcode(OpCode.SET_LOCAL, 1);
    try chunk.writeByte(@intCast(1), 1);  // Store in slot 1
    try chunk.writeOpcode(OpCode.POP, 1);  // Clean up stack

    // Sleep for 2 seconds
    try chunk.writeOpcode(OpCode.CONSTANT, 2);
    try chunk.writeByte(@intCast(sleep_const), 2);
    try chunk.writeOpcode(OpCode.CONSTANT, 2);
    try chunk.writeByte(@intCast(two), 2);
    try chunk.writeOpcode(OpCode.CALL, 2);
    try chunk.writeByte(@intCast(1), 2);  // 1 argument
    try chunk.writeOpcode(OpCode.POP, 2);  // Pop nil return value

    // Get second timestamp (t2)
    try chunk.writeOpcode(OpCode.CONSTANT, 3);
    try chunk.writeByte(@intCast(clock_const), 3);
    try chunk.writeOpcode(OpCode.CALL, 3);
    try chunk.writeByte(@intCast(0), 3);  // 0 arguments
    // Store in local variable slot 2
    try chunk.writeOpcode(OpCode.SET_LOCAL, 3);
    try chunk.writeByte(@intCast(2), 3);  // Store in slot 2
    try chunk.writeOpcode(OpCode.POP, 3);  // Clean up stack

    // Get t2 from local variable
    try chunk.writeOpcode(OpCode.GET_LOCAL, 4);
    try chunk.writeByte(@intCast(2), 4);  // Load from slot 2

    // Get t1 from local variable
    try chunk.writeOpcode(OpCode.GET_LOCAL, 4);
    try chunk.writeByte(@intCast(1), 4);  // Load from slot 1

    // Calculate t2 - t1
    try chunk.writeOpcode(OpCode.SUB, 4);

    // Print the result
    try chunk.writeOpcode(OpCode.PRINT, 4);

    try chunk.writeOpcode(OpCode.RETURN, 4);
    // --- End Top Level Chunk

    return chunk;
}

test "function sum" {
    var chunk = try function_sum(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "function factorial" {
    var chunk = try function_factorial(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}

test "function native clock" {
    var chunk = try function_native_clock(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());  
}