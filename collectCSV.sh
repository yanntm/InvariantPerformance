#!/bin/bash

# Array to track CSV basenames generated in this run
csv_types=()

# Process logs_* directories
for i in logs_*; do
  cd "$i" || exit 1
  type=$(echo "$i" | sed 's/logs_//')
  ../logs2csv2.pl > "../$type.csv"  # Writes to ../$type.csv
  csv_types+=("$type.csv")          # Store just the basename (e.g., pflows.csv)
  cd .. || exit 1
done

# Merge only the CSVs generated in this run
awk 'FNR==1 && NR!=1{next}1' "${csv_types[@]}" > invar.csv
