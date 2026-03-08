#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="david-lakebase-iac"
BRANCH="projects/${PROJECT_ID}/branches/production"
ENDPOINT="${BRANCH}/endpoints/primary"

# --- Protect production branch (idempotent) ---
echo "=== Protecting production branch ==="
IS_PROTECTED=$(databricks postgres get-branch "$BRANCH" -o json \
  | python3 -c "
import sys, json
b = json.load(sys.stdin)
print(str(b.get('status', {}).get('is_protected', False)).lower())
")

if [[ "$IS_PROTECTED" == "true" ]]; then
  echo "Already protected, skipping."
else
  databricks postgres update-branch "$BRANCH" spec.is_protected \
    --json '{"spec": {"is_protected": true}}'
fi

# --- Grant CAN_USE permission ---
echo ""
echo "=== Granting CAN_USE to fake.user@fakecorp.com ==="
PROJECT_UID=$(databricks postgres get-project "projects/${PROJECT_ID}" -o json \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['uid'])")

databricks permissions update database-projects "$PROJECT_UID" \
  --json '{
    "access_control_list": [
      {"user_name": "fake.user@fakecorp.com", "permission_level": "CAN_USE"}
    ]
  }'

# --- Connect and run SQL ---
echo ""
echo "=== Connecting to production endpoint ==="
HOST=$(databricks postgres get-endpoint "$ENDPOINT" -o json \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['status']['hosts']['host'])")
TOKEN=$(databricks postgres generate-database-credential "$ENDPOINT" -o json \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")
USER=$(databricks current-user me -o json \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['userName'])")

echo "Host: ${HOST}"
echo "User: ${USER}"

echo ""
echo "=== Running schema setup SQL ==="
PGPASSWORD="$TOKEN" psql \
  "host=${HOST} dbname=databricks_postgres user=${USER} sslmode=require" \
  -f sql/setup_schema.sql

echo ""
echo "=== Post-deploy complete ==="
