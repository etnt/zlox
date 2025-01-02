const std = @import("std");
const root = @import("root.zig");
const clap: type = @import("clap");
const OpCode = root.OpCode;
const Chunk = root.Chunk;
const VM = root.VM;
const Value = @import("value.zig");
const vm_mod = @import("vm.zig");
const InterpretResult = vm_mod.InterpretResult;
const obj = @import("object.zig");
const ex: type = @import("examples.zig");
const exfun: type = @import("examples_functions.zig");
const exclos: type = @import("examples_closures.zig");

pub fn main() !u8 {
    // Get a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ex_hdr = "Example: ";
    var run_slow = false;
    var run_trace = false;
    var ex_name: []const u8 = undefined;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-x, --example <usize>  Choose example to run
        \\-s, --slow             Run slow (for animated effect)
        \\-t, --trace            Trace the execution
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit.
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return 1;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("Usage: zig build run -- [options]\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  -h, --help             Display this help and exit\n", .{});
        std.debug.print("  -x, --example <usize>  Choose example to run (1-12)\n", .{});
        std.debug.print("  -s, --slow             Run slow (for animated effect)\n", .{});
        std.debug.print("  -t, --trace            Trace the execution\n", .{});
        std.debug.print("\nExamples:\n", .{});
        std.debug.print("  1: Local variable assignment\n", .{});
        std.debug.print("  2: Global variable assignment\n", .{});
        std.debug.print("  3: String concatenation\n", .{});
        std.debug.print("  4: Arithmetic operations\n", .{});
        std.debug.print("  5: If-Then-Else operations\n", .{});
        std.debug.print("  6: If-Greater-Than\n", .{});
        std.debug.print("  7: If-Less-Than\n", .{});
        std.debug.print("  8: while loop\n", .{});
        std.debug.print("  9: for loop\n", .{});
        std.debug.print(" 10: function call (sum)\n", .{});
        std.debug.print(" 11: function call (factorial)\n", .{});
        std.debug.print(" 12: native functions (clock & sleep)\n", .{});
        std.debug.print(" 14: closures\n", .{});
        return 0;
    }

    if (res.args.trace != 0)
        run_trace = true;

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
        8 => blk: {
            ex_name = "\na = 3\nwhile (a > 0) {\n  a = a - 1\n  print a\n}\nprint \"Done!\"";
            break :blk try ex.while_loop(allocator);
        },
        9 => blk: {
            ex_name = "\nfor (i = 0; i < 3; i = i + 1) {\n  print i\n}\nprint \"Done!\"";
            break :blk try ex.for_loop(allocator);
        },
        10 => blk: {
            ex_name = "\nfunc sum(a, b, c) {\n  return a + b + c\n}\nprint 4 + sum(5, 6, 7)";
            break :blk try exfun.function_sum(allocator);
        },
        11 => blk: {
            ex_name = "\nfunc factorial(n) {\n  if (n == 0) return 1\n  return n * factorial(n - 1)\n}\nprint factorial(5)";
            break :blk try exfun.function_factorial(allocator);
        },
        12 => blk: {
            ex_name = "\nt1 = clock();\nsleep(2);\nt2 = clock();\nprint t2 - t1;";
            break :blk try exfun.function_native_clock(allocator);
        },
        14 => blk: {
            ex_name = "\nfun f() {\n  print a;\n}\nvar a = 3;\nf();";
            break :blk try exclos.simple_closure(allocator);
        },
        else => {
            std.debug.print("Invalid example number. Use --help to see available examples.\n", .{});
            return 1;
        },
    };
    defer {
        example.deinit();
    }

    if (run_trace) {
        // Disassemble the chunk to see its contents
        const ex_header = try std.fmt.allocPrint(allocator, "{s}{s}", .{ ex_hdr, ex_name });
        defer allocator.free(ex_header);
        std.debug.print("\nChunk Disassembly:\n", .{});
        example.disassemble(ex_header);
    }

    // Create and initialize a VM with tracing enabled
    var vm = try VM.init(&example, run_trace, allocator);
    defer {
        vm.deinit();
    }

    // Make it go slooow ?
    _ = vm.set_slow(run_slow);

    // Interpret the code
    if (run_trace)
        std.debug.print("\nInterpreting Code:\n", .{});
    const result = vm.interpret();

    // Print the global variables
    if (run_trace) {
        std.debug.print("\nGlobal Variables:\n", .{});
        vm.printGlobals();
        std.debug.print("\n", .{});
    }

    switch (result) {
        .INTERPRET_OK => {
            if (run_trace)
                std.debug.print("Interpretation result: OK\n", .{});
            return 0;
        },
        else => |err| {
            if (run_trace)
                std.debug.print("Interpretation result: {}\n", .{err});
            return 1;
        },
    }
}

test {
    _ = @import("value_test.zig");
    _ = @import("object_test.zig");
    _ = @import("line_array_test.zig");
}
