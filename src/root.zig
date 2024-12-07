const std = @import("std");
pub const ByteArray = @import("byte_array.zig").ByteArray;

test {
    // This will run all tests in referenced files
    std.testing.refAllDecls(@This());
}
