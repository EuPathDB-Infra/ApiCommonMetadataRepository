#!/usr/bin/env perl
use strict;
use warnings;
use YAML;
use feature 'say';
use List::Util qw/pairkeys pairvalues/;

my @sample_ids_and_attributes = YAML::Load (do{local $/; <STDIN>});

my @extra_attributes = map {split "=", $_} @ARGV;

my %attributes;

for my $p (@sample_ids_and_attributes){
  my ($sample_id, $h) = %$p;
  for my $k (keys %$h){
    $attributes{$k}{$h->{$k}}++;
  }
}

# I don't think 'description' is actually ever present
my @sample_detail_types = sort grep {$_ ne 'description' and $_ ne 'sample_name' } keys %attributes;

say join "\t", "name", "description", "sourcemtoverride", "samplemtoverride", @sample_detail_types, pairkeys @extra_attributes;

sub as_slightly_prettier {
  my ($t) = @_;
  return unless $t;
  $t =~ s/^\s+//;
  $t =~ s/\s+$//;

  $t =~ s/_/ /g;
  return $t;
}

for my $p (@sample_ids_and_attributes){
  my ($sample_id, $h) = %$p;
  say join "\t", $sample_id, $h->{description} // as_slightly_prettier($h->{sample_name}) // "", "", "", (map {$h->{$_} // ""} @sample_detail_types), pairvalues @extra_attributes;
}
