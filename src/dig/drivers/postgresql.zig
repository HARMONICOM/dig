//! PostgreSQL driver implementation

const std = @import("std");
const errors = @import("../errors.zig");
const types = @import("../types.zig");
const connection = @import("../connection.zig").Connection;
const libpq = @import("../libs/libpq.zig");

pub const PostgreSQLConnection = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    conn: ?*libpq.PGconn = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .conn = null,
        };
    }

    pub fn connectImpl(state: *anyopaque, config: types.ConnectionConfig, allocator: std.mem.Allocator) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));

        // Build connection string
        const conn_string = try config.toConnectionString(allocator);
        defer allocator.free(conn_string);

        // Add null terminator for C
        const conn_string_z = try allocator.dupeZ(u8, conn_string);
        defer allocator.free(conn_string_z);

        // Connect to database
        self.conn = libpq.connectdb(conn_string_z.ptr);
        if (self.conn == null) {
            return errors.DigError.ConnectionFailed;
        }

        // Check connection status
        if (libpq.status(self.conn.?) != .CONNECTION_OK) {
            const err_msg = libpq.errorMessage(self.conn.?);
            std.log.err("PostgreSQL connection failed: {s}", .{err_msg});
            libpq.finish(self.conn.?);
            self.conn = null;
            return errors.DigError.ConnectionFailed;
        }
    }

    pub fn disconnectImpl(state: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(state));
        if (self.conn) |conn| {
            libpq.finish(conn);
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
        const result = libpq.exec(self.conn.?, query_z.ptr);
        if (result == null) {
            const err_msg = libpq.errorMessage(self.conn.?);
            std.log.err("PostgreSQL execute failed: {s}", .{err_msg});
            return errors.DigError.QueryExecutionFailed;
        }
        defer libpq.clear(result.?);

        // Check result status
        const status = libpq.resultStatus(result.?);
        if (status != .PGRES_COMMAND_OK and status != .PGRES_TUPLES_OK) {
            const err_msg = libpq.resultErrorMessage(result.?);
            std.log.err("PostgreSQL execute status error: {s}", .{err_msg});
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
        const result = libpq.exec(self.conn.?, query_z.ptr);
        if (result == null) {
            const err_msg = libpq.errorMessage(self.conn.?);
            std.log.err("PostgreSQL query failed: {s}", .{err_msg});
            return errors.DigError.QueryExecutionFailed;
        }
        defer libpq.clear(result.?);

        // Check result status
        const status = libpq.resultStatus(result.?);
        if (status != .PGRES_TUPLES_OK) {
            const err_msg = libpq.resultErrorMessage(result.?);
            std.log.err("PostgreSQL query status error: {s}", .{err_msg});
            return errors.DigError.QueryExecutionFailed;
        }

        // Parse result
        return try parseResult(result.?, allocator);
    }

    /// Parse PostgreSQL result into QueryResult
    fn parseResult(result: *libpq.PGresult, allocator: std.mem.Allocator) !connection.QueryResult {
        const num_rows = libpq.ntuples(result);
        const num_cols = libpq.nfields(result);

        // Parse column names
        const columns = try allocator.alloc([]const u8, @intCast(num_cols));
        errdefer allocator.free(columns);

        for (0..@intCast(num_cols)) |i| {
            const col_name = libpq.fname(result, @intCast(i));
            const col_name_len = std.mem.len(col_name);
            columns[i] = try allocator.dupe(u8, col_name[0..col_name_len]);
        }

        // Parse rows with column references
        const rows = try allocator.alloc(connection.QueryResult.Row, @intCast(num_rows));
        errdefer {
            for (rows) |row| {
                allocator.free(row.values);
            }
            allocator.free(rows);
        }

        for (0..@intCast(num_rows)) |row_idx| {
            const values = try allocator.alloc(types.SqlValue, @intCast(num_cols));
            errdefer allocator.free(values);

            for (0..@intCast(num_cols)) |col_idx| {
                const is_null = libpq.getisnull(result, @intCast(row_idx), @intCast(col_idx));

                if (is_null) {
                    values[col_idx] = types.SqlValue.null;
                } else {
                    const value_ptr = libpq.getvalue(result, @intCast(row_idx), @intCast(col_idx));
                    const value_len = libpq.getlength(result, @intCast(row_idx), @intCast(col_idx));
                    const value_str = value_ptr[0..@intCast(value_len)];
                    const pg_type = libpq.ftype(result, @intCast(col_idx));

                    values[col_idx] = try parseValue(value_str, pg_type, allocator);
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

    /// Parse a single value based on PostgreSQL type
    fn parseValue(value_str: []const u8, pg_type: c_uint, allocator: std.mem.Allocator) !types.SqlValue {
        return switch (pg_type) {
            libpq.PG_TYPE_BOOL => blk: {
                const is_true = std.mem.eql(u8, value_str, "t") or
                    std.mem.eql(u8, value_str, "true") or
                    std.mem.eql(u8, value_str, "1");
                break :blk types.SqlValue{ .boolean = is_true };
            },
            libpq.PG_TYPE_INT2, libpq.PG_TYPE_INT4, libpq.PG_TYPE_INT8 => blk: {
                const int_val = std.fmt.parseInt(i64, value_str, 10) catch {
                    break :blk types.SqlValue.null;
                };
                break :blk types.SqlValue{ .integer = int_val };
            },
            libpq.PG_TYPE_FLOAT4, libpq.PG_TYPE_FLOAT8 => blk: {
                const float_val = std.fmt.parseFloat(f64, value_str) catch {
                    break :blk types.SqlValue.null;
                };
                break :blk types.SqlValue{ .float = float_val };
            },
            libpq.PG_TYPE_TEXT, libpq.PG_TYPE_VARCHAR => blk: {
                const text = try allocator.dupe(u8, value_str);
                break :blk types.SqlValue{ .text = text };
            },
            libpq.PG_TYPE_TIMESTAMP, libpq.PG_TYPE_TIMESTAMPTZ => blk: {
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

        const result = libpq.exec(self.conn.?, "BEGIN");
        if (result == null) {
            const err_msg = libpq.errorMessage(self.conn.?);
            std.log.err("PostgreSQL BEGIN failed: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
        defer libpq.clear(result.?);

        const status = libpq.resultStatus(result.?);
        if (status != .PGRES_COMMAND_OK) {
            const err_msg = libpq.resultErrorMessage(result.?);
            std.log.err("PostgreSQL BEGIN status error: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
    }

    pub fn commitImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));
        if (self.conn == null) return errors.DigError.ConnectionFailed;

        const result = libpq.exec(self.conn.?, "COMMIT");
        if (result == null) {
            const err_msg = libpq.errorMessage(self.conn.?);
            std.log.err("PostgreSQL COMMIT failed: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
        defer libpq.clear(result.?);

        const status = libpq.resultStatus(result.?);
        if (status != .PGRES_COMMAND_OK) {
            const err_msg = libpq.resultErrorMessage(result.?);
            std.log.err("PostgreSQL COMMIT status error: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
    }

    pub fn rollbackImpl(state: *anyopaque) errors.DigError!void {
        const self: *Self = @ptrCast(@alignCast(state));
        if (self.conn == null) return errors.DigError.ConnectionFailed;

        const result = libpq.exec(self.conn.?, "ROLLBACK");
        if (result == null) {
            const err_msg = libpq.errorMessage(self.conn.?);
            std.log.err("PostgreSQL ROLLBACK failed: {s}", .{err_msg});
            return errors.DigError.TransactionFailed;
        }
        defer libpq.clear(result.?);

        const status = libpq.resultStatus(result.?);
        if (status != .PGRES_COMMAND_OK) {
            const err_msg = libpq.resultErrorMessage(result.?);
            std.log.err("PostgreSQL ROLLBACK status error: {s}", .{err_msg});
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
