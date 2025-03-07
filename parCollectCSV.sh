oarsub -l '{(host like "tall%")}/nodes=1/core=64,walltime=12:00:00' "cd ~/git/InvariantPerformance/logs_pflows/ ; ../logs2csvpar.pl --parallel=64 > ../pflows.csv ; exit"
oarsub -l '{(host like "tall%")}/nodes=1/core=64,walltime=12:00:00' "cd ~/git/InvariantPerformance/logs_psemiflows/ ; ../logs2csvpar.pl --parallel=64 > ../psemiflows.csv ; exit"
oarsub -l '{(host like "tall%")}/nodes=1/core=64,walltime=12:00:00' "cd ~/git/InvariantPerformance/logs_tsemiflows/ ; ../logs2csvpar.pl --parallel=64 > ../tsemiflows.csv ; exit"
oarsub -l '{(host like "tall%")}/nodes=1/core=64,walltime=12:00:00' "cd ~/git/InvariantPerformance/logs_tflows/ ; ../logs2csvpar.pl --parallel=64 > ../tflows.csv ; exit"


