//! Migration CLI tool example
//!
//! This is an example of a standalone migration tool that can be used
//! in projects using Dig ORM.
//!
//! Usage:
//!   migrate up [--dir <migrations_dir>]     Run pending migrations
//!   migrate down [--dir <migrations_dir>]   Rollback last batch
//!   migrate reset [--dir <migrations_dir>]  Reset all migrations
//!   migrate status [--dir <migrations_dir>] Show migration status
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
    up,
    down,
    reset,
    status,
    help,
};

const Config = struct {
    command: Command,
    migrations_dir: []const u8,
    db_type: dig.types.DatabaseType,
    db_host: []const u8,
    db_port: u16,
    db_name: []const u8,
    db_user: []const u8,
    db_password: []const u8,
};

fn printHelp() void {
    std.debug.print(
        \\Migration CLI Tool
        \\
        \\Usage:
        \\  migrate up [--dir <migrations_dir>]     Run pending migrations
        \\  migrate down [--dir <migrations_dir>]   Rollback last batch
        \\  migrate reset [--dir <migrations_dir>]  Reset all migrations
        \\  migrate status [--dir <migrations_dir>] Show migration status
        \\  migrate help                            Show this help
        \\
        \\Options:
        \\  --dir <path>  Path to migrations directory (default: migrations)
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
        \\  # Run migrations
        \\  DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass migrate up
        \\
        \\  # Rollback last batch
        \\  DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass migrate down
        \\
        \\  # Check status
        \\  DB_TYPE=postgresql DB_DATABASE=mydb DB_USERNAME=user DB_PASSWORD=pass migrate status
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

    // Parse options
    var migrations_dir: []const u8 = "migrations";
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--dir")) {
            migrations_dir = args.next() orelse {
                std.debug.print("Error: --dir requires a path\n", .{});
                return error.InvalidArgument;
            };
        } else {
            std.debug.print("Error: Unknown option '{s}'\n", .{arg});
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
        .migrations_dir = migrations_dir,
        .db_type = db_type,
        .db_host = db_host,
        .db_port = db_port,
        .db_name = db_name,
        .db_user = db_user,
        .db_password = db_password,
    };
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

    // Initialize migration manager
    var manager = dig.migration.Manager.init(&db, allocator);

    // Load migrations from directory
    std.debug.print("Loading migrations from '{s}'...\n", .{config.migrations_dir});
    var migrations = manager.loadFromDirectory(config.migrations_dir) catch |err| {
        std.debug.print("Error loading migrations: {any}\n", .{err});
        return err;
    };
    defer {
        for (migrations.items) |*migration| {
            migration.deinit();
        }
        migrations.deinit(allocator);
    }
    std.debug.print("Loaded {d} migration(s).\n\n", .{migrations.items.len});

    // Execute command
    switch (config.command) {
        .up => {
            std.debug.print("Running migrations...\n", .{});
            try manager.migrate(migrations.items);
        },
        .down => {
            std.debug.print("Rolling back last batch...\n", .{});
            try manager.rollback(migrations.items);
        },
        .reset => {
            std.debug.print("Resetting all migrations...\n", .{});
            try manager.reset(migrations.items);
        },
        .status => {
            std.debug.print("Migration status:\n", .{});
            try manager.status(migrations.items);
        },
        .help => unreachable, // Already handled
    }

    std.debug.print("\nDone.\n", .{});
}
