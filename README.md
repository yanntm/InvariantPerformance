# InvariantPerformance

This repository contains scripts and logs of experiments on computation of Petri net invariants using ITS-Tools and Tina.

This experiment compares the performance of these two tools over the set of models taken from the Model-Checking Contest (2022 edition).

# Running the experiment

We used the following shell commands to build the raw logs:

```
for i in ~/Downloads/TEST/INPUTS/*/ ; do model=$(echo $i | cut -d '/' -f 7) ;  if [ ! -f $model.struct ] ; then echo "Treating $model" ;  ~/Downloads/TEST/bin/timeout.pl 120 time systemd-run --scope -p MemoryMax=16G --user  ./struct -4ti2 -F -q $i/model.pnml > $model.struct 2>&1 ; fi ;  done

for i in ~/Downloads/TEST/INPUTS/*/ ; do model=$(echo $i | cut -d '/' -f 7) ;  if [ ! -f $model.its ] ; then echo "Treating $model" ;  ~/Downloads/TEST/bin/timeout.pl 120 time systemd-run --scope -p MemoryMax=16G --user ~/Downloads/TEST/itstools/itstools/its-tools -pnfolder $i --Pflows --Tflows  > $model.its 2>&1 ; fi ;  done
```

We apologize for the hard coded paths, but they can be easily adapted.
In these commands,
* `~/Downloads/TEST/INPUTS/*/` corresponds to all models of the MCC 2022, extracted from our https://github.com/yanntm/pnmcc-models-2022 repository
* `timeout.pl` is a small utility to force a timeout, available from https://github.com/yanntm/MCC-drivers/blob/master/bin/timeout.pl
* `systemd-run` is some cgroups mantra to enforce a memory limit at 16GB
* `struct` is the Tina utility downloaded from , in version 3.7.0. Note that we also installed `4ti2`
* `its-tools` is the ITS-Tools command line version, available from https://github.com/yanntm/ITS-Tools-MCC We used version 
* Logs are produced in *.its and *.struct files; these commands can be rerun if some issue happened and some logs are missing.

These commands produce the raw logs, contained in `rawlogs.tgz` of this repository.

We then ran the perl script `logs2csv.pl` to extract from these logs one line per log that provides the following columns :
* Model the name of the model
* Tool the tool, its or tina
* CardP the number of places in the net
* CardT the number of transitions in the net
* CardA the number of arcs in the net
* PTime the time to compute P flows in ms
* TTime the time to compute T flows in ms
* ConstP the number of constant places reported by ITS-tools (always 0 in Tina runs). These constant places are simplified away in ITS-Tools so they do not produce trivial flows with a single entry like with Tina. 
* NBP the number of P flows reported
* NBT the number of T flows reported
* TotalTime total runtime in ms as reported by ITS-Tools at end of run; this is measured within the application, hence it does not include JVM startup time.
* Time is the total elapsed time as reported by the `time` command
* Mem is the value reported by time in the `maxresident` field, it estimates memory usage in KB.
* Status is OK if the run finished normally, TO if we timed out, MOVF if there was a memory overflow, ERR if an error was detected

The resulting `invar.csv` file is part of this repository.

Finally to produce some visualisation, we used the script `compareForm.R`, this produces the `fplots.pdf` file.
