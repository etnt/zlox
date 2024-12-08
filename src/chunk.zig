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

    /// Add a constant to the chunk and return its index
    pub fn addConstant(self: *Chunk, value: f64) !usize {
        return self.constants.add(value);
    }

    /// Print the contents of the chunk with both opcodes and constants
    pub fn disassemble(self: *const Chunk, name: []const u8) void {
        std.debug.print("== {s} ==\n", .{name});

        // Print opcodes
        std.debug.print("\nOpcodes:\n", .{});
        self.code.printOpcodes(OpCode.getName);

        // Print constants
        std.debug.print("\nConstants:\n", .{});
        self.constants.print();
    }
};

test "Chunk - basic operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add some constants
    const const1 = try chunk.addConstant(1.2);
    const const2 = try chunk.addConstant(3.4);
    try std.testing.expectEqual(@as(usize, 0), const1);
    try std.testing.expectEqual(@as(usize, 1), const2);

    // Write some opcodes
    try chunk.writeOpcode(OpCode.PUSH);
    try chunk.writeOpcode(OpCode.ADD);
    try chunk.writeOpcode(OpCode.RETURN);

    // Verify code length
    try std.testing.expectEqual(@as(usize, 3), chunk.code.len());

    // Verify constants
    try std.testing.expectEqual(@as(f64, 1.2), chunk.constants.at(0).?);
    try std.testing.expectEqual(@as(f64, 3.4), chunk.constants.at(1).?);
}
