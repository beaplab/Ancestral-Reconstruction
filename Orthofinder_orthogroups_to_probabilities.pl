#!/usr/bin/env perl

# Modified Perl script to produce probabilities of species membership in Orthofinder clusters
# (original script processed OrthoMCL clusters)
#
# Gene family innovation, conservation and loss on the animal stem lineage
# Daniel J Richter, Parinaz Fozouni, Michael B Eisen, Nicole King
# https://doi.org/10.7554/eLife.34226

use warnings;
use strict;

use POSIX;
use Getopt::Long;

my $HELP_OPTION = 'help';
my $ORTHOGROUPS_OPTION = 'orthogroups';
my $BLAST_OPTION = 'blast';
my $IDS_OPTION = 'ids';
my $OUTPUT_OPTION = 'output';
my $TABLE_OPTION = 'table';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $ORTHOGROUPS_OPTION => '=s',
		    $BLAST_OPTION => '=s',
		    $IDS_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $TABLE_OPTION => '!');

my $DIRECTORY_DELIMITER = "/";

my $BLAST_RESULTS_QUERY_COLUMN = 0;
my $BLAST_RESULTS_SUBJECT_COLUMN = 1;
my $BLAST_RESULTS_E_VALUE_COLUMN = 10;

my $ORTHOFINDER_SEQUENCE_ID_DELIMITER = "_";
my $ORTHOFINDER_SEQUENCE_ID_NAME_DELIMITER = ":";
my $ORTHOFINDER_ORTHOGROUPS_SEQUENCE_NAME_DELIMITER = ", ";
my $ORTHOFINDER_BLAST_RESULT_FILE_PREFIX = "Blast";
# Orthofinder substitutes characters in the sequence name using the following Python code:
# accession = accession.replace(":", "_").replace(",", "_").replace("(", "_").replace(")", "_")
my $ORTHOFINDER_SEQUENCE_NAME_CHARACTERS_TO_REPLACE = ":,()";
my $ORTHOFINDER_SEQUENCE_NAME_SUBSTITUTE_CHARACTER = "_";

my $MINIMUM_LOG10_E_VALUE_MINUS_ONE = -316;

sub main 
{
    my %args = &get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$ORTHOGROUPS_OPTION} && $args{$BLAST_OPTION} && $args{$IDS_OPTION} && 
				     $args{$OUTPUT_OPTION})))
    {
	&help();
	exit;
    }

    open(IDS, $args{$IDS_OPTION}) || die "could not open '$args{$IDS_OPTION}' for read";
    open(ORTHOGROUPS, $args{$ORTHOGROUPS_OPTION}) || die "could not open '$args{$ORTHOGROUPS_OPTION}' for read";
    opendir(BLAST_DIRECTORY, $args{$BLAST_OPTION}) || die "could not open directory '$args{$BLAST_OPTION}' for read";
    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "could not open '$args{$OUTPUT_OPTION}' for write";

    # read in the file that matches Orthofinder IDs to sequence names
    my %sequence_names_to_orthofinder_ids = ();

    while (<IDS>)
    {
	chomp;

	my ($orthofinder_id, $sequence_name, undef) = split(" ");

	# remove trailing delimiter to retrieve the ID used in BLAST results
	$orthofinder_id =~ s/\Q$ORTHOFINDER_SEQUENCE_ID_NAME_DELIMITER\E//;

	# the species ID is the first part of the Orthofinder BLAST ID
	my ($species_id, undef) = split($ORTHOFINDER_SEQUENCE_ID_DELIMITER, $orthofinder_id);

	# substitute characters in sequence name using Orthofinder rules
	$sequence_name =~
	    s/[\Q$ORTHOFINDER_SEQUENCE_NAME_CHARACTERS_TO_REPLACE\E]/$ORTHOFINDER_SEQUENCE_NAME_SUBSTITUTE_CHARACTER/g;

	$sequence_names_to_orthofinder_ids{$species_id}->{$sequence_name} = $orthofinder_id;
    }

    close IDS;

    # read in the contents of each orthogroup (which are listed using sequence names)
    my $orthogroups_header = <ORTHOGROUPS>;

    # for some unknown reason, some orthogroups files seem to use DOS newlines instead of UNIX newlines (even
    # when they were produced on a UNIX system)
    my $orthogroups_uses_DOS_newline = 0;
    
    if ($orthogroups_header =~ /\r\n$/)
    {
	$orthogroups_uses_DOS_newline = 1;

	$orthogroups_header =~ s/\r\n$//;
    }
    else
    {
	chomp $orthogroups_header;
    }

    # the species names are in order, starting at the second column, so species ID 0 will be the first one listed,
    # then species ID 1, etc.
    my (undef, @species_names) = split("\t", $orthogroups_header);

    my @orthogroup_names = ();
    my %orthogroup_sizes = ();
    my %orthofinder_ids_to_orthogroup_names = ();

    while (<ORTHOGROUPS>)
    {
	if ($orthogroups_uses_DOS_newline)
	{
	    s/\r\n$//;
	}
	else
	{
	    chomp;
	}

	my ($orthogroup_name, @sequence_names_by_species) = split("\t");

	# add this group to the list of orthogroup names, in order
	push(@orthogroup_names, $orthogroup_name);

	# initialize the size of this group to zero (then increment it for each new sequence)
	$orthogroup_sizes{$orthogroup_name} = 0;
	
	for (my $species_id = 0; $species_id < scalar(@sequence_names_by_species); $species_id++)
	{
	    # skip empty entries (there are no sequences in the orthogroup for this species)
	    if (length($sequence_names_by_species[$species_id]))
	    {
		# iterate through sequence names in the orthogroup for this species
		foreach my $sequence_name (split($ORTHOFINDER_ORTHOGROUPS_SEQUENCE_NAME_DELIMITER,
						 $sequence_names_by_species[$species_id]))
		{
		    my $orthofinder_id = $sequence_names_to_orthofinder_ids{$species_id}->{$sequence_name};
		    
		    if (not defined $orthofinder_id)
		    {
			die "Orthofinder ID for sequence '$sequence_name' in species $species_id ($species_names[$species_id]) " .
			    "not defined in '-$IDS_OPTION'";
		    }
		    
		    $orthofinder_ids_to_orthogroup_names{$orthofinder_id} = $orthogroup_name;
		    
		    $orthogroup_sizes{$orthogroup_name}++;
		}
	    }
	}
    }
    
    close ORTHOGROUPS;

    # verify that there are no orthogroups of size 1 (singletons)
    foreach my $orthogroup_name (@orthogroup_names)
    {
	if ($orthogroup_sizes{$orthogroup_name} < 2)
	{
	    die "Orthogroup '$orthogroup_name' contains only $orthogroup_sizes{$orthogroup_name} sequences; minimum size is 2";
	}
    }

    # read through the E values, recording hits to sequences within orthogroups and building a distribution
    my %e_value_distribution = ();
    my $total_e_value_count = 0;
    
    my %within_orthogroup_e_values = ();

    my $max_log10_e_value;
    
    foreach my $file_name (readdir(BLAST_DIRECTORY))
    {
	if ($file_name !~ /^$ORTHOFINDER_BLAST_RESULT_FILE_PREFIX/o)
	{
	    next;
	}

	my $blast_results_path = $args{$BLAST_OPTION} . $DIRECTORY_DELIMITER . $file_name;

	if ($file_name =~ /\.gz$/)
	{
	    open(INPUT, "gunzip -c $blast_results_path |") || die "could not open gzipped file '$blast_results_path' for read";
	}
	else
	{
	    open(INPUT, $blast_results_path) || die "could not open file '$blast_results_path' for read";
	}

	my ($previous_query_id, $previous_subject_id, $minimum_e_value_for_pair) = ("", "", undef);

	while (<INPUT>)
	{
	    my @columns = split("\t");
	    

	    # adding 0 to the E value forces it to be interpreted as a number, not a string
	    my ($query_orthofinder_id, $subject_orthofinder_id, $e_value) = ($columns[$BLAST_RESULTS_QUERY_COLUMN],
									     $columns[$BLAST_RESULTS_SUBJECT_COLUMN],
									     $columns[$BLAST_RESULTS_E_VALUE_COLUMN] + 0);

	    # do not allow self-hits
	    if ($query_orthofinder_id eq $subject_orthofinder_id)
	    {
		next;
	    }
	    
	    my $log10_e_value;
	    
	    # each bin in the distribution is the floor of the log base 10 E value
	    if ($e_value == 0)
	    {
		$log10_e_value = $MINIMUM_LOG10_E_VALUE_MINUS_ONE;
	    }
	    else
	    {
		$log10_e_value = &POSIX::floor(log($e_value) / log(10));
	    }
	    
	    # use all E values for building the overall distribution
	    if (not defined $e_value_distribution{$log10_e_value})
	    {
		$e_value_distribution{$log10_e_value} = 1;
	    }
	    else
	    {
		$e_value_distribution{$log10_e_value}++;
	    }

	    $total_e_value_count++;

	    if ((not defined $max_log10_e_value) || $log10_e_value > $max_log10_e_value)
	    {
		$max_log10_e_value = $log10_e_value;
	    }

	    # use only the best hit between a pair of sequences for recording E values within orthogroups;
	    # if this line contains a new pair, record the E value for the previous pair (unless this is the
	    # first line of the file, in which case the E value is undefined)
	    if ($query_orthofinder_id ne $previous_query_id && $subject_orthofinder_id ne $previous_subject_id)
	    {
		if (defined $minimum_e_value_for_pair)
		{
		    my $query_orthogroup_name = $orthofinder_ids_to_orthogroup_names{$previous_query_id};
		    my $subject_orthogroup_name = $orthofinder_ids_to_orthogroup_names{$previous_subject_id};
		    
		    # record E value for hits between pairs of sequences within the same orthogroup
		    if (defined $query_orthogroup_name && defined $subject_orthogroup_name &&
			$query_orthogroup_name eq $subject_orthogroup_name)
		    {
			# the species ID is the first part of the Orthofinder BLAST ID
			my ($query_species_id, $query_sequence_id) = split($ORTHOFINDER_SEQUENCE_ID_DELIMITER, $previous_query_id);
			
			my $query_species_name = $species_names[$query_species_id];
			
			if (not defined
			    $within_orthogroup_e_values{$query_orthogroup_name}->{$query_species_name}->{$query_sequence_id})
			{
			    $within_orthogroup_e_values{$query_orthogroup_name}->{$query_species_name}->{$query_sequence_id} = 0;
			}

			# keep a sum of E values within the orthogroup; later, we divide by orthogroup size to obtain
			# the average
			$within_orthogroup_e_values{$query_orthogroup_name}->{$query_species_name}->{$query_sequence_id} +=
			    $minimum_e_value_for_pair;
		    }
		}

		$previous_query_id = $query_orthofinder_id;
		$previous_subject_id = $subject_orthofinder_id;
		$minimum_e_value_for_pair = $log10_e_value;
	    }
	    # otherwise update the minimum E value for this pair (if this value is lower)
	    else
	    {
		if ($log10_e_value < $minimum_e_value_for_pair)
		{
		    $minimum_e_value_for_pair = $log10_e_value;
		}
	    }
	}

	close INPUT || die "could not close file '$blast_results_path' after read";

	# record the E value for the last pair
	my $query_orthogroup_name = $orthofinder_ids_to_orthogroup_names{$previous_query_id};
	my $subject_orthogroup_name = $orthofinder_ids_to_orthogroup_names{$previous_subject_id};
	
	# record E value for hits between pairs of sequences within the same orthogroup
	if (defined $query_orthogroup_name && defined $subject_orthogroup_name &&
	    $query_orthogroup_name eq $subject_orthogroup_name)
	{
	    # the species ID is the first part of the Orthofinder BLAST ID
	    my ($query_species_id, $query_sequence_id) = split($ORTHOFINDER_SEQUENCE_ID_DELIMITER, $previous_query_id);
	    
	    my $query_species_name = $species_names[$query_species_id];
	    
	    if (not defined
		$within_orthogroup_e_values{$query_orthogroup_name}->{$query_species_name}->{$query_sequence_id})
	    {
		$within_orthogroup_e_values{$query_orthogroup_name}->{$query_species_name}->{$query_sequence_id} = 0;
	    }
	    
	    # keep a sum of E values within the orthogroup; later, we divide by orthogroup size to obtain
	    # the average
	    $within_orthogroup_e_values{$query_orthogroup_name}->{$query_species_name}->{$query_sequence_id} +=
		$minimum_e_value_for_pair;
	}
    }

    closedir BLAST_DIRECTORY;

    # normalize e values using the empirical cumulative distribution function
    my %normalized_e_values = ();

    my $cumulative_e_value_count = 0;

    for (my $index = $max_log10_e_value; $index >= $MINIMUM_LOG10_E_VALUE_MINUS_ONE; $index--)
    {
	# calculate probability after adding this index, so that final probability is 1
	$cumulative_e_value_count += $e_value_distribution{$index} || 0;

	$normalized_e_values{$index} = $cumulative_e_value_count / $total_e_value_count;
    }

    # print out probabilities by calculating the average E value of each protein to all others within its orthogroup
    # and then looking up that value in the cumulative distribution
    if ($args{$TABLE_OPTION})
    {
	print OUTPUT join("\t", ("Orthogroup_Name", "Species", "Orthogroup_Size", "Probability")) . "\n";
    }
    
    foreach my $species_name (@species_names)
    {
	if (not $args{$TABLE_OPTION})
	{
	    print OUTPUT ">" . $species_name . "\n";
	}

	my $first_character = 1;

	foreach my $orthogroup_name (@orthogroup_names)
	{
	    my $output_probability = 0;

	    # if the species has at least one sequence in this orthogroup, calculate its probability based on average E value
	    if (defined $within_orthogroup_e_values{$orthogroup_name}->{$species_name})
	    {
		# find the single representative gene for each species within the cluster with the lowest average e value
		# to all other genes in the cluster
		foreach my $sequence_id (keys %{$within_orthogroup_e_values{$orthogroup_name}->{$species_name}})
		{
		    my $average_e_value = $within_orthogroup_e_values{$orthogroup_name}->{$species_name}->{$sequence_id} /
			($orthogroup_sizes{$orthogroup_name} - 1);

		    # interpolate linearly between the E value bin above and the one below
		    my $e_value_above = &POSIX::floor($average_e_value);
		    my $e_value_below = &POSIX::ceil($average_e_value);

		    my $distance_ratio_to_bin_above = $e_value_below - $average_e_value;
		    my $difference_between_bins = $normalized_e_values{$e_value_above} - $normalized_e_values{$e_value_below};
		    
		    # rescale to a value between 0 and 1
		    my $probability = $normalized_e_values{$e_value_below} +
			($distance_ratio_to_bin_above * $difference_between_bins);
		    
		    if ($probability > $output_probability)
		    {
			$output_probability = $probability;
		    }
		}
	    }
	    
	    if (not $args{$TABLE_OPTION})
	    {
		if ($first_character)
		{
		    $first_character = 0;
		}
		else
		{
		    print OUTPUT " ";
		}
		
		print OUTPUT sprintf("%.10f", $output_probability);
	    }
	    else
	    {
		print OUTPUT join("\t", ($orthogroup_name, $species_name, $orthogroup_sizes{$orthogroup_name},
					 sprintf("%.10f", $output_probability))) . "\n";
	    }
	}
	
	if (not $args{$TABLE_OPTION})
	{
	    print OUTPUT "\n";
	}
    }

    close OUTPUT;
}

sub get_options
{
    my %option_types = %{shift @_};

    my %getopt_hash;
    my @getopt_list;
    my %arguments;
    
    foreach my $option (keys %option_types)
    {
	$getopt_hash{$option} = \$arguments{$option};
	push(@getopt_list, $option . $option_types{$option});
    }
    
    &Getopt::Long::GetOptions(\%getopt_hash, @getopt_list);
    
    return %arguments;
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$ORTHOGROUPS_OPTION <tsv> -$BLAST_OPTION <dir> -$IDS_OPTION <txt> -$OUTPUT_OPTION <PASTA or txt> [-$TABLE_OPTION]

Parse Orthofinder orthogroups, sequence IDs and a directory of BLAST/DIAMOND results to
produce presence probabilities for each species in each cluster using the empirical
cumulative E value distribution.

Output probabilities in PASTA format: one record per species, beginning with ">" (as for
a FASTA file), then space-delimited probabilities, one per orthogroup, in order.

Constant representing one log(10) smaller than the minimum possible E value: $MINIMUM_LOG10_E_VALUE_MINUS_ONE

Orthofinder-specific constants:
Delimiter within sequence IDs (from BLAST results files): "$ORTHOFINDER_SEQUENCE_ID_DELIMITER"
Delimiter between sequence IDs and sequence names in '-$IDS_OPTION' file: "$ORTHOFINDER_SEQUENCE_ID_NAME_DELIMITER"
Delimiter between sequence names in '-$ORTHOGROUPS_OPTION': "$ORTHOFINDER_ORTHOGROUPS_SEQUENCE_NAME_DELIMITER"
Prefix of BLAST results file names: "$ORTHOFINDER_BLAST_RESULT_FILE_PREFIX"
Within sequence names in '-$IDS_OPTION' file, replace "$ORTHOFINDER_SEQUENCE_NAME_CHARACTERS_TO_REPLACE" characters with "$ORTHOFINDER_SEQUENCE_NAME_SUBSTITUTE_CHARACTER"

BLAST results columns (0-based):
Query: $BLAST_RESULTS_QUERY_COLUMN
Subject: $BLAST_RESULTS_SUBJECT_COLUMN
E value: $BLAST_RESULTS_E_VALUE_COLUMN
 
    -$HELP_OPTION : print this message
    -$ORTHOGROUPS_OPTION : Orthofinder output file with the genes in each cluster ("Orthogroups/
                   Orthogroups.tsv")
    -$BLAST_OPTION : directory of Orthofinder BLAST/DIAMOND results ("WorkingDirectory")
    -$IDS_OPTION : Orthofinder file mapping gene IDs used in '-$BLAST_OPTION' to corresponding IDs used
           in '-$ORTHOGROUPS_OPTION' ("WorkingDirectory/SequenceIDs.txt")
    -$OUTPUT_OPTION : output probabilities in PASTA format
    -$TABLE_OPTION : instead of producing output probabilities in PASTA format, output in table
             format
		    
HELP

    print STDERR $HELP;

}

&main();

