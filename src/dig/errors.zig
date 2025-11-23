//! Error definitions for Dig ORM

pub const DigError = error{
    ConnectionFailed,
    QueryExecutionFailed,
    InvalidQuery,
    InvalidSchema,
    TypeMismatch,
    NotFound,
    TransactionFailed,
    InvalidConnectionString,
    UnsupportedDatabase,
    InvalidParameter,
    OutOfMemory,
    QueryBuildError,
};
