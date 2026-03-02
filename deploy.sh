#!/bin/bash
# deploy.sh: Install tools, models, Z3, set up virtualenv, perform model conversion,
# and write config.sh with environment variables. Now includes SageMath and PetriSage setup.

set -e
set -x

# Versions (edit these three values only)
TINA_VERSION="3.9.0"
Z3_VERSION="4.16.0"
Z3_GLIBC="2.39"

ROOT=$(pwd)
TOOLS_DIR="$ROOT/tools"

mkdir -p "$TOOLS_DIR"

# --- Install Tools ---

# Tina
mkdir -p "$TOOLS_DIR/tina"
pushd "$TOOLS_DIR/tina"
TINA_BASE="tina-$TINA_VERSION"
TINA_LARGE_TGZ="$TINA_BASE-large-amd64-linux.tgz"
TINA_STD_TGZ="$TINA_BASE-amd64-linux.tgz"
if [ ! -f "$TINA_STD_TGZ" ]; then
    # we only need the struct binary, but in regular AND large versions:
    wget "https://projects.laas.fr/tina/binaries/$TINA_LARGE_TGZ"
    wget "https://projects.laas.fr/tina/binaries/$TINA_STD_TGZ"
    tar xvzf "$TINA_LARGE_TGZ" "$TINA_BASE/bin/struct"
    mv "$TINA_BASE/bin/struct" "$TINA_BASE/bin/struct_large"
    tar xvzf "$TINA_STD_TGZ" "$TINA_BASE/bin/struct"
fi
export STRUCT="$PWD/$TINA_BASE/bin/struct"
export STRUCTLARGE="$PWD/$TINA_BASE/bin/struct_large"
popd

# 4ti2
mkdir -p "$TOOLS_DIR/bin"
pushd "$TOOLS_DIR/bin"
if [ ! -x "4ti2int64" ]; then
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/4ti2int64
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/hilbert
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/zsolve
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/zbasis
  wget https://github.com/yanntm/SMPT-BinaryBuilds/raw/refs/heads/linux/qsolve
  chmod a+x *
fi
popd

# GreatSPN
mkdir -p "$TOOLS_DIR/greatspn"
pushd "$TOOLS_DIR/greatspn"
if [ ! -f "DSPN-Tool" ]; then
    wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/DSPN-Tool
fi
if [ ! -f "GSOL" ]; then
    wget https://github.com/yanntm/MCC-drivers/raw/master/greatspn/greatspn/lib/app/portable_greatspn/bin/GSOL
fi
chmod a+x DSPN-Tool GSOL
export DSPN="$PWD/DSPN-Tool"
export GSOL="$PWD/GSOL"
popd

# PetriSpot
mkdir -p "$TOOLS_DIR/petrispot"
pushd "$TOOLS_DIR/petrispot"
if [ ! -f "petri32" ]; then
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri32
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri64
    wget https://github.com/yanntm/PetriSpot/raw/Inv-Linux/petri128
    chmod a+x petri*
fi
export PETRISPOT32="$PWD/petri32"
export PETRISPOT64="$PWD/petri64"
export PETRISPOT128="$PWD/petri128"
popd

# itstools
mkdir -p "$TOOLS_DIR/itstools"
pushd "$TOOLS_DIR/itstools"
if [ ! -f "its-tools" ]; then
    wget --progress=dot:mega https://lip6.github.io/ITSTools/fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
    unzip fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
    rm fr.lip6.move.gal.itscl.product-linux.gtk.x86_64.zip
    # Run once to cache the OSGi configuration
    ./its-tools
fi
export ITSTOOLS="$PWD/its-tools"
popd

# Timeout utility
pushd "$TOOLS_DIR"
if [ ! -f "timeout.pl" ]; then
    wget https://raw.githubusercontent.com/yanntm/MCC-drivers/master/bin/timeout.pl
fi
chmod a+x timeout.pl
export TIMEOUT="$PWD/timeout.pl"
popd

# --- Install Z3 ---
mkdir -p "$TOOLS_DIR/z3"
pushd "$TOOLS_DIR/z3"
Z3_TAG="z3-$Z3_VERSION"
Z3_ZIP="$Z3_TAG-x64-glibc-$Z3_GLIBC.zip"
if [ ! -f "bin/libz3.so" ]; then
    wget "https://github.com/Z3Prover/z3/releases/download/$Z3_TAG/$Z3_ZIP"
    unzip "$Z3_ZIP"
    mv "$Z3_TAG-x64-glibc-$Z3_GLIBC"/* .
    rmdir "$Z3_TAG-x64-glibc-$Z3_GLIBC"
    rm "$Z3_ZIP"
fi
export Z3_DIR="$PWD"
export LD_LIBRARY_PATH="$Z3_DIR/bin:$LD_LIBRARY_PATH"
popd

# --- Setup Python Environment with Z3 Bindings ---
LIB_DIR="$TOOLS_DIR/lib"
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
  if [ ! -f "INPUTS-2025.tar.gz" ]; then
    wget --progress=dot:mega https://mcc.lip6.fr/2025/archives/INPUTS-2025.tar.gz
  fi
  mkdir -p INPUTS
	tar xzf INPUTS-2025.tar.gz -C INPUTS --strip-components=1 --no-xattrs --warning=no-unknown-keyword
fi
export MODELDIR="$ROOT/INPUTS"

pushd "$MODELDIR"
# Remove COL models
rm *-COL-*.tgz 2>/dev/null || true

# Process each TGZ file
for i in *.tgz; do
    model_dir="${i%.tgz}"
    if [ ! -d "$model_dir" ]; then
        tar xzf "$i" --no-xattrs --warning=no-unknown-keyword
        cd "$model_dir"
        # Clear useless formula files
        # rm Reachability*.xml LTL*.xml UpperBounds.xml CTL*.xml
        # Remove unnecessary files
        rm -f *.xml *.txt

        set +e
        # Step 1: Normalize PNML
        if [ ! -f "model.norm.pnml" ]; then
            "$PETRISPOT64" -i "$PWD/model.pnml" --normalizePNML="$PWD/model.norm.pnml"
            status_norm=$?
            if [ $status_norm -ne 0 ]; then
                echo "Warning: Normalized PNML export failed in $PWD (status: $status_norm)" >&2
                rm -f model.norm.pnml
            fi
        fi

        # Step 2: Export matrix from normalized PNML
        if [ -f "model.norm.pnml" ] && [ ! -f "model.mtx" ]; then
            "$PETRISPOT64" -i "$PWD/model.norm.pnml" --exportAsMatrix="$PWD/model.mtx"
            status_mtx=$?
            if [ $status_mtx -ne 0 ]; then
                echo "Warning: Matrix export failed in $PWD (status: $status_mtx)" >&2
                rm -f model.mtx
            fi
        fi

        # Step 3: Convert normalized PNML to GreatSPN format (.def/.net)
        if [ -f "model.norm.pnml" ] && [ ! -f "model.def" ]; then
            "$GSOL" -use-pnml-ids "$PWD/model.norm.pnml" -export-greatspn "$PWD/model"
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
popd

# --- Install Micromamba and Sage Environment ---
mkdir -p "$TOOLS_DIR/bin"
pushd "$TOOLS_DIR/bin"
if [ ! -f "micromamba" ]; then
    wget -qO- https://micromamba.snakepit.net/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
    mv bin/micromamba .
    rmdir bin
    chmod +x micromamba
fi
export MICROMAMBA="$PWD/micromamba"
popd

# Set up micromamba root prefix under $TOOLS_DIR
mkdir -p "$TOOLS_DIR/micromamba"
if [ ! -d "$TOOLS_DIR/micromamba/envs/sage" ]; then
    "$MICROMAMBA" create -r "$TOOLS_DIR/micromamba" -n sage -c conda-forge sage -y
fi
export SAGE_ENV="$TOOLS_DIR/micromamba/envs/sage"

# --- Install PetriSage ---
mkdir -p "$TOOLS_DIR/petrisage"
pushd "$TOOLS_DIR/petrisage"
if [ ! -f "petrisage.py" ]; then
    wget https://github.com/yanntm/PetriSpot/raw/refs/heads/master/PetriSage/petrisage.py
    chmod +x petrisage.py
fi
export PETRISAGE="$PWD/petrisage.py"
popd

# --- Write Configuration File ---
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
export MICROMAMBA="$MICROMAMBA"
export SAGE_ENV="$SAGE_ENV"
export PETRISAGE="$PETRISAGE"
export PATH="$TOOLS_DIR/bin:$PATH"
EOF

chmod +x config.sh

echo "Deployment complete. Source 'config.sh' and use '\$MICROMAMBA activate \$SAGE_ENV' to enable Sage."
