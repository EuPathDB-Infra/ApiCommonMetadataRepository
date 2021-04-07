#!/usr/bin/env perl

use strict;
use warnings;
use Spreadsheet::Read;
use feature 'say';
use List::Util qw /reduce uniq/;
use Scalar::Util qw/looks_like_number/;
use List::MoreUtils qw/zip/;
use Hash::Merge qw/merge/;
use YAML;

my ($in, $srrs, $outTsv) = @ARGV;
die "Usage: $0 in.xlsx srrsTsv outTsv" unless -f $in && -f $srrs;

my @subjectHeaders;
my %dataBySubject;
my $o = Spreadsheet::Read->new($in);
my $infantFeedingSheet = $o->sheet('Infant_feeding');
my ($infantFeedingHeader, @infantFeedingRows) = $infantFeedingSheet->rows;
# Skip: foods by DOL
my ($subjectIdfH, $__ffH, $__fffH, $__ffffH, $__fffffH, $feedingH) = @{$infantFeedingHeader};

push @subjectHeaders, ("diet");
for my $row (@infantFeedingRows){
  my ($subjectIdf, $__ff, $__fff, $__ffff, $f__fffff, $feeding) = @{$row};
  $feeding =~ s{forumla}{formula} if $feeding;
  die join( "\t", @{$row},  $dataBySubject{$subjectIdf}{$feedingH}) if ($feeding && $dataBySubject{$subjectIdf}{$feedingH} && $dataBySubject{$subjectIdf}{$feedingH} ne $feeding);
  $dataBySubject{$subjectIdf}{diet} = $feeding;
}

my $infantSiblingsSheet = $o->sheet('Infant_siblings');
my ($infantSiblingsHeader, @infantSiblingsRows) = $infantSiblingsSheet->rows;
my ($subjectIdsH, $birthH, $__sH, $fratH, $amnioH, $chorioH, $setH) = @{$infantSiblingsHeader};

push @subjectHeaders, (qw/birth_plurality fraternal_or_identical_twins amnionicity chorionicity sibling_set_id/);
for my $row (@infantSiblingsRows){
  my ($subjectIds, $birth, $__s, $frat, $amnio, $chorio, $set) = @{$row};
  $dataBySubject{$subjectIds}{birth_plurality} = $birth;

  $frat =~ s{identicle}{identical} if $frat;
  $dataBySubject{$subjectIds}{fraternal_or_identical_twins} = $frat;
  $dataBySubject{$subjectIds}{amnionicity} = $amnio;
  $dataBySubject{$subjectIds}{chorionicity} = $chorio;
  $dataBySubject{$subjectIds}{sibling_set_id} = $set;
}

# Skip: the housing tab, which tracks which infant was in which room
# my $infantHousingSheet = $o->sheet('Infant_housing');

my $infantMetadataSheet = $o->sheet('Infant_metadata');
my ($infantMetadataHeader, @infantMetadataRows) = $infantMetadataSheet->rows;
my ($subjectIdMH, $gestationalAgeH, $sequencedH, $birthStudyDayH, $genderH, $birthModeH, $weightGH, $survivedH, $seasonH) = @{$infantMetadataHeader};

push @subjectHeaders, qw/gestational_age cohort birth_study_day sex baby_delivery_mode birth_weight survived season_of_birth/;
for my $row (@infantMetadataRows){
  my ($subjectIdM, $gestationalAge, $sequenced, $birthStudyDay, $gender, $birthMode, $weightG, $survived, $season) = @{$row};
  $dataBySubject{$subjectIdM}{gestational_age} = sprintf("%.2d", $gestationalAge);
  $dataBySubject{$subjectIdM}{cohort} = $sequenced;
  $dataBySubject{$subjectIdM}{birth_study_day} = $birthStudyDay;
  $dataBySubject{$subjectIdM}{sex} = $gender;
  $dataBySubject{$subjectIdM}{baby_delivery_mode} = $birthMode;
  $dataBySubject{$subjectIdM}{birth_weight} = "$weightG grams";
  $dataBySubject{$subjectIdM}{survived} = $survived;
  $dataBySubject{$subjectIdM}{season_of_birth} = $season;
}


my $infantDiseaseSheet = $o->sheet('Infant_disease');
my ($infantDiseaseHeader, @infantDiseaseRows) = $infantDiseaseSheet->rows;
my ($subjectIdDH, $diagnosisH, $typeH, $dStartH, $dEndH, $dMaternalH, $notesH) = @{$infantDiseaseHeader};

push @subjectHeaders, ("chorioamnionitis", "IUGR", "NEC", "sepsis", "MRSA_screen", "mother_group_b_streptococcus");
for my $row (@infantDiseaseRows){
  my ($subjectIdD, $diagnosis, $type, $dStart, $dEnd, $dMaternal, $notes) = @{$row};
  if ($diagnosis eq 'chorioamnionitis'){
    $dataBySubject{$subjectIdD}{chorioamnionitis} = "Y";
  } elsif ($diagnosis eq 'IUGR'){
    $dataBySubject{$subjectIdD}{IUGR} = "Y";
  } elsif ($diagnosis eq 'NEC'){
    $dataBySubject{$subjectIdD}{NEC} = "Y";
  } elsif ($diagnosis eq 'sepsis'){
    $dataBySubject{$subjectIdD}{sepsis} = "Y";
  } elsif ($diagnosis =~ 'MRSA'){
    $dataBySubject{$subjectIdD}{MRSA_screen} = "Y";
  } elsif ($diagnosis =~ 'strep'){
    die join "\t", @{$row} unless $dMaternal;
    $dataBySubject{$subjectIdD}{mother_group_b_streptococcus} = "Y";
  } else {
    #    say STDERR join "\t", @{$row};
  }
}

my %necTimes;
for my $row (@infantDiseaseRows){
  my ($subjectIdD, $diagnosis, $type, $dStart, $dEnd, $dMaternal, $notes) = @{$row};
  if($diagnosis eq 'NEC' and $dStart ne 'unk' and $dStart ne '?'){
     push @{$necTimes{$subjectIdD}}, [$dStart, $dEnd];
  }
}

my $infantAntibioticsSheet = $o->sheet('Infant_antibiotics');
my ($infantAntibioticsHeader, @infantAntibioticsRows) = $infantAntibioticsSheet->rows;
my ($subjectIdAH, $antibioticH, $aStartH, $aEndH, $aDaysH, $aMaternalH, $aReasonH, $aNotesH) = @{$infantAntibioticsHeader};

push @subjectHeaders, "maternal_antepartum_antibiotics", "maternal_antepartum_antibiotics_timing_prior_to_delivery";
for my $row (@infantAntibioticsRows){
  my ($subjectIdA, $antibiotic, $aStart, $aEnd, $aDays, $aMaternal, $aReason, $aNotes) = @{$row};
  if($aMaternal){
    $dataBySubject{$subjectIdA}{maternal_antepartum_antibiotics} = "Y";
    my $x;
    if ($aNotes =~ m{12-24}){
      $x = "12-24 hours prior to delivery";
    } elsif ($aNotes =~ m{24}){
      $x = "more than 24 hours prior to delivery";
    } elsif ($aNotes =~ m{12}){
      $x = "less than 12 hours prior to delivery";
    } else {
      # nothing
    }
    if($x){
      $dataBySubject{$subjectIdA}{maternal_antepartum_antibiotics_timing_prior_to_delivery} = $x;
    }
  }
}

my %antibioticsReasons;
for my $row (@infantAntibioticsRows){
  my ($subjectIdA, $antibiotic, $aStart, $aEnd, $aDays, $aMaternal, $aReason, $aNotes) = @{$row};
  if(!$aMaternal){
    push @{$antibioticsReasons{$subjectIdA}}, [$aStart, $aEnd, $aReason];
  }
}

my %antibioticTimes;
my @antibioticNames = qw/acyclovir amoxicillin ampicillin cefazolin cefepime cefotaxime claforan clindamycin fluconazole gentamycin nafcillin nystatin ofloxacin vancomycin zosyn/;
# also in dataset: penicillin valganciclovir
# but not when samples were collected
for my $row (@infantAntibioticsRows){
  my ($subjectIdA, $antibiotic, $aStart, $aEnd, $aDays, $aMaternal, $aReason, $aNotes) = @{$row};
  if(!$aMaternal){
    push @{$antibioticTimes{$antibiotic}{$subjectIdA}}, [$aStart, $aEnd];
  }
}

my %srrsBySubject;
my %dolsBySrr;
open (my $fh, "<", $srrs) or die "$!: $srrs"; 
while(<$fh>){
  chomp;
  my ($srr, $subjectIdStr) = split "\t";
  next unless $subjectIdStr =~ m{^([NS]\d)_(\d\d\d)_(\d\d\d)G_?[1,2]$};
  my $cohort = $1;
  my $subjectId = $2 + 0;
  my $dol = $3 + 0;
  $subjectId += 500 if $cohort eq 'S2';

  push @{$srrsBySubject{$subjectId}}, $srr;
  $dolsBySrr{$srr} = $dol;
}

my @sampleHeaders = ();
my %dataBySrr;

push @sampleHeaders, ("days_to_first_NEC", "day_of_NEC");
for my $subjectId (keys %necTimes){
  my @necs = sort {$a->[0] cmp $b->[0]} @{$necTimes{$subjectId}};
  my ($firstNecStart, $firstNecEnd) = @{$necs[0]};
  for my $srr (@{$srrsBySubject{$subjectId}}){
     my $dol = $dolsBySrr{$srr};

     if ($dol <= $firstNecStart){
        $dataBySrr{$srr}{days_to_first_NEC} = $firstNecStart - $dol;
     }
     for my $nec (@necs){
        my ($necStart, $necEnd) = @{$nec};
        if ($dol >= $necStart && ($necEnd eq 'unk' || $necEnd eq '?' || $dol <= $necEnd)){
           $dataBySrr{$srr}{day_of_NEC} = $dol - $necStart + 1;
        }
     }
  }
}
my $skip = '
push @sampleHeaders, ("antibiotics_reason_when_sample_taken");
for my $subjectId (keys %antibioticsReasons){
  for my $srr (@{$srrsBySubject{$subjectId}}){
    my $dol = $dolsBySrr{$srr};
    my @reasons = map {
      my ($reasonStart, $reasonEnd, $reason) = @{$_};
       ($dol >= $reasonStart && $dol <= $reasonEnd)
         ? $reason
         : ()
       } @{$antibioticsReasons{$subjectId}};
    if(@reasons){
      my %reasons;
      $reasons{$_}++ for @reasons;
      $dataBySrr{$srr}{antibiotics_reason_when_sample_taken} = join (", ", sort keys %reasons);
    }
  }
}
';
for my $antibioticName (@antibioticNames){
  push @sampleHeaders, "sample_${antibioticName}";
  for my $subjectId (keys %{$antibioticTimes{$antibioticName}}){
    for my $srr (@{$srrsBySubject{$subjectId}}){
      my $dol = $dolsBySrr{$srr};
      for my $antibioticTime (@{$antibioticTimes{$antibioticName}{$subjectId}}){
         my ($antibioticStart, $antibioticEnd) = @{$antibioticTime};
         if ($dol >= $antibioticStart && $dol <= $antibioticEnd){
            $dataBySrr{$srr}{"sample_${antibioticName}"} = "Y";
         }
      }
    }
  }
}
my @extraKeys = qw/body_product body_site host_common_name sample_type body_habitat env_feature/;
my @extraValues = qw/UBERON:feces colon Human Stool colon Human/;
say join "\t", ("name", "description","subject_id", "age", @extraKeys, @subjectHeaders, @sampleHeaders); 
for my $subjectId (sort {$a <=> $b} keys %srrsBySubject){
  for my $srr (sort {$dolsBySrr{$a} <=> $dolsBySrr{$b}} @{$srrsBySubject{$subjectId}}){
    my $dol = $dolsBySrr{$srr};
    say join "\t", (
      $srr, "Infant $subjectId, $dol days", $subjectId, "$dol days",
      @extraValues,
      (map {$dataBySubject{$subjectId}{$_} // ""} @subjectHeaders),
      (map {$dataBySrr{$srr}{$_} // ""} @sampleHeaders),
    );
  }
}
