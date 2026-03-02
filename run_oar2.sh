#!/bin/bash
# run_oar.sh
# OAR job submitter for the new run_atool.sh architecture.
#
# Only edit the top section:
#   - MEMLIMIT / TIMEOUT
#   - MODES
#   - TOOLS list
#   - MODEL_FILTERS
#   - OAR_CONSTRAINTS
#   - the five *_MATRIX_GROUPS arrays
#
# All tools use identical matrix syntax and the same expander function.
# Each group uses " | " as separator between alternatives.

set -e

WORKDIR="/home/ythierry/git/InvariantPerformance"

# ====================== USER CONFIGURATION ======================

MEMLIMIT=ANY ; # or 16G
TIMEOUT=120 ; # in seconds

MODES=(PFLOWS TFLOWS)
#MODES=(PFLOWS PSEMIFLOWS TFLOWS TSEMIFLOWS)
#MODES=(PSEMIFLOWS)
#MODES=(PSEMIFLOWS TSEMIFLOWS)

TOOLS=(tina petri itstools gspn petrisage)
#TOOLS=(tina tina4ti2)
#TOOLS=(petri32 petri64 petri128)
#TOOLS=(tina tina4ti2 petri64 gspn)
#TOOLS=(petri64)
#TOOLS=(petrisage)

MODEL_FILTERS=("A-B" "C-D" "E-F" "G-I" "J-L" "M-O" "P-R" "S-U" "V-Z")

OAR_CONSTRAINTS='{(host like "tall%")}/nodes=1/core=4,walltime=12:00:00'
#OAR_CONSTRAINTS='{(host like "big25") OR (host like "big26")}/nodes=1/core=4,walltime=12:00:00'

# ====================== TOOL MATRICES ======================
# Each *_MATRIX_GROUPS is an array of groups.
# Inside each group, alternatives are separated by " | "
# '' means "no flag for this dimension"

TINA_MATRIX_GROUPS=(
  "@MLton fixed-heap 15G -- | @MLton max-heap 8G -- -4ti2"
  # add your 8 new Tina variants here, one line per group if needed
)

PETRI_MATRIX_GROUPS=(
  "-32 | -64 | -128"
  "--noSingleSignRow | ''"
  "--loopLimit=1 | --loopLimit=500 | --loopLimit=-1"
  "--noTrivialCull | ''"
  # "--minBasis | ''"   # uncomment to add more dimensions
)

ITSTOOLS_MATRIX_GROUPS=(
  ""
)

GSPN_MATRIX_GROUPS=(
  ""
)

PETRISAGE_MATRIX_GROUPS=(
  "--backend=HNF | --backend=PariKernel | --backend=SNF | --backend=Rational"
)

# ====================== SHARED MATRIX EXPANDER ======================

# Expands groups into full cartesian product of flag strings.
# Handles complex flags containing spaces by normalizing " | " separator.
generate_combinations() {
  local -a groups=("$@")
  local -a result=("")

  for group in "${groups[@]}"; do
    if [ -z "$group" ]; then
      continue
    fi
    # Normalize and split on literal " | "
    local normalized="${group// | /|}"
    IFS='|' read -ra opts <<< "$normalized"
    local -a new=()
    for prev in "${result[@]}"; do
      for opt in "${opts[@]}"; do
        # Trim whitespace from each option
        opt=$(echo "$opt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ "$opt" != "''" ] && [ -n "$opt" ]; then
          new+=("${prev:+$prev }$opt")
        else
          new+=("$prev")
        fi
      done
    done
    result=("${new[@]}")
  done

  # Clean leading/trailing whitespace on each final combination
  for i in "${!result[@]}"; do
    result[i]=$(echo "${result[i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  done

  printf '%s\n' "${result[@]}"
}

# ====================== CONFIG LOOKUP ======================

# One-time warning flag for petrisage on unsupported modes
PETRISAGE_WARNED=false

get_configurations_for_tool() {
  local logical_tool="$1"
  local mode="$2"

  # Special handling for petrisage (only allowed in flows modes)
  if [ "$logical_tool" = "petrisage" ] && [ "$mode" != "PFLOWS" ] && [ "$mode" != "TFLOWS" ]; then
    if [ "$PETRISAGE_WARNED" = false ]; then
      echo "WARNING: petrisage is only supported for PFLOWS and TFLOWS. Skipping petrisage in $mode mode."
      PETRISAGE_WARNED=true
    fi
    echo "petrisage"
    echo ""
    return
  fi

  # Dynamic matrix resolution: tina -> TINA_MATRIX_GROUPS
  local upper_tool
  upper_tool=$(echo "$logical_tool" | tr '[:lower:]' '[:upper:]')
  local matrix_var="${upper_tool}_MATRIX_GROUPS"

  echo "$logical_tool"

  if declare -p "$matrix_var" &>/dev/null 2>&1; then
    generate_combinations "${!matrix_var[@]}"
  else
    echo ""
  fi
}

# ====================== MAIN SUBMISSION LOOP ======================

echo "OAR submission started"

TOTAL_JOBS=0

for MODE in "${MODES[@]}"; do
  for TOOL in "${TOOLS[@]}"; do
    mapfile -t configs < <(get_configurations_for_tool "$TOOL" "$MODE")
    real_tool="${configs[0]}"
    unset 'configs[0]'

    if [ ${#configs[@]} -eq 0 ] || { [ ${#configs[@]} -eq 1 ] && [ -z "${configs[0]}" ]; }; then
      echo "Skipping $TOOL in $MODE (no configurations)"
      continue
    fi

    echo "Mode: $MODE | Tool: $TOOL -> --tool=$real_tool | ${#configs[@]} config(s)"

    for FLAGS in "${configs[@]}"; do
      for FILTER in "${MODEL_FILTERS[@]}"; do
        echo "  Submitting: filter=$FILTER${FLAGS:+ | flags='$FLAGS'}"

        CMD="./run_atool.sh $MODE --tool=$real_tool --mem=$MEMLIMIT -t=$TIMEOUT -solution --model-filter=$FILTER"
        [ -n "$FLAGS" ] && CMD="$CMD --flags=\"$FLAGS\""

        # Print the exact oarsub line before submitting
        echo "  oarsub -l \"$OAR_CONSTRAINTS\" \"cd $WORKDIR && $CMD; exit\""

        oarsub -l "$OAR_CONSTRAINTS" "cd $WORKDIR && $CMD; exit"

        TOTAL_JOBS=$((TOTAL_JOBS + 1))
      done
    done
  done
done

echo "All OAR jobs submitted ($TOTAL_JOBS total)"

