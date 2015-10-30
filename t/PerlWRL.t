# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl PerlWRL.t'

#########################

package PerWRL::Test;
use 5.20.2;
use strict;

# change 'tests => 1' to 'tests => last_test_to_print';
use Test::More;
use constant libDir => '../lib';

BEGIN {
	chdir 't' if -d 't'; 		# Change to the test directory
	use lib libDir;			# Set the location of the library
	use_ok('PerlWRL'); 			# Test that library loads
	$PerlWRL::Test::ALL = 1;
	
	eval('use Test::Pod');
	$PerWRL::Test::POD = 1; 	# Test POD docs by default
	$PerWRL::Test::POD = 0 
		if(  "$@" ); 			# Skip POD docs if Test::Pod is not available;
}

if( $PerWRL::Test::POD ) {
	pod_file_ok(libDir .'/PerlWRL.pm');
	pod_file_ok(libDir .'/PerlWRL/vrml.pm');
}

require_ok('VRML/ColorMap.t');
&$PerlWRL::Test::ColorMap();

done_testing();

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

