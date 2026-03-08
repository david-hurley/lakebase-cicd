#!/usr/bin/env bash
set -euo pipefail

databricks bundle deploy "$@"
databricks bundle run post_deploy "$@"
