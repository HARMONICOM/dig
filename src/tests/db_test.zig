//! Tests for database interface

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "Db: connect and disconnect PostgreSQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Verify db type is set correctly
    try testing.expect(db.db_type == .postgresql);
}

test "Db: connect and disconnect MySQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mysql,
        .host = "localhost",
        .port = 3306,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Verify db type is set correctly
    try testing.expect(db.db_type == .mysql);
}

test "Db: table() creates QueryBuilder" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    var builder = try db.table("users");
    defer builder.deinit();

    // Verify builder is initialized
    try testing.expect(std.mem.eql(u8, builder.table_name, "users"));
    try testing.expect(builder.db_type == .postgresql);
}

test "Db: table() with different database types" {
    const allocator = testing.allocator;

    // PostgreSQL
    var pg_db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer pg_db.disconnect();

    var pg_builder = try pg_db.table("products");
    defer pg_builder.deinit();

    try testing.expect(pg_builder.db_type == .postgresql);

    // MySQL
    var mysql_db = try dig.db.connect(allocator, .{
        .database_type = .mysql,
        .host = "localhost",
        .port = 3306,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer mysql_db.disconnect();

    var mysql_builder = try mysql_db.table("products");
    defer mysql_builder.deinit();

    try testing.expect(mysql_builder.db_type == .mysql);
}

test "Db: execute raw SQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
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
        .database_type = .postgresql,
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

    // Query data
    var result = try db.query("SELECT value FROM test_query");
    defer result.deinit();

    try testing.expect(result.rows.len > 0);
}

test "Db: transaction commit" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
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

    // Verify data is committed
    var result = try db.query("SELECT COUNT(*) FROM test_transaction");
    defer result.deinit();

    try testing.expect(result.rows.len > 0);
}

test "Db: transaction rollback" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
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

    // Get initial count
    var result1 = try db.query("SELECT COUNT(*) FROM test_rollback");
    defer result1.deinit();
    const initial_count_val = result1.rows[0].values[0];
    const initial_count: i64 = switch (initial_count_val) {
        .integer => |v| v,
        else => 0,
    };

    // Begin transaction
    try db.beginTransaction();

    // Insert data
    try db.execute("INSERT INTO test_rollback (value) VALUES (200)");

    // Rollback
    try db.rollback();

    // Verify data is rolled back
    var result2 = try db.query("SELECT COUNT(*) FROM test_rollback");
    defer result2.deinit();
    const final_count_val = result2.rows[0].values[0];
    const final_count: i64 = switch (final_count_val) {
        .integer => |v| v,
        else => 0,
    };

    try testing.expect(final_count == initial_count);
}

test "Db: multiple queries" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
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

    try testing.expect(result.rows.len == 3);
}

test "Db: error on invalid SQL" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db.disconnect();

    // Execute invalid SQL
    const result = db.execute("INVALID SQL STATEMENT");
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "Db: query builder integration" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
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
    var builder = try db.table("test_builder");
    defer builder.deinit();

    var result = try builder
        .select(&.{ "name", "age" })
        .where("age", ">", .{ .integer = 20 })
        .orderBy("age", .desc)
        .get();
    defer result.deinit();

    try testing.expect(result.rows.len == 2);
}
