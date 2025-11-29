//! Main database interface

const std = @import("std");
const build_options = @import("build_options");
const errors = @import("errors.zig");
const types = @import("types.zig");
const connection = @import("connection.zig");
const query_builder = @import("queryBuilder.zig");

const postgresql = if (build_options.enable_postgresql) @import("drivers/postgresql.zig") else void;
const mysql = if (build_options.enable_mysql) @import("drivers/mysql.zig") else void;
const mock = @import("drivers/mock.zig");

/// Database instance
pub const Db = struct {
    const Self = @This();

    conn: connection.Connection,
    db_type: types.DatabaseType,
    allocator: std.mem.Allocator,
    conn_state: *anyopaque, // Store connection state pointer for cleanup
    query_builder: ?query_builder.QueryBuilder = null, // Query builder instance for method chaining

    /// Create a new database connection
    pub fn connect(allocator: std.mem.Allocator, config: types.ConnectionConfig) errors.DigError!Self {
        var instance: Self = .{
            .db_type = config.database_type,
            .allocator = allocator,
            .conn = undefined,
            .conn_state = undefined,
            .query_builder = null,
        };

        switch (config.database_type) {
            .postgresql => {
                if (!build_options.enable_postgresql) {
                    std.log.err("PostgreSQL driver is not enabled. Rebuild with -Dpostgresql=true", .{});
                    return errors.DigError.UnsupportedDatabase;
                }
                const pg_conn = try allocator.create(postgresql.PostgreSQLConnection);
                pg_conn.* = postgresql.PostgreSQLConnection.init(allocator);
                instance.conn = pg_conn.toConnection();
                instance.conn_state = pg_conn;
                try instance.conn.connect(config, allocator);
            },
            .mysql => {
                if (!build_options.enable_mysql) {
                    std.log.err("MySQL driver is not enabled. Rebuild with -Dmysql=true", .{});
                    return errors.DigError.UnsupportedDatabase;
                }
                const mysql_conn = try allocator.create(mysql.MySQLConnection);
                mysql_conn.* = mysql.MySQLConnection.init(allocator);
                instance.conn = mysql_conn.toConnection();
                instance.conn_state = mysql_conn;
                try instance.conn.connect(config, allocator);
            },
            .mock => {
                const mock_conn = try allocator.create(mock.MockConnection);
                mock_conn.* = mock.MockConnection.init(allocator);
                instance.conn = mock_conn.toConnection();
                instance.conn_state = mock_conn;
                try instance.conn.connect(config, allocator);
            },
        }

        return instance;
    }

    /// Disconnect from database
    pub fn disconnect(self: *Self) void {
        if (self.query_builder) |*qb| {
            qb.deinit();
            self.query_builder = null;
        }
        self.conn.disconnect();
        switch (self.db_type) {
            .postgresql => {
                if (build_options.enable_postgresql) {
                    const pg_conn: *postgresql.PostgreSQLConnection = @ptrCast(@alignCast(self.conn_state));
                    self.allocator.destroy(pg_conn);
                }
            },
            .mysql => {
                if (build_options.enable_mysql) {
                    const mysql_conn: *mysql.MySQLConnection = @ptrCast(@alignCast(self.conn_state));
                    self.allocator.destroy(mysql_conn);
                }
            },
            .mock => {
                const mock_conn: *mock.MockConnection = @ptrCast(@alignCast(self.conn_state));
                mock_conn.deinit();
                self.allocator.destroy(mock_conn);
            },
        }
    }

    /// Execute a raw SQL query
    pub fn execute(self: *Self, sql_query: []const u8) errors.DigError!void {
        return self.conn.execute(sql_query, self.allocator);
    }

    /// Execute a raw SQL query and return results
    pub fn query(self: *Self, sql_query: []const u8) errors.DigError!connection.Connection.QueryResult {
        return self.conn.query(sql_query, self.allocator);
    }

    /// Begin a transaction
    pub fn beginTransaction(self: *Self) errors.DigError!void {
        return self.conn.beginTransaction();
    }

    /// Commit a transaction
    pub fn commit(self: *Self) errors.DigError!void {
        return self.conn.commit();
    }

    /// Rollback a transaction
    pub fn rollback(self: *Self) errors.DigError!void {
        return self.conn.rollback();
    }

    /// Start a query builder for a table
    /// Returns a pointer to QueryBuilder that can be used to chain query methods
    /// and execute them directly on this connection
    ///
    /// Example:
    /// ```zig
    /// var result = try db.table("users")
    ///     .select(&.{"id", "name"})
    ///     .where("age", ">", .{.integer = 18})
    ///     .orderBy("name", .asc)
    ///     .get();
    /// defer result.deinit();
    /// ```
    pub fn table(self: *Self, table_name: []const u8) *query_builder.QueryBuilder {
        // Clean up existing query builder if present
        if (self.query_builder) |*qb| {
            qb.deinit();
        }
        self.query_builder = query_builder.QueryBuilder.init(&self.conn, table_name, self.db_type, self.allocator);
        return &self.query_builder.?;
    }
};
