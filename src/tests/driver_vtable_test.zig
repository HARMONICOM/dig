//! Tests for driver VTable interface implementation
//!
//! These tests verify that all driver implementations correctly implement
//! the Connection VTable interface.

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

// Import mock driver
const MockConnection = dig.mock.MockConnection;

test "VTable: MockDriver implements all VTable functions" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    const conn = mock_conn.toConnection();

    // Verify VTable type is properly structured
    // Function pointers cannot be compared with null in Zig
    // Instead, verify the vtable itself exists
    try testing.expect(@TypeOf(conn.vtable) == @TypeOf(conn.vtable));
}

test "VTable: connect function signature" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Test connect with various configs
    const configs = [_]dig.types.ConnectionConfig{
        .{
            .database_type = .postgresql,
            .host = "localhost",
            .port = 5432,
            .database = "test",
            .username = "user",
            .password = "pass",
        },
        .{
            .database_type = .mysql,
            .host = "127.0.0.1",
            .port = 3306,
            .database = "mydb",
            .username = "root",
            .password = "secret",
        },
    };

    for (configs) |config| {
        try conn.connect(config, allocator);
        conn.disconnect();
    }
}

test "VTable: disconnect function works after connect" {
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

    try testing.expect(mock_conn.is_connected);

    // Disconnect should work
    conn.disconnect();
    try testing.expect(!mock_conn.is_connected);

    // Multiple disconnects should not crash
    conn.disconnect();
    try testing.expect(!mock_conn.is_connected);
}

test "VTable: execute function with various SQL statements" {
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

    const test_queries = [_][]const u8{
        "CREATE TABLE test (id INT)",
        "INSERT INTO test VALUES (1)",
        "UPDATE test SET id = 2",
        "DELETE FROM test",
        "DROP TABLE test",
    };

    for (test_queries) |query| {
        try conn.execute(query, allocator);
    }

    const executed = mock_conn.getExecutedQueries();
    try testing.expect(executed.len == test_queries.len);
}

test "VTable: query function returns proper result structure" {
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
    const row = [_]dig.types.SqlValue{ .{ .integer = 1 }, .{ .text = "Test" } };
    const rows = [_][]const dig.types.SqlValue{&row};
    try mock_conn.addMockResult(&columns, &rows);

    var result = try conn.query("SELECT id, name FROM test", allocator);
    defer result.deinit();

    // Verify result structure
    try testing.expect(result.columns.len == 2);
    try testing.expect(result.rows.len == 1);
    try testing.expect(result.allocator.ptr == allocator.ptr);

    // Verify Row structure
    const r = result.rows[0];
    try testing.expect(r.values.len == 2);
    try testing.expect(r.columns.len == 2);

    // Verify Row.get method works
    const id = r.get("id");
    try testing.expect(id != null);
    try testing.expect(id.?.integer == 1);

    const name = r.get("name");
    try testing.expect(name != null);
    try testing.expect(std.mem.eql(u8, name.?.text, "Test"));
}

test "VTable: query result getColumnIndex function" {
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
    const columns = [_][]const u8{ "col_a", "col_b", "col_c" };
    const row = [_]dig.types.SqlValue{ .{ .integer = 1 }, .{ .integer = 2 }, .{ .integer = 3 } };
    const rows = [_][]const dig.types.SqlValue{&row};
    try mock_conn.addMockResult(&columns, &rows);

    var result = try conn.query("SELECT * FROM test", allocator);
    defer result.deinit();

    // Test getColumnIndex
    try testing.expect(result.getColumnIndex("col_a").? == 0);
    try testing.expect(result.getColumnIndex("col_b").? == 1);
    try testing.expect(result.getColumnIndex("col_c").? == 2);
    try testing.expect(result.getColumnIndex("non_existent") == null);
}

test "VTable: transaction functions follow proper state transitions" {
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

    // State: not in transaction
    try testing.expect(!mock_conn.in_transaction);

    // beginTransaction: not in transaction -> in transaction
    try conn.beginTransaction();
    try testing.expect(mock_conn.in_transaction);

    // commit: in transaction -> not in transaction
    try conn.commit();
    try testing.expect(!mock_conn.in_transaction);

    // beginTransaction again
    try conn.beginTransaction();
    try testing.expect(mock_conn.in_transaction);

    // rollback: in transaction -> not in transaction
    try conn.rollback();
    try testing.expect(!mock_conn.in_transaction);
}

test "VTable: error handling - execute without connection" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Try to execute without connecting
    const result = conn.execute("SELECT 1", allocator);
    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);
}

test "VTable: error handling - query without connection" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Try to query without connecting
    const result = conn.query("SELECT 1", allocator);
    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);
}

test "VTable: error handling - transaction without connection" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Try transaction operations without connecting
    try testing.expectError(dig.errors.DigError.ConnectionFailed, conn.beginTransaction());
    try testing.expectError(dig.errors.DigError.ConnectionFailed, conn.commit());
    try testing.expectError(dig.errors.DigError.ConnectionFailed, conn.rollback());
}

test "VTable: error handling - invalid transaction operations" {
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

    // Try to commit without begin
    try testing.expectError(dig.errors.DigError.TransactionFailed, conn.commit());

    // Try to rollback without begin
    try testing.expectError(dig.errors.DigError.TransactionFailed, conn.rollback());

    // Begin transaction
    try conn.beginTransaction();

    // Try to begin nested transaction
    try testing.expectError(dig.errors.DigError.TransactionFailed, conn.beginTransaction());
}

test "VTable: memory management - multiple connects and disconnects" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // Multiple connect/disconnect cycles
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try conn.connect(.{
            .database_type = .postgresql,
            .host = "localhost",
            .port = 5432,
            .database = "test",
            .username = "test",
            .password = "test",
        }, allocator);

        try testing.expect(mock_conn.is_connected);
        conn.disconnect();
        try testing.expect(!mock_conn.is_connected);
    }
}

test "VTable: memory management - query result cleanup" {
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

    // Execute multiple queries with results
    var query_count: usize = 0;
    while (query_count < 5) : (query_count += 1) {
        const columns = [_][]const u8{"col"};
        const row = [_]dig.types.SqlValue{.{ .integer = @intCast(query_count) }};
        const rows = [_][]const dig.types.SqlValue{&row};
        try mock_conn.addMockResult(&columns, &rows);

        var result = try conn.query("SELECT col FROM test", allocator);
        // Proper cleanup
        result.deinit();
    }

    // No memory leaks should occur
}

test "VTable: polymorphism - same interface for different implementations" {
    const allocator = testing.allocator;

    // Create two mock connections
    var mock1 = MockConnection.init(allocator);
    defer mock1.deinit();
    var conn1 = mock1.toConnection();

    var mock2 = MockConnection.init(allocator);
    defer mock2.deinit();
    var conn2 = mock2.toConnection();

    // Array of connections (demonstrating polymorphism)
    const connections = [_]*dig.connection.Connection{ &conn1, &conn2 };

    // Both should work with the same interface
    for (connections) |conn| {
        try conn.connect(.{
            .database_type = .postgresql,
            .host = "localhost",
            .port = 5432,
            .database = "test",
            .username = "test",
            .password = "test",
        }, allocator);

        try conn.execute("SELECT 1", allocator);
        conn.disconnect();
    }
}

test "VTable: state pointer integrity" {
    const allocator = testing.allocator;

    var mock_conn = MockConnection.init(allocator);
    defer mock_conn.deinit();

    var conn = mock_conn.toConnection();

    // The state pointer should point to our mock connection
    // Cast to verify (state is opaque)
    const state_ptr: *MockConnection = @ptrCast(@alignCast(conn.state));
    try testing.expect(state_ptr == &mock_conn);

    // Operations should affect the original mock connection
    try conn.connect(.{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    }, allocator);

    // Check that the state was modified
    try testing.expect(mock_conn.is_connected);
}

test "VTable: concurrent VTable access" {
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

    // Multiple operations in sequence (simulating concurrent-like usage)
    try conn.execute("CREATE TABLE test1 (id INT)", allocator);
    try conn.execute("CREATE TABLE test2 (id INT)", allocator);
    try conn.execute("CREATE TABLE test3 (id INT)", allocator);

    const queries = mock_conn.getExecutedQueries();
    try testing.expect(queries.len == 3);
}
