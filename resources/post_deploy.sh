#!/usr/bin/env bash

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

IS_PROTECTED=$(
  databricks postgres get-branch "projects/$PROJECT_ID/branches/production" -o json \
    | jq -r '.status.is_protected'
)

if [ "$IS_PROTECTED" = "true" ]; then
  echo "Already protected, skipping."
else
  databricks postgres update-branch \
    "projects/$PROJECT_ID/branches/production" \
    spec.is_protected \
    --json '{
      "spec": {
        "is_protected": true
      }
    }'
fi
