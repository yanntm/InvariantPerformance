#!/bin/bash
# run_atool.sh
# Front-end orchestrator. Parses arguments, sets up per-mode logging and limits,
# filters models and delegates one call per model to the correct run_<tool>.sh.
# One tool per invocation – exactly as specified.

set -e

print_usage() {
    cat <<EOF
Usage: $0 MODE --tool=NAME [--flags="FLAGS"] [--mem=VALUE] [-t=TIMEOUT] [-solution] [--model-filter=RANGE]

MODE must be one of: PFLOWS, TFLOWS, PSEMIFLOWS, TSEMIFLOWS

Examples:
  $0 TFLOWS --tool=petri --flags="--noSingleSignRow"
  $0 PFLOWS --tool=tina --flags="@MLton max-heap 8G -- -4ti2" -solution
  $0 TFLOWS --tool=petrisage --flags="--backend=pari_kernel"
EOF
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_usage
    exit 0
fi

MODE="$1"
shift

# Default values
TOOL=""
FLAGS=""
MEM_LIMIT="16G"
TIMEOUT_SEC=120
SOLUTION=false
MODEL_FILTER_START=""
MODEL_FILTER_END=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool=*)
      TOOL="${1#*=}"
      ;;
    --flags=*)
      FLAGS="${1#*=}"
      ;;
    --mem=*)
      MEM_LIMIT="${1#*=}"
      ;;
    -t=*)
      TIMEOUT_SEC="${1#*=}"
      ;;
    -solution)
      SOLUTION=true
      ;;
    --model-filter=*)
      range="${1#*=}"
      if [[ "$range" =~ ^([A-Za-z])-([A-Za-z])$ ]]; then
        MODEL_FILTER_START=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
        MODEL_FILTER_END=$(echo "${BASH_REMATCH[2]}" | tr '[:lower:]' '[:upper:]')
        if [[ "$MODEL_FILTER_START" > "$MODEL_FILTER_END" ]]; then
          echo "Error: Model filter range start ($MODEL_FILTER_START) must be <= end ($MODEL_FILTER_END)"
          exit 1
        fi
      else
        echo "Error: Invalid model-filter format (use X-Y)"
        exit 1
      fi
      ;;
    *)
      echo "Unknown argument: $1"
      print_usage
      exit 1
      ;;
  esac
  shift
done

# Validation
if [[ ! "$MODE" =~ ^(PFLOWS|TFLOWS|PSEMIFLOWS|TSEMIFLOWS)$ ]]; then
    echo "Error: MODE must be one of the four supported modes"
    exit 1
fi
if [ -z "$TOOL" ]; then
    echo "Error: --tool=NAME is required"
    exit 1
fi
if [[ ! "$TOOL" =~ ^(tina|petri|itstools|gspn|petrisage)$ ]]; then
    echo "Error: --tool must be one of tina|petri|itstools|gspn|petrisage"
    exit 1
fi
if ! [[ "$TIMEOUT_SEC" =~ ^[0-9]+$ ]] || [ "$TIMEOUT_SEC" -le 0 ]; then
    echo "Error: timeout must be a positive integer"
    exit 1
fi
if [ ! -f ./config.sh ]; then
    echo "Error: config.sh not found"
    exit 1
fi
source ./config.sh

RUNNERS_DIR="$ROOT/runners"
RUNNER="$RUNNERS_DIR/run_${TOOL}.sh"
if [ ! -x "$RUNNER" ]; then
    echo "Error: runner not found or not executable: $RUNNER"
    exit 1
fi

# Per-mode log directory (preserves original organisation)
case "$MODE" in
  TFLOWS)     LOGDIR="logs_tflows" ;;
  PFLOWS)     LOGDIR="logs_pflows" ;;
  TSEMIFLOWS) LOGDIR="logs_tsemiflows" ;;
  PSEMIFLOWS) LOGDIR="logs_psemiflows" ;;
esac

mkdir -p "$LOGDIR"
export LOGS="$PWD/$LOGDIR"

# Build LIMITS wrapper exactly as before
if [ "$MEM_LIMIT" = "ANY" ]; then
    export LIMITS="$TIMEOUT $TIMEOUT_SEC time"
else
    export LIMITS="$TIMEOUT $TIMEOUT_SEC time systemd-run --scope -p MemoryMax=$MEM_LIMIT --user"
fi

# Process each model
for model_dir in "$MODELDIR"/*/; do
    model=$(basename "$model_dir")
    if [ -n "$MODEL_FILTER_START" ] && [ -n "$MODEL_FILTER_END" ]; then
        first_letter=$(echo "$model" | cut -c1 | tr '[:lower:]' '[:upper:]')
        if [[ "$first_letter" < "$MODEL_FILTER_START" || "$first_letter" > "$MODEL_FILTER_END" ]]; then
            continue
        fi
    fi

    echo "Processing model: $model with tool: $TOOL"
    "$RUNNER" "$MODE" "$model_dir" "$FLAGS" "$LIMITS" "$SOLUTION"
done

echo "Execution complete. Logs are in $LOGDIR."
