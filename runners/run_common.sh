#!/bin/bash
# run_common.sh
# Pure plumbing layer used by every normal runner.
# Provides flag compression, idempotent execution with temp files,
# LIMITS wrapping and standard solution collection.

compress_flags() {
  local flags="$1"
  local compressed=""
  local sep=""
  for flag in $flags; do
    if [[ $flag =~ ^--?([a-zA-Z0-9]+)(=[^ ]+)?$ ]]; then
      local name="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]:-}"
      value=${value//=/}
      value=${value//-1/inf}
      local abbr
      abbr=$(echo "$name" | sed 's/\([A-Z]\)[a-z]*/\1/g;s/-//g;s/^\(.\)/\L\1/')
      compressed="${compressed}${sep}${abbr}${value}"
      sep="_"
    fi
  done
  echo "$compressed"
}

# Signature: invoke_and_log "raw_cmd" "final_logfile" "solution_tool" "model_dir" "mode" "LIMITS" "SOLUTION"
invoke_and_log() {
  local raw_cmd="$1"
  local final_logfile="$2"
  local solution_tool="$3"
  local model_dir="$4"
  local mode="$5"
  local LIMITS="$6"
  local SOLUTION="$7"

  local temp_log="/tmp/$(basename "$final_logfile").$$"
  local temp_time="${temp_log}.time"

  if [ -f "$final_logfile" ]; then
    echo "  Skipping (already exists): $final_logfile"
    return 0
  fi

  local full_cmd="$LIMITS $raw_cmd"
  echo "  Running: $full_cmd"

  rm -f "$temp_time" "$temp_log"
  (
    cd "$model_dir" || exit 1
    eval "$full_cmd" > "$temp_log" 2> "$temp_time" || true
  )
  cat "$temp_time" >> "$temp_log"
  mv "$temp_log" "$final_logfile" || echo "Warning: mv failed"
  rm -f "$temp_time"

  if [ "$SOLUTION" = true ] && [ -n "$solution_tool" ]; then
    python3 "$ROOT/InvCompare/collectSolution.py" \
      --tool="$solution_tool" --log="$final_logfile" \
      --model="$model_dir" --mode="$mode" || true
  fi
}
