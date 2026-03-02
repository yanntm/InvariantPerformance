#!/bin/bash
# run_petrisage.sh
# Tool-specific runner for PetriSage. Contains ALL special handling (micromamba,
# .mtx input, temporary .tba file, custom .sol.gz, simple backend suffix).
# Does NOT pollute run_common.sh.

MODE="$1"
MODEL_DIR="$2"
FLAGS="$3"
LIMITS="$4"
SOLUTION="$5"

model=$(basename "$MODEL_DIR")

if [ "$MODE" != "TFLOWS" ] && [ "$MODE" != "PFLOWS" ]; then
    echo "Warning: PetriSage only supports TFLOWS/PFLOWS – skipping"
    exit 0
fi

# Simple backend suffix exactly as original script (e.g. .pK.petrisage)
extra_segment=""
if [[ "$FLAGS" == *"--backend="* ]]; then
    backend=$(echo "$FLAGS" | sed 's/.*--backend=//' | cut -d' ' -f1)
    extra_segment=".$backend"
fi

final_logfile="$LOGS/$model${extra_segment}.petrisage"
temp_tba_file="/tmp/$model${extra_segment}.petrisage.tba"

raw_cmd="\"$MICROMAMBA\" run -r \"$ROOT/micromamba\" -n sage \"$PETRISAGE\" \"$MODEL_DIR/model.mtx\" \"$temp_tba_file\" $MODE $FLAGS"

# Execute via common layer (but disable generic solution collection)
source "$ROOT/runners/run_common.sh"
invoke_and_log "$raw_cmd" "$final_logfile" "" "$MODEL_DIR" "$MODE" "$LIMITS" false

# PetriSage-specific solution collection (kept here)
if [ "$SOLUTION" = true ] && [ -f "$temp_tba_file" ]; then
    python3 "$ROOT/InvCompare/collectSolution.py" --tool=petrisage --log="$final_logfile" --model="$MODEL_DIR" --mode="$MODE"
    [ -f "${final_logfile}.sol.gz" ] && mv "${final_logfile}.sol.gz" "$LOGS/$model${extra_segment}.petrisage.sol.gz" || true
    rm -f "$temp_tba_file"
fi
