---------- BEGIN DASHBRR ------------
DROP DATABASE IF EXISTS dashbrr;
CREATE DATABASE dashbrr;

-- Connect to the test database
\c dashbrr;

-- Create the necessary tables
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS service_configurations (
    id SERIAL PRIMARY KEY,
    instance_id TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    url TEXT,
    api_key TEXT,
    access_url TEXT
);

-- Grant all privileges to the dashbrr user
GRANT ALL PRIVILEGES ON DATABASE dashbrr TO dashbrr;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dashbrr;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO dashbrr;
---------- END DASHBRR ------------
