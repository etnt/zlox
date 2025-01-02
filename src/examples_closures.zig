const std = @import("std");
const root = @import("root.zig");
const Chunk = root.Chunk;
const OpCode = root.OpCode;
const Value = root.Value;
const VM = root.VM;
const vm_mod = @import("vm.zig");

const InterpretResult = vm_mod.InterpretResult;

pub fn simple_closure(allocator: std.mem.Allocator) !Chunk {
    const chunk = try Chunk.init(allocator);
    //var closureChunk = Chunk.init(allocator);

    // ---------------------------
    // {
    //   var a = 3;
    //   fun f() {
    //     print a;
    //   }
    // }
    // ---------------------------

    // Create the function
    //const sumFun = try Value.createFunction(allocator, "f", 0, sumChunk);
    //const sum = try chunk.addConstant(sumFun);

    return chunk;
}