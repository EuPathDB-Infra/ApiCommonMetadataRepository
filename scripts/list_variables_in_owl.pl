#!/usr/bin/env perl
use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use YAML;
use ApiCommonData::Load::OntologyMapping;
use feature 'say';
use List::Util qw/uniq/;

die "Usage: $0 owl" unless @ARGV;

my $om = ApiCommonData::Load::OntologyMapping->fromOwl(shift @ARGV);


my ($ontologySources, $ontologyMapping) = $om->asSourcesAndMapping();

my @a = map {$ontologyMapping->{$_}} sort keys %{$ontologyMapping};
say for uniq(sort grep {/::/} map {@{$_->{characteristicQualifier}{name}//[]}} @a);
#say Dump @a;


