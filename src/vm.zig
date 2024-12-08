const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("opcodes.zig").OpCode;
const Value = @import("value.zig").Value;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

// Stack size should be large enough for most operations but not excessive
const STACK_MAX = 256;

pub const VM = struct {
    chunk: *Chunk,           // Chunk to interpret
    ip: [*]u8,              // Instruction pointer
    trace: bool = false,     // Enable tracing

    stack: [STACK_MAX]Value, // Fixed-size stack array
    stack_top: usize,        // Points to next free slot

    /// Initialize a new VM with a pre-existing chunk
    pub fn init(chunk: *Chunk, trace: bool) VM {
        return VM{
            .chunk = chunk,
            .ip = chunk.code.bytes.items.ptr,
            .trace = trace,
            .stack = undefined,
            .stack_top = 0,
        };
    }

    /// Free the VM (does not free the chunk as it's managed elsewhere)
    pub fn deinit(self: *VM) void {
        // The chunk is owned and freed elsewhere
        self.* = undefined;
    }

    /// Reset the stack
    pub fn resetStack(self: *VM) void {
        self.stack_top = 0;
    }

    /// Push a value onto the stack
    pub fn push(self: *VM, value: Value) !void {
        if (self.stack_top >= STACK_MAX) {
            return error.StackOverflow;
        }
        self.stack[self.stack_top] = value;
        self.stack_top += 1;
    }

    /// Pop a value from the stack
    pub fn pop(self: *VM) !Value {
        if (self.stack_top == 0) {
            return error.StackUnderflow;
        }
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    /// Peek at the top value without removing it
    pub fn peek(self: *VM, distance: usize) !Value {
        const index = self.stack_top - 1 - distance;
        if (index >= self.stack_top) {
            return error.StackUnderflow;
        }
        return self.stack[index];
    }

    /// Print the current contents of the stack
    pub fn printStack(self: *VM) void {
        std.debug.print("          ", .{});
        if (self.stack_top == 0) {
            std.debug.print("[]", .{});
        } else {
            std.debug.print("[ ", .{});
            var i: usize = 0;
            while (i < self.stack_top) : (i += 1) {
                if (i > 0) std.debug.print("| ", .{});
                std.debug.print("{d} ", .{self.stack[i]});
            }
            std.debug.print("]", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn interpret(self: *VM) InterpretResult {
        self.ip = self.chunk.code.bytes.items.ptr;
        return self.run();
    }

    fn run(self: *VM) InterpretResult {
        while (true) {
            if (self.trace) {
                // Print the stack before each instruction
                self.printStack();
                const offset = @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.bytes.items.ptr);
                _ = self.chunk.disassembleInstruction(offset);
            }

            const opcode = self.ip[0];
            self.ip += 1;

            switch (opcode) {
                OpCode.CONSTANT => {
                    self.push(self.chunk.constants.at(self.ip[0]).?) catch |err| {
                        std.debug.print("Error pushing constant: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    self.ip += 1;
                },
                OpCode.NEGATE => {
                    const value = self.pop() catch |err| {
                        std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    self.push(-value) catch |err| {
                        std.debug.print("Error pushing constant: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.RETURN => {
                    _ = self.pop() catch |err| {
                        std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
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
