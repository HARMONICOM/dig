//! Database migration system

const std = @import("std");
const errors = @import("errors.zig");
const types = @import("types.zig");
const db_module = @import("db.zig");

/// Migration status
pub const MigrationStatus = enum {
    pending,
    applied,
    failed,
};

/// Migration record stored in database
pub const MigrationRecord = struct {
    id: []const u8,
    name: []const u8,
    applied_at: i64, // Unix timestamp
    batch: i32,
};

/// SQL-based migration definition (from file)
pub const SqlMigration = struct {
    id: []const u8,
    name: []const u8,
    up_sql: []const u8,
    down_sql: []const u8,
    allocator: std.mem.Allocator,

    /// Initialize from SQL file content
    /// Expected format:
    /// ```
    /// -- up
    /// CREATE TABLE ...;
    ///
    /// -- down
    /// DROP TABLE ...;
    /// ```
    pub fn initFromFile(allocator: std.mem.Allocator, file_path: []const u8, content: []const u8) !SqlMigration {
        // Extract ID and name from filename
        // Expected format: "20251122_create_users_table.sql"
        const basename = std.fs.path.basename(file_path);
        const name_without_ext = if (std.mem.endsWith(u8, basename, ".sql"))
            basename[0 .. basename.len - 4]
        else
            basename;

        // Split by first underscore to get ID and name
        var id: []const u8 = undefined;
        var name: []const u8 = undefined;

        if (std.mem.indexOf(u8, name_without_ext, "_")) |underscore_pos| {
            id = try allocator.dupe(u8, name_without_ext[0..underscore_pos]);
            const name_part = name_without_ext[underscore_pos + 1 ..];
            // Convert underscores to spaces and capitalize
            const name_mutable = try allocator.dupe(u8, name_part);
            // Replace underscores with spaces
            for (name_mutable, 0..) |c, i| {
                if (c == '_') {
                    name_mutable[i] = ' ';
                }
            }
            name = name_mutable;
        } else {
            id = try allocator.dupe(u8, name_without_ext);
            name = try allocator.dupe(u8, name_without_ext);
        }

        // Parse SQL content to extract up and down sections
        const parsed = try parseSqlFile(allocator, content);

        return SqlMigration{
            .id = id,
            .name = name,
            .up_sql = parsed.up_sql,
            .down_sql = parsed.down_sql,
            .allocator = allocator,
        };
    }

    /// Free allocated memory
    pub fn deinit(self: *SqlMigration) void {
        self.allocator.free(self.id);
        self.allocator.free(self.name);
        self.allocator.free(self.up_sql);
        self.allocator.free(self.down_sql);
    }

    /// Execute up migration
    pub fn executeUp(self: *const SqlMigration, db: *db_module.Db) !void {
        var statements = try splitSqlStatements(self.allocator, self.up_sql);
        defer {
            for (statements.items) |stmt| {
                self.allocator.free(stmt);
            }
            statements.deinit(self.allocator);
        }

        for (statements.items) |stmt| {
            if (stmt.len > 0) {
                try db.execute(stmt);
            }
        }
    }

    /// Execute down migration
    pub fn executeDown(self: *const SqlMigration, db: *db_module.Db) !void {
        var statements = try splitSqlStatements(self.allocator, self.down_sql);
        defer {
            for (statements.items) |stmt| {
                self.allocator.free(stmt);
            }
            statements.deinit(self.allocator);
        }

        for (statements.items) |stmt| {
            if (stmt.len > 0) {
                try db.execute(stmt);
            }
        }
    }
};

/// Parsed SQL sections
const ParsedSql = struct {
    up_sql: []const u8,
    down_sql: []const u8,
};

/// Parse SQL file content into up and down sections
fn parseSqlFile(allocator: std.mem.Allocator, content: []const u8) !ParsedSql {
    var up_sql: std.ArrayList(u8) = .{};
    defer up_sql.deinit(allocator);
    var down_sql: std.ArrayList(u8) = .{};
    defer down_sql.deinit(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var current_section: enum { none, up, down } = .none;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Check for section markers
        if (std.mem.eql(u8, trimmed, "-- up")) {
            current_section = .up;
            continue;
        } else if (std.mem.eql(u8, trimmed, "-- down")) {
            current_section = .down;
            continue;
        }

        // Add line to appropriate section
        switch (current_section) {
            .up => {
                try up_sql.appendSlice(allocator, line);
                try up_sql.append(allocator, '\n');
            },
            .down => {
                try down_sql.appendSlice(allocator, line);
                try down_sql.append(allocator, '\n');
            },
            .none => {
                // Skip lines before any section marker
            },
        }
    }

    return ParsedSql{
        .up_sql = try allocator.dupe(u8, up_sql.items),
        .down_sql = try allocator.dupe(u8, down_sql.items),
    };
}

/// Split SQL content into individual statements
/// This is a simple implementation that splits by semicolons
/// Note: This may not handle all edge cases (e.g., semicolons in strings)
fn splitSqlStatements(allocator: std.mem.Allocator, sql: []const u8) !std.ArrayList([]const u8) {
    var statements: std.ArrayList([]const u8) = .{};
    var current: std.ArrayList(u8) = .{};
    defer current.deinit(allocator);

    var i: usize = 0;
    while (i < sql.len) : (i += 1) {
        const c = sql[i];

        if (c == ';') {
            const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
            if (trimmed.len > 0) {
                try statements.append(allocator, try allocator.dupe(u8, trimmed));
            }
            current.clearRetainingCapacity();
        } else {
            try current.append(allocator, c);
        }
    }

    // Handle last statement if no semicolon at end
    const trimmed = std.mem.trim(u8, current.items, " \t\n\r");
    if (trimmed.len > 0) {
        try statements.append(allocator, try allocator.dupe(u8, trimmed));
    }

    return statements;
}

/// Migration manager
pub const Manager = struct {
    const Self = @This();

    db: *db_module.Db,
    allocator: std.mem.Allocator,
    migrations_table: []const u8,

    /// Initialize migration manager
    pub fn init(db: *db_module.Db, allocator: std.mem.Allocator) Self {
        return .{
            .db = db,
            .allocator = allocator,
            .migrations_table = "_dig_migrations",
        };
    }

    /// Load SQL migrations from directory
    /// Files should be named like: "20251122_create_users_table.sql"
    /// Returns an ArrayList of SqlMigration (caller must free each migration and the list)
    pub fn loadFromDirectory(self: *Self, dir_path: []const u8) !std.ArrayList(SqlMigration) {
        var migrations: std.ArrayList(SqlMigration) = .{};
        errdefer {
            for (migrations.items) |*migration| {
                migration.deinit();
            }
            migrations.deinit(self.allocator);
        }

        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".sql")) continue;

            // Read file content
            const file = try dir.openFile(entry.name, .{});
            defer file.close();

            const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // Max 1MB
            defer self.allocator.free(content);

            // Create full path for migration initialization
            const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dir_path, entry.name });
            defer self.allocator.free(full_path);

            const migration = try SqlMigration.initFromFile(self.allocator, entry.name, content);
            try migrations.append(self.allocator, migration);
        }

        // Sort migrations by ID
        std.mem.sort(SqlMigration, migrations.items, {}, struct {
            fn lessThan(_: void, a: SqlMigration, b: SqlMigration) bool {
                return std.mem.order(u8, a.id, b.id) == .lt;
            }
        }.lessThan);

        return migrations;
    }

    /// Ensure migrations table exists
    pub fn ensureMigrationsTable(self: *Self) !void {
        // Check if migrations table already exists
        const table_exists = try self.tableExists();

        if (table_exists) {
            return;
        }

        // Create migrations table
        const create_table_sql = switch (self.db.db_type) {
            .postgresql =>
            \\CREATE TABLE _dig_migrations (
            \\    id VARCHAR(255) PRIMARY KEY,
            \\    name VARCHAR(255) NOT NULL,
            \\    applied_at BIGINT NOT NULL,
            \\    batch INTEGER NOT NULL
            \\)
            ,
            .mysql =>
            \\CREATE TABLE _dig_migrations (
            \\    id VARCHAR(255) PRIMARY KEY,
            \\    name VARCHAR(255) NOT NULL,
            \\    applied_at BIGINT NOT NULL,
            \\    batch INT NOT NULL
            \\)
            ,
            .mock =>
            \\CREATE TABLE _dig_migrations (
            \\    id VARCHAR(255) PRIMARY KEY,
            \\    name VARCHAR(255) NOT NULL,
            \\    applied_at BIGINT NOT NULL,
            \\    batch INTEGER NOT NULL
            \\)
            ,
        };

        try self.db.execute(create_table_sql);
        std.debug.print("Created migrations table '{s}'.\n", .{self.migrations_table});
    }

    /// Check if migrations table exists
    fn tableExists(self: *Self) !bool {
        const check_sql = switch (self.db.db_type) {
            .postgresql =>
            \\SELECT EXISTS (
            \\    SELECT FROM information_schema.tables
            \\    WHERE table_schema = 'public'
            \\    AND table_name = '_dig_migrations'
            \\)
            ,
            .mysql =>
            \\SELECT COUNT(*) > 0
            \\FROM information_schema.tables
            \\WHERE table_schema = DATABASE()
            \\AND table_name = '_dig_migrations'
            ,
            .mock => "SELECT 0", // Mock always returns false for table existence
        };

        var result = try self.db.query(check_sql);
        defer result.deinit();

        if (result.rows.len == 0) {
            return false;
        }

        const exists_value = result.rows[0].values[0];
        return switch (exists_value) {
            .integer => |val| val > 0,
            .boolean => |val| val,
            else => false,
        };
    }

    /// Get current batch number
    fn getCurrentBatch(self: *Self) !i32 {
        const query_sql = "SELECT COALESCE(MAX(batch), 0) as max_batch FROM _dig_migrations";
        var result = try self.db.query(query_sql);
        defer result.deinit();

        if (result.rows.len == 0) {
            return 0;
        }

        const max_batch_value = result.rows[0].values[0];
        return switch (max_batch_value) {
            .integer => |val| @intCast(val),
            .null => 0,
            else => 0,
        };
    }

    /// Check if migration is applied
    fn isMigrationApplied(self: *Self, migration_id: []const u8) !bool {
        const query_sql = try std.fmt.allocPrint(
            self.allocator,
            "SELECT COUNT(*) FROM _dig_migrations WHERE id = '{s}'",
            .{migration_id},
        );
        defer self.allocator.free(query_sql);

        var result = try self.db.query(query_sql);
        defer result.deinit();

        if (result.rows.len == 0) {
            return false;
        }

        const count_value = result.rows[0].values[0];
        const count: i64 = switch (count_value) {
            .integer => |val| val,
            else => 0,
        };

        return count > 0;
    }

    /// Record migration as applied
    fn recordMigration(self: *Self, id: []const u8, name: []const u8, batch: i32) !void {
        const timestamp = std.time.timestamp();
        const insert_sql = try std.fmt.allocPrint(
            self.allocator,
            "INSERT INTO _dig_migrations (id, name, applied_at, batch) VALUES ('{s}', '{s}', {d}, {d})",
            .{ id, name, timestamp, batch },
        );
        defer self.allocator.free(insert_sql);

        try self.db.execute(insert_sql);
    }

    /// Remove migration record
    fn removeMigrationRecord(self: *Self, migration_id: []const u8) !void {
        const delete_sql = try std.fmt.allocPrint(
            self.allocator,
            "DELETE FROM _dig_migrations WHERE id = '{s}'",
            .{migration_id},
        );
        defer self.allocator.free(delete_sql);

        try self.db.execute(delete_sql);
    }

    /// Get applied migrations from latest batch
    fn getLatestBatchMigrations(self: *Self) !std.ArrayList([]const u8) {
        var migration_ids: std.ArrayList([]const u8) = .{};

        const current_batch = try self.getCurrentBatch();
        if (current_batch == 0) {
            return migration_ids;
        }

        const query_sql = try std.fmt.allocPrint(
            self.allocator,
            "SELECT id FROM _dig_migrations WHERE batch = {d} ORDER BY applied_at DESC",
            .{current_batch},
        );
        defer self.allocator.free(query_sql);

        var result = try self.db.query(query_sql);
        defer result.deinit();

        for (result.rows) |row| {
            const id_value = row.values[0];
            const id = switch (id_value) {
                .text => |t| try self.allocator.dupe(u8, t),
                else => continue,
            };
            try migration_ids.append(self.allocator, id);
        }

        return migration_ids;
    }

    /// Run pending migrations
    pub fn migrate(self: *Self, migrations: []const SqlMigration) !void {
        try self.ensureMigrationsTable();

        const next_batch = try self.getCurrentBatch() + 1;
        var applied_count: usize = 0;

        for (migrations) |*migration| {
            const is_applied = try self.isMigrationApplied(migration.id);
            if (is_applied) {
                continue;
            }

            std.debug.print("Migrating: {s}\n", .{migration.name});

            try self.db.beginTransaction();
            errdefer self.db.rollback() catch {};

            migration.executeUp(self.db) catch |err| {
                try self.db.rollback();
                std.debug.print("Migration failed: {s} - {any}\n", .{ migration.name, err });
                return errors.DigError.QueryExecutionFailed;
            };

            try self.recordMigration(migration.id, migration.name, next_batch);
            try self.db.commit();

            applied_count += 1;
            std.debug.print("Migrated: {s}\n", .{migration.name});
        }

        if (applied_count == 0) {
            std.debug.print("Nothing to migrate.\n", .{});
        } else {
            std.debug.print("Migrated {d} migration(s).\n", .{applied_count});
        }
    }

    /// Rollback last batch of migrations
    pub fn rollback(self: *Self, migrations: []const SqlMigration) !void {
        try self.ensureMigrationsTable();

        var migration_ids = try self.getLatestBatchMigrations();
        defer {
            for (migration_ids.items) |id| {
                self.allocator.free(id);
            }
            migration_ids.deinit(self.allocator);
        }

        if (migration_ids.items.len == 0) {
            std.debug.print("Nothing to rollback.\n", .{});
            return;
        }

        for (migration_ids.items) |migration_id| {
            // Find migration definition
            var found_migration: ?*const SqlMigration = null;
            for (migrations) |*migration| {
                if (std.mem.eql(u8, migration.id, migration_id)) {
                    found_migration = migration;
                    break;
                }
            }

            if (found_migration == null) {
                std.debug.print("Warning: Migration {s} not found in migration list\n", .{migration_id});
                continue;
            }

            const migration = found_migration.?;
            std.debug.print("Rolling back: {s}\n", .{migration.name});

            try self.db.beginTransaction();
            errdefer self.db.rollback() catch {};

            migration.executeDown(self.db) catch |err| {
                try self.db.rollback();
                std.debug.print("Rollback failed: {s} - {any}\n", .{ migration.name, err });
                return errors.DigError.QueryExecutionFailed;
            };

            try self.removeMigrationRecord(migration_id);
            try self.db.commit();

            std.debug.print("Rolled back: {s}\n", .{migration.name});
        }

        std.debug.print("Rolled back {d} migration(s).\n", .{migration_ids.items.len});
    }

    /// Reset all migrations (rollback all)
    pub fn reset(self: *Self, migrations: []const SqlMigration) !void {
        try self.ensureMigrationsTable();

        const current_batch = try self.getCurrentBatch();
        var batch: i32 = current_batch;

        while (batch > 0) : (batch -= 1) {
            try self.rollback(migrations);
        }
    }

    /// Get migration status
    pub fn status(self: *Self, migrations: []const SqlMigration) !void {
        try self.ensureMigrationsTable();

        std.debug.print("\n{s: <30} {s: <10}\n", .{ "Migration", "Status" });
        std.debug.print("{s:-<40}\n", .{""});

        for (migrations) |migration| {
            const is_applied = try self.isMigrationApplied(migration.id);
            const status_str = if (is_applied) "Applied" else "Pending";
            std.debug.print("{s: <30} {s: <10}\n", .{ migration.name, status_str });
        }

        std.debug.print("\n", .{});
    }
};
