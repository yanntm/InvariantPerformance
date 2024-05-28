#!/bin/bash

# Step 1: Grab tools and the timeout utility

# Tina
mkdir -p tina
pushd tina
if [ ! -f "tina-3.8.0-amd64-linux.tgz" ]; then
  wget https://projects.laas.fr/tina/binaries/tina-3.8.0-amd64-linux.tgz
  tar xvzf tina-3.8.0-amd64-linux.tgz
fi
export STRUCT=$PWD/tina-3.8.0/bin/struct
popd

# GreatSPN
mkdir -p greatspn
pushd greatspn
if [ ! -f "DSPN-Tool" ]; then
  wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/DSPN-Tool
fi
if [ ! -f "GSOL" ]; then
  wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/GSOL
fi
export DSPN=$PWD/DSPN-Tool
export GSOL=$PWD/GSOL
chmod a+x *
popd

# PetriSpot
mkdir -p petrispot
pushd petrispot
if [ ! -f "petri" ]; then
  wget https://github.com/soufianeelm/PetriSpot/raw/Inv-Linux/petri
  chmod a+x petri
fi
export PETRISPOT=$PWD/petri
popd

# itstools
mkdir -p itstools
pushd itstools
if [ ! -f "its-tools" ]; then
  wget --progress=dot:mega https://lip6.github.io/ITSTools/fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
  unzip fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
  rm fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
  # Run once to cache the OSGi configuration
  ./its-tools
fi
export ITSTOOLS=$PWD/its-tools
popd

# Utilities for timeout
if [ ! -f "timeout.pl" ]; then
  wget https://raw.githubusercontent.com/yanntm/MCC-drivers/master/bin/timeout.pl
fi
export TIMEOUT=$PWD/timeout.pl
chmod a+x $TIMEOUT

# Step 2: Download models and prepare them

if [ ! -d "pnmcc-models-2023" ]; then
  git clone --depth 1 --branch gh-pages https://github.com/yanntm/pnmcc-models-2023.git
fi

export ROOT=$PWD
export MODELDIR=$PWD/pnmcc-models-2023/INPUTS/

pushd $MODELDIR

# Remove COL models
rm *-COL-*.tgz

# Process each TGZ file
for i in *.tgz; do
  model_dir="${i%.tgz}"
  if [ ! -d "$model_dir" ]; then
    # Unzip
    tar xzf $i
    cd $model_dir
    # Clear useless formula files
    rm Reachability*.xml LTL*.xml UpperBounds.xml CTL*.xml
    # Convert to GSPN
    $GSOL -use-pnml-ids $PWD/model.pnml -export-greatspn $PWD/model
    if [[ ! -f model.def ]]; then
      echo "Cannot convert PNML file into net/def format: $PWD"
      rm -f model.net model.def
    fi
    cd ..
  fi
done

popd

# Step 3: Run the tools

export LIMITS="$TIMEOUT 120 time systemd-run --scope -p MemoryMax=16G --user"
cd $ROOT
mkdir -p logs
export LOGS=$PWD/logs

for i in $MODELDIR/*/ ; do 
  cd $i
  model=$(echo $i | sed 's#/$##g' | awk -F/ '{print $NF}')
  echo "Treating $model"

  # Tina with 4ti2
  if [ ! -f "$LOGS/$model.struct" ]; then
    $LIMITS $STRUCT -4ti2 -F -q $i/model.pnml > $LOGS/$model.struct 2>&1
  fi

  # Tina by itself
  if [ ! -f "$LOGS/$model.tina" ]; then
    $LIMITS $STRUCT -F -q $i/model.pnml > $LOGS/$model.tina 2>&1
  fi

  # itstools
  if [ ! -f "$LOGS/$model.its" ]; then
    $LIMITS $ITSTOOLS -pnfolder $i --Pflows --Tflows > $LOGS/$model.its 2>&1
  fi

  # PetriSpot
  if [ ! -f "$LOGS/$model.petri" ]; then
    $LIMITS $PETRISPOT -i $i/model.pnml -q --Pflows --Tflows > $LOGS/$model.petri 2>&1
  fi

  # GreatSPN
  if [ ! -f "$LOGS/$model.gspn" ]; then
    $LIMITS $DSPN -load model -pbasis -tbasis > $LOGS/$model.gspn 2>&1
  fi
done

cd $ROOT
