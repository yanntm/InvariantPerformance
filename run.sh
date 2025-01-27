#!/bin/bash

# Step 1: Grab tools and the timeout utility

# Tina
mkdir -p tina
pushd tina
if [ ! -f "tina-3.8.5-amd64-linux.tgz" ]; then
    # we only need the struct binary, but in regular AND large versions:
    # 4ti2 assumed installed
    wget https://projects.laas.fr/tina/binaries/tina-3.8.5-large-amd64-linux.tgz
    wget https://projects.laas.fr/tina/binaries/tina-3.8.5-amd64-linux.tgz
    tar xvzf tina-3.8.5-large-amd64-linux.tgz tina-3.8.5/bin/struct
    mv tina-3.8.5/bin/struct tina-3.8.5/bin/struct_large
    tar xvzf tina-3.8.5-amd64-linux.tgz tina-3.8.5/bin/struct
fi
export STRUCT=$PWD/tina-3.8.5/bin/struct
export STRUCTLARGE=$PWD/tina-3.8.5/bin/struct_large
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
if [ ! -f "petri32" ]; then
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri32
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri64
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri128
    chmod a+x petri*
fi
export PETRISPOT32=$PWD/petri32
export PETRISPOT64=$PWD/petri64
export PETRISPOT128=$PWD/petri128
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

if [ ! -d "INPUTS/" ]; then
    wget --progress=dot:mega https://mcc.lip6.fr/2024/archives/INPUTS-2024.tar.gz
    tar xzf INPUTS-2024.tar.gz
fi

export ROOT=$PWD
export MODELDIR=$PWD/INPUTS/

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
	# rm Reachability*.xml LTL*.xml UpperBounds.xml CTL*.xml
	rm *.xml *.txt
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
# Check argument count
if [ $# -ne 1 ]; then
  echo "Usage: $0 [FLOWS|SEMIFLOWS]"
  exit 1
fi

MODE=$1

if [ "$MODE" = "FLOWS" ]; then
    TINA_FLAG="-F"
    ITS_FLAG="--Pflows --Tflows"
    PETRISPOT_FLAG="--Pflows --Tflows"
    GSPN_FLAG="-pbasis -tbasis"
    LOGDIR="logs"
elif [ "$MODE" = "SEMIFLOWS" ]; then
    TINA_FLAG="-S"
    ITS_FLAG="--Psemiflows --Tsemiflows"
    PETRISPOT_FLAG="--Psemiflows --Tsemiflows"
    GSPN_FLAG="-pinv -tinv"
    LOGDIR="semilogs"
else
    echo "Usage: $0 [FLOWS|SEMIFLOWS]"
    exit 1
fi

export LIMITS="$TIMEOUT 120 time systemd-run --scope -p MemoryMax=16G --user"
cd "$ROOT"
mkdir -p "$LOGDIR"
export LOGS="$PWD/$LOGDIR"

for i in "$MODELDIR"/*/; do
    cd "$i" || exit
    model=$(echo "$i" | sed 's#/$##' | awk -F/ '{print $NF}')
    echo "Treating $model"

    # Tina by itself
    if [ ! -f "$LOGS/$model.tina" ]; then
        if [ -f large_marking ]; then
            $LIMITS "$STRUCTLARGE" @MLton fixed-heap 15G -- $TINA_FLAG -mp -q "$i/model.pnml" \
                > "$LOGS/$model.tina" 2>&1
        else
            $LIMITS "$STRUCT" @MLton fixed-heap 15G -- $TINA_FLAG -mp -q "$i/model.pnml" \
                > "$LOGS/$model.tina" 2>&1
        fi
    fi

    # Tina with 4ti2
    if [ ! -f "$LOGS/$model.struct" ]; then
        rm -f /tmp/f-* > /dev/null 2>&1
        if [ -f large_marking ]; then
            $LIMITS "$STRUCTLARGE" @MLton max-heap 8G -- -4ti2 $TINA_FLAG -I -q "$i/model.pnml" \
                > "$LOGS/$model.struct" 2>&1
        else
            $LIMITS "$STRUCT" @MLton max-heap 8G -- -4ti2 $TINA_FLAG -I -q "$i/model.pnml" \
                > "$LOGS/$model.struct" 2>&1
        fi
        rm -f /tmp/f-* > /dev/null 2>&1
        sync
    fi

    # itstools
    if [ ! -f "$LOGS/$model.its" ]; then
        $LIMITS "$ITSTOOLS" -pnfolder "$i" $ITS_FLAG \
            > "$LOGS/$model.its" 2>&1
    fi

    # PetriSpot 32-bit
    if [ ! -f "$LOGS/$model.petri32" ]; then
        $LIMITS "$PETRISPOT32" -i "$i/model.pnml" -q $PETRISPOT_FLAG \
            > "$LOGS/$model.petri32" 2>&1
    fi

    # PetriSpot 64-bit
    if [ ! -f "$LOGS/$model.petri64" ]; then
        $LIMITS "$PETRISPOT64" -i "$i/model.pnml" -q $PETRISPOT_FLAG \
            > "$LOGS/$model.petri64" 2>&1
    fi

    # PetriSpot 128-bit
    if [ ! -f "$LOGS/$model.petri128" ]; then
        $LIMITS "$PETRISPOT128" -i "$i/model.pnml" -q $PETRISPOT_FLAG \
            > "$LOGS/$model.petri128" 2>&1
    fi

    # GreatSPN
    if [ ! -f "$LOGS/$model.gspn" ]; then
        $LIMITS "$DSPN" -load model $GSPN_FLAG \
            > "$LOGS/$model.gspn" 2>&1
    fi
done

cd "$ROOT"