-- Test migration: Add columns to test users

-- up
ALTER TABLE test_users ADD COLUMN created_at TIMESTAMP;
ALTER TABLE test_users ADD COLUMN updated_at TIMESTAMP;

-- down
ALTER TABLE test_users DROP COLUMN created_at;
ALTER TABLE test_users DROP COLUMN updated_at;

