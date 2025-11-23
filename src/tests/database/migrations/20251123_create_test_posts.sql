-- Test migration: Create test posts table

-- up
CREATE TABLE test_posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT
);

-- down
DROP TABLE IF EXISTS test_posts;

