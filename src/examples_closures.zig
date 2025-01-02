const std = @import("std");
const root = @import("root.zig");
const Chunk = root.Chunk;
const OpCode = root.OpCode;
const Value = root.Value;
const VM = root.VM;
const vm_mod = @import("vm.zig");

const InterpretResult = vm_mod.InterpretResult;

pub fn simple_closure(allocator: std.mem.Allocator) !Chunk {
    var chunk = Chunk.init(allocator);
    errdefer chunk.deinit();
    var fChunk = Chunk.init(allocator);
    errdefer fChunk.deinit();

    // ---------------------------
    // {
    //   var a = 3;
    //   fun f() {
    //     print a;
    //   }
    //   f();
    // }
    // ---------------------------

    // Create constant for the value of 'a'
    const three = try chunk.addConstant(Value.number(3.0));

    // --- Begin of inner function 'f' Chunk
    // Get the upvalue 'a'
    try fChunk.writeOpcode(OpCode.GET_UPVALUE, 1);
    try fChunk.writeByte(@intCast(0), 1);  // First (and only) upvalue

    // Print the value
    try fChunk.writeOpcode(OpCode.PRINT, 1);

    // Return nil
    try fChunk.writeOpcode(OpCode.NIL, 1);
    try fChunk.writeOpcode(OpCode.RETURN, 1);
    // --- End of inner function 'f' Chunk

    // Create the function and wrap it in a closure
    const fFun = try Value.createFunction(allocator, "f", 0, fChunk);

    // Create an upvalue array for the closure
    var upvalues = std.ArrayList(Value).init(allocator);
    defer upvalues.deinit();
    // The upvalue will be set later in the bytecode

    const fClosure = try Value.createClosure(allocator, fFun.function.?, upvalues.items);
    const f = try chunk.addConstant(fClosure);

    // --- Begin Top Level Chunk
    // Allocate slot 0 (= "script")
    try chunk.writeOpcode(OpCode.NIL, 1);

    // Initialize local variable 'a' with value 3
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(three), 1);

    // Create the closure for function 'f'
    try chunk.writeOpcode(OpCode.CLOSURE, 1);
    try chunk.writeByte(@intCast(f), 1);
    // Specify that we want to capture the local variable 'a'
    try chunk.writeByte(@intCast(1), 1);  // index of local variable 'a'
    try chunk.writeByte(@intCast(0), 1);  // isLocal = true

    // Call function 'f'
    try chunk.writeOpcode(OpCode.CALL, 1);
    try chunk.writeByte(@intCast(0), 1);  // 0 arguments

    try chunk.writeOpcode(OpCode.RETURN, 1);
    // --- End Top Level Chunk

    return chunk;
}

test "simple closure" {
    var chunk = try simple_closure(std.testing.allocator);
    defer chunk.deinit();

    // Create and initialize a VM with tracing disabled
    var vm = try VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();

    // Do VM interpretation and check result
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());
}