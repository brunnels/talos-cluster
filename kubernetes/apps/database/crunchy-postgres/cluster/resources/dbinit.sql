---------- BEGIN DASHBRR ------------
DROP DATABASE IF EXISTS dashbrr;
CREATE DATABASE dashbrr;

-- Connect to the test database
\c dashbrr;

-- Grant all privileges to the dashbrr user
GRANT ALL PRIVILEGES ON DATABASE dashbrr TO dashbrr;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dashbrr;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO dashbrr;
---------- END DASHBRR --------------
