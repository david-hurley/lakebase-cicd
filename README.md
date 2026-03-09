# Lakebase CI/CD

A reference implementation for database-per-branch development workflows using **Databricks Lakebase Autoscaling** (managed Postgres) and **GitHub Actions**.

## How It Works

Every feature branch gets its own isolated Lakebase database branch, forked from production with copy-on-write. Merging to `main` deploys schema changes to production. Deleting the Git branch cleans up the Lakebase branch automatically.

```
main  ──push──▶  deploy bundle  ──▶  configure project  ──▶  run migrations
                 (databricks.yml)     (post_deploy.sh)       (migrations.sql)

feature/*  ──create──▶  fork Lakebase branch from production
           ──delete──▶  delete Lakebase branch
```

## Repository Structure

```
├── databricks.yml                              # DAB: Lakebase project + read replica
├── scripts/
│   ├── post_deploy.sh                          # Permissions, branch protection, DB setup
│   └── migrations.sql                          # Idempotent schema migrations
└── .github/workflows/
    ├── deploy-configure-lakebase.yml           # Push to main → deploy & configure
    ├── create-lakebase-branch.yml              # New Git branch → new Lakebase branch
    └── delete-lakebase-branch.yml              # Delete Git branch → delete Lakebase branch
```

## Setup

1. **GitHub Secrets & Variables** — configure in your repo settings:

   | Type | Name | Description |
   |------|------|-------------|
   | Secret | `DATABRICKS_HOST` | Workspace URL (e.g. `https://myworkspace.cloud.databricks.com`) |
   | Secret | `DATABRICKS_TOKEN` | PAT or OAuth token with workspace access |
   | Variable | `LAKEBASE_PROJECT_NAME` | Name for the Lakebase project (e.g. `my-app`) |

2. **Workspace group** — create a `lakebase-developers` group in your Databricks workspace and add developers who need database access.

3. **Push to main** — the deploy workflow will provision the Lakebase project, protect the production branch, create the database, and run migrations.

## Branch Workflow

1. Create a feature branch (`feature/my-change`) — GitHub Actions automatically creates a Lakebase branch forked from production with a 7-day TTL and a read-write endpoint.
2. Develop and test against the isolated branch database.
3. Add schema changes to `scripts/migrations.sql`.
4. Merge to `main` — migrations run against production.
5. Delete the feature branch — the Lakebase branch is cleaned up automatically.
