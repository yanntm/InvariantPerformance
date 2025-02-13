#!/bin/bash
# deploy.sh: Install tools and models, perform model conversion,
# and write config.sh that simply echoes the current environment variables.

set -e

ROOT=$(pwd)

# --- Install Tools ---

# Tina
mkdir -p tina
pushd tina > /dev/null
if [ ! -f "tina-3.8.5-amd64-linux.tgz" ]; then
    # we only need the struct binary, but in regular AND large versions:
    wget https://projects.laas.fr/tina/binaries/tina-3.8.5-large-amd64-linux.tgz
    wget https://projects.laas.fr/tina/binaries/tina-3.8.5-amd64-linux.tgz
    tar xvzf tina-3.8.5-large-amd64-linux.tgz tina-3.8.5/bin/struct
    mv tina-3.8.5/bin/struct tina-3.8.5/bin/struct_large
    tar xvzf tina-3.8.5-amd64-linux.tgz tina-3.8.5/bin/struct
fi
export STRUCT="$PWD/tina-3.8.5/bin/struct"
export STRUCTLARGE="$PWD/tina-3.8.5/bin/struct_large"
popd > /dev/null

if [ ! -x "bin/4ti2int64" ]; then 
  mkdir -p bin
  cd bin
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/4ti2int64
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/hilbert
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/zsolve
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/zbasis
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/qsolve  
  chmod a+x *
  cd ..
fi  
  
# GreatSPN
mkdir -p greatspn
pushd greatspn > /dev/null
if [ ! -f "DSPN-Tool" ]; then
    wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/DSPN-Tool
fi
if [ ! -f "GSOL" ]; then
    wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/GSOL
fi
chmod a+x DSPN-Tool GSOL
export DSPN="$PWD/DSPN-Tool"
export GSOL="$PWD/GSOL"
popd > /dev/null

# PetriSpot
mkdir -p petrispot
pushd petrispot > /dev/null
if [ ! -f "petri32" ]; then
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri32
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri64
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri128
    chmod a+x petri*
fi
export PETRISPOT32="$PWD/petri32"
export PETRISPOT64="$PWD/petri64"
export PETRISPOT128="$PWD/petri128"
popd > /dev/null

# itstools
mkdir -p itstools
pushd itstools > /dev/null
if [ ! -f "its-tools" ]; then
    wget --progress=dot:mega https://lip6.github.io/ITSTools/fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
    unzip fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
    rm fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
    # Run once to cache the OSGi configuration
    ./its-tools
fi
export ITSTOOLS="$PWD/its-tools"
popd > /dev/null

# Timeout utility
if [ ! -f "timeout.pl" ]; then
    wget https://raw.githubusercontent.com/yanntm/MCC-drivers/master/bin/timeout.pl
fi
chmod a+x timeout.pl
export TIMEOUT="$PWD/timeout.pl"


# Step 2: Download models and prepare them
# --- Install Models and Convert ---
if [ ! -d "INPUTS" ]; then
    wget --progress=dot:mega https://mcc.lip6.fr/2024/archives/INPUTS-2024.tar.gz
    tar xzf INPUTS-2024.tar.gz
fi
export MODELDIR="$ROOT/INPUTS"

pushd "$MODELDIR" > /dev/null
# Remove COL models
rm *-COL-*.tgz 2>/dev/null || true

# Process each TGZ file
for i in *.tgz; do
    model_dir="${i%.tgz}"
    if [ ! -d "$model_dir" ]; then
        tar xzf "$i"
        cd "$model_dir"
        # Clear useless formula files
		# rm Reachability*.xml LTL*.xml UpperBounds.xml CTL*.xml        
        # Remove unnecessary files
        rm -f *.xml *.txt
        # Convert PNML to GreatSPN format (.def/.net)
        set +e
        $GSOL -use-pnml-ids "$PWD/model.pnml" -export-greatspn "$PWD/model"
        status=$?
        set -e
        if [[ ! -f model.def ]]; then
            echo "Warning: Conversion failed in $PWD (status: $status)" >&2
            rm -f model.net model.def
        fi
        cd ..
    fi
done
popd > /dev/null

# --- Write Configuration File ---
# Only ROOT and MODELDIR are hard-coded; tool exports use the current values.
cat > config.sh <<EOF
#!/bin/bash
export ROOT="$ROOT"
export MODELDIR="$MODELDIR"
export STRUCT="$STRUCT"
export STRUCTLARGE="$STRUCTLARGE"
export DSPN="$DSPN"
export GSOL="$GSOL"
export PETRISPOT32="$PETRISPOT32"
export PETRISPOT64="$PETRISPOT64"
export PETRISPOT128="$PETRISPOT128"
export ITSTOOLS="$ITSTOOLS"
export TIMEOUT="$TIMEOUT"
EOF

chmod +x config.sh

echo "Deployment complete. Run 'run.sh' with a chosen mode."
