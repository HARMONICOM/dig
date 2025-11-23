//! Chainable query builder interface for Connection
//!
//! This module provides a fluent interface for building and executing queries
//! directly on database connections without manually generating SQL.

const std = @import("std");
const errors = @import("errors.zig");
const types = @import("types.zig");
const connection = @import("connection.zig");
const query = @import("query.zig");

/// Query builder type
pub const QueryType = enum {
    select,
    insert,
    update,
    delete,
};

/// Chainable query builder that wraps existing query builders
/// and provides direct execution on a connection
pub const QueryBuilder = struct {
    const Self = @This();

    conn: *connection.Connection,
    table_name: []const u8,
    db_type: types.DatabaseType,
    allocator: std.mem.Allocator,
    query_type: QueryType,

    // Internal query builders
    select_query: ?query.Select = null,
    insert_query: ?query.Insert = null,
    update_query: ?query.Update = null,
    delete_query: ?query.Delete = null,

    /// Initialize a new query builder for a table
    pub fn init(conn: *connection.Connection, table_name: []const u8, db_type: types.DatabaseType, allocator: std.mem.Allocator) !Self {
        return .{
            .conn = conn,
            .table_name = table_name,
            .db_type = db_type,
            .allocator = allocator,
            .query_type = .select,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.select_query) |*q| q.deinit();
        if (self.insert_query) |*q| q.deinit();
        if (self.update_query) |*q| q.deinit();
        if (self.delete_query) |*q| q.deinit();
    }

    // ========== SELECT Methods ==========

    /// Set columns to select (default: *)
    pub fn select(self: *Self, columns: []const []const u8) !*Self {
        self.query_type = .select;
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = self.select_query.?.select(columns);
        return self;
    }

    /// Add INNER JOIN clause
    pub fn join(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = try self.select_query.?.join(table, left_column, right_column);
        return self;
    }

    /// Add LEFT JOIN clause
    pub fn leftJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = try self.select_query.?.leftJoin(table, left_column, right_column);
        return self;
    }

    /// Add RIGHT JOIN clause
    pub fn rightJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = try self.select_query.?.rightJoin(table, left_column, right_column);
        return self;
    }

    /// Add FULL OUTER JOIN clause
    pub fn fullJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = try self.select_query.?.fullJoin(table, left_column, right_column);
        return self;
    }

    /// Add WHERE clause
    pub fn where(self: *Self, column: []const u8, operator: []const u8, value: types.SqlValue) !*Self {
        switch (self.query_type) {
            .select => {
                if (self.select_query == null) {
                    self.select_query = try query.Select.init(self.allocator, self.table_name);
                }
                _ = try self.select_query.?.where(column, operator, value);
            },
            .update => {
                if (self.update_query == null) {
                    self.update_query = try query.Update.init(self.allocator, self.table_name);
                }
                _ = try self.update_query.?.where(column, operator, value);
            },
            .delete => {
                if (self.delete_query == null) {
                    self.delete_query = try query.Delete.init(self.allocator, self.table_name);
                }
                _ = try self.delete_query.?.where(column, operator, value);
            },
            else => return errors.DigError.QueryBuildError,
        }
        return self;
    }

    /// Add ORDER BY clause
    pub fn orderBy(self: *Self, column: []const u8, direction: query.Select.Direction) !*Self {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = self.select_query.?.orderBy(column, direction);
        return self;
    }

    /// Add LIMIT clause
    pub fn limit(self: *Self, count: usize) !*Self {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = self.select_query.?.limit(count);
        return self;
    }

    /// Add OFFSET clause
    pub fn offset(self: *Self, count: usize) !*Self {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }
        _ = self.select_query.?.offset(count);
        return self;
    }

    /// Execute SELECT query and return results
    pub fn get(self: *Self) !connection.Connection.QueryResult {
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = try query.Select.init(self.allocator, self.table_name);
        }

        const sql = try self.select_query.?.toSql(self.db_type);
        defer self.allocator.free(sql);

        return self.conn.query(sql, self.allocator);
    }

    /// Execute SELECT query and return first result
    pub fn first(self: *Self) !?connection.Connection.QueryResult.Row {
        _ = try self.limit(1);
        var result = try self.get();

        if (result.rows.len == 0) {
            result.deinit();
            return null;
        }

        // Note: Caller is responsible for calling result.deinit()
        return result.rows[0];
    }

    // ========== INSERT Methods ==========

    /// Add a value for INSERT
    pub fn addValue(self: *Self, column: []const u8, value: types.SqlValue) !*Self {
        self.query_type = .insert;
        if (self.insert_query == null) {
            self.insert_query = try query.Insert.init(self.allocator, self.table_name);
        }
        _ = try self.insert_query.?.addValue(column, value);
        return self;
    }

    /// Set multiple values for INSERT from a hash map
    pub fn setValues(self: *Self, values: std.StringHashMap(types.SqlValue)) !*Self {
        self.query_type = .insert;
        if (self.insert_query == null) {
            self.insert_query = try query.Insert.init(self.allocator, self.table_name);
        }
        _ = try self.insert_query.?.setValues(values);
        return self;
    }

    // ========== UPDATE Methods ==========

    /// Set a column value for UPDATE
    pub fn set(self: *Self, column: []const u8, value: types.SqlValue) !*Self {
        self.query_type = .update;
        if (self.update_query == null) {
            self.update_query = try query.Update.init(self.allocator, self.table_name);
        }
        _ = try self.update_query.?.set(column, value);
        return self;
    }

    /// Set multiple columns for UPDATE from a hash map
    pub fn setMultiple(self: *Self, values: std.StringHashMap(types.SqlValue)) !*Self {
        self.query_type = .update;
        if (self.update_query == null) {
            self.update_query = try query.Update.init(self.allocator, self.table_name);
        }
        _ = try self.update_query.?.setMultiple(values);
        return self;
    }

    // ========== Common Execution Methods ==========

    /// Execute INSERT, UPDATE, or DELETE query
    pub fn execute(self: *Self) !void {
        const sql = switch (self.query_type) {
            .select => return errors.DigError.QueryBuildError, // Use get() for SELECT
            .insert => blk: {
                if (self.insert_query == null) {
                    return errors.DigError.QueryBuildError;
                }
                break :blk try self.insert_query.?.toSql(self.db_type);
            },
            .update => blk: {
                if (self.update_query == null) {
                    return errors.DigError.QueryBuildError;
                }
                break :blk try self.update_query.?.toSql(self.db_type);
            },
            .delete => blk: {
                if (self.delete_query == null) {
                    self.delete_query = try query.Delete.init(self.allocator, self.table_name);
                }
                break :blk try self.delete_query.?.toSql(self.db_type);
            },
        };
        defer self.allocator.free(sql);

        return self.conn.execute(sql, self.allocator);
    }

    /// Start a DELETE query
    pub fn delete(self: *Self) !*Self {
        self.query_type = .delete;
        if (self.delete_query == null) {
            self.delete_query = try query.Delete.init(self.allocator, self.table_name);
        }
        return self;
    }
};
