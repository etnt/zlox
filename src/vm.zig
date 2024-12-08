const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("opcodes.zig").OpCode;
const Value = @import("value.zig").Value;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *Chunk,           // Chunk to interpret
    ip: [*]u8,              // Instruction pointer
    trace: bool = false,     // Enable tracing
    allocator: std.mem.Allocator, // Allocator for dynamic memory

    stack: std.ArrayList(Value), // Dynamic stack
    
    /// Initialize a new VM with a pre-existing chunk
    pub fn init(chunk: *Chunk, trace: bool, allocator: std.mem.Allocator) VM {
        return VM{
            .chunk = chunk,
            .ip = chunk.code.bytes.items.ptr,
            .trace = trace,
            .allocator = allocator,
            .stack = std.ArrayList(Value).init(allocator),
        };
    }

    /// Free the VM (does not free the chunk as it's managed elsewhere)
    pub fn deinit(self: *VM) void {
        self.stack.deinit();
        self.* = undefined;
    }

    /// Reset the stack
    pub fn resetStack(self: *VM) void {
        self.stack.clearRetainingCapacity();
    }

    /// Push a value onto the stack
    pub fn push(self: *VM, value: Value) !void {
        try self.stack.append(value);
    }

    /// Pop a value from the stack
    pub fn pop(self: *VM) !Value {
        if (self.stack.items.len == 0) {
            return error.StackUnderflow;
        }
        return self.stack.pop();
    }

    /// Peek at the top value without removing it
    pub fn peek(self: *VM, distance: usize) !Value {
        if (distance >= self.stack.items.len) {
            return error.StackUnderflow;
        }
        return self.stack.items[self.stack.items.len - 1 - distance];
    }

    /// Print the current contents of the stack
    pub fn printStack(self: *VM) void {
        std.debug.print("          ", .{});
        if (self.stack.items.len == 0) {
            std.debug.print("[]", .{});
        } else {
            std.debug.print("[ ", .{});
            for (self.stack.items, 0..) |value, i| {
                if (i > 0) std.debug.print("| ", .{});
                std.debug.print("{d} ", .{value});
            }
            std.debug.print("]", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn interpret(self: *VM) InterpretResult {
        self.ip = self.chunk.code.bytes.items.ptr;
        return self.run();
    }

    fn binary_op(self: *VM, comptime op: fn (Value, Value) Value) InterpretResult {
        const right = self.pop() catch |err| {
            std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };
        const left = self.pop() catch |err| {
            std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };
        self.push(op(left, right)) catch |err| {
            std.debug.print("Error pushing constant: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };
        return InterpretResult.INTERPRET_OK;
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
                OpCode.ADD => {
                    const result = self.binary_op(struct {
                        fn op(a: Value, b: Value) Value {
                            return a + b;
                        }
                    }.op);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.SUB => {
                    const result = self.binary_op(struct {
                        fn op(a: Value, b: Value) Value {
                            return a - b;
                        }
                    }.op);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.MUL => {
                    const result = self.binary_op(struct {
                        fn op(a: Value, b: Value) Value {
                            return a * b;
                        }
                    }.op);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.DIV => {
                    const result = self.binary_op(struct {
                        fn op(a: Value, b: Value) Value {
                            return a / b;
                        }
                    }.op);
                    if (result != InterpretResult.INTERPRET_OK) return result;
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
                    // Don't pop the final value, just return success
                    // This allows tests to examine the final result
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
