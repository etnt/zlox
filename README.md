# Zig experiments
> A collection of Zig experiments based on [Crafting Interpreters](http://www.craftinginterpreters.com/chunks-of-bytecode.html)

A simple dynamic array implementation for bytes in Zig, demonstrating basic data structure concepts and memory management. Includes support for operation codes (opcodes) with symbolic names.

## Features

- Dynamic array of bytes with automatic memory management
- Push and pop operations
- Array length tracking
- Index-based access
- Pretty printing functionality with opcode symbolic names
- Predefined operation codes for basic stack operations

## Prerequisites

- [Zig](https://ziglang.org/) compiler (tested with version 0.13.0)

## Building and Running

To build and run the example program:

```bash
zig build run
```

This will demonstrate the ByteArray functionality with example opcode operations.

## Running Tests

To run all tests:

```bash
zig build test
```

This will run tests for:
- Basic push/pop operations
- Empty array handling
- Multiple operations sequence
- Memory management
- Opcode name resolution

## Project Structure

```
src/
├── main.zig          # Example usage
├── root.zig         # Library entry point
├── byte_array.zig   # ByteArray implementation
└── opcodes.zig      # Operation codes definitions
```

## Usage Example

```zig
const std = @import("std");
const ByteArray = @import("byte_array.zig").ByteArray;
const OpCode = @import("opcodes.zig").OpCode;

// Initialize
var array = ByteArray.init(allocator);
defer array.deinit();

// Push operation codes
try array.push(OpCode.PUSH);  // 0x01
try array.push(OpCode.ADD);   // 0x03

// Print with symbolic names
array.printOpcodes(OpCode.getName);
// Output:
// [
//   0x01 (PUSH)
//   0x03 (ADD)
// ]

// Pop values
if (array.pop()) |opcode| {
    std.debug.print("Popped: {s}\n", .{OpCode.getName(opcode)});
}
```

## Available OpCodes

The following operation codes are predefined in `opcodes.zig`:

- `RETURN (0x00)`: Return from function
- `PUSH (0x01)`: Push value onto stack
- `POP (0x02)`: Pop value from stack
- `ADD (0x03)`: Add two values
- `SUB (0x04)`: Subtract two values

Each opcode can be printed with its symbolic name using the `printOpcodes` function and the `OpCode.getName` helper.
