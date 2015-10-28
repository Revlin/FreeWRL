package VRML::ColorMap;
use feature qw(postderef);

=encoding utf8

=head1 NAME

VRML::ColorMap - Generate Index From RGB Color List

=head1 SYNOPSIS

	use VRML::ColorMap;

	VRML::ColorMap::loadCoordFromFile('coord.txt');

	VRML::ColorMap::loadColorFromFile('color-set.txt');

	VRML::ColorMap::mapColorsToCoords("heightMap"); # Output 'color.txt'

	VRML::ColorMap::loadCoordIndexFromFile('coordIndex.txt');

	VRML::ColorMap::mapColorToFaces(); # Output 'colorIndex.txt' 
	

=head1 DESCRIPTION

	The methods in this module require two arrays as input and produce a third 
	array as output. The first input array is a set of references to interger
	quartets, each of which represents a polygonal faces. The second input array 
	is a set of references to normalized floating-point (3D) vectors, each of 
	which represents a color in RGB space (i.e. 1.0, 0.5, 0.5). The output array 
	is a set of interger indeces, each representing an index for an element in the 
	array of RGB colors. The output array of indeces should have exactly as many 
	elements as the input array of coordinates indeces.

=head1 ATTRIBUTES

=head2 @coord 

=head2 @coordIndex

=head2 @color  

=head2 @colorIndex 

=head2 $minHeight 

=head2 $maxHeight

=cut

my( @coord, @coordIndex, @color, @colorIndex, $minHeight, $maxHeight ); 

=head1 METHODS

=head2 loadCoordFromFile( $filename )

	Loads a file of the same name/path as the value of $filename and parses 
	the file line-by-line for VRML Coordinate data. The entire data set should 
	be delimited by square brackets and formatted as trios of floating-point 
	values. Commas between each value are optional and will be ignored. Each 
	line is passed to parse3FVectorArray which assigns an array reference for 
	each floating-point triplet to a new element of the @coord array.

=cut

sub loadCoordFromFile( $ ) {
	my $filename = shift;
	my $fh;
	my $start = 0;
	my $end = 0;
	open $fh, '<', $filename;
	while(<>) {
		if( $_ =~ /\[/ ) {
			# Inside the coord array block
			$start = 1;
		}
		if( $start && !$end) {
			parse3FVectorArray(\@coord, $_);
			
			$minHeight = $coord[$#coord]->[2] if( @coord > 0 && !$minHeight );			
			if( @coord > 1 ) {
				$minHeight = $coord[$#coord]->[2] if( $coord[$#coord]->[2] < $minHeight ); 
			}
			
			$maxHeight = $coord[$#coord]->[2] if( @coord > 0 && !$maxHeight );
			if( @coord > 1 ) {
				$maxHeight = $coord[$#coord]->[2] if($coord[$#coord]->[2] > $maxHeight ); 
			}
		}
		if( $_ =~ /\]/ ) {
			# Outside the coord array block
			$end = 1;
			last;
		}
	}
#	print "coord: ", join(" ", $_->@*), "\n" for @coord;
	print "Number of coords: ", ($#coord + 1), "\n";
	print "minHeight: $minHeight, maxHeight: $maxHeight\n";
	close $fh;
	
	return @coord;
}

=head2 loadCoordIndexFromFile( $filename )

	Loads a file of the same name/path as the value of $filename and parses 
	the file line-by-line for VRML CoordIndex data. The entire data set should 
	be delimited by square brackets and formatted as quartet of integer
	values. Commas between each value are optional and will be ignored. Each 
	line is passed to parse4IntVectorArray which assigns an array reference for 
	each integer quartet to a new element of the @coordIndex array.

=cut

sub loadCoordIndexFromFile( $ ) {
	my $filename = shift;
	my $fh;
	my $start = 0;
	my $end = 0;
	open $fh, '<', $filename;
	while(<>) {
		if( $_ =~ /\[/ ) {
			# Inside the coord array block
			$start = 1;
		}
		if( $start && !$end) {
			parse4IntVectorArray(\@coordIndex, $_);
		}
		if( $_ =~ /\]/ ) {
			# Outside the coord array block
			$end = 1;
			last;
		}
	}
#	print "coordIndex: ", join(" ", $_->@*), "\n" for @coordIndex;
	print "Number of faces: ", ($#coordIndex + 1), "\n";
	close $fh;
	
	return @coordIndex;
}

=head2 loadColorFromFile( $filename )

	Loads a file of the same name/path as the value of $filename and parses 
	the file line-by-line for VRML Color data. The entire data set should be 
	delimited by square brackets and formatted as trios of floating-point 
	values. Commas between each value are optional and will be ignored. Each 
	line is passed to parse3FVectorArray which assigns an array reference for 
	each floating-point triplet to a new element of the @color array.

=cut

sub loadColorFromFile( $ ) {
	my $filename = shift;
	my $fh;
	my $start = 0;
	my $end = 0;
	open $fh, '<', $filename;
	while(<>) {
		if( $_ =~ /\[/ ) {
			# Inside the color array block
			$start = 1;
		}
		if( $start && !$end) {
			parse3FVectorArray(\@color, $_);
		}
		if( $_ =~ /\]/ ) {
			# Outside the color array block
			$end = 1;
			last;
		}
	}
#	print "color: ", join(" ", $_->@*), "\n" for @color;
	print "Number of colors: ", ($#color + 1), "\n";
	close $fh;
	
	return @color;
}

=head2 parse3FVectorArray( $refToArray, $lineOfData )

	Parses the given $lineOfData for trios of floating-point values and
	assigns a reference for an array of each trio to a new element in 
	the array given by $refToArray.

=cut

sub parse3FVectorArray( @ ) {
	my $vectorArray = shift;
	my $line = shift;
	
	# Get the first 3 floats representing one vector
	push @$vectorArray, [ $1, $2, $3, ] 
		if( $line =~ /(\-?[\d]+[\.]?[\d]*[e|E|\-|\d]*)[\s|\,]*(\-?[\d]+[\.]?[\d]*[e|E|\-|\d]*)[\s|\,]*(\-?[\d]+[\.]?[\d]*[e|E|\-|\d]*)[\s|\,]*(\-?[\d]+.+)?$/ );
	
	# If there are additional float values, re-iterate on the remainder of this line
	if( $4 ) {
		parse3FVectorArray($vectorArray, $4);
	}
	
	return @$vectorArray;
}

=head2 parse4IntVectorArray( $refToArray, $lineOfData )

	Parses the given $lineOfData for quartets of integer values and
	assigns a reference for an array of each quartet to a new element in 
	the array given by $refToArray.

=cut

sub parse4IntVectorArray( @ ) {
	my $vectorArray = shift;
	my $line = shift;
	my $remaining;
	
	# Get the first 4 (or 5) integers representing one vector
	if( $line =~ /(\-?[\d]+)[\s|\,]*(\-?[\d]+)[\s|\,]*(\-?[\d]+)[\s|\,]*(\-?[\d]+)[\s|\,]*(\-?[\d]+)?[\s|\,]*(\-?[\d]+.+)?$/ ){
		my( $i1, $i2, $i3, $i4, $i5, $i6 ) = ($1, $2, $3, $4, $5, $6); 
		 if( $i4 =~ /\-1/) {
		 	push @$vectorArray, [ $i1, $i2, $i3, $i4 ];
			$remaining = $i5 if( $i5 );
		} elsif( $i5 =~ /\-1/) {
		 	push @$vectorArray, [ $i1, $i2, $i3, $i4, $i5 ];
			$remaining= $i6 if( $i6 );
		}
		
	}
	
	# If there are additional integer values, re-iterate on the remainder of this line
	if( $remaining ) {
		print "Remaining line: $remaining\n";
		parse4IntVectorArray($vectorArray, $remaining);
	}
	
	return @$vectorArray;
}

=head2 mapColorsToCoords( [$] )

	Adds exactly one element to the @colorIndex array for each element in 
	the @coord array. Each value in @colorIndex is a refernce to a color 
	element in the @color array. The resulting @colorIndex array is printed to a
	file on disk called 'color.txt'.
	
=cut

sub mapColorsToCoords {
	my $map = shift;
	my $clength = @color;
	my $fh;
	
	if( $map =~ /(?:defaultMap|heightMap)/ ) {
		&{$map}(\@color, \@coord);
	} else {
		defaultMap(\@color, \@coord);
	}
	
	open $fh, '>', 'color.txt';
	print $fh "[\n";
#		print "colorIndex: ", join(" ", $_->@*), ",\n" for @colorIndex;
		print $fh "\t", join(" ", $_->@*), ",\n" for @colorIndex;
	print $fh "]\n";
	close $fh;
	
	print "Length of colorIndex: ", ($#colorIndex + 1), "\n";

	return @colorIndex;
}

=head2 mapColorsToFaces

	Adds exactly one element to the @colorIndex array for each element in 
	the @coordIndex array. Each value in @colorIndex is an index for a color 
	element in the @color array. The resulting @colorIndex array is printed to a
	file on disk called 'colorIndex.txt'.
	
=cut

sub mapColorsToFaces {
	my $clength = @color;
	my $cidx = 0;
	my $fh;
	
	foreach ( @coordIndex ) {
		push @colorIndex, $cidx++;
		$cidx = 0 if( $cidx > $#color );
	}
	
	open $fh, '>', 'colorIndex.txt';
	print $fh "[\n";
#		print "colorIndex: ", join(" ", $_), ",\n" for @colorIndex;
		print $fh "\t", join(" ", $_), ",\n" for @colorIndex;
	print $fh "]\n";
	close $fh;
	
	print "Length of colorIndex: ", ($#colorIndex + 1), "\n";

	return @colorIndex;
}

=head2 defaultMap( $refToColorArray, $index )

	Maps colors from $refToColorArray to each element in $index

=cut

sub defaultMap( @ ) {
	my @color = @{+shift}; 
	my @index = @{+shift};
	my $cidx = 0;
	
	foreach ( @index ) {
		push @colorIndex, $color[($cidx++)];
		$cidx = 0 if( $cidx > $#color );
	}

	return @colorIndex;
}

=head2 heightMap( $refToColorArray, $index )

	Maps colors from $refToColorArray to each element in $index by 
	foremost color to lowest y coordinate.

=cut

sub heightMap( @ ) {
	my @color = @{+shift}; 
	my @index = @{+shift};
	my $cidx = 0;
	my $cRange = @color;
	my $heightRange = $maxHeight - $minHeight;
	my @heightBand;
	
	foreach (@color) {
		push @heightBand, ($cidx*$heightRange/$cRange + $minHeight);
		$cidx++;
	}
	
	$cidx = 0;	
	(print "heightBand". $cidx++ .": $_\n" ) foreach @heightBand;
	
	foreach ( @index ) {
		my $coord = $_;
		$cidx = -1;
		foreach ( @heightBand ) {
			++$cidx if( $coord->[2] > $_ ); 
		}
		$cidx = $#color if( $cidx > $#color );
		$cidx = 0 if( $cidx < 0 );
#		print "Use heightBand$cidx (", join(" ", $color[$cidx]->@*) ,") for y=", $coord->[2], "\n";
		push @colorIndex, $color[$cidx];
	}

	return @colorIndex;
}

=head1 SEE ALSO

L<http://uni-sol.org/world>

=head1 AUTHOR

Revlin John <revlin@uni-sol.org>

=cut

1;
