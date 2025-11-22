# Dig ORM

![Dig ORM Logo](docs/dig_logo.png)

A type-safe SQL query builder for Zig.

## Overview

Dig ORM is a lightweight, type-safe SQL query builder library for Zig that provides an intuitive API for building SQL queries. It supports PostgreSQL and MySQL databases.

## Features

- **Type-safe query building**: Build SQL queries with compile-time type checking
- **Fluent API**: Chain methods to build queries intuitively
- **Multi-database support**: PostgreSQL and MySQL with full driver implementations
- **Schema definition**: Define tables and columns with a simple API
- **Migration system**: Database schema versioning with up/down migrations
- **Transaction support**: Built-in transaction management (BEGIN/COMMIT/ROLLBACK)
- **Result parsing**: Automatic type conversion from database results
- **C library bindings**: Complete bindings for libpq and libmysqlclient
- **Pure Zig implementation**: Core logic in Zig with FFI to C libraries

## Documentation

📖 **[Online Documentation](https://harmonicom.github.io/dig/)** - Interactive documentation website

Additional documentation:
- **[Specification](documents/specification.md)** - Complete API specification and usage guide
- **[API Reference](documents/api_reference.md)** - Detailed API documentation
- **[Architecture](documents/architecture.md)** - System architecture and design
- **[Migration Tool Guide](examples/README.md)** - Migration tool usage and examples

## Installation

Add Dig to your `build.zig.zon`:

```zig
.dependencies = .{
    .dig = .{
        .path = "path/to/dig",
    },
}
```

Then add it to your `build.zig`:

```zig
const dig = b.dependency("dig", .{
    .target = target,
    .optimize = optimize,
    // Required: Enable the database drivers you need (both disabled by default)
    .postgresql = true,  // Enable if using PostgreSQL
    .mysql = true,       // Enable if using MySQL
});

exe.root_module.addImport("dig", dig.module("dig"));
b.installArtifact(exe);

// Install migration tool (automatically built by Dig)
const migrate_artifact = dig.artifact("migrate");
b.installArtifact(migrate_artifact);
```

**Build Options**: Drivers are disabled by default. You must explicitly enable the drivers you need using `.postgresql = true` or `.mysql = true`.

For detailed build configuration, see the [Specification](documents/specification.md#23-build-configuration).

## Quick Start

### Connection

```zig
const dig = @import("dig");

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

### Building Queries

```zig
// SELECT query
var query = try dig.query.SelectQuery.init(allocator, "users");
defer query.deinit();

const sql = try (try query
    .select(&[_][]const u8{ "id", "name", "email" })
    .where("age", ">", .{ .integer = 18 }))
    .toSql(.postgresql);
defer allocator.free(sql);

// INSERT query
var insert = try dig.query.InsertQuery.init(allocator, "users");
defer insert.deinit();

const insert_sql = try (try (try insert
    .addValue("name", .{ .text = "John Doe" }))
    .addValue("email", .{ .text = "john@example.com" }))
    .toSql(.postgresql);
defer allocator.free(insert_sql);
```

For more detailed examples (UPDATE, DELETE, transactions, schema definition, etc.), see the [Specification](documents/specification.md#5-usage-patterns).

### Migrations

Dig provides a SQL-based migration system for database schema management.

**Example Migration File** (`migrations/20251122_create_users_table.sql`):
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

**Using the Standalone Migration Tool**:

Run migrations:
```bash
# Run migrations
DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass ./zig-out/bin/migrate up
```

For complete migration documentation, see:
- **[Specification - Migration System](documents/specification.md#36-migration-system)** - API and usage patterns
- **[Migration Tool Guide](examples/README.md)** - CLI tool, Docker integration, and CI/CD examples

## Database Support

### PostgreSQL
- **Status**: ✅ Fully implemented
- **Requirements**: libpq development libraries (`libpq-dev`)
- **Enable**: `.postgresql = true` in `build.zig`

### MySQL
- **Status**: ✅ Fully implemented
- **Requirements**: libmysqlclient development libraries (`default-libmysqlclient-dev`)
- **Enable**: `.mysql = true` in `build.zig`

Both drivers support:
- Connection management
- Query execution and result parsing
- Transaction support (BEGIN/COMMIT/ROLLBACK)
- Type conversion (INT, TEXT, FLOAT, BOOL, TIMESTAMP, JSON, etc.)
- NULL value handling

For detailed type mappings and driver implementation, see the [Specification](documents/specification.md#4-database-support).

## Project Structure

```
dig/
├── src/
│   ├── dig.zig                    # Module entry point
│   ├── migrate.zig                # Migration CLI tool (auto-built)
│   ├── dig/                       # Module files directory
│   │   ├── connection.zig         # Connection abstraction
│   │   ├── db.zig                 # Database interface
│   │   ├── drivers/               # Database drivers (PostgreSQL, MySQL)
│   │   ├── libs/                  # C library bindings
│   │   ├── migration.zig          # Migration system
│   │   ├── query.zig              # Query builders
│   │   ├── schema.zig             # Schema definitions
│   │   └── types.zig              # Type definitions
│   └── tests/                     # Test files
├── documents/                     # Documentation
│   ├── specification.md           # Complete API specification
│   ├── api_reference.md           # API reference
│   └── architecture.md            # Architecture document
└── examples/                      # Usage guides
    └── README.md                  # Migration tool guide
```

## Requirements

- Zig 0.15.2 or later
- PostgreSQL: libpq development libraries (if using PostgreSQL)
- MySQL: libmysqlclient development libraries (if using MySQL)

## Examples

See test files in `src/tests/` for usage examples and the [Specification](documents/specification.md) for complete usage patterns.

## License

[Add your license here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

