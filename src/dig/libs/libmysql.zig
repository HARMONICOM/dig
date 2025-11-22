//! libmysqlclient C API bindings for MySQL

/// MySQL connection handle
pub const MYSQL = opaque {};

/// MySQL result handle
pub const MYSQL_RES = opaque {};

/// MySQL row (array of strings)
pub const MYSQL_ROW = [*c][*c]u8;

/// MySQL field structure
pub const MYSQL_FIELD = extern struct {
    name: [*c]u8,
    org_name: [*c]u8,
    table: [*c]u8,
    org_table: [*c]u8,
    db: [*c]u8,
    catalog: [*c]u8,
    def: [*c]u8,
    length: c_ulong,
    max_length: c_ulong,
    name_length: c_uint,
    org_name_length: c_uint,
    table_length: c_uint,
    org_table_length: c_uint,
    db_length: c_uint,
    catalog_length: c_uint,
    def_length: c_uint,
    flags: c_uint,
    decimals: c_uint,
    charsetnr: c_uint,
    type: enum_field_types,
    extension: ?*anyopaque,
};

/// MySQL field types
pub const enum_field_types = enum(c_int) {
    MYSQL_TYPE_DECIMAL = 0,
    MYSQL_TYPE_TINY = 1,
    MYSQL_TYPE_SHORT = 2,
    MYSQL_TYPE_LONG = 3,
    MYSQL_TYPE_FLOAT = 4,
    MYSQL_TYPE_DOUBLE = 5,
    MYSQL_TYPE_NULL = 6,
    MYSQL_TYPE_TIMESTAMP = 7,
    MYSQL_TYPE_LONGLONG = 8,
    MYSQL_TYPE_INT24 = 9,
    MYSQL_TYPE_DATE = 10,
    MYSQL_TYPE_TIME = 11,
    MYSQL_TYPE_DATETIME = 12,
    MYSQL_TYPE_YEAR = 13,
    MYSQL_TYPE_NEWDATE = 14,
    MYSQL_TYPE_VARCHAR = 15,
    MYSQL_TYPE_BIT = 16,
    MYSQL_TYPE_TIMESTAMP2 = 17,
    MYSQL_TYPE_DATETIME2 = 18,
    MYSQL_TYPE_TIME2 = 19,
    MYSQL_TYPE_TYPED_ARRAY = 20,
    MYSQL_TYPE_JSON = 245,
    MYSQL_TYPE_NEWDECIMAL = 246,
    MYSQL_TYPE_ENUM = 247,
    MYSQL_TYPE_SET = 248,
    MYSQL_TYPE_TINY_BLOB = 249,
    MYSQL_TYPE_MEDIUM_BLOB = 250,
    MYSQL_TYPE_LONG_BLOB = 251,
    MYSQL_TYPE_BLOB = 252,
    MYSQL_TYPE_VAR_STRING = 253,
    MYSQL_TYPE_STRING = 254,
    MYSQL_TYPE_GEOMETRY = 255,
};

// Link to libmysqlclient
extern "c" fn mysql_init(mysql: ?*MYSQL) ?*MYSQL;
extern "c" fn mysql_real_connect(
    mysql: *MYSQL,
    host: [*c]const u8,
    user: [*c]const u8,
    passwd: [*c]const u8,
    db: [*c]const u8,
    port: c_uint,
    unix_socket: [*c]const u8,
    clientflag: c_ulong,
) ?*MYSQL;
extern "c" fn mysql_close(sock: *MYSQL) void;
extern "c" fn mysql_error(mysql: *MYSQL) [*c]const u8;
extern "c" fn mysql_query(mysql: *MYSQL, q: [*c]const u8) c_int;
extern "c" fn mysql_store_result(mysql: *MYSQL) ?*MYSQL_RES;
extern "c" fn mysql_free_result(result: *MYSQL_RES) void;
extern "c" fn mysql_num_rows(res: *MYSQL_RES) c_ulonglong;
extern "c" fn mysql_num_fields(res: *MYSQL_RES) c_uint;
extern "c" fn mysql_fetch_row(result: *MYSQL_RES) MYSQL_ROW;
extern "c" fn mysql_fetch_fields(result: *MYSQL_RES) [*c]MYSQL_FIELD;
extern "c" fn mysql_fetch_lengths(result: *MYSQL_RES) [*c]c_ulong;

/// Zig wrapper for mysql_init
pub fn init(mysql: ?*MYSQL) ?*MYSQL {
    return mysql_init(mysql);
}

/// Zig wrapper for mysql_real_connect
pub fn realConnect(
    mysql: *MYSQL,
    host: [*c]const u8,
    user: [*c]const u8,
    passwd: [*c]const u8,
    db: [*c]const u8,
    port: c_uint,
    unix_socket: [*c]const u8,
    clientflag: c_ulong,
) ?*MYSQL {
    return mysql_real_connect(mysql, host, user, passwd, db, port, unix_socket, clientflag);
}

/// Zig wrapper for mysql_close
pub fn close(sock: *MYSQL) void {
    mysql_close(sock);
}

/// Zig wrapper for mysql_error
pub fn getError(mysql: *MYSQL) [*c]const u8 {
    return mysql_error(mysql);
}

/// Zig wrapper for mysql_query
pub fn query(mysql: *MYSQL, q: [*c]const u8) c_int {
    return mysql_query(mysql, q);
}

/// Zig wrapper for mysql_store_result
pub fn storeResult(mysql: *MYSQL) ?*MYSQL_RES {
    return mysql_store_result(mysql);
}

/// Zig wrapper for mysql_free_result
pub fn freeResult(result: *MYSQL_RES) void {
    mysql_free_result(result);
}

/// Zig wrapper for mysql_num_rows
pub fn numRows(res: *MYSQL_RES) c_ulonglong {
    return mysql_num_rows(res);
}

/// Zig wrapper for mysql_num_fields
pub fn numFields(res: *MYSQL_RES) c_uint {
    return mysql_num_fields(res);
}

/// Zig wrapper for mysql_fetch_row
pub fn fetchRow(result: *MYSQL_RES) ?MYSQL_ROW {
    const row = mysql_fetch_row(result);
    // MYSQL_ROW is [*c][*c]u8, which is C-compatible and can be null
    // Check if the returned pointer is null
    if (@intFromPtr(row) == 0) return null;
    return row;
}

/// Zig wrapper for mysql_fetch_fields
pub fn fetchFields(result: *MYSQL_RES) [*c]MYSQL_FIELD {
    return mysql_fetch_fields(result);
}

/// Zig wrapper for mysql_fetch_lengths
pub fn fetchLengths(result: *MYSQL_RES) [*c]c_ulong {
    return mysql_fetch_lengths(result);
}
