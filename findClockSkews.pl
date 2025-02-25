#!/usr/bin/perl
use strict;
use warnings;

my $log_dir = ".";  # Adjust to your directory or use ARGV
opendir(my $dh, $log_dir) or die "Cannot open $log_dir: $!\n";
my @log_files = grep { -f "$log_dir/$_" && !/\.(its|sol)$/ } readdir($dh);
closedir($dh);

foreach my $file (@log_files) {
    my $path = "$log_dir/$file";
    open(my $fh, '<', $path) or die "Cannot open $path: $!\n";
    while (my $line = <$fh>) {
        if ($line =~ /(\d+\.\d+)user (\d+\.\d+)system (\d+:-?\d+\.\d+|\d+\.\d+)elapsed/) {
            my ($user, $system, $elapsed_raw) = ($1, $2, $3);
            my $user_sys = $user + $system;  # Total CPU time in seconds

            # Convert elapsed to seconds
            my $elapsed;
            if ($elapsed_raw =~ /(\d+):(-?\d+\.\d+)/) {
                $elapsed = $1 * 60 + $2;  # Handle MM:SS.SS format, including negatives
	    } else {
                $elapsed = $elapsed_raw;  # Simple seconds format
	    }

            # Check for significant discrepancy
            if ($elapsed < 0 || $user_sys > $elapsed + 2) {
                print "Suspicious clock skew in $path:\n";
                print "  $line";
                print "  User+System: $user_sys s, Elapsed: $elapsed s\n";
	    }
	}
    }
    close($fh);
}
