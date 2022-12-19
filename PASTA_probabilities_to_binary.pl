#!/usr/bin/env perl

BEGIN
{
    push(@INC, (getpwnam('agalvez'))[7] . "/lib/perl");
}

use warnings;
use strict;

use GetOptions;

my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';
my $PHYLIP_OPTION = 'phylip';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $PHYLIP_OPTION => '!');

sub main 
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION})))
    {
	&help();
	exit;
    }

    open(INPUT, $args{$INPUT_OPTION}) || die "could not open file '$args{$INPUT_OPTION}' for read";
    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "could not open file '$args{$OUTPUT_OPTION}' for write";

    my ($number_species, $number_characters) = (0, 0);

    # read through the file to count the number of species and number of characters, then reset the file position
    # to the beginning
    my $current_number_characters = 0;
    
    if ($args{$PHYLIP_OPTION})
    {
	while (<INPUT>)
	{
	    if (not /^>/)
	    {
		chomp;
		
		my @probabilities = split(" ");

		my $number_characters_on_line = scalar(@probabilities);

		$current_number_characters += $number_characters_on_line;
	    }
	    else
	    {
		$number_species++;

		if ($current_number_characters)
		{
		    if (not $number_characters)
		    {
			$number_characters = $current_number_characters;
		    }
		    elsif ($number_characters != $current_number_characters)
		    {
			die "number of characters for species number $number_species ($current_number_characters) does " .
			    "not match number of characters from first species ($number_characters)";
		    }

		    $current_number_characters = 0;
		}
	    }
	}

	if ($number_characters != $current_number_characters)
	{
	    die "number of characters for species number $number_species ($current_number_characters) does " .
		"not match number of characters from first species ($number_characters)";
	}

	# intentionally leave off the "\n", as each new species will create a newline before printing
	print OUTPUT join(" ", ($number_species, $number_characters));

	# go back to the beginning of the input file
	seek(INPUT, 0, 0);
    }

    while (<INPUT>)
    {
	if (not /^>/)
	{
	    chomp;

	    my @probabilities = split(" ");

	    for (my $index = 0; $index < scalar(@probabilities); $index++)
	    {
		if ($probabilities[$index] > 0)
		{
		    $probabilities[$index] = 1;
		}
		else
		{
		    $probabilities[$index] = 0;
		}
	    }

	    if (not $args{$PHYLIP_OPTION})
	    {
		print OUTPUT join(" ", @probabilities) . "\n";
	    }
	    else
	    {
		print OUTPUT join("", @probabilities);
	    }
	}
	else
	{
	    if (not $args{$PHYLIP_OPTION})
	    {
		print OUTPUT $_;
	    }
	    else
	    {
		chomp;
		
		print OUTPUT "\n" . sprintf("%-10s", substr($_, 1, 10));
	    }
	}
    }

    if ($args{$PHYLIP_OPTION})
    {
	print OUTPUT "\n";
    }
    
    close INPUT || die "could not close file '$args{$INPUT_OPTION}' after read";
    close OUTPUT || die "could not close file '$args{$OUTPUT_OPTION}' after write";
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <PASTA> -$OUTPUT_OPTION <PASTA> [-$PHYLIP_OPTION]

Convert probabilities in a PASTA file to binary values (all non-zero values are changed to 1).
    
    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input .pasta file
    -$OUTPUT_OPTION : output .pasta file
    -$PHYLIP_OPTION : output strict PHYLIP format instead of PASTA format

HELP

    print STDERR $HELP;
}

&main();
