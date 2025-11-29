//! Tests for chainable query builder

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "QueryBuilder - SELECT with all columns" {
    const allocator = testing.allocator;

    // Create mock database connection
    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    // Start query builder
    const builder = db.table("users");

    // This test just verifies the API compiles
    // Actual execution would require a database connection
    _ = builder;
}

test "QueryBuilder - SELECT with specific columns" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.select(&.{ "id", "name", "email" });

    // Verify we can chain methods
    _ = builder.where("active", "=", .{ .boolean = true });
    _ = builder.orderBy("created_at", .desc);
    _ = builder.limit(10);
    _ = builder.offset(5);
}

test "QueryBuilder - INSERT" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.addValue("name", .{ .text = "John Doe" });
    _ = builder.addValue("email", .{ .text = "john@example.com" });
    _ = builder.addValue("age", .{ .integer = 30 });
}

test "QueryBuilder - UPDATE" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.set("name", .{ .text = "Jane Doe" });
    _ = builder.set("age", .{ .integer = 25 });
    _ = builder.where("id", "=", .{ .integer = 1 });
}

test "QueryBuilder - UPDATE with WHERE before SET" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    // Call WHERE before SET - WHERE clause should be preserved
    _ = builder.where("id", "=", .{ .integer = 1 });
    _ = builder.set("name", .{ .text = "Jane Doe" });
    _ = builder.set("age", .{ .integer = 25 });

    // Generate SQL and verify WHERE clause is included
    const sql = try builder.toSql();
    defer allocator.free(sql);

    // Verify the SQL contains WHERE clause
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "id") != null);
}

test "QueryBuilder - DELETE" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.delete();
    _ = builder.where("id", "=", .{ .integer = 1 });
}

test "QueryBuilder - DELETE with WHERE before DELETE" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    // Call WHERE before DELETE - WHERE clause should be preserved
    _ = builder.where("id", "=", .{ .integer = 1 });
    _ = builder.delete();

    // Generate SQL and verify WHERE clause is included
    const sql = try builder.toSql();
    defer allocator.free(sql);

    // Verify the SQL contains WHERE clause
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "id") != null);
}

test "QueryBuilder - chaining with HashMap" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    // Create a hash map with values
    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("name", .{ .text = "John Doe" });
    try values.put("email", .{ .text = "john@example.com" });
    try values.put("age", .{ .integer = 30 });

    _ = builder.setValues(values);
}

test "QueryBuilder - UPDATE with HashMap" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    // Create a hash map with values
    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("name", .{ .text = "Jane Doe" });
    try values.put("age", .{ .integer = 25 });

    _ = builder.setMultiple(values);
    _ = builder.where("id", "=", .{ .integer = 1 });
}

test "QueryBuilder - INNER JOIN" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = builder.join("posts", "users.id", "posts.user_id");
}

test "QueryBuilder - LEFT JOIN" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = builder.leftJoin("posts", "users.id", "posts.user_id");
}

test "QueryBuilder - RIGHT JOIN" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = builder.rightJoin("posts", "users.id", "posts.user_id");
}

test "QueryBuilder - FULL OUTER JOIN" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = builder.fullJoin("posts", "users.id", "posts.user_id");
}

test "QueryBuilder - multiple JOINs with WHERE" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    _ = builder.select(&.{ "users.id", "users.name", "posts.title", "comments.content" });
    _ = builder.join("posts", "users.id", "posts.user_id");
    _ = builder.leftJoin("comments", "posts.id", "comments.post_id");
    _ = builder.where("users.active", "=", .{ .boolean = true });
    _ = builder.orderBy("users.name", .asc);
    _ = builder.limit(10);
}

test "QueryBuilder - JOIN with complex chaining" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");

    // Verify we can chain all methods together
    _ = builder.select(&.{ "u.id", "u.name", "p.title" });
    _ = builder.join("posts p", "users.id", "p.user_id");
    _ = builder.where("u.age", ">=", .{ .integer = 18 });
    _ = builder.where("p.published", "=", .{ .boolean = true });
    _ = builder.orderBy("u.name", .asc);
    _ = builder.limit(20);
    _ = builder.offset(0);
}

test "QueryBuilder - toSql() for SELECT" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");
    _ = builder.select(&.{ "id", "name", "email" });
    _ = builder.where("age", ">", .{ .integer = 18 });
    _ = builder.orderBy("name", .asc);
    _ = builder.limit(10);
    _ = builder.offset(5);

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try testing.expect(std.mem.indexOf(u8, sql, "SELECT") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "FROM users") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "ORDER BY") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "LIMIT 10") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "OFFSET 5") != null);
}

test "QueryBuilder - toSql() for INSERT" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");
    _ = builder.addValue("name", .{ .text = "John Doe" });
    _ = builder.addValue("email", .{ .text = "john@example.com" });
    _ = builder.addValue("age", .{ .integer = 30 });

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try testing.expect(std.mem.indexOf(u8, sql, "INSERT INTO users") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "name") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "email") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "VALUES") != null);
}

test "QueryBuilder - toSql() for UPDATE" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");
    _ = builder.set("name", .{ .text = "Jane Doe" });
    _ = builder.set("age", .{ .integer = 25 });
    _ = builder.where("id", "=", .{ .integer = 1 });

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try testing.expect(std.mem.indexOf(u8, sql, "UPDATE users") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "SET") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
}

test "QueryBuilder - toSql() for DELETE" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");
    _ = builder.delete();
    _ = builder.where("id", "=", .{ .integer = 1 });

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try testing.expect(std.mem.indexOf(u8, sql, "DELETE FROM users") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
}

test "QueryBuilder - toSql() for SELECT with JOIN" {
    const allocator = testing.allocator;

    var db = try dig.db.connect(allocator, .{
        .database_type = .mock,
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .username = "test",
        .password = "test",
    });
    defer db.disconnect();

    var builder = db.table("users");
    _ = builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = builder.join("posts", "users.id", "posts.user_id");
    _ = builder.where("users.active", "=", .{ .boolean = true });

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try testing.expect(std.mem.indexOf(u8, sql, "SELECT") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "INNER JOIN posts") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "ON users.id = posts.user_id") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
}
