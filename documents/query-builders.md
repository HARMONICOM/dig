## Query Builders

Dig provides fluent query builders for constructing SQL queries programmatically.
This guide covers SELECT, INSERT, UPDATE, and DELETE query builders with type-safe value handling.

---

## 1. Overview

Query builders allow you to:

- Build SQL queries with a fluent, chainable API
- Generate database-specific SQL (PostgreSQL, MySQL)
- Use type-safe values with `SqlValue` union type
- Avoid manual SQL string concatenation
- Execute queries directly from the builder (recommended)
- Or generate SQL and execute separately (traditional approach)

### 1.1 Two Ways to Use Query Builders

**Method 1: Chainable Query Builder (Recommended)**

Start from a `Db` connection and chain methods directly, then execute:

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to database
    var conn = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    });
    defer conn.disconnect();

    // Build and execute query in one chain
    // Note: table() and chain methods don't return errors
    // Only get(), execute(), and first() return errors
    var result = try conn.table("users")
        .select(&.{"id", "name", "email"})
        .where("age", ">", .{.integer = 18})
        .orderBy("name", .asc)
        .limit(10)
        .get();
    defer result.deinit();

    // Process results...
}
```

**Method 2: Traditional Query Builder**

Create a query builder separately, generate SQL, and execute:

```zig
// Create query builder
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

_ = try query.select(&.{"id", "name"});
const sql = try query.toSql(.postgresql);
defer allocator.free(sql);

// Execute separately
var result = try conn.query(sql);
defer result.deinit();
```

**Query Builder Types**:
- `dig.queryBuilder.QueryBuilder` - Chainable query builder (starts from `conn.table()`)
- `dig.query.Select` - SELECT query builder
- `dig.query.Insert` - INSERT query builder
- `dig.query.Update` - UPDATE query builder
- `dig.query.Delete` - DELETE query builder

**Note**: For backward compatibility, aliases `SelectQuery`, `InsertQuery`, `UpdateQuery`, and `DeleteQuery` are also available.

**Error Handling**:
- Chainable query builder methods (`select`, `where`, `join`, `orderBy`, `limit`, `offset`, `addValue`, `set`, `delete`, etc.) do **not** return errors. Errors are stored internally and checked when executing.
- Only execution methods (`get()`, `execute()`, `first()`) return `dig.errors.DigError!` error unions.
- The `table()` method also does not return errors.

Common errors include:
- `QueryBuildError` - Invalid query builder operation (e.g., using JOIN on non-SELECT query)
- `QueryExecutionFailed` - Query execution failed
- `OutOfMemory` - Memory allocation failed

---

## 2. SqlValue Type

All values in queries are represented using the `SqlValue` tagged union:

```zig
pub const SqlValue = union(enum) {
    null,
    integer: i64,
    float: f64,
    text: []const u8,
    boolean: bool,
    blob: []const u8,
    timestamp: i64,  // Unix timestamp
};
```

### 2.1 Creating SqlValue Instances

```zig
// Null value
const null_value: SqlValue = .null;

// Integer value
const id: SqlValue = .{ .integer = 42 };

// Float value
const price: SqlValue = .{ .float = 19.99 };

// Text value
const name: SqlValue = .{ .text = "John Doe" };

// Boolean value
const active: SqlValue = .{ .boolean = true };

// Timestamp value (Unix timestamp)
const created: SqlValue = .{ .timestamp = 1700000000 };
```

---

## 3. Chainable Query Builder (Recommended)

The chainable query builder provides a convenient way to build and execute queries directly from your database connection.

### 3.1 Starting a Query

Use `conn.table()` to start building a query:

```zig
var conn = try dig.db.connect(allocator, config);
defer conn.disconnect();

// table() does not return errors
var builder = conn.table("users");
defer builder.deinit();
```

### 3.2 SELECT Queries

#### Basic SELECT

```zig
// Select all columns
// Only get() returns an error, not table() or other chain methods
var result = try conn.table("users").get();
defer result.deinit();
```

#### Select Specific Columns

```zig
// Chain methods don't return errors, only get() does
var result = try conn.table("users")
    .select(&.{"id", "name", "email"})
    .get();
defer result.deinit();
```

#### With WHERE Clause

```zig
// Chain methods (select, where) don't return errors
var result = try conn.table("users")
    .select(&.{"id", "name"})
    .where("age", ">", .{.integer = 18})
    .get();  // Only get() returns an error
defer result.deinit();
```

#### Multiple WHERE Clauses

```zig
// Multiple where clauses - no try needed for chain methods
var result = try conn.table("users")
    .select(&.{"id", "name"})
    .where("age", ">=", .{.integer = 18})
    .where("active", "=", .{.boolean = true})
    .get();  // Only get() returns an error
defer result.deinit();
```

#### ORDER BY

```zig
// orderBy doesn't return errors
var result = try conn.table("users")
    .orderBy("created_at", .desc)
    .get();  // Only get() returns an error
defer result.deinit();
```

#### LIMIT and OFFSET

```zig
// limit and offset don't return errors
var result = try conn.table("users")
    .orderBy("id", .asc)
    .limit(10)
    .offset(20)
    .get();  // Only get() returns an error
defer result.deinit();
```

#### Get First Result

```zig
// first() returns an error, chain methods don't
// Note: first() internally calls get() and returns the first row
// The QueryResult is managed internally, but you should handle the row carefully
var first_row = try conn.table("users")
    .where("email", "=", .{.text = "john@example.com"})
    .first();  // first() returns an error

if (first_row) |row| {
    // Process first row
    // The row is part of a QueryResult that is managed internally
    const id = row.get("id").?.integer;
    const name = row.get("name").?.text;
    std.debug.print("Found user: {d} - {s}\n", .{id, name});
}
```

#### JOIN Queries

##### INNER JOIN

```zig
// join() doesn't return errors
var result = try conn.table("users")
    .select(&.{"users.id", "users.name", "posts.title"})
    .join("posts", "users.id", "posts.user_id")
    .get();  // Only get() returns an error
defer result.deinit();
```

##### LEFT JOIN

```zig
// leftJoin() doesn't return errors
var result = try conn.table("users")
    .select(&.{"users.id", "users.name", "posts.title"})
    .leftJoin("posts", "users.id", "posts.user_id")
    .get();  // Only get() returns an error
defer result.deinit();
```

##### RIGHT JOIN

```zig
// rightJoin() doesn't return errors
var result = try conn.table("users")
    .select(&.{"users.id", "users.name", "posts.title"})
    .rightJoin("posts", "users.id", "posts.user_id")
    .get();  // Only get() returns an error
defer result.deinit();
```

##### FULL OUTER JOIN

```zig
// fullJoin() doesn't return errors
var result = try conn.table("users")
    .select(&.{"users.id", "users.name", "posts.title"})
    .fullJoin("posts", "users.id", "posts.user_id")
    .get();  // Only get() returns an error
defer result.deinit();
```

##### Multiple JOINs

```zig
// All chain methods don't return errors
var result = try conn.table("users")
    .select(&.{"u.id", "u.name", "p.title", "c.content"})
    .join("posts p", "users.id", "p.user_id")
    .leftJoin("comments c", "p.id", "c.post_id")
    .where("u.active", "=", .{.boolean = true})
    .orderBy("u.name", .asc)
    .limit(20)
    .get();  // Only get() returns an error
defer result.deinit();
```

##### JOIN with WHERE and ORDER BY

```zig
// Chain methods don't return errors
var result = try conn.table("users")
    .select(&.{"users.name", "posts.title", "posts.created_at"})
    .join("posts", "users.id", "posts.user_id")
    .where("posts.published", "=", .{.boolean = true})
    .where("users.age", ">=", .{.integer = 18})
    .orderBy("posts.created_at", .desc)
    .limit(10)
    .get();  // Only get() returns an error
defer result.deinit();
```

### 3.3 INSERT Queries

#### Single Row Insert

```zig
// addValue() doesn't return errors, only execute() does
try conn.table("users")
    .addValue("name", .{.text = "John Doe"})
    .addValue("email", .{.text = "john@example.com"})
    .addValue("age", .{.integer = 30})
    .execute();  // Only execute() returns an error
```

#### Insert with HashMap

```zig
var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{.text = "Jane Doe"});
try values.put("email", .{.text = "jane@example.com"});
try values.put("age", .{.integer = 25});

// setValues() doesn't return errors, only execute() does
try conn.table("users")
    .setValues(values)
    .execute();  // Only execute() returns an error
```

### 3.4 UPDATE Queries

#### Update Single Column

```zig
// set() and where() don't return errors, only execute() does
try conn.table("users")
    .set("name", .{.text = "John Smith"})
    .where("id", "=", .{.integer = 1})
    .execute();  // Only execute() returns an error
```

#### Update Multiple Columns

```zig
// Chain methods don't return errors
try conn.table("users")
    .set("name", .{.text = "Jane Smith"})
    .set("email", .{.text = "jane.smith@example.com"})
    .set("age", .{.integer = 26})
    .where("id", "=", .{.integer = 2})
    .execute();  // Only execute() returns an error
```

#### Update with HashMap

```zig
var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{.text = "Updated Name"});
try values.put("updated_at", .{.timestamp = std.time.timestamp()});

// setMultiple() and where() don't return errors
try conn.table("users")
    .setMultiple(values)
    .where("id", "=", .{.integer = 3})
    .execute();  // Only execute() returns an error
```

### 3.5 DELETE Queries

#### Delete with WHERE

```zig
// delete() and where() don't return errors
try conn.table("users")
    .delete()
    .where("id", "=", .{.integer = 1})
    .execute();  // Only execute() returns an error
```

#### Delete Multiple Rows

```zig
// Chain methods don't return errors
try conn.table("users")
    .delete()
    .where("active", "=", .{.boolean = false})
    .execute();  // Only execute() returns an error
```

### 3.6 Complete Example

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to database
    var conn = try dig.db.connect(allocator, .{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    });
    defer conn.disconnect();

    // Insert a user
    // Chain methods don't return errors, only execute() does
    try conn.table("users")
        .addValue("name", .{.text = "Alice"})
        .addValue("email", .{.text = "alice@example.com"})
        .addValue("age", .{.integer = 28})
        .execute();

    // Query users
    // Chain methods don't return errors, only get() does
    var result = try conn.table("users")
        .select(&.{"id", "name", "email"})
        .where("age", ">=", .{.integer = 18})
        .orderBy("name", .asc)
        .get();
    defer result.deinit();

    // Process results
    for (result.rows) |row| {
        if (row.get("name")) |name| {
            std.debug.print("Name: {s}\n", .{name.text});
        }
    }

    // Update a user
    // Chain methods don't return errors, only execute() does
    try conn.table("users")
        .set("age", .{.integer = 29})
        .where("email", "=", .{.text = "alice@example.com"})
        .execute();

    // Delete a user
    // Chain methods don't return errors, only execute() does
    try conn.table("users")
        .delete()
        .where("email", "=", .{.text = "alice@example.com"})
        .execute();
}
```

---

## 4. Traditional Query Builders

These are the original query builders that generate SQL strings. They are still fully supported for cases where you need more control over SQL generation.

### 4.1 SELECT Query Builder

Build SELECT queries with filtering, ordering, and pagination.

#### 4.1.1 Basic SELECT

```zig
const std = @import("std");
const dig = @import("dig");

pub fn example(allocator: std.mem.Allocator) !void {
    // Create query builder
    var query = try dig.query.Select.init(allocator, "users");
    defer query.deinit();

    // Select all columns
    const sql = try query.toSql(.postgresql);
    defer allocator.free(sql);
    // Result: SELECT * FROM users

    std.debug.print("SQL: {s}\n", .{sql});
}
```

#### 4.1.2 Selecting Specific Columns

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try query
    .select(&[_][]const u8{"id", "name", "email"})
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT id, name, email FROM users
```

#### 4.1.3 WHERE Clause

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"id", "name"})
    .where("age", ">", .{ .integer = 18 }))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT id, name FROM users WHERE age > 18
```

#### 4.1.4 Multiple WHERE Clauses

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try (try query
    .select(&[_][]const u8{"id", "name"})
    .where("age", ">=", .{ .integer = 18 }))
    .where("active", "=", .{ .boolean = true }))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT id, name FROM users WHERE age >= 18 AND active = true
```

#### 4.1.5 Supported Operators

WHERE clauses support various comparison operators:

- **Equality**: `=`, `!=`, `<>` (not equal)
- **Comparison**: `<`, `<=`, `>`, `>=`
- **Pattern matching**: `LIKE`, `ILIKE` (PostgreSQL case-insensitive)
- **Range**: `IN`, `NOT IN`, `BETWEEN`
- **Null checks**: `IS NULL`, `IS NOT NULL`

```zig
// LIKE operator
try query.where("name", "LIKE", .{ .text = "John%" });

// IS NULL
try query.where("deleted_at", "IS NULL", .null);

// Not equal
try query.where("status", "!=", .{ .text = "inactive" });
```

#### 4.1.6 ORDER BY

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"id", "name"})
    .where("age", ">", .{ .integer = 18 }))
    .orderBy("name", .asc)
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT id, name FROM users WHERE age > 18 ORDER BY name ASC
```

Direction options:
- `.asc` - Ascending order
- `.desc` - Descending order

#### 4.1.7 LIMIT and OFFSET

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"id", "name"})
    .where("active", "=", .{ .boolean = true }))
    .orderBy("created_at", .desc)
    .limit(10)
    .offset(20)
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT id, name FROM users WHERE active = true
//         ORDER BY created_at DESC LIMIT 10 OFFSET 20
```

#### 4.1.8 JOIN Clauses

##### INNER JOIN

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"users.id", "users.name", "posts.title"})
    .join("posts", "users.id", "posts.user_id"))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT users.id, users.name, posts.title FROM users
//         INNER JOIN posts ON users.id = posts.user_id
```

##### LEFT JOIN

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"users.id", "users.name", "posts.title"})
    .leftJoin("posts", "users.id", "posts.user_id"))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT users.id, users.name, posts.title FROM users
//         LEFT JOIN posts ON users.id = posts.user_id
```

##### RIGHT JOIN

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"users.id", "users.name", "posts.title"})
    .rightJoin("posts", "users.id", "posts.user_id"))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT users.id, users.name, posts.title FROM users
//         RIGHT JOIN posts ON users.id = posts.user_id
```

##### FULL OUTER JOIN

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"users.id", "users.name", "posts.title"})
    .fullJoin("posts", "users.id", "posts.user_id"))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT users.id, users.name, posts.title FROM users
//         FULL OUTER JOIN posts ON users.id = posts.user_id
```

##### Multiple JOINs with WHERE

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try (try (try query
    .select(&[_][]const u8{"u.id", "u.name", "p.title", "c.content"})
    .join("posts p", "users.id", "p.user_id"))
    .leftJoin("comments c", "p.id", "c.post_id"))
    .where("u.active", "=", .{ .boolean = true }))
    .orderBy("u.name", .asc)
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: SELECT u.id, u.name, p.title, c.content FROM users
//         INNER JOIN posts p ON users.id = p.user_id
//         LEFT JOIN comments c ON p.id = c.post_id
//         WHERE u.active = true
//         ORDER BY u.name ASC
```

#### 4.1.9 Complete SELECT Example

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };
    var conn = try dig.db.connect(allocator, config);
    defer conn.disconnect();

    // Build query with JOIN
    var query = try dig.query.Select.init(allocator, "users");
    defer query.deinit();

    const sql = try (try (try (try query
        .select(&[_][]const u8{"users.id", "users.name", "users.email", "posts.title"})
        .join("posts", "users.id", "posts.user_id"))
        .where("users.age", ">=", .{ .integer = 18 }))
        .where("posts.published", "=", .{ .boolean = true }))
        .orderBy("users.name", .asc)
        .limit(50)
        .toSql(.postgresql);
    defer allocator.free(sql);

    std.debug.print("SQL: {s}\n\n", .{sql});

    // Execute query
    var result = try conn.query(sql);
    defer result.deinit();

    // Process results
    for (result.rows) |row| {
        const id = row.get("id").?.integer;
        const name = row.get("name").?.text;
        const email = row.get("email").?.text;
        const title = row.get("title").?.text;
        std.debug.print("User {d}: {s} ({s}) - Post: {s}\n", .{ id, name, email, title });
    }
}
```

---

### 4.2 INSERT Query Builder

Build INSERT queries to add new records.

#### 4.2.1 Basic INSERT

```zig
var query = try dig.query.Insert.init(allocator, "users");
defer query.deinit();

const sql = try (try (try query
    .addValue("name", .{ .text = "John Doe" }))
    .addValue("email", .{ .text = "john@example.com" }))
    .addValue("age", .{ .integer = 30 })
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: INSERT INTO users (name, email, age)
//         VALUES ('John Doe', 'john@example.com', 30)
```

#### 4.2.2 Using Hash Map for Values

For more convenience, use `setValues` with a hash map:

```zig
var query = try dig.query.Insert.init(allocator, "users");
defer query.deinit();

var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{ .text = "Jane Doe" });
try values.put("email", .{ .text = "jane@example.com" });
try values.put("age", .{ .integer = 25 });
try values.put("active", .{ .boolean = true });

const sql = try (try query.setValues(values)).toSql(.postgresql);
defer allocator.free(sql);
// Result: INSERT INTO users (name, email, age, active)
//         VALUES ('Jane Doe', 'jane@example.com', 25, true)
```

#### 4.2.3 Complete INSERT Example

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };
    var conn = try dig.db.connect(allocator, config);
    defer conn.disconnect();

    // Build INSERT query
    var query = try dig.query.Insert.init(allocator, "users");
    defer query.deinit();

    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("name", .{ .text = "Alice" });
    try values.put("email", .{ .text = "alice@example.com" });
    try values.put("age", .{ .integer = 28 });
    try values.put("active", .{ .boolean = true });

    const sql = try (try query.setValues(values)).toSql(.postgresql);
    defer allocator.free(sql);

    std.debug.print("SQL: {s}\n", .{sql});

    // Execute INSERT
    try conn.execute(sql);
    std.debug.print("User inserted successfully!\n", .{});
}
```

---

### 4.3 UPDATE Query Builder

Build UPDATE queries to modify existing records.

#### 4.3.1 Basic UPDATE

```zig
var query = try dig.query.Update.init(allocator, "users");
defer query.deinit();

const sql = try (try (try query
    .set("age", .{ .integer = 31 }))
    .where("id", "=", .{ .integer = 1 }))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: UPDATE users SET age = 31 WHERE id = 1
```

#### 4.3.2 Multiple SET Clauses

```zig
var query = try dig.query.Update.init(allocator, "users");
defer query.deinit();

const sql = try (try (try (try query
    .set("name", .{ .text = "John Smith" }))
    .set("age", .{ .integer = 31 }))
    .set("active", .{ .boolean = false }))
    .where("id", "=", .{ .integer = 1 })
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: UPDATE users SET name = 'John Smith', age = 31, active = false
//         WHERE id = 1
```

#### 4.3.3 Using Hash Map for Updates

```zig
var query = try dig.query.Update.init(allocator, "users");
defer query.deinit();

var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{ .text = "Jane Smith" });
try values.put("age", .{ .integer = 32 });
try values.put("active", .{ .boolean = true });

const sql = try (try (try query
    .setMultiple(values))
    .where("id", "=", .{ .integer = 2 }))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: UPDATE users SET name = 'Jane Smith', age = 32, active = true
//         WHERE id = 2
```

#### 4.3.4 Multiple WHERE Clauses

```zig
var query = try dig.query.Update.init(allocator, "users");
defer query.deinit();

const sql = try (try (try (try query
    .set("active", .{ .boolean = false }))
    .where("last_login", "<", .{ .timestamp = 1609459200 }))
    .where("email_verified", "=", .{ .boolean = false }))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: UPDATE users SET active = false
//         WHERE last_login < 1609459200 AND email_verified = false
```

#### 4.3.5 Complete UPDATE Example

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };
    var conn = try dig.db.connect(allocator, config);
    defer conn.disconnect();

    // Build UPDATE query
    var query = try dig.query.Update.init(allocator, "users");
    defer query.deinit();

    var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
    defer values.deinit();

    try values.put("email", .{ .text = "newemail@example.com" });
    try values.put("active", .{ .boolean = true });

    const sql = try (try (try query
        .setMultiple(values))
        .where("id", "=", .{ .integer = 5 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    std.debug.print("SQL: {s}\n", .{sql});

    // Execute UPDATE
    try conn.execute(sql);
    std.debug.print("User updated successfully!\n", .{});
}
```

---

### 4.4 DELETE Query Builder

Build DELETE queries to remove records.

#### 4.4.1 Basic DELETE

```zig
var query = try dig.query.Delete.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .where("id", "=", .{ .integer = 1 }))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: DELETE FROM users WHERE id = 1
```

#### 4.4.2 Multiple WHERE Clauses

```zig
var query = try dig.query.Delete.init(allocator, "users");
defer query.deinit();

const sql = try (try (try query
    .where("active", "=", .{ .boolean = false }))
    .where("last_login", "<", .{ .timestamp = 1609459200 }))
    .toSql(.postgresql);
defer allocator.free(sql);
// Result: DELETE FROM users WHERE active = false AND last_login < 1609459200
```

#### 4.4.3 Complete DELETE Example

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };
    var conn = try dig.db.connect(allocator, config);
    defer conn.disconnect();

    // Build DELETE query
    var query = try dig.query.Delete.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query
        .where("id", "=", .{ .integer = 10 }))
        .toSql(.postgresql);
    defer allocator.free(sql);

    std.debug.print("SQL: {s}\n", .{sql});

    // Execute DELETE
    try conn.execute(sql);
    std.debug.print("User deleted successfully!\n", .{});
}
```

---

## 7. Working with Query Results

### 7.1 Accessing Result Data

Query results are returned in a `QueryResult` structure:

```zig
pub const QueryResult = struct {
    columns: []const []const u8,  // Column names
    rows: []const Row,              // Result rows
    allocator: std.mem.Allocator,
};
```

### 7.2 Reading Row Values

Access row values by column name or index:

```zig
var result = try conn.query("SELECT id, name, email FROM users");
defer result.deinit();

for (result.rows) |row| {
    // By column name (returns ?SqlValue)
    const id = row.get("id").?.integer;
    const name = row.get("name").?.text;
    const email = row.get("email").?.text;

    // By index
    const id_alt = row.values[0].integer;
    const name_alt = row.values[1].text;
    const email_alt = row.values[2].text;

    std.debug.print("User {d}: {s} ({s})\n", .{ id, name, email });
}
```

### 7.3 Handling NULL Values

Check for NULL values before accessing:

```zig
for (result.rows) |row| {
    const id = row.get("id").?.integer;
    const name = row.get("name").?.text;

    // Handle nullable column
    const age_value = row.get("age");
    if (age_value != null and age_value.? != .null) {
        const age = age_value.?.integer;
        std.debug.print("Age: {d}\n", .{age});
    } else {
        std.debug.print("Age: NULL\n", .{});
    }
}
```

### 7.4 Getting Column Information

```zig
var result = try conn.query("SELECT * FROM users");
defer result.deinit();

// Print column names
std.debug.print("Columns: ", .{});
for (result.columns) |col| {
    std.debug.print("{s} ", .{col});
}
std.debug.print("\n", .{});

// Get column index by name
const email_idx = result.getColumnIndex("email");
if (email_idx) |idx| {
    std.debug.print("Email column is at index {d}\n", .{idx});
}
```

---

## 8. Transactions

Execute multiple queries atomically using transactions:

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };
    var conn = try dig.db.connect(allocator, config);
    defer conn.disconnect();

    // Begin transaction
    try conn.beginTransaction();
    errdefer conn.rollback() catch {};

    // Execute multiple queries
    var insert1 = try dig.query.Insert.init(allocator, "users");
    defer insert1.deinit();
    const sql1 = try (try (try insert1
        .addValue("name", .{ .text = "User 1" }))
        .addValue("email", .{ .text = "user1@example.com" }))
        .toSql(.postgresql);
    defer allocator.free(sql1);
    try conn.execute(sql1);

    var insert2 = try dig.query.Insert.init(allocator, "users");
    defer insert2.deinit();
    const sql2 = try (try (try insert2
        .addValue("name", .{ .text = "User 2" }))
        .addValue("email", .{ .text = "user2@example.com" }))
        .toSql(.postgresql);
    defer allocator.free(sql2);
    try conn.execute(sql2);

    // Commit transaction
    try conn.commit();
    std.debug.print("Transaction committed successfully!\n", .{});
}
```

---

## 9. Best Practices

### 9.1 Always Free Resources

Use `defer` to ensure cleanup:

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try query.toSql(.postgresql);
defer allocator.free(sql);

var result = try db.query(sql);
defer result.deinit();
```

### 9.2 Use Transactions for Multiple Operations

Ensure atomicity for related operations:

```zig
try db.beginTransaction();
errdefer db.rollback() catch {};

// Multiple operations...

try db.commit();
```

### 9.3 Handle Errors Explicitly

**Important**: Chainable query builder methods (`select`, `where`, `join`, `orderBy`, `limit`, `offset`, `addValue`, `set`, `delete`, etc.) do **not** return errors. Errors are stored internally and checked when executing.

Only execution methods (`get()`, `execute()`, `first()`) return `dig.errors.DigError!` error unions. Handle errors explicitly:

```zig
const std = @import("std");
const dig = @import("dig");

// Only get() returns an error, not the chain methods
const result = try conn.table("users")
    .select(&.{"id", "name"})
    .where("age", ">", .{.integer = 18})
    .get() catch |err| switch (err) {
        error.QueryBuildError => {
            std.debug.print("Invalid query builder operation\n", .{});
            return err;
        },
        error.QueryExecutionFailed => {
            std.debug.print("Query execution failed\n", .{});
            return err;
        },
        error.OutOfMemory => {
            std.debug.print("Out of memory\n", .{});
            return err;
        },
        else => {
            std.debug.print("Unexpected error: {any}\n", .{err});
            return err;
        },
    };
defer result.deinit();
```

**Common Query Builder Errors**:
- `QueryBuildError` - Invalid query builder operation (e.g., using JOIN on non-SELECT query, or errors stored during chain building)
- `QueryExecutionFailed` - Query execution failed at database level
- `OutOfMemory` - Memory allocation failed during query building or execution

### 9.4 Check for NULL Values

Always check nullable columns:

```zig
const value = row.get("nullable_column");
if (value != null and value.? != .null) {
    // Use value.?
}
```

---

## 10. Limitations

Current limitations:

- **Subqueries**: Not yet supported (use raw SQL)
- **Aggregate functions**: Not yet supported (COUNT, SUM, etc.)
- **GROUP BY / HAVING**: Not yet supported
- **Prepared statements**: Not yet supported (coming soon)

For advanced queries, use raw SQL with `db.query()` or `db.execute()`.

---

## 11. Next Steps

- **Manage schema changes**: See [`migrations.md`](./migrations.md)
- **Learn about database drivers**: See [`database-drivers.md`](./database-drivers.md)
- **API reference**: See [`api-reference.md`](./api-reference.md)

