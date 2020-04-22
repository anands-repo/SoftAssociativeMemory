#!/usr/bin/perl

my $commandSkeleton = "ncverilog -R +nclibdirname+/home/aramach4/sdm/INCA_libs +libext+.v+.sv +access+rcw";

my @frequencies = (8, 16, 24, 32, 34, 36, 38, 40, 48, 56, 64);

my $torqueFile;

open CMDFILE, ">/home/aramach4/sdm/torqueRuns/torqueCmd.sh";

foreach $frequency(@frequencies) {
    foreach (1 .. 64) { #Generate 64 jobs for each
        my $seed       = int rand (1000000);
        my $noiseSeed  = int rand (1000000);
        my $logName    = "/home/aramach4/sdm/torqueRuns/log_${frequency}_${seed}_${noiseSeed}.log";
        $torqueName    = "/home/aramach4/sdm/torqueRuns/torque_${frequency}_${seed}_${noiseSeed}.sh";
        $command = "$commandSkeleton +seed=$seed +frequency=$frequency +noise=$noiseSeed -log $logName";
        #open TORQUE, ">$torqueName";
        #print TORQUE "#!/usr/bin/bash\n\n";
        #print TORQUE "module load incisive/13.10\n\n";
        #print TORQUE "$command\n";
        print CMDFILE "$command\n";
        #close TORQUE;
    }
}

close CMDFILE;
