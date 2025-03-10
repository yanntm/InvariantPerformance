#!/bin/bash

# Script to test minimality of .sol.gz files or folders containing them
# Generates a .sol.min report next to each .sol.gz file
# Usage: ./test_minimality.sh <arg1> [<arg2> ...]

# Check for at least one argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <arg1> [<arg2> ...]" >&2
    echo "Examples:" >&2
    echo "  $0 logs_pflows" >&2
    echo "  $0 logs_pflows/Airplane*.sol.gz" >&2
    echo "  $0 logs_pflows file.sol.gz" >&2
    exit 1
fi

BASE_DIR="/home/ythierry/git/InvariantPerformance"
PYTHON_SCRIPT="$BASE_DIR/InvCompare/main.py"
TEMP_DIR="/tmp"

# Ensure Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: $PYTHON_SCRIPT not found" >&2
    exit 1
fi

# Activate virtualenv and set Z3 library path
source "$HOME/z3_env/bin/activate" || {
    echo "Error: Failed to activate virtualenv 'z3_env'" >&2
    exit 1
}
export LD_LIBRARY_PATH="$HOME/z3-4.14.0/install/bin:$LD_LIBRARY_PATH"

# Function to process a single .sol.gz file
process_file() {
    local SOL_FILE="$1"
    local REPORT_FILE="${SOL_FILE%.sol.gz}.sol.min"

    # Skip if report already exists (optional: remove to overwrite)
    if [ -f "$REPORT_FILE" ]; then
        echo "Skipping $SOL_FILE: $REPORT_FILE already exists" >&2
        return

    fi

    # Create a unique temp file
    local TEMP_FILE=$(mktemp "$TEMP_DIR/minimality_test.XXXXXX.sol")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create temp file for $SOL_FILE" >&2
        echo "Failed to create temp file" > "$REPORT_FILE"
        return
    fi

    # Unzip to temp location
    if ! gunzip -c "$SOL_FILE" > "$TEMP_FILE"; then
        echo "Error: Failed to unzip $SOL_FILE" >&2
        echo "Failed to unzip $SOL_FILE" > "$REPORT_FILE"
        rm -f "$TEMP_FILE"
        return
    fi

    # Run minimality test and write to report file
    {
        echo "Minimality Test Report for $SOL_FILE"
        echo "Started: $(date)"
        python3 "$PYTHON_SCRIPT" --testMinimality "$TEMP_FILE"
        echo "Completed: $(date)"
    } > "$REPORT_FILE" 2>&1

    # Clean up temp file
    rm -f "$TEMP_FILE"
}

# Iterate over all arguments
for arg in "$@"; do
    if [ -d "$arg" ]; then
        # Argument is a folder: process all .sol.gz files inside
        for gz_file in "$arg"/*.sol.gz; do
            if [ -f "$gz_file" ]; then
                process_file "$gz_file"
            fi
        done
    elif [ -f "$arg" ] && [[ "$arg" == *.sol.gz ]]; then
        # Argument is a .sol.gz file: process it directly
        process_file "$arg"
    else
        # Skip invalid arguments
        echo "Warning: Skipping '$arg' - not a folder or .sol.gz file" >&2
    fi
done

