#! /bin/bash

# step 1 : download models
git clone --depth 1 --branch gh-pages https://github.com/yanntm/pnmcc-models-2023.git

export ROOT=$PWD

export MODELDIR=$PWD/pnmcc-models-2023/INPUTS/

pushd $MODELDIR

# remove COL models
rm *-COL-*.tgz
# unzip
for i in *.tgz ; do tar xzf $i ; done
# clear formula files
for i in */ ; do cd $i ; rm Reachability*.xml LTL*.xml UpperBounds.xml CTL*.xml ; cd .. ; done

popd

# step 2 : grab tools

# tina
mkdir tina

pushd tina

wget https://projects.laas.fr/tina/binaries/tina-3.8.0-amd64-linux.tgz
tar xvzf tina-3.8.0-amd64-linux.tgz

export STRUCT=$PWD/tina-3.8.0/bin/struct

popd

# GreatSPN
# we grab from MCC-drivers repo

mkdir greatspn
pushd greatspn


wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/DSPN-Tool
export DSPN=$PWD/DSPN-Tool
wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/GSOL
export GSOL=$PWD/GSOL

chmod a+x *

popd

# PetriSpot

mkdir petrispot
pushd petrispot

# NB : this is Soufiane's version, we should update to yanntm/ repo at some point
wget https://github.com/soufianeelm/PetriSpot/raw/Inv-Linux/petri
export PETRISPOT=$PWD/petri

chmod a+x $PETRISPOT

popd

# itstools

mkdir itstools
cd itstools

wget --progress=dot:mega https://lip6.github.io/ITSTools/fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
unzip fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
rm fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
# run once to cache the osgi configuration
./its-tools

export ITSTOOLS=$PWD/its-tools

cd ..

# utilities for timeout
wget https://raw.githubusercontent.com/yanntm/MCC-drivers/master/bin/timeout.pl

export TIMEOUT=$PWD/timeout.pl
chmod a+x $TIMEOUT

# step 3 : run .net .def transformations for GreatSPN

pushd $MODELDIR
for i in */ ; do 
	cd $i ;
	# flags from GreatSPN driver, for PT case
	$GSOL -use-pnml-ids $PWD/model.pnml -export-greatspn $PWD/model
	if [[ ! -f model.def ]] ; then
		echo "Cannot convert PNML file into net/def format : $PWD"
		rm -f model.net model.def
	fi
	cd ..
done

popd

# Step 4 run and collect logs

# limit memory to 16GB and time to 120 seconds
export LIMITS="$TIMEOUT 120 time systemd-run --scope -p MemoryMax=16G --user"

cd $ROOT
mkdir -p logs
export LOGS=$PWD/logs

for i in $MODELDIR/Air*0?0/ ; do 
	cd $i
	model=$(echo $i | sed 's#/$##g' |  awk -F/ '{print $NF}') ;  
	echo "Treating $model" ;  

	# tina with 4ti2
	$LIMITS $STRUCT -4ti2 -F -q $i/model.pnml > $LOGS/$model.struct 2>&1 ;
	# tina by itself 
	$LIMITS $STRUCT -F -q $i/model.pnml > $LOGS/$model.tina 2>&1 ;

	# itstools
	$LIMITS $ITSTOOLS -pnfolder $i --Pflows --Tflows  > $LOGS/$model.its 2>&1 ;

	# petrispot
	$LIMITS $PETRISPOT -i $i/model.pnml -q --Pflows --Tflows  > $LOGS/$model.petri 2>&1

	# greatspn
	$LIMITS $DSPN -load model -pbasis -tbasis > $LOGS/$model.gspn 2>&1
done

cd $ROOT


