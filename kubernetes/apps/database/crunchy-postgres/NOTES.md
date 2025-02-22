### Crunchypostgres Notes

After you create the cluster you need to login to psql and go into each database under users and do the following

```
-- Connect to the database
\c sonarr_main;

-- Grant all privileges to the dashbrr user
GRANT ALL ON SCHEMA public TO sonabrr;
```

This is because by default users don't have permissions on the public schema

You will also need to do the same thing any time you add a new entry to users list
