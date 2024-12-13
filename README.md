# ZLox - A Bytecode Virtual Machine in Zig

A bytecode virtual machine implementation in Zig, based on [Crafting Interpreters](http://www.craftinginterpreters.com/chunks-of-bytecode.html). This project implements a stack-based VM with support for various data types, operations, and variable management.

## Demo

<table>
  <tr>
    <td><img src="demo/globalvars.gif" width="500"></td>
    <td><img src="demo/jump.gif" width="500"></td>
  </tr>
</table>

## Features

### Data Types and Operations
- Numbers: Full arithmetic operations (add, subtract, multiply, divide)
- Booleans: Logical operations (AND, OR, NOT)
- Strings: Dynamic allocation with string interning for efficiency
- Variables: Both global and local variable support

### Virtual Machine
- Dynamic stack implementation using ArrayList
- Efficient memory management with proper allocation/deallocation
- Run-length encoding for line number tracking
- Comprehensive error handling and type checking

### String Optimization
- String interning for efficient memory usage
- O(1) string equality comparison
- Optimized string concatenation

### Variable Management
- Global variables using StringHashMap
- Local variable support with stack-based allocation
- Proper scoping and memory cleanup

## Usage

### Prerequisites
- [Zig](https://ziglang.org/) compiler (tested with version 0.13.0)

### Building and Running

```bash
zig build run
```

### Command-line Options

```bash
zig build run -- [options]

Options:
  --example, -x <num>   Select example to run (1-4)
  --slow, -s            Enable animated execution
  --help, -h           Display this help message

Examples:
  1: Local variable assignment
  2: Global variable assignment
  3: String concatenation
  4: Arithmetic operations
```

## Project Structure

```
src/
├── main.zig          # Entry point and CLI handling
├── vm.zig           # Virtual Machine implementation
├── chunk.zig        # Bytecode chunk management
├── value.zig        # Value type system
├── object.zig       # Object system (strings, etc.)
├── opcodes.zig      # Operation codes definitions
├── examples.zig     # Example programs
└── root.zig         # Library entry point
```

## Implementation Details

### Value System
- Tagged union type supporting numbers, booleans, and strings
- Type-safe operations with runtime checking
- Efficient memory management for complex types

### Instruction Set
- Arithmetic: ADD, SUBTRACT, MULTIPLY, DIVIDE, NEGATE
- Logic: AND, OR, NOT
- Variables: DEFINE_GLOBAL, SET_GLOBAL, GET_GLOBAL, SET_LOCAL
- Stack: PUSH, POP, RETURN
- Constants: CONSTANT, TRUE, FALSE, NIL

### Memory Management
- Proper cleanup chains for all allocated resources
- String interning pool for efficient string handling
- Stack-based memory management for local variables

## Running Tests

```bash
zig build test
```

Tests cover:
- VM operations and error handling
- Value type system and operations
- Memory management and cleanup
- String interning and concatenation
- Variable scoping and access
- Stack operations and bounds checking

## License

See [LICENSE](LICENSE) file for details.
