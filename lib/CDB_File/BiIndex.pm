#!/usr/bin/perl -w

package CDB_File::BiIndex;
use vars qw($VERSION);

$VERSION = '0.017';

=head1 NAME

CDB_File::BiIndex - index two sets of values against eachother.

=head1 SYNOPSIS

	use CDB_File::BiIndex;
	#test bi-index is initiated with CDB_Generator
	$index = new CDB_File::BiIndex "test";

	$index->lookup_first("USA");
	$index->lookup_second("Lilongwe");

=head1 DESCRIPTION

A CDB_File::BiIndex stores a set of relations from one set of strings to
another.  It's rather similar to a translators dictionary with a list
of words in one language linked to words in the other language.  The
same word can occur in each language, but it's translations would often
be different.

    I    <->  je
    {bar, pub}  <->  bar 
    {truck, lorry, heavy goods vehicle} <-> camion

In this implementation it's just two parallel cdb hashes, which you
have to generate in advance.

=head1 EXAMPLE


    use CDB_File::BiIndex::Generator;
    use CDB_File::BiIndex;
    $gen = new CDB_File::BiIndex::Generator "test";

    $gen->add_relation("John", "Jenny");
    $gen->add_relation("Roger", "Beth");
    $gen->add_relation("John", "Gregory");
    $gen->add_relation("Jemima", "Jenny")
    $gen->add_relation("John", "Gregory");

    $gen->finish();

    $index = new CDB_File::BiIndex::Generator "test";

    $index->lookup_first("Roger");
	["Jenny"]
    $index->lookup_second("Jenny");
	["John", "Jemima"]
    $index->lookup_second("John");
	[]
    $index->lookup_first("John");
	["Jenny", "Gregory"]


=cut

use Fcntl;
use CDB_File 0.86; # there are serious bugs in previous versions
use Carp;
use Data::Dumper;
use strict;

$CDB_File::BiIndex::verbose=0; #no debugging messages
#$CDB_File::BiIndex::verbose=0xffff; #all debugging messages

=head1 METHODS

=head2 new

	new (CLASS, database_filenamebase)
	new (CLASS, first_database_filename, second_database_filename)

New opens and sets up the databases.

=cut

#FIXME.  This should be generalised so it works on any pair of hashes.
#which is very easy.

sub new ($$;$) {
  my $class=shift;
  my $self=bless {}, $class;

  #work out what the arguments mean.. 
  my $first_db_name = shift;
  carp "usage new CDB_File::BiIndex (<file>, [<file>])"
    unless defined $first_db_name;
  my $second_db_name;
  if (@_) {
    $second_db_name = shift ;
  } else {
    $second_db_name = $first_db_name . ".2-1";
    $first_db_name = $first_db_name . ".1-2";
  }

  $self->{"first_cdb"} = tie my %first_hash, "CDB_File", $first_db_name
    or die $!;
  $self->{"first_hash"} = \%first_hash;
  $self->{"second_cdb"} = tie my %second_hash, "CDB_File", $second_db_name
    or die $!;
  $self->{"second_hash"} = \%second_hash;
  return $self;
}


=head2 lookup_first lookup_second (key)

returns the list of values which are indexed against key, direction of
the relation depending on which function is used.

=cut


sub lookup_first ($$) {
  my ($self, $key)=@_;
  print STDERR "lookup_first has been called with key $key\n"
    if $CDB_File::BiIndex::verbose & 32;

  my $return=$self->{"first_cdb"}->multi_get($key);
  #FIXME: all this testing is needless cruft that should go away once 
  #we have a statement from Tim about how CDB_File should behave.  
  return undef unless defined $return;
  die "multi_get didn't return and array ref" unless
      (ref $return) =~ m/ARRAY/;
  return undef unless @$return;
  return $return;
}

sub lookup_second ($$) {
  my ($self, $key)=@_;
  print STDERR "lookup_second has been called with key $key\n"
    if $CDB_File::BiIndex::verbose & 32;
  
  my $return=$self->{"second_cdb"}->multi_get($key);
  #FIXME: all this testing is needless cruft that should go away once 
  #we have a statement from Tim about how CDB_File should behave.  
  return undef unless defined $return;
  die "multi_get didn't return and array ref" unless
      (ref $return) =~ m/ARRAY/;
  return undef unless @$return;
  return $return;
}

# =head1 validate

# Because the two indexes match eachother, they should make sense
# together.  Anything which is indexed under a key in the first index
# should be a key in the second index with a the original key part of
# its value

# =cut

# sub validate {
#   my $self=shift;
#   if ( validate_against($self->{"first_cdb"},$self->{"second_cdb"}) 
#       || validate_against($self->{"second_cdb"},$self->{"first_cdb"}) ) {
#       return 0; #the validation procedures found faults
#   } else {
#       return 1; #validated okay.
#   }
# }

# sub validate_against{
#   my $cdb_one = shift;
#   die "non cdb passed as validate_against first arg" 
#       unless ref($cdb_one);
#   my $cdb_two = shift;
#   die "non cdb passed as validate_against second arg" 
#       unless ref($cdb_two);

#   my $break_count = 0;

#   #reset the iteration
#   $cdb_one->start_iter();
#   #loop through all of the entries in the first cdb
#   my ($key,$value);
#  RELATION: while (($key,$value) = $cdb_one->iterate()) {
#     unless ($cdb_two->set_position($value)) {
#       warn "Relation $key to $value in #1, but not $value as key in #2";
#       $break_count++;
#       next RELATION;
#     }
#     my ($rkey, $rvalue);
#   CHECK: while (($rkey, $rvalue) = $cdb_two->iterate()) {
#       last CHECK unless $rkey=$value;
#       next RELATION if $rvalue=$key;
#     }
#     warn "Relation $key to $value in #1, but $key not in " 
# 	  . $value . "'s record in #2";
#     $break_count++;
#   }
#   return $break_count;
# }

=head1 Iterators

The iterators iterate over the different keys in the database.  They
skip repeated keys.

=cut

sub first_reset ($) {
  print STDERR "first_reset called\n"
    if $CDB_File::BiIndex::verbose & 32;
  my $self=shift;
  my $a=scalar keys %{$self->{"first_hash"}}; 
  delete $self->{"first_lastkey"};
}

sub first_first ($) {
  print STDERR "first_first called\n"
    if $CDB_File::BiIndex::verbose & 32;
  my $self=shift;
  $self->first_reset();
  my $key =  $self->{"first_cdb"}->FIRSTKEY();
  $self->{"first_lastkey"}=$key;
  return $key;
}

sub first_next ($) {
  my $self=shift;
  print STDERR "first_next has been called\n"
    if $CDB_File::BiIndex::verbose & 32;
  croak "first_next called without first_first" 
    unless defined $self->{"first_lastkey"};
  #CDB_File danger

  my $lastkey=$self->{"first_lastkey"};
  my $key=$lastkey;

 KEY: while (1) {
    $key=$self->{"first_cdb"}->NEXTKEY($key);
    defined $key or last KEY;
    $key eq $lastkey or last KEY;
    print STDERR "repeat of last key $key. skipping.\n"
      if $CDB_File::BiIndex::verbose & 128;
    $key =  $self->{"first_cdb"}->NEXTKEY($key);
  }
  ( $CDB_File::BiIndex::verbose & 64 ) && do {
    print STDERR "returning key $key\n" if defined $key ;
    print STDERR "returning undefined key \n" unless defined $key;
  };
  $self->{"first_lastkey"}=$key;
  return $key;
}

sub first_iterate ($) {
  my $self=shift;
  print STDERR "first_iterate has been called\n"
    if $CDB_File::BiIndex::verbose & 32;
  return $self->first_next() if defined $self->{"first_lastkey"};
  return $self->first_first();
}

sub first_set_iterate ($$) {
  my $self=shift;
  print STDERR "first_set_iterate has been called\n"
    if $CDB_File::BiIndex::verbose & 32;
  $self->{"first_lastkey"}=shift;
}

sub second_reset ($) {
  print STDERR "second_reset called\n"
    if $CDB_File::BiIndex::verbose & 32;
  my $self=shift;
  my $a=scalar keys %{$self->{"second_hash"}}; 
  delete $self->{"second_lastkey"};
}

sub second_first ($) {
  print STDERR "second_first called\n"
    if $CDB_File::BiIndex::verbose & 32;
  my $self=shift;
  $self->second_reset();
  my $key =  $self->{"second_cdb"}->FIRSTKEY();
  $self->{"second_lastkey"}=$key;
  return $key;
}

sub second_next ($) {
  my $self=shift;
  print STDERR "second_next has been called\n"
    if $CDB_File::BiIndex::verbose & 32;
  croak "second_next called without second_first"
    unless defined $self->{"second_lastkey"};
  #CDB_File danger

  my $lastkey=$self->{"second_lastkey"};
  my $key=$lastkey;

 KEY: while (1) {
    $key=$self->{"second_cdb"}->NEXTKEY($key);
    defined $key or last KEY;
    $key eq $lastkey or last KEY;
    print STDERR "repeat of last key $key. skipping.\n"
      if $CDB_File::BiIndex::verbose & 128;
    $key =  $self->{"second_cdb"}->NEXTKEY($key);
  }
  ( $CDB_File::BiIndex::verbose & 64 ) && do {
    print STDERR "returning key $key\n" if defined $key ;
    print STDERR "returning undefined key \n" unless defined $key;
  };
  $self->{"second_lastkey"}=$key;
  return $key;
}

sub second_iterate ($) {
  my $self=shift;
  print STDERR "second_iterate has been called\n"
    if $CDB_File::BiIndex::verbose & 32;
  return $self->second_next() if defined $self->{"second_lastkey"};
  return $self->second_first();
}

sub second_set_iterate ($$) {
  my $self=shift;
  print STDERR "second_set_iterate has been called\n"
    if $CDB_File::BiIndex::verbose & 32;
  $self->{"second_lastkey"}=shift;
}

=head1 COPYING

This module may be distributed under the same terms as perl.

=cut


1; #what does it prove...
