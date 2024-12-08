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

test "LineArray - basic operations" {
    var lines = LineArray.init(std.testing.allocator);
    defer lines.deinit();

    // Add some line numbers
    try lines.add(123); // First instruction from line 123
    try lines.add(123); // Second instruction from line 123
    try lines.add(456); // Third instruction from line 456

    // Verify total count
    try std.testing.expectEqual(@as(u32, 3), lines.count());

    // Verify line numbers
    try std.testing.expectEqual(@as(u32, 123), lines.getLine(0).?);
    try std.testing.expectEqual(@as(u32, 123), lines.getLine(1).?);
    try std.testing.expectEqual(@as(u32, 456), lines.getLine(2).?);
}

test "LineArray - run-length encoding" {
    var lines = LineArray.init(std.testing.allocator);
    defer lines.deinit();

    // Add a sequence of line numbers
    try lines.add(100); // First run starts
    try lines.add(100);
    try lines.add(100);
    try lines.add(200); // Second run starts
    try lines.add(200);
    try lines.add(100); // Third run starts

    // Verify we only created three runs
    try std.testing.expectEqual(@as(usize, 3), lines.runs.items.len);

    // Verify the runs are correct
    try std.testing.expectEqual(@as(u32, 3), lines.runs.items[0].count);
    try std.testing.expectEqual(@as(u32, 100), lines.runs.items[0].line);
    try std.testing.expectEqual(@as(u32, 2), lines.runs.items[1].count);
    try std.testing.expectEqual(@as(u32, 200), lines.runs.items[1].line);
    try std.testing.expectEqual(@as(u32, 1), lines.runs.items[2].count);
    try std.testing.expectEqual(@as(u32, 100), lines.runs.items[2].line);

    // Verify total count
    try std.testing.expectEqual(@as(u32, 6), lines.count());
}

test "LineArray - get line at offset" {
    var lines = LineArray.init(std.testing.allocator);
    defer lines.deinit();

    // Add lines with different patterns
    try lines.add(1); // offset 0
    try lines.add(1); // offset 1
    try lines.add(2); // offset 2
    try lines.add(2); // offset 3
    try lines.add(2); // offset 4
    try lines.add(3); // offset 5

    // Check line numbers at each offset
    try std.testing.expectEqual(@as(u32, 1), lines.getLine(0).?);
    try std.testing.expectEqual(@as(u32, 1), lines.getLine(1).?);
    try std.testing.expectEqual(@as(u32, 2), lines.getLine(2).?);
    try std.testing.expectEqual(@as(u32, 2), lines.getLine(3).?);
    try std.testing.expectEqual(@as(u32, 2), lines.getLine(4).?);
    try std.testing.expectEqual(@as(u32, 3), lines.getLine(5).?);

    // Check out of bounds
    try std.testing.expectEqual(@as(?u32, null), lines.getLine(6));
}
