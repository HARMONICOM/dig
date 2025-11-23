//! Schema definition system

const std = @import("std");
const errors = @import("errors.zig");

/// Column type definitions
pub const ColumnType = enum {
    integer,
    bigint,
    text,
    varchar,
    boolean,
    float,
    double,
    timestamp,
    blob,
    json,
};

/// Column definition
pub const Column = struct {
    name: []const u8,
    type: ColumnType,
    nullable: bool = false,
    primary_key: bool = false,
    auto_increment: bool = false,
    unique: bool = false,
    default_value: ?[]const u8 = null,
    length: ?usize = null, // For varchar

    /// Convert column type to SQL string
    pub fn toSqlType(self: Column, db_type: @import("types.zig").DatabaseType, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.type) {
            .integer => "INTEGER",
            .bigint => switch (db_type) {
                .postgresql => "BIGINT",
                .mysql => "BIGINT",
                .mock => "BIGINT",
            },
            .text => "TEXT",
            .varchar => if (self.length) |len| {
                return switch (db_type) {
                    .postgresql => try std.fmt.allocPrint(allocator, "VARCHAR({d})", .{len}),
                    .mysql => try std.fmt.allocPrint(allocator, "VARCHAR({d})", .{len}),
                    .mock => try std.fmt.allocPrint(allocator, "VARCHAR({d})", .{len}),
                };
            } else "VARCHAR(255)",
            .boolean => switch (db_type) {
                .postgresql => "BOOLEAN",
                .mysql => "BOOLEAN",
                .mock => "BOOLEAN",
            },
            .float => "FLOAT",
            .double => "DOUBLE",
            .timestamp => switch (db_type) {
                .postgresql => "TIMESTAMP",
                .mysql => "TIMESTAMP",
                .mock => "TIMESTAMP",
            },
            .blob => "BLOB",
            .json => switch (db_type) {
                .postgresql => "JSONB",
                .mysql => "JSON",
                .mock => "JSON",
            },
        };
    }
};

/// Table definition
pub const Table = struct {
    name: []const u8,
    columns: []const Column,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Table {
        return .{
            .name = name,
            .columns = &.{},
            .allocator = allocator,
        };
    }

    pub fn addColumn(self: *Table, column: Column) !void {
        var new_columns = try std.ArrayList(Column).initCapacity(self.allocator, self.columns.len + 1);
        defer new_columns.deinit(self.allocator);
        try new_columns.appendSlice(self.allocator, self.columns);
        try new_columns.append(self.allocator, column);
        const old_columns = self.columns;
        self.columns = try new_columns.toOwnedSlice(self.allocator);
        if (old_columns.len > 0) {
            self.allocator.free(old_columns);
        }
    }

    /// Generate CREATE TABLE SQL
    pub fn toCreateTableSql(self: Table, db_type: @import("types.zig").DatabaseType, allocator: std.mem.Allocator) ![]const u8 {
        var sql = try std.ArrayList(u8).initCapacity(allocator, 256);
        defer sql.deinit(allocator);
        var writer = sql.writer(allocator);

        try writer.print("CREATE TABLE IF NOT EXISTS {s} (", .{self.name});

        for (self.columns, 0..) |col, i| {
            if (i > 0) try writer.writeAll(", ");
            const sql_type = try col.toSqlType(db_type, allocator);
            const needs_free = col.type == .varchar and col.length != null;
            defer if (needs_free) allocator.free(sql_type);
            try writer.print("{s} {s}", .{ col.name, sql_type });

            if (col.primary_key) try writer.writeAll(" PRIMARY KEY");
            if (col.auto_increment) {
                switch (db_type) {
                    .postgresql => try writer.writeAll(" SERIAL"),
                    .mysql => try writer.writeAll(" AUTO_INCREMENT"),
                    .mock => try writer.writeAll(" AUTO_INCREMENT"),
                }
            }
            if (col.unique) try writer.writeAll(" UNIQUE");
            if (!col.nullable) try writer.writeAll(" NOT NULL");
            if (col.default_value) |default| {
                try writer.print(" DEFAULT {s}", .{default});
            }
        }

        try writer.writeAll(")");

        return sql.toOwnedSlice(allocator);
    }

    pub fn deinit(self: *Table) void {
        self.allocator.free(self.columns);
    }
};
