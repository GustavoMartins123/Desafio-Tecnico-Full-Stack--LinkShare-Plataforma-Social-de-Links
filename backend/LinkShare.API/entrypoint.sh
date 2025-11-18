#!/bin/bash
set -e

echo "========================================="
echo "LinkShare API - Starting up..."
echo "========================================="

# Function to wait for database
wait_for_db() {
    echo "Waiting for PostgreSQL to be ready..."

    max_attempts=30
    attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
            echo "PostgreSQL is ready!"
            return 0
        fi

        attempt=$((attempt + 1))
        echo "Attempt $attempt/$max_attempts: PostgreSQL not ready yet, waiting 2 seconds..."
        sleep 2
    done

    echo "ERROR: PostgreSQL is not available after $max_attempts attempts"
    return 1
}

# Extract database connection info from connection string
# Default values if not set
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-postgres}

echo "Database host: $DB_HOST"
echo "Database port: $DB_PORT"
echo "Database user: $DB_USER"

# Install pg_isready if not available
if ! command -v pg_isready &> /dev/null; then
    echo "Installing postgresql-client..."
    apt-get update > /dev/null 2>&1
    apt-get install -y postgresql-client > /dev/null 2>&1
fi

# Wait for database
if ! wait_for_db; then
    echo "Failed to connect to database. Exiting..."
    exit 1
fi

echo "========================================="
echo "Database is ready. Starting application..."
echo "========================================="

# Execute the application
exec dotnet LinkShare.API.dll
