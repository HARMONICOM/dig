# Dig ORM Specification

## 1. Overview

### 1.1 Purpose

Dig ORM is a type-safe SQL query builder library for Zig programming language. It provides an intuitive API for building SQL queries similar to Drizzle ORM, supporting PostgreSQL and MySQL databases.

### 1.2 Design Goals

- **Type Safety**: Compile-time type checking for SQL queries
- **Intuitive API**: Fluent interface for building queries
- **Multi-database Support**: Support for PostgreSQL and MySQL
- **Lightweight**: Minimal dependencies, pure Zig implementation
- **Performance**: Efficient query building and execution

### 1.3 Target Users

- Zig developers who need database access
- Developers familiar with ORM libraries like Drizzle ORM
- Projects requiring type-safe SQL query building

## 2. Architecture

### 2.1 Core Components

#### 2.1.1 Error Handling (`errors.zig`)

Defines error types for database operations:

- `ConnectionFailed` - Failed to establish database connection
- `QueryExecutionFailed` - Query execution failed
- `InvalidQuery` - Invalid SQL query
- `InvalidSchema` - Invalid schema definition
- `TypeMismatch` - Type mismatch error
- `NotFound` - Resource not found
- `TransactionFailed` - Transaction operation failed
- `InvalidConnectionString` - Invalid connection string format
- `UnsupportedDatabase` - Unsupported database type
- `InvalidParameter` - Invalid parameter value
- `OutOfMemory` - Memory allocation failed

#### 2.1.2 Type System (`types.zig`)

Core type definitions:

- `DatabaseType` - Enumeration of supported databases (postgresql, mysql)
- `SqlValue` - Union type for SQL values (null, integer, float, text, boolean, blob, timestamp)
- `ConnectionConfig` - Database connection configuration

#### 2.1.3 Connection Abstraction (`connection.zig`)

Abstract interface for database connections:

- `Connection` - VTable-based connection interface
- `QueryResult` - Result structure for query execution
- Methods: `connect`, `disconnect`, `execute`, `query`, `beginTransaction`, `commit`, `rollback`

#### 2.1.4 Schema Definition (`schema.zig`)

Table and column definition system:

- `ColumnType` - Supported column types
- `Column` - Column definition structure
- `Table` - Table definition structure
- `toCreateTableSql()` - Generate CREATE TABLE SQL

#### 2.1.5 Query Builders (`query.zig`)

Query builder implementations:

- `SelectQuery` - SELECT query builder
- `InsertQuery` - INSERT query builder
- `UpdateQuery` - UPDATE query builder
- `DeleteQuery` - DELETE query builder

#### 2.1.6 C Library Bindings (`libs/`)

Low-level C library bindings:

- `libpq.zig` - PostgreSQL libpq C API bindings
- `libmysql.zig` - MySQL libmysqlclient C API bindings

#### 2.1.7 Database Drivers (`drivers/`)

Database-specific implementations:

- `postgresql.zig` - PostgreSQL driver (full implementation)
- `mysql.zig` - MySQL driver (full implementation)

#### 2.1.8 Database Interface (`db.zig`)

High-level database interface:

- `Database` - Main database interface
- Connection management
- Transaction support

### 2.2 Module Structure

```
src/
├── dig.zig              # Module base (root file)
├── migrate.zig          # Migration CLI tool (automatically built)
├── dig/                 # Module files directory
│   ├── errors.zig       # Error definitions
│   ├── types.zig        # Core type definitions
│   ├── connection.zig   # Connection abstraction
│   ├── schema.zig       # Schema definition system
│   ├── query.zig        # Query builders
│   ├── db.zig           # Database interface
│   ├── migration.zig    # Migration system (SQL-based)
│   ├── libs/            # C library bindings
│   │   ├── libpq.zig        # PostgreSQL libpq bindings
│   │   └── libmysql.zig     # MySQL libmysqlclient bindings
│   └── drivers/         # Database drivers
│       ├── postgresql.zig   # PostgreSQL driver
│       └── mysql.zig        # MySQL driver
└── tests/               # Test files
    ├── migrations/      # Test migration SQL files
    │   ├── 20251122_create_test_users.sql
    │   ├── 20251123_create_test_posts.sql
    │   └── 20251124_add_test_columns.sql
    ├── connection_test.zig
    ├── migration_test.zig
    └── ...

examples/                # Usage documentation
└── README.md            # Migration tool usage guide and examples
```

**Note**: Users of Dig should:
1. Create their own `migrations/` directory in their project to store migration files
2. Install the `migrate` artifact in their `build.zig` to get the migration tool automatically

### 2.3 Build Configuration

Dig supports conditional compilation of database drivers through build options:

#### 2.3.1 Build Options

- `postgresql` (bool, default: **false**) - Enable PostgreSQL driver
- `mysql` (bool, default: **false**) - Enable MySQL driver

**Note**: Both drivers are disabled by default. Users must explicitly enable the drivers they need.

#### 2.3.2 Conditional Compilation

When a driver is disabled:

1. The corresponding C library (libpq or libmysqlclient) is not linked
2. Driver code is conditionally imported as `void` type
3. Runtime connection attempts return `UnsupportedDatabase` error
4. Clear error message is logged indicating how to rebuild with the driver

This allows developers to build Dig without requiring all database client libraries to be installed.

#### 2.3.3 Usage Example

Build with only PostgreSQL support:

```bash
zig build -Dpostgresql=true
```

In dependent projects:

```zig
const dig = b.dependency("dig", .{
    .target = target,
    .optimize = optimize,
    .postgresql = true,  // Explicitly enable PostgreSQL
    // .mysql = true,    // Enable MySQL if needed
});
```

### 2.4 Test Structure

```
src/
└── tests/               # Test files directory
    ├── migrations/      # Test migration SQL files
    │   ├── 001_create_test_users.sql
    │   ├── 002_create_test_posts.sql
    │   └── 003_add_test_columns.sql
    ├── connection_test.zig
    ├── errors_test.zig
    ├── integration_test.zig
    ├── migration_test.zig    # Tests both SQL and function-based migrations
    ├── query_test.zig
    ├── schema_test.zig
    └── types_test.zig
```

**Note**: Test migrations use the `test_` prefix for table names to avoid conflicts with actual database tables.

## 3. API Specification

### 3.1 Connection Management

#### 3.1.1 ConnectionConfig

```zig
pub const ConnectionConfig = struct {
    database_type: DatabaseType,
    host: []const u8,
    port: u16,
    database: []const u8,
    username: []const u8,
    password: []const u8,
    ssl: bool = false,
};
```

#### 3.1.2 Database Connection

```zig
pub fn connect(allocator: std.mem.Allocator, config: ConnectionConfig) !Database
pub fn disconnect(self: *Database) void
```

### 3.2 Schema Definition

#### 3.2.1 Column Types

Supported column types:

- `integer` - INTEGER
- `bigint` - BIGINT
- `text` - TEXT
- `varchar` - VARCHAR (with optional length)
- `boolean` - BOOLEAN
- `float` - FLOAT
- `double` - DOUBLE
- `timestamp` - TIMESTAMP
- `blob` - BLOB
- `json` - JSON/JSONB

#### 3.2.2 Column Definition

```zig
pub const Column = struct {
    name: []const u8,
    type: ColumnType,
    nullable: bool = false,
    primary_key: bool = false,
    auto_increment: bool = false,
    unique: bool = false,
    default_value: ?[]const u8 = null,
    length: ?usize = null, // For varchar
};
```

#### 3.2.3 Table Definition

```zig
pub fn init(allocator: std.mem.Allocator, name: []const u8) Table
pub fn addColumn(self: *Table, column: Column) !void
pub fn toCreateTableSql(self: Table, db_type: DatabaseType, allocator: std.mem.Allocator) ![]const u8
pub fn deinit(self: *Table) void
```

### 3.3 Query Builders

#### 3.3.1 SelectQuery

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !SelectQuery
pub fn select(self: *SelectQuery, columns: []const []const u8) *SelectQuery
pub fn where(self: *SelectQuery, column: []const u8, operator: []const u8, value: SqlValue) !*SelectQuery
pub fn orderBy(self: *SelectQuery, column: []const u8, direction: Direction) *SelectQuery
pub fn limit(self: *SelectQuery, count: usize) *SelectQuery
pub fn offset(self: *SelectQuery, count: usize) *SelectQuery
pub fn toSql(self: *SelectQuery, db_type: DatabaseType) ![]const u8
pub fn deinit(self: *SelectQuery) void
```

#### 3.3.2 InsertQuery

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !InsertQuery
pub fn addValue(self: *InsertQuery, column: []const u8, value: SqlValue) !*InsertQuery
pub fn toSql(self: *InsertQuery, db_type: DatabaseType) ![]const u8
pub fn deinit(self: *InsertQuery) void
```

#### 3.3.3 UpdateQuery

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !UpdateQuery
pub fn set(self: *UpdateQuery, column: []const u8, value: SqlValue) !*UpdateQuery
pub fn where(self: *UpdateQuery, column: []const u8, operator: []const u8, value: SqlValue) !*UpdateQuery
pub fn toSql(self: *UpdateQuery, db_type: DatabaseType) ![]const u8
pub fn deinit(self: *UpdateQuery) void
```

#### 3.3.4 DeleteQuery

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !DeleteQuery
pub fn where(self: *DeleteQuery, column: []const u8, operator: []const u8, value: SqlValue) !*DeleteQuery
pub fn toSql(self: *DeleteQuery, db_type: DatabaseType) ![]const u8
pub fn deinit(self: *DeleteQuery) void
```

### 3.4 SQL Value Types

```zig
pub const SqlValue = union(enum) {
    null,
    integer: i64,
    float: f64,
    text: []const u8,
    boolean: bool,
    blob: []const u8,
    timestamp: i64, // Unix timestamp
};
```

### 3.5 Transaction Management

```zig
pub fn beginTransaction(self: *Database) !void
pub fn commit(self: *Database) !void
pub fn rollback(self: *Database) !void
```

### 3.6 Migration System

Dig provides a SQL-based migration system where migration SQL is stored in external files.

#### 3.6.1 SqlMigration

```zig
pub const SqlMigration = struct {
    id: []const u8,
    name: []const u8,
    up_sql: []const u8,
    down_sql: []const u8,
    allocator: std.mem.Allocator,
};
```

SQL-based migration definition loaded from a file.

**File Format**:
```sql
-- Migration description (optional comment)

-- up
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

-- down
DROP TABLE IF EXISTS users;
```

**Filename Convention**: `{id}_{name}.sql`
- Example: `20251122_create_users_table.sql`
- ID format: `YYYYMMDD` (year, month, day)
- The ID is extracted from the part before the first underscore
- The name is extracted from the remaining part with underscores replaced by spaces

##### Functions

```zig
pub fn initFromFile(allocator: std.mem.Allocator, file_path: []const u8, content: []const u8) !SqlMigration
pub fn deinit(self: *SqlMigration) void
pub fn executeUp(self: *const SqlMigration, db: *Db) !void
pub fn executeDown(self: *const SqlMigration, db: *Db) !void
```

#### 3.6.2 Manager

```zig
pub const Manager = struct {
    db: *Db,
    allocator: std.mem.Allocator,
    migrations_table: []const u8,
};
```

##### Functions

```zig
pub fn init(db: *Db, allocator: std.mem.Allocator) Manager
pub fn ensureMigrationsTable(self: *Manager) !void
pub fn loadFromDirectory(self: *Manager, dir_path: []const u8) !std.ArrayList(SqlMigration)
pub fn migrate(self: *Manager, migrations: []const SqlMigration) !void
pub fn rollback(self: *Manager, migrations: []const SqlMigration) !void
pub fn reset(self: *Manager, migrations: []const SqlMigration) !void
pub fn status(self: *Manager, migrations: []const SqlMigration) !void
```

#### 3.6.3 MigrationRecord

```zig
pub const MigrationRecord = struct {
    id: []const u8,
    name: []const u8,
    applied_at: i64,
    batch: i32,
};
```

Record of an applied migration stored in the `_dig_migrations` table.

## 4. Database Support

### 4.1 PostgreSQL

- **Driver**: `drivers/postgresql.zig`
- **C Bindings**: `libs/libpq.zig`
- **Required Library**: libpq (PostgreSQL C client library)
- **Connection String Format**: `postgresql://user:password@host:port/database`
- **Implementation Status**: ✅ Complete
- **Features**:
  - Full connection management
  - Query execution and result parsing
  - Transaction support (BEGIN/COMMIT/ROLLBACK)
  - Type conversion for common PostgreSQL types
  - JSONB support for JSON type
  - SERIAL for auto_increment

**Supported Type Mappings**:
- BOOL → SqlValue.boolean
- INT2, INT4, INT8 → SqlValue.integer
- FLOAT4, FLOAT8 → SqlValue.float
- TEXT, VARCHAR → SqlValue.text
- TIMESTAMP, TIMESTAMPTZ → SqlValue.text (converted)

### 4.2 MySQL

- **Driver**: `drivers/mysql.zig`
- **C Bindings**: `libs/libmysql.zig`
- **Required Library**: libmysqlclient (MySQL C client library)
- **Connection String Format**: `mysql://user:password@host:port/database`
- **Implementation Status**: ✅ Complete
- **Features**:
  - Full connection management
  - Query execution and result parsing
  - Transaction support (START TRANSACTION/COMMIT/ROLLBACK)
  - Type conversion for common MySQL types
  - JSON support for JSON type
  - AUTO_INCREMENT for auto_increment

**Supported Type Mappings**:
- MYSQL_TYPE_TINY, SHORT, LONG, LONGLONG → SqlValue.integer
- MYSQL_TYPE_FLOAT, DOUBLE, DECIMAL → SqlValue.float
- MYSQL_TYPE_VARCHAR, STRING, JSON → SqlValue.text
- MYSQL_TYPE_BLOB family → SqlValue.blob
- MYSQL_TYPE_TIMESTAMP, DATETIME → SqlValue.text (converted)

## 5. Usage Patterns

### 5.1 Basic Query Building

#### 5.1.1 SELECT Queries

```zig
var query = try SelectQuery.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{ "id", "name", "email" })
    .where("age", ">", .{ .integer = 18 }))
    .orderBy("name", .asc)
    .limit(10)
    .toSql(.postgresql);
defer allocator.free(sql);
```

#### 5.1.2 INSERT Queries

**Method Chaining Style**:

```zig
var query = try InsertQuery.init(allocator, "users");
defer query.deinit();

const sql = try (try (try query
    .addValue("name", .{ .text = "John Doe" }))
    .addValue("email", .{ .text = "john@example.com" }))
    .addValue("age", .{ .integer = 30 }))
    .toSql(.postgresql);
defer allocator.free(sql);
```

**Hash Map Style**:

```zig
var query = try InsertQuery.init(allocator, "users");
defer query.deinit();

var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{ .text = "John Doe" });
try values.put("email", .{ .text = "john@example.com" });
try values.put("age", .{ .integer = 30 });

const sql = try (try query.setValues(values)).toSql(.postgresql);
defer allocator.free(sql);
```

#### 5.1.3 UPDATE Queries

**Method Chaining Style**:

```zig
var query = try UpdateQuery.init(allocator, "users");
defer query.deinit();

const sql = try (try (try query
    .set("age", .{ .integer = 31 }))
    .where("id", "=", .{ .integer = 1 }))
    .toSql(.postgresql);
defer allocator.free(sql);
```

**Hash Map Style**:

```zig
var query = try UpdateQuery.init(allocator, "users");
defer query.deinit();

var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{ .text = "Jane Doe" });
try values.put("age", .{ .integer = 31 });
try values.put("active", .{ .boolean = true });

const sql = try (try (try query
    .setMultiple(values))
    .where("id", "=", .{ .integer = 1 }))
    .toSql(.postgresql);
defer allocator.free(sql);
```

#### 5.1.4 DELETE Queries

```zig
var query = try DeleteQuery.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .where("id", "=", .{ .integer = 1 }))
    .toSql(.postgresql);
defer allocator.free(sql);
```

#### 5.1.5 Executing Queries and Retrieving Results

**Index-based Access**:

```zig
var result = try db.query("SELECT id, name, age FROM users WHERE age > 18");
defer result.deinit();

for (result.rows) |row| {
    const id = row.values[0].integer;
    const name = row.values[1].text;
    const age = row.values[2].integer;
    std.debug.print("User: {d}, {s}, {d}\n", .{ id, name, age });
}
```

**Column Name-based Access**:

```zig
var result = try db.query("SELECT id, name, age FROM users WHERE age > 18");
defer result.deinit();

for (result.rows) |row| {
    const id = row.get("id").?.integer;
    const name = row.get("name").?.text;
    const age = row.get("age").?.integer;
    std.debug.print("User: {d}, {s}, {d}\n", .{ id, name, age });
}
```

**Note**: `Row.get(column_name)` returns `?SqlValue`, which is `null` if the column is not found.

### 5.2 Schema Definition

```zig
var table = Table.init(allocator, "users");
defer table.deinit();

try table.addColumn(.{
    .name = "id",
    .type = .bigint,
    .primary_key = true,
    .auto_increment = true,
});

const sql = try table.toCreateTableSql(.postgresql, allocator);
```

### 5.3 Transaction Usage

```zig
try db.beginTransaction();
defer db.rollback();

try db.execute("INSERT INTO users ...");
try db.execute("UPDATE users ...");

try db.commit();
```

### 5.4 Migration Usage

#### 5.4.1 SQL-based Migrations (Recommended)

**Step 1**: Create a `migrations/` directory in your project and add migration files

File: `migrations/20251122_create_users_table.sql`
```sql
-- Migration: Create users table

-- up
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);

-- down
DROP TABLE IF EXISTS users;
```

File: `migrations/002_create_posts_table.sql`
```sql
-- Migration: Create posts table

-- up
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- down
DROP TABLE IF EXISTS posts;
```

**Step 2**: Load and run migrations

```zig
var manager = dig.migration.Manager.init(&db, allocator);

// Load migrations from directory
var migrations = try manager.loadFromDirectory("migrations");
defer {
    for (migrations.items) |*migration| {
        migration.deinit();
    }
    migrations.deinit();
}

// Run all pending migrations
try manager.migrate(migrations.items);

// Check migration status
try manager.status(migrations.items);

// Rollback last batch
try manager.rollback(migrations.items);

// Reset all migrations
try manager.reset(migrations.items);
```

#### 5.4.2 Standalone Migration Tool

For production environments, Dig automatically provides a standalone migration CLI tool that runs independently from the main application. This approach provides several benefits:

- **Separation of Concerns**: Migration logic is isolated from application logic
- **Deployment Flexibility**: Migrations can be run separately during deployment
- **CI/CD Integration**: Easy to integrate into automated deployment pipelines
- **Safety**: Reduces the risk of accidentally running migrations in production
- **No Maintenance**: Automatically built and updated with Dig

**Built-in Migration Tool**:

Dig's `build.zig` automatically builds a `migrate` executable with the following features:
- Commands: `up`, `down`, `reset`, `status`, `help`
- Configuration via environment variables
- Custom migration directory support (`--dir` option)
- Clear error messages and help text
- Automatically linked with enabled database drivers

**Integration Steps**:

1. Add Dig as a dependency in `build.zig.zon`
2. Install the migration tool in your `build.zig`:

```zig
const dig = b.dependency("dig", .{
    .target = target,
    .optimize = optimize,
    .postgresql = true,  // Enable required drivers
});

// Your main application
const exe = b.addExecutable(.{ /* ... */ });
exe.root_module.addImport("dig", dig.module("dig"));
b.installArtifact(exe);

// Install migration tool (automatically built by Dig)
const migrate_artifact = dig.artifact("migrate");
b.installArtifact(migrate_artifact);
```

3. Build and use:

```bash
# Build project (includes migrate tool)
zig build

# Run migrations
DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass \
  ./zig-out/bin/migrate up

# Check status
DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass \
  ./zig-out/bin/migrate status
```

The migration tool is automatically built with the same database drivers you've enabled in your Dig dependency configuration.

For complete usage instructions, environment variables, and integration patterns (Docker Compose, Makefile, CI/CD), see `examples/README.md`.

## 6. Error Handling

All database operations return error unions. Common error handling patterns:

```zig
const result = db.query(sql) catch |err| {
    switch (err) {
        error.ConnectionFailed => {
            // Handle connection error
        },
        error.QueryExecutionFailed => {
            // Handle query error
        },
        else => return err,
    }
};
```

## 7. Memory Management

- All query builders require an allocator
- Call `deinit()` on query builders when done
- SQL strings returned by `toSql()` must be freed by the caller
- QueryResult must be freed using `deinit()`

## 8. Future Enhancements

### 8.1 Completed Features

- ✅ Migration system
  - Database schema versioning
  - Up/down migration functions
  - Migration history tracking
  - Batch rollback support
  - Migration status reporting

### 8.2 Planned Features

- Prepared statements support
- Connection pooling
- Relationship definitions (foreign keys)
- JOIN support in SELECT queries
- Subquery support
- Aggregate functions
- GROUP BY and HAVING clauses

### 8.3 Database Driver Implementation

✅ **Completed**:
- C library bindings for libpq (PostgreSQL) - `libs/libpq.zig`
- C library bindings for libmysqlclient (MySQL) - `libs/libmysql.zig`
- Result set parsing for both databases
- Error message extraction from database
- Full transaction support

🔄 **In Progress**:
- Parameter binding for prepared statements
- Connection pooling
- Advanced type conversions

**Implementation Details**:

Each driver consists of two main components:

1. **C Library Bindings** (`libs/`):
   - Low-level FFI to C library functions
   - Type definitions matching C structures
   - Function wrappers for safety

2. **Driver Implementation** (`drivers/`):
   - High-level Zig interface
   - Connection management
   - Query execution and result parsing
   - Type conversion logic
   - Error handling

## 9. Performance Considerations

- Query builders use ArrayList for dynamic allocation
- SQL string generation is efficient but requires memory allocation
- Consider using ArenaAllocator for batch operations
- Connection pooling (future feature) will improve performance

## 10. Security Considerations

- SQL injection prevention through parameterized queries (future)
- Connection string should not be logged
- Password should be stored securely
- SSL support for encrypted connections

## 11. Testing

Test files should be placed in `src/tests/` directory with `_test.zig` suffix.

Example test structure (in `src/tests/query_test.zig`):

```zig
test "SelectQuery: basic select" {
    const allocator = std.testing.allocator;
    var query = try dig.query.SelectQuery.init(allocator, "users");
    defer query.deinit();

    const sql = try query.select(&[_][]const u8{"id"}).toSql(.postgresql);
    defer allocator.free(sql);

    try std.testing.expect(std.mem.eql(u8, sql, "SELECT id FROM users"));
}
```

## 12. Version History

- **0.1.0** - Migration system implementation (Current)
  - ✅ Complete migration system
  - ✅ Migration manager with up/down functions
  - ✅ Migration history tracking in `_dig_migrations` table
  - ✅ Batch-based rollback support
  - ✅ Migration status reporting
  - ✅ Idempotent migration execution
  - ✅ Full test coverage for migrations

- **0.0.2** - Database driver implementation
  - ✅ Complete PostgreSQL driver implementation
  - ✅ Complete MySQL driver implementation
  - ✅ libpq C API bindings
  - ✅ libmysqlclient C API bindings
  - ✅ Query result parsing
  - ✅ Full transaction support
  - ✅ Type conversion system

- **0.0.1** - Initial implementation
  - Basic query builders (SELECT, INSERT, UPDATE, DELETE)
  - Schema definition system
  - PostgreSQL and MySQL driver placeholders
  - Transaction support interface

