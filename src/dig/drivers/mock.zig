//! Mock database driver for testing
//!
//! This driver simulates database operations without requiring an actual database connection.
//! It stores data in memory and can be configured to return specific results or errors.

const std = @import("std");
const errors = @import("../errors.zig");
const types = @import("../types.zig");
const connection = @import("../connection.zig").Connection;

/// Mock query result configuration
pub const MockResult = struct {
    columns: []const []const u8,
    rows: []const []const types.SqlValue,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *MockResult) void {
        for (self.columns) |col| {
            self.allocator.free(col);
        }
        self.allocator.free(self.columns);

        for (self.rows) |row| {
            for (row) |val| {
                switch (val) {
                    .text => |t| self.allocator.free(t),
                    .blob => |b| self.allocator.free(b),
                    else => {},
                }
            }
            self.allocator.free(row);
        }
        self.allocator.free(self.rows);
    }
};

/// Mock connection state
pub const MockConnection = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    is_connected: bool = false,
    should_fail_connect: bool = false,
    should_fail_execute: bool = false,
    should_fail_query: bool = false,
    should_fail_transaction: bool = false,
    in_transaction: bool = false,
    executed_queries: std.ArrayList([]const u8),
    mock_results: std.ArrayList(MockResult),
    next_result_index: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .is_connected = false,
            .should_fail_connect = false,
            .should_fail_execute = false,
            .should_fail_query = false,
            .should_fail_transaction = false,
            .in_transaction = false,
            .executed_queries = std.ArrayList([]const u8){},
            .mock_results = std.ArrayList(MockResult){},
            .next_result_index = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.executed_queries.items) |query| {
            self.allocator.free(query);
        }
        self.executed_queries.deinit(self.allocator);

        for (self.mock_results.items) |*result| {
            result.deinit();
        }
        self.mock_results.deinit(self.allocator);
    }

    /// Add a mock result that will be returned by the next query
    pub fn addMockResult(self: *Self, columns: []const []const u8, rows: []const []const types.SqlValue) !void {
        // Duplicate columns
        var dup_columns = try self.allocator.alloc([]const u8, columns.len);
        for (columns, 0..) |col, i| {
            dup_columns[i] = try self.allocator.dupe(u8, col);
        }

        // Duplicate rows
        var dup_rows = try self.allocator.alloc([]const types.SqlValue, rows.len);
        for (rows, 0..) |row, i| {
            var dup_row = try self.allocator.alloc(types.SqlValue, row.len);
            for (row, 0..) |val, j| {
                dup_row[j] = switch (val) {
                    .text => |t| .{ .text = try self.allocator.dupe(u8, t) },
                    .blob => |b| .{ .blob = try self.allocator.dupe(u8, b) },
                    else => val,
                };
            }
            dup_rows[i] = dup_row;
        }

        try self.mock_results.append(self.allocator, .{
            .columns = dup_columns,
            .rows = dup_rows,
            .allocator = self.allocator,
        });
    }

    /// Set whether connection should fail
    pub fn setShouldFailConnect(self: *Self, should_fail: bool) void {
        self.should_fail_connect = should_fail;
    }

    /// Set whether execute should fail
    pub fn setShouldFailExecute(self: *Self, should_fail: bool) void {
        self.should_fail_execute = should_fail;
    }

    /// Set whether query should fail
    pub fn setShouldFailQuery(self: *Self, should_fail: bool) void {
        self.should_fail_query = should_fail;
    }

    /// Set whether transaction operations should fail
    pub fn setShouldFailTransaction(self: *Self, should_fail: bool) void {
        self.should_fail_transaction = should_fail;
    }

    /// Get the list of executed queries
    pub fn getExecutedQueries(self: *const Self) []const []const u8 {
        return self.executed_queries.items;
    }

    /// Clear executed queries history
    pub fn clearExecutedQueries(self: *Self) void {
        for (self.executed_queries.items) |query| {
            self.allocator.free(query);
        }
        self.executed_queries.clearRetainingCapacity();
    }

    /// Connection implementation
    pub fn connectImpl(state: *anyopaque, config: types.ConnectionConfig, allocator: std.mem.Allocator) errors.DigError!void {
        _ = config;
        _ = allocator;
        const self: *Self = @ptrCast(@alignCast(state));

        if (self.should_fail_connect) {
            return errors.DigError.ConnectionFailed;
        }

        self.is_connected = true;
    }

    /// Disconnect implementation
    pub fn disconnectImpl(state: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(state));
        self.is_connected = false;
    }

    /// Execute implementation
    pub fn executeImpl(state: *anyopaque, query: []const u8, allocator: std.mem.Allocator) errors.DigError!void {
        _ = allocator;
        const self: *Self = @ptrCast(@alignCast(state));

        if (!self.is_connected) {
            return errors.DigError.ConnectionFailed;
        }

        if (self.should_fail_execute) {
            return errors.DigError.QueryExecutionFailed;
        }

        // Store executed query
        const query_copy = try self.allocator.dupe(u8, query);
        try self.executed_queries.append(self.allocator, query_copy);
    }

    /// Query implementation
    pub fn queryImpl(state: *anyopaque, query: []const u8, allocator: std.mem.Allocator) errors.DigError!connection.QueryResult {
        const self: *Self = @ptrCast(@alignCast(state));

        if (!self.is_connected) {
            return errors.DigError.ConnectionFailed;
        }

        if (self.should_fail_query) {
            return errors.DigError.QueryExecutionFailed;
        }

        // Store executed query
        const query_copy = try self.allocator.dupe(u8, query);
        try self.executed_queries.append(self.allocator, query_copy);

        // Return mock result if available
        if (self.next_result_index < self.mock_results.items.len) {
            const mock_result = &self.mock_results.items[self.next_result_index];
            self.next_result_index += 1;

            // Duplicate columns
            var columns = try allocator.alloc([]const u8, mock_result.columns.len);
            for (mock_result.columns, 0..) |col, i| {
                columns[i] = try allocator.dupe(u8, col);
            }

            // Duplicate rows
            var rows = try allocator.alloc(connection.QueryResult.Row, mock_result.rows.len);
            for (mock_result.rows, 0..) |row, i| {
                var values = try allocator.alloc(types.SqlValue, row.len);
                for (row, 0..) |val, j| {
                    values[j] = switch (val) {
                        .text => |t| .{ .text = try allocator.dupe(u8, t) },
                        .blob => |b| .{ .blob = try allocator.dupe(u8, b) },
                        else => val,
                    };
                }
                rows[i] = .{
                    .values = values,
                    .columns = columns,
                };
            }

            return connection.QueryResult{
                .columns = columns,
                .rows = rows,
                .allocator = allocator,
            };
        }

        // Return empty result if no mock results
        const columns = try allocator.alloc([]const u8, 0);
        const rows = try allocator.alloc(connection.QueryResult.Row, 0);

        return connection.QueryResult{
            .columns = columns,
            .rows = rows,
            .allocator = allocator,
        };
    }

    /// Begin transaction implementation
    pub fn beginTransactionImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));

        if (!self.is_connected) {
            return errors.DigError.ConnectionFailed;
        }

        if (self.should_fail_transaction) {
            return errors.DigError.TransactionFailed;
        }

        if (self.in_transaction) {
            return errors.DigError.TransactionFailed;
        }

        self.in_transaction = true;
    }

    /// Commit implementation
    pub fn commitImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));

        if (!self.is_connected) {
            return errors.DigError.ConnectionFailed;
        }

        if (self.should_fail_transaction) {
            return errors.DigError.TransactionFailed;
        }

        if (!self.in_transaction) {
            return errors.DigError.TransactionFailed;
        }

        self.in_transaction = false;
    }

    /// Rollback implementation
    pub fn rollbackImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));

        if (!self.is_connected) {
            return errors.DigError.ConnectionFailed;
        }

        if (self.should_fail_transaction) {
            return errors.DigError.TransactionFailed;
        }

        if (!self.in_transaction) {
            return errors.DigError.TransactionFailed;
        }

        self.in_transaction = false;
    }

    /// Convert to Connection interface
    pub fn toConnection(self: *Self) connection {
        return .{
            .vtable = &.{
                .connect = connectImpl,
                .disconnect = disconnectImpl,
                .execute = executeImpl,
                .query = queryImpl,
                .beginTransaction = beginTransactionImpl,
                .commit = commitImpl,
                .rollback = rollbackImpl,
            },
            .state = self,
        };
    }
};
