#!/bin/bash

# CLI tool to initialize the user's database directory for pg-migrate
# Usage: ./init.sh [db_directory]

set -e

# Default database directory
DEFAULT_DB_DIR="./db"

# Get the target directory from argument or prompt
DB_DIR="$1"

if [ -z "$DB_DIR" ]; then
    read -p "Enter database directory [${DEFAULT_DB_DIR}]: " USER_INPUT
    DB_DIR="${USER_INPUT:-$DEFAULT_DB_DIR}"
fi

# Create the target directory and migrations subdirectory
mkdir -p "$DB_DIR/migrations"

# Copy migrations (preserve file attributes, overwrite existing)
cp -a ./migrations/. "$DB_DIR/migrations/"

# Copy schema.sql
cp ./schema.sql "$DB_DIR/schema.sql"

echo "Database directory initialized at $DB_DIR"
echo "Migrations and schema.sql have been copied."
