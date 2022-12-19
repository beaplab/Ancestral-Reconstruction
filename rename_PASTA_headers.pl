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
my $NAMES_OPTION = 'names';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $NAMES_OPTION => '=s');

sub main 
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION} && $args{$NAMES_OPTION})))
    {
	&help();
	exit;
    }

    open(INPUT, $args{$INPUT_OPTION}) || die "could not open '$args{$INPUT_OPTION}' for read";
    open(NAMES, $args{$NAMES_OPTION}) || die "could not open '$args{$NAMES_OPTION}' for read";
    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "could not open '$args{$OUTPUT_OPTION} for write";

    my %names_to_replace = ();

    while (<NAMES>)
    {
	chomp;

	my ($current_name, $new_name) = split("\t");

	$names_to_replace{$current_name} = $new_name;
    }

    while (<INPUT>)
    {
	chomp;

	if (/^>(.*)/)
	{
	    my $current_name = $1;

	    if (not defined $names_to_replace{$current_name})
	    {
		die "ERROR: current name '$current_name' not present in '-$NAMES_OPTION'";
	    }

	    print OUTPUT ">" . $names_to_replace{$current_name} . "\n";
	}
	else
	{
	    print OUTPUT $_ . "\n";
	}
    }
    
    close INPUT || die "could not close '$args{$INPUT_OPTION}' after read";
    close NAMES || die "could not close '$args{$NAMES_OPTION}' after read";
    close OUTPUT || die "could not close '$args{$OUTPUT_OPTION}' after write";
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <PASTA> -$OUTPUT_OPTION <PASTA> [-$NAMES_OPTION <txt>]

Rename the headers of a PASTA file. The '-$NAMES_OPTION' file contains two columns. The first column is the current name, the second column is the new name.
    
    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input PASTA file
    -$OUTPUT_OPTION : output PASTA file
    -$NAMES_OPTION : tab-delimited text file with the current and new names

HELP

    print STDERR $HELP;

}

&main();
