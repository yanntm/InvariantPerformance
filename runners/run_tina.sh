#!/bin/bash
# run_tina.sh
# Tool-specific runner for Tina (struct component).
# All variants (normal, 4ti2, different heaps, etc.) are expressed purely inside --flags.
# Logfile always ends with .tina.

MODE="$1"
MODEL_DIR="$2"
FLAGS="$3"
LIMITS="$4"
SOLUTION="$5"

model=$(basename "$MODEL_DIR")

# Mode-specific base flags (only the four supported modes)
case "$MODE" in
    TFLOWS)     TINA_FLAG="-F -T" ;;
    PFLOWS)     TINA_FLAG="-F -P" ;;
    TSEMIFLOWS) TINA_FLAG="-S -T" ;;
    PSEMIFLOWS) TINA_FLAG="-S -P" ;;
    *) 
        echo "Error: run_tina.sh does not support mode $MODE"
        exit 1 
        ;;
esac

# Add -q unless we are collecting solutions
if [ "$SOLUTION" != true ]; then
    TINA_FLAG="$TINA_FLAG -q"
fi

# Choose executable (large_marking support kept)
tina_exe="$STRUCT"
[ -f "$MODEL_DIR/large_marking" ] && tina_exe="$STRUCTLARGE"

# Tina with -4ti2 flag needs the 4ti2 binaries that live in $ROOT/bin
source "$ROOT/config.sh"

# Raw command WITHOUT the LIMITS wrapper
raw_cmd="\"$tina_exe\" $FLAGS $TINA_FLAG \"$MODEL_DIR/model.norm.pnml\""

source "$ROOT/runners/run_common.sh"

# Compute optional compressed-flags segment
extra_segment=$(compress_flags "$FLAGS")

final_logfile="$LOGS/$model${extra_segment:+.$extra_segment}.tina"

# Delegate to common layer
invoke_and_log "$raw_cmd" "$final_logfile" "tina" "$MODEL_DIR" "$MODE" "$LIMITS" "$SOLUTION"

