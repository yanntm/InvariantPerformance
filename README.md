# InvariantPerformance

This repository contains scripts and logs of experiments on computation of Petri net invariants using ITS-Tools and Tina.

This experiment compares the performance of these two tools over the set of models taken from the Model-Checking Contest (2022 edition) http://mcc.lip6.fr.

![Time](./time.svg?)

![Memory](./mem.svg?)

Overall results :
* 1384 total models evaluated
* ITS-Tools solved 1374 and timed out (>120 seconds) in 10 cases
* Tina with 4ti2 solved 1215, timed out (>120 seconds) in 157 cases and produced a memory overflow (>16 GB) in 8 cases.
* Tina without 4ti2 solved 948, timed out (>120 seconds) in 289 cases and produced a memory overflow (>16 GB) in 146 cases.

Due to Tina with 4ti2 outprforming Tina, we simply compare ITS-Tools to Tina with 4ti2 in the plots.

# Running the experiment

We used the following shell commands to build the raw logs:

```
for i in ~/Downloads/TEST/INPUTS/*/ ; do model=$(echo $i |  awk -F/ '{print $NF}') ;  if [ ! -f $model.struct ] ; then echo "Treating $model" ;  ~/Downloads/TEST/bin/timeout.pl 120 time systemd-run --scope -p MemoryMax=16G --user  ./struct -4ti2 -F -q $i/model.pnml > $model.struct 2>&1 ; fi ;  done

for i in ~/Downloads/TEST/INPUTS/*/ ; do model=$(echo $i | awk -F/ '{print $NF}') ;  if [ ! -f $model.its ] ; then echo "Treating $model" ;  ~/Downloads/TEST/bin/timeout.pl 120 time systemd-run --scope -p MemoryMax=16G --user ~/Downloads/TEST/itstools/itstools/its-tools -pnfolder $i --Pflows --Tflows  > $model.its 2>&1 ; fi ;  done

for i in ~/Downloads/TEST/INPUTS/*PT*/ ; do model=$(echo $i | awk -F/ '{print $NF}') ;  if [ ! -f $model.tina ] ; then echo "Treating $model" ;  ~/Downloads/TEST/bin/timeout.pl 120 time systemd-run --scope -p MemoryMax=16G --user  ./struct -F -q $i/model.pnml > $model.tina 2>&1 ; fi ;  done
```

We apologize for the hard coded paths, but they can be easily adapted.
In these commands,
* `~/Downloads/TEST/INPUTS/*/` corresponds to all models of the MCC 2022, extracted from our https://github.com/yanntm/pnmcc-models-2022 repository. We dropped 4 models with respect to 2022 MCC : StigmergyCommit-PT-11b, TokenRing-PT-040, TokenRing-PT-050 which are all too big to be stored on GitHub (over 100MB compressed) and GPPP-PT-C0010N1000000000 whose initial marking overflows from 32 bit integers and both tools fail immediately. 
* `timeout.pl` is a small utility to force a timeout, available from https://github.com/yanntm/MCC-drivers/blob/master/bin/timeout.pl
* `systemd-run` is some cgroups mantra to enforce a memory limit at 16GB
* `struct` is the Tina utility downloaded from https://projects.laas.fr/tina/download.php, in version 3.7.0. Note that we also installed `4ti2`
* `its-tools` is the ITS-Tools command line version, available from https://github.com/yanntm/ITS-Tools-MCC We used version 202303281143.
* Logs are produced in *.its and *.tina and *.struct files; these commands can be rerun if some issue happened and some logs are missing.

These commands produce the raw logs.
Before zipping them into `rawlogs.tgz` of this repository, we first remove the actual invariants from the output as the archived logs are otherwise over 250MB.
We ran the following sed line :`sed -i '/inv :.*/d' *.its`.
The flag `-q` we use for Tina means "quiet" and avoids printing the actual invariants, but ITS-Tools does not have such a flag.

We then ran the perl script `logs2csv.pl` to extract from these logs one line per log that provides the following columns :
* Model the name of the model
* Tool the tool, its, tina4ti2 or tina
* CardP the number of places in the net
* CardT the number of transitions in the net
* CardA the number of arcs in the net
* PTime the time to compute P flows in ms
* TTime the time to compute T flows in ms
* ConstP the number of constant places reported by ITS-tools (always 0 in Tina runs). These constant places are simplified away in ITS-Tools so they do not produce trivial flows with a single entry like with Tina. 
* NBP the number of P flows reported
* NBT the number of T flows reported
* TotalTime total runtime in ms as reported by ITS-Tools at end of run; this is measured within the application, hence it does not include JVM startup time. Value is 0 for Tina.
* Time is the total elapsed time as reported by the `time` command converted to milliseconds (or 120 seconds if some error occurred)
* Mem is the value reported by time in the `maxresident` field, it estimates memory usage in KB.
* Status is OK if the run finished normally, TO if we timed out, MOVF if there was a memory overflow, ERR if an error was detected

The resulting `invar.csv` file is part of this repository.

Finally to produce some visualisation, we used the script `compareForm.R`, this produces the `fplots.pdf` file and `mem.svg` `time.svg`.

We use as time measurement the sum of reported times to compute P and T flows by both tools; while elapsed time
 measured externally is also interesting it is polluted by JVM startup time (around 700 ms) and the fact that ITS-Tools actually
 prints the invariants (with some intense I/O) when Tina simply prints the number of invariants computed.

We also filter COL models at this stage, it seems that Tina is computing the invariants of the skeleton of the net when provided a COL model, whereas ITS-Tools actually unfolds the model and reports invariants on it's unfolding, so that the results on COL models are incomparable.

