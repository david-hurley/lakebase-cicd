#!/usr/bin/env bash

echo "Assigning Lakebase instance permissions..."

PROJECT_ID=$(
  databricks postgres get-project "projects/david-lakebase-cicd" -o json \
    | jq -r '.uid'
)

databricks permissions update database-projects "$PROJECT_ID" \
  --json '{
    "access_control_list": [
      {
        "group_name": "lakebase-developers",
        "permission_level": "CAN_USE"
      }
    ]
  }'
