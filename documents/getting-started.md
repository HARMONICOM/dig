## Getting Started with Dig

This guide walks you through:

1. Setting up the environment
2. Connecting to a database
3. Executing your first query
4. Understanding a typical project structure

It assumes basic familiarity with Zig and SQL databases.

---

## 1. Install Zig and Dependencies

- **Zig version**: Dig targets **Zig 0.15.2** or later.
- **Database Client Libraries** (optional):
  - **PostgreSQL**: `libpq` (libpq-dev on Debian/Ubuntu)
  - **MySQL**: `libmysqlclient` (libmysqlclient-dev on Debian/Ubuntu)

**Important**: By default, Dig does not require any database client libraries. You only need to install the libraries for the databases you plan to use, and explicitly enable them at build time.

If you use the provided Docker environment, all dependencies are preconfigured.

---

## 2. Adding Dig to Your Project

Add Dig as a dependency in your `build.zig.zon`:

```zig
.{
    .name = "my-app",
    .version = "0.1.0",
    .dependencies = .{
        .dig = .{
            .url = "https://github.com/username/dig/archive/<commit-hash>.tar.gz",
            .hash = "<hash>",
        },
    },
}
```

In your `build.zig`, import Dig and enable the database drivers you need:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import Dig with database drivers enabled
    const dig = b.dependency("dig", .{
        .target = target,
        .optimize = optimize,
        .postgresql = true,  // Enable PostgreSQL support
        // .mysql = true,     // Enable MySQL support if needed
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add Dig module to your executable
    exe.root_module.addImport("dig", dig.module("dig"));

    b.installArtifact(exe);
}
```

**Note**: Both PostgreSQL and MySQL drivers are disabled by default. You must explicitly enable the ones you need.

---

## 3. Connecting to a Database

Below is a minimal example that connects to a PostgreSQL database:

```zig
const std = @import("std");
const dig = @import("dig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Database connection configuration
    const config = dig.types.ConnectionConfig{
        .database_type = .postgresql,
        .host = "localhost",
        .port = 5432,
        .database = "mydb",
        .username = "user",
        .password = "pass",
        .ssl = false,
    };

    // Connect to database
    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    std.debug.print("Connected to database!\n", .{});
}
```

For MySQL, change `.database_type` to `.mysql` and adjust the port (usually 3306):

```zig
const config = dig.types.ConnectionConfig{
    .database_type = .mysql,
    .host = "localhost",
    .port = 3306,
    .database = "mydb",
    .username = "user",
    .password = "pass",
};
```

---

## 4. Executing Your First Query

### 4.1 Raw SQL Query

Execute a raw SQL query:

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

    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    // Execute a query and get results
    var result = try db.query("SELECT id, name, email FROM users LIMIT 5");
    defer result.deinit();

    // Print column names
    std.debug.print("Columns: ", .{});
    for (result.columns) |col| {
        std.debug.print("{s} ", .{col});
    }
    std.debug.print("\n", .{});

    // Print rows
    for (result.rows) |row| {
        const id = row.get("id").?.integer;
        const name = row.get("name").?.text;
        const email = row.get("email").?.text;
        std.debug.print("User {d}: {s} ({s})\n", .{ id, name, email });
    }
}
```

### 4.2 Using Query Builders

Build queries with the fluent API. There are two ways to use query builders:

**Method 1: Chainable Query Builder (Recommended)**

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

    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    // Build and execute a SELECT query in one chain
    var result = try db.table("users")
        .select(&.{"id", "name", "email"})
        .where("age", ">=", .{.integer = 18})
        .orderBy("name", .asc)
        .limit(10)
        .get();
    defer result.deinit();

    for (result.rows) |row| {
        const id = row.get("id").?.integer;
        const name = row.get("name").?.text;
        std.debug.print("User {d}: {s}\n", .{ id, name });
    }
}
```

**Method 2: Traditional Query Builder**

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

    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    // Build a SELECT query
    var query = try dig.query.Select.init(allocator, "users");
    defer query.deinit();

    const sql = try (try query
        .select(&[_][]const u8{"id", "name", "email"})
        .where("age", ">=", .{ .integer = 18 }))
        .orderBy("name", .asc)
        .limit(10)
        .toSql(.postgresql);
    defer allocator.free(sql);

    std.debug.print("Generated SQL: {s}\n", .{sql});

    // Execute the query
    var result = try db.query(sql);
    defer result.deinit();

    for (result.rows) |row| {
        const id = row.get("id").?.integer;
        const name = row.get("name").?.text;
        std.debug.print("User {d}: {s}\n", .{ id, name });
    }
}
```

---

## 5. Creating Tables with Schema Definition

Define and create tables using Dig's schema API:

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

    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    // Define a table
    var users_table = dig.schema.Table.init(allocator, "users");
    defer users_table.deinit();

    try users_table.addColumn(.{
        .name = "id",
        .type = .bigint,
        .primary_key = true,
        .auto_increment = true,
    });

    try users_table.addColumn(.{
        .name = "name",
        .type = .varchar,
        .length = 255,
        .nullable = false,
    });

    try users_table.addColumn(.{
        .name = "email",
        .type = .varchar,
        .length = 255,
        .nullable = false,
        .unique = true,
    });

    try users_table.addColumn(.{
        .name = "age",
        .type = .integer,
        .nullable = true,
    });

    // Generate CREATE TABLE SQL
    const sql = try users_table.toCreateTableSql(.postgresql, allocator);
    defer allocator.free(sql);

    std.debug.print("Generated SQL:\n{s}\n", .{sql});

    // Execute the CREATE TABLE statement
    try db.execute(sql);

    std.debug.print("Table 'users' created successfully!\n", .{});
}
```

---

## 6. Using Transactions

Transactions allow you to execute multiple queries atomically:

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

    var db = try dig.db.connect(allocator, config);
    defer db.disconnect();

    // Start transaction
    try db.beginTransaction();
    errdefer db.rollback() catch {};

    // Execute multiple queries
    try db.execute("INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com')");
    try db.execute("INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com')");

    // Commit transaction
    try db.commit();

    std.debug.print("Transaction committed successfully!\n", .{});
}
```

---

## 7. Project Structure (Typical)

When using Dig in a real project, a common layout is:

```text
src/
  main.zig           # Entry point
  models/            # Data model definitions
    user.zig
    post.zig
database/
  migrations/        # SQL migration files (default directory)
    20251122_create_users.sql
    20251123_create_posts.sql
build.zig            # Build configuration
build.zig.zon        # Dependencies
```

You can organize your database logic in separate modules and import them in `main.zig`.

---

## 8. Next Steps

- **Define database schemas**: See [`schema.md`](./schema.md)
- **Build complex queries**: See [`query-builders.md`](./query-builders.md)
- **Manage database migrations**: See [`migrations.md`](./migrations.md)
- **Learn about database drivers**: See [`database-drivers.md`](./database-drivers.md)
- **API reference**: See [`api-reference.md`](./api-reference.md)

---

## 9. Troubleshooting

### Error: `UnsupportedDatabase`

If you see this error when trying to connect:

```
error: UnsupportedDatabase
Database driver not enabled. Build with -Dpostgresql=true to enable PostgreSQL support.
```

**Solution**: Rebuild your project with the appropriate driver flag:

```bash
zig build -Dpostgresql=true
# or for MySQL
zig build -Dmysql=true
```

Or update your `build.zig.zon` dependency configuration:

```zig
const dig = b.dependency("dig", .{
    .target = target,
    .optimize = optimize,
    .postgresql = true,  // Add this line
});
```

### Error: Cannot find `libpq` or `libmysqlclient`

If you get a linker error about missing libraries:

**Solution**: Install the required database client libraries:

```bash
# Debian/Ubuntu
sudo apt-get install libpq-dev      # For PostgreSQL
sudo apt-get install libmysqlclient-dev  # For MySQL

# macOS (via Homebrew)
brew install postgresql@15          # For PostgreSQL
brew install mysql-client           # For MySQL
```

### Connection Failed

If connection fails, check:

1. Database server is running
2. Host, port, username, and password are correct
3. Database exists and user has access permissions
4. Firewall allows connections to the database port

