const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options for database drivers
    const enable_postgresql = b.option(bool, "postgresql", "Enable PostgreSQL driver (default: false)") orelse false;
    const enable_mysql = b.option(bool, "mysql", "Enable MySQL driver (default: false)") orelse false;

    // Create build options
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_postgresql", enable_postgresql);
    build_options.addOption(bool, "enable_mysql", enable_mysql);

    // Create dig module (can be obtained externally with `dependency.module("dig")`)
    const dig_module = b.addModule("dig", .{
        .root_source_file = b.path("src/dig.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Import build options
    dig_module.addImport("build_options", build_options.createModule());

    // Link PostgreSQL library (libpq) if enabled
    if (enable_postgresql) {
        dig_module.linkSystemLibrary("pq", .{});
    }

    // Link MySQL library (libmysqlclient) if enabled
    if (enable_mysql) {
        dig_module.linkSystemLibrary("mysqlclient", .{});
    }

    // Migration CLI tool executable
    const migrate_module = b.createModule(.{
        .root_source_file = b.path("src/migrate.zig"),
        .target = target,
        .optimize = optimize,
    });
    migrate_module.addImport("dig", dig_module);

    const migrate_exe = b.addExecutable(.{
        .name = "migrate",
        .root_module = migrate_module,
    });
    migrate_exe.linkLibC();

    // Link enabled database libraries
    if (enable_postgresql) {
        migrate_exe.linkSystemLibrary("pq");
    }
    if (enable_mysql) {
        migrate_exe.linkSystemLibrary("mysqlclient");
    }

    // Install migrate executable
    b.installArtifact(migrate_exe);

    // Individual test files
    const test_files = [_][]const u8{
        "src/tests/query_test.zig",
        "src/tests/schema_test.zig",
        "src/tests/types_test.zig",
        "src/tests/integration_test.zig",
        "src/tests/errors_test.zig",
        "src/tests/connection_test.zig",
    };

    // Step to run all tests
    const test_step = b.step("test", "Run all unit tests");

    for (test_files) |test_file| {
        const test_module = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });
        test_module.addImport("dig", dig_module);
        test_module.addImport("build_options", build_options.createModule());

        const test_exe = b.addTest(.{
            .root_module = test_module,
        });
        test_exe.linkLibC();

        // Link only enabled drivers
        if (enable_postgresql) {
            test_exe.linkSystemLibrary("pq");
        }
        if (enable_mysql) {
            test_exe.linkSystemLibrary("mysqlclient");
        }

        const run_test = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test.step);
    }
}
