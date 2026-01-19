#!/bin/bash

# Run all numbered SQL files and save EXPLAIN ANALYZE output

usage() {
    echo "Usage: $0 [-o <output_dir>] [-n on|off]"
    echo "  -o <output_dir>    output directory (default: explain_results)"
    echo "  -n on|off          set enable_nestloop GUC (default: on)"
    exit 1
}

# Default values
OUTPUT_DIR="explain_results"
ENABLE_NESTLOOP="on"

# Parse command-line arguments
while getopts "o:n:h" opt; do
    case $opt in
        o)
            OUTPUT_DIR="$OPTARG"
            ;;
        n)
            if [[ "$OPTARG" != "on" && "$OPTARG" != "off" ]]; then
                echo "Error: -n must be 'on' or 'off'"
                exit 1
            fi
            ENABLE_NESTLOOP="$OPTARG"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Output directory: $OUTPUT_DIR"
echo "enable_nestloop: $ENABLE_NESTLOOP"
echo ""

# Arrays to store timing results
declare -a QUERY_NAMES
declare -a QUERY_TIMES
declare -a QUERY_STATUS

# Get all numbered SQL files and sort them
for sql_file in $(ls [0-9]*.sql | sort -V); do
    echo -n "Running $sql_file with enable_nestloop = $ENABLE_NESTLOOP... "

    OUTPUT_FILE="$OUTPUT_DIR/${sql_file%.sql}.txt"

    # Run the query and save output
    psql imdb -c "SET enable_nestloop = $ENABLE_NESTLOOP;" -f "$sql_file" > "$OUTPUT_FILE" 2>&1
    EXIT_CODE=$?

    # Store results
    QUERY_NAMES+=("${sql_file%.sql}")

    if [ $EXIT_CODE -eq 0 ]; then
        # Parse execution time from EXPLAIN ANALYZE output
        EXEC_TIME=$(grep 'Execution Time:' "$OUTPUT_FILE" | tail -1 | sed 's/.*Execution Time: \([0-9.]*\) ms.*/\1/')
        if [ -n "$EXEC_TIME" ]; then
            QUERY_TIMES+=("$EXEC_TIME")
            QUERY_STATUS+=("OK")
            printf "%.3f ms\n" "$EXEC_TIME"
        else
            QUERY_TIMES+=("0")
            QUERY_STATUS+=("FAIL")
            echo "Failed! (no execution time found)"
        fi
    else
        QUERY_TIMES+=("0")
        QUERY_STATUS+=("FAIL")
        echo "Failed!"
    fi
done

# Calculate total execution time from parsed times
TOTAL_EXEC_MS=0
for t in "${QUERY_TIMES[@]}"; do
    TOTAL_EXEC_MS=$(echo "$TOTAL_EXEC_MS + $t" | bc)
done
TOTAL_EXEC_S=$(echo "scale=3; $TOTAL_EXEC_MS / 1000" | bc)

TIMES_FILE="$OUTPUT_DIR/execution_times.out"

# Generate summary and write to both stdout and file
{
    echo "========================================"
    echo "               SUMMARY"
    echo "========================================"
    printf "%-12s %12s %8s\n" "Query" "Time (ms)" "Status"
    echo "----------------------------------------"

    for i in "${!QUERY_NAMES[@]}"; do
        printf "%-12s %12.3f %8s\n" "${QUERY_NAMES[$i]}" "${QUERY_TIMES[$i]}" "${QUERY_STATUS[$i]}"
    done

    echo "----------------------------------------"
    printf "%-12s %11.3fs\n" "TOTAL" "$TOTAL_EXEC_S"
    echo "========================================"
} | tee "$TIMES_FILE"

echo ""
echo "Done! Check $OUTPUT_DIR/ directory for all outputs."
echo "Timing summary saved to $TIMES_FILE"
