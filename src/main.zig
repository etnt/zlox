const std = @import("std");
const root = @import("root.zig");
const clap: type = @import("clap");
const OpCode = root.OpCode;
const Chunk = root.Chunk;
const VM = root.VM;
const Value = @import("value.zig").Value;
const vm_mod = @import("vm.zig");
const InterpretResult = vm_mod.InterpretResult;
const obj = @import("object.zig");
const ex: type = @import("examples.zig");

pub fn main() !void {
    // Get a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ex_hdr = "Example: ";
    var run_slow = false;
    var ex_name: []const u8 = undefined;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-x, --example <usize>  Choose example to run
        \\-s, --slow             Run slow (for animated effect)
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit.
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("Usage: zig build run -- [options]\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  -h, --help             Display this help and exit\n", .{});
        std.debug.print("  -x, --example <usize>  Choose example to run (1-4)\n", .{});
        std.debug.print("  -s, --slow             Run slow (for animated effect)\n", .{});
        std.debug.print("\nExamples:\n", .{});
        std.debug.print("  1: Local variable assignment\n", .{});
        std.debug.print("  2: Global variable assignment\n", .{});
        std.debug.print("  3: String concatenation\n", .{});
        std.debug.print("  4: Arithmetic operations\n", .{});
        std.debug.print("  5: If-Then-Else operations\n", .{});
        std.debug.print("  6: If-Greater-Than\n", .{});
        std.debug.print("  7: If-Less-Than\n", .{});
        return;
    }

    if (res.args.slow != 0)
        run_slow = true;

    // Choose which example to run based on command line argument
    const run_example = res.args.example orelse 1;
    var example = switch (run_example) {
        1 => blk: {
            ex_name = "local variable assignment";
            break :blk try ex.local_variables(allocator);
        },
        2 => blk: {
            ex_name = "variable assignment";
            break :blk try ex.assignment(allocator);
        },
        3 => blk: {
            ex_name = "concatenate strings";
            break :blk try ex.concatenate(allocator);
        },
        4 => blk: {
            ex_name = "arithmetics";
            break :blk try ex.arithmetics(allocator);
        },
        5 => blk: {
            ex_name = "if <bool> then 3 else 7";
            break :blk try ex.if_then_else(allocator);
        },
        6 => blk: {
            ex_name = "if (3.0 > 7.0) then print(\"Yes\") else print(\"No\")";
            break :blk try ex.if_gt(allocator);
        },
        7 => blk: {
            ex_name = "if (3.0 < 7.0) then print(\"Yes\") else print(\"No\")";
            break :blk try ex.if_lt(allocator);
        },
        else => {
            std.debug.print("Invalid example number. Use --help to see available examples.\n", .{});
            return;
        },
    };
    defer example.deinit();

    // Disassemble the chunk to see its contents
    const ex_header = try std.fmt.allocPrint(allocator, "{s}{s}", .{ ex_hdr, ex_name });
    defer allocator.free(ex_header);
    std.debug.print("\nChunk Disassembly:\n", .{});
    example.disassemble(ex_header);

    // Create and initialize a VM with tracing enabled
    var vm = VM.init(&example, true, allocator);
    defer vm.deinit();

    // Make it go sloow...
    _ = vm.set_slow(run_slow);

    // Interpret the code
    std.debug.print("\nInterpreting Code:\n", .{});
    const result = vm.interpret();
    std.debug.print("\nInterpretation result: {}\n", .{result});

    // Print the global variables
    std.debug.print("\nGlobal Variables:\n", .{});
    vm.printGlobals();
    std.debug.print("\n", .{});
}

test "global variables" {
    // Initialize with testing allocator
    const allocator = std.testing.allocator;

    // Clean up intern pool at the start and end of test
    obj.deinitInternPool();
    defer obj.deinitInternPool();

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    // Global variable: myvar = null
    const myvar = try chunk.addConstant(try Value.createString(allocator, "myvar"));
    const e = try chunk.addConstant(Value.number(2.71828));
    try chunk.writeOpcode(OpCode.NIL, 6060);           // the value is null
    try chunk.writeOpcode(OpCode.CONSTANT, 6060);      // the name is a constant
    try chunk.writeByte(@intCast(myvar), 6060);      // the name of the variable
    try chunk.writeOpcode(OpCode.DEFINE_GLOBAL, 6060); // define the global variable
    // Assign value to the global variable: myvar = 2.71828
    try chunk.writeOpcode(OpCode.CONSTANT, 6061);
    try chunk.writeByte(@intCast(e), 6061);
    try chunk.writeOpcode(OpCode.CONSTANT, 6061);
    try chunk.writeByte(@intCast(myvar), 6061);
    try chunk.writeOpcode(OpCode.SET_GLOBAL, 6061);

    try chunk.writeOpcode(OpCode.RETURN, 6061);

    // Create and initialize a VM with tracing enabled
    var vm = VM.init(&chunk, false, allocator);
    defer vm.deinit();

    // Do VM interpretation and check global variable
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());
    try std.testing.expectEqual(Value.number(2.71828), vm.globals.get("myvar").?);
}

test "chunk with constants" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add number constants
    const const1 = try chunk.addConstant(Value.number(1.2));
    const const2 = try chunk.addConstant(Value.number(3.4));
    try std.testing.expectEqual(@as(usize, 0), const1);
    try std.testing.expectEqual(@as(usize, 1), const2);

    // Write opcodes with their operands
    try chunk.writeOpcode(OpCode.CONSTANT, 123);
    try chunk.writeByte(@intCast(const1), 123);
    try chunk.writeOpcode(OpCode.CONSTANT, 456);
    try chunk.writeByte(@intCast(const2), 456);
    try chunk.writeOpcode(OpCode.TRUE, 456);  // Use TRUE opcode directly
    try chunk.writeOpcode(OpCode.RETURN, 456);

    // Verify code length (6 bytes total: 2 for each CONSTANT+idx, 1 for TRUE, 1 for RETURN)
    try std.testing.expectEqual(@as(usize, 6), chunk.code.len());
    try std.testing.expectEqual(@as(u32, 6), chunk.lines.count());

    // Verify constants
    if (chunk.constants.at(0)) |val| {
        try std.testing.expectEqual(Value.number(1.2), val);
    }
    if (chunk.constants.at(1)) |val| {
        try std.testing.expectEqual(Value.number(3.4), val);
    }

    // Test VM interpretation
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());
}

test "arithmetic calculation" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add constants
    const c1 = try chunk.addConstant(Value.number(2.0));
    const c2 = try chunk.addConstant(Value.number(3.4));
    const c3 = try chunk.addConstant(Value.number(2.6));

    // Setup: (3.4 + 2.6) * 2.0
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c2), 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c3), 1);

    try chunk.writeOpcode(OpCode.ADD, 1);

    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(c1), 1);

    try chunk.writeOpcode(OpCode.MUL, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain the result: (3.4 + 2.6) * 2.0 = 12.0
    const result = try vm.peek(0);
    try std.testing.expectEqual(Value.number(12.0), result);
}

test "boolean operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Test AND operation (true AND false = false)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.AND, 1);

    // Test OR operation (false OR true = true)
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.OR, 1);

    // Test NOT operation (NOT true = false)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.NOT, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Create VM and interpret
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain three results:
    // [false, true, false]
    const not_result = try vm.peek(0);
    const or_result = try vm.peek(1);
    const and_result = try vm.peek(2);

    try std.testing.expectEqual(Value.boolean(false), not_result);
    try std.testing.expectEqual(Value.boolean(true), or_result);
    try std.testing.expectEqual(Value.boolean(false), and_result);
}

test "mixed operations" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();

    // Add number constant
    const num = try chunk.addConstant(Value.number(1.0));

    // Try to perform arithmetic on a boolean (should fail)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.CONSTANT, 1);
    try chunk.writeByte(@intCast(num), 1);
    try chunk.writeOpcode(OpCode.ADD, 1);

    // Create VM and interpret
    // NOTE: This may produce some debug output warning about wrong type of operands
    //       but that is what we want to test here, i.e we expect a runtime error.
    var vm = VM.init(&chunk, false, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_RUNTIME_ERROR, vm.interpret());
}

test "conditional jumps" {
    const allocator = std.testing.allocator;
    const ex_hdr ="Conditional Jumps";
    const ex_name = "conditional jumps";

    var chunk = Chunk.init(allocator);
    defer chunk.deinit();

    // Test with false boolean (should jump)
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);  // MSB of jump offset
    try chunk.writeByte(1, 1);  // LSB of jump offset (skip next instruction)
    try chunk.writeOpcode(OpCode.TRUE, 1);  // This should be skipped
    try chunk.writeOpcode(OpCode.FALSE, 1); // We should jump here

    // Test with another false boolean (should jump)
    try chunk.writeOpcode(OpCode.FALSE, 1);
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);  // MSB of jump offset
    try chunk.writeByte(1, 1);  // LSB of jump offset (skip next instruction)
    try chunk.writeOpcode(OpCode.TRUE, 1);  // This should be skipped
    try chunk.writeOpcode(OpCode.FALSE, 1); // We should jump here

    // Test with true boolean (should not jump)
    try chunk.writeOpcode(OpCode.TRUE, 1);
    try chunk.writeOpcode(OpCode.JUMP_IF_FALSE, 1);
    try chunk.writeByte(0, 1);  // MSB of jump offset
    try chunk.writeByte(1, 1);  // LSB of jump offset (skip next instruction)
    try chunk.writeOpcode(OpCode.TRUE, 1);  // This should NOT be skipped
    try chunk.writeOpcode(OpCode.FALSE, 1);

    try chunk.writeOpcode(OpCode.RETURN, 1);

    // Disassemble the chunk to see its contents
    const ex_header = try std.fmt.allocPrint(allocator, "{s}{s}", .{ ex_hdr, ex_name });
    defer allocator.free(ex_header);
    std.debug.print("\nChunk Disassembly:\n", .{});
    chunk.disassemble(ex_header);

    // Create VM and interpret
    var vm = VM.init(&chunk, true, std.testing.allocator);
    defer vm.deinit();
    try std.testing.expectEqual(InterpretResult.INTERPRET_OK, vm.interpret());

    // The stack should contain the results of our jumps
    // [false, false, true, false]
    const result4 = try vm.peek(0);  // Last pushed value
    const result3 = try vm.peek(1);  // Result of true test (should be true)
    const result2 = try vm.peek(2);  // Result of false test (should be false)
    const result1 = try vm.peek(3);  // Result of false test (should be false)

    try std.testing.expectEqual(Value.boolean(false), result1);  // false test jumped
    try std.testing.expectEqual(Value.boolean(true), result2);  // false test jumped
    try std.testing.expectEqual(Value.boolean(true), result3);   // true didn't jump
    try std.testing.expectEqual(Value.boolean(false), result4);  // last value pushed
}
