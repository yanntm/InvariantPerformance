#!/bin/bash
# run.sh: Run performance tests on models for a given mode and a selected set of tools.
#
# Usage:
#   ./run.sh [MODE] [--tools=tina,tina4ti2,itstools,petri32,petri64,petri128,gspn,petrisage] [--mem=VALUE] [-t TIMEOUT] [--extra-petri-flags=FLAGS] [--extra-petrisage-flags=FLAGS] [--model-filter=RANGE]
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
#   petrisage  : PetriSage with SageMath (uses model.mtx, TFLOWS or PFLOWS only)
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
# --extra-petrisage-flags=FLAGS:
#   Additional flags for PetriSage (e.g., "--backend=pari_kernel").
#   Logs will include a suffix based on these flags (e.g., ModelName.pK.petrisage).
#
# --model-filter=RANGE:
#   Process only models whose names start with a letter in the specified range (inclusive).
#   Format: X-Y (e.g., A-D, E-L, M-R, S-Z). Case-insensitive.
#   Default: process all models.
#
# Examples:
#   ./run.sh TFLOWS
#   ./run.sh PFLOWS --tools=tina4ti2,petri64,petrisage -t 300
#   ./run.sh TFLOWS --mem=ANY --extra-petri-flags="--noSingleSignRow --loopLimit=500" --extra-petrisage-flags="--backend=snf"
#   ./run.sh PFLOWS --model-filter=A-D

print_usage() {
    cat <<EOF
Usage: $0 [MODE] [--tools=tina,tina4ti2,itstools,petri32,petri64,petri128,gspn,petrisage] [--mem=VALUE] [-t=TIMEOUT] [-solution] [--extra-petri-flags=FLAGS] [--extra-petrisage-flags=FLAGS] [--model-filter=RANGE]

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
  petrisage  : PetriSage with SageMath (uses model.mtx, TFLOWS or PFLOWS only)

--mem=VALUE:
  Set memory limit for systemd-run (default: 16G, "ANY" disables).

-t=TIMEOUT:
  Set timeout in seconds (default: 120).

-solution:
  Collect solution files (*.sol) alongside logs.

--extra-petri-flags=FLAGS:
  Additional flags for PetriSpot tools (e.g., "--noSingleSignRow --loopLimit=500").
  Logs will include a suffix based on these flags (e.g., ModelName.nSSR_lL500.petri64).

--extra-petrisage-flags=FLAGS:
  Additional flags for PetriSage (e.g., "--backend=pari_kernel").
  Logs will include a suffix based on these flags (e.g., ModelName.pK.petrisage).

--model-filter=RANGE:
  Process only models whose names start with a letter in the specified range (inclusive).
  Format: X-Y (e.g., A-D, E-L, M-R, S-Z). Case-insensitive.
  Default: process all models.

Examples:
  $0 TFLOWS
  $0 PFLOWS --tools=tina4ti2,petri64,petrisage -t=300 -solution
  $0 TFLOWS --mem=ANY --extra-petri-flags="--noSingleSignRow --loopLimit=500" --extra-petrisage-flags="--backend=snf"
  $0 PFLOWS --model-filter=A-D
EOF
}

# Echo the full command invocation with all arguments to stdout
echo "Running: $0 $@"

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
TOOLS_TO_RUN="tina,tina4ti2,itstools,petri32,petri64,petri128,gspn,petrisage"
MEM_LIMIT="16G"
TIMEOUT_SEC=120
SOLUTION=false
EXTRA_PETRI_FLAGS=""
EXTRA_PETRISAGE_FLAGS=""
MODEL_FILTER_START=""
MODEL_FILTER_END=""

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
    --extra-petrisage-flags=*)
      EXTRA_PETRISAGE_FLAGS="${arg#*=}"
      ;;
    --model-filter=*)
      range="${arg#*=}"
      if [[ "$range" =~ ^([A-Za-z])-([A-Za-z])$ ]]; then
        MODEL_FILTER_START=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
        MODEL_FILTER_END=$(echo "${BASH_REMATCH[2]}" | tr '[:lower:]' '[:upper:]')
        if [[ "$MODEL_FILTER_START" > "$MODEL_FILTER_END" ]]; then
          echo "Error: Model filter range start ($MODEL_FILTER_START) must be less than or equal to end ($MODEL_FILTER_END)"
          print_usage
          exit 1
        fi
      else
        echo "Error: Invalid model filter range format. Use X-Y (e.g., A-D)"
        print_usage
        exit 1
      fi
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
allowed_tools="tina tina4ti2 itstools petri32 petri64 petri128 gspn petrisage"
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
    ["petrisage"]="$PETRISAGE"
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
    PETRISAGE_MODE="TFLOWS"
    LOGDIR="logs_tflows"
    ;;
  PFLOWS)
    TINA_FLAG="-F -P"
    ITS_FLAG="--Pflows"
    PETRISPOT_FLAG="--Pflows"
    GSPN_FLAG="-pbasis"
    PETRISAGE_MODE="PFLOWS"
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
    final_logfile="$LOGS/$model${extra_suffix}${log_suffix}"
    temp_logfile="/tmp/$model${extra_suffix}${log_suffix}$LOGDIR"
    temp_timelog="/tmp/$model${extra_suffix}${log_suffix}$LOGDIR.timelog"
    [ -f "$temp_timelog" ] && rm -f "$temp_timelog"
    if [ ! -f "$final_logfile" ]; then
      cmd="$LIMITS \"$petri_cmd\" -i \"$model_dir/model.norm.pnml\" $PETRISPOT_FLAG $EXTRA_PETRI_FLAGS > \"$temp_logfile\" 2> \"$temp_timelog\""
      echo "Running $tool_name: $cmd"
      eval "$cmd"
      cat "$temp_timelog" >> "$temp_logfile"
      mv "$temp_logfile" "$final_logfile" || echo "Warning: Failed to move $temp_logfile to $final_logfile"
      rm -f "$temp_timelog"
      if [ "$SOLUTION" = true ]; then
        python3 "$ROOT/InvCompare/collectSolution.py" --tool=petrispot --log="$final_logfile" \
          --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model${extra_suffix}${log_suffix}"
      fi
    fi
  fi
}

# --- Function: Run PetriSage ---
run_petrisage() {
  local tool_name="petrisage"
  local petrisage_cmd="$PETRISAGE"
  local log_suffix=".petrisage"
  local model_dir="$1"  # Model directory
  local model="$2"      # Model name
  local extra_suffix="$3"  # Extra flags suffix (e.g., ".pK")

  if contains_tool "$tool_name"; then
    # Check if mode is supported by petrisage
    if [ "$MODE" != "TFLOWS" ] && [ "$MODE" != "PFLOWS" ]; then
      echo "Warning: petrisage only supports TFLOWS or PFLOWS, skipping for mode $MODE"
      return
    fi
    final_logfile="$LOGS/$model${extra_suffix}${log_suffix}"
    temp_logfile="/tmp/$model${extra_suffix}${log_suffix}$LOGDIR"
    temp_timelog="/tmp/$model${extra_suffix}${log_suffix}$LOGDIR.timelog"
    [ -f "$temp_timelog" ] && rm -f "$temp_timelog"
    if [ ! -f "$final_logfile" ]; then
      cmd="$LIMITS bash -c 'source \"$ROOT/config.sh\" && \$MICROMAMBA activate \$SAGE_ENV && \"$petrisage_cmd\" \"$model_dir/model.mtx\" \"$temp_logfile.tba\" $PETRISAGE_MODE $EXTRA_PETRISAGE_FLAGS' > \"$temp_logfile\" 2> \"$temp_timelog\""
      echo "Running $tool_name: $cmd"
      eval "$cmd"
      cat "$temp_timelog" >> "$temp_logfile"
      mv "$temp_logfile" "$final_logfile" || echo "Warning: Failed to move $temp_logfile to $final_logfile"
      rm -f "$temp_timelog"
      if [ "$SOLUTION" = true ]; then
        python3 "$ROOT/InvCompare/collectSolution.py" --tool=petrisage --log="$final_logfile" \
          --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model${extra_suffix}${log_suffix}"
      fi
    fi
  fi
}

# --- Process Each Model ---
for model_dir in "$MODELDIR"/*/; do
    model=$(basename "$model_dir")
    if [ -n "$MODEL_FILTER_START" ] && [ -n "$MODEL_FILTER_END" ]; then
        first_letter=$(echo "$model" | cut -c1 | tr '[:lower:]' '[:upper:]')
        if [[ "$first_letter" < "$MODEL_FILTER_START" || "$first_letter" > "$MODEL_FILTER_END" ]]; then
            continue
        fi
    fi
    cd "$model_dir" || exit
    echo "Processing model: $model"
    
    # --- Tina (without 4ti2 integration) ---
    if contains_tool tina; then
        final_logfile="$LOGS/$model.tina"
        temp_logfile="/tmp/$model$LOGDIR.tina"
        temp_timelog="/tmp/$model$LOGDIR.tina.timelog"
        [ -f "$temp_timelog" ] && rm -f "$temp_timelog"
        if [ ! -f "$final_logfile" ]; then
            tina_cmd="$STRUCT"
            if [ -f large_marking ]; then tina_cmd="$STRUCTLARGE"; fi
            cmd="$LIMITS \"$tina_cmd\" @MLton fixed-heap 15G -- $TINA_FLAG -mp \"$model_dir/model.norm.pnml\" > \"$temp_logfile\" 2> \"$temp_timelog\""
            echo "Running tina: $cmd"
            eval "$cmd"
            cat "$temp_timelog" >> "$temp_logfile"
            mv "$temp_logfile" "$final_logfile" || echo "Warning: Failed to move $temp_logfile to $final_logfile"
            rm -f "$temp_timelog"
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=tina --log="$final_logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.tina"
            fi
        fi
    fi

    # --- Tina with 4ti2 integration ---
    if contains_tool tina4ti2; then
        final_logfile="$LOGS/$model.struct"
        temp_logfile="/tmp/$model$LOGDIR.struct"
        temp_timelog="/tmp/$model$LOGDIR.struct.timelog"
        [ -f "$temp_timelog" ] && rm -f "$temp_timelog"
        if [ ! -f "$final_logfile" ]; then
            export PATH=$ROOT/bin:$PATH
            tina_cmd="$STRUCT"
            if [ -f large_marking ]; then tina_cmd="$STRUCTLARGE"; fi
            cmd="$LIMITS \"$tina_cmd\" @MLton max-heap 8G -- -4ti2 $TINA_FLAG -I \"$model_dir/model.norm.pnml\" > \"$temp_logfile\" 2> \"$temp_timelog\""
            echo "Running tina4ti2: $cmd"
            eval "$cmd"
            cat "$temp_timelog" >> "$temp_logfile"
            mv "$temp_logfile" "$final_logfile" || echo "Warning: Failed to move $temp_logfile to $final_logfile"
            rm -f "$temp_timelog"
            sync  # Optional: Ensure NFS sync after move
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=tina --log="$final_logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.struct"
            fi
        fi
    fi

    # --- ITS-Tools ---
    if contains_tool itstools; then
        final_logfile="$LOGS/$model.its"
        temp_logfile="/tmp/$model$LOGDIR.its"
        temp_timelog="/tmp/$model$LOGDIR.its.timelog"
        [ -f "$temp_timelog" ] && rm -f "$temp_timelog"
        if [ ! -f "$final_logfile" ]; then
            cmd="$LIMITS \"$ITSTOOLS\" -pnfolder \"$model_dir\" $ITS_FLAG > \"$temp_logfile\" 2> \"$temp_timelog\""
            echo "Running itstools: $cmd"
            eval "$cmd"
            cat "$temp_timelog" >> "$temp_logfile"
            mv "$temp_logfile" "$final_logfile" || echo "Warning: Failed to move $temp_logfile to $final_logfile"
            rm -f "$temp_timelog"
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=itstools --log="$final_logfile" \
                  --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.its"
            fi
        fi
    fi

    # Compute log suffix for PetriSpot tools if extra flags are provided
    extra_petri_suffix=""
    if [ -n "$EXTRA_PETRI_FLAGS" ]; then
        extra_petri_suffix=".$(compress_flags "$EXTRA_PETRI_FLAGS")"
    fi

    # --- Run PetriSpot variants ---
    run_petrispot "petri32" "$PETRISPOT32" ".petri32" "$model_dir" "$model" "$extra_petri_suffix"
    run_petrispot "petri64" "$PETRISPOT64" ".petri64" "$model_dir" "$model" "$extra_petri_suffix"
    run_petrispot "petri128" "$PETRISPOT128" ".petri128" "$model_dir" "$model" "$extra_petri_suffix"

    # Compute log suffix for PetriSage if extra flags are provided
    extra_petrisage_suffix=""
    if [ -n "$EXTRA_PETRISAGE_FLAGS" ]; then
        extra_petrisage_suffix=".$(compress_flags "$EXTRA_PETRISAGE_FLAGS")"
    fi

    # --- Run PetriSage ---
    run_petrisage "$model_dir" "$model" "$extra_petrisage_suffix"

    # --- GreatSPN ---
    if contains_tool gspn; then
        final_logfile="$LOGS/$model.gspn"
        temp_logfile="/tmp/$model$LOGDIR.gspn"
        temp_timelog="/tmp/$model$LOGDIR.gspn.timelog"
        [ -f "$temp_timelog" ] && rm -f "$temp_timelog"
        if [ ! -f "$final_logfile" ]; then
            cmd="$LIMITS \"$DSPN\" -load model $GSPN_FLAG > \"$temp_logfile\" 2> \"$temp_timelog\""
            echo "Running gspn: $cmd"
            eval "$cmd"
            cat "$temp_timelog" >> "$temp_logfile"
            mv "$temp_logfile" "$final_logfile" || echo "Warning: Failed to move $temp_logfile to $final_logfile"
            rm -f "$temp_timelog"
            if [ "$SOLUTION" = true ]; then
                python3 "$ROOT/InvCompare/collectSolution.py" --tool=greatspn --log="$final_logfile" \
                    --model="$model_dir" --mode="$MODE" || echo "Warning: Failed to collect solution for $model.gspn"
            fi
        fi
    fi

    cd "$MODELDIR"
done

cd "$ROOT"
echo "Execution complete. Logs are stored in $LOGDIR."