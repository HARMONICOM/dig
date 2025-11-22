## Migrations

Dig provides a SQL-based migration system for managing database schema changes over time.
This guide covers creating, running, and managing migrations using SQL files.

---

## 1. Overview

The migration system allows you to:

- **Version control** your database schema
- **Track** which migrations have been applied
- **Roll back** migrations to previous states
- **Share** schema changes with your team through SQL files
- **Automate** migrations in CI/CD pipelines

Dig uses SQL files with `-- up` and `-- down` sections, making migrations readable and database-tool compatible.

---

## 2. Migration Files

### 2.1 File Format

Migration files follow this structure:

```sql
-- Migration description (optional comment)

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

**Key Sections**:
- **`-- up`**: SQL statements to apply the migration
- **`-- down`**: SQL statements to roll back the migration

### 2.2 File Naming Convention

Format: `{id}_{description}.sql`

Examples:
- `20251122_create_users_table.sql`
- `20251123_add_email_verification.sql`
- `20251124_create_posts_table.sql`

**ID Format**: Use `YYYYMMDD` (date-based):
- Year: 4 digits (2025)
- Month: 2 digits (01-12)
- Day: 2 digits (01-31)

**Description**: Use lowercase with underscores, describing what the migration does.

**Note**: The ID is extracted from the part before the first underscore, and the description is taken from the rest with underscores replaced by spaces.

### 2.3 Migration File Example

File: `migrations/20251122_create_users_table.sql`

```sql
-- Migration: Create users table with authentication fields

-- up
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email_verified BOOLEAN DEFAULT false,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- down
DROP TABLE IF EXISTS users;
```

---

## 3. Migration Directory Structure

Create a `migrations/` directory in your project root:

```text
my-project/
├── src/
│   └── main.zig
├── migrations/
│   ├── 20251122_create_users_table.sql
│   ├── 20251123_create_posts_table.sql
│   └── 20251124_add_user_roles.sql
├── build.zig
└── build.zig.zon
```

**Best Practice**: Keep migration files in version control (git) to track schema changes.

---

## 4. Using the Standalone Migration Tool

Dig automatically provides a standalone `migrate` CLI tool that runs independently from your application.

### 4.1 Installing the Migration Tool

In your `build.zig`, install the migration tool provided by Dig:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import Dig with database drivers
    const dig = b.dependency("dig", .{
        .target = target,
        .optimize = optimize,
        .postgresql = true,  // Enable PostgreSQL
        // .mysql = true,     // Enable MySQL if needed
    });

    // Your application
    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("dig", dig.module("dig"));
    b.installArtifact(exe);

    // Install the migration tool (automatically built by Dig)
    const migrate_artifact = dig.artifact("migrate");
    b.installArtifact(migrate_artifact);
}
```

Build your project:

```bash
zig build
```

The `migrate` tool will be available in `zig-out/bin/migrate`.

### 4.2 Configuration via Environment Variables

The migration tool uses environment variables for configuration:

| Variable        | Description                              | Required | Default     |
|-----------------|------------------------------------------|----------|-------------|
| `DB_TYPE`       | Database type (`postgresql` or `mysql`)  | Yes      | -           |
| `DB_HOST`       | Database host                            | No       | `localhost` |
| `DB_PORT`       | Database port                            | No       | 5432 (PG) / 3306 (MySQL) |
| `DB_DATABASE`   | Database name                            | Yes      | -           |
| `DB_USERNAME`   | Database username                        | Yes      | -           |
| `DB_PASSWORD`   | Database password                        | Yes      | -           |

### 4.3 Migration Commands

#### Run All Pending Migrations

```bash
DB_TYPE=postgresql \
DB_DATABASE=mydb \
DB_USERNAME=user \
DB_PASSWORD=pass \
  ./zig-out/bin/migrate up
```

Default migration directory: `./migrations/`

Custom migration directory:

```bash
DB_TYPE=postgresql \
DB_DATABASE=mydb \
DB_USERNAME=user \
DB_PASSWORD=pass \
  ./zig-out/bin/migrate up --dir=db/migrations
```

#### Roll Back Last Migration Batch

```bash
DB_TYPE=postgresql \
DB_DATABASE=mydb \
DB_USERNAME=user \
DB_PASSWORD=pass \
  ./zig-out/bin/migrate down
```

#### Roll Back All Migrations

```bash
DB_TYPE=postgresql \
DB_DATABASE=mydb \
DB_USERNAME=user \
DB_PASSWORD=pass \
  ./zig-out/bin/migrate reset
```

**Warning**: This will drop all tables managed by migrations!

#### Check Migration Status

```bash
DB_TYPE=postgresql \
DB_DATABASE=mydb \
DB_USERNAME=user \
DB_PASSWORD=pass \
  ./zig-out/bin/migrate status
```

Output:
```
Migration Status:
✓ 20251122 create users table (applied)
✓ 20251123 create posts table (applied)
✗ 20251124 add user roles (pending)
```

#### Show Help

```bash
./zig-out/bin/migrate help
```

---

## 5. Integration Patterns

### 5.1 Using Environment Variables

Create a `.env` file (don't commit this!):

```bash
DB_TYPE=postgresql
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=mydb
DB_USERNAME=user
DB_PASSWORD=password
```

Load and run:

```bash
source .env
./zig-out/bin/migrate up
```

---

## 6. Migration History Tracking

Dig tracks applied migrations in a special table `_dig_migrations`:

```sql
CREATE TABLE _dig_migrations (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    applied_at BIGINT NOT NULL,
    batch INTEGER NOT NULL
);
```

**Fields**:
- **id**: Migration ID (e.g., "20251122")
- **name**: Migration name (e.g., "create users table")
- **applied_at**: Unix timestamp when applied
- **batch**: Batch number for grouping related migrations

### 7.1 Batch System

Migrations run together in the same session are grouped in a batch:

```
Batch 1: 20251122_create_users.sql
Batch 2: 20251123_create_posts.sql, 20251124_add_indexes.sql
Batch 3: 20251125_add_comments.sql
```

When you roll back, all migrations in the last batch are rolled back together.

---

## 7. Best Practices

### 7.1 Never Modify Applied Migrations

Once a migration is applied in production:
- **Don't modify** the file
- **Don't rename** the file
- **Create a new migration** for changes

### 7.2 Use Idempotent SQL

Use `IF EXISTS` / `IF NOT EXISTS` to make migrations safer:

```sql
-- up
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255)
);

-- down
DROP TABLE IF EXISTS users;
```

### 7.3 Test Migrations Locally

Always test both `up` and `down` migrations:

```bash
# Apply migration
./zig-out/bin/migrate up

# Verify database state
psql -U user -d mydb -c "\d users"

# Roll back
./zig-out/bin/migrate down

# Verify rollback worked
psql -U user -d mydb -c "\d users"

# Re-apply
./zig-out/bin/migrate up
```

### 7.4 Keep Migrations Small

Each migration should:
- Do **one logical change**
- Be **fast to execute**
- Be **easy to review**

Bad:
```
20251122_add_many_changes.sql  (creates 10 tables, adds indexes, modifies data)
```

Good:
```
20251122_create_users_table.sql
20251123_create_posts_table.sql
20251124_add_user_indexes.sql
```

### 7.5 Add Comments

Explain complex migrations:

```sql
-- Migration: Add user roles system
-- This migration creates the roles and user_roles tables
-- to support role-based access control (RBAC)

-- up
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE user_roles (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- down
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
```

### 7.6 Be Careful with Data Migrations

When migrating data, consider:
- **Large tables**: May take a long time
- **Data loss**: Always back up first
- **Transactions**: Wrap in transactions where possible

```sql
-- up
BEGIN;

-- Add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);

-- Migrate data
UPDATE users SET full_name = CONCAT(first_name, ' ', last_name);

-- Make column NOT NULL after data is populated
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;

COMMIT;

-- down
ALTER TABLE users DROP COLUMN full_name;
```

---

## 8. Troubleshooting

### Migration Failed Midway

If a migration fails:

1. Check the error message
2. Fix the SQL in the migration file
3. Manually clean up the database if needed
4. Delete the migration record from `_dig_migrations` if partially applied
5. Re-run the migration

```sql
-- Remove failed migration record
DELETE FROM _dig_migrations WHERE id = '20251122';
```

### Migration Applied but Not in History

If you manually applied SQL but it's not tracked:

```sql
-- Manually add migration record
INSERT INTO _dig_migrations (id, name, applied_at, batch)
VALUES ('20251122', 'create users table', EXTRACT(EPOCH FROM NOW()), 1);
```

### Reset Everything

To completely reset and re-run all migrations:

```bash
# Drop all tables
./zig-out/bin/migrate reset

# Re-run migrations
./zig-out/bin/migrate up
```

---

## 9. Examples

### Example 1: Creating a Users Table

File: `migrations/20251122_create_users_table.sql`

```sql
-- Migration: Create users table

-- up
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- down
DROP TABLE IF EXISTS users;
```

### Example 2: Adding a Column

File: `migrations/20251123_add_user_bio.sql`

```sql
-- Migration: Add bio column to users table

-- up
ALTER TABLE users ADD COLUMN bio TEXT;

-- down
ALTER TABLE users DROP COLUMN bio;
```

### Example 3: Creating a Related Table

File: `migrations/20251124_create_posts_table.sql`

```sql
-- Migration: Create posts table with foreign key to users

-- up
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    published BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_posts_user_id ON posts(user_id);

-- down
DROP TABLE IF EXISTS posts;
```

### Example 4: Renaming a Column

File: `migrations/20251125_rename_bio_to_description.sql`

```sql
-- Migration: Rename bio column to description

-- up
ALTER TABLE users RENAME COLUMN bio TO description;

-- down
ALTER TABLE users RENAME COLUMN description TO bio;
```

---

## 10. Next Steps

- **Learn about database drivers**: See [`database-drivers.md`](./database-drivers.md)
- **API reference**: See [`api-reference.md`](./api-reference.md)
- **Architecture details**: See [`architecture.md`](./architecture.md)

