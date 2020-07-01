#!/usr/bin/env perl
use strict;
use warnings;
package IsaSummary;
use List::MoreUtils qw/zip/;
use Scalar::Util qw/looks_like_number/;
use List::Util qw/all max min/;

sub summariseValues {
  my ($values) = @_;
  my %h;
  $h{$_//""}++ for @{$values};
  my @distinct_values = keys %h;
  my @values_that_are_numbers = grep {looks_like_number $_} @distinct_values;
  my @values_that_are_not_numbers = grep {not (looks_like_number $_)} @distinct_values;
  my $valuesSummary;
  if (@distinct_values == 1){
    $valuesSummary =  $distinct_values[0];
  } elsif (@distinct_values < 10 and not (@values_that_are_numbers)){
    $valuesSummary =  join (", ", sort @distinct_values);
  } elsif (@values_that_are_numbers and @values_that_are_not_numbers < 5){
    $valuesSummary = sprintf("%s to %s", min(@values_that_are_numbers), max(@values_that_are_numbers));
    $valuesSummary = join (", ", sort @values_that_are_not_numbers).", $valuesSummary" if @values_that_are_not_numbers;
  } else {
    $valuesSummary =  sprintf("%s different values", scalar @distinct_values);
  }
  return $valuesSummary;
}
sub sampleDetails {
  my ($self) = @_;
  return sort keys %$self;
}

sub valuesSummary {
  my ($self, $sampleDetail) = @_;
  return $self->{$sampleDetail};
}

sub new {
  my ($class, $isa_path) = @_;
  return undef unless -f $isa_path;

  open(my $fh, "<", $isa_path) or die $isa_path;
  my $l = <$fh>;
  chomp $l;
  my @hs = split "\t", $l;

  my @aoh;
  while (my $l = <$fh>){
    chomp $l;
    my @xs = split "\t", $l;
    my %h = zip @hs, @xs;
    push @aoh, \%h;
  }

  my %sampleDetails;
  my %samples;
  for my $h (@aoh){
    delete $h->{$_} for ("name", "description", "sourcemtoverride", "samplemtoverride");
    for my $k (keys %$h){
      push @{$sampleDetails{$k}}, $h->{$k};
    }
  }
  my %o;
  for my $sampleDetail (keys %sampleDetails){
    $o{$sampleDetail} = summariseValues($sampleDetails{$sampleDetail});
  }
  return bless \%o, $class;
}
1;
