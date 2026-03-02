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
# Each group uses " | " as separator between alternatives (single-flag lines also work).

set -e

WORKDIR="/home/ythierry/git/InvariantPerformance"

# ====================== USER CONFIGURATION ======================

MEMLIMIT=ANY ; # or 16G
TIMEOUT=120 ; # in seconds

#MODES=(PFLOWS TFLOWS)
MODES=(PFLOWS PSEMIFLOWS TFLOWS TSEMIFLOWS)
#MODES=(PSEMIFLOWS)
#MODES=(PSEMIFLOWS TSEMIFLOWS)

TOOLS=(tina petri)
# TOOLS=(tina petri itstools gspn petrisage)

#MODEL_FILTERS=("A-B" "C-D" "E-F" "G-I" "J-L" "M-O" "P-R" "S-U" "V-Z")
MODEL_FILTERS=("I-I")

OAR_CONSTRAINTS='{(host like "tall%")}/nodes=1/core=4,walltime=12:00:00'
#OAR_CONSTRAINTS='{(host like "big25") OR (host like "big26")}/nodes=1/core=4,walltime=12:00:00'

# ====================== TOOL MATRICES ======================
# Each *_MATRIX_GROUPS is an array of groups.
# Inside each group, alternatives are separated by " | "
# '' means "no flag for this dimension"
# Single flag per line is also supported.

TINA_MATRIX_GROUPS=(
  "@MLton fixed-heap 15G -- -mp | @MLton max-heap 8G -- -4ti2 -I"    # tina w/o or with 4ti2
)

PETRI_MATRIX_GROUPS=(
  "-64"                       #   "-32 | -64 | -128"
  "--noSingleSignRow | ''"    # impacts phase 1
  "--loopLimit=500"           #   "--loopLimit=1 | --loopLimit=500 | --loopLimit=-1"
  "--noTrivialCull | ''"
  "--useQPlusBasis"           # positive rationals
  "--useCompression | ''"     # compression
)

ITSTOOLS_MATRIX_GROUPS=("")
GSPN_MATRIX_GROUPS=("")
PETRISAGE_MATRIX_GROUPS=(
  "--backend=HNF | --backend=PariKernel | --backend=SNF | --backend=Rational"
)

# ====================== SHARED MATRIX EXPANDER ======================
# Expands groups into full cartesian product of flag strings.
# Empty matrix always produces exactly one config (no flags).

generate_combinations() {
  local -a groups=("$@")
  local -a result=("")

  for group in "${groups[@]}"; do
    if [ -z "$group" ]; then
      continue
    fi
    local normalized="${group// | /|}"
    IFS='|' read -ra opts <<< "$normalized"
    local -a new=()
    for prev in "${result[@]}"; do
      for opt in "${opts[@]}"; do
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

  for i in "${!result[@]}"; do
    result[i]=$(echo "${result[i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  done

  if [ ${#result[@]} -eq 0 ]; then
    echo ""
  else
    printf '%s\n' "${result[@]}"
  fi
}

# ====================== CONFIG LOOKUP (EXPLICIT CASE) ======================
# Maps logical tool name to real tool + its matrix.
# PetriSage warning is printed only once per run.

PETRISAGE_WARNED=false

get_configurations_for_tool() {
  local logical_tool="$1"
  local mode="$2"

  if [ "$logical_tool" = "petrisage" ] && [ "$mode" != "PFLOWS" ] && [ "$mode" != "TFLOWS" ]; then
    if [ "$PETRISAGE_WARNED" = false ]; then
      echo "WARNING: petrisage is only supported for PFLOWS and TFLOWS. Skipping petrisage in $mode mode."
      PETRISAGE_WARNED=true
    fi
    echo "petrisage"
    echo ""
    return
  fi

  case "$logical_tool" in
    tina)
      echo "tina"
      generate_combinations "${TINA_MATRIX_GROUPS[@]}"
      ;;
    petri)
      echo "petri"
      generate_combinations "${PETRI_MATRIX_GROUPS[@]}"
      ;;
    itstools)
      echo "itstools"
      generate_combinations "${ITSTOOLS_MATRIX_GROUPS[@]}"
      ;;
    gspn)
      echo "gspn"
      generate_combinations "${GSPN_MATRIX_GROUPS[@]}"
      ;;
    petrisage)
      echo "petrisage"
      generate_combinations "${PETRISAGE_MATRIX_GROUPS[@]}"
      ;;
    *)
      echo "$logical_tool"
      echo ""
      ;;
  esac
}

# ====================== MAIN SUBMISSION LOOP ======================

echo "OAR submission started"

TOTAL_JOBS=0

for MODE in "${MODES[@]}"; do
  for TOOL in "${TOOLS[@]}"; do
    mapfile -t all_lines < <(get_configurations_for_tool "$TOOL" "$MODE")
    real_tool="${all_lines[0]}"
    flag_combos=("${all_lines[@]:1}")

    if [ ${#flag_combos[@]} -eq 0 ]; then
      flag_combos=("")
    fi

    echo "Mode: $MODE | Tool: $TOOL -> --tool=$real_tool | ${#flag_combos[@]} config(s)"

    for FLAGS in "${flag_combos[@]}"; do
      for FILTER in "${MODEL_FILTERS[@]}"; do
        echo "  Submitting: filter=$FILTER${FLAGS:+ | flags='$FLAGS'}"

        # -solution : also compute solutions and store them.
        CMD="./run_atool.sh $MODE --tool=$real_tool --mem=$MEMLIMIT -t=$TIMEOUT --model-filter=$FILTER"
        [ -n "$FLAGS" ] && CMD="$CMD --flags=\"$FLAGS\""

        echo "  oarsub -l \"$OAR_CONSTRAINTS\" \"cd $WORKDIR && $CMD; exit\""

        oarsub -l "$OAR_CONSTRAINTS" "cd $WORKDIR && $CMD; exit"

        TOTAL_JOBS=$((TOTAL_JOBS + 1))
      done
    done
  done
done

echo "All OAR jobs submitted ($TOTAL_JOBS total)"

