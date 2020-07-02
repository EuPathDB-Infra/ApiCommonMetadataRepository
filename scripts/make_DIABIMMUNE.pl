#!/usr/bin/env perl

use strict;
use warnings;
use Spreadsheet::Read;
use feature 'say';
use List::Util qw /reduce uniq/;
use List::MoreUtils qw/zip/;
use Hash::Merge qw/merge/;
use YAML;

my ($in, $ontologyMappings, $outTsv) = @ARGV;
die "Usage: $0 in.xlsx ontologyMappings.xml outTsv" unless -f $in && -f $ontologyMappings;

my $o = Spreadsheet::Read->new($in);
my %subjects;
my %sampleToSubject;
my %samples;
my %birthInfos;
my %milks;
my %diabetesInfos;
my %growths;
my %dietInfos;

my $samplesSheet = $o->sheet('Samples');
my ($samplesHeader, @samplesRows) = $samplesSheet->rows;
my ($__s, $countryH, $__ss, $__sss, @samplePropsH) = @{$samplesHeader};

my %countryCodes = (
  FIN => "Finland",
  RUS => "Russia",
  EST => "Estonia",
);
for my $r (@samplesRows) {
  my ($subject, $country, $sample, $ageAtCollection, $cohort) = @{$r};
  $sample = int $sample;
  $subjects{$subject}{$countryH} = $countryCodes{$country};
  $sampleToSubject{$sample} = $subject;
  $samples{$sample} = {
    age_at_collection_months => int ($ageAtCollection * 12 / 365.25 ),
    cohort => $cohort,
  };
}


my $birthInfoSheet = $o->sheet('Pregnancy, birth');
my ($birthInfoHeader, @birthInfoRows) = $birthInfoSheet->rows;
my ($__b, @birthInfoPropsH) = @{$birthInfoHeader};
pop @birthInfoPropsH;

for my $r (@birthInfoRows) {
  my ($subject, @birthInfoProps) = @{$r};
  my $birthLocation = pop @birthInfoProps;

  my %h = zip @birthInfoPropsH, @birthInfoProps;
  $h{birth_location} = $birthLocation;
  $birthInfos{$subject} = \%h;
}

my $milkSheet = $o->sheet('Milk');
my ($milkHeader, @milkRows) = $milkSheet->rows;
my ($__m, @milkPropsH) = @{$milkHeader};

for my $r (@milkRows) {
  my ($subject, @milkProps) = @{$r};
  my %h = zip @milkPropsH, @milkProps;
  $milks{$subject} = \%h;
}



my $diabetesInfoSheet = $o->sheet('Diabetes');
my ($diabetesInfoHeader, @diabetesInfoRows) = $diabetesInfoSheet->rows;
my ($__d, @diabetesInfoPropsH) = @{$diabetesInfoHeader};

for my $r (@diabetesInfoRows) {
  my ($subject, @diabetesInfoProps) = @{$r};
  my %h = zip @diabetesInfoPropsH, @diabetesInfoProps;
  $diabetesInfos{$subject} = \%h;
}


my $growthSheet = $o->sheet('Growth');
my ($growthHeader, @growthRows) = $growthSheet->rows;
my ($__g, @growthPropsH) = @{$growthHeader};

for my $r (@growthRows) {
  my ($subject, @growthProps) = @{$r};
  my %h = zip @growthPropsH, @growthProps;
  $growths{$subject} = \%h;
}


my $dietInfoSheet = $o->sheet('Early diet');
my ($dietInfoHeader, @dietInfoRows) = $dietInfoSheet->rows;

my %hs;
for my $r (@dietInfoRows) {
  my ($subject, $dietaryCompound, $startMonth) = @{$r};
  $dietInfos{$subject}{"compound_$dietaryCompound"} = $startMonth;
  $hs{"compound_$dietaryCompound"}++;
}

# check that this is really an aggregate term
delete $hs{compound_solid_start_approx};
for my $subject (keys %dietInfos){
   my $startSolidFoods = $dietInfos{$subject}{compound_solid_start_approx};
   for my $food (keys %hs){
      if($dietInfos{$subject}{$food} && $dietInfos{$subject}{$food} < $dietInfos{$subject}{compound_solid_start_approx}){
        die join ("\t", $subject, $food, $dietInfos{$subject}{$food}, $dietInfos{$subject}{compound_solid_start_approx}); 
      }
   }
}

my $subjectProps = reduce {merge ($a, $b) } \%subjects, \%birthInfos, \%milks, \%diabetesInfos, \%growths, \%dietInfos;
my %subjectProps = %{$subjectProps};

my @subjectKeys = sort {$a cmp $b} map {keys %{$_->{E003188}}} \%subjects, \%birthInfos, \%milks, \%diabetesInfos, \%growths, \%dietInfos;

my %props = %samples;
for my $sample (keys %sampleToSubject){
  my $subject = $sampleToSubject{$sample};
  for my $subjectKey (@subjectKeys){
    $props{$sample}{$subjectKey} = $subjectProps{$subject}{$subjectKey};
  }
}

my @propKeys = sort {$a cmp $b} uniq map {keys %{$_}} values %props;

my $legendSheet = $o->sheet('Table legend');
my ($legendH, @legendRows) = $legendSheet->rows;

my %columnNameToDescription;
my %columnNameToCurrentIri;

for my $r (@legendRows){
  my ($__l, $columnName, $columnDescription, $__ll, $__lll, $__llll, $mappedIri) = @{$r};
  $columnNameToDescription{$columnName} = $columnDescription if $columnDescription;
  $columnNameToCurrentIri{$columnName} = $mappedIri if $columnName;
}

my $newTermsSheet = $o->sheet('terms added');
my ($newTermsH, @newTermsRows) = $newTermsSheet->rows;

my %newTermToIri;
my %columnDescriptionToIri;

for my $r (@newTermsRows){
  my ($iriPurl, $newTerm, $columnDescription) = @{$r};
  my ($iri) = reverse split ("/", $iriPurl);
  $newTermToIri{$newTerm} = $iri;
  $columnDescriptionToIri{$columnDescription} = $iri if $columnDescription;
}
my %propToCurrentIri = (
  age_at_collection_months => "EUPATH_0009029",
  compound_solid_start_approx => "EUPATH_0009056",
);

my %propToNewTerm = (
  HLA_risk_class => "HLA risk, by HLA haplotyping",
  weight_growth_pace_during_three_years => "Yearly average weight gain during first three years (kg/year)",
  birth_location => "Urban or rural site",
);

sub pickIri {
  my $p = shift;
  no warnings;
  return $propToCurrentIri{$p} || $columnNameToCurrentIri{$p} || $columnDescriptionToIri{$columnNameToDescription{$p}} || $newTermToIri{$propToNewTerm{$p}} || do {
     $p =~ /compound_(.*)/;
     my $compound = $1;
     $compound =~ s/milkprod/milk products/ if $compound;
     $compound =~ s/sweetpota/sweet potato/ if $compound;
     $newTermToIri{"Age at first received $compound (months)"}
  };
}

my %propKeyToIri;

for my $propKey (@propKeys){
  $propKeyToIri{$propKey} = pickIri($propKey) or die $propKey;
}

open(my $ontologyInFh, "<", $ontologyMappings) or die "Could not open for read: $ontologyMappings";

my @linesUntilSource;
my @linesFromSourceUntilSample;
my @linesFromSampleUntilUnits;
my @linesFromUnits;
my $current = \@linesUntilSource;

my %irisMatched;
while(my $line = <$ontologyInFh>){
  chomp $line;
  if($line =~ /<!-- Characteristics associated with Source -->/){
    $current = \@linesFromSourceUntilSample;
  }
  if($line =~ /<!-- Characteristics associated with Sample -->/){
    $current = \@linesFromSampleUntilUnits;
  }
  if($line =~ /<!--units-->/){
    $current = \@linesFromUnits;
  }
  push @{$current}, $line;
  for my $propKey (keys %propKeyToIri){
    my $iri = $propKeyToIri{$propKey};
    if ($line =~ /$iri/){
            push @{$current}, "      <name>$propKey</name>";
      $irisMatched{$iri}++;
    }
  }
}
open(my $ontologyOutFh, ">", "$ontologyMappings.out") or die "Could not open for write: $ontologyMappings.out";
say $ontologyOutFh $_ for @linesUntilSource;
say $ontologyOutFh $_ for @linesFromSourceUntilSample;
for my $propKey (sort keys %propKeyToIri){
  my $iri = $propKeyToIri{$propKey};
  next if $irisMatched{$iri};
  next if grep {$_ eq $propKey} @samplePropsH;

  print $ontologyOutFh <<"EOF";
  <ontologyTerm source_id="${iri}" type="characteristicValue" parent="Source">
    <name>${propKey}</name>
  </ontologyTerm>
EOF
}
say $ontologyOutFh $_ for @linesFromSampleUntilUnits;
for my $propKey (sort keys %propKeyToIri){
  my $iri = $propKeyToIri{$propKey};
  next if $irisMatched{$iri};
  next unless grep {$_ eq $propKey} @samplePropsH;

  print $ontologyOutFh <<"EOF";
  <ontologyTerm source_id="${iri}" type="characteristicValue" parent="Sample">
    <name>${propKey}</name>
  </ontologyTerm>
EOF
}
say $ontologyOutFh $_ for @linesFromUnits;
close $ontologyInFh;
close $ontologyOutFh;
`mv $ontologyMappings.out $ontologyMappings`;

# cut -f 16,17,18,19,20 MALED_healthy.txt
# plus env_feature
my @extraKeys = qw/body_product body_site host_common_name sample_type body_habitat env_feature/;
my @extraValues = qw/UBERON:feces colon Human Stool colon Human/;
open (my $outFh, ">", $outTsv) or die "Could not open for writing: $outTsv";


sub goodTruths {
  my ($x) = @_;
  return unless defined $x;
  $x eq '0' ? 'false' : $x eq '1' ? 'true' : $x
}
say $outFh join("\t", "name", "description", "sourcemtoverride", "samplemtoverride", @extraKeys, @propKeys);
for my $sample (sort keys %props){
  my %h = %{$props{$sample}};
  
  $h{$_} = goodTruths($h{$_}) for qw/csection gestational_diabetes abx_while_pregnant t1d_diagnosed IAA GADA IA2A ZNT8A ICA/;
  if($h{milk_first_three_days}){
    $h{milk_first_three_days} =~s/_/ /g;
    $h{milk_first_three_days} =~s/mothers/mother's/g;
  }
  $h{gender} = lc $h{gender};
  my @values = map {$h{$_} //""} @propKeys;
  my $description = "Sample ID $sample: $h{country}, $h{age_at_collection_months} month";
  if ($h{age_at_collection_months} > 1){
    $description .= "s";
  }
  $description .= " old";
  if ($h{t1d_diagnosed} and $h{t1d_diagnosed} eq 'true'){
    $description .= ' with type 1 diabetes';
  }

  say $outFh join("\t", $sample, $description, "", "", @extraValues, @values);
}

close $outFh;
