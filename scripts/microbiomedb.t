use FindBin;

use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/extlib/lib/perl5";

use IsaSummary;
use OntologyMappings;
use ApiCommonData::Load::OwlReader;
use Test::More;

my $owlFile = "$FindBin::Bin/lib/ApiCommonData/Load/ontology/Microbiome/microbiome.owl";
my $owl = ApiCommonData::Load::OwlReader->new($owlFile);
my ($labelsBySourceId, $__) = $owl->getLabelsAndParentsHashes;


my $ontologyMappings = OntologyMappings->new("$FindBin::Bin/../ISA/config/ontologyMappingsMicrobiome.xml");
# my $valueMappingFile = "$FindBin::Bin/../../ISA/config/valueMappingsMicrobiome.txt";


my $mbioDir = "$FindBin::Bin/../ISA/metadata/MBSTDY0020";
# my $ontologyMappingOverrideFile = "$mbioDir/ontologyMappingOverride.xml";

opendir(my $dh, $mbioDir) or die "Can't open metadata dir: $!";

for my $isaName (grep {$_ !~ /changesMade/} grep {/\.txt$/} readdir $dh){
  subtest($isaName => sub {
    my $isaSummary = IsaSummary->new("$mbioDir/$isaName");
    for my $sampleDetail ($isaSummary->sampleDetails){
       my $term = $ontologyMappings->getTermByName($sampleDetail);
       if($term){
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
done_testing;
