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

use GetOptions;
use Table;

my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';
my $POLYTOMIES_OPTION = 'polytomies';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $POLYTOMIES_OPTION => '=s');

my $CHARACTERS_BEFORE_STATES = length("root     56         yes    ");

my $POLYTOMY_PARENT_ID_COLUMN = "ID";
my $POLYTOMY_CHILDREN_ID_COLUMN = "Descendants";

sub main 
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION})))
    {
	&help();
	exit;
    }

    open(INPUT, $args{$INPUT_OPTION}) || die "could not open '$args{$INPUT_OPTION}' for read";
    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "could not open '$args{$OUTPUT_OPTION}' for write";

    my $reading = 0;
    
    my %states = ();
    
    # keep track of node_from and node_to
    my %transitions = ();
    
    my ($node_from, $node_to, $current_state_index) = ("", "", 0);

    while (<INPUT>)
    {
	if (/^root/)
	{
	    $reading = 1;
	}
	
	if (not $reading)
	{
	    next;
	}
	
	chomp;
	
	if (not length($_))
	{
	    next;
	}
	
	my $before_states = substr($_, 0, $CHARACTERS_BEFORE_STATES);

	$before_states =~ s/^\s+//g;
	
	my @columns_before_states = split(/\s+/, $before_states);
	
	if (scalar(@columns_before_states))
	{
	    $node_from = $columns_before_states[0];
	    $node_to = $columns_before_states[1];

	    $transitions{$node_from}->{$node_to} = 1;
	    
	    $current_state_index = 0;
	}
	
	my $states = substr($_, $CHARACTERS_BEFORE_STATES);
	
	$states =~ s/ //g;
	
	my @states = split("", $states);
	
	if ($node_from eq "root")
	{
	    for (my $index = 0; $index < scalar(@states); $index++)
	    {
		$states{$node_from}->[$current_state_index + $index] = 0;
	    }
	}
	
	for (my $index = 0; $index < scalar(@states); $index++)
	{
	    # the child (node_to) inherits its state from the parent (node_from)
	    $states{$node_to}->[$current_state_index + $index] = $states{$node_from}->[$current_state_index + $index];

	    # only update the state if it changes from the parent to the child (if it does not change, it will be a ".")
	    if ($states[$index] eq "1" || $states[$index] eq "0")
	    {
		$states{$node_to}->[$current_state_index + $index] = $states[$index];
	    }
	}
	
#	print "from $node_from to $node_to state " . join("", @{$states{$node_to}}) . " at index $current_state\n";
	
	$current_state_index += scalar(@states);
	
	undef @columns_before_states;
	undef @states;
    }

    # if there are polytomies, update the states appropriately
    if ($args{$POLYTOMIES_OPTION})
    {
	open(POLYTOMIES, $args{$POLYTOMIES_OPTION}) || die "ERROR: could not open file '$args{$POLYTOMIES_OPTION}' for read";

	my $polytomies_header = <POLYTOMIES>;
	
	my %polytomies_column_headers = &Table::get_column_header_indices([$POLYTOMY_PARENT_ID_COLUMN,
									   $POLYTOMY_CHILDREN_ID_COLUMN],
									  $polytomies_header);
	
	my $row_count = 1;
	
	while (<POLYTOMIES>)
	{
	    chomp;
	    
	    $row_count++;
	    
	    my @columns = split("\t");
	    
	    my ($parent_id, $children_ids) = ($columns[$polytomies_column_headers{$POLYTOMY_PARENT_ID_COLUMN}],
					      $columns[$polytomies_column_headers{$POLYTOMY_CHILDREN_ID_COLUMN}]);
	    
	    if (not (defined $parent_id && defined $children_ids))
	    {
		die "ERROR: row $row_count missing data";
	    }

	    my @children_ids = split(",", $children_ids);

	    foreach my $node_id ($parent_id, @children_ids)
	    {
		if (not defined $states{$node_id})
		{
		    die "ERROR: in polytomies, node id '$node_id' does not have states defined in input file";
		}
	    }
	    
	    for (my $index = 0; $index < scalar(@{$states{$parent_id}}); $index++)
	    {
#		if ($parent_id eq "1")
#		{
#		    my @child_states = ();
#		    
#		    foreach my $child_id (@children_ids)
#		    {
#			push(@child_states, $states{$child_id}->[$index]);
#		    }
#
#		    print join("\t", ($states{$parent_id}->[$index], join(",", (@child_states))));
#		}
		
		# if the parent node does not have a gene present, update it to present if two or more children
		# within the polytomy have the gene present
		if ($states{$parent_id}->[$index] == 0)
		{
		    my $children_present = 0;
		    
		    foreach my $child_id (@children_ids)
		    {
			$children_present += $states{$child_id}->[$index];
		    }
		    
		    if ($children_present >= 2)
		    {
			$states{$parent_id}->[$index] = 1;

#			if ($parent_id eq "1")
#			{
#			    print " *";
#			}
		    }
		}

#		if ($parent_id eq "1")
#		{
#		    print "\n";
#		}
	    }
	}

	close POLYTOMIES || die "ERROR: could not close file '$args{$POLYTOMIES_OPTION}' after read";
    }

    # iterate through each parent/child pair, counting present/gained/lost at each node
    my %present = ();
    my %lost = ();
    my %gained = ();

    foreach my $node_from (keys %transitions)
    {
	foreach my $node_to (keys %{$transitions{$node_from}})
	{
	    $present{$node_to} = 0;
	    $gained{$node_to} = 0;
	    $lost{$node_to} = 0;
	    
	    for (my $index = 0; $index < scalar(@{$states{$node_from}}); $index++)
	    {
		$present{$node_to} += $states{$node_to}->[$index];
		
		if ($states{$node_from}->[$index] eq "0" && $states{$node_to}->[$index] eq "1")
		{
		    $gained{$node_to}++;
		}
		elsif ($states{$node_from}->[$index] eq "1" && $states{$node_to}->[$index] eq "0")
		{
		    $lost{$node_to}++;
		}
		
	    }
	}
    }
    
    print OUTPUT join("\t", ("Node", "Present", "Gained", "Lost")) . "\n";
	
    foreach my $node (sort keys %present)
    {
	print OUTPUT join("\t", ($node, $present{$node}, $gained{$node}, $lost{$node})) . "\n";
    }
    
    close OUTPUT;
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <dollop> -$OUTPUT_OPTION <txt> [-$POLYTOMIES_OPTION <txt>]

Parse the output of dollop from the Phylip package to count the number
of genes at each inferred ancestral node.

Columns for optional '-$POLYTOMIES_OPTION': $POLYTOMY_PARENT_ID_COLUMN, $POLYTOMY_CHILDREN_ID_COLUMN (child IDs delimited by comma)

Parent nodes in the optional '-$POLYTOMIES_OPTION' file must be listed
in order, from leaves to root. Otherwise, if one polytomy is a direct
descendant of another, the parent polytomy will not be treated
appropriately.

    -$HELP_OPTION : print this message
    -$INPUT_OPTION : output of dollop
    -$OUTPUT_OPTION : text file
    -$POLYTOMIES_OPTION : optional list of polytomies that were artificially resolved for PHYLIP
 
HELP

    print STDERR $HELP;

}

&main();
