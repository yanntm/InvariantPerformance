#!/bin/bash

# prints summary of results in md format, from invar.csv
# usage (from logs dir): ../summary.sh [> dummary.md]

tools="GreatSPN ItsTools PetriSpot32 PetriSpot64 PetriSpot128 tina tina4ti2"
tools="GreatSPN PetriSpot32 PetriSpot64 PetriSpot128 tina tina4ti2"

function summary {
    echo summary
    echo
    echo "| Tool | Failure | time | ovf | mem | unk | Success | Total |"
    echo "|---|---|---|---|---|---|---|---|"
    for tool in $tools
    do
	tot=`grep "$tool," invar.csv | wc -l`
	succ=`grep "$tool," invar.csv | grep 'OK$' | wc -l`
	time=`grep "$tool," invar.csv | grep TO | wc -l`
	ovf=`grep "$tool," invar.csv | grep OF | wc -l`
	mem=`grep "$tool," invar.csv | grep MO | grep -v OF | wc -l`
	unk=`grep "$tool," invar.csv | grep 'UNK$' | wc -l`
	fail=$(( tot - succ ))
	echo "| $tool | $fail | $time | $ovf | $mem | $unk | $succ | $tot |"
    done
}

function main {
    # summary of results
    summary
}

main

