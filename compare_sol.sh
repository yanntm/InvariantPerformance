#!/bin/bash

# Script to compare compatible .sol.gz files by model name
# Usage: ./compare_sol.sh <file1.sol.gz> [<file2.sol.gz> ...]
# Example: ./compare_sol.sh logs_pflows/ARMCacheCoherence-PT-none.*.sol.gz

# Check for at least one argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <file1.sol.gz> [<file2.sol.gz> ...]" >&2
    echo "Example: $0 logs_pflows/ARMCacheCoherence-PT-none.*.sol.gz" >&2
    exit 1
fi

# Source the environment
if [ ! -f "config.sh" ]; then
    echo "Error: config.sh not found. Run deploy.sh first." >&2
    exit 1
fi
source ./config.sh

PYTHON_SCRIPT="$ROOT/InvCompare/main.py"
TIMEOUT_SEC=300

# Ensure Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: $PYTHON_SCRIPT not found" >&2
    exit 1
fi

# Filter for .sol.gz files and extract unique model names
MODEL_FILES=()
for file in "$@"; do
    if [[ "$file" == *.sol.gz && -f "$file" ]]; then
        MODEL_FILES+=("$file")
    fi
done

if [ ${#MODEL_FILES[@]} -eq 0 ]; then
    echo "Error: No valid .sol.gz files provided" >&2
    exit 1
fi

mapfile -t MODELS < <(printf '%s\n' "${MODEL_FILES[@]}" | sed 's/\.sol\.gz$//' | cut -d '.' -f 1 | sort -u)

# Process each model
for model in "${MODELS[@]}"; do
    if [ -z "$model" ]; then
        echo "Warning: Skipping empty model name" >&2
        continue
    fi

    # Find all .sol.gz files for this model from input
    mapfile -t MODEL_FILES < <(printf '%s\n' "${MODEL_FILES[@]}" | grep -F "$model")

    if [ ${#MODEL_FILES[@]} -lt 2 ]; then
        echo "Skipping $model: Fewer than 2 solution files found" >&2
        continue
    fi

    # Report file in the folder of the first .sol.gz
    REPORT_DIR=$(dirname "${MODEL_FILES[0]}")
    REPORT_FILE="$REPORT_DIR/${model}.comp"
    if [ -f "$REPORT_FILE" ]; then
        echo "Skipping $model: $REPORT_FILE already exists" >&2
        continue
    fi

    # Create report file early
    echo "Comparison Report for model: $model" > "$REPORT_FILE"
    echo "Files: ${MODEL_FILES[*]}" >> "$REPORT_FILE"
    echo "Started: $(date)" >> "$REPORT_FILE"

    # Create a unique temp directory in /tmp for this model
    # Sanitize model name for temp dir (replace slashes or invalid chars if any)
    SAFE_MODEL=$(echo "$model" | tr -C '[:alnum:]-' '_')
    TEMP_DIR=$(mktemp -d "/tmp/compare_${SAFE_MODEL}.XXXXXX")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create temp directory for $model" >&2
        echo "Failed to create temp directory" >> "$REPORT_FILE"
        continue
    fi

    # Unzip files to temp directory
    TEMP_FILES=()
    for gz_file in "${MODEL_FILES[@]}"; do
        TEMP_FILE="$TEMP_DIR/$(basename "${gz_file%.sol.gz}.sol")"
        if ! gunzip -c "$gz_file" > "$TEMP_FILE"; then
            echo "Warning: Failed to unzip $gz_file" >&2
            echo "Warning: Failed to unzip $gz_file" >> "$REPORT_FILE"
        else
            TEMP_FILES+=("$TEMP_FILE")
        fi
    done

    if [ ${#TEMP_FILES[@]} -lt 2 ]; then
        echo "Warning: Fewer than 2 files unzipped successfully for $model" >&2
        echo "Warning: Fewer than 2 files unzipped successfully" >> "$REPORT_FILE"
    else
        # Run comparison with timeout
        "$TIMEOUT" "$TIMEOUT_SEC" python3 "$PYTHON_SCRIPT" --keepDup --compareSolutions "${TEMP_FILES[@]}" >> "$REPORT_FILE" 2>&1
    fi

    echo "Completed: $(date)" >> "$REPORT_FILE"

    # Clean up temp directory
    rm -rf "$TEMP_DIR"
done