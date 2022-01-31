use strict;
use warnings;
use feature 'say';

use File::Slurp qw(write_file);

my %idcs = (
BONUS => "subject_id",
Bangladesh_healthy_5yr => "Child ID",
Ciara_V1V3 => "host_subject_id",
DIABIMMUNE => "subject",
DailyBaby => "subject_id",
Dantas_earlyLife => "subject_id",
EMP_10249_ECAM => "host_subject_id",
EMP_1927_HMP_V13 => "host_subject_id",
EMP_1928_HMP_V35 => "host_subject_id",
EcoCF => "host_subject_id",
HMPWgs => "subject_id",
MALED_healthy => "Child ID",
NICUNEC => "subject_id",
ResistomeAmplicon => "subject_id",
ResistomeWgs => "subject_id",
Resistome => "subject_id",
StLouisNICU => "subject_id",
);
sub idc {
  my ($ds) = @_;
  my $h = $idcs{$ds};
  return $h ? sprintf('idColumn="%s"', $h) : ""; 
}
sub a1 {
  my ($suffix, $type) = @_;
  die unless $suffix and $type;
  return sprintf('<node isaObject="Assay" name="%s" type="%s" suffix="%s"/>', $suffix, $type, $suffix);
}
sub a2 {
  my ($suffix) = @_;
  return sprintf('
    <edge input="Sample" output="%s">
        <protocol>DNA sequencing</protocol>
    </edge>
', $suffix);
}
my $stanza = <<'EOF';
<investigation identifierRegex="^MBSTDY0021$" identifierIsDirectoryName="true">

  <study fileName="DATASET.txt" identifierSuffix="-1" sampleRegex="MBSMPL">
    <dataset>MicrobiomeStudyEDA_DATASET_RSRC</dataset>

    <node name="Source" type="Participant" suffix="Source" ID_COLUMN /> 
    <node name="Sample" type="Sample"/>
    ASSAYS_1


    <edge input="Source" output="Sample">
        <protocol>specimen collection</protocol>
    </edge>
    ASSAYS_2
  </study>
</investigation>
EOF

# ! grep -A 25 SO_0001000 /eupath/data/EuPathDB/devWorkflows/MicrobiomeDB/EDAwg/data/OntologyTerm_microbiome_human_only_RSRC/microbiome_human_only.owl | perl -nE 'next unless /EUPATH_0000755/; m{>(.*?)(?:.txt)?::(.*?)<} and say "$1 => \"$2\","'
my %suffixes = (
  BONUS => "WGS",
  DIABIMMUNE_WGS => "WGS",
  HMPWgs => "WGS",
  NICUDischarge => "WGS",
  NICUNEC => "WGS",
  Pig_pregnancy => "WGS",
  Resistome => "WGS",
  Bangladesh_healthy_5yr => "16S",
  Ciara_V1V3 => "16S",
  DIABIMMUNE => "16S",
  DailyBaby => "16S",
  EMP_10249_ECAM => "16S",
  EMP_1927_HMP_V13 => "16S",
  EMP_1928_HMP_V35 => "16S",
  EcoCF => "16S",
  GEMS => "16S",
  MALED_diarrhea => "16S",
  MALED_healthy => "16S",
  PIH_Uganda => "16S",
  ResistomeAmplicon => "16S",
  StLouisNICU => "16S",
  UgandaMaternal => "TODO",
  DiabImmune => "TODO",
);

my %types16S = (
  Bangladesh_healthy_5yr => "16S rRNA sequencing assay targeting V4 region",
  Ciara_V1V3 => "16S rRNA sequencing assay targeting V1-V3 region",
  DailyBaby => "16S rRNA sequencing assay targeting V4 region",
  EMP_10249_ECAM => "16S rRNA sequencing assay targeting V4 region",
  EMP_1927_HMP_V13 => "16S rRNA sequencing assay targeting V1-V3 region",
  EMP_1928_HMP_V35 => "16S rRNA sequencing assay targeting V3-V5 region",
  EcoCF => "16S rRNA sequencing assay targeting V4 region",
  GEMS => "16S rRNA sequencing assay targeting V1-V2 region",
  MALED_diarrhea => "16S rRNA sequencing assay targeting V4 region",
  MALED_healthy => "16S rRNA sequencing assay targeting V4 region",
  PIH_Uganda => "16S rRNA sequencing assay targeting V1-V2 region",
  StLouisNICU => "16S rRNA sequencing assay targeting V3-V5 region",
  UgandaMaternal => "TODO",
  DiabImmune => "TODO",
);
sub xml {
  my ($dataset) = @_;
  my $suffix = $suffixes{$dataset};
  die $dataset unless $suffix;
  my $type = $suffix eq 'WGS' ? 'whole metagenome sequencing assay' : $types16S{$dataset};
  my $body = $stanza;
  my $idc = idc($dataset);
  my $a1;
  my $a2;
  if($dataset eq "UgandaMaternal"){
     $a1 = a1("16S_V1_V2", "16S rRNA sequencing assay targeting V1-V2 region")."\n".a1("16S_V3_V4", "16S rRNA sequencing assay targeting V3-V4 region");
     $a2 = a2("16S_V1_V2").a2("16S_V3_V4");
  } elsif ($dataset eq "DiabImmune"){
     $a1 = a1("16S", "16S rRNA sequencing assay targeting V4 region")."\n".a1("WGS", 'whole metagenome sequencing assay');
     $a2 = a2("16S").a2("WGS");
  } else {
     die $dataset unless $type;
     $a1 = a1($suffix, $type);
     $a2 = a2($suffix);
  }
  
  $body =~ s/DATASET/$dataset/g;
  $body =~ s/ASSAYS_1/$a1/g;
  $body =~ s/ASSAYS_2/$a2/g;
  $body =~ s/ID_COLUMN/$idc/g;
  return $body; 
}

for my $f (glob "./*.txt"){
  $f =~ m{\./(.*).txt};
  my $dataset = $1;
  write_file("$dataset.xml", xml($dataset));
} 
