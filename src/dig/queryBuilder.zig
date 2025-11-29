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

/// WHERE clause structure for temporary storage
const WhereClause = struct {
    column: []const u8,
    operator: []const u8,
    value: types.SqlValue,
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
    build_error: ?errors.DigError = null,

    // Pending WHERE clauses (applied when query type is determined)
    pending_where_clauses: ?std.ArrayList(WhereClause) = null,

    // Internal query builders
    select_query: ?query.Select = null,
    insert_query: ?query.Insert = null,
    update_query: ?query.Update = null,
    delete_query: ?query.Delete = null,

    /// Initialize a new query builder for a table
    pub fn init(conn: *connection.Connection, table_name: []const u8, db_type: types.DatabaseType, allocator: std.mem.Allocator) Self {
        return .{
            .conn = conn,
            .table_name = table_name,
            .db_type = db_type,
            .allocator = allocator,
            .query_type = .select,
            .build_error = null,
            .pending_where_clauses = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.pending_where_clauses) |*clauses| {
            clauses.deinit(self.allocator);
        }
        if (self.select_query) |*q| {
            q.deinit();
            self.select_query = null;
        }
        if (self.insert_query) |*q| {
            q.deinit();
            self.insert_query = null;
        }
        if (self.update_query) |*q| {
            q.deinit();
            self.update_query = null;
        }
        if (self.delete_query) |*q| {
            q.deinit();
            self.delete_query = null;
        }
    }

    /// Apply pending WHERE clauses to the current query object
    fn applyPendingWhereClauses(self: *Self) void {
        if (self.pending_where_clauses == null) return;
        if (self.build_error != null) return;

        for (self.pending_where_clauses.?.items) |clause| {
            switch (self.query_type) {
                .select => {
                    if (self.select_query) |*q| {
                        _ = q.where(clause.column, clause.operator, clause.value) catch |err| {
                            self.build_error = err;
                            return;
                        };
                    }
                },
                .update => {
                    if (self.update_query) |*q| {
                        _ = q.where(clause.column, clause.operator, clause.value) catch |err| {
                            self.build_error = err;
                            return;
                        };
                    }
                },
                .delete => {
                    if (self.delete_query) |*q| {
                        _ = q.where(clause.column, clause.operator, clause.value) catch |err| {
                            self.build_error = err;
                            return;
                        };
                    }
                },
                else => {},
            }
        }

        // Clear pending clauses after applying
        self.pending_where_clauses.?.clearRetainingCapacity();
    }

    // ========== SELECT Methods ==========

    /// Set columns to select (default: *)
    pub fn select(self: *Self, columns: []const []const u8) *Self {
        if (self.build_error != null) return self;
        self.query_type = .select;
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.select(columns);
        return self;
    }

    /// Add INNER JOIN clause
    pub fn join(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) *Self {
        if (self.build_error != null) return self;
        if (self.query_type != .select) {
            self.build_error = errors.DigError.QueryBuildError;
            return self;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.join(table, left_column, right_column) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    /// Add LEFT JOIN clause
    pub fn leftJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) *Self {
        if (self.build_error != null) return self;
        if (self.query_type != .select) {
            self.build_error = errors.DigError.QueryBuildError;
            return self;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.leftJoin(table, left_column, right_column) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    /// Add RIGHT JOIN clause
    pub fn rightJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) *Self {
        if (self.build_error != null) return self;
        if (self.query_type != .select) {
            self.build_error = errors.DigError.QueryBuildError;
            return self;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.rightJoin(table, left_column, right_column) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    /// Add FULL OUTER JOIN clause
    pub fn fullJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) *Self {
        if (self.build_error != null) return self;
        if (self.query_type != .select) {
            self.build_error = errors.DigError.QueryBuildError;
            return self;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.fullJoin(table, left_column, right_column) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    /// Add WHERE clause
    pub fn where(self: *Self, column: []const u8, operator: []const u8, value: types.SqlValue) *Self {
        if (self.build_error != null) return self;

        // Initialize pending_where_clauses if needed
        if (self.pending_where_clauses == null) {
            self.pending_where_clauses = std.ArrayList(WhereClause){};
        }

        // First, store the WHERE clause in pending list
        self.pending_where_clauses.?.append(self.allocator, WhereClause{
            .column = column,
            .operator = operator,
            .value = value,
        }) catch |err| {
            self.build_error = switch (err) {
                error.OutOfMemory => errors.DigError.OutOfMemory,
            };
            return self;
        };

        // Then apply it to the appropriate query if it exists
        switch (self.query_type) {
            .select => {
                if (self.select_query) |*q| {
                    _ = q.where(column, operator, value) catch |err| {
                        self.build_error = err;
                        return self;
                    };
                }
            },
            .update => {
                if (self.update_query) |*q| {
                    _ = q.where(column, operator, value) catch |err| {
                        self.build_error = err;
                        return self;
                    };
                }
            },
            .delete => {
                if (self.delete_query) |*q| {
                    _ = q.where(column, operator, value) catch |err| {
                        self.build_error = err;
                        return self;
                    };
                }
            },
            else => {},
        }
        return self;
    }

    /// Add ORDER BY clause
    pub fn orderBy(self: *Self, column: []const u8, direction: query.Select.Direction) *Self {
        if (self.build_error != null) return self;
        if (self.query_type != .select) {
            self.build_error = errors.DigError.QueryBuildError;
            return self;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.orderBy(column, direction);
        return self;
    }

    /// Add LIMIT clause
    pub fn limit(self: *Self, count: usize) *Self {
        if (self.build_error != null) return self;
        if (self.query_type != .select) {
            self.build_error = errors.DigError.QueryBuildError;
            return self;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.limit(count);
        return self;
    }

    /// Add OFFSET clause
    pub fn offset(self: *Self, count: usize) *Self {
        if (self.build_error != null) return self;
        if (self.query_type != .select) {
            self.build_error = errors.DigError.QueryBuildError;
            return self;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.select_query.?.offset(count);
        return self;
    }

    /// Execute SELECT query and return results
    pub fn get(self: *Self) errors.DigError!connection.Connection.QueryResult {
        if (self.build_error) |err| {
            return err;
        }
        if (self.query_type != .select) {
            return errors.DigError.QueryBuildError;
        }
        if (self.select_query == null) {
            self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| {
                return err;
            };
            // Apply pending WHERE clauses when creating new select query
            self.applyPendingWhereClauses();
            if (self.build_error) |err| {
                return err;
            }
        }

        const sql = self.select_query.?.toSql(self.db_type) catch |err| {
            return err;
        };
        defer self.allocator.free(sql);

        return self.conn.query(sql, self.allocator);
    }

    /// Execute SELECT query and return first result
    pub fn first(self: *Self) errors.DigError!?connection.Connection.QueryResult.Row {
        _ = self.limit(1);
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
    pub fn addValue(self: *Self, column: []const u8, value: types.SqlValue) *Self {
        if (self.build_error != null) return self;
        self.query_type = .insert;
        if (self.insert_query == null) {
            self.insert_query = query.Insert.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.insert_query.?.addValue(column, value) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    /// Set multiple values for INSERT from a hash map
    pub fn setValues(self: *Self, values: std.StringHashMap(types.SqlValue)) *Self {
        if (self.build_error != null) return self;
        self.query_type = .insert;
        if (self.insert_query == null) {
            self.insert_query = query.Insert.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
        }
        _ = self.insert_query.?.setValues(values) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    // ========== UPDATE Methods ==========

    /// Set a column value for UPDATE
    pub fn set(self: *Self, column: []const u8, value: types.SqlValue) *Self {
        if (self.build_error != null) return self;
        const was_update = self.query_type == .update;
        self.query_type = .update;
        if (self.update_query == null) {
            self.update_query = query.Update.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
            // Apply pending WHERE clauses when creating new update query
            if (!was_update) {
                self.applyPendingWhereClauses();
            }
        }
        _ = self.update_query.?.set(column, value) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    /// Set multiple columns for UPDATE from a hash map
    pub fn setMultiple(self: *Self, values: std.StringHashMap(types.SqlValue)) *Self {
        if (self.build_error != null) return self;
        const was_update = self.query_type == .update;
        self.query_type = .update;
        if (self.update_query == null) {
            self.update_query = query.Update.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
            // Apply pending WHERE clauses when creating new update query
            if (!was_update) {
                self.applyPendingWhereClauses();
            }
        }
        _ = self.update_query.?.setMultiple(values) catch |err| {
            self.build_error = err;
            return self;
        };
        return self;
    }

    // ========== Common Execution Methods ==========

    /// Generate SQL string from the query builder
    /// Returns an allocated string that must be freed by the caller
    pub fn toSql(self: *Self) errors.DigError![]const u8 {
        if (self.build_error) |err| {
            return err;
        }
        return switch (self.query_type) {
            .select => blk: {
                if (self.select_query == null) {
                    self.select_query = query.Select.init(self.allocator, self.table_name) catch |err| return err;
                    // Apply pending WHERE clauses when creating new select query
                    self.applyPendingWhereClauses();
                    if (self.build_error) |err| {
                        return err;
                    }
                }
                break :blk self.select_query.?.toSql(self.db_type) catch |err| return err;
            },
            .insert => blk: {
                if (self.insert_query == null) {
                    return errors.DigError.QueryBuildError;
                }
                break :blk self.insert_query.?.toSql(self.db_type) catch |err| return err;
            },
            .update => blk: {
                if (self.update_query == null) {
                    return errors.DigError.QueryBuildError;
                }
                break :blk self.update_query.?.toSql(self.db_type) catch |err| return err;
            },
            .delete => blk: {
                if (self.delete_query == null) {
                    self.delete_query = query.Delete.init(self.allocator, self.table_name) catch |err| return err;
                    // Apply pending WHERE clauses when creating new delete query
                    self.applyPendingWhereClauses();
                    if (self.build_error) |err| {
                        return err;
                    }
                }
                break :blk self.delete_query.?.toSql(self.db_type) catch |err| return err;
            },
        };
    }

    /// Execute INSERT, UPDATE, or DELETE query
    pub fn execute(self: *Self) errors.DigError!void {
        if (self.build_error) |err| {
            return err;
        }
        const sql = switch (self.query_type) {
            .select => return errors.DigError.QueryBuildError, // Use get() for SELECT
            .insert => blk: {
                if (self.insert_query == null) {
                    return errors.DigError.QueryBuildError;
                }
                break :blk self.insert_query.?.toSql(self.db_type) catch |err| return err;
            },
            .update => blk: {
                if (self.update_query == null) {
                    return errors.DigError.QueryBuildError;
                }
                break :blk self.update_query.?.toSql(self.db_type) catch |err| return err;
            },
            .delete => blk: {
                if (self.delete_query == null) {
                    self.delete_query = query.Delete.init(self.allocator, self.table_name) catch |err| return err;
                    // Apply pending WHERE clauses when creating new delete query
                    self.applyPendingWhereClauses();
                    if (self.build_error) |err| {
                        return err;
                    }
                }
                break :blk self.delete_query.?.toSql(self.db_type) catch |err| return err;
            },
        };
        defer self.allocator.free(sql);

        return self.conn.execute(sql, self.allocator);
    }

    /// Start a DELETE query
    pub fn delete(self: *Self) *Self {
        if (self.build_error != null) return self;
        const was_delete = self.query_type == .delete;
        self.query_type = .delete;
        if (self.delete_query == null) {
            self.delete_query = query.Delete.init(self.allocator, self.table_name) catch |err| {
                self.build_error = err;
                return self;
            };
            // Apply pending WHERE clauses when creating new delete query
            if (!was_delete) {
                self.applyPendingWhereClauses();
            }
        }
        return self;
    }
};
