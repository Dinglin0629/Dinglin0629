-- Run while connected to the default "postgres" database:
--   psql -U postgres -f sql/00_create_database.sql

SELECT 'CREATE DATABASE sd6103_housing'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_database WHERE datname = 'sd6103_housing'
)\gexec

\connect sd6103_housing

