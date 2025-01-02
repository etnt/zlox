// Operation codes as single-byte constants
pub const OpCode = struct {
    pub const NIL: u8      = 0x00;         // Push null onto the stack
    pub const CONSTANT: u8 = 0x01;         // Instruction to "produce" a constant value (1 byte operand)
    pub const ADD: u8      = 0x02;         // Add two values
    pub const SUB: u8      = 0x03;         // Subtract two values
    pub const MUL: u8      = 0x04;         // Multiply two values
    pub const DIV: u8      = 0x05;         // Divide two values
    pub const NEGATE: u8   = 0x06;         // Negate a value
    pub const AND: u8      = 0x07;         // Logical AND two values
    pub const OR: u8       = 0x08;         // Logical OR two values
    pub const NOT: u8      = 0x09;         // Logical NOT a value
    pub const RETURN: u8   = 0x0A;         // Return from function
    pub const TRUE: u8     = 0x0B;         // Push true onto the stack
    pub const FALSE: u8    = 0x0C;         // Push false onto the stack
    pub const PRINT: u8    = 0x0D;         // Print a value
    pub const POP: u8      = 0x0E;         // Pop a value from the stack
    pub const DEFINE_GLOBAL: u8 = 0x0F;    // Define a global variable
    pub const SET_GLOBAL: u8 = 0x10;       // Set a global variable (1 byte operand)
    pub const GET_GLOBAL: u8 = 0x11;       // Get a global variable (1 byte operand)
    pub const SET_LOCAL: u8 = 0x12;        // Set a local variable (1 byte operand)
    pub const GET_LOCAL: u8 = 0x13;        // Get a local variable (1 byte operand)
    pub const JUMP_IF_FALSE: u8 = 0x14;    // Jump if false (2 byte operand) forward
    pub const JUMP: u8 = 0x15;             // Jump unconditionally (2 byte operand) forward
    pub const EQUAL: u8 = 0x16;            // Equality test
    pub const LESS: u8 = 0x17;             // Less than test
    pub const GREATER: u8 = 0x18;          // Greater than test
    pub const LOOP: u8 = 0x19;             // Loop works like JUMP but jump backward
    pub const CALL: u8 = 0x1A;             // Call a function (1 byte operand) argCount
    //
    // The CLOSURE instruction is unique in that it has a variably sized encoding.
    // For each upvalue the closure captures, there are two single-byte operands.
    // Each pair of operands specifies what that upvalue captures.
    // If the first byte is one, it captures a local variable in the enclosing function.
    // If zero, it captures one of the function’s upvalues.
    // The next byte is the local slot or upvalue index to capture.
    //
    pub const CLOSURE: u8 = 0x1B;          // Create a closure (1 byte operand + variable number of operands): constant index to function + upvalues
    pub const GET_UPVALUE: u8 = 0x1C;      // Get an upvalue (1 byte operand) upvalue index
    pub const SET_UPVALUE: u8 = 0x1D;      // Set an upvalue (1 byte operand) upvalue index


    // Convert opcode value to name
    pub fn getName(code: u8) []const u8 {
        return switch (code) {
            RETURN => "RETURN",
            CONSTANT => "CONSTANT",
            NIL => "NIL",
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
            DEFINE_GLOBAL => "DEFINE_GLOBAL",
            SET_GLOBAL => "SET_GLOBAL",
            GET_GLOBAL => "GET_GLOBAL",
            SET_LOCAL => "SET_LOCAL",
            GET_LOCAL => "GET_LOCAL",
            JUMP_IF_FALSE => "JUMP_IF_FALSE",
            JUMP => "JUMP",
            EQUAL => "EQUAL",
            LESS => "LESS",
            GREATER => "GREATER",
            LOOP => "LOOP",
            CALL => "CALL",
            else => "UNKNOWN",
        };
    }
};

test "opcode names" {
    const std = @import("std");
    try std.testing.expectEqualStrings("CONSTANT", OpCode.getName(OpCode.CONSTANT));
    try std.testing.expectEqualStrings("NIL", OpCode.getName(OpCode.NIL));
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
    try std.testing.expectEqualStrings("DEFINE_GLOBAL", OpCode.getName(OpCode.DEFINE_GLOBAL));
    try std.testing.expectEqualStrings("SET_GLOBAL", OpCode.getName(OpCode.SET_GLOBAL));
    try std.testing.expectEqualStrings("GET_GLOBAL", OpCode.getName(OpCode.GET_GLOBAL));
    try std.testing.expectEqualStrings("SET_LOCAL", OpCode.getName(OpCode.SET_LOCAL));
    try std.testing.expectEqualStrings("GET_LOCAL", OpCode.getName(OpCode.GET_LOCAL));
    try std.testing.expectEqualStrings("JUMP_IF_FALSE", OpCode.getName(OpCode.JUMP_IF_FALSE));
    try std.testing.expectEqualStrings("JUMP", OpCode.getName(OpCode.JUMP));
    try std.testing.expectEqualStrings("EQUAL", OpCode.getName(OpCode.EQUAL));
    try std.testing.expectEqualStrings("LESS", OpCode.getName(OpCode.LESS));
    try std.testing.expectEqualStrings("GREATER", OpCode.getName(OpCode.GREATER));
    try std.testing.expectEqualStrings("LOOP", OpCode.getName(OpCode.LOOP));
    try std.testing.expectEqualStrings("CALL", OpCode.getName(OpCode.CALL));
    try std.testing.expectEqualStrings("UNKNOWN", OpCode.getName(0xFF));
}
