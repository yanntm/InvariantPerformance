#!/bin/bash
# run.sh: Run performance tests on models for a given mode and a selected set of tools.
#
# Usage:
#   ./run.sh [MODE] [--tools=tina,tina4ti2,itstools,petri32,petri64,petri128,gspn] [--mem=VALUE]
#
# MODE must be one of:
#   FLOWS, SEMIFLOWS, TFLOWS, PFLOWS, TSEMIFLOWS, PSEMIFLOWS
#
# Tool names and their meanings:
#   tina       : Tina struct component (LAAS, CNRS)
#   tina4ti2   : Tina with 4ti2 integration (LAAS, CNRS)
#   itstools   : ITS-Tools (LIP6, Sorbonne Université)
#   petri32    : PetriSpot in 32-bit mode (LIP6, Sorbonne Université)
#   petri64    : PetriSpot in 64-bit mode (LIP6, Sorbonne Université)
#   petri128   : PetriSpot in 128-bit mode (LIP6, Sorbonne Université)
#   gspn       : GreatSPN (Università di Torino)
#
# --mem=VALUE:
#   Set memory limit for systemd-run.
#   Default is "16G". Use "ANY" to disable the memory limit.
#
# Examples:
#   ./run.sh FLOWS
#   ./run.sh PSEMIFLOWS --tools=tina4ti2,petri64
#   ./run.sh PFLOWS --mem=ANY

print_usage() {
    cat <<EOF
Usage: $0 [MODE] [--tools=tina,tina4ti2,itstools,petri32,petri64,petri128,gspn] [--mem=VALUE]

MODE must be one of:
  FLOWS, SEMIFLOWS, TFLOWS, PFLOWS, TSEMIFLOWS, PSEMIFLOWS

Tool names and their meanings:
  tina       : Tina struct component (LAAS, CNRS)
  tina4ti2   : Tina with 4ti2 integration (LAAS, CNRS)
  itstools   : ITS-Tools (LIP6, Sorbonne Université)
  petri32    : PetriSpot in 32-bit mode (LIP6, Sorbonne Université)
  petri64    : PetriSpot in 64-bit mode (LIP6, Sorbonne Université)
  petri128   : PetriSpot in 128-bit mode (LIP6, Sorbonne Université)
  gspn       : GreatSPN (Università di Torino)

--mem=VALUE:
  Set memory limit for systemd-run.
  Default is "16G". Use "ANY" to disable memory limit.

Examples:
  $0 FLOWS
  $0 PSEMIFLOWS --tools=tina4ti2,petri64
  $0 PFLOWS --mem=ANY
EOF
}

# Print usage if no arguments provided or help is requested.
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_usage
    exit 0
fi

# --- Ensure configuration is available ---
if [ ! -f ./config.sh ]; then
    echo "Error: config.sh not found. Please run the deployment script first."
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

# --- Parse Arguments ---
MODE="$1"
shift

# Default: run all tools
TOOLS_TO_RUN="tina,tina4ti2,itstools,petri32,petri64,petri128,gspn"
MEM_LIMIT="16G"

for arg in "$@"; do
  case "$arg" in
    --tools=*)
      TOOLS_TO_RUN="${arg#*=}"
      ;;
    -mem=*|--mem=*)
      MEM_LIMIT="${arg#*=}"
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      print_usage
      exit 1
      ;;
  esac
done

# Validate provided tool names.
allowed_tools="tina tina4ti2 itstools petri32 petri64 petri128 gspn"
IFS=',' read -ra selected_tools <<< "$TOOLS_TO_RUN"
for tool in "${selected_tools[@]}"; do
    valid=0
    for allowed in $allowed_tools; do
        if [ "$tool" = "$allowed" ]; then
            valid=1
            break
        fi
    done
    if [ $valid -ne 1 ]; then
        echo "Error: unknown tool: $tool"
        print_usage
        exit 1
    fi
done

# Set memory limits based on MEM_LIMIT flag.
if [ "$MEM_LIMIT" = "ANY" ]; then
    export LIMITS="$TIMEOUT 120 time"
else
    export LIMITS="$TIMEOUT 120 time systemd-run --scope -p MemoryMax=$MEM_LIMIT --user"
fi

# --- Set Mode-Specific Flags ---
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
    echo "Error: unknown mode: $MODE"
    print_usage
    exit 1
    ;;
esac

mkdir -p "$LOGDIR"
export LOGS="$PWD/$LOGDIR"

# --- Utility: Check if a given tool is requested ---
contains_tool() {
  local needle="$1"
  local tool
  IFS=',' read -ra arr <<< "$TOOLS_TO_RUN"
  for tool in "${arr[@]}"; do
    if [ "$tool" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

# --- Process Each Model ---
for model_dir in "$MODELDIR"/*/; do
    cd "$model_dir" || exit
    model=$(basename "$model_dir")
    echo "Processing model: $model"
    
    # --- Tina (without 4ti2 integration) ---
    if contains_tool tina; then
      if [ ! -f "$LOGS/$model.tina" ]; then
          if [ -f large_marking ]; then
              $LIMITS "$STRUCTLARGE" @MLton fixed-heap 15G -- $TINA_FLAG -mp -q "$model_dir/model.pnml" \
                  > "$LOGS/$model.tina" 2>&1
          else
              $LIMITS "$STRUCT" @MLton fixed-heap 15G -- $TINA_FLAG -mp -q "$model_dir/model.pnml" \
                  > "$LOGS/$model.tina" 2>&1
          fi
      fi
    fi

    # --- Tina with 4ti2 integration ---
    if contains_tool tina4ti2; then
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
    fi

    # --- ITS-Tools ---
    if contains_tool itstools; then
      if [ ! -f "$LOGS/$model.its" ]; then
          $LIMITS "$ITSTOOLS" -pnfolder "$model_dir" $ITS_FLAG \
              > "$LOGS/$model.its" 2>&1
      fi
    fi

    # --- PetriSpot 32-bit ---
    if contains_tool petri32; then
      if [ ! -f "$LOGS/$model.petri32" ]; then
          $LIMITS "$PETRISPOT32" -i "$model_dir/model.pnml" -q $PETRISPOT_FLAG \
              > "$LOGS/$model.petri32" 2>&1
      fi
    fi

    # --- PetriSpot 64-bit ---
    if contains_tool petri64; then
      if [ ! -f "$LOGS/$model.petri64" ]; then
          $LIMITS "$PETRISPOT64" -i "$model_dir/model.pnml" -q $PETRISPOT_FLAG \
              > "$LOGS/$model.petri64" 2>&1
      fi
    fi

    # --- PetriSpot 128-bit ---
    if contains_tool petri128; then
      if [ ! -f "$LOGS/$model.petri128" ]; then
          $LIMITS "$PETRISPOT128" -i "$model_dir/model.pnml" -q $PETRISPOT_FLAG \
              > "$LOGS/$model.petri128" 2>&1
      fi
    fi

    # --- GreatSPN ---
    if contains_tool gspn; then
      if [ ! -f "$LOGS/$model.gspn" ]; then
          $LIMITS "$DSPN" -load model $GSPN_FLAG \
              > "$LOGS/$model.gspn" 2>&1
      fi
    fi

    cd "$MODELDIR"
done

cd "$ROOT"
echo "Execution complete. Logs are stored in $LOGDIR."
