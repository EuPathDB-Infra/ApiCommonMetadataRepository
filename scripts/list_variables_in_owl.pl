#!/usr/bin/env perl
use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use YAML;
use ApiCommonData::Load::OntologyMapping;
use feature 'say';

die "Usage: $0 owl" unless @ARGV;

my $om = ApiCommonData::Load::OntologyMapping->fromOwl(shift @ARGV);


my ($ontologySources, $ontologyMapping) = $om->asSourcesAndMapping();

my @a = map {$ontologyMapping->{$_}} sort keys %{$ontologyMapping};
say Dump @a;


