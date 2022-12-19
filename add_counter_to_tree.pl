#!/usr/bin/env perl

BEGIN
{
    push(@INC, (getpwnam('drichter'))[7] . "/lib/perl");
}

use warnings;
use strict;

use GetOptions;

my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';
my $NAMES_OPTION = 'names';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $NAMES_OPTION => '=s');

my $CHARACTERS_TO_COUNT = "__";

sub main 
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION})))
    {
	&help();
	exit;
    }

    open(INPUT, $args{$INPUT_OPTION}) || die "could not open '$args{$INPUT_OPTION}' for read";
    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "could not open '$args{$OUTPUT_OPTION} for write";

    if ($args{$NAMES_OPTION})
    {
	open(NAMES, ">", $args{$NAMES_OPTION}) || die "could not open '$args{$NAMES_OPTION}' for write";
    }
    
    while (<INPUT>)
    {
	chomp;

	my $counter = 0;

	my @input_tokens = split($CHARACTERS_TO_COUNT);

	print OUTPUT $input_tokens[0];

	for (my $index = 1; $index < scalar(@input_tokens); $index++)
	{
	    print OUTPUT join("_", ($counter, $input_tokens[$index]));

	    if ($args{$NAMES_OPTION})
	    {
		if ($input_tokens[$index] =~ /^(EP\d+[A-Za-z0-9_.-]+)/ || $input_tokens[$index] =~ /^(\d{5})/)
		{
		    print NAMES join("\t", ($1, join("_", ($counter, $1)))) . "\n";
		}
	    }

	    $counter++;
	}

	print OUTPUT "\n";
    }
    
    close INPUT || die "could not close '$args{$INPUT_OPTION}' after read";
    close OUTPUT || die "could not close '$args{$OUTPUT_OPTION}' after write";

    if ($args{$NAMES_OPTION})
    {
	close NAMES || die "could not close '$args{$NAMES_OPTION}' after write";
    }
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <tree> -$OUTPUT_OPTION <tree> [-$NAMES_OPTION <txt>]

Read a tree file, looking for characters matching "$CHARACTERS_TO_COUNT". Replace each instance with a counter, starting from zero.
    
    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input tree (Newick format)
    -$OUTPUT_OPTION : output tree (Newick format)
    -$NAMES_OPTION : optional tab-delimited text file with the previous and newly assigned names of nodes in the tree

HELP

    print STDERR $HELP;

}

&main();
