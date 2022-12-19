#!/usr/bin/env perl

# in order to search for modules in the directory where this script is located
use File::Basename;
use Cwd;
use lib dirname (&Cwd::abs_path(__FILE__));

use warnings;
use strict;

# modules in this distribution
use GetOptions;

# names of command line options
my $HELP_OPTION = 'help';
my $INPUT_OPTION = 'input';
my $OUTPUT_OPTION = 'output';
my $TEMPLATE_OPTION = 'template';

# types for command line options; see 'Getopt::Long' Perl documentation for information on option types
my %OPTION_TYPES = ($HELP_OPTION => '',
		    $INPUT_OPTION => '=s',
		    $OUTPUT_OPTION => '=s',
		    $TEMPLATE_OPTION => '=s');

my $DIRECTORY_DELIMITER = "/";

my $PLACEHOLDER_STRING = "placeholder";

sub main
{
    my %args = &GetOptions::get_options(\%OPTION_TYPES);

    if ($args{$HELP_OPTION} || (not ($args{$INPUT_OPTION} && $args{$OUTPUT_OPTION} && $args{$TEMPLATE_OPTION})))
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

    my $template_string = "";
    
    open(INPUT, $args{$TEMPLATE_OPTION}) || die "could not open file '$args{$TEMPLATE_OPTION}' for read";
    
    while (<INPUT>)
    {
	$template_string .= $_;
    }
    
    close INPUT || die "could not close file '$args{$TEMPLATE_OPTION}' after read";

    opendir(INPUT_DIR, $args{$INPUT_OPTION}) || die "could not open directory '$args{$INPUT_OPTION}' for read";
    
    my @input_file_names = readdir(INPUT_DIR);

    closedir INPUT_DIR || die "could not close directory '$args{$INPUT_OPTION}' after read";

    my $file_counter = 0;
    
    foreach my $input_file_name (sort @input_file_names)
    {
	if ($input_file_name !~ /(.*?)\.pasta$/)
	{
	    next;
	}

	my $file_base_name = $1;

	my $input_file_path = $args{$INPUT_OPTION} . $DIRECTORY_DELIMITER . $input_file_name;
	my $output_file_path = $args{$OUTPUT_OPTION} . $DIRECTORY_DELIMITER . $file_base_name . ".conf";

	open(OUTPUT, ">", $output_file_path) || die "could not open file '$output_file_path' for write";

	my $output_string = $template_string;
	
	$output_string =~ s/$PLACEHOLDER_STRING/$input_file_name/;

	print OUTPUT $output_string;
	
	close OUTPUT || die "could not close file '$output_file_path' after write";

	$file_counter++;
    }

    print STDOUT "$file_counter file(s) processed\n";
}

sub help
{
    my $HELP = <<HELP;
Syntax: $0 -$INPUT_OPTION <dir> -$OUTPUT_OPTION <dir> -$TEMPLATE_OPTION <txt>

For each file in the input directory, modify the template to replace
the string $PLACEHOLDER_STRING with the name of the file, and save
the modified template to the output directory.

    -$HELP_OPTION : print this message
    -$INPUT_OPTION : input directory containing files ending in .pasta
    -$OUTPUT_OPTION : output directory for modified templates
    -$TEMPLATE_OPTION : template file
   
HELP

    print STDERR $HELP;
}

&main();
