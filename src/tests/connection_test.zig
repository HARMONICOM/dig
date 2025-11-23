//! Tests for connection abstraction

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "Connection: VTable structure exists" {
    // Verify that Connection.VTable is defined
    _ = dig.connection.Connection.VTable;
}

test "Connection: QueryResult structure exists" {
    // Verify that QueryResult is defined
    _ = dig.connection.Connection.QueryResult;
}

test "Connection: QueryResult deinit" {
    const allocator = testing.allocator;
    var result = dig.connection.Connection.QueryResult{
        .columns = try allocator.alloc([]const u8, 0),
        .rows = try allocator.alloc(dig.connection.Connection.QueryResult.Row, 0),
        .allocator = allocator,
    };
    defer result.deinit();

    // Should not crash
    result.deinit();
}

test "Connection: QueryResult with empty rows" {
    const allocator = testing.allocator;
    const col1 = try allocator.dupe(u8, "id");
    const col2 = try allocator.dupe(u8, "name");
    var columns = try allocator.alloc([]const u8, 2);
    columns[0] = col1;
    columns[1] = col2;

    const rows = try allocator.alloc(dig.connection.Connection.QueryResult.Row, 0);

    var result = dig.connection.Connection.QueryResult{
        .columns = columns,
        .rows = rows,
        .allocator = allocator,
    };
    defer result.deinit();

    try testing.expect(result.columns.len == 2);
    try testing.expect(result.rows.len == 0);
}

test "Connection: Row get by column name" {
    const allocator = testing.allocator;
    const types = dig.types;

    // Create columns
    const col1 = try allocator.dupe(u8, "id");
    const col2 = try allocator.dupe(u8, "name");
    const col3 = try allocator.dupe(u8, "age");
    var columns = try allocator.alloc([]const u8, 3);
    columns[0] = col1;
    columns[1] = col2;
    columns[2] = col3;

    // Create row values
    var values = try allocator.alloc(types.SqlValue, 3);
    values[0] = .{ .integer = 1 };
    values[1] = .{ .text = try allocator.dupe(u8, "John") };
    values[2] = .{ .integer = 30 };

    // Create row with column references
    const row = dig.connection.Connection.QueryResult.Row{
        .values = values,
        .columns = columns,
    };

    // Test get by column name
    const id_value = row.get("id");
    try testing.expect(id_value != null);
    try testing.expect(id_value.?.integer == 1);

    const name_value = row.get("name");
    try testing.expect(name_value != null);
    try testing.expect(std.mem.eql(u8, name_value.?.text, "John"));

    const age_value = row.get("age");
    try testing.expect(age_value != null);
    try testing.expect(age_value.?.integer == 30);

    // Test non-existent column
    const invalid_value = row.get("email");
    try testing.expect(invalid_value == null);

    // Clean up
    allocator.free(values[1].text);
    allocator.free(values);
    for (columns) |col| {
        allocator.free(col);
    }
    allocator.free(columns);
}

test "Connection: QueryResult getColumnIndex" {
    const allocator = testing.allocator;

    // Create columns
    const col1 = try allocator.dupe(u8, "id");
    const col2 = try allocator.dupe(u8, "name");
    const col3 = try allocator.dupe(u8, "email");
    var columns = try allocator.alloc([]const u8, 3);
    columns[0] = col1;
    columns[1] = col2;
    columns[2] = col3;

    const rows = try allocator.alloc(dig.connection.Connection.QueryResult.Row, 0);

    var result = dig.connection.Connection.QueryResult{
        .columns = columns,
        .rows = rows,
        .allocator = allocator,
    };
    defer result.deinit();

    // Test getColumnIndex
    const idx0 = result.getColumnIndex("id");
    try testing.expect(idx0 != null);
    try testing.expect(idx0.? == 0);

    const idx1 = result.getColumnIndex("name");
    try testing.expect(idx1 != null);
    try testing.expect(idx1.? == 1);

    const idx2 = result.getColumnIndex("email");
    try testing.expect(idx2 != null);
    try testing.expect(idx2.? == 2);

    // Test non-existent column
    const invalid_idx = result.getColumnIndex("phone");
    try testing.expect(invalid_idx == null);
}
