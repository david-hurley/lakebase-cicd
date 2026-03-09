-- ---------------------------------------------------------------------------
-- Schema migrations for the customer_service_app database.
--
-- This file is executed by post_deploy.sh against the production branch
-- endpoint after every deploy.  All statements are idempotent so the
-- script can be re-run safely.
-- ---------------------------------------------------------------------------

-- Enable Databricks-native authentication (SSO pass-through).
CREATE EXTENSION IF NOT EXISTS databricks_auth;

-- Map the Databricks workspace group to a Postgres role and grant read
-- access to the app schema so team members can query data directly.
SELECT databricks_create_role('lakebase-developers', 'GROUP');
GRANT USAGE ON SCHEMA app TO "lakebase-developers";
GRANT SELECT ON ALL TABLES IN SCHEMA app TO "lakebase-developers";

-- Application schema and tables.
CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
