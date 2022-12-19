#!/usr/bin/env perl

BEGIN
{
    push(@INC, (getpwnam('drichter'))[7] . "/lib/perl");
}

use warnings;
use strict;

use POSIX;

use GetOptions;

my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';

my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s');

my $DIRECTORY_DELIMITER = "/";

sub main 
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION})))
    {
	&help();
	exit;
    }

    opendir(INPUT_DIR, $args{$INPUT_OPTION}) || die "could not open directory '$args{$INPUT_OPTION}' for read";
    open(OUTPUT, ">", $args{$OUTPUT_OPTION}) || die "could not open '$args{$OUTPUT_OPTION} for write";

    my %domains_by_species = ();
    my %all_domains = ();
    
    foreach my $file (readdir(INPUT_DIR))
    {
	if ($file !~ /(.*?)\.fasta.tsv$/)
	{
	    next;
	}

	my $file_base_name = $1;
	my $input_file_path = $args{$INPUT_OPTION} . $DIRECTORY_DELIMITER . $file;
	
	open(INPUT, $input_file_path) || die "could not open file '$input_file_path' for read";

	while (<INPUT>)
	{
	    my ($protein_id, $md5sum, $length, $source, $pfam_id, $pfam_description, $domain_start,
		$domain_end, $e_value, undef) = split("\t");

	    if ($source ne "Pfam")
	    {
		next;
	    }

	    $domains_by_species{$file_base_name}->{$pfam_id} = 1;
	    $all_domains{$pfam_id} = 1;
	}

	close INPUT || die "could not close file '$input_file_path' after read";
    }

    closedir INPUT_DIR;

    my @ordered_pfam_ids = sort keys %all_domains;

    foreach my $species_name (sort keys %domains_by_species)
    {
	print OUTPUT ">" . $species_name . "\n";

	my $first_domain = 0;

	foreach my $pfam_id (@ordered_pfam_ids)
	{
	    if (not $first_domain)
	    {
		$first_domain = 1;
	    }
	    else
	    {
		print OUTPUT " ";
	    }

	    if (defined $domains_by_species{$species_name}->{$pfam_id})
	    {
		print OUTPUT "1";
	    }
	    else
	    {
		print OUTPUT "0";
	    }
	}

	print OUTPUT "\n";
    }
    
    close OUTPUT;
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <dir> -$OUTPUT_OPTION <pasta>

Go through a directory of InterProScan results (ending in .tsv) and
group together domains, outputting a binary PASTA format.
    
    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input directory of InterProScan results (ending in .tsv)
    -$OUTPUT_OPTION : output binary characters PASTA file

HELP

    print STDERR $HELP;

}

&main();
