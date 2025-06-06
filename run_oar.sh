#!/bin/bash
# run_oar.sh: Submit one OAR job per mode/tool combination, with a matrix of PetriSpot configurations.
#
# This script runs experiments using the following new modes:
#   PFLOWS, PSEMIFLOWS, TFLOWS, TSEMIFLOWS
#
# For each mode, it submits one job per tool. Allowed tool identifiers (passed via --tools) are:
#   tina       : Tina struct component (LAAS, CNRS)
#   tina4ti2   : Tina with 4ti2 integration (LAAS, CNRS)
#   itstools   : ITS-Tools (LIP6, Sorbonne Université)
#   petri32    : PetriSpot in 32-bit mode (LIP6, Sorbonne Université)
#   petri64    : PetriSpot in 64-bit mode (LIP6, Sorbonne Université)
#   petri128   : PetriSpot in 128-bit mode (LIP6, Sorbonne Université)
#   gspn       : GreatSPN (Università di Torino)
#   petrisage  : PetriSage with SageMath (uses model.mtx, TFLOWS or PFLOWS only)
#
# For PetriSpot tools, a matrix of extra flags is applied (see PETRI_MATRIX below).
#
# Cluster constraints:
#   - Only run on nodes with hostnames matching OARCONSTRAINTS
#   - Use 4 cores on 1 node
#   - Limit walltime to 24 hours (24:00:00)
#
# The work folder is set to:
#   /home/ythierry/git/InvariantPerformance
# (This folder contains run.sh and config.sh; deploy.sh has been run ahead of time)

#set -x

WORKDIR="/home/ythierry/git/InvariantPerformance"

# New modes to run
#MODES=(PFLOWS PSEMIFLOWS TFLOWS TSEMIFLOWS)
MODES=(PFLOWS TFLOWS)
#MODES=(PSEMIFLOWS)
#MODES=(PSEMIFLOWS TSEMIFLOWS)

# Allowed tool identifiers
#TOOLS=(tina tina4ti2 itstools petri32 petri64 petri128 gspn)
# TOOLS=(tina4ti2)
#TOOLS=(petri32 petri64 petri128)
#TOOLS=(tina tina4ti2 petri64 gspn)
#TOOLS=(petri64)
TOOLS=(petrisage)

# Model filter ranges to partition the workload
MODEL_FILTERS=("A-B" "C-D" "E-F" "G-I" "J-L" "M-O" "P-R" "S-U" "V-Z")

# OAR constraints: nodes "big25" or "big26", 4 cores, 12-hour walltime.
# OAR_CONSTRAINTS='{(host like "big25") OR (host like "big26")}/nodes=1/core=4,walltime=12:00:00'
OAR_CONSTRAINTS='{(host like "tall%")}/nodes=1/core=4,walltime=12:00:00'

# PetriSpot configuration matrix (array of arrays)
declare -A PETRI_MATRIX
PETRI_MATRIX[0]="--noSingleSignRow ''"                        # 2 options: on or off
PETRI_MATRIX[1]="--loopLimit=1 --loopLimit=500 --loopLimit=-1"  # 3 options
#PETRI_MATRIX[1]="--loopLimit=500"  # 3 options
PETRI_MATRIX[2]="--noTrivialCull ''"                          # 2 options
#PETRI_MATRIX[3]="--minBasis ''"                          # 2 options

# PetriSage backend flags (fixed set, only for PFLOWS/TFLOWS)
PETRISAGE_BACKENDS=("--extra-petrisage-flags=--backend=HNF" "--extra-petrisage-flags=--backend=PariKernel" "--extra-petrisage-flags=--backend=SNF" "--extra-petrisage-flags=--backend=Rational")

# --- Utility: Check if a tool is a PetriSpot variant ---
is_petrispot() {
  local tool="$1"
  case "$tool" in
    petri32|petri64|petri128)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Utility: Check if a tool is PetriSage ---
is_petrisage() {
  local tool="$1"
  case "$tool" in
    petrisage)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Function: Generate PetriSpot flag combinations ---
generate_petri_combinations() {
  local -a bases=()   # Number of options per flag set
  local total_combos=1

  # Calculate bases and total combinations
  for i in "${!PETRI_MATRIX[@]}"; do
    IFS=' ' read -ra options <<< "${PETRI_MATRIX[$i]}"
    bases[$i]=${#options[@]}
    total_combos=$((total_combos * bases[$i]))
  done

  # Print total to stderr
  echo "Total PetriSpot configurations to test: $total_combos" >&2

  local -a combinations=()
  for ((combo=0; combo<total_combos; combo++)); do
    local flags=""
    local temp=$combo

    # Convert combo number to flag indices (mixed-base number)
    for i in "${!PETRI_MATRIX[@]}"; do
      IFS=' ' read -ra options <<< "${PETRI_MATRIX[$i]}"
      local base=${bases[$i]}
      local index=$((temp % base))
      temp=$((temp / base))
      # Only add non-empty flags
      [ "${options[$index]}" != "''" ] && flags="$flags ${options[$index]}"
    done

    # Trim whitespace and format as --extra-petri-flags
    flags=$(echo "$flags" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -n "$flags" ]; then
      combinations+=("--extra-petri-flags=$flags")
    else
      combinations+=("")
    fi
  done

  # Output combinations, one per line, preserving multi-word strings
  printf '%q\n' "${combinations[@]}"
}

# --- Main Logic ---
echo "Computing PetriSpot configuration matrix..."
mapfile -t PETRI_COMBINATIONS < <(generate_petri_combinations)

for MODE in "${MODES[@]}"; do
  for TOOL in "${TOOLS[@]}"; do
    # Set COMBINATIONS based on tool type
    COMBINATIONS=()  # No 'local' here
    if is_petrispot "$TOOL"; then
      COMBINATIONS=("${PETRI_COMBINATIONS[@]}")
    elif is_petrisage "$TOOL" && { [ "$MODE" = "PFLOWS" ] || [ "$MODE" = "TFLOWS" ]; }; then
      COMBINATIONS=("${PETRISAGE_BACKENDS[@]}")
    else
      COMBINATIONS=("")
    fi

    # Submit one job per combination and model filter
    for EXTRA_FLAGS in "${COMBINATIONS[@]}"; do
      for MODEL_FILTER in "${MODEL_FILTERS[@]}"; do
        echo "Submitting OAR job for Mode: $MODE, Tool: $TOOL, Filter: $MODEL_FILTER${EXTRA_FLAGS:+, Extra Flags: $EXTRA_FLAGS}"
        oarsub -l "$OAR_CONSTRAINTS" "uname -a; cd $WORKDIR && ./run.sh $MODE --tools=$TOOL --mem=ANY -solution --model-filter=$MODEL_FILTER $EXTRA_FLAGS; exit"
      done
    done
  done
done