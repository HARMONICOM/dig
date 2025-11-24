## API Reference (High-Level)

This document provides a high-level summary of Dig's main types, functions, and components.
For detailed usage examples, see the respective documentation pages.

---

## 1. Core Types

### 1.1 Db

Main database interface for connection and query execution.

**Module**: `dig.db` (imported from `@import("dig")`)

```zig
pub const Db = struct {
    allocator: std.mem.Allocator,
    db_type: DatabaseType,
    conn: Connection,
    conn_state: *anyopaque,
};
```

**Key Methods**:
- `connect(allocator, config)` - Connect to database
- `disconnect()` - Close connection
- `execute(sql)` - Execute SQL without returning results
- `query(sql)` - Execute SQL and return results
- `table(table_name)` - Start a chainable query builder for a table
- `beginTransaction()` - Start transaction
- `commit()` - Commit transaction
- `rollback()` - Roll back transaction

**See**: [`getting-started.md`](./getting-started.md), [`query-builders.md`](./query-builders.md)

---

### 1.2 ConnectionConfig

Database connection configuration.

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

**Example**:
```zig
const config = dig.types.ConnectionConfig{
    .database_type = .postgresql,
    .host = "localhost",
    .port = 5432,
    .database = "mydb",
    .username = "user",
    .password = "pass",
};
```

**See**: [`getting-started.md`](./getting-started.md), [`database-drivers.md`](./database-drivers.md)

---

### 1.3 SqlValue

Tagged union for type-safe SQL values.

```zig
pub const SqlValue = union(enum) {
    null,
    integer: i64,
    float: f64,
    text: []const u8,
    boolean: bool,
    blob: []const u8,
    timestamp: i64,
};
```

**Example**:
```zig
const id: SqlValue = .{ .integer = 42 };
const name: SqlValue = .{ .text = "John Doe" };
const active: SqlValue = .{ .boolean = true };
```

**See**: [`query-builders.md`](./query-builders.md)

---

### 1.4 DatabaseType

Enumeration of supported database types.

```zig
pub const DatabaseType = enum {
    postgresql,
    mysql,
    mock, // Mock driver for testing
};
```

**See**: [`database-drivers.md`](./database-drivers.md)

---

## 2. Schema Definition

### 2.1 Table

Table definition structure.

**Module**: `dig.schema`

```zig
pub const Table = struct {
    name: []const u8,
    columns: []const Column,
    allocator: std.mem.Allocator,
};
```

**Key Methods**:
- `init(allocator, name)` - Create new table definition
- `addColumn(column)` - Add column to table
- `toCreateTableSql(db_type, allocator)` - Generate CREATE TABLE SQL
- `deinit()` - Free resources

**See**: [`schema.md`](./schema.md)

---

### 2.2 Column

Column definition structure.

```zig
pub const Column = struct {
    name: []const u8,
    type: ColumnType,
    nullable: bool = false,
    primary_key: bool = false,
    auto_increment: bool = false,
    unique: bool = false,
    default_value: ?[]const u8 = null,
    length: ?usize = null,
};
```

**See**: [`schema.md`](./schema.md)

---

### 2.3 ColumnType

Supported column types.

```zig
pub const ColumnType = enum {
    integer,
    bigint,
    text,
    varchar,
    boolean,
    float,
    double,
    timestamp,
    blob,
    json,
};
```

**See**: [`schema.md`](./schema.md), [`database-drivers.md`](./database-drivers.md)

---

## 3. Query Builders

### 3.1 Select

SELECT query builder.

**Module**: `dig.query`

**Note**: `SelectQuery` is available as an alias for backward compatibility.

```zig
pub const Select = struct {
    table: []const u8,
    columns: []const []const u8,
    joins: std.ArrayList(JoinClause),
    where_clauses: std.ArrayList(WhereClause),
    order_by: ?OrderBy,
    limit_value: ?usize,
    offset_value: ?usize,
    allocator: std.mem.Allocator,
};
```

**Key Methods**:
- `init(allocator, table)` - Create SELECT query
- `select(columns)` - Specify columns to select
- `join(table, left_column, right_column)` - Add INNER JOIN
- `leftJoin(table, left_column, right_column)` - Add LEFT JOIN
- `rightJoin(table, left_column, right_column)` - Add RIGHT JOIN
- `fullJoin(table, left_column, right_column)` - Add FULL OUTER JOIN
- `where(column, operator, value)` - Add WHERE clause
- `orderBy(column, direction)` - Add ORDER BY
- `limit(count)` - Add LIMIT
- `offset(count)` - Add OFFSET
- `toSql(db_type)` - Generate SQL string
- `deinit()` - Free resources

**See**: [`query-builders.md`](./query-builders.md)

---

### 3.2 Insert

INSERT query builder.

**Module**: `dig.query`

**Note**: `InsertQuery` is available as an alias for backward compatibility.

```zig
pub const Insert = struct {
    table: []const u8,
    values: std.ArrayList(ValuePair),
    allocator: std.mem.Allocator,
};
```

**Key Methods**:
- `init(allocator, table)` - Create INSERT query
- `addValue(column, value)` - Add value to insert
- `setValues(hash_map)` - Set multiple values from hash map
- `toSql(db_type)` - Generate SQL string
- `deinit()` - Free resources

**See**: [`query-builders.md`](./query-builders.md)

---

### 3.3 Update

UPDATE query builder.

**Module**: `dig.query`

**Note**: `UpdateQuery` is available as an alias for backward compatibility.

```zig
pub const Update = struct {
    table: []const u8,
    set_clauses: std.ArrayList(SetClause),
    where_clauses: std.ArrayList(WhereClause),
    allocator: std.mem.Allocator,
};
```

**Key Methods**:
- `init(allocator, table)` - Create UPDATE query
- `set(column, value)` - Set column value
- `setMultiple(hash_map)` - Set multiple columns from hash map
- `where(column, operator, value)` - Add WHERE clause
- `toSql(db_type)` - Generate SQL string
- `deinit()` - Free resources

**See**: [`query-builders.md`](./query-builders.md)

---

### 3.4 Delete

DELETE query builder.

**Module**: `dig.query`

**Note**: `DeleteQuery` is available as an alias for backward compatibility.

```zig
pub const Delete = struct {
    allocator: std.mem.Allocator,
    table: []const u8,
    where_clauses: std.ArrayList(WhereClause),
};
```

**Key Methods**:
- `init(allocator, table)` - Create DELETE query
- `where(column, operator, value)` - Add WHERE clause
- `toSql(db_type)` - Generate SQL string
- `deinit()` - Free resources

**See**: [`query-builders.md`](./query-builders.md)

---

## 4. Query Results

### 4.1 QueryResult

Result structure from query execution.

**Module**: `dig.connection` (as `Connection.QueryResult`)

```zig
pub const QueryResult = struct {
    columns: []const []const u8,
    rows: []const Row,
    allocator: std.mem.Allocator,
};
```

**Key Methods**:
- `getColumnIndex(column_name)` - Get column index by name
- `deinit()` - Free resources

**See**: [`query-builders.md`](./query-builders.md)

---

### 4.2 Row

Single row in query result.

```zig
pub const Row = struct {
    values: []const SqlValue,
    columns: []const []const u8,
};
```

**Key Methods**:
- `get(column_name)` - Get value by column name (returns `?SqlValue`)

**Example**:
```zig
for (result.rows) |row| {
    const id = row.get("id").?.integer;
    const name = row.get("name").?.text;
    // ...
}
```

**See**: [`query-builders.md`](./query-builders.md)

---

## 5. Migration System

### 5.1 Manager

Migration manager for schema versioning.

**Module**: `dig.migration`

```zig
pub const Manager = struct {
    db: *Db,
    allocator: std.mem.Allocator,
    migrations_table: []const u8,
};
```

**Key Methods**:
- `init(db, allocator)` - Create migration manager
- `ensureMigrationsTable()` - Create migrations history table
- `loadFromDirectory(dir_path)` - Load SQL migrations from directory
- `migrate(migrations)` - Run pending migrations
- `rollback(migrations)` - Roll back last batch
- `reset(migrations)` - Roll back all migrations
- `status(migrations)` - Show migration status

**See**: [`migrations.md`](./migrations.md)

---

### 5.2 SqlMigration

SQL-based migration loaded from file.

```zig
pub const SqlMigration = struct {
    id: []const u8,
    name: []const u8,
    up_sql: []const u8,
    down_sql: []const u8,
    allocator: std.mem.Allocator,
};
```

**Key Methods**:
- `initFromFile(allocator, file_path, content)` - Load from file
- `deinit()` - Free resources
- `executeUp(db)` - Execute up migration
- `executeDown(db)` - Execute down migration

**File Format**:
```sql
-- up
CREATE TABLE users (...);

-- down
DROP TABLE IF EXISTS users;
```

**See**: [`migrations.md`](./migrations.md)

---

### 5.3 MigrationRecord

Record of applied migration in database.

```zig
pub const MigrationRecord = struct {
    id: []const u8,
    name: []const u8,
    applied_at: i64,
    batch: i32,
};
```

**See**: [`migrations.md`](./migrations.md)

---

## 6. Error Types

### 6.1 DigError

Error types for database operations.

**Module**: `dig.errors`

```zig
pub const DigError = error{
    ConnectionFailed,
    QueryExecutionFailed,
    InvalidQuery,
    InvalidSchema,
    TypeMismatch,
    NotFound,
    TransactionFailed,
    InvalidConnectionString,
    UnsupportedDatabase,
    InvalidParameter,
    OutOfMemory,
};
```

**Common Errors**:
- `ConnectionFailed` - Database connection failed
- `QueryExecutionFailed` - Query execution failed
- `UnsupportedDatabase` - Database driver not enabled (rebuild with driver flag)
- `TransactionFailed` - Transaction operation failed

**See**: [`getting-started.md`](./getting-started.md), [`database-drivers.md`](./database-drivers.md)

---

## 7. Standalone Tools

### 7.1 migrate (CLI Tool)

Standalone migration CLI tool automatically built by Dig.

**Installation**: Add to `build.zig`:

```zig
const migrate_artifact = dig.artifact("migrate");
b.installArtifact(migrate_artifact);
```

**Commands**:
- `migrate up` - Run pending migrations
- `migrate down` - Roll back last batch
- `migrate reset` - Roll back all migrations
- `migrate status` - Show migration status
- `migrate help` - Show help

**Configuration**: Via environment variables:
- `DB_TYPE` - Database type (postgresql/mysql)
- `DB_HOST` - Host (default: localhost)
- `DB_PORT` - Port (default: 5432/3306)
- `DB_DATABASE` - Database name
- `DB_USERNAME` - Username
- `DB_PASSWORD` - Password

**Options**:
- `--dir=<path>` - Custom migration directory (default: database/migrations/)

**See**: [`migrations.md`](./migrations.md)

---

## 8. Build Configuration

### 8.1 Build Options

Conditional compilation flags for database drivers.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-Dpostgresql` | `bool` | `false` | Enable PostgreSQL driver |
| `-Dmysql` | `bool` | `false` | Enable MySQL driver |

**Command Line**:
```bash
zig build -Dpostgresql=true
zig build -Dmysql=true
```

**build.zig**:
```zig
const dig = b.dependency("dig", .{
    .target = target,
    .optimize = optimize,
    .postgresql = true,
    .mysql = true,
});
```

**See**: [`database-drivers.md`](./database-drivers.md)

---

## 9. Quick Reference

### 9.1 Connecting to Database

```zig
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
```

### 9.2 Creating a Table

```zig
var table = dig.schema.Table.init(allocator, "users");
defer table.deinit();

try table.addColumn(.{
    .name = "id",
    .type = .bigint,
    .primary_key = true,
    .auto_increment = true,
});

const sql = try table.toCreateTableSql(.postgresql, allocator);
defer allocator.free(sql);

try db.execute(sql);
```

### 9.3 Building a SELECT Query

```zig
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{"id", "name"})
    .where("age", ">", .{ .integer = 18 }))
    .toSql(.postgresql);
defer allocator.free(sql);

var result = try db.query(sql);
defer result.deinit();
```

### 9.4 Inserting Data

```zig
var query = try dig.query.Insert.init(allocator, "users");
defer query.deinit();

var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{ .text = "Alice" });
try values.put("age", .{ .integer = 30 });

const sql = try (try query.setValues(values)).toSql(.postgresql);
defer allocator.free(sql);

try db.execute(sql);
```

### 9.5 Running Migrations

Use the standalone CLI tool:

```bash
DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass \
  ./zig-out/bin/migrate up
```

---

## 10. See Also

- **Getting Started**: [`getting-started.md`](./getting-started.md)
- **Schema Definition**: [`schema.md`](./schema.md)
- **Query Builders**: [`query-builders.md`](./query-builders.md)
- **Migrations**: [`migrations.md`](./migrations.md)
- **Database Drivers**: [`database-drivers.md`](./database-drivers.md)
- **Architecture**: [`architecture.md`](./architecture.md)

