#!/bin/bash

# slices invar in <thres>.csv fail.csv files


# with Its:
tools="GreatSPN ItsTools PetriSpot32 PetriSpot64 PetriSpot128 tina tina4ti2"
# without:
tools="GreatSPN PetriSpot32 PetriSpot64 PetriSpot128 tina tina4ti2"

thresholds='100 200 500 1000 2000 5000 10000 20000 50000 max'



function dispatch {
    rm -f fail.csv
    for thres in $thresholds
    do rm -f $thres.csv
    done
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
		    # classify models in .mod files
		    # could classify directly in csv 
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



function results {
    if [ ! -z "$1" ] && [ "$1" == C ]
    then mode=C
    else mode=S
    fi
    if [ "$mode" == S ]
    then

	# "per slices" version    
	echo
	echo
	prev=0
	for slice in 100 200 500 1000 2000 5000 10000 20000 50000 max
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

    else

	# cumulative version using associative arrays
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

	for slice in 100 200 500 1000 2000 5000 10000 20000 50000 max
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
    fi
}



function summary {
    echo
    echo
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



export PERL_BADLANG=0

if [ ! -f invar.csv ]
then echo creating invar.csv
     ../logs2csv.pl > invar.csv 
fi

# sliced reports:

# create *.csv slices
echo dispatching invar.csv
dispatch ../pnmcc-models-2023/INPUTS/
echo csv slices created

# create md reports
results S > report-s.md
echo report-s.md created
results C > report-c.md
echo report-c.md created
summary >> summary.md
echo summary.md created

# cleaning
echo cleaning
rm *0.csv max.csv
echo done









    
















