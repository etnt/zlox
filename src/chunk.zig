const std = @import("std");
const ByteArray = @import("byte_array.zig").ByteArray;
const ValueArray = @import("value.zig").ValueArray;
const U32Array = @import("u32_array.zig").U32Array;
const OpCode = @import("opcodes.zig").OpCode;

/// Chunk represents a sequence of bytecode instructions and their associated constant values
pub const Chunk = struct {
    code: ByteArray,
    constants: ValueArray,
    lines: U32Array, // Store line numbers for each instruction

    /// Initialize a new Chunk with the given allocator
    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = ByteArray.init(allocator),
            .constants = ValueArray.init(allocator),
            .lines = U32Array.init(allocator),
        };
    }

    /// Free the memory used by the Chunk
    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.constants.deinit();
        self.lines.deinit();
    }

    /// Write an opcode to the chunk
    pub fn writeOpcode(self: *Chunk, op: u8, line: u32) !void {
        try self.code.push(op);
        try self.lines.push(line);
    }

    /// Write a byte to the chunk (used for operands)
    pub fn writeByte(self: *Chunk, byte: u8, line: u32) !void {
        try self.code.push(byte);
        try self.lines.push(line);
    }

    /// Add a constant to the chunk and return its index
    pub fn addConstant(self: *Chunk, value: f64) !usize {
        return self.constants.add(value);
    }

    /// Print the contents of the chunk with both opcodes and constants
    pub fn disassemble(self: *const Chunk, name: []const u8) void {
        std.debug.print("== {s} ==\n\n", .{name});
        std.debug.print("Address  Line OpCode           Value\n", .{});
        std.debug.print("-------- ---- ----------------- --------\n", .{});

        var offset: usize = 0;
        var last_line: u32 = 0;
        while (offset < self.code.len()) {
            const current_line = self.lines.at(offset).?;
            if (current_line == last_line) {
                std.debug.print("{d:0>4}        | ", .{offset});
            } else {
                std.debug.print("{d:0>4}     {d:>4} ", .{ offset, current_line });
                last_line = current_line;
            }

            offset = self.disassembleInstruction(offset);
        }
    }

    /// Disassemble a single instruction at the given offset
    /// Returns the offset of the next instruction
    fn disassembleInstruction(self: *const Chunk, offset: usize) usize {
        if (self.code.at(offset)) |instruction| {
            switch (instruction) {
                OpCode.CONSTANT => {
                    if (self.code.at(offset + 1)) |constant_index| {
                        if (self.constants.at(constant_index)) |constant_value| {
                            std.debug.print("CONSTANT         {d} '{d}'\n", .{ constant_index, constant_value });
                            return offset + 2; // Skip the opcode and the constant index
                        }
                    }
                    std.debug.print("CONSTANT         <error>\n", .{});
                    return offset + 2;
                },
                OpCode.RETURN => {
                    std.debug.print("RETURN\n", .{});
                    return offset + 1;
                },
                else => {
                    std.debug.print("Unknown opcode {d}\n", .{instruction});
                    return offset + 1;
                },
            }
        } else {
            std.debug.print("Error: Could not read instruction\n", .{});
            return offset + 1;
        }
    }
};

test "Chunk - basic operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add a constant and get its index
    const const_idx = try chunk.addConstant(1.2);
    try std.testing.expectEqual(@as(usize, 0), const_idx);

    // Write CONSTANT opcode followed by the constant index
    try chunk.writeOpcode(OpCode.CONSTANT, 123);
    try chunk.writeByte(@intCast(const_idx), 123);

    // Write RETURN opcode
    try chunk.writeOpcode(OpCode.RETURN, 123);

    // Verify code length (should be 3: CONSTANT opcode + constant index + RETURN)
    try std.testing.expectEqual(@as(usize, 3), chunk.code.len());
    try std.testing.expectEqual(@as(usize, 3), chunk.lines.len());

    // Verify the constant value
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.at(0).?);

    // Verify line numbers
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.at(0).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.at(1).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.at(2).?);
}
