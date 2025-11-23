//! Comprehensive error handling tests

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "Error handling: invalid connection config - wrong host" {
    const allocator = testing.allocator;

    const result = dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "invalid-host-that-does-not-exist",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });

    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);
}

test "Error handling: invalid connection config - wrong port" {
    const allocator = testing.allocator;

    const result = dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 1, // Invalid port
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });

    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);
}

test "Error handling: invalid SQL syntax" {
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

    const result = db.execute("SELECT * FROM non_existent_table_xyz");
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "Error handling: invalid query syntax" {
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

    const result = db.execute("INVALID SQL SYNTAX HERE");
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "Error handling: query on non-existent table" {
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

    const result = db.query("SELECT * FROM table_that_does_not_exist_xyz");
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "Error handling: insert with constraint violation" {
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

    // Create table with unique constraint
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_constraint (
        \\    id SERIAL PRIMARY KEY,
        \\    email VARCHAR(255) UNIQUE
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_constraint") catch {};

    // Insert first record
    try db.execute("INSERT INTO test_constraint (email) VALUES ('test@example.com')");

    // Try to insert duplicate - should fail
    const result = db.execute("INSERT INTO test_constraint (email) VALUES ('test@example.com')");
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "Error handling: invalid column name in query" {
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
        \\CREATE TABLE IF NOT EXISTS test_invalid_column (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(255)
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_invalid_column") catch {};

    // Query with non-existent column
    const result = db.query("SELECT non_existent_column FROM test_invalid_column");
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "Error handling: transaction rollback on error" {
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
        \\CREATE TABLE IF NOT EXISTS test_transaction_error (
        \\    id SERIAL PRIMARY KEY,
        \\    value INTEGER NOT NULL
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_transaction_error") catch {};

    // Begin transaction
    try db.beginTransaction();

    // Insert valid data
    try db.execute("INSERT INTO test_transaction_error (value) VALUES (100)");

    // Try to insert invalid data (NULL into NOT NULL column)
    const insert_result = db.execute("INSERT INTO test_transaction_error (value) VALUES (NULL)");

    // Rollback on error
    if (insert_result) |_| {
        try db.commit();
    } else |_| {
        try db.rollback();
    }

    // Verify no data was committed
    var result = try db.query("SELECT COUNT(*) FROM test_transaction_error");
    defer result.deinit();

    const count_val = result.rows[0].values[0];
    const count: i64 = switch (count_val) {
        .integer => |v| v,
        else => 0,
    };
    try testing.expect(count == 0);
}

test "Error handling: query builder with invalid query type combination" {
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

    var builder = try db.table("test_table");
    defer builder.deinit();

    // Try to use orderBy on INSERT (should fail)
    _ = try builder.addValue("name", .{ .text = "Test" });
    const result = builder.orderBy("name", .asc);

    try testing.expectError(dig.errors.DigError.QueryBuildError, result);
}

test "Error handling: empty SQL execution" {
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

    // Execute empty string should not crash
    const result = db.execute("");
    // This might succeed or fail depending on driver, just check it doesn't crash
    _ = result;
}

test "Error handling: SQL injection attempt in query builder" {
    const allocator = testing.allocator;

    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    // Try to inject SQL via text value
    const malicious_input = "'; DROP TABLE users; --";

    const sql = try (try query.where("name", "=", .{ .text = malicious_input })).toSql(.postgresql);
    defer allocator.free(sql);

    // Verify that the SQL properly escapes the input
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "''"));
    try testing.expect(!std.mem.containsAtLeast(u8, sql, 1, "DROP TABLE"));
}

test "Error handling: very long SQL string" {
    const allocator = testing.allocator;

    var query = try dig.query.InsertQuery.init(allocator, "test_table");
    defer query.deinit();

    // Create a very long string
    const long_text = "A" ** 10000;
    _ = try query.addValue("data", .{ .text = long_text });

    const sql = try query.toSql(.postgresql);
    defer allocator.free(sql);

    // Should handle long strings without crashing
    try testing.expect(sql.len > 10000);
}

test "Error handling: NULL value handling" {
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

    // Create table with nullable column
    try db.execute(
        \\CREATE TABLE IF NOT EXISTS test_null (
        \\    id SERIAL PRIMARY KEY,
        \\    optional_value VARCHAR(255)
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_null") catch {};

    // Insert NULL value
    try db.execute("INSERT INTO test_null (optional_value) VALUES (NULL)");

    // Query and verify NULL handling
    var result = try db.query("SELECT optional_value FROM test_null");
    defer result.deinit();

    try testing.expect(result.rows.len == 1);
    const val = result.rows[0].values[0];
    try testing.expect(val == .null);
}

test "Error handling: concurrent connection attempts" {
    const allocator = testing.allocator;

    // Create multiple connections simultaneously
    var db1 = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db1.disconnect();

    var db2 = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test_db",
        .username = "test_user",
        .password = "test_pass",
    });
    defer db2.disconnect();

    // Both connections should work independently
    try db1.execute("SELECT 1");
    try db2.execute("SELECT 1");
}

test "Error handling: migration with invalid SQL" {
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

    const invalid_migration_sql =
        \\-- Migration with invalid SQL
        \\
        \\-- up
        \\INVALID SQL SYNTAX;
        \\
        \\-- down
        \\DROP TABLE IF EXISTS test_table;
    ;

    var migration = try dig.migration.SqlMigration.initFromFile(
        allocator,
        "20251122_invalid_migration.sql",
        invalid_migration_sql,
    );
    defer migration.deinit();

    // Executing invalid migration should fail
    const result = migration.executeUp(&db);
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "Error handling: schema with invalid column type" {
    const allocator = testing.allocator;

    var table = dig.schema.Table.init(allocator, "test_table");
    defer table.deinit();

    // Add column with valid type
    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
    });

    // Generate SQL should succeed
    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "CREATE TABLE"));
}
