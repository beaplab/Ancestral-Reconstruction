#!/usr/bin/env perl

BEGIN
{
    push(@INC, (getpwnam('agalvez'))[7] . "/lib/perl");
}

use warnings;
use strict;

# core Perl modules
use IPC::Run;

# modules in this distribution
use GetOptions;

# names of command line options
my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';
my $INTERPROSCAN_OPTION = 'interproscan';
my $LIMIT_OPTION = 'limit';
my $FORCE_OPTION = 'force';
my $TEST_OPTION = 'test';

# types for command line options; see 'Getopt::Long' Perl documentation for information on option types
my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $INTERPROSCAN_OPTION => '=s',
		    $LIMIT_OPTION => '=i',
		    $FORCE_OPTION => '!',
		    $TEST_OPTION => '!');

my $DIRECTORY_DELIMITER = "/";

sub main
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION} && $args{$INTERPROSCAN_OPTION})))
    {
	&help();
	exit;
    }

    foreach my $argument ($INPUT_OPTION, $OUTPUT_OPTION)
    {
	if (not -d $args{$argument})
	{
	    die "'-$argument' must be a directory";
	}
    }
    
    if (not -x $args{$INTERPROSCAN_OPTION})
    {
	die "'-$INTERPROSCAN_OPTION' must be executable";
    }

    opendir(INPUT, $args{$INPUT_OPTION}) || die "could not open directory '$args{$INPUT_OPTION}' for read";
    
    my @input_file_names = readdir(INPUT);

    closedir INPUT || die "could not close directory '$args{$INPUT_OPTION}' after read";

    my $job_counter = 0;
    
    foreach my $input_file_name (sort @input_file_names)
    {
	if ($input_file_name !~ /(.*?)\.fasta$/)
	{
	    next;
	}

	my $file_base_name = $1;

	print STDOUT "--- $file_base_name ---\n";

	my $input_file_path = $args{$INPUT_OPTION} . $DIRECTORY_DELIMITER . $input_file_name;
	my $output_file_path = $args{$OUTPUT_OPTION} . $DIRECTORY_DELIMITER . $input_file_name . ".tsv";

	if (-e $output_file_path && (not -z $output_file_path))
	{
	    if (not $args{$FORCE_OPTION})
	    {
		print STDOUT "Skipping '$input_file_name', output file '$output_file_path' exists and is non-zero in size.\n";

		next;
	    }
	}

	# run InterProScan
	my @interproscan_command = ($args{$INTERPROSCAN_OPTION},
				    "--input", $input_file_path,
				    "--output-dir", $args{$OUTPUT_OPTION},
				    "--applications", "Pfam",
				    "--formats", "TSV",
				    "--cpu", "8",
				    "--disable-precalc");
 
	my $interproscan_command = join(" ", @interproscan_command);
	
	print STDOUT "$interproscan_command\n";
	
	if (not $args{$TEST_OPTION})
	{
	    &IPC::Run::run(\@interproscan_command) || die "ERROR: could not run '$interproscan_command': $?";
	}

	$job_counter++;

	if ($args{$LIMIT_OPTION} && $job_counter == $args{$LIMIT_OPTION})
	{
	    last;
	}
    }
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <dir> -$OUTPUT_OPTION <dir> -$INTERPROSCAN_OPTION <interproscan.sh> [-$LIMIT_OPTION <int>] [-$FORCE_OPTION] [-$TEST_OPTION]

Run InterProScan to search Pfam domains in a directory of FASTA files.

    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input directory containing files ending in .fasta
    -$OUTPUT_OPTION : output directory for InterProScan results (ending in .tsv)
    -$INTERPROSCAN_OPTION : location of interproscan.sh executable
    -$LIMIT_OPTION : only run on this many input files
    -$FORCE_OPTION : re-run even if previous InterProScan output exists (otherwise skip)
    -$TEST_OPTION : do not launch commands or write files, only print what would have run
   
HELP

    print STDERR $HELP;
}

&main();
