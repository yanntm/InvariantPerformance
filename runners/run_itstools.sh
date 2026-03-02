#!/bin/bash
# run_itstools.sh
# Tool-specific runner for ITS-Tools. Simple flag mapping + -q handling.

MODE="$1"
MODEL_DIR="$2"
FLAGS="$3"
LIMITS="$4"
SOLUTION="$5"

model=$(basename "$MODEL_DIR")

case "$MODE" in
    TFLOWS)     ITS_FLAG="--Tflows" ;;
    PFLOWS)     ITS_FLAG="--Pflows" ;;
    TSEMIFLOWS) ITS_FLAG="--Tsemiflows" ;;
    PSEMIFLOWS) ITS_FLAG="--Psemiflows" ;;
    *) echo "Error: run_itstools.sh does not support this mode"; exit 1 ;;
esac

if [ "$SOLUTION" != true ]; then
    ITS_FLAG="$ITS_FLAG -q"
fi

raw_cmd="\"$ITSTOOLS\" -pnfolder \"$MODEL_DIR\" $ITS_FLAG $FLAGS"

source "$ROOT/runners/run_common.sh"
extra_segment=$(compress_flags "$FLAGS")

final_logfile="$LOGS/$model${extra_segment:+.$extra_segment}.its"

invoke_and_log "$raw_cmd" "$final_logfile" "itstools" "$MODEL_DIR" "$MODE" "$LIMITS" "$SOLUTION"
