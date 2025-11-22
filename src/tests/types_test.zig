//! Tests for type definitions

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "SqlValue: integer value" {
    const allocator = testing.allocator;
    const value = dig.types.SqlValue{ .integer = 42 };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.eql(u8, sql_str, "42"));
}

test "SqlValue: float value" {
    const allocator = testing.allocator;
    const value = dig.types.SqlValue{ .float = 3.14 };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.containsAtLeast(u8, sql_str, 1, "3"));
}

test "SqlValue: text value" {
    const allocator = testing.allocator;
    const value = dig.types.SqlValue{ .text = "Hello World" };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.containsAtLeast(u8, sql_str, 1, "Hello World"));
    try testing.expect(std.mem.startsWith(u8, sql_str, "'"));
    try testing.expect(std.mem.endsWith(u8, sql_str, "'"));
}

test "SqlValue: text value with single quote escaping" {
    const allocator = testing.allocator;
    const value = dig.types.SqlValue{ .text = "O'Reilly" };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    // Should escape single quotes as ''
    try testing.expect(std.mem.containsAtLeast(u8, sql_str, 1, "''"));
}

test "SqlValue: boolean true" {
    const allocator = testing.allocator;
    const value = dig.types.SqlValue{ .boolean = true };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.eql(u8, sql_str, "TRUE"));
}

test "SqlValue: boolean false" {
    const allocator = testing.allocator;
    const value = dig.types.SqlValue{ .boolean = false };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.eql(u8, sql_str, "FALSE"));
}

test "SqlValue: null value" {
    const allocator = testing.allocator;
    const value: dig.types.SqlValue = .null;

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.eql(u8, sql_str, "NULL"));
}

test "SqlValue: blob value" {
    const allocator = testing.allocator;
    const blob_data = [_]u8{ 0x48, 0x65, 0x6C, 0x6C, 0x6F }; // "Hello" in hex
    const value = dig.types.SqlValue{ .blob = &blob_data };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.startsWith(u8, sql_str, "x'"));
    try testing.expect(std.mem.endsWith(u8, sql_str, "'"));
}

test "SqlValue: timestamp value" {
    const allocator = testing.allocator;
    const timestamp: i64 = 1609459200; // 2021-01-01 00:00:00 UTC
    const value = dig.types.SqlValue{ .timestamp = timestamp };

    const sql_str = try value.toSqlString(allocator);
    defer allocator.free(sql_str);

    try testing.expect(std.mem.eql(u8, sql_str, "1609459200"));
}

test "ConnectionConfig: PostgreSQL connection string" {
    const allocator = testing.allocator;
    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };

    const conn_str = try config.toConnectionString(allocator);
    defer allocator.free(conn_str);

    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "postgresql://"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "user"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "pass"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "localhost"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "5432"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "mydb"));
}

test "ConnectionConfig: MySQL connection string" {
    const allocator = testing.allocator;
    const config = dig.types.ConnectionConfig{
        .database_type = .mysql,
        .host = "localhost",
        .port = 3306,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };

    const conn_str = try config.toConnectionString(allocator);
    defer allocator.free(conn_str);

    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "mysql://"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "user"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "pass"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "localhost"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "3306"));
    try testing.expect(std.mem.containsAtLeast(u8, conn_str, 1, "mydb"));
}

test "DatabaseType: enum values" {
    try testing.expect(@intFromEnum(dig.types.DatabaseType.postgresql) == 0);
    try testing.expect(@intFromEnum(dig.types.DatabaseType.mysql) == 1);
}
