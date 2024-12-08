// Operation codes as single-byte constants
pub const OpCode = struct {
    pub const CONSTANT: u8 = 0x01;    // Instruction to "produce" a constant value
    pub const NEGATE: u8   = 0x02;    // Negate a value
    pub const RETURN: u8   = 0x03;    // Return from function

    // Convert opcode value to name
    pub fn getName(code: u8) []const u8 {
        return switch (code) {
            RETURN => "RETURN",
            CONSTANT => "CONSTANT",
            NEGATE => "NEGATE",
            else => "UNKNOWN",
        };
    }
};

test "opcode names" {
    const std = @import("std");
    try std.testing.expectEqualStrings("CONSTANT", OpCode.getName(OpCode.CONSTANT));
    try std.testing.expectEqualStrings("NEGATE", OpCode.getName(OpCode.NEGATE));
    try std.testing.expectEqualStrings("RETURN", OpCode.getName(OpCode.RETURN));
    try std.testing.expectEqualStrings("UNKNOWN", OpCode.getName(0xFF));
}
