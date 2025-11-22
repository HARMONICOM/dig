//! Database connection abstraction

const std = @import("std");
const errors = @import("errors.zig");
const types = @import("types.zig");

/// Abstract database connection interface
pub const Connection = struct {
    const Self = @This();

    vtable: *const VTable,
    state: *anyopaque,

    pub const VTable = struct {
        connect: *const fn (state: *anyopaque, config: types.ConnectionConfig, allocator: std.mem.Allocator) errors.DigError!void,
        disconnect: *const fn (state: *anyopaque) void,
        execute: *const fn (state: *anyopaque, query: []const u8, allocator: std.mem.Allocator) errors.DigError!void,
        query: *const fn (state: *anyopaque, query: []const u8, allocator: std.mem.Allocator) errors.DigError!QueryResult,
        beginTransaction: *const fn (state: *anyopaque) errors.DigError!void,
        commit: *const fn (state: *anyopaque) errors.DigError!void,
        rollback: *const fn (state: *anyopaque) errors.DigError!void,
    };

    pub const QueryResult = struct {
        columns: []const []const u8,
        rows: []const Row,
        allocator: std.mem.Allocator,

        pub const Row = struct {
            values: []const types.SqlValue,
            columns: []const []const u8,

            /// Get value by column name
            /// Returns null if column not found
            pub fn get(self: Row, column_name: []const u8) ?types.SqlValue {
                for (self.columns, 0..) |col, i| {
                    if (std.mem.eql(u8, col, column_name)) {
                        if (i >= self.values.len) return null;
                        return self.values[i];
                    }
                }
                return null;
            }
        };

        /// Get column index by name
        /// Returns null if column not found
        pub fn getColumnIndex(self: QueryResult, column_name: []const u8) ?usize {
            for (self.columns, 0..) |col, i| {
                if (std.mem.eql(u8, col, column_name)) {
                    return i;
                }
            }
            return null;
        }

        pub fn deinit(self: *QueryResult) void {
            for (self.rows) |row| {
                for (row.values) |value| {
                    switch (value) {
                        .text => |t| self.allocator.free(t),
                        .blob => |b| self.allocator.free(b),
                        else => {},
                    }
                }
                self.allocator.free(row.values);
            }
            for (self.columns) |col| {
                self.allocator.free(col);
            }
            self.allocator.free(self.rows);
            self.allocator.free(self.columns);
        }
    };

    pub fn connect(self: *Self, config: types.ConnectionConfig, allocator: std.mem.Allocator) errors.DigError!void {
        return self.vtable.connect(self.state, config, allocator);
    }

    pub fn disconnect(self: *Self) void {
        self.vtable.disconnect(self.state);
    }

    pub fn execute(self: *Self, sql_query: []const u8, allocator: std.mem.Allocator) errors.DigError!void {
        return self.vtable.execute(self.state, sql_query, allocator);
    }

    pub fn query(self: *Self, sql_query: []const u8, allocator: std.mem.Allocator) errors.DigError!QueryResult {
        return self.vtable.query(self.state, sql_query, allocator);
    }

    pub fn beginTransaction(self: *Self) errors.DigError!void {
        return self.vtable.beginTransaction(self.state);
    }

    pub fn commit(self: *Self) errors.DigError!void {
        return self.vtable.commit(self.state);
    }

    pub fn rollback(self: *Self) errors.DigError!void {
        return self.vtable.rollback(self.state);
    }
};
