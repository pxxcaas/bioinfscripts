#!/usr/bin/perl

## kmer dotplot -- creates a self-vs-self dotplot of a sequence using
## kmer sequences, outputs a PNG file to standard out
## example usage: ~/scripts/fastx-kdotplot.pl -s 300 -k 13 out_sseq.fa | \
##                convert png:- -resize 1000x1000 - > repeat_region.png
## Detected patterns:
##  * Forward copies (repeats)
##  * Reverse copies
##  * Reverse-complement copies
## Sequencing types (-t <type>):
##  * ACGT - no change
##  * KM - modify base sequence to K/M binary classification
##  * SW - modify base sequence to S/W binary classification
##  * RY - modify base sequence to R/Y binary classification

use warnings;
use strict;

use GD; ## for images
use Getopt::Long qw(:config auto_help pass_through);

sub rc {
  my ($seq) = @_;
  # assume input is upper-case
  $seq =~ tr/ACGTUYRSWMKDVHBXN-/TGCAARYSWKMHBDVXN-/;
  return(scalar(reverse($seq)));
}

sub comp {
  my ($seq) = @_;
  # assume input is upper-case
  $seq =~ tr/ACGTUYRSWMKDVHBXN-/TGCAARYSWKMHBDVXN-/;
  return($seq);
}

sub rev {
  my ($seq) = @_;
  return(scalar(reverse($seq)));
}

my $size = 1024;
my ($sizeX, $sizeY) = (0,0);
my $subseq = "";
my @region = ();
my $defaultKmerLength = 17;
my $kmerLength = -1; ## number of bases in hash keys
my $blockPicture = 0; ## false
my $hLines = ""; ## horizontal lines
my $type = "ACGT"; ## search type
my $catSeps = "";
my $catStart = 0;
my $catEnd = 0;
my %catKmerCounts = ();

GetOptions("kmer=i" => \$kmerLength, "size=s" => \$size,
	   "hlines=s" => \$hLines, "type=s" => \$type,
	   "categorise=s" => \$catSeps,
           "region=s" => \$subseq, "altview!" => \$blockPicture ) or
  die("Error in command line arguments");

if($size =~ /^([0-9]+)x([0-9]+)$/){
  $sizeX = $1;
  $sizeY = $2;
} else {
  $sizeX = $size;
  $sizeY = $size;
}

if($catSeps){
  ($catStart, $catEnd) = split(/[,;\-]/, $catSeps);
  ($catStart, $catEnd) = (log($catStart), log($catEnd));
}

if($kmerLength == -1){ ## Default length
  $kmerLength = ($type eq "ACGT") ? $defaultKmerLength : ($defaultKmerLength+5);
}

## simplify search-type logic searches later on
$type =~ s/([YMW])([RKS])/$2$1/;
$type =~ s/[ACGT]{4}/ACGT/;

if($subseq){
  @region = split(/\-/, $subseq);
  print(STDERR $region[0], " - ", $region[1], "\n");
}

my @rlengths = ();
my $inQual = 0; # false
my $seqID = "";
my $qualID = "";
my $seq = "";
my $qual = "";
my $buffer = "";

my $im = new GD::Image($sizeX,$sizeY);

my $white = $im->colorAllocate(255,255,255);
my $black = $im->colorAllocate(0,0,0);
my $red = $im->colorAllocate(0x8b,0,0);
my $green = $im->colorAllocate(0,0xA0,0);
my $blue = $im->colorAllocate(0,0,255);
my $darkRed = $im->colorAllocate(0x6b,0,0);
my $darkGreen = $im->colorAllocate(0,0x80,0);
my $darkBlue = $im->colorAllocate(0,0,0xa0);
my $yellow = $im->colorAllocate(0xa0,0x90,0);
my $magenta = $im->colorAllocate(0x90,0,0xa0);
my $cyan = $im->colorAllocate(0,0xa0,0x90);
my $orange = $im->colorAllocate(0xff,0x7f,0x00);
my $salmon = $im->colorAllocate(0xfd,0xc0,0x86);
my $grey = $im->colorAllocate(0x70,0x70,0x70);

$im->setThickness(3);

while(<>){
  chomp;
  chomp;
  if(!$inQual){
    if(/^(>|@)((.+?)( .*?\s*)?)$/){
      my $newSeqID = $2;
      my $newShortID = $3;
      my $len = length($seq);
      my $logLen = ($len == 0) ? 1 : log($len);
      my $ppb = ($sizeX > $len) ? 1 : $sizeX / $len; # pixels per base
      my $ppl = $sizeY / $logLen; # pixels per log
      my $sseq = "";
      if($seqID && (length($seq) > $kmerLength)){
        if($subseq){
          $seq = substr($seq, $region[0], ($region[1]-$region[0]));
          $len = length($seq);
	  $logLen = ($len == 0) ? 0 : log($len);
          $ppb = ($sizeX > $len) ? 1 : $sizeX / $len;
          $ppl = $sizeY / $logLen;
        }
	if($hLines){
	  my @poss = split(/[,; ]/, $hLines);
	  foreach my $pos (@poss){
	    if($blockPicture){
	      $im->line(0, $sizeY - log($pos) * $ppl,
			$sizeX, $sizeY - log($pos) * $ppl, $grey);
	    }
	  }
	}
        my $countTotal = 0;
        my $countMax = 0;
	my $dist = 0;
        my $maxKmer = "";
	my @rptCounts = ();
	my %posHash = ();
        my %gapCounts = ();
        $seq =~ tr/a-z/A-Z/;
	if($type eq "RY") {
	  $seq =~ tr/ACGT/RYRY/;
	} elsif($type eq "KM") {
	  $seq =~ tr/ACGT/MMKK/;
	} elsif($type eq "SW") {
	  $seq =~ tr/ACGT/WSSW/;
	}
	$seq =~ tr/ACGTUYRSWMKDVHBXN//cd; # remove any non-base characters
	printf(STDERR "$seqID | Sequence length: %d\n", length($seq));
	for(my $p = $len; $p >= $kmerLength; $p--){
          my $sseq = substr($seq, $p-$kmerLength, $kmerLength);
          if($sseq !~ /N/){ # ignore kmers containing N
            push(@{$posHash{$sseq}}, $p);
          }
	}
	printf(STDERR "Done indexing\n");
	foreach my $kmer (keys(%posHash)){
	  my @posList = @{$posHash{$kmer}};
          foreach my $x (@posList){
	    foreach my $y (@posList){
	      if($blockPicture){
		if($x != $y){
		  $dist = log(abs($x - $y));
		  if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
		    $catKmerCounts{$kmer}++;
		  }
		  $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $red);
		  $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $magenta);
		}
	      } else {
		$im->setPixel($x * $ppb, $y * $ppb, $red);
	      }
	    }
          }
	}
	## make sure reverse and reverse complement explicitly overwrite
	foreach my $kmer (keys(%posHash)){
	  my @posList = @{$posHash{$kmer}};
          foreach my $x (@posList){
	    if($type ne "SW"){
	      foreach my $y (grep {$_ < $x} (@{$posHash{comp($kmer)}})){
		if($blockPicture){
		  if($x != $y){
		    $dist = log(abs($x - $y));
		    if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
		      $catKmerCounts{$kmer}++;
		    }
		    $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $salmon);
		    $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $orange);
		  }
		} else {
		  $im->setPixel($x * $ppb, $y * $ppb, $orange);
		}
	      }
	    }
	    foreach my $y (grep {$_ < $x} (@{$posHash{rc($kmer)}})){
	      if($blockPicture){
		if($x != $y){
		  $dist = log(abs($x - $y));
		  if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
		    $catKmerCounts{$kmer}++;
		  }
		  $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $blue);
		  $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $cyan);
		}
	      } else {
		$im->setPixel($x * $ppb, $y * $ppb, $blue);
	      }
	    }
	    if($type ne "SW"){
	      foreach my $y (grep {$_ > $x} (@{$posHash{rev($kmer)}})){
		if($blockPicture){
		  if($x != $y){
		    $dist = log(abs($x - $y));
		    if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
		      $catKmerCounts{$kmer}++;
		    }
		    $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $green);
		    $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $yellow);
		  }
		} else {
		  $im->setPixel($x * $ppb, $y * $ppb, $green);
		}
	      }
	    }
          }
	}
      }
      $seq = "";
      $qual = "";
      $buffer = "";
      $seqID = $newSeqID;
    } elsif(/^\+(.*)$/) {
      $inQual = 1; # true
      $qualID = $1;
    } else {
      $seq .= $_;
    }
  } else {
    $qual .= $_;
    if(length($qual) >= length($seq)){
      $inQual = 0; # false
    }
  }
}

my $len = length($seq);
my $logLen = ($len == 0) ? 1 : log($len);
my $ppb = ($sizeX > $len) ? 1 : $sizeX / $len;
my $ppl = $sizeY / $logLen;
my $sseq = "";
if($seqID && (length($seq) > $kmerLength)){
  if($subseq){
    $seq = substr($seq, $region[0], ($region[1]-$region[0]));
    $len = length($seq);
    $logLen = ($len == 0) ? 0 : log($len);
    $ppb = ($sizeX > $len) ? 1 : $sizeX / $len;
    $ppl = $sizeY / $logLen;
  }
  if($hLines){
    my @poss = split(/[,; ]/, $hLines);
    foreach my $pos (@poss){
      if($blockPicture){
	$im->line(0, $sizeY - log($pos) * $ppl,
		  $sizeX, $sizeY - log($pos) * $ppl, $grey);
      }
    }
  }
  my $countTotal = 0;
  my $countMax = 0;
  my $dist = 0;
  my $maxKmer = "";
  my @rptCounts = ();
  my %posHash = ();
  my %gapCounts = ();
  $seq =~ tr/a-z/A-Z/;
  if($type eq "RY") {
    $seq =~ tr/ACGT/RYRY/;
  } elsif($type eq "KM") {
	  $seq =~ tr/ACGT/MMKK/;
  } elsif($type eq "SW") {
    $seq =~ tr/ACGT/WSSW/;
  }
  $seq =~ tr/ACGTUYRSWMKDVHBXN//cd; # remove any non-base characters
  printf(STDERR "$seqID | Sequence length: %d\n", length($seq));
  for(my $p = $len; $p >= $kmerLength; $p--){
    my $sseq = substr($seq, $p-$kmerLength, $kmerLength);
    if($sseq !~ /N/){ # ignore kmers containing N
      push(@{$posHash{$sseq}}, $p);
    }
  }
  printf(STDERR "Done indexing\n");
  printf(STDERR "Drawing repeated kmers (2 iterations)\n");
  printf(STDERR "[".("-" x 48)."]\n");
  my $dones = 0;
  my $lastPct = 0;
  foreach my $kmer (keys(%posHash)){
    $dones++;
    if($lastPct < int($dones / scalar(keys(%posHash)) * 50)){
      print(STDERR ".");
      $lastPct = int($dones / scalar(keys(%posHash)) * 50);
    }
    my @posList = @{$posHash{$kmer}};
    foreach my $x (@posList){
      foreach my $y (@posList){
	if($blockPicture){
	  if($x != $y){
	    $dist = log(abs($x - $y));
	    if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
	      $catKmerCounts{$kmer}++;
	    }
	    $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $red);
	    $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $magenta);
	  }
	} else {
	  $im->setPixel($x * $ppb, $y * $ppb, $red);
	}
      }
    }
  }
  print(STDERR "\n");
  ## make sure complement, reverse and reverse complement explicitly overwrite
  $dones = 0;
  $lastPct = 0;
  foreach my $kmer (keys(%posHash)){
    $dones++;
    if($lastPct < int($dones / scalar(keys(%posHash)) * 50)){
      print(STDERR ".");
      $lastPct = int($dones / scalar(keys(%posHash)) * 50);
    }
    my @posList = @{$posHash{$kmer}};
    foreach my $x (@posList){
      if($type ne "SW"){
	foreach my $y (grep {$_ < $x} (@{$posHash{comp($kmer)}})){
	  if($blockPicture){
	    if($x != $y){
	      $dist = log(abs($x - $y));
	      if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
		$catKmerCounts{$kmer}++;
	      }
	      $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $salmon);
	      $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $orange);
	    }
	  } else {
	    $im->setPixel($x * $ppb, $y * $ppb, $orange);
	  }
	}
      }
      foreach my $y (grep {$_ < $x} (@{$posHash{rc($kmer)}})){
	if($blockPicture){
	  if($x != $y){
	    $dist = log(abs($x - $y));
	    if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
	      $catKmerCounts{$kmer}++;
	    }
	    $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $blue);
	    $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $cyan);
	  }
	} else {
	  $im->setPixel($x * $ppb, $y * $ppb, $blue);
	}
      }
      if($type ne "SW"){
	foreach my $y (grep {$_ > $x} (@{$posHash{rev($kmer)}})){
	  if($blockPicture){
	    if($x != $y){
	      $dist = log(abs($x - $y));
	      if($catStart && ($dist >= $catStart) && ($dist <= $catEnd)){
		$catKmerCounts{$kmer}++;
	      }
	      $im->setPixel($x * $ppb, $sizeY - $dist * $ppl, $green);
	      $im->setPixel($y * $ppb, $sizeY - $dist * $ppl, $yellow);
	    }
	  } else {
	    $im->setPixel($x * $ppb, $y * $ppb, $green);
	  }
	}
      }
    }
  }
  print(STDERR "\n");
}

if($catStart){
  my $catLimit = 10;
  printf(STDERR "%d most abundant kmers in search band:\n", 
	 scalar(keys(%catKmerCounts)));
  foreach my $kmer (sort {$catKmerCounts{$b} <=> $catKmerCounts{$a}} 
		    keys(%catKmerCounts)){
    if($catLimit-- > 0){
      printf(STDERR "%s %d\n", $kmer, $catKmerCounts{$kmer});
    }
  }
}

# make sure we are writing to a binary stream
binmode STDOUT;

# Convert the image to PNG and print it on standard output
print $im->png;
