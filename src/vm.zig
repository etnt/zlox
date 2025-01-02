const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("opcodes.zig").OpCode;
const Value = @import("value.zig").Value;
const obj = @import("object.zig");
const utils = @import("utils.zig");

pub const Object = obj.Object;
pub const Function = obj.Object.Function;
pub const NativeFunction = obj.Object.NativeFunction;
pub const String = obj.Object.String;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

// A CallFrame represents a single ongoing function call.
pub const CallFrame = struct {
    // Function being called, we'll use that to look up
    // constants and for a few other things.
    function: *Function,
    // Instead of storing the return address in the callee's frame,
    // the caller stores its own ip. When we return from a function,
    // the VM will jump to the ip of the caller's CallFrame and resume
    // from there.
    ip: [*]const u8,
    // Points into the VM's value stack at the first slot that this
    // function can use.
    slots: usize,

    pub fn init(function: *Function, slots: usize) CallFrame {
        return CallFrame{
            .function = function,
            .ip = function.chunk.code.bytes.items.ptr, // FIXME correct ?
            .slots = slots,
        };
    }
};

pub const VM = struct {
    chunk: *Chunk, // Chunk to interpret
    ip: [*]u8, // Instruction pointer
    trace: bool = false, // Enable tracing
    slow: bool = false, // Run slow for "animated" effect
    allocator: std.mem.Allocator, // Allocator for dynamic memory
    stack: std.ArrayList(Value), // Dynamic stack
    sp: usize = 0, // Stack pointer
    globals: std.StringHashMap(Value), // Global variables

    // Each time a function is called, we create a new CallFrame
    call_frames: std.ArrayList(CallFrame), // Call frames
    frame_cnt: usize = 0, // Current frame counter

    /// Initialize a new VM with the top-level chunk in the init call frame
    pub fn init(chunk: *Chunk, trace: bool, allocator: std.mem.Allocator) !VM {
        var vm = VM{
            .chunk = chunk,
            .ip = chunk.code.bytes.items.ptr,
            .trace = trace,
            .allocator = allocator,
            .stack = std.ArrayList(Value).init(allocator),
            .globals = std.StringHashMap(Value).init(allocator),
            .call_frames = std.ArrayList(CallFrame).init(allocator),
            .frame_cnt = 0,
        };

        // Create a dummy function for the top-level code, but don't take ownership of the chunk
        const topFunction = Function.init(allocator, "script", 0, chunk.*) catch |err| {
            utils.debugPrint(@src(), "Error creating top-level function: {s}\n", .{@errorName(err)});
            return err; 
        };

        // Create and add the initial frame
        const initFrame = CallFrame.init(topFunction, 0);
        try vm.call_frames.append(initFrame);
        vm.frame_cnt = 1; // Note: frame_cnt is 1-based!

        return vm;
    }

    /// Free the VM (does not free the chunk as it's managed elsewhere)
    pub fn deinit(self: *VM) void {
        // Clean up all call frames and their functions, but don't free their chunks
        for (self.call_frames.items) |frame| {
            // Free only the function's name and the function object itself
            self.allocator.free(frame.function.name);
            self.allocator.destroy(frame.function);
        }
        self.call_frames.deinit();

        // Clean up the stack and globals
        self.stack.deinit();
        self.globals.deinit();

        // Clean up the intern pool which owns all strings
        if (obj.string_intern_pool) |*pool| {
            // Free all strings in the pool
            var it = pool.iterator();
            while (it.next()) |entry| {
                const str = entry.value_ptr.*;
                str.deinit(self.allocator);
            }
        }
        obj.deinitInternPool();

        self.* = undefined;
    }

    pub fn set_slow(self: *VM, slow: bool) bool {
        const old_slow = self.slow;
        self.slow = slow;
        return old_slow;
    }

    /// Reset the stack
    pub fn resetStack(self: *VM) void {
        self.stack.clearRetainingCapacity();
        self.sp = 0;
        self.frame_cnt = 0;
    }

    /// Push a value onto the stack
    pub fn push(self: *VM, value: Value) !void {
        try self.stack.append(value);
        self.sp += 1;
    }

    /// Pop a value from the stack
    pub fn pop(self: *VM) !Value {
        if (self.stack.items.len == 0) {
            return error.StackUnderflow;
        } else if (self.sp == 0) {
            return self.stack.pop();
        } else {
            self.sp -= 1;
            return self.stack.pop();
        }
    }

    pub fn getSP(self: *VM) usize {
        return self.sp;
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
        return self.run();
    }

    fn binary_op(self: *VM, comptime op: fn (Value, Value, std.mem.Allocator) anyerror!?Value) InterpretResult {
        const right = self.pop() catch |err| {
            utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };
        const left = self.pop() catch |err| {
            utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };

        const result = op(left, right, self.allocator) catch |err| {
            utils.debugPrint(@src(), "Error in binary operation: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };

        if (result) |value| {
            self.push(value) catch |err| {
                utils.debugPrint(@src(), "Error pushing result: {s}\n", .{@errorName(err)});
                return InterpretResult.INTERPRET_RUNTIME_ERROR;
            };
            return InterpretResult.INTERPRET_OK;
        } else {
            utils.debugPrint(@src(), "Invalid operand types for binary operation\n", .{});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        }
    }

    fn unary_op(self: *VM, comptime op: fn (Value) ?Value) InterpretResult {
        const value = self.pop() catch |err| {
            utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        };

        if (op(value)) |result| {
            self.push(result) catch |err| {
                utils.debugPrint(@src(), "Error pushing result: {s}\n", .{@errorName(err)});
                return InterpretResult.INTERPRET_RUNTIME_ERROR;
            };
            return InterpretResult.INTERPRET_OK;
        } else {
            utils.debugPrint(@src(), "Invalid operand type for unary operation\n", .{});
            return InterpretResult.INTERPRET_RUNTIME_ERROR;
        }
    }

    fn run(self: *VM) InterpretResult {
        const one_second = 1 * std.time.ns_per_s;

        while (true) {
            // Just for a "cool" effect when running the examples
            if (self.slow) {
                std.time.sleep(one_second);
            }

            if (self.trace) {
                // Print the stack before each instruction
                self.printStack();
                const current_frame = &self.call_frames.items[self.frame_cnt - 1];
                const offset = @intFromPtr(current_frame.ip) - @intFromPtr(current_frame.function.chunk.code.bytes.items.ptr);
                std.debug.print("{d:0>4}   ", .{offset});
                _ = current_frame.function.chunk.disassembleInstruction(offset);
            }

            var frame = &self.call_frames.items[self.frame_cnt - 1];
            const instruction = frame.ip[0];
            frame.ip += 1;

            switch (instruction) {
                OpCode.NIL => {
                    self.push(Value.nil()) catch |err| {
                        utils.debugPrint(@src(), "Error pushing nil: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.CONSTANT => {
                    const constant = frame.function.chunk.constants.at(frame.ip[0]).?;
                    frame.ip += 1;
                    self.push(constant) catch |err| {
                        utils.debugPrint(@src(), "Error pushing constant: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.TRUE => {
                    self.push(Value.boolean(true)) catch |err| {
                        utils.debugPrint(@src(), "Error pushing true: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.FALSE => {
                    self.push(Value.boolean(false)) catch |err| {
                        utils.debugPrint(@src(), "Error pushing false: {s}\n", .{@errorName(err)});
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
                    // When a function returns a value, that value will be on top
                    // of the stack. We're about to discard the called function's
                    // entire stack window, so we pop that return value off and
                    // hang on to it. Then we discard the CallFrame for the
                    // returning function. If that was the very last CallFrame,
                    // it means we've finished executing the top-level code.
                    // The entire program is done, so we pop the main script
                    // function from the stack and then exit the interpreter.
                    //
                    // Otherwise, we discard all of the slots the callee was using
                    // for its parameters and local variables. That includes the
                    // same slots the caller used to pass the arguments. Now that
                    // the call is done, the caller doesn't need them anymore.
                    // This means the top of the stack ends up right at the beginning
                    // of the returning function's stack window.
                    const result = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };

                    if (self.frame_cnt == 1) { // Top-level chunk (1-based)
                        return InterpretResult.INTERPRET_OK;
                    }

                    // Remove the call frame from the stack and prepare to pop the stack slots
                    const slots_to_pop = frame.slots;
                    _ = self.call_frames.pop();
                    self.frame_cnt -= 1;

                    // Shrink the stack back to the caller's frame
                    while (self.stack.items.len > slots_to_pop) {
                        _ = self.pop() catch |err| {
                            utils.debugPrint(@src(), "Error popping values after RETURN: {s}\n", .{@errorName(err)});
                            return InterpretResult.INTERPRET_RUNTIME_ERROR;
                        };
                    }
                    self.push(result) catch |err| {
                        utils.debugPrint(@src(), "Error pushing result: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.PRINT => {
                    const value = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    value.print();
                    std.debug.print("\n", .{});
                },
                OpCode.POP => {
                    _ = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.DEFINE_GLOBAL => {
                    const name = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    const value = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };

                    // Get the string name from either a string value or a string object
                    var name_str: []const u8 = undefined;
                    switch (name) {
                        .string => |maybe_str| {
                            if (maybe_str) |str| {
                                name_str = str.chars;
                            } else {
                                utils.debugPrint(@src(), "String is null\n", .{});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            }
                        },
                        .object => |maybe_obj| {
                            if (maybe_obj) |obj_ptr| {
                                if (obj_ptr.type == .string) {
                                    const str_ptr: *String = @alignCast(@ptrCast(obj_ptr));
                                    name_str = str_ptr.chars;
                                } else {
                                    utils.debugPrint(@src(), "Object is not a string\n", .{});
                                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                }
                            } else {
                                utils.debugPrint(@src(), "Object is null\n", .{});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            }
                        },
                        else => {
                            utils.debugPrint(@src(), "Invalid operand type for DEFINE_GLOBAL\n", .{});
                            return InterpretResult.INTERPRET_RUNTIME_ERROR;
                        },
                    }

                    // Store the value in globals
                    self.globals.put(name_str, value) catch |err| {
                        utils.debugPrint(@src(), "Error putting value in global map: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.SET_GLOBAL => {
                    const name = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    if (name == .string) {
                        if (name.string) |str_ptr| {
                            const value = self.pop() catch |err| {
                                utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            };
                            self.globals.put(str_ptr.chars, value) catch |err| {
                                utils.debugPrint(@src(), "Error putting value in global map: {s}\n", .{@errorName(err)});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            };
                        }
                    } else {
                        utils.debugPrint(@src(), "Invalid operand type for SET_GLOBAL\n", .{});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    }
                },
                OpCode.GET_GLOBAL => {
                    const name = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    if (name == .string) {
                        if (name.string) |str_ptr| {
                            if (self.globals.get(str_ptr.chars)) |value| {
                                self.push(value) catch |err| {
                                    utils.debugPrint(@src(), "Error pushing value: {s}\n", .{@errorName(err)});
                                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                };
                            } else {
                                utils.debugPrint(@src(), "Undefined global variable: {s}\n", .{str_ptr.chars});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            }
                        }
                    } else {
                        utils.debugPrint(@src(), "Invalid operand type for GET_GLOBAL\n", .{});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    }
                },
                OpCode.SET_LOCAL => {
                    // Get the slot number from the instruction stream
                    const slot = frame.slots + frame.ip[0];
                    frame.ip += 1;

                    // Pop the value to store
                    const value = self.peek(0) catch |err| {
                        utils.debugPrint(@src(), "Error popping local value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };

                    // Validate slot is within bounds
                    if (slot >= self.stack.items.len) {
                        utils.debugPrint(@src(), "Invalid slot index for SET_LOCAL\n", .{});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    }

                    // Set the value at the slot
                    self.stack.items[slot] = value;
                },
                OpCode.GET_LOCAL => {
                    // Get the slot number from the instruction stream
                    const slot = frame.slots + frame.ip[0];
                    frame.ip += 1;

                    // Validate slot is within bounds
                    if (slot >= self.stack.items.len) {
                        utils.debugPrint(@src(), "Invalid slot index for GET_LOCAL\n", .{});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    }

                    // Push the value at the slot onto the stack
                    self.push(self.stack.items[slot]) catch |err| {
                        utils.debugPrint(@src(), "Error pushing local value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                },
                OpCode.JUMP_IF_FALSE => {
                    // Read the two bytes that form the jump offset
                    const msb = frame.ip[0];
                    const lsb = frame.ip[1];
                    frame.ip += 2;

                    // Pop the condition value
                    const condition = self.peek(0) catch |err| {
                        utils.debugPrint(@src(), "Error popping condition value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };

                    // Check if we should jump
                    const is_falsey = condition.isFalsey() catch |err| {
                        utils.debugPrint(@src(), "Invalid condition type for JUMP_IF_FALSE: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };

                    // Maybe jump to the offset
                    if (is_falsey == 1) {
                        const jump_offset = (@as(u16, msb) << 8) | @as(u16, lsb);
                        frame.ip += jump_offset;
                    }
                },
                OpCode.JUMP => {
                    // Read the two bytes that form the jump offset
                    const msb = frame.ip[0];
                    const lsb = frame.ip[1];
                    frame.ip += 2;

                    // Jump to the offset
                    const jump_offset = (@as(u16, msb) << 8) | @as(u16, lsb);
                    frame.ip += jump_offset;
                },
                OpCode.LOOP => {
                    // Read the two bytes that form the jump offset
                    const msb = frame.ip[0];
                    const lsb = frame.ip[1];
                    frame.ip += 2;

                    // Jump backward by subtracting the offset
                    const jump_offset = (@as(u16, msb) << 8) | @as(u16, lsb);
                    frame.ip -= jump_offset;
                },
                OpCode.EQUAL => {
                    const right = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    const left = self.pop() catch |err| {
                        utils.debugPrint(@src(), "Error popping value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };
                    if (Value.equals(left, right)) {
                        self.push(Value.boolean(true)) catch |err| {
                            utils.debugPrint(@src(), "Error pushing true: {s}\n", .{@errorName(err)});
                            return InterpretResult.INTERPRET_RUNTIME_ERROR;
                        };
                    } else {
                        self.push(Value.boolean(false)) catch |err| {
                            utils.debugPrint(@src(), "Error pushing false: {s}\n", .{@errorName(err)});
                            return InterpretResult.INTERPRET_RUNTIME_ERROR;
                        };
                    }
                },
                OpCode.LESS => {
                    const result = self.binary_op(Value.lt);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.GREATER => {
                    const result = self.binary_op(Value.gt);
                    if (result != InterpretResult.INTERPRET_OK) return result;
                },
                OpCode.CALL => {
                    const argCount = frame.ip[0];
                    frame.ip += 1;
                    const callee = self.peek(argCount) catch |err| {
                        utils.debugPrint(@src(), "Error peeking callee value: {s}\n", .{@errorName(err)});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    };

                    // Handle both regular functions and native functions
                    switch (callee) {
                        .function => |maybe_function| {
                            if (maybe_function) |function| {
                                const new_frame = CallFrame.init(function, self.stack.items.len - argCount - 1);
                                self.call_frames.append(new_frame) catch |err| {
                                    utils.debugPrint(@src(), "Error appending call frame: {s}\n", .{@errorName(err)});
                                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                };
                                self.frame_cnt += 1;
                                self.sp = new_frame.slots + function.arity;
                            } else {
                                utils.debugPrint(@src(), "Function is null\n", .{});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            }
                        },
                        .native_function => |maybe_native| {
                            if (maybe_native) |native| {
                                // Check arity
                                if (argCount != native.arity) {
                                    utils.debugPrint(@src(), "Expected {d} arguments but got {d}\n", .{ native.arity, argCount });
                                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                }

                                // Get arguments from stack
                                var args = std.ArrayList(Value).init(self.allocator);
                                defer args.deinit();

                                var i: usize = 0;
                                while (i < argCount) : (i += 1) {
                                    const arg = self.peek(argCount - i - 1) catch |err| {
                                        utils.debugPrint(@src(), "Error getting argument: {s}\n", .{@errorName(err)});
                                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                    };
                                    args.append(arg) catch |err| {
                                        utils.debugPrint(@src(), "Error appending argument: {s}\n", .{@errorName(err)});
                                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                    };
                                }

                                // Pop the function and arguments
                                var j: usize = 0;
                                while (j < argCount + 1) : (j += 1) {
                                    _ = self.pop() catch |err| {
                                        utils.debugPrint(@src(), "Error popping arguments: {s}\n", .{@errorName(err)});
                                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                    };
                                }

                                // Call the native function
                                const result = native.function(args.items);

                                // Push the result
                                self.push(result) catch |err| {
                                    utils.debugPrint(@src(), "Error pushing native function result: {s}\n", .{@errorName(err)});
                                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                                };
                            } else {
                                utils.debugPrint(@src(), "Native function is null\n", .{});
                                return InterpretResult.INTERPRET_RUNTIME_ERROR;
                            }
                        },
                        else => {
                            utils.debugPrint(@src(), "Can only call functions and native functions\n", .{});
                            return InterpretResult.INTERPRET_RUNTIME_ERROR;
                        },
                    }
                },
                else => {
                    utils.debugPrint(@src(), "Unknown opcode {d}\n", .{instruction});
                    return InterpretResult.INTERPRET_RUNTIME_ERROR;
                },
            }
        }
    }
};
