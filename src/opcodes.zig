// Operation codes as single-byte constants
pub const OpCode = struct {
    pub const RETURN: u8 = 0x00;  // Return from function
    pub const PUSH: u8 = 0x01;    // Push value onto stack
    pub const POP: u8 = 0x02;     // Pop value from stack
    pub const ADD: u8 = 0x03;     // Add two values
    pub const SUB: u8 = 0x04;     // Subtract two values

    // Convert opcode value to name
    pub fn getName(code: u8) []const u8 {
        return switch (code) {
            RETURN => "RETURN",
            PUSH => "PUSH",
            POP => "POP",
            ADD => "ADD",
            SUB => "SUB",
            else => "UNKNOWN",
        };
    }
};

test "opcode names" {
    const std = @import("std");
    try std.testing.expectEqualStrings("PUSH", OpCode.getName(OpCode.PUSH));
    try std.testing.expectEqualStrings("ADD", OpCode.getName(OpCode.ADD));
    try std.testing.expectEqualStrings("UNKNOWN", OpCode.getName(0xFF));
}
