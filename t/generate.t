#!/usr/bin/perl -w

BEGIN {print "1..7\n"}
END {print "not ok 1\n" unless $loaded;}

use Carp;
use CDB_File::Generator;
$loaded=1;

sub ok ($) {my $t=shift; print "ok $t\n";}
sub nogo () {print "not "}

#unlink any existing my.cdb
(! (-e "my.cdb") or unlink "my.cdb")
   or die "Couldn't get rid of the existing database";
$gen = new CDB_File::Generator "my.cdb" or nogo;
ok(1);
@keyval = 
  ( en => "Hello",
    us => "hi",
    us => "howdy",
    us => "yo",
    oz => "g'day",
  );

@checkval = 
  ( en => "Hello",
    oz => "g'day",
    us => "hi",
    us => "howdy",
    us => "yo",
  );


while (@keyval) {
  ($key, $value, @keyval) = @keyval;
  $gen->add($key,$value);
}

ok(2);
$gen->finish;
undef $gen;
-e 'my.cdb' or nogo;
ok(3);

use CDB_File;
use vars qw($tst);

$tst = tie %test_hash, "CDB_File", "my.cdb" or nogo;
ok(4);

$test_hash{"en"} eq "Hello" or nogo;
ok(5);

$test_hash{"us"} eq "hi" or nogo;
ok(6);

# this assumes a version of CDB_File which handles multiple keys by
# iterating to the next one.  On version 0.5 this test WILL FAIL.

use vars qw($a);
$a = scalar keys %test_hash;
my ($key, $value);
while ( ($key, $value) = each %test_hash ){
  (my ($ckey, $cvalue), @checkval) = @checkval;
  unless ($key eq $ckey and $value eq $cvalue) {
    print "not ";
    last;
  }
}
ok(7);
