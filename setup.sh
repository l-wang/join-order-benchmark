#!/bin/bash

# Setup script for Join Order Benchmark (JOB) database

set -e

usage() {
    echo "Usage: $0 [-s <stats_mode>] [-d <dbname>]"
    echo "  -d <dbname>      database name (default: imdb)"
    echo "  -s <stats_mode>  join stats mode: none, implicit, or explicit (default: none)"
    echo "                     none     - no additional join stats"
    echo "                     implicit - join stats via FK constraints + multi-column stats"
    echo "                     explicit - join stats via CREATE STATISTICS"
    echo "  -h               show this help"
    exit 1
}

# Default values
DBNAME="imdb"
STATS_MODE="none"

# Parse command-line arguments
while getopts "d:s:h" opt; do
    case $opt in
        d)
            DBNAME="$OPTARG"
            ;;
        s)
            if [[ "$OPTARG" != "none" && "$OPTARG" != "implicit" && "$OPTARG" != "explicit" ]]; then
                echo "Error: -s must be 'none', 'implicit', or 'explicit'"
                exit 1
            fi
            STATS_MODE="$OPTARG"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

echo "========================================"
echo "  JOB Database Setup"
echo "========================================"
echo "Database: $DBNAME"
echo "Stats mode: $STATS_MODE"
echo "========================================"
echo ""

echo "Creating database '$DBNAME'..."
if createdb "$DBNAME" 2>/dev/null; then
    echo "  Database created."
else
    echo "  Database already exists (or error occurred). Continuing..."
fi

echo "Creating schema..."
psql "$DBNAME" -f schema.sql
echo "  Schema created."

echo "Loading data..."
psql "$DBNAME" -f load.sql
echo "  Data loaded."

echo "Creating indexes..."
psql "$DBNAME" -f fkindexes.sql
echo "  Indexes created."

# Create join stats (optional)
case $STATS_MODE in
    implicit)
        echo "Creating FK constraints and multi-column stats..."
        psql "$DBNAME" -f create-constraints-and-stats.sql
        echo "  FK constraints and multi-column stats created."
        ;;
    explicit)
        echo "Creating explicit join statistics..."
        psql "$DBNAME" -f create-join-stats.sql
        echo "  Explicit join statistics created."
        ;;
    none)
        echo "Skipping join stats (stats_mode=none)."
        ;;
esac

echo "Analyzing all tables..."
psql "$DBNAME" -f analyze_tables.sql
echo "  Tables analyzed."

echo ""
echo "========================================"
echo "  Setup complete!"
echo "========================================"
echo ""
echo "To run benchmark queries:"
echo "  ./run_queries.sh -o explain_results -n on"
