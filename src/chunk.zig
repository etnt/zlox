const std = @import("std");
const ByteArray = @import("byte_array.zig").ByteArray;
const ValueArray = @import("value.zig").ValueArray;
const Value = @import("value.zig").Value;
const LineArray = @import("line_array.zig").LineArray;
const OpCode = @import("opcodes.zig").OpCode;

/// Chunk represents a sequence of bytecode instructions and their associated constant values
pub const Chunk = struct {
    // The actual bytecode
    code: ByteArray,

    // Each chunk will carry with it a list of the values that appear as
    // literals in the program. To keep things simpler, we’ll put all
    // constants in here, even simple integers.
    constants: ValueArray,

    // Store line numbers using run-length encoding
    lines: LineArray,

    /// Initialize a new Chunk with the given allocator
    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = ByteArray.init(allocator),
            .constants = ValueArray.init(allocator),
            .lines = LineArray.init(allocator),
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
        try self.lines.add(line);
    }

    /// Write a byte to the chunk (used for operands)
    pub fn writeByte(self: *Chunk, byte: u8, line: u32) !void {
        try self.code.push(byte);
        try self.lines.add(line);
    }

    /// Add a constant to the chunk and return its index
    pub fn addConstant(self: *Chunk, value: Value) !usize {
        return self.constants.add(value);
    }

    /// Print the contents of the chunk with both opcodes and constants
    pub fn disassemble(self: *const Chunk, name: []const u8) void {
        std.debug.print("== {s} ==\n\n", .{name});
        std.debug.print("Address  Line OpCode            Value\n", .{});
        std.debug.print("-------- ---- ----------------- --------\n", .{});

        var offset: usize = 0;
        var last_line: u32 = 0;
        while (offset < self.code.len()) {
            const current_line = self.lines.getLine(@intCast(offset)).?;
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
    pub fn disassembleInstruction(self: *const Chunk, offset: usize) usize {
        if (self.code.at(offset)) |instruction| {
            switch (instruction) {
                OpCode.NIL => {
                    std.debug.print("NIL\n", .{});
                    return offset + 1;
                },
                OpCode.CONSTANT => {
                    if (self.code.at(offset + 1)) |constant_index| {
                        if (self.constants.at(constant_index)) |constant_value| {
                            std.debug.print("CONSTANT          {d} '", .{constant_index});
                            constant_value.print();
                            std.debug.print("'\n", .{});
                            return offset + 2; // Skip the opcode and the constant index
                        }
                    }
                    std.debug.print("CONSTANT         <error>\n", .{});
                    return offset + 2;
                },
                OpCode.TRUE => {
                    std.debug.print("TRUE\n", .{});
                    return offset + 1;
                },
                OpCode.FALSE => {
                    std.debug.print("FALSE\n", .{});
                    return offset + 1;
                },
                OpCode.ADD => {
                    std.debug.print("ADD\n", .{});
                    return offset + 1;
                },
                OpCode.SUB => {
                    std.debug.print("SUB\n", .{});
                    return offset + 1;
                },
                OpCode.MUL => {
                    std.debug.print("MUL\n", .{});
                    return offset + 1;
                },
                OpCode.DIV => {
                    std.debug.print("DIV\n", .{});
                    return offset + 1;
                },
                OpCode.AND => {
                    std.debug.print("AND\n", .{});
                    return offset + 1;
                },
                OpCode.OR => {
                    std.debug.print("OR\n", .{});
                    return offset + 1;
                },
                OpCode.NOT => {
                    std.debug.print("NOT\n", .{});
                    return offset + 1;
                },
                OpCode.NEGATE => {
                    std.debug.print("NEGATE\n", .{});
                    return offset + 1;
                },
                OpCode.RETURN => {
                    std.debug.print("RETURN\n", .{});
                    return offset + 1;
                },
                OpCode.PRINT => {
                    std.debug.print("PRINT\n", .{});
                    return offset + 1;
                },
                OpCode.POP => {
                    std.debug.print("POP\n", .{});
                    return offset + 1;
                },
                OpCode.DEFINE_GLOBAL => {
                    std.debug.print("DEFINE_GLOBAL\n", .{});
                    return offset + 1;
                },
                OpCode.SET_GLOBAL => {
                    std.debug.print("SET_GLOBAL\n", .{});
                    return offset + 1;
                },
                OpCode.GET_GLOBAL => {
                    std.debug.print("GET_GLOBAL\n", .{});
                    return offset + 1;
                },
                OpCode.SET_LOCAL => {
                    const slot = self.code.at(offset + 1).?;
                    std.debug.print("SET_LOCAL         {d} \n", .{slot});
                    return offset + 2;
                },
                OpCode.GET_LOCAL => {
                    std.debug.print("GET_LOCAL\n", .{});
                    return offset + 1;
                },
                else => {
                    std.debug.print("Unknown opcode {d}\n", .{instruction});
                    return offset + 1;
                },
            }
        } else {
            std.debug.print("Error: Could not read instruction at offset {d}\n", .{offset});
            return offset + 1;
        }
    }
};

test "Chunk - basic operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add a number constant and get its index
    const num_idx = try chunk.addConstant(Value.number(1.2));
    try std.testing.expectEqual(@as(usize, 0), num_idx);

    // Add a boolean constant and get its index
    const bool_idx = try chunk.addConstant(Value.boolean(true));
    try std.testing.expectEqual(@as(usize, 1), bool_idx);

    // Write CONSTANT opcode followed by the number constant index
    try chunk.writeOpcode(OpCode.CONSTANT, 123);
    try chunk.writeByte(@intCast(num_idx), 123);

    // Write TRUE and FALSE opcodes
    try chunk.writeOpcode(OpCode.TRUE, 123);
    try chunk.writeOpcode(OpCode.FALSE, 123);

    // Write some boolean operations
    try chunk.writeOpcode(OpCode.AND, 123);
    try chunk.writeOpcode(OpCode.OR, 123);
    try chunk.writeOpcode(OpCode.NOT, 123);

    // Write RETURN opcode
    try chunk.writeOpcode(OpCode.RETURN, 123);

    // Verify code length (2 for CONSTANT+idx, 1 each for TRUE, FALSE, AND, OR, NOT, RETURN)
    try std.testing.expectEqual(@as(usize, 8), chunk.code.len());
    try std.testing.expectEqual(@as(u32, 8), chunk.lines.count());

    // Verify the constant values
    if (chunk.constants.at(0)) |val| {
        try std.testing.expectEqual(@as(f64, 1.2), val.number);
    }
    if (chunk.constants.at(1)) |val| {
        try std.testing.expectEqual(true, val.boolean);
    }

    // Verify line numbers
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(0).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(1).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(2).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(3).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(4).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(5).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(6).?);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.getLine(7).?);

    // Verify we only created one run since all instructions are from the same line
    try std.testing.expectEqual(@as(usize, 1), chunk.lines.runs.items.len);
    try std.testing.expectEqual(@as(u32, 8), chunk.lines.runs.items[0].count);
    try std.testing.expectEqual(@as(u32, 123), chunk.lines.runs.items[0].line);
}
