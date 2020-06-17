#!/usr/bin/env perl
# Input from "PIH Uganda" spreadsheet online

use List::MoreUtils qw/zip/;
use feature 'say';

my $header = <>;
chomp $header;
my ($accessionH, @header) = split "\t", $header;

my @extraKeys = qw/body_product body_site host_common_name sample_type body_habitat country/;
my @extraValues = ("UBERON:cerebrospinal fluid", "spinal cord", "Human", "cerebrospinal fluid", "spinal cord", "Uganda");

say join("\t", "name", "description", "sourcemtoverride", "samplemtoverride", "age_at_collection_months", "sex", "location", "hydrocephalus", @extraKeys);
while(<>){
  chomp;
  my ($accession, @line) = split "\t";
  my %line = zip @header, @line;
  next unless $line{tissue} eq 'CSF';
  my ($age) = ($line{age} =~ /(.*) days/);
  my $ageMonths = sprintf('%.1f', ($age * 12 ) / 365.25);

  my $sex = $line{sex};
  my $region = $line{region};
  my $disease = $line{disease};
  my $diseaseLong = $disease eq 'PIH' ? 'Postinfectious hydrocephalus (PIH)': $disease eq 'NPIH' ? 'Nonpostinfectious hydrocephalus (NPIH)' : die $disease;

  my $description = "$region, $ageMonths months $sex, $disease";

  say join("\t", $accession, $description, "", "", $ageMonths, $sex, $region, $diseaseLong, @extraValues);
}


