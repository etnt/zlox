// Operation codes as single-byte constants
pub const OpCode = struct {
    pub const CONSTANT: u8 = 0x01;    // Instruction to "produce" a constant value
    pub const ADD: u8      = 0x02;    // Add two values
    pub const SUB: u8      = 0x03;    // Subtract two values
    pub const MUL: u8      = 0x04;    // Multiply two values
    pub const DIV: u8      = 0x05;    // Divide two values
    pub const NEGATE: u8   = 0x06;    // Negate a value
    pub const AND: u8      = 0x07;    // Logical AND two values
    pub const OR: u8       = 0x08;    // Logical OR two values
    pub const NOT: u8      = 0x09;    // Logical NOT a value
    pub const RETURN: u8   = 0x0A;    // Return from function
    pub const TRUE: u8     = 0x0B;    // Push true onto the stack
    pub const FALSE: u8    = 0x0C;    // Push false onto the stack
    pub const PRINT: u8    = 0x0D;    // Print a value
    pub const POP: u8      = 0x0E;    // Pop a value from the stack

    // Convert opcode value to name
    pub fn getName(code: u8) []const u8 {
        return switch (code) {
            RETURN => "RETURN",
            CONSTANT => "CONSTANT",
            ADD => "ADD",
            SUB => "SUB",
            MUL => "MUL",
            DIV => "DIV",
            NEGATE => "NEGATE",
            AND => "AND",
            OR => "OR",
            NOT => "NOT",
            TRUE => "TRUE",
            FALSE => "FALSE",
            PRINT => "PRINT",
            POP => "POP",
            else => "UNKNOWN",
        };
    }
};

test "opcode names" {
    const std = @import("std");
    try std.testing.expectEqualStrings("CONSTANT", OpCode.getName(OpCode.CONSTANT));
    try std.testing.expectEqualStrings("ADD", OpCode.getName(OpCode.ADD));
    try std.testing.expectEqualStrings("SUB", OpCode.getName(OpCode.SUB));
    try std.testing.expectEqualStrings("MUL", OpCode.getName(OpCode.MUL));
    try std.testing.expectEqualStrings("DIV", OpCode.getName(OpCode.DIV));
    try std.testing.expectEqualStrings("NEGATE", OpCode.getName(OpCode.NEGATE));
    try std.testing.expectEqualStrings("AND", OpCode.getName(OpCode.AND));
    try std.testing.expectEqualStrings("OR", OpCode.getName(OpCode.OR));
    try std.testing.expectEqualStrings("NOT", OpCode.getName(OpCode.NOT));
    try std.testing.expectEqualStrings("RETURN", OpCode.getName(OpCode.RETURN));
    try std.testing.expectEqualStrings("TRUE", OpCode.getName(OpCode.TRUE));
    try std.testing.expectEqualStrings("FALSE", OpCode.getName(OpCode.FALSE));
    try std.testing.expectEqualStrings("PRINT", OpCode.getName(OpCode.PRINT));
    try std.testing.expectEqualStrings("POP", OpCode.getName(OpCode.POP));
    try std.testing.expectEqualStrings("UNKNOWN", OpCode.getName(0xFF));
}
