#!/bin/bash

# Submit 4 OAR jobs to compare solutions in parallel across 4 folders
# Each job uses 64 cores on a Tall node with xargs for parallel processing of models

BASE_DIR="/home/ythierry/git/InvariantPerformance"
TEST_SCRIPT="$BASE_DIR/compare_sol.sh"

# Ensure the test script exists
if [ ! -f "$TEST_SCRIPT" ]; then
    echo "Error: $TEST_SCRIPT not found" >&2
    exit 1
fi

# Folders to process (relative to BASE_DIR)
FOLDERS=(
    "logs_pflows"
    "logs_psemiflows"
    "logs_tsemiflows"
    "logs_tflows"
)

# Submit one job per folder
for folder in "${FOLDERS[@]}"; do
    # Get unique model names and pipe to xargs for parallel processing
    JOB_CMD="cd $BASE_DIR/$folder ; ls *.sol.gz | cut -d '.' -f 1 | sort -u | xargs -n 1 -P 64 bash -c '$TEST_SCRIPT \"$BASE_DIR/$folder\" \"\$0\"' ; exit"
    oarsub -l "{(host like \"tall%\")}/nodes=1/core=64,walltime=12:00:00" "$JOB_CMD"
    echo "Submitted job for $folder"
done

echo "All jobs submitted. Check OAR status with 'oarstat'."

