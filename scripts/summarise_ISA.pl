#!/usr/bin/env perl
use strict;
use warnings;
use YAML;
use Text::CSV qw( csv );
use Scalar::Util qw/looks_like_number/;
use List::Util qw/all max min/;
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/lib";
use OntologyMappings;

my ($isa_path, $ontology_mappings_path) = @ARGV;
die "Usage: $0 isa_path ontology_mappings_path" unless -f $isa_path and -f $ontology_mappings_path;

my $aoh = csv(in => $isa_path, headers => "auto", sep => "\t");
my $ontology_mappings = OntologyMappings->new($ontology_mappings_path);
my %attributes;

for my $h (@{$aoh}){
  delete $h->{$_} for ("name", "description", "sourcemtoverride", "samplemtoverride");
  for my $k (keys %$h){
    push @{$attributes{$k}}, $h->{$k};
  }
}
my %categories;
my %attribute_names;

sub putative_parent_and_values_summary {
  my ($values) = @_;
  my %h;
  $h{$_}++ for @{$values};
  my @distinct_values =  map {$_ =~/^$/ ? '""' : $_ } keys %h;
  my @values_that_are_numbers = grep {looks_like_number $_} @distinct_values;
  my @values_that_are_not_numbers = grep {not (looks_like_number $_)} @distinct_values;
  my ($values_summary, $parent);
  if (@distinct_values == 1){
    $parent = "...common...";
    $values_summary =  $distinct_values[0];
  } elsif (@distinct_values < 10 and not (@values_that_are_numbers)){
    $parent = "...enum...";
    $values_summary =  join (", ", sort @distinct_values);
  } elsif (@values_that_are_numbers and @values_that_are_not_numbers < 5){
    $parent = "...numeric...";
    $values_summary = sprintf("%s to %s", min(@values_that_are_numbers), max(@values_that_are_numbers));
    $values_summary = join (", ", sort @values_that_are_not_numbers).", $values_summary" if @values_that_are_not_numbers;
  } else {
    $parent = "...multiple...";
    $values_summary =  sprintf("%s different values", scalar @distinct_values);
  }
  return $parent, $values_summary;
}

my %o;
for my $attribute_name (keys %attributes){
  my ($putative_parent, $values_summary) = putative_parent_and_values_summary($attributes{$attribute_name});
  my ($parent, $term_string) = $ontology_mappings->getParentAndTermStringByName($attribute_name);
  $parent //= $putative_parent;
  $term_string //= "...$attribute_name";
  $o{$parent}{$term_string} = $values_summary;
}

say YAML::Dump(\%o);
