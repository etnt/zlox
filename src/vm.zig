const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("opcodes.zig").OpCode;
const Value = @import("value.zig").Value;
const obj = @import("object.zig");

pub const String = obj.Object.String;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *Chunk,                      // Chunk to interpret
    ip: [*]u8,                          // Instruction pointer
    trace: bool = false,                // Enable tracing
    allocator: std.mem.Allocator,       // Allocator for dynamic memory
    stack: std.ArrayList(Value),        // Dynamic stack
    globals: std.StringHashMap(Value),  // Global variables

    /// Initialize a new VM with a pre-existing chunk
    pub fn init(chunk: *Chunk, trace: bool, allocator: std.mem.Allocator) VM {
        return VM{
            .chunk = chunk,
            .ip = chunk.code.bytes.items.ptr,
            .trace = trace,
            .allocator = allocator,
            .stack = std.ArrayList(Value).init(allocator),
            .globals = std.StringHashMap(Value).init(allocator),
        };
    }

    /// Free the VM (does not free the chunk as it's managed elsewhere)
    pub fn deinit(self: *VM) void {
        // Clean up any temporary strings on the stack
        for (self.stack.items) |value| {
            switch (value) {
                .string => |str| {
                    if (str) |str_ptr| {
                        // Only free strings that are not constants
                        if (!self.chunk.constants.contains(value)) {
                            str_ptr.deinit(self.allocator);
                        }
                    }
                },
                else => {},
            }
        }
        self.stack.deinit();

        // Clean up globals
        var it = self.globals.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*) {
                .string => |str| {
                    if (str) |str_ptr| {
                        // Only free strings that are not constants
                        if (!self.chunk.constants.contains(entry.value_ptr.*)) {
                            str_ptr.deinit(self.allocator);
                        }
                    }
                },
                else => {},
            }
        }
        self.globals.deinit();

        obj.deinitInternPool();
        self.* = undefined;
    }

    /// Reset the stack
    pub fn resetStack(self: *VM) void {
        // Clean up any temporary strings before clearing
        for (self.stack.items) |value| {
            switch (value) {
                .string => |str| {
                    if (str) |str_ptr| {
                        // Only free strings that are not constants
                        if (!self.chunk.constants.contains(value)) {
                            str_ptr.deinit(self.allocator);
                        }
                    }
                },
                else => {},
            }
        }
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
                value.print();
                std.debug.print(" ", .{});
            }
            std.debug.print("]", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn printGlobals(self: *VM) void {
        std.debug.print("          ", .{});
        var it = self.globals.iterator();
        var first = true;
        std.debug.print("[ ", .{});
        while (it.next()) |entry| {
            if (!first) {
                std.debug.print("| ", .{});
            }
            std.debug.print("{s}: ", .{entry.key_ptr.*});
            entry.value_ptr.print();
            first = false;
        }
        std.debug.print(" ]\n", .{});
    }

    pub fn interpret(self: *VM) InterpretResult {
        self.ip = self.chunk.code.bytes.items.ptr;
        return self.run();
    }

    fn binary_op(self: *VM, comptime op: fn (Value, Value, std.mem.Allocator) anyerror!?Value) InterpretResult {
        const right = self.pop() catch |err| {
            std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };
        const left = self.pop() catch |err| {
            std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };

        const result = op(left, right, self.allocator) catch |err| {
            std.debug.print("Error in binary operation: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };

        if (result) |value| {
            self.push(value) catch |err| {
                // Clean up the result if it's a string since we failed to push it
                if (value == .string) {
                    if (value.string) |str_ptr| {
                        str_ptr.deinit(self.allocator);
                    }
                }
                std.debug.print("Error pushing result: {s}\n", .{@errorName(err)});
                return InterpretResult.INTERPRET_RUNTIME_ERROR;
            };
            return InterpretResult.INTERPRET_OK;
        } else {
            std.debug.print("Invalid operand types for binary operation\n", .{});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        }
    }

    fn unary_op(self: *VM, comptime op: fn (Value) ?Value) InterpretResult {
        const value = self.pop() catch |err| {
            std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };

        if (op(value)) |result| {
            self.push(result) catch |err| {
                std.debug.print("Error pushing result: {s}\n", .{@errorName(err)});
                return InterpretResult.INTERPRET_RUNTIME_ERROR;
            };
            return InterpretResult.INTERPRET_OK;
        } else {
            std.debug.print("Invalid operand type for unary operation\n", .{});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        }
    }

    fn freeValue(self: *VM, value: Value) !void {
        if (value == .string) {
            if (value.string) |str_ptr| {
                str_ptr.deinit(self.allocator);
            }
        }
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
                OpCode.NIL => {
                    self.push(Value.nil()) catch |err| {
                        std.debug.print("Error pushing nil: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };

                },
                OpCode.CONSTANT => {
                    self.push(self.chunk.constants.at(self.ip[0]).?) catch |err| {
                        std.debug.print("Error pushing constant: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    self.ip += 1;
                },
                OpCode.TRUE => {
                    self.push(Value.boolean(true)) catch |err| {
                        std.debug.print("Error pushing true: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.FALSE => {
                    self.push(Value.boolean(false)) catch |err| {
                        std.debug.print("Error pushing false: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.ADD => {
                    const result = self.binary_op(Value.add);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.SUB => {
                    const result = self.binary_op(Value.sub);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.MUL => {
                    const result = self.binary_op(Value.mul);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.DIV => {
                    const result = self.binary_op(Value.div);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.AND => {
                    const result = self.binary_op(Value.logicalAnd);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.OR => {
                    const result = self.binary_op(Value.logicalOr);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.NOT => {
                    const result = self.unary_op(Value.not);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.NEGATE => {
                    const result = self.unary_op(Value.negate);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.RETURN => {
                    // Don't pop the final value, just return success
                    // This allows tests to examine the final result
                    return InterpretResult.INTERPRET_OK;
                },
                OpCode.PRINT => {
                    const value = self.pop() catch |err| {
                        std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    value.print();
                    try self.freeValue(value);
                },
                OpCode.POP => {
                    const value = self.pop() catch |err| {
                        std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    try self.freeValue(value);
                },
                OpCode.DEFINE_GLOBAL => {
                    const name = self.pop() catch |err| {
                        std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    if (name == .string) {
                        if (name.string) |str_ptr| {
                            const value = self.pop() catch |err| {
                                std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            };
                            self.globals.put(str_ptr.chars, value) catch |err| {
                                std.debug.print("Error putting value in global map: {s}\n", .{@errorName(err)});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            };
                        }
                    } else {
                        std.debug.print("Invalid operand type for DEFINE_GLOBAL\n", .{});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    }
                },
                OpCode.SET_GLOBAL => {
                    const name = self.pop() catch |err| {
                        std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    if (name == .string) {
                        if (name.string) |str_ptr| {
                            const value = self.pop() catch |err| {
                                std.debug.print("Error popping value: {s}\n", .{@errorName(err)});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            };
                            self.globals.put(str_ptr.chars, value) catch |err| {
                                std.debug.print("Error putting value in global map: {s}\n", .{@errorName(err)});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            };
                        }
                    } else {
                        std.debug.print("Invalid operand type for SET_GLOBAL\n", .{});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    }
                },
                else => {
                    std.debug.print("Unknown opcode {d}\n", .{opcode});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                },
            }
        }
    }
};
