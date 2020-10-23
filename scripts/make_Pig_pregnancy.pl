#!/usr/bin/env perl
# Input from "PIH Uganda" spreadsheet online

use List::MoreUtils qw/zip/;
use feature 'say';

my $header = <>;
chomp $header;
my ($accessionH, @header) = split "\t", $header;

my @extraKeys = qw/body_product body_site host_common_name sample_type body_habitat env_feature/;
my @extraValues = (qw/UBERON:feces colon Pig Stool colon/ , "Veterinary animal");

my $doc = <<'EOF';
Sow_or_Piglet   Sow_Parity      geo_loc_name    env_medium      env_local_scale Timepoint_or_Piglet_no  BioSampleModel  sex     collection_date Piglet_weight   host    SowID   env_broad_scale sample_name     lat_lon
...common...:
  ...BioSampleModel: MIGS/MIMS/MIMARKS.host-associated
  ...collection_date: missing
  ...env_broad_scale: Pig
  ...env_local_scale: gut
  ...env_medium: fecal
  ...geo_loc_name: 'USA: Philadelphia'
  ...host: Sus scrofa domesticus
  ...lat_lon: 39.8687 N 75.7547 W
...enum...:
  ...Sow_Parity: 'P0, P3, P4, P5, P6, P7'
  ...Sow_or_Piglet: 'Piglet, Sow'
  ...sex: 'female, male'
...multiple...:
  ...Timepoint_or_Piglet_no: 22 different values
...numeric...:
  ...Piglet_weight: 'NA, 1.4 to 5'
  ...SowID: 34 to 8907
EOF

say join("\t", "name", "description", "sourcemtoverride", "samplemtoverride", "mom_child", "sex", "subject", @extraKeys);
while(<>){
  chomp;
  my ($accession, @line) = split "\t";
  $accession =~ s/\.SRR.*//;
  my %line = zip @header, @line;

  my $momChild = $line{Sow_or_Piglet};
  my $subject = $momChild eq 'Piglet' ? $line{Timepoint_or_Piglet_no} : $line{SowID}. " " . $line{Sow_Parity};

  my $description = "$momChild $subject";

  say join("\t", $accession, $description, "", "", $momChild, $line{sex}, $subject, @extraValues);
}


