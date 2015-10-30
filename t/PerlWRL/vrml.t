package PerWRL::Test;
use 5.20.2;
use strict;

BEGIN {
	unless( defined $PerlWRL::Test::ALL ) {
		use Test::More;
		eval('use constant libDir => qw(lib)');
		eval('use Test::Pod');
		$PerWRL::Test::POD = 1; 	# Test POD docs by default
		$PerWRL::Test::POD = 0 		# Skip POD docs if Test::Pod is not available
			if(  "$@" ); 
	} 
}

$PerlWRL::Test::vrml = sub {	
	if( $PerWRL::Test::POD ) {
		pod_file_ok(libDir .'/PerlWRL/vrml.pm');
	}
};

unless( defined $PerlWRL::Test::ALL ) {
	&$PerlWRL::Test::vrml;

	done_testing();
}
