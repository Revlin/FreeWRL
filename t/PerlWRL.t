# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl PerlWRL.t'

#########################

package PerWRL::Test;
use 5.20.2;
use strict;

use Test::More;
use constant libDir => '../lib';

BEGIN {
	chdir 't' if -d 't'; 		# Change to the test directory
	use lib libDir;				# Set the location of the library
	use_ok('PerlWRL'); 			# Test that library loads
	$PerlWRL::Test::ALL = 1;
	
	eval('use Test::Pod');
	$PerWRL::Test::POD = 1; 	# Test POD docs by default
	$PerWRL::Test::POD = 0		# Skip POD docs if Test::Pod is not available
		if(  "$@" );
}

if( $PerWRL::Test::POD ) {
	pod_file_ok(libDir .'/PerlWRL.pm');
}

require_ok('PerlWRL/vrml.t');
&$PerlWRL::Test::vrml();

done_testing();
