const std = @import("std");
const ByteArray = @import("byte_array.zig").ByteArray;
const ValueArray = @import("value.zig").ValueArray;
const OpCode = @import("opcodes.zig").OpCode;

/// Chunk represents a sequence of bytecode instructions and their associated constant values
pub const Chunk = struct {
    code: ByteArray,
    constants: ValueArray,

    /// Initialize a new Chunk with the given allocator
    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = ByteArray.init(allocator),
            .constants = ValueArray.init(allocator),
        };
    }

    /// Free the memory used by the Chunk
    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.constants.deinit();
    }

    /// Write an opcode to the chunk
    pub fn writeOpcode(self: *Chunk, op: u8) !void {
        try self.code.push(op);
    }

    /// Write a byte to the chunk (used for operands)
    pub fn writeByte(self: *Chunk, byte: u8) !void {
        try self.code.push(byte);
    }

    /// Add a constant to the chunk and return its index
    pub fn addConstant(self: *Chunk, value: f64) !usize {
        return self.constants.add(value);
    }

    /// Print the contents of the chunk with both opcodes and constants
    pub fn disassemble(self: *const Chunk, name: []const u8) void {
        std.debug.print("== {s} ==\n\n", .{name});
        std.debug.print("Address  OpCode           Value\n", .{});
        std.debug.print("-------- ----------------- --------\n", .{});

        var offset: usize = 0;
        while (offset < self.code.len()) {
            offset = self.disassembleInstruction(offset);
        }
    }

    /// Disassemble a single instruction at the given offset
    fn disassembleInstruction(self: *const Chunk, offset: usize) usize {
        // Print the instruction address
        std.debug.print("{d:0>4}     ", .{offset});

        if (self.code.at(offset)) |instruction| {
            switch (instruction) {
                OpCode.CONSTANT => {
                    if (self.code.at(offset + 1)) |constant_index| {
                        if (self.constants.at(constant_index)) |constant_value| {
                            std.debug.print("CONSTANT          {d} '{d}'\n", .{ constant_index, constant_value });
                            return offset + 2; // Skip the opcode and the constant index
                        }
                    }
                    std.debug.print("CONSTANT          <error>\n", .{});
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
    try chunk.writeOpcode(OpCode.CONSTANT);
    try chunk.writeByte(@intCast(const_idx));

    // Write RETURN opcode
    try chunk.writeOpcode(OpCode.RETURN);

    // Verify code length (should be 3: CONSTANT opcode + constant index + RETURN)
    try std.testing.expectEqual(@as(usize, 3), chunk.code.len());

    // Verify the constant value
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.at(0).?);
}
