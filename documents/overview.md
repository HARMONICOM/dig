## Dig ORM Overview

Dig is a type-safe SQL query builder and ORM library for Zig.
It focuses on **simplicity**, **type safety**, and **multi-database support** while
leveraging Zig's compile‑time guarantees.

---

## 1. Design Philosophy

- **Type Safety**: Compile-time type checking for SQL queries and values
- **Intuitive API**: Fluent interface for building queries, similar to modern ORMs
- **Multi-database Support**: Support for PostgreSQL and MySQL with conditional compilation
- **Lightweight**: Minimal dependencies, built on Zig's standard library
- **Performance**: Efficient query building and execution with explicit memory management

---

## 2. Main Features

1. **Database Connection Management**
   - Connection abstraction layer with VTable pattern
   - Support for PostgreSQL and MySQL (conditionally compiled)
   - Transaction support (BEGIN/COMMIT/ROLLBACK)

2. **Schema Definition**
   - Declarative table and column definitions
   - Type-safe column types (integer, text, varchar, boolean, etc.)
   - Constraints (primary key, unique, nullable, default values)
   - Cross-database CREATE TABLE SQL generation

3. **Query Builders**
   - Fluent API for SELECT, INSERT, UPDATE, DELETE queries
   - Method chaining for intuitive query construction
   - Database-specific SQL generation
   - Type-safe value handling with `SqlValue` union type

4. **Migration System**
   - SQL-based migrations with `-- up` and `-- down` sections
   - Migration history tracking in `_dig_migrations` table
   - Batch-based rollback support
   - Standalone migration CLI tool (`migrate` binary)
   - Migration status reporting

5. **Type-Safe SQL Values**
   - Tagged union for SQL values (null, integer, float, text, boolean, blob, timestamp)
   - Automatic type conversion between database and Zig types
   - Safe handling of NULL values

6. **Conditional Compilation**
   - Database drivers disabled by default
   - Explicitly enable only the drivers you need (`-Dpostgresql=true`, `-Dmysql=true`)
   - Zero build dependencies by default
   - Smaller binary size and faster build times

---

## 3. Architecture

High‑level data flow:

```text
Application Code
    ↓
Query Builders / Schema Definition
    ↓
Database Interface (High-level API)
    ↓
Connection Abstraction (VTable-based)
    ↓
Database Drivers (PostgreSQL / MySQL)
    ↓
C Libraries (libpq / libmysqlclient)
    ↓
Database Server
```

Core modules:

- `db.zig`: Database interface and connection management
- `connection.zig`: Connection abstraction with VTable pattern
- `query.zig`: Query builders (Select, Insert, Update, Delete)
- `queryBuilder.zig`: Chainable query builder for direct execution
- `schema.zig`: Table and column definition system
- `migration.zig`: SQL-based migration system
- `types.zig`: Core type definitions (SqlValue, DatabaseType, etc.)
- `errors.zig`: Error type definitions
- `drivers/`: Database-specific implementations
- `libs/`: C library bindings (libpq, libmysqlclient)

---

## 4. Technical Requirements

- **Language**: Zig **0.15.2** or later
- **Dependencies**:
  - Zig standard library
  - **libpq** (PostgreSQL C client library) - Optional, enabled with `-Dpostgresql=true`
  - **libmysqlclient** (MySQL C client library) - Optional, enabled with `-Dmysql=true`

When using Dig as a module:

- Database driver compilation is controlled via build options
- By default, no database drivers are enabled (zero dependencies)
- Explicitly enable the drivers you need in your `build.zig.zon` or build command
- The Docker environment in this repository already includes all database client libraries

Supported platforms:

- Linux
- macOS
- Windows (Docker environment recommended for database client libraries)

---

## 5. Supported Databases

### PostgreSQL

- **Status**: ✅ Fully supported
- **C Library**: libpq
- **Build Flag**: `-Dpostgresql=true`
- **Features**: Full CRUD, transactions, JSONB, SERIAL auto-increment
- **Connection String**: `postgresql://user:password@host:port/database`

### MySQL

- **Status**: ✅ Fully supported
- **C Library**: libmysqlclient
- **Build Flag**: `-Dmysql=true`
- **Features**: Full CRUD, transactions, JSON, AUTO_INCREMENT
- **Connection String**: `mysql://user:password@host:port/database`

---

## 6. Where to Go Next

- **Set up and connect to a database**: See [`getting-started.md`](./getting-started.md)
- **Define database schemas**: See [`schema.md`](./schema.md)
- **Build and execute queries**: See [`query-builders.md`](./query-builders.md)
- **Manage database migrations**: See [`migrations.md`](./migrations.md)
- **Learn about database drivers**: See [`database-drivers.md`](./database-drivers.md)
- **API reference**: See [`api-reference.md`](./api-reference.md)

---

## 7. Example Usage

Here's a quick example of what working with Dig looks like:

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to database
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

    // Build and execute a query using chainable query builder
    var result = try db.table("users")
        .select(&.{"id", "name", "email"})
        .where("age", ">", .{.integer = 18})
        .orderBy("name", .asc)
        .get();
    defer result.deinit();

    // Process results
    for (result.rows) |row| {
        const id = row.get("id").?.integer;
        const name = row.get("name").?.text;
        std.debug.print("User {d}: {s}\n", .{ id, name });
    }
}
```

---

## 8. Memory Management

Dig uses explicit memory management following Zig's conventions:

- **Query Builders**: Require an allocator, must call `deinit()` when done
- **SQL Strings**: Returned by `toSql()` must be freed by the caller
- **Query Results**: Must be freed using `deinit()`
- **Database Connection**: Freed via `disconnect()`

Example memory flow:

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit(); // Free query builder

const sql = try query.toSql(.postgresql);
defer allocator.free(sql); // Free SQL string

var result = try db.query(sql);
defer result.deinit(); // Free query result
```

---

## 9. Security & Best Practices

- **SQL Injection**: Current version uses string interpolation; prepared statements are planned
- **Connection Strings**: Should not be logged or exposed in error messages
- **Credentials**: Store database passwords securely (environment variables, secret management)
- **SSL**: SSL support available for encrypted database connections
- **Memory Safety**: Always use `defer` for cleanup to prevent memory leaks

---

## 10. Future Enhancements

Planned features:

- ✅ Migration system (completed in v0.1.0)
- ✅ JOIN support in SELECT queries (completed)
- ✅ Chainable query builder (completed)
- Prepared statements support
- Connection pooling
- Relationship definitions (foreign keys)
- Subquery support
- Aggregate functions (COUNT, SUM, AVG, etc.)
- GROUP BY and HAVING clauses

