#!/bin/bash
set -e

# Usage: ./migrate.sh [DATABASE_URL]
# Defaults to DATABASE_URL in .env if not provided

MIGRATIONS_DIR="$(dirname "$0")/migrations"
SCHEMA_FILE="$(dirname "$0")/schema.sql"

if [ -n "$1" ]; then
  DB_URL="$1"
else
  DB_URL="$DATABASE_URL"
fi

if [ -z "$DB_URL" ]; then
  echo "DATABASE_URL must be set in environment or passed as an argument"
  exit 1
fi

# Parse connection info
url="${DB_URL#postgres://}"
PGUSER="${url%%:*}"
rest="${url#*:}"
PGPASSWORD="${rest%%@*}"
rest="${rest#*@}"
PGHOST="${rest%%:*}"
rest="${rest#*:}"
PGPORT="${rest%%/*}"
PGDATABASE="${rest#*/}"

# On Mac, Docker needs host.docker.internal
if [[ "$PGHOST" == "localhost" ]]; then
  PGHOST="host.docker.internal"
fi

# Always apply init.sql first, but record and skip if already applied
INIT_MIGRATION="$MIGRATIONS_DIR/init.sql"
INIT_VERSION="init.sql"
if [ -f "$INIT_MIGRATION" ]; then
  APPLIED=$(PGPASSWORD="$PGPASSWORD" psql "$DB_URL" -tAc "SELECT 1 FROM _migrations.migrations WHERE version = '$INIT_VERSION'" || true)
  if [[ "$APPLIED" == "1" ]]; then
    echo "Skipping already applied migration: $INIT_VERSION"
  else
    echo "Applying init.sql (migration tracking table)"
    PGPASSWORD="$PGPASSWORD" psql "$DB_URL" -v ON_ERROR_STOP=1 -w -f "$INIT_MIGRATION"
    # Insert into tracking table
    PGPASSWORD="$PGPASSWORD" psql "$DB_URL" -c "INSERT INTO _migrations.migrations (version) VALUES ('$INIT_VERSION')" -w
    echo "Recorded migration: $INIT_VERSION"
  fi
fi

# Apply all migration files in order, tracking in _migrations.migrations
for f in "$MIGRATIONS_DIR"/*.sql; do
  VERSION=$(basename "$f")
  # Skip init.sql (already applied)
  if [[ "$VERSION" == "init.sql" ]]; then
    continue
  fi
  # Check if already applied
  APPLIED=$(PGPASSWORD="$PGPASSWORD" psql "$DB_URL" -tAc "SELECT 1 FROM _migrations.migrations WHERE version = '$VERSION'" || true)
  if [[ "$APPLIED" == "1" ]]; then
    echo "Skipping already applied migration: $VERSION"
    continue
  fi
  echo "Applying migration: $f"
  PGPASSWORD="$PGPASSWORD" psql "$DB_URL" -v ON_ERROR_STOP=1 -w -f "$f"
  # Insert into tracking table
  PGPASSWORD="$PGPASSWORD" psql "$DB_URL" -c "INSERT INTO _migrations.migrations (version) VALUES ('$VERSION')" -w
  echo "Recorded migration: $VERSION"
done

echo "All migrations applied."

# Optionally, update schema.sql.txt to reflect current schema
# pg_dump --schema-only --no-owner --no-privileges "$DB_URL" > "$SCHEMA_FILE"

# Optionally generate Kysely types after migrations (dev only)
if [ "$NODE_ENV" = "development" ]; then
  echo "Generating Kysely types with Kanel..."
  bun run --cwd "$(dirname "$0")/.." generate:kysely
fi
