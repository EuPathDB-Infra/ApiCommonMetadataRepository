use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/extlib/lib/perl5";

use IsaSummary;
use OntologyMappings;
use ApiCommonData::Load::OwlReader;
use Test::More;

die "Usage: SPARQLPATH=scripts/lib/ApiCommonData/Load/lib/SPARQL/ perl $0" unless $ENV{SPARQLPATH};
my $owlFile = "$FindBin::Bin/lib/ApiCommonData/Load/ontology/Microbiome/microbiome.owl";
ok(-f $owlFile, $owlFile);
my $owl = ApiCommonData::Load::OwlReader->new($owlFile);
my ($labelsBySourceId, $__) = $owl->getLabelsAndParentsHashes;


my $ontologyMappings = OntologyMappings->new("$FindBin::Bin/../ISA/config/ontologyMappingsMicrobiome.xml");
# my $valueMappingFile = "$FindBin::Bin/../../ISA/config/valueMappingsMicrobiome.txt";

# just the word age, meaning age in years: OBI_0001169
my @requiredSourceIds = qw/OBI_0100051 OBI_0001627 EUPATH_0000512 UBERON_0000466 UBERON_0000061 UBERON_0000463 ENVO_00002297 SO_0001000/;

my $mbioDir = "$FindBin::Bin/../ISA/metadata/MBSTDY0020";
# my $ontologyMappingOverrideFile = "$mbioDir/ontologyMappingOverride.xml";

opendir(my $dh, $mbioDir) or die "Can't open metadata dir: $!";
my @isaNames = sort grep {$_ !~ /changesMade/} grep {/\.txt$/} readdir $dh; 


our %termIds;
for my $isaName (@isaNames){
  subtest($isaName => sub {
    my $isaSummary = IsaSummary->new("$mbioDir/$isaName");
    for my $sampleDetail ($isaSummary->sampleDetails){
       my $term = $ontologyMappings->getTermByName($sampleDetail);
       if($term){
         $termIds{$term->{source_id}}{$isaName}++;
         ok($labelsBySourceId->{$term->{source_id}}, $sampleDetail)
	   or do {
	     diag "Couldn't map $sampleDetail, with values: " . $isaSummary->valuesSummary($sampleDetail);
	     diag "Not in owl: ".$term->{source_id};
             diag explain $term;
           };
       } else {
         diag "No ontology mapping for $sampleDetail: " . $isaSummary->valuesSummary($sampleDetail);
         fail($sampleDetail);
       }
    }
  });
}
my %exceptions = (
  OBI_0001627 => {
    "Ciara_V4.txt" => "Lab setting, no need for country"
  },
  SO_0001000 => {
    "EMP_1064_Bee_Microbiome.txt" => "Bees are missing sequencing region, not worth the time finding out what it is"
  }
);
for my $requiredTermId (@requiredSourceIds){
  my @isasWhereTermExpectedMissing = keys %{$exceptions{$requiredTermId}};
  my @isasWhereTermPresent = grep {$termIds{$requiredTermId}{$_}} @isaNames;
  my @isasWhereTermMissing = grep {not $termIds{$requiredTermId}{$_} and not $exceptions{$requiredTermId}{$_}} @isaNames;
  ok(not (@isasWhereTermMissing), "Required $requiredTermId " . $labelsBySourceId->{$requiredTermId})
    or diag explain {"present" => \@isasWhereTermPresent, "missing" => \@isasWhereTermMissing, "expected not present" => \@isasWhereTermExpectedMissing};
}
done_testing;
