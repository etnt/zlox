const std = @import("std");

/// A run of instructions from the same line
const LineRun = struct {
    count: u32, // Number of instructions in this run
    line: u32, // The line number
};

/// LineArray provides a run-length encoded array of line numbers
pub const LineArray = struct {
    runs: std.ArrayList(LineRun),
    total_count: u32, // Total number of instructions tracked

    /// Initialize a new LineArray with the given allocator
    pub fn init(allocator: std.mem.Allocator) LineArray {
        return LineArray{
            .runs = std.ArrayList(LineRun).init(allocator),
            .total_count = 0,
        };
    }

    /// Free the memory used by the LineArray
    pub fn deinit(self: *LineArray) void {
        self.runs.deinit();
    }

    /// Add a line number for an instruction
    pub fn add(self: *LineArray, line: u32) !void {
        if (self.runs.items.len > 0) {
            // Check if we can extend the last run
            const last = &self.runs.items[self.runs.items.len - 1];
            if (last.line == line) {
                last.count += 1;
                self.total_count += 1;
                return;
            }
        }
        // Start a new run
        try self.runs.append(LineRun{ .count = 1, .line = line });
        self.total_count += 1;
    }

    /// Get the line number for an instruction at the given offset
    pub fn getLine(self: *const LineArray, offset: u32) ?u32 {
        if (offset >= self.total_count) return null;

        var current_offset: u32 = 0;
        for (self.runs.items) |run| {
            if (offset < current_offset + run.count) {
                return run.line;
            }
            current_offset += run.count;
        }
        return null;
    }

    /// Get the total number of instructions tracked
    pub fn count(self: *const LineArray) u32 {
        return self.total_count;
    }
};

