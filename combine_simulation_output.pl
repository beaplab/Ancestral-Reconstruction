#!/usr/bin/env perl

# in order to search for modules in the directory where this script is located
use File::Basename;
use Cwd;
use lib dirname (&Cwd::abs_path(__FILE__));

use warnings;
use strict;

use Table;
use GetOptions;

my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';
my $NAMES_OPTION = 'names';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $NAMES_OPTION => '=s');

my $NODE_COLUMN_NAME = "Node";
my $GENES_PRESENT_COLUMN_NAME = "Present";
my $GENES_GAINED_COLUMN_NAME = "Gained";
my $GENES_LOST_COLUMN_NAME = "Lost";
my $SIMULATION_COLUMN_NAME = "Sim";

my $DIRECTORY_DELIMITER = "/";

sub main 
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION})))
    {
	&help();
	exit;
    }

    open(INPUT, $args{$INPUT_OPTION}) || die "ERROR: could not open '$args{$INPUT_OPTION}' for read";
    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "ERROR: could not open '$args{$OUTPUT_OPTION} for write";

    my %substitute_node_names = ();
    
    if ($args{$NAMES_OPTION})
    {
	open(NAMES, $args{$NAMES_OPTION}) || die "ERROR: could not open '$args{$NAMES_OPTION}' for read";

	my $names_header = <NAMES>;

	while (<NAMES>)
	{
	    chomp;

	    my ($substitute_name, $name_in_file) = split("\t");

	    $substitute_node_names{$name_in_file} = $substitute_name;
	}

	close NAMES || die "ERROR: could not close '$args{$NAMES_OPTION}' after read";
    }

    opendir(INPUT_DIR, $args{$INPUT_OPTION}) || die "ERROR: could not open directory '$args{$INPUT_OPTION}' for read";

    my @input_file_names = readdir(INPUT_DIR);

    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "ERROR: could not open file '$args{$OUTPUT_OPTION}' for write";

    print OUTPUT join("\t", ($SIMULATION_COLUMN_NAME, $NODE_COLUMN_NAME, $GENES_PRESENT_COLUMN_NAME, $GENES_GAINED_COLUMN_NAME,
			     $GENES_LOST_COLUMN_NAME)) . "\n";

    my $simulations_processed = 0;
    
    foreach my $input_file_name (sort @input_file_names)
    {
	if ($input_file_name !~ /^sim/)
	{
	    next;
	}

	$simulations_processed++;
	
	my $input_file_path = $args{$INPUT_OPTION} . $DIRECTORY_DELIMITER . $input_file_name;

	open(INPUT, $input_file_path) || die "ERROR: could not open file '$input_file_path' for read";

	my $input_header = <INPUT>;
	
	my %input_column_headers = &Table::get_column_header_indices([$NODE_COLUMN_NAME, $GENES_PRESENT_COLUMN_NAME,
								      $GENES_GAINED_COLUMN_NAME, $GENES_LOST_COLUMN_NAME],
								     $input_header);

	my $row_count = 0;
	
	while (<INPUT>)
	{
	    chomp;

	    $row_count++;
	
	    my @columns = split("\t");
	    
	    my ($node_name, $genes_present, $genes_gained, $genes_lost) = 
		($columns[$input_column_headers{$NODE_COLUMN_NAME}],
		 $columns[$input_column_headers{$GENES_PRESENT_COLUMN_NAME}],
		 $columns[$input_column_headers{$GENES_GAINED_COLUMN_NAME}],
		 $columns[$input_column_headers{$GENES_LOST_COLUMN_NAME}]);
	
	    if (not (defined $node_name && defined $genes_present))
	    {
		die "ERROR: row $row_count missing data in input file '$input_file_name'";
	    }
	
	    my $output_node_name = $node_name;

	    if ($args{$NAMES_OPTION})
	    {
		$output_node_name = $substitute_node_names{$node_name};

		if (not defined $output_node_name)
		{
		    die "ERROR: no substitute node name specified for '$node_name'";
		}
	    }

	    print OUTPUT join("\t", ($input_file_name, $output_node_name, $genes_present, $genes_gained || "",
				     $genes_lost || "")) . "\n";
	}
	    
	close INPUT || die "ERROR: could not close file '$input_file_path' after read";
    }
	    
    close OUTPUT || die "ERROR: could not close file '$args{$OUTPUT_OPTION}' after write";

    print STDOUT "Processed $simulations_processed simulation(s)\n";
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <dir> -$OUTPUT_OPTION <txt> [-$NAMES_OPTION <txt>]

Go through a directory of dollop or bppancestor results for different
simulations and produce one output file summarizing results for all
simulations.

    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input directory
    -$OUTPUT_OPTION : output tab-delimited text file
    -$NAMES_OPTION : optional file to substitute node names in output (has header, first column
             is substitute name, second column is name in files)
    
HELP

    print STDERR $HELP;

}

&main();
