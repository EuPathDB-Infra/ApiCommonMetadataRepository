use strict;
use warnings;

use XML::Simple;

package OntologyMappings;

sub new {
   my ($class, @args) = @_;
   die "Usage: $class <path>" unless @args;
   my $xml = XML::Simple::XMLin(@args), 
   my %name_to_ontologyTerm;
   for my $ontologyTerm (@{$xml->{ontologyTerm}}){
      my @names = ref $ontologyTerm->{name} ? @{$ontologyTerm->{name}} : ($ontologyTerm->{name});
      $name_to_ontologyTerm{lc $_} = $ontologyTerm for @names;
   }

   return bless {xml => $xml, name_to_ontologyTerm => \%name_to_ontologyTerm}, $class;
}

sub getTermByName {
    my ($self, $name) = @_;
    return $self->{name_to_ontologyTerm}{lc $name};
}

sub getParentAndTermStringByName {
    my ($self, $name) = @_;
    my $ontologyTerm = $self->getTermByName($name);
    return unless $ontologyTerm;
    return $ontologyTerm->{parent}, sprintf("%s:%s", $ontologyTerm->{source_id}, $name);
}
1;
