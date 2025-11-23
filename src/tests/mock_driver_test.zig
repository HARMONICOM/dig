//! Tests for mock database driver

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");
const mock = @import("dig").connection.@"drivers/mock.zig";

// Import mock driver directly
const MockConnection = @import("../dig/drivers/mock.zig").MockConnection;

test "MockDriver: basic connection and disconnection" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Initially not connected
    try testing.expect(!mock_conn.is_connected);

    // Connect
    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    try testing.expect(mock_conn.is_connected);

    // Disconnect
    conn.disconnect();
    try testing.expect(!mock_conn.is_connected);
}

test "MockDriver: connection failure simulation" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Set connection to fail
    mock_conn.setShouldFailConnect(true);

    const result = conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);
    try testing.expect(!mock_conn.is_connected);
}

test "MockDriver: execute query" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Execute query
    try conn.execute("CREATE TABLE users (id SERIAL PRIMARY KEY)", allocator);

    // Verify query was recorded
    const executed_queries = mock_conn.getExecutedQueries();
    try testing.expect(executed_queries.len == 1);
    try testing.expect(std.mem.containsAtLeast(u8, executed_queries[0], 1, "CREATE TABLE"));
}

test "MockDriver: execute multiple queries" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Execute multiple queries
    try conn.execute("CREATE TABLE users (id SERIAL PRIMARY KEY)", allocator);
    try conn.execute("INSERT INTO users (id) VALUES (1)", allocator);
    try conn.execute("UPDATE users SET id = 2 WHERE id = 1", allocator);

    // Verify all queries were recorded
    const executed_queries = mock_conn.getExecutedQueries();
    try testing.expect(executed_queries.len == 3);
    try testing.expect(std.mem.containsAtLeast(u8, executed_queries[0], 1, "CREATE TABLE"));
    try testing.expect(std.mem.containsAtLeast(u8, executed_queries[1], 1, "INSERT INTO"));
    try testing.expect(std.mem.containsAtLeast(u8, executed_queries[2], 1, "UPDATE"));
}

test "MockDriver: execute failure simulation" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Set execute to fail
    mock_conn.setShouldFailExecute(true);

    const result = conn.execute("CREATE TABLE users (id SERIAL PRIMARY KEY)", allocator);
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "MockDriver: query with mock results" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Add mock result
    const columns = [_][]const u8{ "id", "name" };
    const row1 = [_]dig.types.SqlValue{ .{ .integer = 1 }, .{ .text = "Alice" } };
    const row2 = [_]dig.types.SqlValue{ .{ .integer = 2 }, .{ .text = "Bob" } };
    const rows = [_][]const dig.types.SqlValue{ &row1, &row2 };

    try mock_conn.addMockResult(&columns, &rows);

    // Query
    var result = try conn.query("SELECT id, name FROM users", allocator);
    defer result.deinit();

    // Verify results
    try testing.expect(result.columns.len == 2);
    try testing.expect(std.mem.eql(u8, result.columns[0], "id"));
    try testing.expect(std.mem.eql(u8, result.columns[1], "name"));

    try testing.expect(result.rows.len == 2);

    const alice_id = result.rows[0].get("id").?;
    const alice_name = result.rows[0].get("name").?;
    try testing.expect(alice_id.integer == 1);
    try testing.expect(std.mem.eql(u8, alice_name.text, "Alice"));

    const bob_id = result.rows[1].get("id").?;
    const bob_name = result.rows[1].get("name").?;
    try testing.expect(bob_id.integer == 2);
    try testing.expect(std.mem.eql(u8, bob_name.text, "Bob"));
}

test "MockDriver: query empty result" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Query without mock results
    var result = try conn.query("SELECT * FROM users", allocator);
    defer result.deinit();

    try testing.expect(result.columns.len == 0);
    try testing.expect(result.rows.len == 0);
}

test "MockDriver: query failure simulation" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Set query to fail
    mock_conn.setShouldFailQuery(true);

    const result = conn.query("SELECT * FROM users", allocator);
    try testing.expectError(dig.errors.DigError.QueryExecutionFailed, result);
}

test "MockDriver: multiple queries with different mock results" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Add first mock result
    const columns1 = [_][]const u8{"count"};
    const row1 = [_]dig.types.SqlValue{.{ .integer = 10 }};
    const rows1 = [_][]const dig.types.SqlValue{&row1};
    try mock_conn.addMockResult(&columns1, &rows1);

    // Add second mock result
    const columns2 = [_][]const u8{ "id", "email" };
    const row2 = [_]dig.types.SqlValue{ .{ .integer = 1 }, .{ .text = "test@example.com" } };
    const rows2 = [_][]const dig.types.SqlValue{&row2};
    try mock_conn.addMockResult(&columns2, &rows2);

    // First query
    var result1 = try conn.query("SELECT COUNT(*) FROM users", allocator);
    defer result1.deinit();
    try testing.expect(result1.rows.len == 1);
    try testing.expect(result1.rows[0].values[0].integer == 10);

    // Second query
    var result2 = try conn.query("SELECT id, email FROM users WHERE id = 1", allocator);
    defer result2.deinit();
    try testing.expect(result2.rows.len == 1);
    try testing.expect(result2.rows[0].values[0].integer == 1);
    try testing.expect(std.mem.eql(u8, result2.rows[0].values[1].text, "test@example.com"));
}

test "MockDriver: transaction workflow" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Not in transaction initially
    try testing.expect(!mock_conn.in_transaction);

    // Begin transaction
    try conn.beginTransaction();
    try testing.expect(mock_conn.in_transaction);

    // Commit
    try conn.commit();
    try testing.expect(!mock_conn.in_transaction);
}

test "MockDriver: transaction rollback" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Begin transaction
    try conn.beginTransaction();
    try testing.expect(mock_conn.in_transaction);

    // Rollback
    try conn.rollback();
    try testing.expect(!mock_conn.in_transaction);
}

test "MockDriver: nested transaction error" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Begin transaction
    try conn.beginTransaction();

    // Try to begin another transaction (should fail)
    const result = conn.beginTransaction();
    try testing.expectError(dig.errors.DigError.TransactionFailed, result);
}

test "MockDriver: commit without transaction" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Try to commit without starting transaction
    const result = conn.commit();
    try testing.expectError(dig.errors.DigError.TransactionFailed, result);
}

test "MockDriver: transaction failure simulation" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Set transaction to fail
    mock_conn.setShouldFailTransaction(true);

    const result = conn.beginTransaction();
    try testing.expectError(dig.errors.DigError.TransactionFailed, result);
}

test "MockDriver: execute without connection" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Try to execute without connecting
    const result = conn.execute("CREATE TABLE users (id INT)", allocator);
    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);
}

test "MockDriver: query without connection" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Try to query without connecting
    const result = conn.query("SELECT * FROM users", allocator);
    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);
}

test "MockDriver: clear executed queries" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Execute queries
    try conn.execute("CREATE TABLE users (id INT)", allocator);
    try conn.execute("INSERT INTO users VALUES (1)", allocator);

    try testing.expect(mock_conn.getExecutedQueries().len == 2);

    // Clear history
    mock_conn.clearExecutedQueries();
    try testing.expect(mock_conn.getExecutedQueries().len == 0);

    // Execute new query
    try conn.execute("SELECT * FROM users", allocator);
    try testing.expect(mock_conn.getExecutedQueries().len == 1);
}

test "MockDriver: query with NULL values" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Add mock result with NULL value
    const columns = [_][]const u8{ "id", "optional_field" };
    const row = [_]dig.types.SqlValue{ .{ .integer = 1 }, .null };
    const rows = [_][]const dig.types.SqlValue{&row};

    try mock_conn.addMockResult(&columns, &rows);

    // Query
    var result = try conn.query("SELECT id, optional_field FROM users", allocator);
    defer result.deinit();

    try testing.expect(result.rows.len == 1);
    const optional_field = result.rows[0].get("optional_field").?;
    try testing.expect(optional_field == .null);
}

test "MockDriver: query with all SQL value types" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Add mock result with various types
    const columns = [_][]const u8{ "int_col", "float_col", "text_col", "bool_col", "timestamp_col", "null_col" };
    const row = [_]dig.types.SqlValue{
        .{ .integer = 42 },
        .{ .float = 3.14 },
        .{ .text = "Hello" },
        .{ .boolean = true },
        .{ .timestamp = 1609459200 },
        .null,
    };
    const rows = [_][]const dig.types.SqlValue{&row};

    try mock_conn.addMockResult(&columns, &rows);

    // Query
    var result = try conn.query("SELECT * FROM test_table", allocator);
    defer result.deinit();

    try testing.expect(result.rows.len == 1);
    const r = result.rows[0];

    try testing.expect(r.get("int_col").?.integer == 42);
    try testing.expect(r.get("float_col").?.float == 3.14);
    try testing.expect(std.mem.eql(u8, r.get("text_col").?.text, "Hello"));
    try testing.expect(r.get("bool_col").?.boolean == true);
    try testing.expect(r.get("timestamp_col").?.timestamp == 1609459200);
    try testing.expect(r.get("null_col").? == .null);
}
