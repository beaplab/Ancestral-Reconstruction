#!/usr/bin/env perl

use warnings;
use strict;

# in order to search for modules in the directory where this script is located
use File::Basename;
use Cwd;
use lib dirname (&Cwd::abs_path(__FILE__));

use File::Copy;

# modules in this distribution
use GetOptions;

# names of command line options
my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';
my $TEST_OPTION = 'test';

# types for command line options; see 'Getopt::Long' Perl documentation for information on option types
my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $TEST_OPTION => '!');

my $DIRECTORY_DELIMITER = "/";

my $DOLLOP_OUTFILE_NAME = "outfile";
my $OUTPUT_FILE_EXTENSION = ".dollop.out";

sub main
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION})))
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
    
    opendir(INPUT, $args{$INPUT_OPTION}) || die "could not open directory '$args{$INPUT_OPTION}' for read";
    
    my @input_directories = readdir(INPUT);

    closedir INPUT || die "could not close directory '$args{$INPUT_OPTION}' after read";

    my $directories_processed = 0;
    
    foreach my $input_directory (sort @input_directories)
    {
	if ($input_directory !~ /^binary_(sim\d+)_/)
	{
	    next;
	}

	my $simulation_name = $1;

	print STDOUT "--- $simulation_name ---\n";

	my $input_file_path = $args{$INPUT_OPTION} . $DIRECTORY_DELIMITER . $input_directory . $DIRECTORY_DELIMITER .
	    $DOLLOP_OUTFILE_NAME;
	my $output_file_path = $args{$OUTPUT_OPTION} . $DIRECTORY_DELIMITER . $simulation_name . $OUTPUT_FILE_EXTENSION;

	print STDOUT "cp $input_file_path $output_file_path\n";
	
	if (not $args{$TEST_OPTION})
	{
	    &File::Copy::copy($input_file_path, $output_file_path) || die "could not copy '$input_file_path' to " .
		"'$output_file_path'";
	}

	$directories_processed++;
    }

    print STDOUT "\n$directories_processed directories processed\n";
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <dir> -$OUTPUT_OPTION <dir>

Copy PHYLIP dollop output files from a set of input directories to a single output directory.

Files to be copied in the input directories are named: $DOLLOP_OUTFILE_NAME
New files will have the extension: $OUTPUT_FILE_EXTENSION

    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input directory containing subdirectories with dollop results
    -$OUTPUT_OPTION : output directory
    -$TEST_OPTION : do not copy files, only print what would have copied
   
HELP

    print STDERR $HELP;
}

&main();
