//! Tests for schema definition

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "Table: create empty table" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try testing.expect(std.mem.eql(u8, table.name, "users"));
    try testing.expect(table.columns.len == 0);
}

test "Table: add column" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
    });

    try testing.expect(table.columns.len == 1);
    try testing.expect(std.mem.eql(u8, table.columns[0].name, "id"));
    try testing.expect(table.columns[0].type == .bigint);
    try testing.expect(table.columns[0].primary_key == true);
}

test "Table: add multiple columns" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
    });

    try table.addColumn(.{
        .name = "name",
        .type = .varchar,
        .length = 255,
        .nullable = false,
    });

    try table.addColumn(.{
        .name = "email",
        .type = .varchar,
        .length = 255,
        .unique = true,
    });

    try testing.expect(table.columns.len == 3);
    try testing.expect(std.mem.eql(u8, table.columns[0].name, "id"));
    try testing.expect(std.mem.eql(u8, table.columns[1].name, "name"));
    try testing.expect(std.mem.eql(u8, table.columns[2].name, "email"));
}

test "Table: generate CREATE TABLE SQL for PostgreSQL" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });

    try table.addColumn(.{
        .name = "name",
        .type = .varchar,
        .length = 255,
        .nullable = false,
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "CREATE TABLE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "users"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "id"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "name"));
}

test "Table: generate CREATE TABLE SQL for MySQL" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });

    const sql = try table.toCreateTableSql(.mysql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "CREATE TABLE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "AUTO_INCREMENT"));
}

test "Table: column with default value" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "status",
        .type = .varchar,
        .length = 50,
        .default_value = "'active'",
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "DEFAULT"));
}

test "Table: nullable column" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "optional_field",
        .type = .text,
        .nullable = true,
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    // Should not contain "NOT NULL"
    try testing.expect(!std.mem.containsAtLeast(u8, sql, 1, "NOT NULL"));
}

test "Table: NOT NULL column" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "required_field",
        .type = .text,
        .nullable = false,
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "NOT NULL"));
}

test "Table: unique column" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "email",
        .type = .varchar,
        .length = 255,
        .unique = true,
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "UNIQUE"));
}

test "Table: varchar with length" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "name",
        .type = .varchar,
        .length = 100,
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "VARCHAR(100)"));
}

test "Table: varchar without length defaults to 255" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "name",
        .type = .varchar,
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "VARCHAR"));
}

test "Table: JSON column type differences" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "data");
    defer table.deinit();

    try table.addColumn(.{
        .name = "json_data",
        .type = .json,
    });

    const pg_sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(pg_sql);

    const mysql_sql = try table.toCreateTableSql(.mysql, allocator);
    defer allocator.free(mysql_sql);

    // PostgreSQL uses JSONB, MySQL uses JSON
    try testing.expect(std.mem.containsAtLeast(u8, pg_sql, 1, "JSONB"));
    try testing.expect(std.mem.containsAtLeast(u8, mysql_sql, 1, "JSON"));
}

test "Table: complex table definition" {
    const allocator = testing.allocator;
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });

    try table.addColumn(.{
        .name = "username",
        .type = .varchar,
        .length = 50,
        .unique = true,
        .nullable = false,
    });

    try table.addColumn(.{
        .name = "email",
        .type = .varchar,
        .length = 255,
        .unique = true,
        .nullable = false,
    });

    try table.addColumn(.{
        .name = "age",
        .type = .integer,
        .nullable = true,
    });

    try table.addColumn(.{
        .name = "created_at",
        .type = .timestamp,
        .nullable = false,
        .default_value = "CURRENT_TIMESTAMP",
    });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(table.columns.len == 5);
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "CREATE TABLE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "PRIMARY KEY"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "UNIQUE"));
}
