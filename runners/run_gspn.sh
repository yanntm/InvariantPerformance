#!/bin/bash
# run_gspn.sh
# Tool-specific runner for GreatSPN. No -q flag needed.

MODE="$1"
MODEL_DIR="$2"
FLAGS="$3"
LIMITS="$4"
SOLUTION="$5"

model=$(basename "$MODEL_DIR")

case "$MODE" in
    TFLOWS)     GSPN_FLAG="-tbasis" ;;
    PFLOWS)     GSPN_FLAG="-pbasis" ;;
    TSEMIFLOWS) GSPN_FLAG="-tinv" ;;
    PSEMIFLOWS) GSPN_FLAG="-pinv" ;;
    *) echo "Error: run_gspn.sh does not support this mode"; exit 1 ;;
esac

raw_cmd="\"$DSPN\" -load model $GSPN_FLAG $FLAGS"

source "$ROOT/runners/run_common.sh"
extra_segment=$(compress_flags "$FLAGS")

final_logfile="$LOGS/$model${extra_segment:+.$extra_segment}.gspn"

invoke_and_log "$raw_cmd" "$final_logfile" "greatspn" "$MODEL_DIR" "$MODE" "$LIMITS" "$SOLUTION"
