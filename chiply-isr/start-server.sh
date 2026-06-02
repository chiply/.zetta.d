#!/usr/bin/env bash
# Start the vendored org-db-v3 FastAPI server with the isolated demo database.
# Usage: ./start-server.sh   (Ctrl-C to stop)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="$HERE/db"
cd "$HERE/server"

export ORG_DB_DB_PATH="$DB/org-db-v3.db"
export ORG_DB_SEMANTIC_DB_PATH="$DB/org-db-v3-semantic.db"
export ORG_DB_IMAGE_DB_PATH="$DB/org-db-v3-images.db"
export ORG_DB_HOST="${ORG_DB_HOST:-127.0.0.1}"
export ORG_DB_PORT="${ORG_DB_PORT:-8765}"

exec uv run uvicorn org_db_server.main:app \
  --host "$ORG_DB_HOST" --port "$ORG_DB_PORT"
