const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("opcodes.zig").OpCode;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *Chunk,
    ip: [*]u8, // Instruction pointer
    trace: bool = false,

    /// Initialize a new VM with a pre-existing chunk
    pub fn init(chunk: *Chunk, trace: bool) VM {
        return VM{
            .chunk = chunk,
            .ip = chunk.code.bytes.items.ptr,
            .trace = trace,
        };
    }

    /// Free the VM (does not free the chunk as it's managed elsewhere)
    pub fn deinit(self: *VM) void {
        // The chunk is owned and freed elsewhere
        self.* = undefined;
    }

    pub fn interpret(self: *VM) InterpretResult {
        self.ip = self.chunk.code.bytes.items.ptr;
        return self.run();
    }

    fn run(self: *VM) InterpretResult {
        while (true) {
            const opcode = self.ip[0];
            self.ip += 1;

            switch (opcode) {
                OpCode.CONSTANT => {
                    self.ip += 1;
                    if (self.trace) {
                        const offset = @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.bytes.items.ptr) - 2;
                        _ = self.chunk.disassembleInstruction(offset);
                    }
                },
                OpCode.RETURN => {
                    return InterpretResult.INTERPRET_OK;
                },
                else => {
                    std.debug.print("Unknown opcode {d}\n", .{opcode});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                },
            }
        }
    }
};
