#!/bin/bash

# usage (from logs dir):   ../reports.sh
# only requires invar.csv, builds it if absent
# partitions invar.csv into <thres>.csv fail.csv files
# beware: removes all csv file except invar.csv, at start and on completion

# all known:
tools="GreatSPN ItsTools PetriSpot32 PetriSpot64 PetriSpot128 tina tina4ti2"
# adjust at your wish:
tools="GreatSPN PetriSpot32 PetriSpot64 PetriSpot128 tina tina4ti2"

# adjust at your wish (last threshold must be "max")
thresholds='100 200 500 1000 2000 5000 10000 20000 50000 max'


function dispatch {
    for f in `ls $1`
    do
	model=$1/$f/model.pnml
	name=$f
	# echo $name
	echo -n .
	case "$name" in
	    *-PT-*)
 		# loop on block until p>0 found for name ...
		# Q: can we avoid file block ?
		grep $name invar.csv > block
		p=-1
		while read -r line; do
		    p=`echo $line | cut -d"," -f 3`
		    t=`echo $line | cut -d"," -f 4`
		    if (( "$p" > 0 ))
		    then break
		    else continue
		    fi
		done < block
		rm block
		if (( "$p" < 0 ))
		then grep $name invar.csv >> fail.csv
		else
		    # z is max of p,t
		    if (( "$p" <= "$t" ))
		    then z=$t
		    else z=$p
		    fi
		    prev=0
		    for thres in $thresholds
		    do  
			if (( "$thres" == "max" ))
			then grep $name invar.csv >> max.csv
			else if (( "$z" > "$prev" )) && (( "$z" <= "$thres" ))
			     then grep $name invar.csv >> $thres.csv
				  prev=$thres
				  break
			     fi
			fi
		    done
		fi
		;;
	    *);;
	esac
    done
    echo 
}

function perslices {
    # "per slices" version    
    echo
    echo
    prev=0
    for slice in $thresholds
    do
	echo
	echo "slice = ]$prev,$slice]"
	prev=$slice
	echo
	echo "| Tool | Failure | time | ovf | mem | unk | Success | Total |"
	echo "|---|---|---|---|---|---|---|---|"
	for tool in $tools
	do
	    tot=`grep "$tool," $slice.csv | wc -l`
	    succ=`grep "$tool," $slice.csv | grep 'OK$' | wc -l`
	    time=`grep "$tool," $slice.csv | grep TO | wc -l`
	    ovf=`grep "$tool," $slice.csv | grep OF | wc -l`
	    mem=`grep "$tool," $slice.csv | grep MO | grep -v OF | wc -l`
	    unk=`grep "$tool," $slice.csv | grep 'UNK$' | wc -l`
	    fail=$(( tot - succ ))
	    echo "| $tool | $fail | $time | $ovf | $mem | $unk | $succ | $tot |"
	done
    done
}

function cumulated {
    # cumulative version using associative arrays
    # declare/initialize arrays:
    declare -A prevfail
    declare -A prevsucc
    declare -A prevtime
    declare -A prevovf
    declare -A prevmem
    declare -A prevunk
    declare -A prevtot
    for tool in $tools
    do
	prevfail[$tool]=0
	prevsucc[$tool]=0
	prevtime[$tool]=0
        prevovf[$tool]=0
        prevmem[$tool]=0
        prevunk[$tool]=0
	prevtot[$tool]=0
    done
    
    # print results for each slice:
    for slice in $thresholds
    do echo
       echo "slice = ]0,$slice] "
       echo
       echo "| Tool | Failure | time | ovf | mem | unk | Success | Total |"
       echo "|---|---|---|---|---|---|---|---|"
       for tool in $tools
       do
	   prevtot=${prevtot[$tool]}
	   prevsucc=${prevsucc[$tool]}
	   prevtime=${prevtime[$tool]}
	   prevovf=${prevovf[$tool]}
	   prevmem=${prevmem[$tool]}
	   prevunk=${prevunk[$tool]}
	   prevfail=${prevfail[$tool]}

	   tot=`grep "$tool," $slice.csv | wc -l`
	   tot=$(( tot + prevtot ))
	   succ=`grep "$tool," $slice.csv | grep 'OK$' | wc -l`
	   succ=$(( succ + prevsucc ))

	   time=`grep "$tool," $slice.csv | grep TO | wc -l`
	   time=$(( time + prevtime ))
	   ovf=`grep "$tool," $slice.csv | grep OF | wc -l`
	   ovf=$(( ovf + prevovf ))
	   mem=`grep "$tool," $slice.csv | grep MO | grep -v OF | wc -l`
	   mem=$(( mem + prevmem ))
	   unk=`grep "$tool," $slice.csv | grep 'UNK$' | wc -l`
	   unk=$(( unk + prevunk ))
	   fail=$(( tot - succ ))
	   echo "| $tool | $fail | $time | $ovf | $mem | $unk | $succ | $tot |"

	   prevfail[$tool]=$fail
	   prevsucc[$tool]=$succ
	   prevtime[$tool]=$time
	   prevovf[$tool]=$ovf
	   prevmem[$tool]=$mem
	   prevunk[$tool]=$unk
	   prevtot[$tool]=$tot
       done
    done
}

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

function preclean {
    # removes all md and csv files except invar.csv
    rm -f `ls *.md *.csv 2> /dev/null | grep -v invar`
}

function postclean {
    # removes all csv files except invar.csv
    rm -f `ls *.csv 2> /dev/null | grep -v invar`
}


function main {
    # avoids missing locales messages by perl
    export PERL_BADLANG=0

    # clean in case some csv files 
    preclean

    # build invar.csv if absent
    if [ ! -f invar.csv ]
    then 
	echo creating invar.csv
	../logs2csv.pl > invar.csv
    fi

    # summary of results
    summary >> summary.md
    echo summary.md created

    # sliced reports:

    # create *.csv slices
    echo dispatching invar.csv
    dispatch ../pnmcc-models-2023/INPUTS/
    echo csv slices created

    # create md reports
    perslices > report-s.md
    echo report-s.md created
    cumulated > report-c.md
    echo report-c.md created

    # cleaning
    echo cleaning
    postclean
    echo done
}

main

