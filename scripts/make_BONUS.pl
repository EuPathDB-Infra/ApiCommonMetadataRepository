#!/usr/bin/env perl

use strict;
use warnings;
use Spreadsheet::Read;
use feature 'say';
use List::Util qw /reduce uniq/;
use Scalar::Util qw/looks_like_number/;
use List::MoreUtils qw/zip/;
use Hash::Merge qw/merge/;
use YAML;

my ($in, $outTsv) = @ARGV;
die "Usage: $0 in.xlsx outTsv" unless -f $in and $outTsv;


my %dataBySubject;
my $o = Spreadsheet::Read->new($in);
my $subjectSheet= $o->sheet('SuppTable1');

my ($subjectHeader, @subjectRows) = $subjectSheet->rows;

sub goodTruth {
  my ($x) = @_;
  return "" unless defined $x;
  return "Y" if $x eq 1 || $x eq "Y";
  return "N" if $x eq 0 || $x eq "N";
  return "" if $x eq "NA";
  die $x;
}
my %genocats = (
  1 => "Homozygous F508del",
  2 => "Heterozygous F508del",
  3 => "No F508del",
);
my @subjectHeaders = ("sex", "Is low length", "Is low weight", "Pancreatic insufficiency", "F508del-CFTR genotype", "Received protein pump inhibitor", "Received acid blocker");

for my $row (@subjectRows){
  my ($subjectId, $gender, $lowLength, $lowWeight, $pancInsuf, $genocat, $anyPpi, $anyH2 ) = @{$row};
  $dataBySubject{$subjectId}{sex} = $gender;
  $dataBySubject{$subjectId}{"Is low length"} = goodTruth($lowLength);
  $dataBySubject{$subjectId}{"Is low weight"} = goodTruth($lowWeight);
  $dataBySubject{$subjectId}{"Pancreatic insufficiency"} = goodTruth($pancInsuf);
  $dataBySubject{$subjectId}{"F508del-CFTR genotype"} = $genocat ? $genocats{$genocat} : "";
  $dataBySubject{$subjectId}{"Received protein pump inhibitor"} = goodTruth($anyPpi);
  $dataBySubject{$subjectId}{"Received acid blocker"} = goodTruth($anyH2);
}
my $sampleSheet= $o->sheet('SuppTable2');
my ($sampleHeader, @sampleRows) = $sampleSheet->rows;
my @sampleHeaders = ("age_at_collection_months", "Host weight (g)", "Body length (cm)", "Breastmilk in diet", "Formula in diet", "Table food in diet", "antibiotic_exposure", "Fecal fat percentage", "Calprotectin"), 
my %dataBySample;
for my $row (@sampleRows){
  my ($sampleId, $month, $weight, $weightPerc, $length, $lengthPerc, $breastmilk, $formula, $tablefood, $currentorpriorantibiotics, $fecalfatPerc2, $calprotectin3) = @{$row};

  $dataBySample{$sampleId}{age_at_collection_months} = $month;
  $dataBySample{$sampleId}{"Host weight (g)"} = $weight && $weight ne 'NA' ? $weight * 1000 : "";
  $dataBySample{$sampleId}{"Body length (cm)"} = $length;
  $dataBySample{$sampleId}{"Breastmilk in diet"} = goodTruth($breastmilk);
  $dataBySample{$sampleId}{"Formula in diet"} = goodTruth($formula);
  $dataBySample{$sampleId}{"Table food in diet"} = goodTruth($tablefood);
  $dataBySample{$sampleId}{antibiotic_exposure} = goodTruth($currentorpriorantibiotics);
  $dataBySample{$sampleId}{"Fecal fat percentage"} = $fecalfatPerc2 eq 'NA' ? "" : sprintf("%.02f", $fecalfatPerc2);
  $dataBySample{$sampleId}{"Calprotectin"} = $calprotectin3 eq 'NA' ? "" : $calprotectin3;

}

open (my $fh, ">", $outTsv) or die "$!: $outTsv";

my @extraKeys = qw/body_product body_site host_common_name sample_type body_habitat env_feature/;
my @extraValues = qw/UBERON:feces colon Human Stool colon Human/;

say $fh join("\t", "name", "description", "cohort", "subject_id", @sampleHeaders, @subjectHeaders, @extraKeys);
for my $sampleId (sort keys %dataBySample){
  my $subjectId;
  my $cohort;
  my $description;
  if ($sampleId =~ m{(B\d+)-M\d+}){
    $subjectId = $1;
    $cohort = "Cystic fibrosis";
    $description = sprintf("CF patient %s, %s months", $subjectId, $dataBySample{$sampleId}{age_at_collection_months});
  } elsif ($sampleId =~ m{(4-14-10\d\d)-(.*)}){
    $subjectId = $1;
    $cohort = "Control";
    $dataBySample{$sampleId}{age_at_collection_months} = 0 + $2;
    $description = sprintf("Control subject %s, %s months", $subjectId, $dataBySample{$sampleId}{age_at_collection_months});
  }
  die $sampleId unless $subjectId and $dataBySubject{$subjectId};

  say $fh join ("\t", $sampleId, $description, $cohort, $subjectId,
    (map {$dataBySample{$sampleId}{$_} // ""} @sampleHeaders),
    (map {$dataBySubject{$subjectId}{$_} // ""} @subjectHeaders),
    @extraValues,
  );
}
