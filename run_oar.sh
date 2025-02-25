#!/bin/bash
# run_oar.sh: Submit one OAR job per mode/tool combination for the new modes.
#
# This script runs experiments using the following new modes:
#   PFLOWS, PSEMIFLOWS, TFLOWS, TSEMIFLOWS
#
# For each mode, it submits one job per tool. Allowed tool identifiers (passed via --tools) are:
#   tina       : Tina struct component (LAAS, CNRS)
#   tina4ti2   : Tina with 4ti2 integration (LAAS, CNRS)
#   itstools   : ITS-Tools (LIP6, Sorbonne Université)
#   petri32    : PetriSpot in 32-bit mode (LIP6, Sorbonne Université)
#   petri64    : PetriSpot in 64-bit mode (LIP6, Sorbonne Université)
#   petri128   : PetriSpot in 128-bit mode (LIP6, Sorbonne Université)
#   gspn       : GreatSPN (Università di Torino)
#
# Cluster constraints:
#   - Only run on nodes with hostnames matching "big25" or "big26"
#   - Use 4 cores on 1 node
#   - Limit walltime to 12 hours (12:00:00)
#
# The work folder is set to:
#   /home/ythierry/git/InvariantPerformance
# (This folder contains run.sh and config.sh; deploy.sh has been run ahead of time)

WORKDIR="/home/ythierry/git/InvariantPerformance"

# New modes to run
MODES=(PFLOWS PSEMIFLOWS TFLOWS TSEMIFLOWS)
#MODES=(PSEMIFLOWS)

# Allowed tool identifiers
#TOOLS=(tina tina4ti2 itstools petri32 petri64 petri128 gspn)
# TOOLS=(tina4ti2)
#TOOLS=(petri32 petri64 petri128)
#TOOLS=(tina tina4ti2 itstools petri64 gspn)
TOOLS=(petri64 itstools)

# OAR constraints: nodes "big25" or "big26", 4 cores, 12-hour walltime.
OAR_CONSTRAINTS='{(host like "big25") OR (host like "big26")}/nodes=1/core=4,walltime=12:00:00'

for MODE in "${MODES[@]}"; do
  for TOOL in "${TOOLS[@]}"; do
    echo "Submitting OAR job for Mode: $MODE, Tool: $TOOL"
    oarsub -l "$OAR_CONSTRAINTS" "uname -a; cd $WORKDIR && ./run.sh $MODE --tools=$TOOL --mem=ANY -solution; exit"
  done
done
