## Schema Definition

Dig provides a declarative schema definition system for creating database tables.
This guide covers defining tables, columns, constraints, and generating CREATE TABLE statements.

---

## 1. Overview

The schema definition system allows you to:

- Define tables and columns programmatically
- Specify column types, constraints, and defaults
- Generate database-specific CREATE TABLE SQL
- Create tables in PostgreSQL and MySQL with the same code

---

## 2. Column Types

Dig supports the following column types:

| Dig Type    | PostgreSQL           | MySQL                | Description                    |
|-------------|----------------------|----------------------|--------------------------------|
| `integer`   | INTEGER              | INT                  | 32-bit integer                 |
| `bigint`    | BIGINT               | BIGINT               | 64-bit integer                 |
| `text`      | TEXT                 | TEXT                 | Variable-length text           |
| `varchar`   | VARCHAR(n)           | VARCHAR(n)           | Variable-length string with limit |
| `boolean`   | BOOLEAN              | BOOLEAN              | True/false value               |
| `float`     | REAL                 | FLOAT                | Single-precision floating point |
| `double`    | DOUBLE PRECISION     | DOUBLE               | Double-precision floating point |
| `timestamp` | TIMESTAMP            | TIMESTAMP            | Date and time                  |
| `blob`      | BYTEA                | BLOB                 | Binary data                    |
| `json`      | JSONB                | JSON                 | JSON data                      |

---

## 3. Column Definition

A column is defined using the `Column` struct:

```zig
pub const Column = struct {
    name: []const u8,
    type: ColumnType,
    nullable: bool = false,
    primary_key: bool = false,
    auto_increment: bool = false,
    unique: bool = false,
    default_value: ?[]const u8 = null,
    length: ?usize = null, // For varchar only
};
```

### 3.1 Column Attributes

- **name**: Column name (required)
- **type**: Column type from `ColumnType` enum (required)
- **nullable**: Allow NULL values (default: `false`)
- **primary_key**: Mark as primary key (default: `false`)
- **auto_increment**: Auto-increment for integer types (default: `false`)
  - PostgreSQL: Uses `SERIAL` or `BIGSERIAL`
  - MySQL: Uses `AUTO_INCREMENT`
- **unique**: Enforce unique constraint (default: `false`)
- **default_value**: Default value as SQL expression (default: `null`)
- **length**: Maximum length for `varchar` type (required for varchar)

### 3.2 Example Column Definitions

```zig
// Primary key with auto-increment
.{
    .name = "id",
    .type = .bigint,
    .primary_key = true,
    .auto_increment = true,
}

// Required text column
.{
    .name = "name",
    .type = .varchar,
    .length = 255,
    .nullable = false,
}

// Unique email column
.{
    .name = "email",
    .type = .varchar,
    .length = 255,
    .nullable = false,
    .unique = true,
}

// Optional integer column with default
.{
    .name = "status",
    .type = .integer,
    .nullable = true,
    .default_value = "0",
}

// Boolean column with default
.{
    .name = "active",
    .type = .boolean,
    .nullable = false,
    .default_value = "true",
}

// Timestamp with default
.{
    .name = "created_at",
    .type = .timestamp,
    .nullable = false,
    .default_value = "CURRENT_TIMESTAMP",
}

// JSON column
.{
    .name = "metadata",
    .type = .json,
    .nullable = true,
}
```

---

## 4. Table Definition

A table is defined using the `Table` struct.

### 4.1 Creating a Table

```zig
const allocator = std.heap.page_allocator;

var table = dig.schema.Table.init(allocator, "users");
defer table.deinit();
```

### 4.2 Adding Columns

Add columns using the `addColumn` method:

```zig
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

try table.addColumn(.{
    .name = "email",
    .type = .varchar,
    .length = 255,
    .nullable = false,
    .unique = true,
});

try table.addColumn(.{
    .name = "age",
    .type = .integer,
    .nullable = true,
});

try table.addColumn(.{
    .name = "created_at",
    .type = .timestamp,
    .nullable = false,
    .default_value = "CURRENT_TIMESTAMP",
});
```

### 4.3 Generating CREATE TABLE SQL

Generate database-specific SQL using `toCreateTableSql`:

```zig
const sql = try table.toCreateTableSql(.postgresql, allocator);
defer allocator.free(sql);

std.debug.print("SQL:\n{s}\n", .{sql});
```

**PostgreSQL Output**:
```sql
CREATE TABLE IF NOT EXISTS users (
    id BIGINT PRIMARY KEY SERIAL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    age INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
)
```

**MySQL Output** (with `.mysql` database type):
```sql
CREATE TABLE IF NOT EXISTS users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    age INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
)
```

### 4.4 Creating the Table in Database

Execute the generated SQL to create the table:

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

    // Define table schema
    var table = dig.schema.Table.init(allocator, "users");
    defer table.deinit();

    try table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });

    try table.addColumn(.{
        .name = "username",
        .type = .varchar,
        .length = 50,
        .nullable = false,
        .unique = true,
    });

    try table.addColumn(.{
        .name = "email",
        .type = .varchar,
        .length = 255,
        .nullable = false,
    });

    // Generate and execute CREATE TABLE
    const sql = try table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    try db.execute(sql);
    std.debug.print("Table 'users' created successfully!\n", .{});
}
```

---

## 5. Complete Example

Here's a complete example creating a `posts` table with foreign key reference:

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

    // Define posts table
    var posts_table = dig.schema.Table.init(allocator, "posts");
    defer posts_table.deinit();

    try posts_table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });

    try posts_table.addColumn(.{
        .name = "user_id",
        .type = .bigint,
        .nullable = false,
    });

    try posts_table.addColumn(.{
        .name = "title",
        .type = .varchar,
        .length = 255,
        .nullable = false,
    });

    try posts_table.addColumn(.{
        .name = "content",
        .type = .text,
        .nullable = true,
    });

    try posts_table.addColumn(.{
        .name = "published",
        .type = .boolean,
        .nullable = false,
        .default_value = "false",
    });

    try posts_table.addColumn(.{
        .name = "created_at",
        .type = .timestamp,
        .nullable = false,
        .default_value = "CURRENT_TIMESTAMP",
    });

    try posts_table.addColumn(.{
        .name = "updated_at",
        .type = .timestamp,
        .nullable = true,
    });

    // Generate CREATE TABLE SQL
    const sql = try posts_table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    std.debug.print("Generated SQL:\n{s}\n\n", .{sql});

    // Execute CREATE TABLE
    try db.execute(sql);

    // Add foreign key constraint (currently requires raw SQL)
    const fk_sql =
        \\ALTER TABLE posts
        \\ADD CONSTRAINT fk_posts_user_id
        \\FOREIGN KEY (user_id) REFERENCES users(id)
        \\ON DELETE CASCADE
    ;
    try db.execute(fk_sql);

    std.debug.print("Table 'posts' created with foreign key!\n", .{});
}
```

**Note**: Foreign key constraints are not yet supported in the schema builder. Use raw SQL with `db.execute()` to add them after table creation.

---

## 6. Database-Specific Differences

The schema builder automatically handles database-specific differences:

### PostgreSQL
- Auto-increment: `SERIAL` (integer) or `BIGSERIAL` (bigint)
- JSON type: `JSONB` (binary JSON for better performance)
- Binary data: `BYTEA`
- Float: `REAL` (single) or `DOUBLE PRECISION` (double)

### MySQL
- Auto-increment: `AUTO_INCREMENT` attribute
- JSON type: `JSON`
- Binary data: `BLOB`
- Float: `FLOAT` (single) or `DOUBLE` (double)

Both databases support:
- Standard SQL types (INTEGER, BIGINT, VARCHAR, TEXT, BOOLEAN, TIMESTAMP)
- NOT NULL constraints
- UNIQUE constraints
- PRIMARY KEY constraints
- DEFAULT values

---

## 7. Best Practices

### 7.1 Always Use Primary Keys

Every table should have a primary key:

```zig
try table.addColumn(.{
    .name = "id",
    .type = .bigint,
    .primary_key = true,
    .auto_increment = true,
});
```

### 7.2 Add Created/Updated Timestamps

Track when records are created and updated:

```zig
try table.addColumn(.{
    .name = "created_at",
    .type = .timestamp,
    .nullable = false,
    .default_value = "CURRENT_TIMESTAMP",
});

try table.addColumn(.{
    .name = "updated_at",
    .type = .timestamp,
    .nullable = true,
});
```

### 7.3 Use VARCHAR with Appropriate Lengths

Specify reasonable lengths for text columns:

```zig
// Email addresses
try table.addColumn(.{
    .name = "email",
    .type = .varchar,
    .length = 255,
    .nullable = false,
});

// Short names
try table.addColumn(.{
    .name = "username",
    .type = .varchar,
    .length = 50,
    .nullable = false,
});
```

### 7.4 Use TEXT for Long Content

For long text content without size limits:

```zig
try table.addColumn(.{
    .name = "content",
    .type = .text,
    .nullable = true,
});
```

### 7.5 Use JSON for Structured Data

For flexible structured data:

```zig
try table.addColumn(.{
    .name = "metadata",
    .type = .json,
    .nullable = true,
});
```

---

## 8. Limitations

Current limitations of the schema builder:

- **Foreign keys**: Not yet supported in schema builder (use raw SQL)
- **Indexes**: Not yet supported (use raw SQL)
- **Constraints**: Only basic constraints supported (primary key, unique, not null)
- **ALTER TABLE**: Not yet supported (use migrations for schema changes)

For advanced features, use raw SQL with `db.execute()` or create migration files (see [`migrations.md`](./migrations.md)).

---

## 9. Next Steps

- **Build queries**: See [`query-builders.md`](./query-builders.md)
- **Manage schema changes**: See [`migrations.md`](./migrations.md)
- **API reference**: See [`api-reference.md`](./api-reference.md)

