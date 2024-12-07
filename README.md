# Zig ByteArray Implementation

A simple dynamic array implementation for bytes in Zig, demonstrating basic data structure concepts and memory management.

## Features

- Dynamic array of bytes with automatic memory management
- Push and pop operations
- Array length tracking
- Index-based access
- Pretty printing functionality

## Prerequisites

- [Zig](https://ziglang.org/) compiler (tested with version 0.11.0)

## Building and Running

To build and run the example program:

```bash
zig build run
```

This will demonstrate the ByteArray functionality with some example operations.

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

## Project Structure

```
src/
├── main.zig          # Example usage
├── root.zig         # Library entry point
└── byte_array.zig   # ByteArray implementation
```

## Usage Example

```zig
const std = @import("std");
const ByteArray = @import("byte_array.zig").ByteArray;

// Initialize
var array = ByteArray.init(allocator);
defer array.deinit();

// Push values
try array.push(10);
try array.push(20);

// Pop values
if (array.pop()) |byte| {
    std.debug.print("Popped: {d}\n", .{byte});
}

// Get length
const len = array.len();
