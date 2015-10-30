package PerWRL::Test;
use 5.20.2;
use strict;

BEGIN {
	unless( defined $PerlWRL::Test::ALL ) {
		use Test::More;
		eval('use constant libDir => qw(lib)');
	} 
}

$PerlWRL::Test::ColorMap = sub {	
	if( $PerWRL::Test::POD ) {
		pod_file_ok(libDir .'/VRML/ColorMap.pm');
	}
};

unless( defined $PerlWRL::Test::ALL ) {
	eval('use Test::Pod');
	$PerWRL::Test::POD = 1; 	# Test POD docs by default
	$PerWRL::Test::POD = 0 
		if(  "$@" ); 			# Skip POD docs if Test::Pod is not available;
	&$PerlWRL::Test::ColorMap;

	done_testing();
}
