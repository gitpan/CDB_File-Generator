#!/usr/bin/perl

=head1 NAME 

addword - add a word translation to the translators dictionary.

=head1 DESCRIPTION

This is a little sample program which will add a word to the
translators dictionary between English and Polish.  

=cut

use BiIndex;

my $english=shift;
my $polish=shift;
die "Give english followed by Polish.\n" unless $polish;
die "Give only two words (English then Polish\n" if @ARGV;

my $index=new BiIndex "english-polish", "polish-english"; 
$index->add_relation($english, $polish);
