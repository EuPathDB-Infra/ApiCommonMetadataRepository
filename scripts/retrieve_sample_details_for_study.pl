#!/usr/bin/env perl
use strict;
use warnings;

use LWP;
use JSON;
use YAML;
use XML::Simple;
use feature 'say';
my ($study_accession) = @ARGV or die "Usage: $0 <study accession>";

my $samples_url = "https://www.ebi.ac.uk/ena/portal/api/search?query=secondary_study_accession=\"$study_accession\"&result=read_run&fields=secondary_sample_accession,run_accession,sample_accession&format=json";
my $samples_response = LWP::UserAgent->new->get($samples_url);
die sprintf("Error %s: $samples_url", $samples_response->status_line) unless $samples_response->is_success && $samples_response->decoded_content;

for (@{from_json ($samples_response->decoded_content)}){
  my $sample_accession=$_->{sample_accession};
  my $id=$_->{secondary_sample_accession}.".".$_->{run_accession};
  my $attributes_url = "https://www.ebi.ac.uk/ena/data/view/$sample_accession&display=xml";
  my $attributes_response = LWP::UserAgent->new->get($attributes_url);
  die sprintf("Error %s: $attributes_url", $attributes_response->status_line) unless $attributes_response->is_success;
  my $attributes_xml = XMLin($attributes_response->decoded_content);
  my %attributes = map {$_->{TAG} => $_->{VALUE}} grep {$_->{TAG} !~ /^ENA-/} @{$attributes_xml->{SAMPLE}{SAMPLE_ATTRIBUTES}{SAMPLE_ATTRIBUTE}};
  $attributes{sample_name} = $attributes_xml->{SAMPLE}{TITLE};
  say YAML::Dump({$id => \%attributes });
}

