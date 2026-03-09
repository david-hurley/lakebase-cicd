#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Post-deploy configuration for the Lakebase project.
#
# Called by the "configure" job in deploy-configure-lakebase.yml after the
# bundle has been deployed.  It performs three tasks:
#   1. Grants workspace-level CAN_USE permission to the "lakebase-developers"
#      group so team members can connect.
#   2. Marks the production branch as protected to prevent accidental writes.
#   3. Creates the application database (if it doesn't exist) and runs
#      schema migrations via psql.
#
# Usage:
#   bash scripts/post_deploy.sh <project-name>
# ---------------------------------------------------------------------------

PROJECT_NAME="${1:-$PROJECT_NAME}"
if [ -z "$PROJECT_NAME" ]; then
  echo "Error: PROJECT_NAME is required. Pass as argument or set as env var."
  exit 1
fi

# --- 1. Workspace permissions -----------------------------------------------

echo "Assigning Lakebase instance permissions..."

PROJECT_UID=$(
  databricks postgres get-project "projects/$PROJECT_NAME" -o json \
    | jq -r '.uid'
)

databricks permissions update database-projects "$PROJECT_UID" \
  --json '{
    "access_control_list": [
      {
        "group_name": "lakebase-developers",
        "permission_level": "CAN_USE"
      }
    ]
  }'

# --- 2. Protect production branch -------------------------------------------

echo "Protecting production branch..."

IS_PROTECTED=$(
  databricks postgres get-branch "projects/$PROJECT_NAME/branches/production" -o json \
    | jq -r '.status.is_protected'
)

if [ "$IS_PROTECTED" = "true" ]; then
  echo "Already protected, skipping."
else
  databricks postgres update-branch \
    "projects/$PROJECT_NAME/branches/production" \
    spec.is_protected \
    --json '{
      "spec": {
        "is_protected": true
      }
    }'
fi

# --- 3. Database creation & schema migrations --------------------------------

echo "Running database setup..."

HOST=$(
  databricks postgres get-endpoint "projects/$PROJECT_NAME/branches/production/endpoints/primary" -o json \
    | jq -r '.status.hosts.host'
)

DB_TOKEN=$(
  databricks postgres generate-database-credential \
    "projects/$PROJECT_NAME/branches/production/endpoints/primary" -o json \
    | jq -r '.token'
)

DB_USER=$(
  databricks current-user me -o json \
    | jq -r '.userName'
)

CONN="host=$HOST port=5432 user=$DB_USER sslmode=require"

echo "Creating database customer_service_app (if not exists)..."

PGPASSWORD=$DB_TOKEN psql "$CONN dbname=postgres" \
  -tc "SELECT 1 FROM pg_database WHERE datname = 'customer_service_app'" | grep -q 1 \
  || PGPASSWORD=$DB_TOKEN psql "$CONN dbname=postgres" \
       -c "CREATE DATABASE customer_service_app;"

echo "Running schema setup..."

PGPASSWORD=$DB_TOKEN psql "$CONN dbname=customer_service_app" \
  -f scripts/migrations.sql
