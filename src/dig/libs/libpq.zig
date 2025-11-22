//! libpq C API bindings for PostgreSQL

/// PostgreSQL connection handle
pub const PGconn = opaque {};

/// PostgreSQL result handle
pub const PGresult = opaque {};

/// Connection status
pub const ConnStatusType = enum(c_int) {
    CONNECTION_OK = 0,
    CONNECTION_BAD = 1,
    CONNECTION_STARTED = 2,
    CONNECTION_MADE = 3,
    CONNECTION_AWAITING_RESPONSE = 4,
    CONNECTION_AUTH_OK = 5,
    CONNECTION_SETENV = 6,
    CONNECTION_SSL_STARTUP = 7,
    CONNECTION_NEEDED = 8,
    CONNECTION_CHECK_WRITABLE = 9,
    CONNECTION_CONSUME = 10,
    CONNECTION_GSS_STARTUP = 11,
    CONNECTION_CHECK_TARGET = 12,
    CONNECTION_CHECK_STANDBY = 13,
};

/// Query execution status
pub const ExecStatusType = enum(c_int) {
    PGRES_EMPTY_QUERY = 0,
    PGRES_COMMAND_OK = 1,
    PGRES_TUPLES_OK = 2,
    PGRES_COPY_OUT = 3,
    PGRES_COPY_IN = 4,
    PGRES_BAD_RESPONSE = 5,
    PGRES_NONFATAL_ERROR = 6,
    PGRES_FATAL_ERROR = 7,
    PGRES_COPY_BOTH = 8,
    PGRES_SINGLE_TUPLE = 9,
    PGRES_PIPELINE_SYNC = 10,
    PGRES_PIPELINE_ABORTED = 11,
};

/// PostgreSQL data types (Oid)
pub const PG_TYPE_BOOL = 16;
pub const PG_TYPE_INT8 = 20;
pub const PG_TYPE_INT2 = 21;
pub const PG_TYPE_INT4 = 23;
pub const PG_TYPE_TEXT = 25;
pub const PG_TYPE_FLOAT4 = 700;
pub const PG_TYPE_FLOAT8 = 701;
pub const PG_TYPE_VARCHAR = 1043;
pub const PG_TYPE_TIMESTAMP = 1114;
pub const PG_TYPE_TIMESTAMPTZ = 1184;

// Link to libpq
extern "c" fn PQconnectdb(conninfo: [*:0]const u8) ?*PGconn;
extern "c" fn PQfinish(conn: *PGconn) void;
extern "c" fn PQstatus(conn: *PGconn) ConnStatusType;
extern "c" fn PQerrorMessage(conn: *PGconn) [*:0]const u8;
extern "c" fn PQexec(conn: *PGconn, query: [*:0]const u8) ?*PGresult;
extern "c" fn PQresultStatus(res: *PGresult) ExecStatusType;
extern "c" fn PQresultErrorMessage(res: *PGresult) [*:0]const u8;
extern "c" fn PQclear(res: *PGresult) void;
extern "c" fn PQntuples(res: *PGresult) c_int;
extern "c" fn PQnfields(res: *PGresult) c_int;
extern "c" fn PQfname(res: *PGresult, field_num: c_int) [*:0]const u8;
extern "c" fn PQftype(res: *PGresult, field_num: c_int) c_uint;
extern "c" fn PQgetvalue(res: *PGresult, row_num: c_int, field_num: c_int) [*:0]const u8;
extern "c" fn PQgetisnull(res: *PGresult, row_num: c_int, field_num: c_int) c_int;
extern "c" fn PQgetlength(res: *PGresult, row_num: c_int, field_num: c_int) c_int;

/// Zig wrapper for PQconnectdb
pub fn connectdb(conninfo: [*:0]const u8) ?*PGconn {
    return PQconnectdb(conninfo);
}

/// Zig wrapper for PQfinish
pub fn finish(conn: *PGconn) void {
    PQfinish(conn);
}

/// Zig wrapper for PQstatus
pub fn status(conn: *PGconn) ConnStatusType {
    return PQstatus(conn);
}

/// Zig wrapper for PQerrorMessage
pub fn errorMessage(conn: *PGconn) [*:0]const u8 {
    return PQerrorMessage(conn);
}

/// Zig wrapper for PQexec
pub fn exec(conn: *PGconn, query: [*:0]const u8) ?*PGresult {
    return PQexec(conn, query);
}

/// Zig wrapper for PQresultStatus
pub fn resultStatus(res: *PGresult) ExecStatusType {
    return PQresultStatus(res);
}

/// Zig wrapper for PQresultErrorMessage
pub fn resultErrorMessage(res: *PGresult) [*:0]const u8 {
    return PQresultErrorMessage(res);
}

/// Zig wrapper for PQclear
pub fn clear(res: *PGresult) void {
    PQclear(res);
}

/// Zig wrapper for PQntuples
pub fn ntuples(res: *PGresult) c_int {
    return PQntuples(res);
}

/// Zig wrapper for PQnfields
pub fn nfields(res: *PGresult) c_int {
    return PQnfields(res);
}

/// Zig wrapper for PQfname
pub fn fname(res: *PGresult, field_num: c_int) [*:0]const u8 {
    return PQfname(res, field_num);
}

/// Zig wrapper for PQftype
pub fn ftype(res: *PGresult, field_num: c_int) c_uint {
    return PQftype(res, field_num);
}

/// Zig wrapper for PQgetvalue
pub fn getvalue(res: *PGresult, row_num: c_int, field_num: c_int) [*:0]const u8 {
    return PQgetvalue(res, row_num, field_num);
}

/// Zig wrapper for PQgetisnull
pub fn getisnull(res: *PGresult, row_num: c_int, field_num: c_int) bool {
    return PQgetisnull(res, row_num, field_num) != 0;
}

/// Zig wrapper for PQgetlength
pub fn getlength(res: *PGresult, row_num: c_int, field_num: c_int) c_int {
    return PQgetlength(res, row_num, field_num);
}
