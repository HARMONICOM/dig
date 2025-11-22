//! Tests for error handling

const std = @import("std");
const testing = std.testing;
const dig = @import("dig");

test "DigError: error set exists" {
    // Verify that DigError is defined
    _ = dig.errors.DigError;
}

test "DigError: all error types are accessible" {
    // Test that all error types can be referenced by using them in a function
    const test_fn = struct {
        fn testError() dig.errors.DigError!void {
            return dig.errors.DigError.ConnectionFailed;
        }
    }.testError;

    const result = test_fn();
    try testing.expectError(dig.errors.DigError.ConnectionFailed, result);

    // Test each error type by creating functions that return them
    const test_errors = struct {
        fn testConnectionFailed() dig.errors.DigError!void {
            return dig.errors.DigError.ConnectionFailed;
        }
        fn testQueryExecutionFailed() dig.errors.DigError!void {
            return dig.errors.DigError.QueryExecutionFailed;
        }
        fn testInvalidQuery() dig.errors.DigError!void {
            return dig.errors.DigError.InvalidQuery;
        }
        fn testInvalidSchema() dig.errors.DigError!void {
            return dig.errors.DigError.InvalidSchema;
        }
        fn testTypeMismatch() dig.errors.DigError!void {
            return dig.errors.DigError.TypeMismatch;
        }
        fn testNotFound() dig.errors.DigError!void {
            return dig.errors.DigError.NotFound;
        }
        fn testTransactionFailed() dig.errors.DigError!void {
            return dig.errors.DigError.TransactionFailed;
        }
        fn testInvalidConnectionString() dig.errors.DigError!void {
            return dig.errors.DigError.InvalidConnectionString;
        }
        fn testUnsupportedDatabase() dig.errors.DigError!void {
            return dig.errors.DigError.UnsupportedDatabase;
        }
        fn testInvalidParameter() dig.errors.DigError!void {
            return dig.errors.DigError.InvalidParameter;
        }
        fn testOutOfMemory() dig.errors.DigError!void {
            return dig.errors.DigError.OutOfMemory;
        }
    };

    // All functions compile, meaning all error types exist
    _ = test_errors.testConnectionFailed;
    _ = test_errors.testQueryExecutionFailed;
    _ = test_errors.testInvalidQuery;
    _ = test_errors.testInvalidSchema;
    _ = test_errors.testTypeMismatch;
    _ = test_errors.testNotFound;
    _ = test_errors.testTransactionFailed;
    _ = test_errors.testInvalidConnectionString;
    _ = test_errors.testUnsupportedDatabase;
    _ = test_errors.testInvalidParameter;
    _ = test_errors.testOutOfMemory;
}
