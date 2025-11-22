//! MySQL driver implementation

const std = @import("std");
const errors = @import("../errors.zig");
const types = @import("../types.zig");
const connection = @import("../connection.zig").Connection;
const libmysql = @import("../libs/libmysql.zig");

pub const MySQLConnection = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    conn: ?*libmysql.MYSQL = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .conn = null,
        };
    }

    pub fn connectImpl(state: *anyopaque, config: types.ConnectionConfig, allocator: std.mem.Allocator) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));

        // Initialize MySQL connection
        self.conn = libmysql.init(null);
        if (self.conn == null) {
            return errors.DigError.ConnectionFailed;
        }

        // Prepare null-terminated strings for C
        const host_z = try allocator.dupeZ(u8, config.host);
        defer allocator.free(host_z);
        const user_z = try allocator.dupeZ(u8, config.username);
        defer allocator.free(user_z);
        const passwd_z = try allocator.dupeZ(u8, config.password);
        defer allocator.free(passwd_z);
        const db_z = try allocator.dupeZ(u8, config.database);
        defer allocator.free(db_z);

        // Connect to MySQL
        const result = libmysql.realConnect(
            self.conn.?,
            host_z.ptr,
            user_z.ptr,
            passwd_z.ptr,
            db_z.ptr,
            config.port,
            null,
            0,
        );

        if (result == null) {
            const err_msg = libmysql.getError(self.conn.?);
            std.log.err("MySQL connection failed: {s}", .{err_msg});
            libmysql.close(self.conn.?);
            self.conn = null;
            return errors.DigError.ConnectionFailed;
        }
    }

    pub fn disconnectImpl(state: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(state));
        if (self.conn) |conn| {
            libmysql.close(conn);
            self.conn = null;
        }
    }

    pub fn executeImpl(state: *anyopaque, query: []const u8, allocator: std.mem.Allocator) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));

        if (self.conn == null) return errors.DigError.ConnectionFailed;

        // Add null terminator for C
        const query_z = try allocator.dupeZ(u8, query);
        defer allocator.free(query_z);

        // Execute query
        if (libmysql.query(self.conn.?, query_z.ptr) != 0) {
            const err_msg = libmysql.getError(self.conn.?);
            std.log.err("MySQL execute failed: {s}", .{err_msg});
            return errors.DigError.QueryExecutionFailed;
        }
    }

    pub fn queryImpl(state: *anyopaque, query: []const u8, allocator: std.mem.Allocator) errors.DigError!connection.QueryResult {
        const self: *Self = @ptrCast(@alignCast(state));

        if (self.conn == null) return errors.DigError.ConnectionFailed;

        // Add null terminator for C
        const query_z = try allocator.dupeZ(u8, query);
        defer allocator.free(query_z);

        // Execute query
        if (libmysql.query(self.conn.?, query_z.ptr) != 0) {
            const err_msg = libmysql.getError(self.conn.?);
            std.log.err("MySQL query failed: {s}", .{err_msg});
            return errors.DigError.QueryExecutionFailed;
        }

        // Store result
        const result = libmysql.storeResult(self.conn.?);
        if (result == null) {
            const err_msg = libmysql.getError(self.conn.?);
            std.log.err("MySQL store result failed: {s}", .{err_msg});
            return errors.DigError.QueryExecutionFailed;
        }
        defer libmysql.freeResult(result.?);

        // Parse result
        return try parseResult(result.?, allocator);
    }

    /// Parse MySQL result into QueryResult
    fn parseResult(result: *libmysql.MYSQL_RES, allocator: std.mem.Allocator) !connection.QueryResult {
        const num_rows = libmysql.numRows(result);
        const num_cols = libmysql.numFields(result);

        // Parse column names
        const fields = libmysql.fetchFields(result);
        const columns = try allocator.alloc([]const u8, num_cols);
        errdefer allocator.free(columns);

        for (0..num_cols) |i| {
            const field_name = std.mem.span(fields[i].name);
            columns[i] = try allocator.dupe(u8, field_name);
        }

        // Parse rows with column references
        const rows = try allocator.alloc(connection.QueryResult.Row, @intCast(num_rows));
        errdefer {
            for (rows) |row| {
                allocator.free(row.values);
            }
            allocator.free(rows);
        }

        var row_idx: usize = 0;
        while (libmysql.fetchRow(result)) |mysql_row| : (row_idx += 1) {
            const lengths = libmysql.fetchLengths(result);
            const values = try allocator.alloc(types.SqlValue, num_cols);
            errdefer allocator.free(values);

            for (0..num_cols) |col_idx| {
                if (mysql_row[col_idx] == null) {
                    values[col_idx] = types.SqlValue.null;
                } else {
                    const value_ptr = mysql_row[col_idx];
                    const value_len = lengths[col_idx];
                    const value_str = value_ptr[0..@intCast(value_len)];
                    const field_type = fields[col_idx].type;

                    values[col_idx] = try parseValue(value_str, field_type, allocator);
                }
            }

            rows[row_idx] = .{
                .values = values,
                .columns = columns,
            };
        }

        return connection.QueryResult{
            .columns = columns,
            .rows = rows,
            .allocator = allocator,
        };
    }

    /// Parse a single value based on MySQL type
    fn parseValue(value_str: []const u8, mysql_type: libmysql.enum_field_types, allocator: std.mem.Allocator) !types.SqlValue {
        return switch (mysql_type) {
            .MYSQL_TYPE_TINY,
            .MYSQL_TYPE_SHORT,
            .MYSQL_TYPE_LONG,
            .MYSQL_TYPE_LONGLONG,
            .MYSQL_TYPE_INT24,
            => blk: {
                const int_val = std.fmt.parseInt(i64, value_str, 10) catch {
                    break :blk types.SqlValue.null;
                };
                break :blk types.SqlValue{ .integer = int_val };
            },
            .MYSQL_TYPE_FLOAT,
            .MYSQL_TYPE_DOUBLE,
            .MYSQL_TYPE_DECIMAL,
            .MYSQL_TYPE_NEWDECIMAL,
            => blk: {
                const float_val = std.fmt.parseFloat(f64, value_str) catch {
                    break :blk types.SqlValue.null;
                };
                break :blk types.SqlValue{ .float = float_val };
            },
            .MYSQL_TYPE_VARCHAR,
            .MYSQL_TYPE_VAR_STRING,
            .MYSQL_TYPE_STRING,
            .MYSQL_TYPE_JSON,
            => blk: {
                const text = try allocator.dupe(u8, value_str);
                break :blk types.SqlValue{ .text = text };
            },
            .MYSQL_TYPE_BLOB,
            .MYSQL_TYPE_TINY_BLOB,
            .MYSQL_TYPE_MEDIUM_BLOB,
            .MYSQL_TYPE_LONG_BLOB,
            => blk: {
                const blob = try allocator.dupe(u8, value_str);
                break :blk types.SqlValue{ .blob = blob };
            },
            .MYSQL_TYPE_TIMESTAMP,
            .MYSQL_TYPE_DATETIME,
            .MYSQL_TYPE_DATE,
            .MYSQL_TYPE_TIME,
            => blk: {
                // For now, store as text. Could be converted to timestamp later
                const text = try allocator.dupe(u8, value_str);
                break :blk types.SqlValue{ .text = text };
            },
            else => blk: {
                // Default: treat as text
                const text = try allocator.dupe(u8, value_str);
                break :blk types.SqlValue{ .text = text };
            },
        };
    }

    pub fn beginTransactionImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));
        if (self.conn == null) return errors.DigError.ConnectionFailed;

        if (libmysql.query(self.conn.?, "START TRANSACTION") != 0) {
            const err_msg = libmysql.getError(self.conn.?);
            std.log.err("MySQL START TRANSACTION failed: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
    }

    pub fn commitImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));
        if (self.conn == null) return errors.DigError.ConnectionFailed;

        if (libmysql.query(self.conn.?, "COMMIT") != 0) {
            const err_msg = libmysql.getError(self.conn.?);
            std.log.err("MySQL COMMIT failed: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
    }

    pub fn rollbackImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));
        if (self.conn == null) return errors.DigError.ConnectionFailed;

        if (libmysql.query(self.conn.?, "ROLLBACK") != 0) {
            const err_msg = libmysql.getError(self.conn.?);
            std.log.err("MySQL ROLLBACK failed: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
    }

    pub fn toConnection(self: *Self) connection {
        return connection{
            .vtable = &.{
                .connect = connectImpl,
                .disconnect = disconnectImpl,
                .execute = executeImpl,
                .query = queryImpl,
                .beginTransaction = beginTransactionImpl,
                .commit = commitImpl,
                .rollback = rollbackImpl,
            },
            .state = self,
        };
    }
};
