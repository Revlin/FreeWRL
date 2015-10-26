#!/usr/bin/env perl
use 5.10.1;
use strict;
use warnings;

use lib 'lib';
use PerlWRL::vrml;

if( defined $ARGV[0] && $ARGV[0] =~ /see/ && PerlWRL::vrml->see($ARGV[1]) ) {

} else {
    print <<INSTRUCTIONS;
    'see' a PerlWRL(.pwrl):\n
    Ex.
        ./vrml.pl see first

INSTRUCTIONS

}
