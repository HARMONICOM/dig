//! Migration system tests

const std = @import("std");
const dig = @import("../dig.zig");
const testing = std.testing;

test "Migration: init manager" {
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

    var manager = dig.migration.Manager.init(&db, allocator);
    try manager.ensureMigrationsTable();

    // Cleanup
    try db.execute("DROP TABLE IF EXISTS _dig_migrations");
}

// SQL-based migration tests

test "SqlMigration: parse SQL file" {
    const allocator = testing.allocator;

    const sql_content =
        \\-- Migration: Create users table
        \\
        \\-- up
        \\CREATE TABLE users (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(255) NOT NULL
        \\);
        \\
        \\-- down
        \\DROP TABLE IF EXISTS users;
    ;

    var migration = try dig.migration.SqlMigration.initFromFile(
        allocator,
        "20251122_create_users_table.sql",
        sql_content,
    );
    defer migration.deinit();

    try testing.expect(std.mem.eql(u8, migration.id, "20251122"));
    try testing.expect(std.mem.containsAtLeast(u8, migration.name, 1, "create"));
    try testing.expect(std.mem.containsAtLeast(u8, migration.up_sql, 1, "CREATE TABLE"));
    try testing.expect(std.mem.containsAtLeast(u8, migration.down_sql, 1, "DROP TABLE"));
}

test "SqlMigration: migrate and rollback" {
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

    var manager = dig.migration.Manager.init(&db, allocator);

    // Load migrations from test directory
    const test_migrations_dir = "src/tests/migrations";
    var migrations = try manager.loadFromDirectory(test_migrations_dir);
    defer {
        for (migrations.items) |*migration| {
            migration.deinit();
        }
        migrations.deinit();
    }

    // Run migrations
    try manager.migrate(migrations.items);

    // Check if tables exist
    var result = try db.query(
        \\SELECT table_name FROM information_schema.tables
        \\WHERE table_schema = 'public'
        \\AND (table_name = 'test_users' OR table_name = 'test_posts')
    );
    defer result.deinit();

    try testing.expect(result.rows.len >= 2);

    // Rollback
    try manager.rollback(migrations.items);

    // Cleanup
    try db.execute("DROP TABLE IF EXISTS test_users CASCADE");
    try db.execute("DROP TABLE IF EXISTS test_posts CASCADE");
    try db.execute("DROP TABLE IF EXISTS _dig_migrations");
}

test "SqlMigration: load from directory" {
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

    var manager = dig.migration.Manager.init(&db, allocator);

    // Load migrations from test directory
    const test_migrations_dir = "src/tests/migrations";
    var migrations = try manager.loadFromDirectory(test_migrations_dir);
    defer {
        for (migrations.items) |*migration| {
            migration.deinit();
        }
        migrations.deinit();
    }

    try testing.expect(migrations.items.len >= 3);
    try testing.expect(std.mem.eql(u8, migrations.items[0].id, "20251122"));
    try testing.expect(std.mem.eql(u8, migrations.items[1].id, "20251123"));
    try testing.expect(std.mem.eql(u8, migrations.items[2].id, "20251124"));
}

test "SqlMigration: full migration cycle with directory" {
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

    var manager = dig.migration.Manager.init(&db, allocator);

    // Load migrations from test directory
    const test_migrations_dir = "src/tests/migrations";
    var migrations = try manager.loadFromDirectory(test_migrations_dir);
    defer {
        for (migrations.items) |*migration| {
            migration.deinit();
        }
        migrations.deinit();
    }

    // Run migrations
    try manager.migrate(migrations.items);

    // Check if tables exist
    var result = try db.query(
        \\SELECT table_name FROM information_schema.tables
        \\WHERE table_schema = 'public'
        \\AND table_name LIKE 'test_%'
        \\ORDER BY table_name
    );
    defer result.deinit();

    try testing.expect(result.rows.len >= 2);

    // Check status
    try manager.status(migrations.items);

    // Rollback last batch
    try manager.rollback(migrations.items);

    // Cleanup
    try db.execute("DROP TABLE IF EXISTS test_users CASCADE");
    try db.execute("DROP TABLE IF EXISTS test_posts CASCADE");
    try db.execute("DROP TABLE IF EXISTS _dig_migrations");
}
