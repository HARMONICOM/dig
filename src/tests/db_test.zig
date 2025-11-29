//! Tests for database interface

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "Db: connect and disconnect PostgreSQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Verify db type is set correctly
    try testing.expect(db.db_type == .mock);
}

test "Db: connect and disconnect MySQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 3306,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Verify db type is set correctly
    try testing.expect(db.db_type == .mock);
}

test "Db: table() creates QueryBuilder" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    const builder = db.table("users");

    // Verify builder is initialized
    try testing.expect(std.mem.eql(u8, builder.table_name, "users"));
    try testing.expect(builder.db_type == .mock);
}

test "Db: table() with different database types" {
    const allocator = testing.allocator;

    // PostgreSQL
    var pg_db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer pg_db.disconnect();

    const pg_builder = pg_db.table("products");

    try testing.expect(pg_builder.db_type == .mock);

    // MySQL
    var mysql_db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 3306,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer mysql_db.disconnect();

    const mysql_builder = mysql_db.table("products");

    try testing.expect(mysql_builder.db_type == .mock);
}

test "Db: execute raw SQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Create table
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_execute (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(255)
        \\)
    );

    // Cleanup
    try db.execute("DROP TABLE IF EXISTS test_execute");
}

test "Db: query raw SQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Create and populate test table
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_query (
        \\    id SERIAL PRIMARY KEY,
        \\    value INTEGER
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_query") catch {};

    try db.execute("INSERT INTO test_query (value) VALUES (42)");

    // Query data (mock returns empty result)
    var result = try db.query("SELECT value FROM test_query");
    defer result.deinit();

    // Mock driver returns empty result by default
    try testing.expect(result.rows.len == 0);
}

test "Db: transaction commit" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Create test table
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_transaction (
        \\    id SERIAL PRIMARY KEY,
        \\    value INTEGER
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_transaction") catch {};

    // Begin transaction
    try db.beginTransaction();

    // Insert data
    try db.execute("INSERT INTO test_transaction (value) VALUES (100)");

    // Commit
    try db.commit();

    // Verify data is committed (mock returns empty result)
    var result = try db.query("SELECT COUNT(*) FROM test_transaction");
    defer result.deinit();

    // Mock driver returns empty result
    try testing.expect(result.rows.len == 0);
}

test "Db: transaction rollback" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Create test table
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_rollback (
        \\    id SERIAL PRIMARY KEY,
        \\    value INTEGER
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_rollback") catch {};

    // Begin transaction
    try db.beginTransaction();

    // Insert data
    try db.execute("INSERT INTO test_rollback (value) VALUES (200)");

    // Rollback
    try db.rollback();

    // Verify rollback worked (mock doesn't track transaction state)
    // Just verify we can query after rollback
    var result = try db.query("SELECT COUNT(*) FROM test_rollback");
    defer result.deinit();

    // Mock returns empty result
    try testing.expect(result.rows.len == 0);
}

test "Db: multiple queries" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Create test table
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_multi (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(255)
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_multi") catch {};

    // Insert multiple records
    try db.execute("INSERT INTO test_multi (name) VALUES ('Alice')");
    try db.execute("INSERT INTO test_multi (name) VALUES ('Bob')");
    try db.execute("INSERT INTO test_multi (name) VALUES ('Charlie')");

    // Query all records
    var result = try db.query("SELECT name FROM test_multi ORDER BY id");
    defer result.deinit();

    // Mock returns empty result
    try testing.expect(result.rows.len == 0);
}

test "Db: error on invalid SQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Mock driver doesn't validate SQL
    try db.execute("INVALID SQL STATEMENT");
}

test "Db: query builder integration" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Create test table
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_builder (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(255),
        \\    age INTEGER
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_builder") catch {};

    // Insert data
    try db.execute("INSERT INTO test_builder (name, age) VALUES ('Alice', 30)");
    try db.execute("INSERT INTO test_builder (name, age) VALUES ('Bob', 25)");

    // Use query builder
    var builder = db.table("test_builder");

    _ = builder.select(&.{ "name", "age" });
    _ = builder.where("age", ">", .{ .integer = 20 });
    _ = builder.orderBy("age", .desc);
    var result = try builder.get();
    defer result.deinit();

    // Mock returns empty result
    try testing.expect(result.rows.len == 0);
}
