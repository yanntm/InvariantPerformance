# InvariantPerformance

This repository provides a comprehensive comparison of tools for computing Petri net invariants on a large benchmark set from the [Model-Checking Contest (MCC)](https://mcc.lip6.fr). It includes scripts to run the tools, collect logs, transform logs to CSV format, and generate plots and analyses using Python or R.

Currently, the repository compares the following tools:
* [ITS-Tools](https://github.com/lip6/ITSTools)
* [Tina](https://projects.laas.fr/tina/index.php)
* [PetriSpot](https://github.com/yanntm/PetriSpot)
* [GreatSPN](https://github.com/greatspn/SOURCES)

This repository was originally built as a companion to the paper ["Efficient Strategies to Compute Invariants, Bounds and Stable Places of Petri nets" by Yann Thierry-Mieg, PNSE'23](https://hal.science/hal-04142675); the data and scripts used to build the analysis and plots in that paper are still visible [here](https://github.com/yanntm/InvariantPerformance/tree/PNSE23) or as a release (side panel). Slides of the presentation are also available [here](https://github.com/yanntm/InvariantPerformance/blob/master/docs/PNSE23_vfinal.pdf).

The current repository is easier to use, compares more tools, and uses MCC 2023 models.

## How to Reproduce

0. **Clone the Repository:**
   ```bash
   git clone https://github.com/yanntm/InvariantPerformance.git
   cd InvariantPerformance
   ```

1. **Deploy tools and models:**
  This step will download the tools, the models, and translate PNML models to GreatSPN format, preparing the experiments.
  It builds a `config.sh` script that contains the configuration used by `run.sh`.
   ```bash
   ./deploy.sh
   ```

2. **Run the Experiment:**

   Execute the `run.sh` script to automate the entire process. The script now accepts an optional `--tools` parameter to select a subset of tools. For example:
   ```bash
   ./run.sh PSEMIFLOWS --tools=tina4ti2,petri64
   ```
   If the `--tools` parameter is omitted, all tools are executed.

   **Arguments:**
   - **MODE**: Must be one of:
     - `FLOWS`
     - `SEMIFLOWS`
     - `TFLOWS`
     - `PFLOWS`
     - `TSEMIFLOWS`
     - `PSEMIFLOWS`
     
   - **--tools** (optional): A comma-separated list specifying which tools to run. Valid tool names and their meanings:
     - `tina`: Tina struct component (LAAS, CNRS)
     - `tina4ti2`: Tina with 4ti2 integration (LAAS, CNRS)
     - `itstools`: ITS-Tools (LIP6, Sorbonne Université)
     - `petri32`: PetriSpot in 32-bit mode (LIP6, Sorbonne Université)
     - `petri64`: PetriSpot in 64-bit mode (LIP6, Sorbonne Université)
     - `petri128`: PetriSpot in 128-bit mode (LIP6, Sorbonne Université)
     - `gspn`: GreatSPN (Università di Torino)

   If run without any arguments or with `-h/--help`, the script prints a detailed usage message.


3. **Log Generation:**
   Logs for each tool are produced in the `logs/` directory, with file extensions specific to each tool (e.g., `.its`, `.tina`, `.petri32`, etc.).

   The full logs of our run are available in `rawlogs.tgz`. Before zipping them into `rawlogs.tgz`, we first remove the actual invariants from the output as the archived logs are otherwise over 250MB. We ran the following sed line:
   ```bash
   sed -i '/inv :.*/d' *.its
   ```
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

   The file `invar.csv` obtained from our logs is part of this repo. 

Caveat : 
 * We measure both P and T invariants in a single invocation, so a timeout on places induces a timeout on transitions. 
 * The status column contains "OK" when both P and T invariants were successfully computed. But the other status values are not fully homogeneous across tools, see the precise collection process is in `logs2csv.pl`. 
 * The tools are invoked as specified in run.sh, it could be the case that a better configuration or invocation of a tool exists to treat a model (e.g. Tina could be configured to avoid its single overflow).

5. **Generate Reports:**
   To build comparison plots, tables, and graphs, use the `makeReport.py` and `multiCompare.R` scripts:
   ```bash
   python makeReport.py
   Rscript multiCompare.R
   ```
   
The python builds a pdf [analysis_report.pdf](./docs/analysis_report.pdf) some distributions as box plots, some comparisons using cactus plots, as well as tables of results such as this one.   

| Tool         | Failure | Success | Total |
|--------------|---------|---------|-------|
| GreatSPN     | 69      | 1355    | 1424  |
| PetriSpot128 | 11      | 1413    | 1424  |
| PetriSpot32  | 55      | 1369    | 1424  |
| PetriSpot64  | 11      | 1413    | 1424  |
| itstools     | 28      | 1396    | 1424  |
| tina         | 504     | 920     | 1424  |
| tina4ti2     | 256     | 1168    | 1424  |

The R compares each pair of tools using scatter plots in time and memory and builds a pdf [Tool_Comparisons.pdf](./docs/Tool_Comparisons.pdf).
Each point is a model, so each plot contains 1424 points. Scales are log/log.
It also builds summary tables like this one.

| Tool          | Mean_Time | Mean_Mem | INVP_OK | INVT_OK | Status_OK | Status_OK_OF | Status_OK_OF_OF | Status_TO | Status_UNK | Status_TO_OF | Status_MOVF_OF |
|---------------|-----------|----------|---------|---------|-----------|--------------|-----------------|------------|------------|--------------|----------------|
| PetriSpot128  | 523.0     | 52527.0  | 1423    | 1419    | 1413      | 4            | 2               | 3          | 2          | 0            | 0              |
| PetriSpot32   | 534.0     | 39797.0  | 1400    | 1396    | 1369      | 24           | 3               | 27         | 1          | 0            | 0              |
| PetriSpot64   | 526.0     | 52529.0  | 1423    | 1419    | 1413      | 4            | 2               | 3          | 2          | 0            | 0              |
| itstools      | 966.0     | 191040.0 | 1416    | 1414    | 1396      | 14           | 5               | 8          | 0          | 1            | 0              |
| tina4ti2      | 17885.0   | 859936.0 | 1259    | 1259    | 1259      | 0            | 0               | 164        | 0          | 0            | 1              |
| tina          | 28689.0   | 198005.0 | 990     | 985     | 985       | 0            | 0               | 298        | 0          | 0            | 141            |
| GreatSPN      | 972.0     | 14582.0  | 1406    | 1355    | 1355      | 0            | 0               | 0          | 69         | 0            | 0              |


## Acknowledgements

This repository is available under the GPL license.

Created by Yann Thierry-Mieg, LIP6, Sorbonne Université, CNRS.

Contributions (PetriSpot integration) by Soufiane El Mouahid (Master student @ Sorbonne, 2024).

Comments leading to corrections by Bernard Berthomieu (LAAS, Tina author).

