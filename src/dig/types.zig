//! Common type definitions for Dig ORM

const std = @import("std");

/// Database type enumeration
pub const DatabaseType = enum {
    postgresql,
    mysql,
    mock, // Mock driver for testing
};

/// SQL value types
pub const SqlValue = union(enum) {
    null,
    integer: i64,
    float: f64,
    text: []const u8,
    boolean: bool,
    blob: []const u8,
    timestamp: i64, // Unix timestamp

    /// Convert SqlValue to string representation for SQL
    /// Returns an allocated string that must be freed by the caller
    pub fn toSqlString(self: SqlValue, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .null => try allocator.dupe(u8, "NULL"),
            .integer => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .float => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .text => |v| {
                var escaped = try std.ArrayList(u8).initCapacity(allocator, v.len * 2 + 2);
                defer escaped.deinit(allocator);
                try escaped.append(allocator, '\'');
                for (v) |c| {
                    if (c == '\'') {
                        try escaped.appendSlice(allocator, "''");
                    } else {
                        try escaped.append(allocator, c);
                    }
                }
                try escaped.append(allocator, '\'');
                return escaped.toOwnedSlice(allocator);
            },
            .boolean => |v| try allocator.dupe(u8, if (v) "TRUE" else "FALSE"),
            .blob => |v| {
                var hex = try std.ArrayList(u8).initCapacity(allocator, v.len * 2 + 3);
                defer hex.deinit(allocator);
                try hex.appendSlice(allocator, "x'");
                for (v) |b| {
                    try std.fmt.format(hex.writer(allocator), "{x:0>2}", .{b});
                }
                try hex.append(allocator, '\'');
                return hex.toOwnedSlice(allocator);
            },
            .timestamp => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
        };
    }
};

/// Connection configuration
pub const ConnectionConfig = struct {
    database_type: DatabaseType,
    host: []const u8,
    port: u16,
    database: []const u8,
    username: []const u8,
    password: []const u8,
    ssl: bool = false,

    /// Create connection string
    pub fn toConnectionString(self: ConnectionConfig, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self.database_type) {
            .postgresql => try std.fmt.allocPrint(
                allocator,
                "postgresql://{s}:{s}@{s}:{d}/{s}",
                .{ self.username, self.password, self.host, self.port, self.database },
            ),
            .mysql => try std.fmt.allocPrint(
                allocator,
                "mysql://{s}:{s}@{s}:{d}/{s}",
                .{ self.username, self.password, self.host, self.port, self.database },
            ),
            .mock => try std.fmt.allocPrint(
                allocator,
                "mock://{s}:{d}/{s}",
                .{ self.host, self.port, self.database },
            ),
        };
    }
};
