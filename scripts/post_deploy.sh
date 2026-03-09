#!/usr/bin/env bash

PROJECT_NAME="${1:-$PROJECT_NAME}"
if [ -z "$PROJECT_NAME" ]; then
  echo "Error: PROJECT_NAME is required. Pass as argument or set as env var."
  exit 1
fi

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

echo "Running database setup..."

HOST=$(
  databricks postgres list-endpoints "projects/$PROJECT_NAME/branches/production" -o json \
    | jq -r '.[0].status.hosts.host'
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
