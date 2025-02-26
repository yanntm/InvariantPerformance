#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(:sys_wait_h);  # For WNOHANG in waitpid
use Getopt::Long;          # For command-line options

# Default parallelism: number of CPUs or 4 if detection fails
use Sys::CPU;  # Optional, fallback if not installed
my $default_processes = eval { Sys::CPU::cpu_count() } // 4;
my $num_processes = $default_processes;

# Parse command-line option for parallelism
GetOptions("parallel=i" => \$num_processes) or die "Usage: $0 [--parallel=N]\n";
$num_processes = 1 if $num_processes < 1;  # Ensure at least 1 process

sub compute_solution_metrics {
    my ($log_file) = @_;
    my $sol_file_gz = "$log_file.sol.gz";  # Gzipped solution file
    my $sol_file = "$log_file.sol";        # Plain solution file
    my %metrics = (
        SolSizeKB     => -1,
        SolSize       => -1,
        SolPosSize    => -1,
        SolMaxCoeff   => -1,
        SolSumCoeff   => -1,
        SolNbCoeff    => -1
    );

    # Check for .sol.gz first, decompress if found, otherwise use .sol
    my $use_file = $sol_file;
    if (-f $sol_file_gz && -r $sol_file_gz) {
        system("gunzip -c $sol_file_gz > $sol_file");  # Decompress to temporary .sol
        $use_file = $sol_file if -f $sol_file;         # Use it if successful
    }

    # Return defaults if no usable file exists or isn’t readable
    return %metrics unless -f $use_file && -r $use_file;

    # File size in KB (use decompressed .sol size, whether decompressed here or pre-existing)
    my $size_bytes = (stat($use_file))[7] // 0;
    $metrics{SolSizeKB} = sprintf("%.3f", $size_bytes / 1024);

    # Open the decompressed or plain file
    open my $fh, '<', $use_file or return %metrics;

    my $num_lines = 0;
    my $num_pos_lines = 0;
    my $max_coeff = 0.0;       # Native double
    my $sum_coeff = 0.0;       # Native double for total sum
    my $num_terms = 0;

    while (my $line = <$fh>) {
        chomp $line;
        next unless $line;  # Skip empty lines

        $num_lines++;
        # Remove constant and everything after =
        $line =~ s/=.*$//;  # Drop /g, single match

        # Check for negatives for SolPosSize
        my $has_negative = ($line =~ /-/);
        $num_pos_lines++ unless $has_negative;

        # Simplify: remove signs, compress spaces, trim
        $line =~ s/[+-]//g;
        $line =~ s/\s+/ /g;
        $line =~ s/^\s+|\s+$//;  # Drop /g, single trim
        next unless $line;  # Skip if line is now empty

        # Split into terms
        my @terms = split /\s/, $line;
        $num_terms += scalar @terms;

        # Sum coefficients for this line into a double
        my $line_sum = 0.0;  # Native double for line-specific sum
        for my $term (@terms) {
            my ($coeff) = $term =~ /^(\d+)\*/;  # Match optional coefficient before *
            $coeff = 1 unless defined $coeff;   # Default to 1 if no explicit coefficient
            my $abs_coeff = abs($coeff + 0.0);  # Convert to double, take absolute value
            $max_coeff = $abs_coeff if $abs_coeff > $max_coeff;
            $line_sum += $abs_coeff;            # Add to line-specific sum
        }
        $sum_coeff += $line_sum;  # Add line sum to total after processing all terms
    }
    close $fh;

    # Clean up temporary .sol if we decompressed it
    unlink $sol_file if -f $sol_file_gz && -f $sol_file;

    # Set metrics with conditional formatting
    $metrics{SolSize} = $num_lines;
    $metrics{SolPosSize} = $num_pos_lines;
    $metrics{SolNbCoeff} = $num_terms;
    $metrics{SolMaxCoeff} = $max_coeff >= 10000 ? sprintf("%.3e", $max_coeff) : $max_coeff;
    $metrics{SolSumCoeff} = $sum_coeff >= 10000 ? sprintf("%.3e", $sum_coeff) : $sum_coeff;

    return %metrics;
}

# Parsing functions for each tool type
sub parse_petri_file {
    my ($file) = @_;
    if ($file =~ /\.petri(32|64|128)$/) {
        my $model = $file;
        my $flags = "";
        my $tool_base;
        if ($file =~ /^(.*)\.([^.]*)\.petri(32|64|128)$/) {
            $model = $1;
            $flags = $2 if $2;
            $tool_base = "PetriSpot$3";
        } else {
            $model =~ s/\.petri(32|64|128)//g;
            $tool_base = "PetriSpot$1";
        }
        my $tool = $flags ? "${tool_base}_$flags" : $tool_base;
        my $status = "UNK";
        my $ptime = -1, my $ttime = -1, my $nbp = -1, my $nbt = -1, my $tottime = -1, my $tmem = -1;
        my $timecmd = -1;
        my $cardp = -1, my $cardt = -1, my $carda = -1;
        my $examination = "UNK";
        my $overflow = 0;

        open my $fh, '<', $file or die "Could not open file '$file': $!";
        my $first_line = <$fh>;
        if ($first_line =~ /--Pflows/ and $first_line =~ /--Tflows/) {
            $examination = "FLOWS";
        } elsif ($first_line =~ /--Psemiflows/ and $first_line =~ /--Tsemiflows/) {
            $examination = "SEMIFLOWS";
        } elsif ($first_line =~ /--Pflows/) {
            $examination = "PFLOWS";
        } elsif ($first_line =~ /--Psemiflows/) {
            $examination = "PSEMIFLOWS";
        } elsif ($first_line =~ /--Tflows/) {
            $examination = "TFLOWS";
        } elsif ($first_line =~ /--Tsemiflows/) {
            $examination = "TSEMIFLOWS";
        }
        seek($fh, 0, 0);

        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /Reduce places removed (\d+) places/) {
                next;
            } elsif ($line =~ /overflow/i) {
                $overflow = 1;
                next;
            } elsif ($line =~ /Computed (\d+) P\s+flows in (\d+) ms/) {
                $nbp = $1;
                $ptime = $2;
                next;
            } elsif ($line =~ /Computed (\d+) T\s+flows in (\d+) ms/) {
                $nbt = $1;
                $ttime = $2;
                next;
            } elsif ($line =~ /Computed (\d+) P\s+semiflows in (\d+) ms/) {
                $nbp = $1;
                $ptime = $2;
                next;
            } elsif ($line =~ /Computed (\d+) T\s+semiflows in (\d+) ms/) {
                $nbt = $1;
                $ttime = $2;
                next;
            } elsif ($line =~ /Parsed PT model containing (\d+) places and (\d+) transitions and (\d+) arcs in (\d+) ms/) {
                $cardp = $1;
                $cardt = $2;
                $carda = $3;
                next;
            } elsif ($line =~ /Total runtime (\d+) ms/) {
                $tottime = $1;
                $status = "OK";
                next;
            } elsif ($line =~ /TIME LIMIT: Killed by timeout after (\d+) seconds/) {
                $timecmd = $1 * 1000;
                $status = "TO";
                next;
            } elsif ($line =~ /TIME LIMIT/) {
                $tottime = 120000;
                $status = "TO";
                next;
            } elsif ($line =~ /.*user .*system (.*)elapsed .*CPU \(.*avgtext+.*avgdata (.*)maxresident\)k/) {
                $timecmd = $1;
                $tmem = $2;
                if ($timecmd =~ /(\d+):(\d+)\.(\d+)/) {
                    my $frac_ms = $3 * (10 ** (3 - length($3)));
                    $timecmd = 60000 * $1 + 1000 * $2 + $frac_ms;
                }
            }
        }
        close $fh;

        if ($overflow) {
            $status = "OF";
            $nbp = -1;
            $nbt = -1;
        }

        my $time_internal;
        if ($ptime != -1 && $ttime != -1 && $ptime != $ttime) {
            $time_internal = "$ptime/$ttime";
        } elsif ($ptime != -1) {
            $time_internal = $ptime;
        } else {
            $time_internal = $ttime;
        }

        my %sol_metrics = compute_solution_metrics($file);
        print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$sol_metrics{SolSizeKB},$sol_metrics{SolSize},$sol_metrics{SolPosSize},$sol_metrics{SolMaxCoeff},$sol_metrics{SolSumCoeff},$sol_metrics{SolNbCoeff},$timecmd,$tmem,$status\n";
    }
}

sub parse_its_file {
    my ($file) = @_;
    if ($file =~ /its$/) {
        my $model = $file;
        $model =~ s/\.its//g;
        my $tool = "ItsTools";
        my $status = "UNK";
        my $ptime = -1, my $ttime = -1, my $nbp = -1, my $nbt = -1;
        my $tottime = -1, my $tmem = -1;
        my $timecmd = -1;
        my $cardp = -1, my $cardt = -1, my $carda = -1;
        my $examination = "UNK";
        my $ofp = 0, my $oft = 0;

        open my $fh, '<', $file or die "Could not open file '$file': $!";
        my $first_line = <$fh>;
        if ($first_line =~ /--Pflows/ and $first_line =~ /--Tflows/) {
            $examination = "FLOWS";
        } elsif ($first_line =~ /--Psemiflows/ and $first_line =~ /--Tsemiflows/) {
            $examination = "SEMIFLOWS";
        } elsif ($first_line =~ /--Pflows/) {
            $examination = "PFLOWS";
        } elsif ($first_line =~ /--Psemiflows/) {
            $examination = "PSEMIFLOWS";
        } elsif ($first_line =~ /--Tflows/) {
            $examination = "TFLOWS";
        } elsif ($first_line =~ /--Tsemiflows/) {
            $examination = "TSEMIFLOWS";
        }
        seek($fh, 0, 0);

        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /Computed (\d+) P\s+flows in (\d+) ms/) {
                $nbp = $1;
                $ptime = $2;
                next;
            } elsif ($line =~ /Computed (\d+) T\s+flows in (\d+) ms/) {
                $nbt = $1;
                $ttime = $2;
                next;
            } elsif ($line =~ /Invariants computation overflowed/) {
                if ($ptime == -1) {
                    $ofp = 1;
                } else {
                    $oft = 1;
                }
            } elsif ($line =~ /Parsed PT model containing (\d+) places and (\d+) transitions and (\d+) arcs in (\d+) ms/) {
                $cardp = $1;
                $cardt = $2;
                $carda = $3;
            } elsif ($line =~ /Unfolded HLPN to a Petri net with (\d+) places and (\d+) transitions (\d+) arcs in (\d+) ms/) {
                $cardp = $1;
                $cardt = $2;
                $carda = $3;
            } elsif ($line =~ /Total runtime (\d+) ms/) {
                $tottime = $1;
                $status = "OK";
                next;
            } elsif ($line =~ /TIME LIMIT/) {
                $tottime = 120000;
                $status = "TO";
                next;
            } elsif ($line =~ /.*user .*system (.*)elapsed .*CPU \(.*avgtext+.*avgdata (.*)maxresident\)k/) {
                $timecmd = $1;
                $tmem = $2;
                if ($timecmd =~ /(\d+):(\d+)\.(\d+)/) {
                    my $frac_ms = $3 * (10 ** (3 - length($3)));
                    $timecmd = 60000 * $1 + 1000 * $2 + $frac_ms;
                }
            }
        }
        close $fh;

        if ($ofp || $oft) {
            $status = "OF";
            $nbp = -1;
            $nbt = -1;
        }

        my $time_internal = $tottime;
        my %sol_metrics = compute_solution_metrics($file);
        print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$sol_metrics{SolSizeKB},$sol_metrics{SolSize},$sol_metrics{SolPosSize},$sol_metrics{SolMaxCoeff},$sol_metrics{SolSumCoeff},$sol_metrics{SolNbCoeff},$timecmd,$tmem,$status\n";
    }
}

sub parse_tina_file {
    my ($file) = @_;
    if ($file =~ /\.(struct|tina)$/) {
        my $model = $file;
        $model =~ s/\.(struct|tina)$//;
        my $tool = ($file =~ /\.struct$/) ? "tina4ti2" : "tina";
        my $status = "UNK";
        my $nbp   = -1;
        my $nbt   = -1;
        my $tmem  = -1;
        my $timecmd = -1;
        my $cardp = -1;
        my $cardt = -1;
        my $carda = -1;
        my $examination = "UNK";
        my $of = 0;

        open my $fh, '<', $file or die "Could not open file '$file': $!";
        my $first_line = <$fh>;
        if ($first_line =~ /-F/ and $first_line =~ /-T/) {
            $examination = "TFLOWS";
        } elsif ($first_line =~ /-F/ and $first_line =~ /-P/) {
            $examination = "PFLOWS";
        } elsif ($first_line =~ /-S/ and $first_line =~ /-T/) {
            $examination = "TSEMIFLOWS";
        } elsif ($first_line =~ /-S/ and $first_line =~ /-P/) {
            $examination = "PSEMIFLOWS";
        } elsif ($first_line =~ /-F\b/) {
            $examination = "FLOWS";
        } elsif ($first_line =~ /-S\b/) {
            $examination = "SEMIFLOWS";
        } else {
            $examination = "UNK";
        }
        seek($fh, 0, 0);

        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /(\d+) places, (\d+) transitions, (\d+) arcs/) {
                $cardp = $1;
                $cardt = $2;
                $carda = $3;
            } elsif ($line =~ /(\d+) flow\(s\)/) {
                if ($nbp == -1) {
                    $nbp = $1;
                } else {
                    $nbt = $1;
                }
            } elsif ($line =~ /no flow\(s\)/) {
                if ($nbp == -1) {
                    $nbp = 0;
                } else {
                    $nbt = 0;
                }
            } elsif ($line =~ /(\d+) semiflow\(s\)/) {
                if ($nbp == -1) {
                    $nbp = $1;
                } else {
                    $nbt = $1;
                }
            } elsif ($line =~ /no semiflow\(s\)/) {
                if ($nbp == -1) {
                    $nbp = 0;
                } else {
                    $nbt = 0;
                }
            } elsif ($line =~ /ANALYSIS COMPLETED/) {
                $status = "OK";
                next;
            } elsif ($line =~ /TIME LIMIT: Killed by timeout after (\d+) seconds/) {
                $timecmd = $1 * 1000;
                $status = "TO";
                next;
            } elsif ($line =~ /Command terminated by signal 9/) {
                $status = "MOVF";
                next;
            } elsif ($line =~ /overflow/) {
                $of = 1;
            } elsif ($line =~ /Command exited with non-zero status/) {
                $status = "MOVF";
                next;
            } elsif ($line =~ /.*user .*system (.*)elapsed .*CPU \(.*avgtext+.*avgdata (.*)maxresident\)k/) {
                $timecmd = $1;
                $tmem = $2;
                if ($timecmd =~ /(\d+):(\d+)\.(\d+)/) {
                    my $frac_ms = $3 * (10 ** (3 - length($3)));
                    $timecmd = 60000 * $1 + 1000 * $2 + $frac_ms;
                }
            }
        }
        close $fh;

        if ($of == 1) {
            $status = "OF";
            $nbp = -1;
            $nbt = -1;
        }

        my $time_internal = -1;
        my %sol_metrics = compute_solution_metrics($file);
        print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$sol_metrics{SolSizeKB},$sol_metrics{SolSize},$sol_metrics{SolPosSize},$sol_metrics{SolMaxCoeff},$sol_metrics{SolSumCoeff},$sol_metrics{SolNbCoeff},$timecmd,$tmem,$status\n";
    }
}

sub parse_gspn_file {
    my ($file) = @_;
    if ($file =~ /\.gspn$/) {
        my $model = $file;
        $model =~ s/\.gspn//g;
        my $tool = "GreatSPN";
        my $status = "UNK";
        my ($ptime, $nbp, $nbt, $timecmd, $tmem) = (-1, -1, -1, -1, -1);
        my ($cardp, $cardt, $carda) = (-1, -1, -1);
        my $examination = "UNK";
        my $of = 0;

        open my $fh, '<', $file or die "Could not open file '$file': $!";
        my $first_line = <$fh>;
        if (defined $first_line) {
            chomp $first_line;
            if ($first_line =~ /-pbasis/ and $first_line =~ /-tbasis/) {
                $examination = "FLOWS";
            } elsif ($first_line =~ /-pinv/ and $first_line =~ /-tinv/) {
                $examination = "SEMIFLOWS";
            } elsif ($first_line =~ /-tbasis/) {
                $examination = "TFLOWS";
            } elsif ($first_line =~ /-pbasis/) {
                $examination = "PFLOWS";
            } elsif ($first_line =~ /-tinv/) {
                $examination = "TSEMIFLOWS";
            } elsif ($first_line =~ /-pinv/) {
                $examination = "PSEMIFLOWS";
            } else {
                $examination = "UNK";
            }
        }

        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /PLACES:\s+(\d+)/) {
                $cardp = $1;
            } elsif ($line =~ /TRANSITIONS:\s+(\d+)/) {
                $cardt = $1;
            } elsif ($line =~ /FOUND (\d+) VECTORS IN THE PLACE FLOW BASIS/) {
                $nbp = $1;
            } elsif ($line =~ /FOUND (\d+) VECTORS IN THE TRANSITION FLOW BASIS/) {
                $nbt = $1;
            } elsif ($line =~ /FOUND (\d+) PLACE SEMIFLOWS/) {
                $nbp = $1;
            } elsif ($line =~ /FOUND (\d+) TRANSITION SEMIFLOWS/) {
                $nbt = $1;
            } elsif ($line =~ /TIME LIMIT: Killed by timeout after (\d+) seconds/) {
                $timecmd = $1 * 1000;
                $status = "TO";
                next;
            } elsif ($line =~ /TIME LIMIT/) {
                $timecmd = 120000;
                $status = "TO";
                next;
            } elsif ($line =~ /overflow/) {
                $of = 1;
            } elsif ($line =~ /TOTAL TIME:\s*\[User\s+(\d+\.\d+)s,\s*Sys\s+(\d+\.\d+)s\]/) {
                my $user_time = $1;
                my $sys_time  = $2;
                $ptime = ($user_time + $sys_time) * 1000.0;
            } elsif ($line =~ /(\d+\.\d+)user\s+(\d+\.\d+)system\s+(\d+):(\d+)\.(\d+)elapsed/) {
                my $user = $1;
                my $system = $2;
                my $minutes = $3;
                my $seconds = $4;
                my $fraction = $5;
                my $frac_ms = $fraction * (10 ** (3 - length($fraction)));
                $timecmd = 60000 * $minutes + 1000 * $seconds + $frac_ms;
            }
            if ($line =~ /(\d+)maxresident\)k/) {
                $tmem = $1;
            }
        }
        close $fh;

        if ($of == 1) {
            $status = "OF";
            $nbp = -1;
            $nbt = -1;
        }

        if ($status ne "TO" and $status ne "OF") {
            if ($examination eq "FLOWS") {
                $status = (($nbp != -1) and ($nbt != -1)) ? "OK" : "ERR";
            } elsif ($examination eq "PFLOWS" or $examination eq "PSEMIFLOWS") {
                $status = ($nbp != -1) ? "OK" : "ERR";
            } elsif ($examination eq "TFLOWS" or $examination eq "TSEMIFLOWS") {
                $status = ($nbt != -1) ? "OK" : "ERR";
            } else {
                $status = "ERR";
            }
        }

        my $time_internal = $ptime;
        my %sol_metrics = compute_solution_metrics($file);
        print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$sol_metrics{SolSizeKB},$sol_metrics{SolSize},$sol_metrics{SolPosSize},$sol_metrics{SolMaxCoeff},$sol_metrics{SolSumCoeff},$sol_metrics{SolNbCoeff},$timecmd,$tmem,$status\n";
    }
}

# Main script
# Create pipe for children to write CSV lines
pipe(my $pipe_read, my $pipe_write) or die "Cannot create pipe: $!";
my @all_files = (<*petri*>, <*its>, <*struct>, <*tina>, <*gspn>);
my $total_files = scalar @all_files;
my $chunk_size = int(($total_files + $num_processes - 1) / $num_processes);  # Ceiling division

# Write CSV header to file
open my $csv_fh, '>', 'invar.csv' or die "Cannot open invar.csv: $!";
print $csv_fh "Model,Tool,Examination,CardP,CardT,CardA,NbPInv,NbTInv,TimeInternal,SolSizeKB,SolSize,SolPosSize,SolMaxCoeff,SolSumCoeff,SolNbCoeff,Time,Mem,Status\n";
close $csv_fh;

# Fork children to process files
my @child_pids;
for (my $i = 0; $i < $num_processes && $i * $chunk_size < $total_files; $i++) {
    my $pid = fork();
    if (!defined $pid) {
        die "Fork failed: $!";
    } elsif ($pid == 0) {  # Child process
        # Close read end of pipe in child
        close $pipe_read;
        # Redirect stdout to pipe write end
        open STDOUT, '>&', $pipe_write or die "Cannot redirect stdout to pipe: $!";
        close $pipe_write;  # Close original write handle after redirect

        # Process chunk of files
        my $start = $i * $chunk_size;
        my $end = ($i + 1) * $chunk_size - 1;
        $end = $total_files - 1 if $end >= $total_files;
        for my $j ($start..$end) {
            my $file = $all_files[$j];
            if ($file =~ /\.petri(32|64|128)$/) {
                parse_petri_file($file);
            } elsif ($file =~ /\.its$/) {
                parse_its_file($file);
            } elsif ($file =~ /\.(struct|tina)$/) {
                parse_tina_file($file);
            } elsif ($file =~ /\.gspn$/) {
                parse_gspn_file($file);
            }
        }
        exit 0;  # Child exits after processing its chunk
    } else {  # Parent process
        push @child_pids, $pid;
    }
}

# Parent: Close write end of pipe
close $pipe_write;

# Parent: Read from pipe and append to invar.csv until EOF
open my $csv_fh, '>>', 'invar.csv' or die "Cannot reopen invar.csv: $!";
while (my $line = <$pipe_read>) {
    print $csv_fh $line;
}
close $pipe_read;
close $csv_fh;

# Wait for all children to ensure cleanup
foreach my $pid (@child_pids) {
    waitpid($pid, 0);
}