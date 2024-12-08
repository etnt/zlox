const std = @import("std");

pub const ByteArray = @import("byte_array.zig").ByteArray;
pub const OpCode = @import("opcodes.zig").OpCode;
pub const Value = @import("value.zig").Value;
pub const ValueArray = @import("value.zig").ValueArray;
pub const Chunk = @import("chunk.zig").Chunk;
pub const VM = @import("vm.zig").VM;

test {
    // This will run all tests in referenced files
    std.testing.refAllDecls(@This());
}
