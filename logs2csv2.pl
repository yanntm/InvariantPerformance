#! /usr/bin/perl


use strict vars;

print "Model,Tool,Examination,CardP,CardT,CardA,NbPInv,NbTInv,TimeInternal,Time,Mem,Status\n";

my @files = <*petri*>;
foreach my $file (@files) {
    if ( $file =~ /petri(32|64|128)$/ ) {
        my $model = $file;
        my $tool = "PetriSpot$1";
        $model =~ s/\.petri(32|64|128)//g;
        my $status = "UNK";
        my $ptime = -1, my $ttime = -1, my $nbp = -1, my $nbt = -1, my $tottime = -1, my $tmem = -1;
        my $timecmd = -1;
        my $cardp = -1, my $cardt = -1, my $carda = -1;
        my $examination = "UNK";
        my $overflow = 0;

        # Open the file and read the first line to determine the examination mode.
        open IN, "< $file";
        my $first_line = <IN>;
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
        # Reset file pointer to start processing all lines.
        seek(IN, 0, 0);

        while (my $line = <IN>) {
            chomp $line;
            if ($line =~ /Reduce places removed (\d+) places/) {
                # (Not used in petrispot logs)
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
        close IN;

        # If any overflow occurred, override status and invariant counts.
        if ($overflow) {
            $status = "OF";
            $nbp = -1;
            $nbt = -1;
        }

        # Determine TimeInternal: if both ptime and ttime are set and differ, show both separated by "/"
        my $time_internal;
        if ($ptime != -1 && $ttime != -1 && $ptime != $ttime) {
            $time_internal = "$ptime/$ttime";
        } elsif ($ptime != -1) {
            $time_internal = $ptime;
        } else {
            $time_internal = $ttime;
        }

        print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$timecmd,$tmem,$status\n";
    }
}


my @files = <*its>;
foreach my $file (@files) {
    if ( $file =~ /its$/ ) {  
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
        
        open IN, "< $file";
        my $first_line = <IN>;
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
        # Reset file pointer to process all lines.
        seek(IN, 0, 0);
        
        while (my $line = <IN>) {
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
        close IN;
        
        if ($ofp || $oft) {
            $status = "OF";
            $nbp = -1;
            $nbt = -1;
        }
        
        # Use the Total runtime value as TimeInternal.
        my $time_internal = $tottime;
        
        print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$timecmd,$tmem,$status\n";
    }
}


my @files = (<*struct>, <*tina>);
foreach my $file (@files) {
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
        
        open IN, "< $file";
        # Determine Examination from the first line of the log.
        my $first_line = <IN>;
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
        # Reset file pointer to process all lines.
        seek(IN, 0, 0);
        
        while (my $line = <IN>) {
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
        close IN;
        
        if ($of == 1) {
            $status = "OF";
            $nbp = -1;
            $nbt = -1;
        }
        
        # For Tina logs, we choose to report -1 as the internal time.
        my $time_internal = -1;
        
        print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$timecmd,$tmem,$status\n";
    }
}


my @files = <*gspn>;
foreach my $file (@files) {
    my $model = $file;
    $model =~ s/\.gspn//g;
    my $tool = "GreatSPN";
    my $status = "UNK";
    my ($ptime, $ttime, $nbp, $nbt, $tottime, $timecmd, $tmem) = (-1, -1, -1, -1, -1, -1, -1);
    my ($cardp, $cardt, $carda) = (-1, -1, 0);  # arc info not provided: set to 0
    my $is_semiflow = 0;  # flag if log contains semiflow info
    open my $fh, '<', $file or die "Could not open file '$file' $!";
    my $of = 0;
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
            $is_semiflow = 1;
        } elsif ($line =~ /FOUND (\d+) TRANSITION SEMIFLOWS/) {
            $nbt = $1;
            $is_semiflow = 1;
        } elsif ($line =~ /TIME LIMIT/) {
            $timecmd = 120000;
            $status = "TO";
            next;
        } elsif ($line =~ /overflow/) {
            $of = 1;
        } elsif ($line =~ /TOTAL TIME: \[User (\d+\.\d+)s, Sys (\d+\.\d+)s\]/) {
            my $user_time = $1;
            my $sys_time  = $2;
            if ($ptime == -1) {
                $ptime = ($user_time + $sys_time) * 1000.0;
            } else {
                $ttime = ($user_time + $sys_time) * 1000.0;
            }
            if ($ptime != -1 and $ttime != -1) {
                $status = "OK";
                next;
            }
        } elsif ($line =~ /(\d+\.\d+)user\s+(\d+\.\d+)system\s+(\d+):(\d+)\.(\d+)elapsed/) {
            my $user = $1;
            my $system = $2;
            my $minutes = $3;
            my $seconds = $4;
            my $fraction = $5;
            $timecmd = 60000 * $minutes + $seconds * 1000 + ( $fraction * (10 ** (3 - length($fraction))) );
        } 
        if ($line =~ /(\d+)maxresident\)k/) {
            $tmem = $1;
        }
    }
    close $fh;
    
    # Compute total internal time (if both ptime and ttime are available)
    $tottime = ($ptime != -1 and $ttime != -1) ? $ptime + $ttime : -1;
    if ($of == 1) {
        $status = "OF";
    }
    
    # Determine Examination field based on content:
    my $examination;
    if ($is_semiflow) {
        if ($nbp != -1 and $nbt != -1) {
            $examination = "SEMIFLOWS";
        } elsif ($nbp != -1) {
            $examination = "PSEMIFLOWS";
        } elsif ($nbt != -1) {
            $examination = "TSEMIFLOWS";
        } else {
            $examination = "SEMIFLOWS";
        }
    } else {
        if ($nbp != -1 and $nbt != -1) {
            $examination = "FLOWS";
        } elsif ($nbp != -1) {
            $examination = "PFLOWS";
        } elsif ($nbt != -1) {
            $examination = "TFLOWS";
        } else {
            $examination = "FLOWS";
        }
    }
    
    # Use totime as TimeInternal.
    my $time_internal = $tottime;
    
    print "$model,$tool,$examination,$cardp,$cardt,$carda,$nbp,$nbt,$time_internal,$timecmd,$tmem,$status\n";
}
