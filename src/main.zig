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
    defer {
        example.deinit();
    }

    // Disassemble the chunk to see its contents
    const ex_header = try std.fmt.allocPrint(allocator, "{s}{s}", .{ ex_hdr, ex_name });
    defer allocator.free(ex_header);
    std.debug.print("\nChunk Disassembly:\n", .{});
    example.disassemble(ex_header);

    // Create and initialize a VM with tracing enabled
    var vm = VM.init(&example, true, allocator);
    defer {
        vm.deinit();
    }

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




