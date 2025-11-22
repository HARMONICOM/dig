# Dig ORM Architecture Document

## 1. System Architecture

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Application Code                      │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                    Dig ORM API                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ Schema   │  │  Query   │  │   DB     │            │
│  │ Builder  │  │  Builder │  │ Interface│            │
│  └──────────┘  └──────────┘  └──────────┘            │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Connection Abstraction Layer                 │
│              (VTable-based interface)                    │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        ▼                              ▼
┌──────────────┐              ┌──────────────┐
│ PostgreSQL   │              │    MySQL     │
│   Driver     │              │    Driver    │
└──────┬───────┘              └──────┬───────┘
       │                             │
       ▼                             ▼
┌──────────────┐              ┌──────────────┐
│   libpq       │              │ libmysqlclient│
│  (C Library)  │              │  (C Library)  │
└───────────────┘              └───────────────┘
```

### 1.2 Component Interaction

1. **Application Layer**: Uses Dig ORM API to build queries and manage database connections
2. **API Layer**: Provides high-level interfaces for schema definition and query building
3. **Abstraction Layer**: Defines common interface for database operations
4. **Driver Layer**: Implements database-specific operations (conditionally compiled)
5. **C Library Layer**: Provides actual database connectivity (conditionally linked)

### 1.3 Conditional Compilation

Dig uses conditional compilation of database drivers to minimize build dependencies:

- **Build Time**: Drivers are **disabled by default** and must be explicitly enabled using `-Dpostgresql=true` and `-Dmysql=true` flags
- **Link Time**: Only enabled drivers' C libraries are linked
- **Runtime**: Attempting to use a disabled driver returns `UnsupportedDatabase` error with a helpful message

This opt-in architecture allows applications to include only the drivers they need, providing:
- **Zero build dependencies by default** (no database client libraries required unless explicitly enabled)
- **Smaller binary size** (unused driver code is not compiled)
- **Faster build times** (fewer libraries to link)
- **Explicit dependency declaration** (developers clearly specify which databases they use)

### 1.4 Project Structure

The project follows the structure defined in AGENTS.md:

```
.
├── src/
│   ├── dig.zig              # Module base file
│   ├── dig/                 # Module files directory
│   │   ├── connection.zig   # Connection abstraction
│   │   ├── db.zig           # Database interface
│   │   ├── drivers/         # Database drivers
│   │   │   ├── mysql.zig        # MySQL driver implementation
│   │   │   └── postgresql.zig   # PostgreSQL driver implementation
│   │   ├── errors.zig       # Error definitions
│   │   ├── libs/            # C library bindings
│   │   │   ├── libmysql.zig     # MySQL C API bindings
│   │   │   └── libpq.zig        # PostgreSQL C API bindings
│   │   ├── query.zig        # Query builders
│   │   ├── schema.zig       # Schema definition
│   │   └── types.zig        # Core type definitions
│   └── tests/               # Test files
│       ├── connection_test.zig
│       ├── errors_test.zig
│       ├── integration_test.zig
│       ├── query_test.zig
│       ├── schema_test.zig
│       └── types_test.zig
├── documents/              # Documentation
│   ├── api_reference.md
│   ├── architecture.md
│   └── specification.md
└── build.zig               # Build configuration
```

## 2. Design Patterns

### 2.1 VTable Pattern

The connection abstraction uses a VTable pattern to allow different database drivers to implement the same interface:

```zig
pub const Connection = struct {
    vtable: *const VTable,
    state: *anyopaque,

    pub const VTable = struct {
        connect: *const fn(...),
        disconnect: *const fn(...),
        execute: *const fn(...),
        query: *const fn(...),
        // ...
    };
};
```

**Benefits**:
- Type-safe polymorphism
- No runtime overhead (function pointers)
- Easy to add new database drivers

### 2.2 Builder Pattern

Query builders use the builder pattern for fluent API:

```zig
var query = try dig.query.Select.init(allocator, "users");
const sql = try query
    .select(&[_][]const u8{"id", "name"})
    .where("age", ">", .{ .integer = 18 })
    .orderBy("name", .asc)
    .toSql(.postgresql);
```

**Benefits**:
- Intuitive API
- Method chaining
- Progressive query building

### 2.3 Error Handling Pattern

All operations return error unions:

```zig
pub fn connect(...) !Database
pub fn execute(...) !void
pub fn query(...) !QueryResult
```

**Benefits**:
- Explicit error handling
- Compile-time error checking
- No exceptions

## 3. Memory Management

### 3.1 Allocation Strategy

- **Query Builders**: Use provided allocator for internal structures
- **SQL Generation**: Allocates strings that must be freed by caller
- **Query Results**: Owned by QueryResult structure, freed via deinit()

### 3.2 Ownership Rules

1. **Query Builders**: Owned by caller, must call `deinit()`
2. **SQL Strings**: Owned by caller after `toSql()` returns
3. **Query Results**: Owned by QueryResult, freed via `deinit()`
4. **Connection**: Owned by Database struct, freed via `disconnect()`

### 3.3 Example Memory Flow

```zig
// 1. Allocate query builder
var query = try dig.query.Select.init(allocator, "users");
defer query.deinit(); // Free query builder

// 2. Build query (allocates internal structures)
try query.where("id", "=", .{ .integer = 1 });

// 3. Generate SQL (allocates string)
const sql = try query.toSql(.postgresql);
defer allocator.free(sql); // Free SQL string

// 4. Execute query
const result = try db.query(sql);
defer result.deinit(); // Free result
```

## 4. Type System

### 4.1 SQL Value Types

SQL values are represented as a tagged union:

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

**Benefits**:
- Type-safe value representation
- Clear distinction between value types
- Easy to extend with new types

### 4.2 Database Type Enumeration

```zig
pub const DatabaseType = enum {
    postgresql,
    mysql,
};
```

Used for:
- SQL generation differences
- Connection string formatting
- Type-specific optimizations

## 5. Query Building Process

### 5.1 Query Builder Lifecycle

```
1. init()          → Create builder with allocator
2. Method calls    → Build query structure
3. toSql()         → Generate SQL string
4. deinit()        → Free builder resources
```

### 5.2 SQL Generation Flow

```
Query Builder
    ↓
Internal Structure (ArrayList, etc.)
    ↓
SQL String Generation
    ↓
Formatted SQL String
```

### 5.3 Example: SELECT Query Building

```zig
// Step 1: Initialize
var query = try dig.query.Select.init(allocator, "users");

// Step 2: Build query structure
query.select(&[_][]const u8{"id", "name"});
try query.where("age", ">", .{ .integer = 18 });
query.orderBy("name", .asc);
query.limit(10);

// Step 3: Generate SQL
const sql = try query.toSql(.postgresql);
// Result: "SELECT id, name FROM users WHERE age > 18 ORDER BY name ASC LIMIT 10"

// Step 4: Cleanup
query.deinit();
allocator.free(sql);
```

## 6. Database Driver Architecture

### 6.1 Driver Interface

Each driver must implement:

```zig
pub const VTable = struct {
    connect: *const fn(state: *anyopaque, config: ConnectionConfig, allocator: Allocator) !void,
    disconnect: *const fn(state: *anyopaque) void,
    execute: *const fn(state: *anyopaque, query: []const u8, allocator: Allocator) !void,
    query: *const fn(state: *anyopaque, query: []const u8, allocator: Allocator) !QueryResult,
    beginTransaction: *const fn(state: *anyopaque) !void,
    commit: *const fn(state: *anyopaque) !void,
    rollback: *const fn(state: *anyopaque) !void,
};
```

### 6.2 Driver State

Each driver maintains its own state:

**PostgreSQL Driver**:
```zig
pub const PostgreSQLConnection = struct {
    allocator: std.mem.Allocator,
    conn: ?*libpq.PGconn = null,
};
```

**MySQL Driver**:
```zig
pub const MySQLConnection = struct {
    allocator: std.mem.Allocator,
    conn: ?*libmysql.MYSQL = null,
};
```

### 6.3 Driver Registration

Drivers are registered through the Db.connect() function:

```zig
switch (config.database_type) {
    .postgresql => {
        const pg_conn = try allocator.create(PostgreSQLConnection);
        pg_conn.* = PostgreSQLConnection.init(allocator);
        instance.conn = pg_conn.toConnection();
        instance.conn_state = pg_conn;
        try instance.conn.connect(config, allocator);
    },
    .mysql => {
        const mysql_conn = try allocator.create(MySQLConnection);
        mysql_conn.* = MySQLConnection.init(allocator);
        instance.conn = mysql_conn.toConnection();
        instance.conn_state = mysql_conn;
        try instance.conn.connect(config, allocator);
    },
}
```

### 6.4 C Library Integration

#### PostgreSQL (libpq)

The PostgreSQL driver uses libpq through the `libs/libpq.zig` bindings:

**Key Functions**:
- `PQconnectdb()` - Establish connection
- `PQfinish()` - Close connection
- `PQexec()` - Execute query
- `PQresultStatus()` - Check query result status
- `PQntuples()`, `PQnfields()` - Get result dimensions
- `PQgetvalue()` - Retrieve cell value
- `PQclear()` - Free result memory

**Example Flow**:
```zig
// Connect
const conn = libpq.connectdb(conn_string_z.ptr);
if (libpq.status(conn) != .CONNECTION_OK) {
    return error.ConnectionFailed;
}

// Execute query
const result = libpq.exec(conn, query_z.ptr);
defer libpq.clear(result);

// Parse results
const num_rows = libpq.ntuples(result);
const num_cols = libpq.nfields(result);
```

#### MySQL (libmysqlclient)

The MySQL driver uses libmysqlclient through the `libs/libmysql.zig` bindings:

**Key Functions**:
- `mysql_init()` - Initialize connection handle
- `mysql_real_connect()` - Establish connection
- `mysql_close()` - Close connection
- `mysql_query()` - Execute query
- `mysql_store_result()` - Retrieve full result set
- `mysql_num_rows()`, `mysql_num_fields()` - Get result dimensions
- `mysql_fetch_row()` - Fetch next row
- `mysql_free_result()` - Free result memory

**Example Flow**:
```zig
// Initialize and connect
const conn = libmysql.init(null);
const result = libmysql.realConnect(
    conn, host, user, passwd, db, port, null, 0
);

// Execute query
if (libmysql.query(conn, query_z.ptr) != 0) {
    return error.QueryExecutionFailed;
}

// Store and parse results
const result = libmysql.storeResult(conn);
defer libmysql.freeResult(result);
```

## 7. Error Propagation

### 7.1 Error Flow

```
Database Operation
    ↓
Driver Implementation
    ↓
C Library Call
    ↓
Error Detection
    ↓
Dig Error Type
    ↓
Application Error Handling
```

### 7.2 Error Types

Errors are defined in `errors.zig` and propagated through error unions:

```zig
pub const DigError = error{
    ConnectionFailed,
    QueryExecutionFailed,
    InvalidQuery,
    // ...
};
```

## 8. Extension Points

### 8.1 Adding New Database Support

1. **Create C library bindings**: `libs/libnewdb.zig`
   - Define opaque types for handles
   - Bind C functions with `extern "c"`
   - Create Zig wrapper functions

2. **Create driver implementation**: `drivers/newdb.zig`
   - Implement connection state struct
   - Implement VTable functions
   - Implement result parsing logic
   - Implement type conversion

3. **Register database type**:
   - Add to `DatabaseType` enum in `types.zig`
   - Add case to `Db.connect()` in `db.zig`
   - Add case to `disconnect()` for cleanup

4. **Update build configuration**:
   - Link required C library in `build.zig`
   - Update Docker/system dependencies

### 8.2 Adding New Query Types

1. Create new query builder struct
2. Implement builder methods
3. Implement `toSql()` method
4. Export from `src/dig.zig`

### 8.3 Adding New Column Types

1. Add type to `ColumnType` enum
2. Update `toSqlType()` method in `Column`
3. Handle database-specific differences

## 9. Performance Considerations

### 9.1 Query Building

- ArrayList pre-allocation reduces reallocations
- SQL string building is single-pass
- No unnecessary copies

### 9.2 Memory Usage

- Query builders use minimal memory
- SQL strings are allocated only when needed
- Results are streamed (future enhancement)

### 9.3 Optimization Opportunities

- Prepared statement caching
- Connection pooling
- Query result streaming
- Batch operations

## 10. Thread Safety

Current implementation:
- **Not thread-safe**: Each Database instance should be used by single thread
- **Future**: Thread-safe connection pooling

## 11. Testing Strategy

### 11.1 Unit Tests

- Query builder tests
- SQL generation tests
- Schema definition tests

### 11.2 Integration Tests

- Database connection tests
- Query execution tests
- Transaction tests

### 11.3 Test Structure

```
src/tests/
├── connection_test.zig
├── errors_test.zig
├── integration_test.zig
├── query_test.zig
├── schema_test.zig
└── types_test.zig
```

