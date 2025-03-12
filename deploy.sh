#!/bin/bash
# deploy.sh: Install tools, models, Z3, set up virtualenv, perform model conversion,
# and write config.sh with environment variables.

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

# --- Install Z3 ---
mkdir -p z3
pushd z3 > /dev/null
if [ ! -f "bin/libz3.so" ]; then
    wget https://github.com/Z3Prover/z3/releases/download/z3-4.14.0/z3-4.14.0-x64-glibc-2.35.zip
    unzip z3-4.14.0-x64-glibc-2.35.zip
    mv z3-4.14.0-x64-glibc-2.35/* .
    rmdir z3-4.14.0-x64-glibc-2.35
    rm z3-4.14.0-x64-glibc-2.35.zip
fi
export Z3_DIR="$PWD"
export LD_LIBRARY_PATH="$Z3_DIR/bin:$LD_LIBRARY_PATH"
popd > /dev/null

# --- Setup Python Environment with Z3 Bindings ---
LIB_DIR="$ROOT/lib"
mkdir -p "$LIB_DIR"
if [ ! -d "$LIB_DIR/z3" ]; then
    # Get Python version (e.g., "Python 3.11.2" -> "python3.11")
    PYTHON_VERSION=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
    cp -r "$Z3_DIR/bin/python/z3" "$LIB_DIR/"
fi
export PYTHONPATH="$LIB_DIR:$PYTHONPATH"

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
        
        set +e
        # Step 1: Normalize PNML
        if [ ! -f "model.norm.pnml" ]; then
            $PETRISPOT64 -i "$PWD/model.pnml" --normalizePNML="$PWD/model.norm.pnml"
            status_norm=$?
            if [ $status_norm -ne 0 ]; then
                echo "Warning: Normalized PNML export failed in $PWD (status: $status_norm)" >&2
                rm -f model.norm.pnml
            fi
        fi
        
        # Step 2: Export matrix from normalized PNML
        if [ -f "model.norm.pnml" ] && [ ! -f "model.mtx" ]; then
            $PETRISPOT64 -i "$PWD/model.norm.pnml" --exportAsMatrix="$PWD/model.mtx"
            status_mtx=$?
            if [ $status_mtx -ne 0 ]; then
                echo "Warning: Matrix export failed in $PWD (status: $status_mtx)" >&2
                rm -f model.mtx
            fi
        fi
        
        # Step 3: Convert normalized PNML to GreatSPN format (.def/.net)
        if [ -f "model.norm.pnml" ] && [ ! -f "model.def" ]; then
            $GSOL -use-pnml-ids "$PWD/model.norm.pnml" -export-greatspn "$PWD/model"
            status_gsol=$?
            if [ $status_gsol -ne 0 ] || [ ! -f "model.def" ]; then
                echo "Warning: GreatSPN conversion failed in $PWD (status: $status_gsol)" >&2
                rm -f model.net model.def
            fi
        fi
        set -e
        
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
export Z3_DIR="$Z3_DIR"
export LD_LIBRARY_PATH="$Z3_DIR/bin:$LD_LIBRARY_PATH"
export PYTHONPATH="$LIB_DIR:$PYTHONPATH"
EOF

chmod +x config.sh

echo "Deployment complete. Run 'run.sh' with a chosen mode."