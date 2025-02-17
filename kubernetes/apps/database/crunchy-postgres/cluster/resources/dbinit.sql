---------- BEGIN DASHBRR ------------
DROP DATABASE IF EXISTS dashbrr;
CREATE DATABASE dashbrr;

-- Connect to the test database
\c dashbrr;

-- Grant all privileges to the dashbrr user
GRANT ALL ON SCHEMA public TO dashbrr;
---------- END DASHBRR --------------
