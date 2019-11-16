#!/usr/bin/env perl
use 5.20.2;
use strict;
use warnings;

use lib 'lib';
use PerlWRL::vrml;

sub instructions {
    print <<INSTRUCTIONS;
    'see' a PerlWRL(.pwrl):\n
    Ex.
        examine world/first.pwrl

INSTRUCTIONS

	exit 0;
}

instructions() unless( defined $ARGV[0] && PerlWRL::vrml->examine(+shift) );
