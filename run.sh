#!/bin/bash
# run.sh: Run performance tests for all models in a given mode.
# Supported modes: FLOWS, SEMIFLOWS, TFLOWS, PFLOWS, TSEMIFLOWS, PSEMIFLOWS

set -e

# Ensure config.sh exists and source it.
if [ ! -f ./config.sh ]; then
    echo "Error: config.sh not found. Please run deploy.sh first."
    exit 1
fi
source ./config.sh

# --- Check Required Binaries ---
check_executable() {
    if [ ! -x "$1" ]; then
        echo "Error: '$1' not found or not executable."
        exit 1
    fi
}

check_executable "$STRUCT"
check_executable "$DSPN"
check_executable "$GSOL"
check_executable "$PETRISPOT32"
check_executable "$PETRISPOT64"
check_executable "$PETRISPOT128"
check_executable "$ITSTOOLS"
check_executable "$TIMEOUT"

# --- Parse Mode Argument ---
if [ $# -ne 1 ]; then
    echo "Usage: $0 [FLOWS|SEMIFLOWS|TFLOWS|PFLOWS|TSEMIFLOWS|PSEMIFLOWS]"
    exit 1
fi

MODE=$1

case "$MODE" in
  FLOWS)
    TINA_FLAG="-F"
    ITS_FLAG="--Pflows --Tflows"
    PETRISPOT_FLAG="--Pflows --Tflows"
    GSPN_FLAG="-pbasis -tbasis"
    LOGDIR="logs"
    ;;
  SEMIFLOWS)
    TINA_FLAG="-S"
    ITS_FLAG="--Psemiflows --Tsemiflows"
    PETRISPOT_FLAG="--Psemiflows --Tsemiflows"
    GSPN_FLAG="-pinv -tinv"
    LOGDIR="semilogs"
    ;;
  TFLOWS)
    TINA_FLAG="-F -T"
    ITS_FLAG="--Tflows"
    PETRISPOT_FLAG="--Tflows"
    GSPN_FLAG="-tbasis"
    LOGDIR="logs_tflows"
    ;;
  PFLOWS)
    TINA_FLAG="-F -P"
    ITS_FLAG="--Pflows"
    PETRISPOT_FLAG="--Pflows"
    GSPN_FLAG="-pbasis"
    LOGDIR="logs_pflows"
    ;;
  TSEMIFLOWS)
    TINA_FLAG="-S -T"
    ITS_FLAG="--Tsemiflows"
    PETRISPOT_FLAG="--Tsemiflows"
    GSPN_FLAG="-tinv"
    LOGDIR="logs_tsemiflows"
    ;;
  PSEMIFLOWS)
    TINA_FLAG="-S -P"
    ITS_FLAG="--Psemiflows"
    PETRISPOT_FLAG="--Psemiflows"
    GSPN_FLAG="-pinv"
    LOGDIR="logs_psemiflows"
    ;;
  *)
    echo "Usage: $0 [FLOWS|SEMIFLOWS|TFLOWS|PFLOWS|TSEMIFLOWS|PSEMIFLOWS]"
    exit 1
    ;;
esac

export LIMITS="$TIMEOUT 120 time systemd-run --scope -p MemoryMax=16G --user"
cd "$ROOT"
mkdir -p "$LOGDIR"
export LOGS="$PWD/$LOGDIR"

# --- Run Tools for Each Model ---
for model_dir in "$MODELDIR"/*/; do
    cd "$model_dir" || exit
    model=$(basename "$model_dir")
    echo "Processing model: $model"

    # TINA without 4ti2
    if [ ! -f "$LOGS/$model.tina" ]; then
        if [ -f large_marking ]; then
            $LIMITS "$STRUCTLARGE" @MLton fixed-heap 15G -- $TINA_FLAG -mp -q "$model_dir/model.pnml" \
                > "$LOGS/$model.tina" 2>&1
        else
            $LIMITS "$STRUCT" @MLton fixed-heap 15G -- $TINA_FLAG -mp -q "$model_dir/model.pnml" \
                > "$LOGS/$model.tina" 2>&1
        fi
    fi

    # TINA with 4ti2
    if [ ! -f "$LOGS/$model.struct" ]; then
        rm -f /tmp/f-* > /dev/null 2>&1
        if [ -f large_marking ]; then
            $LIMITS "$STRUCTLARGE" @MLton max-heap 8G -- -4ti2 $TINA_FLAG -I -q "$model_dir/model.pnml" \
                > "$LOGS/$model.struct" 2>&1
        else
            $LIMITS "$STRUCT" @MLton max-heap 8G -- -4ti2 $TINA_FLAG -I -q "$model_dir/model.pnml" \
                > "$LOGS/$model.struct" 2>&1
        fi
        rm -f /tmp/f-* > /dev/null 2>&1
        sync
    fi

    # itstools
    if [ ! -f "$LOGS/$model.its" ]; then
        $LIMITS "$ITSTOOLS" -pnfolder "$model_dir" $ITS_FLAG \
            > "$LOGS/$model.its" 2>&1
    fi

    # PetriSpot 32-bit
    if [ ! -f "$LOGS/$model.petri32" ]; then
        $LIMITS "$PETRISPOT32" -i "$model_dir/model.pnml" -q $PETRISPOT_FLAG \
            > "$LOGS/$model.petri32" 2>&1
    fi

    # PetriSpot 64-bit
    if [ ! -f "$LOGS/$model.petri64" ]; then
        $LIMITS "$PETRISPOT64" -i "$model_dir/model.pnml" -q $PETRISPOT_FLAG \
            > "$LOGS/$model.petri64" 2>&1
    fi

    # PetriSpot 128-bit
    if [ ! -f "$LOGS/$model.petri128" ]; then
        $LIMITS "$PETRISPOT128" -i "$model_dir/model.pnml" -q $PETRISPOT_FLAG \
            > "$LOGS/$model.petri128" 2>&1
    fi

    # GreatSPN
    if [ ! -f "$LOGS/$model.gspn" ]; then
        $LIMITS "$DSPN" -load model $GSPN_FLAG \
            > "$LOGS/$model.gspn" 2>&1
    fi

    cd "$MODELDIR"
done

cd "$ROOT"
echo "Execution complete. Logs are stored in $LOGDIR."
