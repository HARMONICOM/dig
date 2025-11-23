//! Database seeder CLI tool
//!
//! This tool executes SQL files from a specified directory to seed database with initial data.
//!
//! Usage:
//!   seeder run [subdirectory] [--dir <seeders_dir>]     Execute seed files
//!   seeder help                                         Show help message
//!
//! Environment variables:
//!   DB_TYPE      Database type (postgresql or mysql)
//!   DB_HOST      Database host (default: localhost)
//!   DB_PORT      Database port (default: 5432 for PostgreSQL, 3306 for MySQL)
//!   DB_DATABASE  Database name
//!   DB_USERNAME  Database username
//!   DB_PASSWORD  Database password

const std = @import("std");
const dig = @import("dig");

const Command = enum {
    run,
    help,
};

const Config = struct {
    command: Command,
    seeders_dir: []const u8,
    subdirectory: ?[]const u8,
    db_type: dig.types.DatabaseType,
    db_host: []const u8,
    db_port: u16,
    db_name: []const u8,
    db_user: []const u8,
    db_password: []const u8,
};

const SeedFile = struct {
    name: []const u8,
    content: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SeedFile) void {
        self.allocator.free(self.name);
        self.allocator.free(self.content);
    }
};

fn printHelp() void {
    std.debug.print(
        \\Database Seeder CLI Tool
        \\
        \\Usage:
        \\  seeder run [subdirectory] [--dir <seeders_dir>]     Execute seed files
        \\  seeder help                                         Show this help
        \\
        \\Arguments:
        \\  subdirectory  Optional subdirectory name within seeders directory
        \\
        \\Options:
        \\  --dir <path>  Path to seeders directory (default: database/seeders)
        \\
        \\Environment variables:
        \\  DB_TYPE      Database type (postgresql or mysql, required)
        \\  DB_HOST      Database host (default: localhost)
        \\  DB_PORT      Database port (default: 5432 for PostgreSQL, 3306 for MySQL)
        \\  DB_DATABASE  Database name (required)
        \\  DB_USERNAME  Database username (required)
        \\  DB_PASSWORD  Database password (required)
        \\
        \\Examples:
        \\  # Run all seeders from default directory
        \\  DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass seeder run
        \\
        \\  # Run seeders from specific subdirectory
        \\  DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass seeder run development --dir database/seeders
        \\
        \\  # Run seeders from production subdirectory
        \\  DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass seeder run production --dir database/seeders
        \\
        \\  # Run seeders directly from a specific path (no subdirectory)
        \\  DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass seeder run --dir database/seeders/development
        \\
    , .{});
}

fn parseConfig(allocator: std.mem.Allocator) !Config {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    // Parse command
    const command_str = args.next() orelse {
        printHelp();
        return error.NoCommand;
    };

    const command = std.meta.stringToEnum(Command, command_str) orelse {
        std.debug.print("Error: Unknown command '{s}'\n", .{command_str});
        printHelp();
        return error.InvalidCommand;
    };

    if (command == .help) {
        printHelp();
        std.process.exit(0);
    }

    // Parse options and arguments
    var seeders_dir: []const u8 = "database/seeders";
    var subdirectory: ?[]const u8 = null;
    var first_arg = true;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--dir")) {
            seeders_dir = args.next() orelse {
                std.debug.print("Error: --dir requires a path\n", .{});
                return error.InvalidArgument;
            };
        } else if (std.mem.startsWith(u8, arg, "--")) {
            std.debug.print("Error: Unknown option '{s}'\n", .{arg});
            return error.InvalidArgument;
        } else if (first_arg) {
            // First non-option argument is the subdirectory
            subdirectory = arg;
            first_arg = false;
        } else {
            std.debug.print("Error: Unexpected argument '{s}'\n", .{arg});
            return error.InvalidArgument;
        }
    }

    // Get environment variables
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const db_type_str = env_map.get("DB_TYPE") orelse {
        std.debug.print("Error: DB_TYPE environment variable is required\n", .{});
        return error.MissingEnvVar;
    };

    const db_type = if (std.mem.eql(u8, db_type_str, "postgresql"))
        dig.types.DatabaseType.postgresql
    else if (std.mem.eql(u8, db_type_str, "mysql"))
        dig.types.DatabaseType.mysql
    else {
        std.debug.print("Error: DB_TYPE must be 'postgresql' or 'mysql'\n", .{});
        return error.InvalidDbType;
    };

    const db_host_raw = env_map.get("DB_HOST") orelse "localhost";
    const db_host = try allocator.dupe(u8, db_host_raw);

    const db_port_str = env_map.get("DB_PORT");
    const db_port = if (db_port_str) |port_str|
        try std.fmt.parseInt(u16, port_str, 10)
    else switch (db_type) {
        .postgresql => @as(u16, 5432),
        .mysql => @as(u16, 3306),
        .mock => @as(u16, 0), // Mock driver doesn't use a real port
    };

    const db_name_raw = env_map.get("DB_DATABASE") orelse {
        std.debug.print("Error: DB_DATABASE environment variable is required\n", .{});
        return error.MissingEnvVar;
    };
    const db_name = try allocator.dupe(u8, db_name_raw);

    const db_user_raw = env_map.get("DB_USERNAME") orelse {
        std.debug.print("Error: DB_USERNAME environment variable is required\n", .{});
        return error.MissingEnvVar;
    };
    const db_user = try allocator.dupe(u8, db_user_raw);

    const db_password_raw = env_map.get("DB_PASSWORD") orelse {
        std.debug.print("Error: DB_PASSWORD environment variable is required\n", .{});
        return error.MissingEnvVar;
    };
    const db_password = try allocator.dupe(u8, db_password_raw);

    return Config{
        .command = command,
        .seeders_dir = seeders_dir,
        .subdirectory = subdirectory,
        .db_type = db_type,
        .db_host = db_host,
        .db_port = db_port,
        .db_name = db_name,
        .db_user = db_user,
        .db_password = db_password,
    };
}

/// Load all SQL files from seeders directory
fn loadSeedFiles(allocator: std.mem.Allocator, dir_path: []const u8) !std.ArrayList(SeedFile) {
    var seed_files: std.ArrayList(SeedFile) = .{};
    errdefer {
        for (seed_files.items) |*seed_file| {
            seed_file.deinit();
        }
        seed_files.deinit(allocator);
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

        const content = try file.readToEndAlloc(allocator, 1024 * 1024); // Max 1MB
        const name = try allocator.dupe(u8, entry.name);

        const seed_file = SeedFile{
            .name = name,
            .content = content,
            .allocator = allocator,
        };

        try seed_files.append(allocator, seed_file);
    }

    // Sort seed files by name for consistent execution order
    std.mem.sort(SeedFile, seed_files.items, {}, struct {
        fn lessThan(_: void, a: SeedFile, b: SeedFile) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lessThan);

    return seed_files;
}

/// Split SQL content into individual statements
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

/// Execute seed file
fn executeSeedFile(db: *dig.db, seed_file: *const SeedFile, allocator: std.mem.Allocator) !void {
    std.debug.print("Seeding: {s}\n", .{seed_file.name});

    var statements = try splitSqlStatements(allocator, seed_file.content);
    defer {
        for (statements.items) |stmt| {
            allocator.free(stmt);
        }
        statements.deinit(allocator);
    }

    // Execute each statement
    for (statements.items) |stmt| {
        if (stmt.len > 0) {
            // Skip comments
            const trimmed = std.mem.trim(u8, stmt, " \t\n\r");
            if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "--")) {
                try db.execute(stmt);
            }
        }
    }

    std.debug.print("Seeded: {s}\n", .{seed_file.name});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = parseConfig(allocator) catch |err| {
        if (err == error.NoCommand or err == error.InvalidCommand) {
            std.process.exit(1);
        }
        return err;
    };
    defer {
        allocator.free(config.db_host);
        allocator.free(config.db_name);
        allocator.free(config.db_user);
        allocator.free(config.db_password);
    }

    // Connect to database
    std.debug.print("Connecting to database...\n", .{});
    var db = try dig.db.connect(allocator, .{
        .database_type = config.db_type,
        .host = config.db_host,
        .port = config.db_port,
        .database = config.db_name,
        .username = config.db_user,
        .password = config.db_password,
    });
    defer db.disconnect();
    std.debug.print("Connected successfully.\n\n", .{});

    // Build the full path with subdirectory if specified
    const full_path = if (config.subdirectory) |subdir|
        try std.fs.path.join(allocator, &[_][]const u8{ config.seeders_dir, subdir })
    else
        config.seeders_dir;
    defer if (config.subdirectory != null) allocator.free(full_path);

    // Load seed files from directory
    std.debug.print("Loading seed files from '{s}'...\n", .{full_path});
    var seed_files = loadSeedFiles(allocator, full_path) catch |err| {
        std.debug.print("Error loading seed files: {any}\n", .{err});
        return err;
    };
    defer {
        for (seed_files.items) |*seed_file| {
            seed_file.deinit();
        }
        seed_files.deinit(allocator);
    }
    std.debug.print("Loaded {d} seed file(s).\n\n", .{seed_files.items.len});

    if (seed_files.items.len == 0) {
        std.debug.print("No seed files found.\n", .{});
        return;
    }

    // Execute command
    switch (config.command) {
        .run => {
            std.debug.print("Running seeders...\n", .{});
            for (seed_files.items) |*seed_file| {
                executeSeedFile(&db, seed_file, allocator) catch |err| {
                    std.debug.print("Error executing seed file {s}: {any}\n", .{ seed_file.name, err });
                    return err;
                };
            }
        },
        .help => unreachable, // Already handled
    }

    std.debug.print("\nDone. Executed {d} seed file(s).\n", .{seed_files.items.len});
}
