const std = @import("std");
const Value = @import("value.zig").Value;
const ValueArray = @import("value.zig").ValueArray;
const VM = @import("vm.zig").VM;
const Chunk = @import("chunk.zig").Chunk;

test "ValueArray - basic operations" {
    var array = ValueArray.init(std.testing.allocator);
    defer array.deinit();

    // Test adding number values
    const idx1 = try array.add(Value.number(1.5));
    const idx2 = try array.add(Value.number(2.7));
    try std.testing.expectEqual(idx1, 0);
    try std.testing.expectEqual(idx2, 1);

    // Test adding boolean values
    const idx3 = try array.add(Value.boolean(true));
    try std.testing.expectEqual(idx3, 2);

    // Test retrieving values
    if (array.at(0)) |val| {
        try std.testing.expect(val == .number);
        try std.testing.expectEqual(val.number, 1.5);
    }
    if (array.at(2)) |val| {
        try std.testing.expect(val == .boolean);
        try std.testing.expectEqual(val.boolean, true);
    }
    try std.testing.expectEqual(array.at(3), null);

    // Test length
    try std.testing.expectEqual(array.len(), 3);
}

test "Value - arithmetic operations" {
    // Test number operations
    const a = Value.number(5.0);
    const b = Value.number(2.5);

    if (Value.add(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 7.5);
        }
    } else |_| {}
    if (Value.sub(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 2.5);
        }
    } else |_| {}
    if (Value.mul(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 12.5);
        }
    } else |_| {}
    if (Value.div(a, b, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.number, 2.0);
        }
    } else |_| {}
    if (Value.negate(a)) |result| {
        try std.testing.expectEqual(result.number, -5.0);
    }

    // Test operations with booleans (should return null)
    const c = Value.boolean(true);
    if (Value.add(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    if (Value.sub(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    if (Value.mul(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    if (Value.div(a, c, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}
    try std.testing.expectEqual(Value.negate(c), null);
}

test "Value - boolean operations" {
    const t = Value.boolean(true);
    const f = Value.boolean(false);
    const n = Value.number(1.0);

    // Test AND
    if (Value.logicalAnd(t, t, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, true);
        }
    } else |_| {}
    if (Value.logicalAnd(t, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, false);
        }
    } else |_| {}
    if (Value.logicalAnd(f, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, false);
        }
    } else |_| {}
    if (Value.logicalAnd(t, n, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}

    // Test OR
    if (Value.logicalOr(t, t, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, true);
        }
    } else |_| {}
    if (Value.logicalOr(t, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, true);
        }
    } else |_| {}
    if (Value.logicalOr(f, f, std.testing.allocator)) |result| {
        if (result) |val| {
            try std.testing.expectEqual(val.boolean, false);
        }
    } else |_| {}
    if (Value.logicalOr(t, n, std.testing.allocator)) |result| {
        try std.testing.expectEqual(result, null);
    } else |_| {}

    // Test NOT
    if (Value.not(t)) |result| {
        try std.testing.expectEqual(result.boolean, false);
    }
    if (Value.not(f)) |result| {
        try std.testing.expectEqual(result.boolean, true);
    }
    try std.testing.expectEqual(Value.not(n), null);
}

test "Value - string operations" {
    const allocator = std.testing.allocator;

    // Create a VM to own the strings
    var chunk = Chunk.init(allocator);
    var vm = VM.init(&chunk, false, allocator);
    defer {
        vm.deinit();
        chunk.deinit();
    }

    // Test string creation and equality with interning
    const str_val1 = try Value.createString(allocator, "hello");
    const str_val2 = try Value.createString(allocator, "hello");

    // Test that we got the same string back (pointer equality)
    try std.testing.expect(Value.equals(str_val1, str_val2));
    if (str_val1.string) |str1| {
        if (str_val2.string) |str2| {
            try std.testing.expectEqual(str1, str2);
        }
    }

    // Test different strings
    const str_val3 = try Value.createString(allocator, "world");
    try std.testing.expect(!Value.equals(str_val1, str_val3));

    // Test string concatenation
    if (try Value.add(str_val1, str_val3, allocator)) |result| {
        try std.testing.expect(result == .string);
        if (result.string) |str_ptr| {
            try std.testing.expectEqualStrings("helloworld", str_ptr.chars);
        }
    }
}

test "ValueArray - contains" {
    const allocator = std.testing.allocator;

    // Create a VM to own the strings
    var chunk = Chunk.init(allocator);
    var vm = VM.init(&chunk, false, allocator);
    defer {
        vm.deinit();
        chunk.deinit();
    }

    const num = Value.number(1.5);
    const bool_val = Value.boolean(true);
    const str = try Value.createString(allocator, "test");

    var array = ValueArray.init(allocator);
    defer array.deinit();

    // Add values to array
    _ = try array.add(num);
    _ = try array.add(bool_val);
    _ = try array.add(str);

    // Test contains
    try std.testing.expect(array.contains(num));
    try std.testing.expect(array.contains(bool_val));
    try std.testing.expect(array.contains(str));
    try std.testing.expect(!array.contains(Value.number(2.0)));
    try std.testing.expect(!array.contains(Value.boolean(false)));
}

test "Value - isFalsey" {
    const allocator = std.testing.allocator;

    // Create a VM to own the strings
    var chunk = Chunk.init(allocator);
    var vm = VM.init(&chunk, false, allocator);
    defer {
        vm.deinit();
        chunk.deinit();
    }

    try std.testing.expectError(Value.IsFalseyError.InvalidType, Value.nil().isFalsey());
    try std.testing.expectEqual(@as(u1, 1), try Value.boolean(false).isFalsey());
    try std.testing.expectEqual(@as(u1, 0), try Value.boolean(true).isFalsey());
    try std.testing.expectError(Value.IsFalseyError.InvalidType, Value.number(0).isFalsey());
    try std.testing.expectError(Value.IsFalseyError.InvalidType, Value.number(1).isFalsey());
    
    const str = try Value.createString(allocator, "test");
    try std.testing.expectError(Value.IsFalseyError.InvalidType, str.isFalsey());
}
