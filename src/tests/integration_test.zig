//! Integration tests for Dig ORM

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "Full workflow: schema to query" {
    const allocator = testing.allocator;

    // 1. Create table schema
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

    try table.addColumn(.{
        .name = "email",
        .type = .varchar,
        .length = 255,
        .unique = true,
    });

    // 2. Generate CREATE TABLE SQL
    const create_sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(create_sql);

    try testing.expect(std.mem.containsAtLeast(u8, create_sql, 1, "CREATE TABLE"));
    try testing.expect(std.mem.containsAtLeast(u8, create_sql, 1, "users"));

    // 3. Build INSERT query
    var insert_query = try dig.query.InsertQuery.init(allocator, "users");
    defer insert_query.deinit();

    const insert_sql = try (try (try insert_query
        .addValue("name", .{ .text = "John Doe" }))
        .addValue("email", .{ .text = "john@example.com" }))
        .toSql(.postgresql);
    defer allocator.free(insert_sql);

    try testing.expect(std.mem.containsAtLeast(u8, insert_sql, 1, "INSERT INTO"));
    try testing.expect(std.mem.containsAtLeast(u8, insert_sql, 1, "users"));

    // 4. Build SELECT query
    var select_query = try dig.query.SelectQuery.init(allocator, "users");
    defer select_query.deinit();

    const select_sql = try (try select_query
        .select(&[_][]const u8{ "id", "name", "email" })
        .where("email", "=", .{ .text = "john@example.com" }))
        .toSql(.postgresql);
    defer allocator.free(select_sql);

    try testing.expect(std.mem.containsAtLeast(u8, select_sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, select_sql, 1, "FROM users"));
    try testing.expect(std.mem.containsAtLeast(u8, select_sql, 1, "WHERE"));

    // 5. Build UPDATE query
    var update_query = try dig.query.UpdateQuery.init(allocator, "users");
    defer update_query.deinit();

    const update_sql = try (try (try update_query
        .set("name", .{ .text = "Jane Doe" }))
        .where("id", "=", .{ .integer = 1 }))
        .toSql(.postgresql);
    defer allocator.free(update_sql);

    try testing.expect(std.mem.containsAtLeast(u8, update_sql, 1, "UPDATE"));
    try testing.expect(std.mem.containsAtLeast(u8, update_sql, 1, "SET"));
    try testing.expect(std.mem.containsAtLeast(u8, update_sql, 1, "WHERE"));

    // 6. Build DELETE query
    var delete_query = try dig.query.DeleteQuery.init(allocator, "users");
    defer delete_query.deinit();

    const delete_sql = try (try delete_query
        .where("id", "=", .{ .integer = 1 }))
        .toSql(.postgresql);
    defer allocator.free(delete_sql);

    try testing.expect(std.mem.containsAtLeast(u8, delete_sql, 1, "DELETE FROM"));
    try testing.expect(std.mem.containsAtLeast(u8, delete_sql, 1, "WHERE"));
}

test "Query builder chaining" {
    const allocator = testing.allocator;

    var query = try dig.query.SelectQuery.init(allocator, "products");
    defer query.deinit();

    // Chain multiple methods
    const sql = try (try (try query
        .select(&[_][]const u8{ "id", "name", "price" })
        .where("price", ">", .{ .float = 10.0 }))
        .where("stock", ">", .{ .integer = 0 }))
        .orderBy("price", .asc)
        .limit(20)
        .offset(0)
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "AND"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "ORDER BY"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LIMIT"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "OFFSET"));
}

test "Different SQL value types in queries" {
    const allocator = testing.allocator;

    var query = try dig.query.InsertQuery.init(allocator, "test_table");
    defer query.deinit();

    const sql = try (try (try (try (try (try query
        .addValue("int_col", .{ .integer = 42 }))
        .addValue("float_col", .{ .float = 3.14 }))
        .addValue("text_col", .{ .text = "Hello" }))
        .addValue("bool_col", .{ .boolean = true }))
        .addValue("null_col", .null))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "42"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "Hello"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "TRUE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "NULL"));
}

test "Cross-database compatibility" {
    const allocator = testing.allocator;

    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const pg_sql = try query.select(&[_][]const u8{"id"}).toSql(.postgresql);
    defer allocator.free(pg_sql);

    const mysql_sql = try query.select(&[_][]const u8{"id"}).toSql(.mysql);
    defer allocator.free(mysql_sql);

    // Both should generate valid SELECT statements
    try testing.expect(std.mem.containsAtLeast(u8, pg_sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, mysql_sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, pg_sql, 1, "FROM users"));
    try testing.expect(std.mem.containsAtLeast(u8, mysql_sql, 1, "FROM users"));
}

test "Complex schema with all column types" {
    const allocator = testing.allocator;

    var table = dig.schema.Table.init(allocator, "all_types");
    defer table.deinit();

    try table.addColumn(.{ .name = "id", .type = .bigint, .primary_key = true });
    try table.addColumn(.{ .name = "int_col", .type = .integer });
    try table.addColumn(.{ .name = "text_col", .type = .text });
    try table.addColumn(.{ .name = "varchar_col", .type = .varchar, .length = 100 });
    try table.addColumn(.{ .name = "bool_col", .type = .boolean });
    try table.addColumn(.{ .name = "float_col", .type = .float });
    try table.addColumn(.{ .name = "double_col", .type = .double });
    try table.addColumn(.{ .name = "timestamp_col", .type = .timestamp });
    try table.addColumn(.{ .name = "blob_col", .type = .blob });
    try table.addColumn(.{ .name = "json_col", .type = .json });

    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(table.columns.len == 10);
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "CREATE TABLE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "all_types"));
}
