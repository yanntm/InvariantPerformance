#! /usr/bin/perl


use strict vars;


print "Model,Tool,CardP,CardT,CardA,PTime,TTime,ConstP,NBP,NBT,TotalTime,Time,Mem,Status\n";

my @files = <*petri*>;
foreach my $file (@files) {
    if ( $file =~ /petri(32|64|128)$/ ) {
        my $model = $file;
        my $tool = "PetriSpot$1";
        $model =~ s/\.petri(32|64|128)//g;
        my $status = "UNK";
        my $ptime = -1, my $ttime = -1, my $constp = 0, my $nbp = 0, my $nbt = 0, my $tottime = -1, my $tmem = -1;
        my $timecmd = -1;
        my $colp = -1, my $colt = -1;
        my $cardp = -1, my $cardt = -1, my $carda = -1;
        open IN, "< $file";
        my $ofp = 0, my $oft = 0;
        while (my $line = <IN>) {
            chomp $line;
            if ($line =~ /Reduce places removed (\d+) places/) {
                $constp = $1;
                next;
            } elsif ($line =~ /Computed (\d+) P\s+flows in (\d+) ms/) {
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
        print "$model,$tool,$cardp,$cardt,$carda,$ptime,$ttime,$constp,$nbp,$nbt,$tottime,$timecmd,$tmem,$status\n";
    }
}
  



my @files = <*its>;
#print "working on files : @files";
foreach my $file (@files) {
    if ( $file =~ /its$/ ) {	
	#print "looking at file : $file";
	my $model=$file;
	$model =~ s/\.its//g ;
	my $tool="itstools";
	my $status="UNK";
	my $ptime=-1, my $ttime=-1, my $constp=0, my $nbp=0, my $nbt=0, my $tottime=-1, my $tmem=-1;
	my $timecmd=-1;
	my $colp=-1,my $colt=-1;
	my $cardp=-1,my $cardt=-1,my$carda=-1;
	open IN, "< $file";
	my $ofp=0, my $oft=0;
	while (my $line=<IN>) {
	    chomp $line;
	    if ($line =~ /Reduce places removed (\d+) places/) {
		$constp=$1;
		next;
	    } elsif ($line =~ /Computed (\d+) P\s+flows in (\d+) ms/) {
		$nbp=$1;
		$ptime=$2;
		next;
	    } elsif ($line =~ /Computed (\d+) T\s+flows in (\d+) ms/) {
		$nbt=$1;
		$ttime=$2;
		next;
	    } elsif ($line =~ /Invariants computation overflowed/) {
		if ($ptime == -1) {
		    $ofp=1;
		} else {
		    $oft=1;
		}
	    } elsif ($line =~ /Parsed PT model containing (\d+) places and (\d+) transitions and (\d+) arcs in (\d+) ms/) {
		$cardp=$1;
		$cardt=$2;
		$carda=$3;
		# $parsetime=$4;
	    } elsif ($line =~ /Unfolded HLPN to a Petri net with (\d+) places and (\d+) transitions (\d+) arcs in (\d+) ms/) {
		$cardp=$1;
		$cardt=$2;
		$carda=$3;
		# $parsetime=$4;
	    } elsif ($line =~ /Total runtime (\d+) ms/) {
		$tottime=$1;
		$status="OK";
		next;
	    } elsif ($line =~ /TIME LIMIT/) {
		$tottime=120000;
		$status="TO";
		next;
	    } elsif ($line =~ /.*user .*system (.*)elapsed .*CPU \(.*avgtext+.*avgdata (.*)maxresident\)k/) {
		$timecmd=$1;
		$tmem=$2;
		if ($timecmd =~ /(\d+):(\d+)\.(\d+)/) {
		    $timecmd = 60000*$1 + $2*1000 + $3;
		}
	    }
	}
	if ($ofp==1) {
	    $status .= "_OF";	    
	}
	if ($oft==1) {
	    $status .= "_OF";
	}
	close IN;
	print "$model,itstools,$cardp,$cardt,$carda,$ptime,$ttime,$constp,$nbp,$nbt,$tottime,$timecmd,$tmem,$status\n";
    }
}   



@files = <*struct>;
#print "working on files : @files";
foreach my $file (@files) {
    if ( $file =~ /struct$/ ) {	
	#print "looking at file : $file";
	my $model=$file;
	$model =~ s/\.struct//g ;
	my $tool="tina4ti2";
	my $status="UNK";
	my $ptime=-1, my $ttime=-1, my $constp=0, my $nbp=-1, my $nbt=-1, my $tottime=-1, my $tmem=-1;
	my $timecmd=-1;
	my $colp=-1,my $colt=-1;
	my $cardp=-1,my $cardt=-1,my$carda=-1;
	open IN, "< $file";
	my $of=0;
	while (my $line=<IN>) {
	    chomp $line;
	    if ($line =~ /(\d+) places, (\d+) transitions, (\d+) arcs/) {
		$cardp=$1;
		$cardt=$2;
		$carda=$3;
		# $parsetime=$4;
	    } elsif ($line =~ /(\d+) flow\(s\)/) {
		if ($nbp == -1) {
		    $nbp=$1;
		} else {
		    $nbt=$1;
		}
	    } elsif ($line =~ /^(\d+\.\d+)s$/) {
		if ($nbp == -1) {
		    next;
		} elsif ($nbp != -1 && $nbt == -1) {
		    $ptime=$1*1000.0;
		} elsif ($nbp != -1 && $nbt != -1) {
		    $ttime=$1*1000.0;
		    $status="OK";
		}
		next;
	    } elsif ($line =~ /overflow/) {
		# probably this :
		# unexpected failure (overflow ?), please retry with flag -mp
		$of = 1;
	    } elsif ($line =~ /TIME LIMIT/) {
		$timecmd=120000;
		$status="TO";
		next;
	    } elsif ($line =~ /Command terminated by signal 9/) {
		$status="MOVF";
		next;
	    } elsif ($line =~ /Command exited with non-zero status/) {
		$status="MOVF";
		next;
	    } elsif ($line =~ /.*user .*system (.*)elapsed .*CPU \(.*avgtext+.*avgdata (.*)maxresident\)k/) {
		$timecmd=$1;
		$tmem=$2;
		if ($timecmd =~ /(\d+):(\d+)\.(\d+)/) {
		    $timecmd = 60000*$1 + $2*1000 + $3;
		}
	    } else {
	#	print "nomatch: $line\n";
	    }
	}
	if ($of==1) {
	    $status .= "_OF";
	}
	close IN;
	print "$model,$tool,$cardp,$cardt,$carda,$ptime,$ttime,$constp,$nbp,$nbt,$tottime,$timecmd,$tmem,$status\n";
    }
}   

@files = <*tina>;
#print "working on files : @files";
foreach my $file (@files) {
    if ( $file =~ /\.tina$/ ) {	
	#print "looking at file : $file";
	my $model=$file;
	$model =~ s/\.tina//g ;
	my $tool="tina";
	my $status="UNK";
	my $ptime=-1, my $ttime=-1, my $constp=0, my $nbp=-1, my $nbt=-1, my $tottime=-1, my $tmem=-1;
	my $timecmd=-1;
	my $colp=-1,my $colt=-1;
	my $cardp=-1,my $cardt=-1,my$carda=-1;
	open IN, "< $file";
	my $of=0;
	while (my $line=<IN>) {
	    chomp $line;
	    if ($line =~ /(\d+) places, (\d+) transitions, (\d+) arcs/) {
		$cardp=$1;
		$cardt=$2;
		$carda=$3;
		# $parsetime=$4;
	    } elsif ($line =~ /(\d+) flow\(s\)/) {
		if ($nbp == -1) {
		    $nbp=$1;
		} else {
		    $nbt=$1;
		}
	    } elsif ($line =~ /no flow\(s\)/) {
		if ($nbp == -1) {
		    $nbp=0;
		} else {
		    $nbt=0;
		}
  	    } elsif ($line =~ /^(\d+\.\d+)s$/) {
		if ($nbp == -1) {
		    next;
		} elsif ($nbp != -1 && $nbt == -1) {
		    $ptime=$1*1000.0;
		} elsif ($nbp != -1 && $nbt != -1) {
		    $ttime=$1*1000.0;
		    $status="OK";
		}
		next;
	    } elsif ($line =~ /TIME LIMIT/) {
		$timecmd=120000;
		$status="TO";
		next;
	    } elsif ($line =~ /Command terminated by signal 9/) {
		$status="MOVF";
		next;
	    } elsif ($line =~ /overflow/) {
		# probably this :
		# unexpected failure (overflow ?), please retry with flag -mp
		$of = 1;
	    } elsif ($line =~ /Command exited with non-zero status/) {
		$status="MOVF";
		next;
	    } elsif ($line =~ /.*user .*system (.*)elapsed .*CPU \(.*avgtext+.*avgdata (.*)maxresident\)k/) {
		$timecmd=$1;
		$tmem=$2;
		if ($timecmd =~ /(\d+):(\d+)\.(\d+)/) {
		    $timecmd = 60000*$1 + $2*1000 + $3;
		}
	    } else {
	#	print "nomatch: $line\n";
	    }
	}
	if ($of==1) {
	    $status .= "_OF";
	}
	close IN;
	print "$model,$tool,$cardp,$cardt,$carda,$ptime,$ttime,$constp,$nbp,$nbt,$tottime,$timecmd,$tmem,$status\n";
    }
}   


@files = <*gspn>;
foreach my $file (@files) {
    my $model = $file;
    $model =~ s/\.gspn//g;
    my $tool = "GreatSPN";
    my $status = "UNK";
    my ($ptime, $ttime, $constp, $nbp, $nbt, $tottime, $timecmd, $tmem) = (-1, -1, 0, -1, -1, -1, -1, -1);
    my ($cardp, $cardt, $carda) = (-1, -1, -1);
    $carda = 0;  # The log does not provide arc information

    open my $fh, '<', $file or die "Could not open file '$file' $!";
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
        } elsif ($line =~ /TOTAL TIME: \[User (\d+\.\d+)s, Sys (\d+\.\d+)s\]/) {
            my $user_time = $1;
            my $sys_time = $2;
            if ($ptime == -1) {
                $ptime = ($user_time + $sys_time) * 1000.0;  # Convert to milliseconds
            } else {
                $ttime = ($user_time + $sys_time) * 1000.0;  # Convert to milliseconds
            }
        } elsif ($line =~ /(\d+\.\d+)user\s+(\d+\.\d+)system\s+(\d+):(\d+)\.(\d+)elapsed/) {
            my $user = $1;
            my $system = $2;
            my $minutes = $3;
            my $seconds = $4;
            my $fraction = $5;
            $timecmd = 60000 * $minutes + $seconds * 1000 + $fraction;  # Convert to milliseconds
        } 
        if ($line =~ /(\d+)maxresident\)k/) {
            $tmem = $1;
        }
    }
    close $fh;

    $tottime = $ptime + $ttime;  # Sum of PTime and TTime
    $status = "OK" if $ptime != -1 && $ttime != -1;

    print "$model,$tool,$cardp,$cardt,$carda,$ptime,$ttime,$constp,$nbp,$nbt,$tottime,$timecmd,$tmem,$status\n";
}
