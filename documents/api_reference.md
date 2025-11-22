# Dig ORM API Reference

## Table of Contents

1. [Connection Management](#connection-management)
2. [Schema Definition](#schema-definition)
3. [Query Builders](#query-builders)
4. [Migration System](#migration-system)
5. [Type Definitions](#type-definitions)
6. [Error Handling](#error-handling)

## Connection Management

### Database Drivers

Dig supports multiple database drivers that must be explicitly enabled at build time:

- **PostgreSQL** (libpq): Disabled by default, enable with `-Dpostgresql=true`
- **MySQL** (libmysqlclient): Disabled by default, enable with `-Dmysql=true`

**Important**: Both drivers are disabled by default to avoid requiring database client libraries during build. You must explicitly enable the drivers you need.

If a disabled driver is used at runtime, the `connect()` function will return `UnsupportedDatabase` error with a message indicating which build flag is needed.

### Database

Main database interface for connection and query execution.

#### Functions

##### `connect`

```zig
pub fn connect(allocator: std.mem.Allocator, config: ConnectionConfig) !Database
```

Creates a new database connection.

**Parameters**:
- `allocator`: Memory allocator to use
- `config`: Connection configuration

**Returns**: `Database` instance on success

**Errors**: `ConnectionFailed`, `InvalidConnectionString`

**Example**:
```zig
const config = ConnectionConfig{
    .database_type = .postgresql,
    .host = "localhost",
    .port = 5432,
    .database = "mydb",
    .username = "user",
    .password = "pass",
};
var db = try Database.connect(allocator, config);
```

##### `disconnect`

```zig
pub fn disconnect(self: *Database) void
```

Closes the database connection.

**Example**:
```zig
db.disconnect();
```

##### `execute`

```zig
pub fn execute(self: *Database, sql_query: []const u8) !void
```

Executes a SQL query without returning results.

**Parameters**:
- `sql_query`: SQL query string

**Errors**: `QueryExecutionFailed`, `ConnectionFailed`

**Example**:
```zig
try db.execute("INSERT INTO users (name) VALUES ('John')");
```

##### `query`

```zig
pub fn query(self: *Database, sql_query: []const u8) !Connection.QueryResult
```

Executes a SQL query and returns results.

**Parameters**:
- `sql_query`: SQL query string

**Returns**: `QueryResult` containing columns and rows

**Errors**: `QueryExecutionFailed`, `ConnectionFailed`

**Example**:
```zig
const result = try db.query("SELECT id, name FROM users");
defer result.deinit();
```

### QueryResult

Result structure containing query execution results.

#### Fields

- `columns: []const []const u8` - Array of column names
- `rows: []const Row` - Array of result rows
- `allocator: std.mem.Allocator` - Allocator used for memory management

#### Functions

##### `getColumnIndex`

```zig
pub fn getColumnIndex(self: QueryResult, column_name: []const u8) ?usize
```

Gets the index of a column by name.

**Parameters**:
- `column_name`: Name of the column to find

**Returns**: Column index or `null` if not found

**Example**:
```zig
const idx = result.getColumnIndex("id");
if (idx) |i| {
    std.debug.print("Column 'id' is at index {d}\n", .{i});
}
```

##### `deinit`

```zig
pub fn deinit(self: *QueryResult) void
```

Frees all resources associated with the query result.

**Example**:
```zig
var result = try db.query("SELECT * FROM users");
defer result.deinit();
```

### Row

Represents a single row in a query result.

#### Fields

- `values: []const SqlValue` - Array of values in the row
- `columns: []const []const u8` - Reference to column names

#### Functions

##### `get`

```zig
pub fn get(self: Row, column_name: []const u8) ?SqlValue
```

Gets a value by column name.

**Parameters**:
- `column_name`: Name of the column

**Returns**: `SqlValue` or `null` if column not found

**Example**:
```zig
var result = try db.query("SELECT id, name, age FROM users");
defer result.deinit();

for (result.rows) |row| {
    // Column name-based access
    const id = row.get("id").?.integer;
    const name = row.get("name").?.text;
    const age = row.get("age").?.integer;

    // Index-based access (also supported)
    const id_alt = row.values[0].integer;
    const name_alt = row.values[1].text;
    const age_alt = row.values[2].integer;
}
```

**Note**: The `get()` method returns `?SqlValue`, so you should check for `null` before accessing the value. If you're certain the column exists, you can use `.?` to unwrap it.

##### `beginTransaction`

```zig
pub fn beginTransaction(self: *Database) !void
```

Starts a database transaction.

**Errors**: `TransactionFailed`, `ConnectionFailed`

**Example**:
```zig
try db.beginTransaction();
```

##### `commit`

```zig
pub fn commit(self: *Database) !void
```

Commits the current transaction.

**Errors**: `TransactionFailed`, `ConnectionFailed`

**Example**:
```zig
try db.commit();
```

##### `rollback`

```zig
pub fn rollback(self: *Database) !void
```

Rolls back the current transaction.

**Errors**: `TransactionFailed`, `ConnectionFailed`

**Example**:
```zig
try db.rollback();
```

## Schema Definition

### Table

Table definition structure for creating database tables.

#### Functions

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator, name: []const u8) Table
```

Creates a new table definition.

**Parameters**:
- `allocator`: Memory allocator
- `name`: Table name

**Returns**: `Table` instance

**Example**:
```zig
var table = Table.init(allocator, "users");
```

##### `addColumn`

```zig
pub fn addColumn(self: *Table, column: Column) !void
```

Adds a column to the table.

**Parameters**:
- `column`: Column definition

**Errors**: `OutOfMemory`

**Example**:
```zig
try table.addColumn(.{
    .name = "id",
    .type = .bigint,
    .primary_key = true,
    .auto_increment = true,
});
```

##### `toCreateTableSql`

```zig
pub fn toCreateTableSql(self: Table, db_type: DatabaseType, allocator: std.mem.Allocator) ![]const u8
```

Generates CREATE TABLE SQL statement.

**Parameters**:
- `db_type`: Target database type
- `allocator`: Memory allocator for SQL string

**Returns**: SQL string (must be freed by caller)

**Errors**: `OutOfMemory`

**Example**:
```zig
const sql = try table.toCreateTableSql(.postgresql, allocator);
defer allocator.free(sql);
```

##### `deinit`

```zig
pub fn deinit(self: *Table) void
```

Frees table resources.

**Example**:
```zig
table.deinit();
```

### Column

Column definition structure.

#### Fields

- `name: []const u8` - Column name
- `type: ColumnType` - Column type
- `nullable: bool = false` - Whether column allows NULL
- `primary_key: bool = false` - Whether column is primary key
- `auto_increment: bool = false` - Whether column auto-increments
- `unique: bool = false` - Whether column is unique
- `default_value: ?[]const u8 = null` - Default value
- `length: ?usize = null` - Length for VARCHAR columns

## Query Builders

### SelectQuery

Query builder for SELECT statements.

#### Functions

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !SelectQuery
```

Creates a new SELECT query builder.

**Parameters**:
- `allocator`: Memory allocator
- `table`: Table name

**Returns**: `SelectQuery` instance

**Example**:
```zig
var query = try SelectQuery.init(allocator, "users");
```

##### `select`

```zig
pub fn select(self: *SelectQuery, columns: []const []const u8) *SelectQuery
```

Specifies columns to select.

**Parameters**:
- `columns`: Array of column names

**Returns**: Self for method chaining

**Example**:
```zig
query.select(&[_][]const u8{"id", "name", "email"});
```

##### `where`

```zig
pub fn where(self: *SelectQuery, column: []const u8, operator: []const u8, value: SqlValue) !*SelectQuery
```

Adds a WHERE clause.

**Parameters**:
- `column`: Column name
- `operator`: Comparison operator (e.g., "=", ">", "<", "LIKE")
- `value`: Value to compare

**Returns**: Self for method chaining

**Errors**: `OutOfMemory`

**Example**:
```zig
try query.where("age", ">", .{ .integer = 18 });
```

##### `orderBy`

```zig
pub fn orderBy(self: *SelectQuery, column: []const u8, direction: Direction) *SelectQuery
```

Adds ORDER BY clause.

**Parameters**:
- `column`: Column name
- `direction`: Sort direction (.asc or .desc)

**Returns**: Self for method chaining

**Example**:
```zig
query.orderBy("name", .asc);
```

##### `limit`

```zig
pub fn limit(self: *SelectQuery, count: usize) *SelectQuery
```

Adds LIMIT clause.

**Parameters**:
- `count`: Maximum number of rows

**Returns**: Self for method chaining

**Example**:
```zig
query.limit(10);
```

##### `offset`

```zig
pub fn offset(self: *SelectQuery, count: usize) *SelectQuery
```

Adds OFFSET clause.

**Parameters**:
- `count`: Number of rows to skip

**Returns**: Self for method chaining

**Example**:
```zig
query.offset(20);
```

##### `toSql`

```zig
pub fn toSql(self: *SelectQuery, db_type: DatabaseType) ![]const u8
```

Generates SQL string.

**Parameters**:
- `db_type`: Target database type

**Returns**: SQL string (must be freed by caller)

**Errors**: `OutOfMemory`

**Example**:
```zig
const sql = try query.toSql(.postgresql);
defer allocator.free(sql);
```

##### `deinit`

```zig
pub fn deinit(self: *SelectQuery) void
```

Frees query builder resources.

**Example**:
```zig
query.deinit();
```

### InsertQuery

Query builder for INSERT statements.

#### Functions

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !InsertQuery
```

Creates a new INSERT query builder.

**Example**:
```zig
var query = try InsertQuery.init(allocator, "users");
```

##### `addValue`

```zig
pub fn addValue(self: *InsertQuery, column: []const u8, value: SqlValue) !*InsertQuery
```

Adds a value to insert.

**Parameters**:
- `column`: Column name
- `value`: Value to insert

**Returns**: Self for method chaining

**Errors**: `OutOfMemory`

**Example**:
```zig
try query.addValue("name", .{ .text = "John Doe" });
```

##### `setValues`

```zig
pub fn setValues(self: *InsertQuery, values: std.StringHashMap(SqlValue)) !*InsertQuery
```

Sets multiple values from a hash map.

**Parameters**:
- `values`: Hash map of column names to values

**Returns**: Self for method chaining

**Errors**: `OutOfMemory`

**Example**:
```zig
var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{ .text = "John Doe" });
try values.put("email", .{ .text = "john@example.com" });
try values.put("age", .{ .integer = 30 });

try query.setValues(values);
```

##### `toSql`

```zig
pub fn toSql(self: *InsertQuery, db_type: DatabaseType) ![]const u8
```

Generates SQL string.

**Example**:
```zig
const sql = try query.toSql(.postgresql);
```

##### `deinit`

```zig
pub fn deinit(self: *InsertQuery) void
```

Frees query builder resources.

### UpdateQuery

Query builder for UPDATE statements.

#### Functions

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !UpdateQuery
```

Creates a new UPDATE query builder.

##### `set`

```zig
pub fn set(self: *UpdateQuery, column: []const u8, value: SqlValue) !*UpdateQuery
```

Sets a column value.

**Parameters**:
- `column`: Column name
- `value`: New value

**Returns**: Self for method chaining

**Errors**: `OutOfMemory`

**Example**:
```zig
try query.set("age", .{ .integer = 31 });
```

##### `setMultiple`

```zig
pub fn setMultiple(self: *UpdateQuery, values: std.StringHashMap(SqlValue)) !*UpdateQuery
```

Sets multiple columns from a hash map.

**Parameters**:
- `values`: Hash map of column names to values

**Returns**: Self for method chaining

**Errors**: `OutOfMemory`

**Example**:
```zig
var values = std.StringHashMap(dig.types.SqlValue).init(allocator);
defer values.deinit();

try values.put("name", .{ .text = "Jane Doe" });
try values.put("age", .{ .integer = 31 });
try values.put("active", .{ .boolean = true });

try query.setMultiple(values);
```

##### `where`

```zig
pub fn where(self: *UpdateQuery, column: []const u8, operator: []const u8, value: SqlValue) !*UpdateQuery
```

Adds a WHERE clause.

**Example**:
```zig
try query.where("id", "=", .{ .integer = 1 });
```

##### `toSql`

```zig
pub fn toSql(self: *UpdateQuery, db_type: DatabaseType) ![]const u8
```

Generates SQL string.

##### `deinit`

```zig
pub fn deinit(self: *UpdateQuery) void
```

Frees query builder resources.

### DeleteQuery

Query builder for DELETE statements.

#### Functions

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator, table: []const u8) !DeleteQuery
```

Creates a new DELETE query builder.

##### `where`

```zig
pub fn where(self: *DeleteQuery, column: []const u8, operator: []const u8, value: SqlValue) !*DeleteQuery
```

Adds a WHERE clause.

**Example**:
```zig
try query.where("id", "=", .{ .integer = 1 });
```

##### `toSql`

```zig
pub fn toSql(self: *DeleteQuery, db_type: DatabaseType) ![]const u8
```

Generates SQL string.

##### `deinit`

```zig
pub fn deinit(self: *DeleteQuery) void
```

Frees query builder resources.

## Migration System

Dig provides a SQL-based migration system using SQL files with `-- up` and `-- down` sections.

### Manager

Migration manager for database schema versioning.

#### Functions

##### `init`

```zig
pub fn init(db: *Db, allocator: std.mem.Allocator) Manager
```

Creates a new migration manager.

**Parameters**:
- `db`: Database connection
- `allocator`: Memory allocator

**Returns**: `Manager` instance

**Example**:
```zig
var manager = dig.migration.Manager.init(&db, allocator);
```

##### `ensureMigrationsTable`

```zig
pub fn ensureMigrationsTable(self: *Manager) !void
```

Creates the migrations history table if it doesn't exist.

**Errors**: `QueryExecutionFailed`

**Example**:
```zig
try manager.ensureMigrationsTable();
```

##### `loadFromDirectory`

```zig
pub fn loadFromDirectory(self: *Manager, dir_path: []const u8) !std.ArrayList(SqlMigration)
```

Loads SQL migrations from a directory.

**Parameters**:
- `dir_path`: Path to directory containing migration files

**Returns**: ArrayList of SqlMigration (caller must free each migration and the list)

**Errors**: `OutOfMemory`, file system errors

**Example**:
```zig
var migrations = try manager.loadFromDirectory("migrations");
defer {
    for (migrations.items) |*migration| {
        migration.deinit();
    }
    migrations.deinit();
}
```

##### `migrate`

```zig
pub fn migrate(self: *Manager, migrations: []const SqlMigration) !void
```

Runs all pending migrations.

**Parameters**:
- `migrations`: Array of SQL migration definitions

**Errors**: `QueryExecutionFailed`

**Example**:
```zig
var migrations = try manager.loadFromDirectory("migrations");
defer {
    for (migrations.items) |*migration| {
        migration.deinit();
    }
    migrations.deinit();
}

try manager.migrate(migrations.items);
```

##### `rollback`

```zig
pub fn rollback(self: *Manager, migrations: []const SqlMigration) !void
```

Rolls back the last batch of migrations.

**Parameters**:
- `migrations`: Array of SQL migration definitions

**Errors**: `QueryExecutionFailed`

**Example**:
```zig
try manager.rollback(migrations.items);
```

##### `reset`

```zig
pub fn reset(self: *Manager, migrations: []const SqlMigration) !void
```

Rolls back all migrations.

**Parameters**:
- `migrations`: Array of SQL migration definitions

**Errors**: `QueryExecutionFailed`

**Example**:
```zig
try manager.reset(migrations.items);
```

##### `status`

```zig
pub fn status(self: *Manager, migrations: []const SqlMigration) !void
```

Prints the status of all migrations (applied or pending).

**Parameters**:
- `migrations`: Array of SQL migration definitions

**Errors**: `QueryExecutionFailed`

**Example**:
```zig
try manager.status(migrations.items);
```

### SqlMigration

SQL-based migration definition loaded from a file.

#### Fields

- `id: []const u8` - Migration identifier (extracted from filename)
- `name: []const u8` - Migration name (extracted from filename)
- `up_sql: []const u8` - SQL statements for migration
- `down_sql: []const u8` - SQL statements for rollback
- `allocator: std.mem.Allocator` - Allocator used for memory management

#### Functions

##### `initFromFile`

```zig
pub fn initFromFile(allocator: std.mem.Allocator, file_path: []const u8, content: []const u8) !SqlMigration
```

Creates a SqlMigration from file path and content.

**Parameters**:
- `allocator`: Memory allocator
- `file_path`: Path to the migration file
- `content`: File content

**Returns**: `SqlMigration` instance

**Errors**: `OutOfMemory`

**File Format**:
```sql
-- Migration: Create users table

-- up
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

-- down
DROP TABLE IF EXISTS users;
```

**Filename Format**: `20251122_create_users_table.sql`
- ID format: `YYYYMMDD` (e.g., `20251122` for November 22, 2025)
- The part before the first underscore becomes the migration ID
- The part after is converted to a name (underscores replaced with spaces)

**Example**:
```zig
const content = try std.fs.cwd().readFileAlloc(allocator, "20251122_create_users.sql", 1024 * 1024);
defer allocator.free(content);

var migration = try dig.migration.SqlMigration.initFromFile(
    allocator,
    "20251122_create_users.sql",
    content,
);
defer migration.deinit();
```

##### `deinit`

```zig
pub fn deinit(self: *SqlMigration) void
```

Frees all allocated memory.

**Example**:
```zig
migration.deinit();
```

##### `executeUp`

```zig
pub fn executeUp(self: *const SqlMigration, db: *Db) !void
```

Executes the up migration SQL.

**Parameters**:
- `db`: Database connection

**Errors**: `QueryExecutionFailed`

##### `executeDown`

```zig
pub fn executeDown(self: *const SqlMigration, db: *Db) !void
```

Executes the down migration SQL.

**Parameters**:
- `db`: Database connection

**Errors**: `QueryExecutionFailed`

### MigrationRecord

Record of an applied migration stored in the database.

#### Fields

- `id: []const u8` - Migration identifier
- `name: []const u8` - Migration name
- `applied_at: i64` - Unix timestamp when migration was applied
- `batch: i32` - Batch number for grouping migrations

## Type Definitions

### DatabaseType

```zig
pub const DatabaseType = enum {
    postgresql,
    mysql,
};
```

Enumeration of supported database types.

### SqlValue

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

Union type representing SQL values.

**Example**:
```zig
const value: SqlValue = .{ .integer = 42 };
const text_value: SqlValue = .{ .text = "Hello" };
const null_value: SqlValue = .null;
```

### ConnectionConfig

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

Database connection configuration.

### ColumnType

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

Supported column types.

## Error Handling

### DigError

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

Error types for database operations.

### Error Handling Example

```zig
const result = db.query(sql) catch |err| {
    switch (err) {
        error.ConnectionFailed => {
            std.debug.print("Connection failed\n", .{});
            return;
        },
        error.QueryExecutionFailed => {
            std.debug.print("Query failed\n", .{});
            return;
        },
        else => return err,
    }
};
```

