#!/bin/bash
set -e

# Usage: ./generate.sh <description>
# 1. Applies all migrations to a temp database
# 2. Dumps temp DB schema using Dockerized pg_dump
# 3. Diffs with schema.sql using apgdiff
# 4. Writes diff SQL to migrations/<timestamp>_<description>.sql if non-empty

if [ -z "$DB_DIR" ]; then
  echo "DB_DIR must be set in environment"
  exit 1
fi

TMP_DIR="$(dirname "$0")/tmp"

if [ -z "$1" ]; then
  echo "Usage: $0 <description>"
  exit 1
fi

DB_URL="$DATABASE_URL"
if [ -z "$DB_URL" ]; then
  echo "DATABASE_URL must be set in environment"
  exit 1
fi

# Robustly parse connection info from DB_URL
url="${DB_URL#postgres://}"
PGUSER="${url%%:*}"
rest="${url#*:}"
PGPASSWORD="${rest%%@*}"
rest="${rest#*@}"
PGHOST="${rest%%:*}"
rest="${rest#*:}"
PGPORT="${rest%%/*}"
PGDATABASE="${rest#*/}"

# TMP_DB should always be set explicitly
TMP_DB="_migration_tmp"

# On Mac, Docker needs host.docker.internal instead of localhost
if [[ "$PGHOST" == "localhost" ]]; then
  PGHOST="host.docker.internal"
fi

# Ensure tmp dir exists
mkdir -p "$TMP_DIR"
DUMP_PATH="$TMP_DIR/current_schema.sql"

# Create and migrate a temp DB
BASE_URL="$(echo "$DB_URL" | sed -E 's|/[^/]+$||')/postgres"
PGPASSWORD="$PGPASSWORD" psql "$BASE_URL" -c "DROP DATABASE IF EXISTS \"$TMP_DB\";" -w
PGPASSWORD="$PGPASSWORD" psql "$BASE_URL" -c "CREATE DATABASE \"$TMP_DB\";" -w
TMP_URL="$(echo "$DB_URL" | sed -E "s|/[^/]+$|/$TMP_DB|")"

for f in "$DB_DIR/migrations"/*.sql; do
  echo "Applying migration to temp DB: $f"
  PGPASSWORD="$PGPASSWORD" psql "$TMP_URL" -v ON_ERROR_STOP=1 -w -f "$f"
done

# Dump the current schema from the temp DB using Dockerized pg_dump
PGPASSWORD="$PGPASSWORD" docker run --rm --network=host -e PGPASSWORD="$PGPASSWORD" -v "$(pwd)":/workspace pgvector/pgvector:pg16 \
  pg_dump --schema-only --no-owner --no-privileges -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$TMP_DB" -w \
  > "$DUMP_PATH"

# Apply migrations/init.sql to the SCHEMA (desired) database before diffing
# We'll create a temp DB for the schema.sql, apply init.sql, then schema.sql, then dump
SCHEMA_TMP_DB="_schema_tmp"
PGPASSWORD="$PGPASSWORD" psql "$BASE_URL" -c "DROP DATABASE IF EXISTS \"$SCHEMA_TMP_DB\";" -w
PGPASSWORD="$PGPASSWORD" psql "$BASE_URL" -c "CREATE DATABASE \"$SCHEMA_TMP_DB\";" -w
SCHEMA_TMP_URL="$(echo "$DB_URL" | sed -E "s|/[^/]+$|/$SCHEMA_TMP_DB|")"

# Apply migrations/init.sql (if exists)
INIT_MIGRATION="$DB_DIR/migrations/init.sql"
if [ -f "$INIT_MIGRATION" ]; then
  echo "Applying migrations/init.sql to schema tmp DB"
  PGPASSWORD="$PGPASSWORD" psql "$SCHEMA_TMP_URL" -v ON_ERROR_STOP=1 -w -f "$INIT_MIGRATION"
fi

# Apply schema.sql
PGPASSWORD="$PGPASSWORD" psql "$SCHEMA_TMP_URL" -v ON_ERROR_STOP=1 -w -f "$DB_DIR/schema.sql"

# Dump the schema for diffing
SCHEMA_DUMP_PATH="$TMP_DIR/schema_db.sql"
PGPASSWORD="$PGPASSWORD" docker run --rm --network=host -e PGPASSWORD="$PGPASSWORD" -v "$(pwd)":/workspace pgvector/pgvector:pg16 \
  pg_dump --schema-only --no-owner --no-privileges -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$SCHEMA_TMP_DB" -w \
  > "$SCHEMA_DUMP_PATH"

# Now run apgdiff on the two dumps
TS=$(date +%Y%m%d_%H%M%S)
OUTFILE="$DB_DIR/migrations/${TS}_$1.sql"
docker run --rm -v "$(pwd)":/workspace lovelysystems/apgdiff:dev \
  /workspace/$DUMP_PATH /workspace/$SCHEMA_DUMP_PATH \
  --out-file=/workspace/$OUTFILE

if [ -s "$OUTFILE" ]; then
  echo "Migration generated: $OUTFILE"
else
  echo "No differences detected. No migration generated."
  rm -f "$OUTFILE"
fi

# Clean up temp DBs
PGPASSWORD="$PGPASSWORD" psql "$BASE_URL" -c "DROP DATABASE IF EXISTS \"$TMP_DB\";" -w
PGPASSWORD="$PGPASSWORD" psql "$BASE_URL" -c "DROP DATABASE IF EXISTS \"$SCHEMA_TMP_DB\";" -w

# Clean up tmp dir
rm -rf "$TMP_DIR"
