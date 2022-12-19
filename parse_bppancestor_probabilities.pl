#!/usr/bin/env perl

# in order to search for modules in the directory where this script is located
use File::Basename;
use Cwd;
use lib dirname (&Cwd::abs_path(__FILE__));

#BEGIN
#{
#    push(@INC, (getpwnam('drichter'))[7] . "/lib/perl");
#}

use warnings;
use strict;

use POSIX;

use Table;
use GetOptions;

my $HELP_OPTION = 'help';
my $BPP_OPTION = 'bpp';
my $PASTA_OPTION = 'pasta';
my $DISTRIBUTION_OPTION = 'distribution';
my $OUTPUT_OPTION = 'output';
my $CHANGES_OPTION = 'changes';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $BPP_OPTION => '=s',
		    $PASTA_OPTION => '=s',
		    $DISTRIBUTION_OPTION => '=f',
		    $OUTPUT_OPTION => '=s',
		    $CHANGES_OPTION => '=s');

my $NODE_COLUMN = "Node";
my $PARENT_COLUMN = "Parent";

sub main 
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not (($args{$BPP_OPTION} || $args{$PASTA_OPTION}) && $args{$OUTPUT_OPTION})))
    {
	&help();
	exit;
    }

    if ((not $args{$DISTRIBUTION_OPTION}) && (not $args{$BPP_OPTION}))
    {
	die "if '-$DISTRIBUTION_OPTION' is not specified, then output of bppancestor must be specified in '-$BPP_OPTION'";
    }

    if ($args{$PASTA_OPTION} && (not $args{$DISTRIBUTION_OPTION}))
    {
	die "'-$PASTA_OPTION' should only be used with '-$DISTRIBUTION_OPTION'";
    }

    my %nodes_for_gain_and_loss = ();
    
    if ($args{$CHANGES_OPTION})
    {
	open(CHANGES, $args{$CHANGES_OPTION}) || die "ERROR: could not open file '$args{$CHANGES_OPTION}' for read";

	my $changes_header = <CHANGES>;
	
	my %changes_column_headers = &Table::get_column_header_indices([$NODE_COLUMN, $PARENT_COLUMN],
								       $changes_header);
	
	my $row_count = 1;
	
	while (<CHANGES>)
	{
	    chomp;
	    
	    $row_count++;
	    
	    my @columns = split("\t");
	    
	    my ($node_id, $parent_id) = ($columns[$changes_column_headers{$NODE_COLUMN}],
					 $columns[$changes_column_headers{$PARENT_COLUMN}]);
	    
	    if (not (defined $node_id && defined $parent_id))
	    {
		die "ERROR: row $row_count missing data";
	    }
	    
	    $nodes_for_gain_and_loss{$node_id} = $parent_id;
	}

	close CHANGES || die "ERROR: could not open file '$args{$CHANGES_OPTION}' for read";
    }
    
    my %sums_by_node = ();
    my %gains_by_node = ();
    my %losses_by_node = ();
    my %distribution_by_node = ();
    
    if ($args{$BPP_OPTION})
    {
	open(INPUT, $args{$BPP_OPTION}) || die "could not open '$args{$BPP_OPTION}' for input";
    
	my $header = <INPUT>;
	
	chomp $header;
	
	my @header_columns = split("\t", $header);
	
	my %columns_to_parse = ();
	
	for (my $index = 0; $index < scalar(@header_columns); $index++)
	{
	    if ($header_columns[$index] =~ /prob\.(\d+)\.([01])/)
	    {
		my ($node, $state) = ($1, $2);
		
		$columns_to_parse{$node}->{$state} = $index;
	    }
	}
	
	while (<INPUT>)
	{
	    chomp;
	    
	    my @data_columns = split("\t");
	    
	    foreach my $node (keys %columns_to_parse)
	    {
		foreach my $state (0, 1)
		{
		    my $probability = $data_columns[$columns_to_parse{$node}->{$state}];
		    
		    if (not defined $probability)
		    {
			die "column $columns_to_parse{$node}->{$state} not defined for node $node state $state";
		    }
		    
		    if (not defined $sums_by_node{$node}->{$state})
		    {
			$sums_by_node{$node}->{$state} = $probability;
		    }
		    else
		    {
			$sums_by_node{$node}->{$state} += $probability;
		    }
		    
		    if ($state == 1)
		    {
			if ($args{$DISTRIBUTION_OPTION})
			{
			    my $bin = &POSIX::floor($probability / $args{$DISTRIBUTION_OPTION});
			    
			    if (not defined $distribution_by_node{$node}->{$bin})
			    {
				$distribution_by_node{$node}->{$bin} = 1;
			    }
			    else
			    {
				$distribution_by_node{$node}->{$bin}++;
			    }
			}
		    }
		}

		if (defined $nodes_for_gain_and_loss{$node})
		{
		    if (not defined $gains_by_node{$node})
		    {
			$gains_by_node{$node} = 0;
			$losses_by_node{$node} = 0;
		    }
		
		    my $from_presence_probability = $data_columns[$columns_to_parse{$nodes_for_gain_and_loss{$node}}->{1}];
		    my $to_presence_probability = $data_columns[$columns_to_parse{$node}->{1}];
	    
		    if ($from_presence_probability > $to_presence_probability)
		    {
			$losses_by_node{$node} += $from_presence_probability - $to_presence_probability;
		    }
		    elsif ($to_presence_probability > $from_presence_probability)
		    {
			$gains_by_node{$node} += $to_presence_probability - $from_presence_probability;
		    }
		}
	    }
	}
	
	close INPUT;
    }

    if ($args{$PASTA_OPTION})
    {
	open(PASTA, $args{$PASTA_OPTION}) || die "could not open '$args{$PASTA_OPTION}' for read";
	
	my $node = "";
	
	while (<PASTA>)
	{
	    chomp;
	    
	    if (/^>(.*)/)
	    {
		$node = $1;
	    }
	    else
	    {
		foreach my $probability (split(/\s+/))
		{
		    my $bin = &POSIX::floor($probability / $args{$DISTRIBUTION_OPTION});
		    
		    if (not defined $distribution_by_node{$node}->{$bin})
		    {
			$distribution_by_node{$node}->{$bin} = 1;
		    }
		    else
		    {
			$distribution_by_node{$node}->{$bin}++;
		    }
		}
	    }
	}
	
	close PASTA;
    }

    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "could not open '$args{$OUTPUT_OPTION}' for write";

    if (not $args{$DISTRIBUTION_OPTION})
    {
	print OUTPUT join("\t", ("Node", "Absent", "Present", "Gained", "Lost")) . "\n";
	
	foreach my $node (sort { $a <=> $b } keys %sums_by_node)
	{
	    print OUTPUT join("\t", ($node, $sums_by_node{$node}->{0}, $sums_by_node{$node}->{1},
				     $gains_by_node{$node} || "", $losses_by_node{$node} || "")) . "\n";
	}
    }
    else
    {
	my @sorted_nodes = sort { $a <=> $b } keys %distribution_by_node;
	
	print OUTPUT join("\t", ("bin", "all", @sorted_nodes)) . "\n";
	
	for (my $bin = 0; $bin <= 1 / $args{$DISTRIBUTION_OPTION}; $bin++)
	{
	    print OUTPUT $bin * $args{$DISTRIBUTION_OPTION};

	    my $count_in_bin = 0;
	    my $output_string = "";
	    
	    foreach my $node (@sorted_nodes)
	    {
		if (defined $distribution_by_node{$node}->{$bin})
		{
		    $output_string .= "\t" . $distribution_by_node{$node}->{$bin};
		    $count_in_bin += $distribution_by_node{$node}->{$bin};
		}
		else
		{
		    $output_string .= "\t0";
		}
	    }
	    
	    print OUTPUT "\t" . $count_in_bin . $output_string . "\n";
	}
    }

    close OUTPUT;
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 (-$BPP_OPTION <sites> and\/or -$PASTA_OPTION <pasta>) -$OUTPUT_OPTION <txt> [-$DISTRIBUTION_OPTION <float>] [-$CHANGES_OPTION <txt>]

Read input of bppancestor and summarize number of ancestral genes
present at each node.

If '-$DISTRIBUTION_OPTION' is specified, can read either output sites
file, input pasta file, or both at once. Artificial output node 'all'
is the sum of all other nodes.

Columns of optional '-$CHANGES_OPTION' file: $NODE_COLUMN, $PARENT_COLUMN

    -$HELP_OPTION : print this message
    -$BPP_OPTION : output of bppancestor (.sites file)
    -$PASTA_OPTION : input pasta-formatted probabilities file (used only with
             '-$DISTRIBUTION_OPTION')
    -$OUTPUT_OPTION : output text file
    -$DISTRIBUTION_OPTION : instead of producing a summary of ancestral gene content,
                    print a distribution of probabilities using the specified bin
                    size
    -$CHANGES_OPTION : optional tab-delimited file containing nodes for which to print changes
               in probability (gains/losses)
		    
HELP

    print STDERR $HELP;

}

&main();


