## Database Drivers

Dig supports multiple database systems through a driver architecture.
This guide covers PostgreSQL and MySQL drivers, their features, type mappings, and conditional compilation.

---

## 1. Overview

Dig's driver system provides:

- **Abstraction**: Common interface for different databases via VTable pattern
- **Conditional Compilation**: Enable only the drivers you need
- **Zero Dependencies by Default**: No database libraries required unless explicitly enabled
- **Type Safety**: Automatic conversion between database and Zig types
- **Native Performance**: Direct bindings to C client libraries

---

## 2. Driver Architecture

### 2.1 VTable Pattern

All drivers implement a common interface using Zig's VTable pattern:

```zig
pub const Connection = struct {
    vtable: *const VTable,
    state: *anyopaque,

    pub const VTable = struct {
        connect: *const fn(state: *anyopaque, config: ConnectionConfig, allocator: Allocator) !void,
        disconnect: *const fn(state: *anyopaque) void,
        execute: *const fn(state: *anyopaque, query: []const u8, allocator: Allocator) !void,
        query: *const fn(state: *anyopaque, query: []const u8, allocator: Allocator) !QueryResult,
        beginTransaction: *const fn(state: *anyopaque) !void,
        commit: *const fn(state: *anyopaque) !void,
        rollback: *const fn(state: *anyopaque) !void,
    };
};
```

This allows different database drivers to be used interchangeably through the same API.

### 2.2 Driver Components

Each driver consists of:

1. **C Library Bindings** (`src/dig/libs/`)
   - Low-level FFI to database client library
   - Type definitions for C structures
   - Function wrappers for safety

2. **Driver Implementation** (`src/dig/drivers/`)
   - High-level Zig interface
   - Connection management
   - Query execution and result parsing
   - Type conversion logic
   - Error handling

---

## 3. Conditional Compilation

### 3.1 Build Options

Dig uses build options to conditionally compile database drivers:

| Build Option | Default | Description |
|--------------|---------|-------------|
| `-Dpostgresql=true` | `false` | Enable PostgreSQL driver |
| `-Dmysql=true` | `false` | Enable MySQL driver |

**Important**: Both drivers are **disabled by default**. You must explicitly enable the ones you need.

### 3.2 Enabling Drivers

**Option 1: Command Line**

```bash
zig build -Dpostgresql=true
zig build -Dmysql=true
zig build -Dpostgresql=true -Dmysql=true  # Both
```

**Option 2: In Dependency Configuration**

In your `build.zig`:

```zig
const dig = b.dependency("dig", .{
    .target = target,
    .optimize = optimize,
    .postgresql = true,  // Enable PostgreSQL
    .mysql = true,       // Enable MySQL
});
```

### 3.3 Runtime Behavior

If you try to connect to a database without its driver enabled:

```zig
const config = dig.types.ConnectionConfig{
    .database_type = .postgresql,  // PostgreSQL not enabled
    // ...
};
var db = try dig.db.connect(allocator, config);
// Error: UnsupportedDatabase
// Database driver not enabled. Build with -Dpostgresql=true to enable PostgreSQL support.
```

---

## 4. PostgreSQL Driver

### 4.1 Overview

- **Status**: ✅ Fully supported
- **C Library**: libpq (PostgreSQL C client library)
- **Build Flag**: `-Dpostgresql=true`
- **Default Port**: 5432

### 4.2 Installation

**Debian/Ubuntu**:
```bash
sudo apt-get install libpq-dev
```

**macOS (Homebrew)**:
```bash
brew install postgresql@15
```

**Alpine Linux**:
```bash
apk add postgresql-dev
```

**Docker**:
```dockerfile
FROM debian:trixie-slim
RUN apt-get update && apt-get install -y libpq-dev
```

### 4.3 Connection Configuration

```zig
const config = dig.types.ConnectionConfig{
    .database_type = .postgresql,
    .host = "localhost",
    .port = 5432,
    .database = "mydb",
    .username = "user",
    .password = "pass",
    .ssl = false,
};

var db = try dig.db.connect(allocator, config);
defer db.disconnect();
```

### 4.4 Type Mappings

| Dig Type | PostgreSQL Type | Zig Type | Notes |
|----------|----------------|----------|-------|
| `integer` | INT, INTEGER, INT2, INT4 | `i64` | Stored as integer |
| `bigint` | BIGINT, INT8 | `i64` | Stored as integer |
| `float` | REAL, FLOAT4 | `f64` | Single precision |
| `double` | DOUBLE PRECISION, FLOAT8 | `f64` | Double precision |
| `text` | TEXT, VARCHAR | `[]const u8` | UTF-8 string |
| `varchar` | VARCHAR(n) | `[]const u8` | Limited length |
| `boolean` | BOOLEAN, BOOL | `bool` | True/false |
| `timestamp` | TIMESTAMP, TIMESTAMPTZ | `[]const u8` | ISO 8601 string |
| `blob` | BYTEA | `[]const u8` | Binary data |
| `json` | JSONB | `[]const u8` | Binary JSON |

### 4.5 Auto-Increment

PostgreSQL uses `SERIAL` keyword for auto-increment:

```zig
try table.addColumn(.{
    .name = "id",
    .type = .integer,
    .primary_key = true,
    .auto_increment = true,
});

try table.addColumn(.{
    .name = "id",
    .type = .bigint,
    .primary_key = true,
    .auto_increment = true,
});
```

Generated SQL:
```sql
CREATE TABLE IF NOT EXISTS example (
    id INTEGER PRIMARY KEY SERIAL,
    -- or
    id BIGINT PRIMARY KEY SERIAL
);
```

### 4.6 JSON Support

PostgreSQL uses `JSONB` (binary JSON) for better performance:

```zig
try table.addColumn(.{
    .name = "metadata",
    .type = .json,  // Becomes JSONB
    .nullable = true,
});
```

Query JSON data:

```zig
const sql = "SELECT metadata->>'name' as name FROM users WHERE id = 1";
var result = try db.query(sql);
defer result.deinit();
```

### 4.7 Transaction Support

```zig
try db.beginTransaction();  // BEGIN
errdefer db.rollback() catch {};  // ROLLBACK on error

try db.execute("INSERT INTO users (name) VALUES ('Alice')");
try db.execute("INSERT INTO posts (user_id, title) VALUES (1, 'Hello')");

try db.commit();  // COMMIT
```

### 4.8 Example: Full CRUD with PostgreSQL

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect
    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };
    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    // Create table
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });
    try table.addColumn(.{
        .name = "name",
        .type = .varchar,
        .length = 255,
        .nullable = false,
    });

    const create_sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(create_sql);
    try db.execute(create_sql);

    // Insert
    var insert = try dig.query.Insert.init(allocator, "users");
    defer insert.deinit();
    const insert_sql = try (try insert
        .addValue("name", .{ .text = "Alice" }))
        .toSql(.postgresql);
    defer allocator.free(insert_sql);
    try db.execute(insert_sql);

    // Select
    var select = try dig.query.Select.init(allocator, "users");
    defer select.deinit();
    const select_sql = try select.toSql(.postgresql);
    defer allocator.free(select_sql);

    var result = try db.query(select_sql);
    defer result.deinit();

    for (result.rows) |row| {
        const name = row.get("name").?.text;
        std.debug.print("User: {s}\n", .{name});
    }
}
```

---

## 5. MySQL Driver

### 5.1 Overview

- **Status**: ✅ Fully supported
- **C Library**: libmysqlclient (MySQL C client library)
- **Build Flag**: `-Dmysql=true`
- **Default Port**: 3306

### 5.2 Installation

**Debian/Ubuntu**:
```bash
sudo apt-get install libmysqlclient-dev
```

**macOS (Homebrew)**:
```bash
brew install mysql-client
```

**Alpine Linux**:
```bash
apk add mysql-dev mariadb-connector-c-dev
```

**Docker**:
```dockerfile
FROM debian:trixie-slim
RUN apt-get update && apt-get install -y libmysqlclient-dev
```

### 5.3 Connection Configuration

```zig
const config = dig.types.ConnectionConfig{
    .database_type = .mysql,
    .host = "localhost",
    .port = 3306,
    .database = "mydb",
    .username = "user",
    .password = "pass",
    .ssl = false,
};

var db = try dig.db.connect(allocator, config);
defer db.disconnect();
```

### 5.4 Type Mappings

| Dig Type | MySQL Type | Zig Type | Notes |
|----------|-----------|----------|-------|
| `integer` | INT | `i64` | 32-bit integer |
| `bigint` | BIGINT | `i64` | 64-bit integer |
| `float` | FLOAT | `f64` | Single precision |
| `double` | DOUBLE | `f64` | Double precision |
| `text` | TEXT | `[]const u8` | Variable length |
| `varchar` | VARCHAR(n) | `[]const u8` | Limited length |
| `boolean` | BOOLEAN, TINYINT(1) | `bool` | 0/1 values |
| `timestamp` | TIMESTAMP, DATETIME | `[]const u8` | String format |
| `blob` | BLOB | `[]const u8` | Binary data |
| `json` | JSON | `[]const u8` | JSON string |

### 5.5 Auto-Increment

MySQL uses `AUTO_INCREMENT` attribute:

```zig
try table.addColumn(.{
    .name = "id",
    .type = .bigint,
    .primary_key = true,
    .auto_increment = true,
});
```

Generated SQL:
```sql
CREATE TABLE IF NOT EXISTS example (
    id BIGINT PRIMARY KEY AUTO_INCREMENT
);
```

### 5.6 JSON Support

MySQL uses `JSON` type (string-based):

```zig
try table.addColumn(.{
    .name = "metadata",
    .type = .json,
    .nullable = true,
});
```

Query JSON data:

```zig
const sql = "SELECT JSON_EXTRACT(metadata, '$.name') as name FROM users WHERE id = 1";
var result = try db.query(sql);
defer result.deinit();
```

### 5.7 Transaction Support

```zig
try db.beginTransaction();  // START TRANSACTION
errdefer db.rollback() catch {};  // ROLLBACK on error

try db.execute("INSERT INTO users (name) VALUES ('Alice')");
try db.execute("INSERT INTO posts (user_id, title) VALUES (1, 'Hello')");

try db.commit();  // COMMIT
```

### 5.8 Example: Full CRUD with MySQL

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect
    const config = dig.types.ConnectionConfig{
        .database_type = .mysql,
        .host = "localhost",
        .port = 3306,
        .database = "mydb",
        .username = "user",
        .password = "pass",
    };
    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    // Create table
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });
    try table.addColumn(.{
        .name = "name",
        .type = .varchar,
        .length = 255,
        .nullable = false,
    });

    const create_sql = try table.toCreateTableSql(.mysql, allocator);
    defer allocator.free(create_sql);
    try db.execute(create_sql);

    // Insert
    var insert = try dig.query.Insert.init(allocator, "users");
    defer insert.deinit();
    const insert_sql = try (try insert
        .addValue("name", .{ .text = "Bob" }))
        .toSql(.mysql);
    defer allocator.free(insert_sql);
    try db.execute(insert_sql);

    // Select
    var select = try dig.query.Select.init(allocator, "users");
    defer select.deinit();
    const select_sql = try select.toSql(.mysql);
    defer allocator.free(select_sql);

    var result = try db.query(select_sql);
    defer result.deinit();

    for (result.rows) |row| {
        const name = row.get("name").?.text;
        std.debug.print("User: {s}\n", .{name});
    }
}
```

---

## 6. Database-Specific Differences

### 6.1 SQL Syntax Differences

| Feature | PostgreSQL | MySQL |
|---------|-----------|-------|
| Auto-increment | `SERIAL`, `BIGSERIAL` | `AUTO_INCREMENT` |
| JSON type | `JSONB` (binary) | `JSON` (text) |
| String concatenation | `||` operator | `CONCAT()` function |
| Case-insensitive LIKE | `ILIKE` | `LIKE` (case-insensitive by default) |
| Boolean literals | `true`, `false` | `TRUE`, `FALSE`, `1`, `0` |
| String quotes | Single quotes `'` | Single or double quotes `'` or `"` |

### 6.2 Transaction Differences

**PostgreSQL**:
```sql
BEGIN;
-- queries
COMMIT;
-- or
ROLLBACK;
```

**MySQL**:
```sql
START TRANSACTION;
-- queries
COMMIT;
-- or
ROLLBACK;
```

Dig handles these differences automatically.

### 6.3 Performance Characteristics

**PostgreSQL**:
- Better support for complex queries
- JSONB is binary format (faster queries)
- More standards-compliant SQL
- Better for write-heavy workloads

**MySQL**:
- Faster for simple read queries
- Better for read-heavy workloads
- Simpler replication setup
- More forgiving with SQL syntax

---

## 7. Multi-Database Applications

### 7.1 Supporting Both Databases

Enable both drivers:

```zig
const dig = b.dependency("dig", .{
    .target = target,
    .optimize = optimize,
    .postgresql = true,
    .mysql = true,
});
```

### 7.2 Runtime Database Selection

Choose database at runtime based on configuration:

```zig
const db_type = std.os.getenv("DB_TYPE") orelse "postgresql";

const config = dig.types.ConnectionConfig{
    .database_type = if (std.mem.eql(u8, db_type, "mysql"))
        .mysql
    else
        .postgresql,
    .host = std.os.getenv("DB_HOST") orelse "localhost",
    .port = if (std.mem.eql(u8, db_type, "mysql")) 3306 else 5432,
    .database = std.os.getenv("DB_NAME") orelse "mydb",
    .username = std.os.getenv("DB_USER") orelse "user",
    .password = std.os.getenv("DB_PASS") orelse "pass",
};

var db = try dig.db.connect(allocator, config);
defer db.disconnect();
```

### 7.3 Writing Cross-Database SQL

When writing raw SQL, consider database differences:

```zig
const sql = switch (config.database_type) {
    .postgresql =>
        \\SELECT * FROM users
        \\WHERE name ILIKE '%john%'
    ,
    .mysql =>
        \\SELECT * FROM users
        \\WHERE name LIKE '%john%'
    ,
};

var result = try db.query(sql);
defer result.deinit();
```

Or use query builders which handle differences automatically:

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"*"})
    .where("name", "LIKE", .{ .text = "%john%" }))
    .toSql(config.database_type);  // Automatically adapts
defer allocator.free(sql);
```

---

## 8. Error Handling

### 8.1 Connection Errors

```zig
const db = dig.db.connect(allocator, config) catch |err| {
    switch (err) {
        error.ConnectionFailed => {
            std.debug.print("Failed to connect to database\n", .{});
            std.debug.print("Check host, port, username, and password\n", .{});
        },
        error.UnsupportedDatabase => {
            std.debug.print("Database driver not enabled\n", .{});
            std.debug.print("Rebuild with -Dpostgresql=true or -Dmysql=true\n", .{});
        },
        else => return err,
    }
    return err;
};
```

### 8.2 Query Errors

```zig
db.execute(sql) catch |err| {
    switch (err) {
        error.QueryExecutionFailed => {
            std.debug.print("Query failed: {s}\n", .{sql});
            // Check logs for database error message
        },
        else => return err,
    }
};
```

---

## 9. Advanced Features

### 9.1 Connection Pooling

**Status**: ⏳ Planned for future release

Connection pooling will allow reusing database connections for better performance:

```zig
// Future API (not yet implemented)
var pool = try dig.ConnectionPool.init(allocator, config, .{
    .min_connections = 5,
    .max_connections = 20,
});
defer pool.deinit();

var conn = try pool.acquire();
defer pool.release(conn);
```

### 9.2 Prepared Statements

**Status**: ⏳ Planned for future release

Prepared statements will provide better performance and SQL injection protection:

```zig
// Future API (not yet implemented)
var stmt = try db.prepare("SELECT * FROM users WHERE id = ?");
defer stmt.finalize();

var result = try stmt.execute(&[_]dig.types.SqlValue{
    .{ .integer = 1 }
});
defer result.deinit();
```

---

## 10. Best Practices

### 10.1 Enable Only Needed Drivers

Only enable the database drivers you actually use:

```zig
// Good: Only enable what you need
const dig = b.dependency("dig", .{
    .postgresql = true,  // Only PostgreSQL
});

// Bad: Enabling drivers you don't use
const dig = b.dependency("dig", .{
    .postgresql = true,
    .mysql = true,  // Not used, increases dependencies
});
```

### 10.2 Use Query Builders for Portability

Query builders generate database-specific SQL automatically:

```zig
// Good: Works on both databases
var query = try dig.query.Select.init(allocator, "users");
const sql = try query.toSql(config.database_type);

// Bad: Hardcoded for PostgreSQL
const sql = "SELECT * FROM users WHERE name ILIKE '%john%'";
```

### 10.3 Always Close Connections

Use `defer` to ensure cleanup:

```zig
var db = try dig.db.connect(allocator, config);
defer db.disconnect();  // Always called, even on error
```

---

## 11. Next Steps

- **API reference**: See [`api-reference.md`](./api-reference.md)
- **Architecture details**: See [`architecture.md`](./architecture.md)

