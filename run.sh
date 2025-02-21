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
Usage: $0 [MODE] [--tools=tina,tina4ti2,itstools,petri32,petri64,petri128,gspn] [--mem=VALUE] [-solution]

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
  Set memory limit for systemd-run (default: 16G, "ANY" disables).

-solution:
  Collect solution files (*.sol) alongside logs.

Examples:
  $0 FLOWS
  $0 PSEMIFLOWS --tools=tina4ti2,petri64 -solution
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


# --- Parse Arguments ---
MODE="$1"
shift

# Default: run all tools
TOOLS_TO_RUN="tina,tina4ti2,itstools,petri32,petri64,petri128,gspn"
MEM_LIMIT="16G"
SOLUTION=false

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
    -solution) 
      SOLUTION=true 
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

# --- Check Required Binaries for Selected Tools ---
check_executable() {
    if [ ! -x "$1" ]; then
        echo "Error: '$1' not found or not executable."
        exit 1
    fi
}

# Map tools to their executables
declare -A tool_to_exe=(
    ["tina"]="$STRUCT"
    ["tina4ti2"]="$STRUCT"
    ["itstools"]="$ITSTOOLS"
    ["petri32"]="$PETRISPOT32"
    ["petri64"]="$PETRISPOT64"
    ["petri128"]="$PETRISPOT128"
    ["gspn"]="$DSPN"
)

# Check only selected tools
IFS=',' read -ra selected_tools <<< "$TOOLS_TO_RUN"
for tool in "${selected_tools[@]}"; do
    check_executable "${tool_to_exe[$tool]}"
done
check_executable "$TIMEOUT"  # Always needed


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

# Adjust tool flags based on SOLUTION mode: add -q if not collecting solutions
if [ "$SOLUTION" != true ]; then
    TINA_FLAG="$TINA_FLAG -q"
    ITS_FLAG="$ITS_FLAG -q"
    PETRISPOT_FLAG="$PETRISPOT_FLAG -q"
fi

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
        logfile="$LOGS/$model.tina"
        if [ ! -f "$logfile" ]; then
            tina_cmd="$STRUCT"
            if [ -f large_marking ]; then tina_cmd="$STRUCTLARGE"; fi
            $LIMITS "$tina_cmd" @MLton fixed-heap 15G -- $TINA_FLAG -mp "$model_dir/model.pnml" \
                > "$logfile" 2>&1
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=tina --log="$logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.tina"
            fi
        fi
    fi

    # --- Tina with 4ti2 integration ---
    if contains_tool tina4ti2; then
        logfile="$LOGS/$model.struct"
        if [ ! -f "$logfile" ]; then
            rm -f /tmp/f-* > /dev/null 2>&1
            export PATH=$ROOT/bin:$PATH
            tina_cmd="$STRUCT"
            if [ -f large_marking ]; then tina_cmd="$STRUCTLARGE"; fi
            $LIMITS "$tina_cmd" @MLton max-heap 8G -- -4ti2 $TINA_FLAG -I "$model_dir/model.pnml" \
                > "$logfile" 2>&1
            rm -f /tmp/f-* > /dev/null 2>&1
            sync
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=tina --log="$logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.struct"
            fi
        fi
    fi

    # --- ITS-Tools ---
    if contains_tool itstools; then
        logfile="$LOGS/$model.its"
        if [ ! -f "$logfile" ]; then
            $LIMITS "$ITSTOOLS" -pnfolder "$model_dir" $ITS_FLAG \
                > "$logfile" 2>&1
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=itstools --log="$logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.its"
            fi
        fi
    fi

    # --- PetriSpot 32-bit ---
    if contains_tool petri32; then
        logfile="$LOGS/$model.petri32"
        if [ ! -f "$logfile" ]; then
            $LIMITS "$PETRISPOT32" -i "$model_dir/model.pnml" $PETRISPOT_FLAG \
                > "$logfile" 2>&1
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=petrispot --log="$logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.petri32"
            fi
        fi
    fi

    # --- PetriSpot 64-bit ---
    if contains_tool petri64; then
        logfile="$LOGS/$model.petri64"
        if [ ! -f "$logfile" ]; then
            $LIMITS "$PETRISPOT64" -i "$model_dir/model.pnml" $PETRISPOT_FLAG \
                > "$logfile" 2>&1
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=petrispot --log="$logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.petri64"
            fi
        fi
    fi

    # --- PetriSpot 128-bit ---
    if contains_tool petri128; then
        logfile="$LOGS/$model.petri128"
        if [ ! -f "$logfile" ]; then
            $LIMITS "$PETRISPOT128" -i "$model_dir/model.pnml" $PETRISPOT_FLAG \
                > "$logfile" 2>&1
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=petrispot --log="$logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.petri128"
            fi
        fi
    fi

    # --- GreatSPN ---
    if contains_tool gspn; then
        logfile="$LOGS/$model.gspn"
        if [ ! -f "$logfile" ]; then
            $LIMITS "$DSPN" -load model $GSPN_FLAG \
                > "$logfile" 2>&1
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=greatspn --log="$logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.gspn"
            fi
        fi
    fi

    cd "$MODELDIR"
done

cd "$ROOT"
echo "Execution complete. Logs are stored in $LOGDIR."
