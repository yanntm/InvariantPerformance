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
        my $ofp = 0, my $oft = 0;
        my $examination = "UNK";

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
                # (Originally used for ITS, not used in petrispot logs.)
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
                # $parsetime = $4;
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
                    $timecmd = 60000 * $1 + $2 * 1000 + $3;
                }
            }
        }
        if ($ofp == 1) {
            $status .= "_OF";
        }
        if ($oft == 1) {
            $status .= "_OF";
        }
        close IN;

        # Determine TimeInternal: if both ptime and ttime are set, report them as "ptime/ttime"
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
