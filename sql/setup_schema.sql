-- Lakebase schema setup for david-lakebase-iac

CREATE EXTENSION IF NOT EXISTS databricks_auth;

CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.example (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

SELECT databricks_create_role('fake.user@fakecorp.com', 'USER');
GRANT USAGE ON SCHEMA app TO "fake.user@fakecorp.com";
GRANT SELECT ON ALL TABLES IN SCHEMA app TO "fake.user@fakecorp.com";
