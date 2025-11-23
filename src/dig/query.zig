//! Query builder for SQL queries

const std = @import("std");
const errors = @import("errors.zig");
const types = @import("types.zig");

/// Query builder for SELECT statements
pub const Select = struct {
    const Self = @This();

    table: []const u8,
    columns: []const []const u8,
    joins: std.ArrayList(JoinClause),
    where_clauses: std.ArrayList(WhereClause),
    order_by: ?OrderBy = null,
    limit_value: ?usize = null,
    offset_value: ?usize = null,
    allocator: std.mem.Allocator,

    pub const Direction = enum { asc, desc };

    pub const JoinType = enum {
        inner,
        left,
        right,
        full,
    };

    pub const JoinClause = struct {
        join_type: JoinType,
        table: []const u8,
        left_column: []const u8,
        right_column: []const u8,
    };

    pub const WhereClause = struct {
        column: []const u8,
        operator: []const u8,
        value: types.SqlValue,
    };

    pub const OrderBy = struct {
        column: []const u8,
        direction: Direction,
    };

    pub fn init(allocator: std.mem.Allocator, table: []const u8) !Self {
        return .{
            .table = table,
            .columns = &.{},
            .joins = try std.ArrayList(JoinClause).initCapacity(allocator, 4),
            .where_clauses = try std.ArrayList(WhereClause).initCapacity(allocator, 4),
            .order_by = null,
            .limit_value = null,
            .offset_value = null,
            .allocator = allocator,
        };
    }

    pub fn select(self: *Self, columns: []const []const u8) *Self {
        self.columns = columns;
        return self;
    }

    /// Add INNER JOIN clause
    pub fn join(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        try self.joins.append(self.allocator, .{
            .join_type = .inner,
            .table = table,
            .left_column = left_column,
            .right_column = right_column,
        });
        return self;
    }

    /// Add LEFT JOIN clause
    pub fn leftJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        try self.joins.append(self.allocator, .{
            .join_type = .left,
            .table = table,
            .left_column = left_column,
            .right_column = right_column,
        });
        return self;
    }

    /// Add RIGHT JOIN clause
    pub fn rightJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        try self.joins.append(self.allocator, .{
            .join_type = .right,
            .table = table,
            .left_column = left_column,
            .right_column = right_column,
        });
        return self;
    }

    /// Add FULL OUTER JOIN clause
    pub fn fullJoin(self: *Self, table: []const u8, left_column: []const u8, right_column: []const u8) !*Self {
        try self.joins.append(self.allocator, .{
            .join_type = .full,
            .table = table,
            .left_column = left_column,
            .right_column = right_column,
        });
        return self;
    }

    pub fn where(self: *Self, column: []const u8, operator: []const u8, value: types.SqlValue) !*Self {
        try self.where_clauses.append(self.allocator, .{
            .column = column,
            .operator = operator,
            .value = value,
        });
        return self;
    }

    pub fn orderBy(self: *Self, column: []const u8, direction: Direction) *Self {
        self.order_by = .{
            .column = column,
            .direction = direction,
        };
        return self;
    }

    pub fn limit(self: *Self, count: usize) *Self {
        self.limit_value = count;
        return self;
    }

    pub fn offset(self: *Self, count: usize) *Self {
        self.offset_value = count;
        return self;
    }

    pub fn toSql(self: *Self, _: types.DatabaseType) ![]const u8 {
        var sql = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        defer sql.deinit(self.allocator);
        var writer = sql.writer(self.allocator);

        try writer.writeAll("SELECT ");
        if (self.columns.len == 0) {
            try writer.writeAll("*");
        } else {
            for (self.columns, 0..) |col, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("{s}", .{col});
            }
        }

        try writer.print(" FROM {s}", .{self.table});

        // Add JOIN clauses
        for (self.joins.items) |join_clause| {
            const join_type_str = switch (join_clause.join_type) {
                .inner => "INNER JOIN",
                .left => "LEFT JOIN",
                .right => "RIGHT JOIN",
                .full => "FULL OUTER JOIN",
            };
            try writer.print(" {s} {s} ON {s} = {s}", .{
                join_type_str,
                join_clause.table,
                join_clause.left_column,
                join_clause.right_column,
            });
        }

        if (self.where_clauses.items.len > 0) {
            try writer.writeAll(" WHERE ");
            for (self.where_clauses.items, 0..) |clause, i| {
                if (i > 0) try writer.writeAll(" AND ");
                const value_str = try clause.value.toSqlString(self.allocator);
                defer self.allocator.free(value_str);
                try writer.print("{s} {s} {s}", .{ clause.column, clause.operator, value_str });
            }
        }

        if (self.order_by) |order| {
            try writer.print(" ORDER BY {s} {s}", .{ order.column, if (order.direction == .asc) "ASC" else "DESC" });
        }

        if (self.limit_value) |limit_val| {
            try writer.print(" LIMIT {d}", .{limit_val});
        }

        if (self.offset_value) |offset_val| {
            try writer.print(" OFFSET {d}", .{offset_val});
        }

        return sql.toOwnedSlice(self.allocator);
    }

    pub fn deinit(self: *Self) void {
        self.joins.deinit(self.allocator);
        self.where_clauses.deinit(self.allocator);
    }
};

/// Query builder for INSERT statements
pub const Insert = struct {
    const Self = @This();

    table: []const u8,
    values: std.ArrayList(ValuePair),
    allocator: std.mem.Allocator,

    pub const ValuePair = struct {
        column: []const u8,
        value: types.SqlValue,
    };

    pub fn init(allocator: std.mem.Allocator, table: []const u8) !Self {
        return .{
            .table = table,
            .values = try std.ArrayList(ValuePair).initCapacity(allocator, 4),
            .allocator = allocator,
        };
    }

    pub fn addValue(self: *Self, column: []const u8, value: types.SqlValue) !*Self {
        try self.values.append(self.allocator, .{ .column = column, .value = value });
        return self;
    }

    /// Set multiple values from a hash map
    pub fn setValues(self: *Self, values: std.StringHashMap(types.SqlValue)) !*Self {
        var iterator = values.iterator();
        while (iterator.next()) |entry| {
            _ = try self.addValue(entry.key_ptr.*, entry.value_ptr.*);
        }
        return self;
    }

    pub fn toSql(self: *Self, _: types.DatabaseType) ![]const u8 {
        var sql = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        defer sql.deinit(self.allocator);
        var writer = sql.writer(self.allocator);

        try writer.print("INSERT INTO {s} (", .{self.table});

        for (self.values.items, 0..) |item, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("{s}", .{item.column});
        }

        try writer.writeAll(") VALUES (");

        for (self.values.items, 0..) |item, i| {
            if (i > 0) try writer.writeAll(", ");
            const value_str = try item.value.toSqlString(self.allocator);
            defer self.allocator.free(value_str);
            try writer.print("{s}", .{value_str});
        }

        try writer.writeAll(")");

        return sql.toOwnedSlice(self.allocator);
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit(self.allocator);
    }
};

/// Query builder for UPDATE statements
pub const Update = struct {
    const Self = @This();

    table: []const u8,
    set_clauses: std.ArrayList(SetClause),
    where_clauses: std.ArrayList(Select.WhereClause),
    allocator: std.mem.Allocator,

    pub const SetClause = struct {
        column: []const u8,
        value: types.SqlValue,
    };

    pub fn init(allocator: std.mem.Allocator, table: []const u8) !Self {
        return .{
            .table = table,
            .set_clauses = try std.ArrayList(SetClause).initCapacity(allocator, 4),
            .where_clauses = try std.ArrayList(Select.WhereClause).initCapacity(allocator, 4),
            .allocator = allocator,
        };
    }

    pub fn set(self: *Self, column: []const u8, value: types.SqlValue) !*Self {
        try self.set_clauses.append(self.allocator, .{ .column = column, .value = value });
        return self;
    }

    /// Set multiple columns from a hash map
    pub fn setMultiple(self: *Self, values: std.StringHashMap(types.SqlValue)) !*Self {
        var iterator = values.iterator();
        while (iterator.next()) |entry| {
            _ = try self.set(entry.key_ptr.*, entry.value_ptr.*);
        }
        return self;
    }

    pub fn where(self: *Self, column: []const u8, operator: []const u8, value: types.SqlValue) !*Self {
        try self.where_clauses.append(self.allocator, .{
            .column = column,
            .operator = operator,
            .value = value,
        });
        return self;
    }

    pub fn toSql(self: *Self, _: types.DatabaseType) ![]const u8 {
        var sql = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        defer sql.deinit(self.allocator);
        var writer = sql.writer(self.allocator);

        try writer.print("UPDATE {s} SET ", .{self.table});

        for (self.set_clauses.items, 0..) |clause, i| {
            if (i > 0) try writer.writeAll(", ");
            const value_str = try clause.value.toSqlString(self.allocator);
            defer self.allocator.free(value_str);
            try writer.print("{s} = {s}", .{ clause.column, value_str });
        }

        if (self.where_clauses.items.len > 0) {
            try writer.writeAll(" WHERE ");
            for (self.where_clauses.items, 0..) |clause, i| {
                if (i > 0) try writer.writeAll(" AND ");
                const value_str = try clause.value.toSqlString(self.allocator);
                defer self.allocator.free(value_str);
                try writer.print("{s} {s} {s}", .{ clause.column, clause.operator, value_str });
            }
        }

        return sql.toOwnedSlice(self.allocator);
    }

    pub fn deinit(self: *Self) void {
        self.set_clauses.deinit(self.allocator);
        self.where_clauses.deinit(self.allocator);
    }
};

/// Query builder for DELETE statements
pub const Delete = struct {
    const Self = @This();

    table: []const u8,
    where_clauses: std.ArrayList(Select.WhereClause),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, table: []const u8) !Self {
        return .{
            .table = table,
            .where_clauses = try std.ArrayList(Select.WhereClause).initCapacity(allocator, 4),
            .allocator = allocator,
        };
    }

    pub fn where(self: *Self, column: []const u8, operator: []const u8, value: types.SqlValue) !*Self {
        try self.where_clauses.append(self.allocator, .{
            .column = column,
            .operator = operator,
            .value = value,
        });
        return self;
    }

    pub fn toSql(self: *Self, _: types.DatabaseType) ![]const u8 {
        var sql = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        defer sql.deinit(self.allocator);
        var writer = sql.writer(self.allocator);

        try writer.print("DELETE FROM {s}", .{self.table});

        if (self.where_clauses.items.len > 0) {
            try writer.writeAll(" WHERE ");
            for (self.where_clauses.items, 0..) |clause, i| {
                if (i > 0) try writer.writeAll(" AND ");
                const value_str = try clause.value.toSqlString(self.allocator);
                defer self.allocator.free(value_str);
                try writer.print("{s} {s} {s}", .{ clause.column, clause.operator, value_str });
            }
        }

        return sql.toOwnedSlice(self.allocator);
    }

    pub fn deinit(self: *Self) void {
        self.where_clauses.deinit(self.allocator);
    }
};

// Aliases for backward compatibility
pub const SelectQuery = Select;
pub const InsertQuery = Insert;
pub const UpdateQuery = Update;
pub const DeleteQuery = Delete;
