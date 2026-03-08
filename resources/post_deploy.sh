#!/usr/bin/env bash

PROJECT_ID="david-lakebase-cicd"
BRANCH_ID="production"

echo "Assigning Lakebase instance permissions..."

PROJECT_UID=$(
  databricks postgres get-project "projects/$PROJECT_ID" -o json \
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

databricks postgres update-branch \
  "projects/$PROJECT_ID/branches/$BRANCH_ID" \
  spec.is_protected \
  --json '{
    "spec": {
      "is_protected": true
    }
  }'
