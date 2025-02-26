#!/bin/bash

# Array to track CSV basenames generated in this run
csv_types=()

# Process logs_* directories
for i in logs_*; do
  cd "$i" || exit 1
  type=$(echo "$i" | sed 's/logs_//')
  ../logs2csvpar.pl --parallel=10 > "../$type.csv"  & # Writes to ../$type.csv : Detached !
  csv_types+=("$type.csv")          # Store just the basename (e.g., pflows.csv)
  cd .. || exit 1
done

# Wait politely for all detached children to finish
wait

# Merge only the CSVs generated in this run
awk 'FNR==1 && NR!=1{next}1' "${csv_types[@]}" > invar.csv
