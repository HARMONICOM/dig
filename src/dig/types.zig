//! Common type definitions for Dig ORM

const std = @import("std");
const errors = @import("errors.zig");

/// Helper function to convert allocator errors to DigError
fn convertAllocatorError(err: std.mem.Allocator.Error) errors.DigError {
    return switch (err) {
        error.OutOfMemory => errors.DigError.OutOfMemory,
    };
}

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
    pub fn toSqlString(self: SqlValue, allocator: std.mem.Allocator) errors.DigError![]const u8 {
        return switch (self) {
            .null => allocator.dupe(u8, "NULL") catch |err| return convertAllocatorError(err),
            .integer => |v| std.fmt.allocPrint(allocator, "{d}", .{v}) catch |err| return convertAllocatorError(err),
            .float => |v| std.fmt.allocPrint(allocator, "{d}", .{v}) catch |err| return convertAllocatorError(err),
            .text => |v| {
                var escaped = std.ArrayList(u8).initCapacity(allocator, v.len * 2 + 2) catch |err| return convertAllocatorError(err);
                defer escaped.deinit(allocator);
                escaped.append(allocator, '\'') catch |err| return convertAllocatorError(err);
                for (v) |c| {
                    if (c == '\'') {
                        escaped.appendSlice(allocator, "''") catch |err| return convertAllocatorError(err);
                    } else {
                        escaped.append(allocator, c) catch |err| return convertAllocatorError(err);
                    }
                }
                escaped.append(allocator, '\'') catch |err| return convertAllocatorError(err);
                return escaped.toOwnedSlice(allocator) catch |err| convertAllocatorError(err);
            },
            .boolean => |v| allocator.dupe(u8, if (v) "TRUE" else "FALSE") catch |err| return convertAllocatorError(err),
            .blob => |v| {
                var hex = std.ArrayList(u8).initCapacity(allocator, v.len * 2 + 3) catch |err| return convertAllocatorError(err);
                defer hex.deinit(allocator);
                hex.appendSlice(allocator, "x'") catch |err| return convertAllocatorError(err);
                for (v) |b| {
                    std.fmt.format(hex.writer(allocator), "{x:0>2}", .{b}) catch |err| return convertAllocatorError(err);
                }
                hex.append(allocator, '\'') catch |err| return convertAllocatorError(err);
                return hex.toOwnedSlice(allocator) catch |err| convertAllocatorError(err);
            },
            .timestamp => |v| std.fmt.allocPrint(allocator, "{d}", .{v}) catch |err| return convertAllocatorError(err),
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
                "postgresql://{s}:{s}@{s}:{d}/{s}?connect_timeout=5",
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
