//! Tests for query builders

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "SelectQuery: basic select" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.select(&[_][]const u8{ "id", "name" }).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.eql(u8, sql, "SELECT id, name FROM users"));
}

test "SelectQuery: select all columns" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.eql(u8, sql, "SELECT * FROM users"));
}

test "SelectQuery: where clause" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.where("age", ">", .{ .integer = 18 })).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "age"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "18"));
}

test "SelectQuery: multiple where clauses" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try query
        .where("age", ">", .{ .integer = 18 }))
        .where("status", "=", .{ .text = "active" }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "AND"));
}

test "SelectQuery: orderBy" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.orderBy("name", .asc).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "ORDER BY"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "name"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "ASC"));
}

test "SelectQuery: orderBy desc" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.orderBy("name", .desc).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "DESC"));
}

test "SelectQuery: limit" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.limit(10).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LIMIT"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "10"));
}

test "SelectQuery: offset" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.offset(20).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "OFFSET"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "20"));
}

test "SelectQuery: complex query" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query
        .select(&[_][]const u8{ "id", "name", "email" })
        .where("age", ">", .{ .integer = 18 }))
        .orderBy("name", .asc)
        .limit(10)
        .offset(0)
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "FROM users"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "ORDER BY"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LIMIT"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "OFFSET"));
}

test "InsertQuery: basic insert" {
    const allocator = testing.allocator;
    var query = try dig.query.InsertQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.addValue("name", .{ .text = "John" })).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INSERT INTO"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "users"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "VALUES"));
}

test "InsertQuery: multiple values" {
    const allocator = testing.allocator;
    var query = try dig.query.InsertQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try query
        .addValue("name", .{ .text = "John" }))
        .addValue("age", .{ .integer = 30 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "name"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "age"));
}

test "InsertQuery: null value" {
    const allocator = testing.allocator;
    var query = try dig.query.InsertQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.addValue("optional_field", .null)).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "NULL"));
}

test "InsertQuery: setValues with hash map" {
    const allocator = testing.allocator;
    var query = try dig.query.InsertQuery.init(allocator, "users");
    defer query.deinit();

    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("name", .{ .text = "John" });
    try values.put("age", .{ .integer = 30 });
    try values.put("active", .{ .boolean = true });

    const sql = try (try query.setValues(values)).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INSERT INTO"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "users"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "VALUES"));
    // Check that all values are present (order may vary due to hash map)
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "name"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "age"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "active"));
}

test "UpdateQuery: basic update" {
    const allocator = testing.allocator;
    var query = try dig.query.UpdateQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.set("name", .{ .text = "Jane" })).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "UPDATE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "users"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SET"));
}

test "UpdateQuery: update with where" {
    const allocator = testing.allocator;
    var query = try dig.query.UpdateQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try query
        .set("age", .{ .integer = 31 }))
        .where("id", "=", .{ .integer = 1 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "UPDATE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SET"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
}

test "UpdateQuery: multiple set clauses" {
    const allocator = testing.allocator;
    var query = try dig.query.UpdateQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try query
        .set("name", .{ .text = "Jane" }))
        .set("age", .{ .integer = 31 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "name"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "age"));
}

test "UpdateQuery: setMultiple with hash map" {
    const allocator = testing.allocator;
    var query = try dig.query.UpdateQuery.init(allocator, "users");
    defer query.deinit();

    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("name", .{ .text = "Jane" });
    try values.put("age", .{ .integer = 31 });
    try values.put("active", .{ .boolean = false });

    const sql = try (try (try query
        .setMultiple(values))
        .where("id", "=", .{ .integer = 1 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "UPDATE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "users"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SET"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
    // Check that all values are present (order may vary due to hash map)
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "name"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "age"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "active"));
}

test "DeleteQuery: basic delete" {
    const allocator = testing.allocator;
    var query = try dig.query.DeleteQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "DELETE FROM"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "users"));
}

test "DeleteQuery: delete with where" {
    const allocator = testing.allocator;
    var query = try dig.query.DeleteQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.where("id", "=", .{ .integer = 1 })).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "DELETE FROM"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
}

test "DeleteQuery: multiple where clauses" {
    const allocator = testing.allocator;
    var query = try dig.query.DeleteQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try query
        .where("age", "<", .{ .integer = 18 }))
        .where("status", "=", .{ .text = "inactive" }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "AND"));
}

test "Query builders: MySQL vs PostgreSQL differences" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const pg_sql = try query.select(&[_][]const u8{"id"}).toSql(.postgresql);
    defer allocator.free(pg_sql);

    const mysql_sql = try query.select(&[_][]const u8{"id"}).toSql(.mysql);
    defer allocator.free(mysql_sql);

    // Both should generate valid SELECT statements
    try testing.expect(std.mem.containsAtLeast(u8, pg_sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, mysql_sql, 1, "SELECT"));
}

test "SelectQuery: exact SQL output for simple query" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.select(&[_][]const u8{"id"}).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.eql(u8, sql, "SELECT id FROM users"));
}

test "SelectQuery: exact SQL with where clause" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query
        .select(&[_][]const u8{"id"})
        .where("id", "=", .{ .integer = 1 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SELECT id FROM users WHERE id = 1"));
}

test "InsertQuery: exact SQL output" {
    const allocator = testing.allocator;
    var query = try dig.query.InsertQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.addValue("name", .{ .text = "John" })).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INSERT INTO users (name) VALUES ('John')"));
}

test "UpdateQuery: exact SQL output" {
    const allocator = testing.allocator;
    var query = try dig.query.UpdateQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.set("name", .{ .text = "Jane" })).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "UPDATE users SET name = 'Jane'"));
}

test "DeleteQuery: exact SQL output" {
    const allocator = testing.allocator;
    var query = try dig.query.DeleteQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.eql(u8, sql, "DELETE FROM users"));
}

test "SelectQuery: text value escaping" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.where("name", "=", .{ .text = "O'Reilly" })).toSql(.postgresql);
    defer allocator.free(sql);

    // Should escape single quotes
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "''"));
}

test "SelectQuery: boolean values" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql_true = try (try query.where("active", "=", .{ .boolean = true })).toSql(.postgresql);
    defer allocator.free(sql_true);
    try testing.expect(std.mem.containsAtLeast(u8, sql_true, 1, "TRUE"));

    var query2 = try dig.query.SelectQuery.init(allocator, "users");
    defer query2.deinit();
    const sql_false = try (try query2.where("active", "=", .{ .boolean = false })).toSql(.postgresql);
    defer allocator.free(sql_false);
    try testing.expect(std.mem.containsAtLeast(u8, sql_false, 1, "FALSE"));
}

test "SelectQuery: null value" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.where("deleted_at", "IS", .null)).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "NULL"));
}

test "SelectQuery: INNER JOIN" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.join("posts", "users.id", "posts.user_id")).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INNER JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "posts"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "users.id"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "posts.user_id"));
}

test "SelectQuery: LEFT JOIN" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.leftJoin("posts", "users.id", "posts.user_id")).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LEFT JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "posts"));
}

test "SelectQuery: RIGHT JOIN" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.rightJoin("posts", "users.id", "posts.user_id")).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "RIGHT JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "posts"));
}

test "SelectQuery: FULL OUTER JOIN" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query.fullJoin("posts", "users.id", "posts.user_id")).toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "FULL OUTER JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "posts"));
}

test "SelectQuery: multiple JOINs" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try query
        .join("posts", "users.id", "posts.user_id"))
        .leftJoin("comments", "posts.id", "comments.post_id"))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INNER JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LEFT JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "posts"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "comments"));
}

test "SelectQuery: JOIN with WHERE clause" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try query
        .select(&[_][]const u8{ "users.id", "users.name", "posts.title" })
        .join("posts", "users.id", "posts.user_id"))
        .where("users.age", ">=", .{ .integer = 18 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INNER JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
}

test "SelectQuery: JOIN with ORDER BY and LIMIT" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query
        .select(&[_][]const u8{ "users.name", "posts.title" })
        .join("posts", "users.id", "posts.user_id"))
        .orderBy("users.name", .asc)
        .limit(10)
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INNER JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "ORDER BY"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LIMIT"));
}

test "SelectQuery: complex query with JOINs" {
    const allocator = testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try (try query
        .select(&[_][]const u8{ "u.id", "u.name", "p.title", "c.content" })
        .join("posts p", "users.id", "p.user_id"))
        .leftJoin("comments c", "p.id", "c.post_id"))
        .where("u.active", "=", .{ .boolean = true }))
        .orderBy("u.name", .asc)
        .limit(20)
        .toSql(.postgresql);
    defer allocator.free(sql);

    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "SELECT"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "FROM users"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "INNER JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LEFT JOIN"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "WHERE"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "ORDER BY"));
    try testing.expect(std.mem.containsAtLeast(u8, sql, 1, "LIMIT"));
}
