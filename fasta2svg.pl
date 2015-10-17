#!/usr/bin/perl

# fasta2svg.pl -- converts a fasta sequence to a colour-coded
# sequence.
#
# Homopolymer regions of a specified length are used to define colour
# region borders. The homopolymers themselves are coloured using the
# standard electropherogram colours for bases:
#
# A -- Green  C -- Blue
# G -- Yellow T -- Red
#
# Regions between homopolymer sequences are coded in the RGB space
# with each of the three components defined based on the proportion of
# the three possible binary divisions of bases:
#
# R component: M proportion (i.e. AC ratio) [alternate colour cyan]
# G component: Y proportion (i.e. TC ratio) [alternate colour magenta]
# B component: S proportion (i.e. GC ratio) [alternate colour yellow]
#
# These colours can be presented as-is, or scaled based on the
# observed range (or distribution) of proportions. The effect of
# proportion scaling would be an increase in the colour saturation of
# regions between homopolymer sequences.
#
# Copyright 2015, David Eccles (gringer) <bioinformatics@gringene.org>
#
# Permission to use, copy, modify, and/or distribute this software for
# any purpose with or without fee is hereby granted. The software is
# provided "as is" and the author disclaims all warranties with regard
# to this software including all implied warranties of merchantability
# and fitness. The parties responsible for running the code are solely
# liable for the consequences of code excecution.

use warnings;
use strict;

use Getopt::Long qw(:config auto_version auto_help pass_through); # for option parsing

my $hpLength = 1;

GetOptions('hplength=i' => \$hpLength) or
  die("Error in command line arguments");

my $seq = "";
my $seqCount = 1;
my $seqID = "";

print("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n");
print("<svg xmlns:svg=\"http://www.w3.org/2000/svg\" version=\"1.1\">\n");


while(<>){
  chomp;
  if(/^>(.+)$/){
    my $newID = $1;
    if($seq){
      drawSeq($seq, $seqID, $seqCount);
      $seqCount++;
    }
    $seq = "";
    $seqID = $newID;
  } else {
    $seq .= $_;
  }
}

if($seq){
  drawSeq($seq, $seqID, $seqCount);
}

print("</svg>\n");

sub comp{
  my ($tSeq) = @_;
  $tSeq =~ tr/ACGT/TGCA/;
  return($tSeq);
}

sub drawSeq{
  my ($tSeq, $tSeqID, $tSeqCount) = @_;
  my %hpCols = ( A => "#00FF00", C => "#0000FF", G=> "#FFFF00", T=> "#FF0000");
  $tSeq = substr($tSeq,0,100); # only show first 100 bases for testing purposes
  my $tSeqC = comp($tSeq);
  printf(" <g id=\"%s\">\n", $tSeqID);
  my $xp = 5;
  printf("  <g id=\"%s_FWD\">\n", $tSeqID);
  while($tSeq =~ s/^(A{1}|C{1}|G{1}|T{1})//){
    my $hpSeq = $1;
    my $hpBase = substr($hpSeq,0,1);
    printf("   <path stroke=\"%s\" d=\"M%s,%s l%s,0\" />\n",
           $hpCols{$hpBase}, $xp, $tSeqCount*5+1, length($hpSeq));
    $xp += length($hpSeq);
  }
  printf("  </g>\n");
  $xp = 5;
  printf("  <g id=\"%s_REV\">\n", $tSeqID);
  while($tSeqC =~ s/^(A{1}|C{1}|G{1}|T{1})//){
    my $hpSeq = $1;
    my $hpBase = substr($hpSeq,0,1);
    printf("   <path stroke=\"%s\" d=\"M%s,%s l%s,0\" />\n",
           $hpCols{$hpBase}, $xp, $tSeqCount*5-1, length($hpSeq));
    $xp += length($hpSeq);
  }
  printf("  </g>\n");
  printf(" </g>\n");
}