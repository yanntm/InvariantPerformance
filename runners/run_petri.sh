#!/bin/bash
# run_petri.sh
# Tool-specific runner for PetriSpot (32/64/128-bit).
# Bitness is now part of --flags (e.g. -64). Default = 64-bit.
# Log suffix always includes the bitness: .petri64 / .petri32 / .petri128.

MODE="$1"
MODEL_DIR="$2"
FLAGS="$3"
LIMITS="$4"
SOLUTION="$5"

model=$(basename "$MODEL_DIR")

# Mode-specific base flags
case "$MODE" in
    TFLOWS)     PETRI_FLAG="--Tflows" ;;
    PFLOWS)     PETRI_FLAG="--Pflows" ;;
    TSEMIFLOWS) PETRI_FLAG="--Tsemiflows" ;;
    PSEMIFLOWS) PETRI_FLAG="--Psemiflows" ;;
    *) echo "Error: run_petri.sh does not support this mode"; exit 1 ;;
esac

if [ "$SOLUTION" != true ]; then
    PETRI_FLAG="$PETRI_FLAG -q"
fi

# Detect and strip bitness flag (used only for binary selection)
BITNESS="64"
[[ "$FLAGS" == *"-32"* ]]  && { BITNESS="32";  FLAGS="${FLAGS//-32/}"; }
[[ "$FLAGS" == *"-128"* ]] && { BITNESS="128"; FLAGS="${FLAGS//-128/}"; }
[[ "$FLAGS" == *"-64"* ]]  && FLAGS="${FLAGS//-64/}"

case "$BITNESS" in
    32)  petri_exe="$PETRISPOT32" ;;
    128) petri_exe="$PETRISPOT128" ;;
    *)   petri_exe="$PETRISPOT64" ;;
esac

raw_cmd="\"$petri_exe\" -i \"$MODEL_DIR/model.norm.pnml\" $PETRI_FLAG $FLAGS"

source "$ROOT/runners/run_common.sh"
extra_segment=$(compress_flags "$FLAGS")

final_logfile="$LOGS/$model${extra_segment:+.$extra_segment}.petri${BITNESS}"

invoke_and_log "$raw_cmd" "$final_logfile" "petrispot" "$MODEL_DIR" "$MODE" "$LIMITS" "$SOLUTION"
