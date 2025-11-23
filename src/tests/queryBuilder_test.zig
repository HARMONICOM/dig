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
    var builder = try db.table("users");
    defer builder.deinit();

    // This test just verifies the API compiles
    // Actual execution would require a database connection
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.select(&.{ "id", "name", "email" });

    // Verify we can chain methods
    _ = try builder.where("active", "=", .{ .boolean = true });
    _ = try builder.orderBy("created_at", .desc);
    _ = try builder.limit(10);
    _ = try builder.offset(5);
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.addValue("name", .{ .text = "John Doe" });
    _ = try builder.addValue("email", .{ .text = "john@example.com" });
    _ = try builder.addValue("age", .{ .integer = 30 });
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.set("name", .{ .text = "Jane Doe" });
    _ = try builder.set("age", .{ .integer = 25 });
    _ = try builder.where("id", "=", .{ .integer = 1 });
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.delete();
    _ = try builder.where("id", "=", .{ .integer = 1 });
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

    var builder = try db.table("users");
    defer builder.deinit();

    // Create a hash map with values
    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("name", .{ .text = "John Doe" });
    try values.put("email", .{ .text = "john@example.com" });
    try values.put("age", .{ .integer = 30 });

    _ = try builder.setValues(values);
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

    var builder = try db.table("users");
    defer builder.deinit();

    // Create a hash map with values
    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("name", .{ .text = "Jane Doe" });
    try values.put("age", .{ .integer = 25 });

    _ = try builder.setMultiple(values);
    _ = try builder.where("id", "=", .{ .integer = 1 });
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = try builder.join("posts", "users.id", "posts.user_id");
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = try builder.leftJoin("posts", "users.id", "posts.user_id");
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = try builder.rightJoin("posts", "users.id", "posts.user_id");
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.select(&.{ "users.id", "users.name", "posts.title" });
    _ = try builder.fullJoin("posts", "users.id", "posts.user_id");
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

    var builder = try db.table("users");
    defer builder.deinit();

    _ = try builder.select(&.{ "users.id", "users.name", "posts.title", "comments.content" });
    _ = try builder.join("posts", "users.id", "posts.user_id");
    _ = try builder.leftJoin("comments", "posts.id", "comments.post_id");
    _ = try builder.where("users.active", "=", .{ .boolean = true });
    _ = try builder.orderBy("users.name", .asc);
    _ = try builder.limit(10);
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

    var builder = try db.table("users");
    defer builder.deinit();

    // Verify we can chain all methods together
    _ = try builder.select(&.{ "u.id", "u.name", "p.title" });
    _ = try builder.join("posts p", "users.id", "p.user_id");
    _ = try builder.where("u.age", ">=", .{ .integer = 18 });
    _ = try builder.where("p.published", "=", .{ .boolean = true });
    _ = try builder.orderBy("u.name", .asc);
    _ = try builder.limit(20);
    _ = try builder.offset(0);
}
