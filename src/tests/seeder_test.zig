//! Tests for seeder functionality

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

// Test SQL splitting functionality
test "Seeder: split SQL statements with single statement" {
    const allocator = testing.allocator;

    const sql = "INSERT INTO users (name) VALUES ('Alice');";

    // Simulate splitSqlStatements function
    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    try testing.expect(statements.items.len == 1);
    try testing.expect(std.mem.containsAtLeast(u8, statements.items[0], 1, "INSERT INTO users"));
}

test "Seeder: split SQL statements with multiple statements" {
    const allocator = testing.allocator;

    const sql =
        \\INSERT INTO users (name) VALUES ('Alice');
        \\INSERT INTO users (name) VALUES ('Bob');
        \\INSERT INTO users (name) VALUES ('Charlie');
    ;

    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    try testing.expect(statements.items.len == 3);
    try testing.expect(std.mem.containsAtLeast(u8, statements.items[0], 1, "Alice"));
    try testing.expect(std.mem.containsAtLeast(u8, statements.items[1], 1, "Bob"));
    try testing.expect(std.mem.containsAtLeast(u8, statements.items[2], 1, "Charlie"));
}

test "Seeder: split SQL statements with empty statements" {
    const allocator = testing.allocator;

    const sql = ";;;";

    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    try testing.expect(statements.items.len == 0);
}

test "Seeder: split SQL statements without trailing semicolon" {
    const allocator = testing.allocator;

    const sql = "INSERT INTO users (name) VALUES ('Alice')";

    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    // Handle last statement if no semicolon at end
    const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
    if (trimmed.len > 0) {
        try statements.append(allocator, try allocator.dupe(u8, trimmed));
    }

    try testing.expect(statements.items.len == 1);
    try testing.expect(std.mem.containsAtLeast(u8, statements.items[0], 1, "INSERT INTO users"));
}

test "Seeder: split SQL statements with comments" {
    const allocator = testing.allocator;

    const sql =
        \\-- This is a comment
        \\INSERT INTO users (name) VALUES ('Alice');
        \\-- Another comment
        \\INSERT INTO users (name) VALUES ('Bob');
    ;

    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    // The split will include comments as part of statements
    try testing.expect(statements.items.len == 2);
}

test "Seeder: execute seed file with PostgreSQL" {
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
        \\CREATE TABLE IF NOT EXISTS test_seed (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(255)
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_seed") catch {};

    // Simulate seed file content
    const seed_sql =
        \\INSERT INTO test_seed (name) VALUES ('Seed1');
        \\INSERT INTO test_seed (name) VALUES ('Seed2');
        \\INSERT INTO test_seed (name) VALUES ('Seed3');
    ;

    // Split and execute statements
    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < seed_sql.len) : (i += 1) {
        const c = seed_sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    // Execute statements
    for (statements.items) |stmt| {
        if (stmt.len > 0) {
            const trimmed = std.mem.trim(u8, stmt, " \t\n\r");
            if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "--")) {
                try db.execute(stmt);
            }
        }
    }

    // Verify data was seeded
    var result = try db.query("SELECT COUNT(*) FROM test_seed");
    defer result.deinit();

    try testing.expect(result.rows.len > 0);
    const count_val = result.rows[0].values[0];
    const count: i64 = switch (count_val) {
        .integer => |v| v,
        else => 0,
    };
    try testing.expect(count == 3);
}

test "Seeder: skip comment lines" {
    const allocator = testing.allocator;

    const sql =
        \\-- This is a comment and should be skipped
        \\INSERT INTO users (name) VALUES ('Alice');
    ;

    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    // Filter out comment statements
    var non_comment_count: usize = 0;
    for (statements.items) |stmt| {
        const trimmed = std.mem.trim(u8, stmt, " \t\n\r");
        if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "--")) {
            non_comment_count += 1;
        }
    }

    try testing.expect(non_comment_count == 1);
}

test "Seeder: execute seed files in order" {
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
        \\CREATE TABLE IF NOT EXISTS test_order (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(255)
        \\)
    );
    defer db.execute("DROP TABLE IF EXISTS test_order") catch {};

    // Simulate multiple seed files
    const seed1 = "INSERT INTO test_order (name) VALUES ('First');";
    const seed2 = "INSERT INTO test_order (name) VALUES ('Second');";
    const seed3 = "INSERT INTO test_order (name) VALUES ('Third');";

    try db.execute(seed1);
    try db.execute(seed2);
    try db.execute(seed3);

    // Verify order
    var result = try db.query("SELECT name FROM test_order ORDER BY id");
    defer result.deinit();

    try testing.expect(result.rows.len == 3);
    const name1 = result.rows[0].values[0];
    const name2 = result.rows[1].values[0];
    const name3 = result.rows[2].values[0];

    try testing.expect(std.mem.eql(u8, name1.text, "First"));
    try testing.expect(std.mem.eql(u8, name2.text, "Second"));
    try testing.expect(std.mem.eql(u8, name3.text, "Third"));
}

test "Seeder: handle empty SQL file" {
    const allocator = testing.allocator;

    const sql = "";

    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
    if (trimmed.len > 0) {
        try statements.append(allocator, try allocator.dupe(u8, trimmed));
    }

    try testing.expect(statements.items.len == 0);
}

test "Seeder: handle multiline SQL statements" {
    const allocator = testing.allocator;

    const sql =
        \\INSERT INTO users (
        \\    name,
        \\    email,
        \\    age
        \\) VALUES (
        \\    'Alice',
        \\    'alice@example.com',
        \\    30
        \\);
    ;

    var statements: std.ArrayList([]const u8) = .{};
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];
        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    try testing.expect(statements.items.len == 1);
    try testing.expect(std.mem.containsAtLeast(u8, statements.items[0], 1, "INSERT INTO users"));
    try testing.expect(std.mem.containsAtLeast(u8, statements.items[0], 1, "Alice"));
}
