#!/bin/bash
# run.sh: Run performance tests on models for a given mode and a selected set of tools.
#
# Usage:
#   ./run.sh [MODE] [--tools=tina,tina4ti2,itstools,petri32,petri64,petri128,gspn] [--mem=VALUE] [-t TIMEOUT] [--extra-petri-flags=FLAGS]
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
# -t TIMEOUT:
#   Set timeout in seconds (default: 120).
#
# --extra-petri-flags=FLAGS:
#   Additional flags for PetriSpot tools (e.g., "--noSingleSignRow --loopLimit=500").
#   Logs will include a suffix based on these flags (e.g., ModelName.nSSR_lL500.petri64).
#
# Examples:
#   ./run.sh FLOWS
#   ./run.sh PSEMIFLOWS --tools=tina4ti2,petri64 -t 300
#   ./run.sh PFLOWS --mem=ANY --extra-petri-flags="--noSingleSignRow --loopLimit=500"

print_usage() {
    cat <<EOF
Usage: $0 [MODE] [--tools=tina,tina4ti2,itstools,petri32,petri64,petri128,gspn] [--mem=VALUE] [-t=TIMEOUT] [-solution] [--extra-petri-flags=FLAGS]

MODE must be one of:
  FLOWS, SEMIFLOWS, TFLOWS, PFLOWS, TSEMIFLOWS, PSEMIFLOWS

Tool names and their meanings: (default : all tools)
  tina       : Tina struct component (LAAS, CNRS)
  tina4ti2   : Tina with 4ti2 integration (LAAS, CNRS)
  itstools   : ITS-Tools (LIP6, Sorbonne Université)
  petri32    : PetriSpot in 32-bit mode (LIP6, Sorbonne Université)
  petri64    : PetriSpot in 64-bit mode (LIP6, Sorbonne Université)
  petri128   : PetriSpot in 128-bit mode (LIP6, Sorbonne Université)
  gspn       : GreatSPN (Università di Torino)

--mem=VALUE:
  Set memory limit for systemd-run (default: 16G, "ANY" disables).

-t=TIMEOUT:
  Set timeout in seconds (default: 120).

-solution:
  Collect solution files (*.sol) alongside logs.

--extra-petri-flags=FLAGS:
  Additional flags for PetriSpot tools (e.g., "--noSingleSignRow --loopLimit=500").
  Logs will include a suffix based on these flags (e.g., ModelName.nSSR_lL500.petri64).

Examples:
  $0 FLOWS
  $0 PSEMIFLOWS --tools=tina4ti2,petri64 -t=300 -solution
  $0 PFLOWS --mem=ANY --extra-petri-flags="--noSingleSignRow --loopLimit=500"
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

# Default values
TOOLS_TO_RUN="tina,tina4ti2,itstools,petri32,petri64,petri128,gspn"
MEM_LIMIT="16G"
TIMEOUT_SEC=120
SOLUTION=false
EXTRA_PETRI_FLAGS=""

for arg in "$@"; do
  case "$arg" in
    --tools=*)
      TOOLS_TO_RUN="${arg#*=}"
      ;;
    -mem=*|--mem=*)
      MEM_LIMIT="${arg#*=}"
      ;;
    -t=*)
      TIMEOUT_SEC="${arg#*=}"
      ;;
    --extra-petri-flags=*)
      EXTRA_PETRI_FLAGS="${arg#*=}"
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

# Validate timeout is a positive integer
if ! [[ "$TIMEOUT_SEC" =~ ^[0-9]+$ ]] || [ "$TIMEOUT_SEC" -le 0 ]; then
    echo "Error: Timeout must be a positive integer."
    print_usage
    exit 1
fi

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

# Set memory limits and timeout based on flags
if [ "$MEM_LIMIT" = "ANY" ]; then
    export LIMITS="$TIMEOUT $TIMEOUT_SEC time"
else
    export LIMITS="$TIMEOUT $TIMEOUT_SEC time systemd-run --scope -p MemoryMax=$MEM_LIMIT --user"
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

# --- Utility: Compress extra flags into a unique suffix ---
compress_flags() {
  local flags="$1"
  local compressed=""
  local sep=""  # Separator starts empty, becomes _ after first flag

  for flag in $flags; do
    if [[ $flag =~ ^--([a-zA-Z]+)(=[0-9-]+)?$ ]]; then
      local name="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]:-}"  # Capture value, default to empty if absent

      # Replace -1 with inf, remove =
      value=${value//=-1/inf}
      value=${value//=/}

      # Compress name: uppercase first letter, keep first letter of each lowercase segment or after hyphen, preserve capitals
      local abbr=$(echo "$name" | sed 's/\([A-Z]\)[a-z]*/\1/g;s/-//g;s/^\(.\)/\L\1/')
      
      # Append to compressed string with separator
      compressed="${compressed}${sep}${abbr}${value}"
      sep="_"
    fi
  done
  echo "$compressed"
}

# --- Function: Run PetriSpot for a given variant ---
run_petrispot() {
  local tool_name="$1"  # e.g., "petri32"
  local petri_cmd="$2"  # e.g., "$PETRISPOT32"
  local log_suffix="$3" # e.g., ".petri32"
  local model_dir="$4"  # Model directory
  local model="$5"      # Model name
  local extra_suffix="$6"  # Extra flags suffix (e.g., ".nSSRlL500")

  if contains_tool "$tool_name"; then
    logfile="$LOGS/$model${extra_suffix}${log_suffix}"
    if [ ! -f "$logfile" ]; then
      $LIMITS "$petri_cmd" -i "$model_dir/model.pnml" $PETRISPOT_FLAG $EXTRA_PETRI_FLAGS \
        > "$logfile" 2>&1
      if [ "$SOLUTION" = true ]; then
        python3 "$ROOT/InvCompare/collectSolution.py" --tool=petrispot --log="$logfile" \
          --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model${extra_suffix}${log_suffix}"
      fi
    fi
  fi
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
            export PATH=$ROOT/bin:$PATH
            tina_cmd="$STRUCT"
            if [ -f large_marking ]; then tina_cmd="$STRUCTLARGE"; fi
            $LIMITS "$tina_cmd" @MLton max-heap 8G -- -4ti2 $TINA_FLAG -I "$model_dir/model.pnml" \
                > "$logfile" 2>&1
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

    # Compute log suffix for PetriSpot tools if extra flags are provided
    extra_flags_suffix=""
    if [ -n "$EXTRA_PETRI_FLAGS" ]; then
        extra_flags_suffix=".$(compress_flags "$EXTRA_PETRI_FLAGS")"
    fi

    # --- Run PetriSpot variants ---
    run_petrispot "petri32" "$PETRISPOT32" ".petri32" "$model_dir" "$model" "$extra_flags_suffix"
    run_petrispot "petri64" "$PETRISPOT64" ".petri64" "$model_dir" "$model" "$extra_flags_suffix"
    run_petrispot "petri128" "$PETRISPOT128" ".petri128" "$model_dir" "$model" "$extra_flags_suffix"

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