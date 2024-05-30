# InvariantPerformance

This repository provides a comprehensive comparison of tools for computing Petri net invariants on a large benchmark set from the [Model-Checking Contest (MCC)](https://mcc.lip6.fr). 
It includes scripts to run the tools, collect logs, transform logs to CSV format, and generate plots and analyses using Python or R.

Currently, the repository compares the following tools:
* [ITS-Tools](https://github.com/lip6/ITSTools)
* [Tina](https://projects.laas.fr/tina/index.php)
* [PetriSpot](https://github.com/yanntm/PetriSpot)
* [GreatSPN](https://github.com/greatspn/SOURCES)

This repository was originally built as a companion to the paper ["Efficient Strategies to Compute Invariants, Bounds and Stable Places of Petri nets", Yann Thierry-Mieg, PNSE'23](https://hal.science/hal-04142675); the data and scripts used to build the analysis and plots in that paper are still visible [here](https://github.com/yanntm/InvariantPerformance/tree/PNSE23) or as a release (side panel). 
Slides of the presentation are also available here https://github.com/yanntm/InvariantPerformance/blob/master/PNSE23_vfinal.pdf

The current repository is easier to use, compares more tools, and uses MCC 2023 models.

## How to Reproduce

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/yanntm/InvariantPerformance.git
   cd InvariantPerformance
   ```

2. **Run the Experiment:**
   Execute the `run.sh` script to automate the entire process:
   ```bash
   ./run.sh
   ```
   This script performs the following tasks:
   * Downloads the necessary tools (versions are specified in the script; logs correspond to Tina 3.8.0, GreatSPN MCC 2022 release, ITS-Tools 202405141337, PetriSpot at this revision https://github.com/yanntm/PetriSpot/commit/7b8898f36256cad5382452f03952d08db6605a42).
   * Downloads and prepares models from [pnmcc-models-2023](https://github.com/yanntm/pnmcc-models-2023), and builds GreatSPN format files from PNML. We also clear COL models since they are not uniformly supported by tools.
   * Runs each tool on each model, configured to compute a generative basis of P flows and T flows (precise invocation flags in `run.sh` script). 
   We limit memory to 16GB and time to 120 seconds wall clock time (none of the tools are concurrent). 

3. **Log Generation:**
   Logs for each tool are produced in the `logs/` directory, with file extensions specific to each tool (e.g., `.its`, `.tina`, `.petri32`,...).

The full logs of our run are available in `rawlogs.tgz`, 
Before zipping them into `rawlogs.tgz` of this repository, we first remove the actual invariants from the output as the archived logs are otherwise over 250MB.
We ran the following sed line :`sed -i '/inv :.*/d' *.its`.
The flag `-q` we use for Tina means "quiet" and avoids printing the actual invariants, but ITS-Tools does not have such a flag. PetriSpot does have a `-q`, GreatSPN outputs the invariants in files placed next to the model itself.

4. **Convert Logs to CSV:**
   Use the `logs2csv.pl` script to consolidate log data into a CSV file:
   ```bash
   cd logs
   ../logs2csv.pl > invar.csv
   ```
   The resulting `invar.csv` file includes the following columns:
   * **Model**: The name of the model
   * **Tool**: The tool used (`its`, `tina4ti2`, or `tina`)
   * **CardP**: The number of places in the net
   * **CardT**: The number of transitions in the net
   * **CardA**: The number of arcs in the net
   * **PTime**: The time to compute P flows in ms
   * **TTime**: The time to compute T flows in ms
   * **ConstP**: The number of constant places reported by ITS-Tools (always 0 in Tina runs)
   * **NBP**: The number of P flows reported
   * **NBT**: The number of T flows reported
   * **TotalTime**: Total runtime in ms as reported by ITS-Tools at end of run (0 for Tina)
   * **Time**: Total elapsed time as reported by the `time` command, converted to milliseconds (or 120 seconds if an error occurred)
   * **Mem**: Memory usage in KB as reported by the `maxresident` field in `time`
   * **Status**: Status of the run (`OK`, `TO`, `MOVF`, `ERR`, `_OF`)

The file `invar.csv` obtained from our logs is part of this repo. It includes traces from `PetriSpot` without a size indicator;
 this is a version of the tool prior to introduction of template parameters to set the size of integer used, so should be comparable to
 PetriSpot32 version for all useful purpose.

5. **Generate Reports:**
   To build comparison plots, tables, and graphs, use the `makeReport.py` and `multiCompare.R` scripts:
   ```bash
   python makeReport.py
   Rscript multiCompare.R
   ```



## Acknowledgements

This repository is available under the GPL license.

Created by Yann Thierry-Mieg, LIP6, Sorbonne Université, CNRS.

Contributions (PetriSpot integration) by Soufiane El Mouahid (Master student @ Sorbonne, 2024).

