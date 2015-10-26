package PerlWRL::vrml;
use 5.10.1;
use strict;
use warnings;

our @ISA = ('PerlWRL');

my $VRML = "#VRML V2.0 utf8";

{ 	package SFValue;
	sub new {
		my $self = shift;
		return bless \("VRML ". $self), $self;
	}
}

{	package SFRotation;
	our @ISA = ('SFValue');
}

{	package SFVec3f;
	our @ISA = ('SFValue');
}

sub DEF(%) {
	my( $name, $innerVRML ) = @_;
	return "DEF $name ". $innerVRML;
}
sub USE($) {
	my $name = shift;
	return "USE $name";
}

sub Group($) {
	my( @children, $bboxCenter, $bbox );
	my $attributes = shift;
	my @attributes = keys %$attributes;
	my $innerVRML = "";
	my @innerVRML = ();
	for my $attr ( @attributes ) {
		push(@innerVRML, $attr ." [ ". join(", ", @{$attributes->{$attr}}) ." ]")
			if( ${$attributes}{$attr} =~ /ARRAY/ && $attr =~ /children/ );
		push(@innerVRML, $attr ." [ ". join(" ", @{$attributes->{$attr}}) ." ]")
			if( ${$attributes}{$attr} =~ /ARRAY/ && $attr !~ /children/ );
		push(@innerVRML, $attr ." [ ".  $attributes->{$attr} ." ]")
			if( ${$attributes}{$attr} !~ /ARRAY/ );
	}
	$innerVRML = join ", ", @innerVRML;
	print "$innerVRML\n";
	return "Group{". $innerVRML ."}";
}
sub Transform($) {
	my( @children, $translation, $rotation, $scale, $scaleOrientation, $center, $bboxCenter, $bbox );
	my $attributes = shift;
	my @attributes = keys %$attributes;
	my $innerVRML = "";
	my @innerVRML = ();
	for my $attr ( @attributes ) {
		push(@innerVRML, $attr ." [ ". join(", ", @{$attributes->{$attr}}) ." ]")
			if( ${$attributes}{$attr} =~ /ARRAY/ && $attr =~ /children/ );
		push(@innerVRML, $attr ." [ ". join(" ", @{$attributes->{$attr}}) ." ]")
			if( ${$attributes}{$attr} =~ /ARRAY/ && $attr !~ /children/ );
		push(@innerVRML, $attr ." ".  $attributes->{$attr})
			if( ${$attributes}{$attr} !~ /ARRAY/ );
	}
	$innerVRML = join ", ", @innerVRML;
	print "$innerVRML\n";
	return "Transform{". $innerVRML ."}"
}

sub Shape($) {
	my( $appearance, $geometry );
	my $attributes = shift;
	my @attributes = keys %$attributes;
	my $innerVRML = "";
	my @innerVRML = ();
	for my $attr ( @attributes ) {
		push(@innerVRML, $attr ." [ ". join(", ", @{$attributes->{$attr}}) ." ]")
			if( ${$attributes}{$attr} =~ /ARRAY/ && $attr =~ /children/ );
		push(@innerVRML, $attr ." [ ". join(" ", @{$attributes->{$attr}}) ." ]")
			if( ${$attributes}{$attr} =~ /ARRAY/ && $attr !~ /children/ );
		push(@innerVRML, $attr ." ".  $attributes->{$attr})
			if( ${$attributes}{$attr} !~ /ARRAY/ );
	}
	$innerVRML = join " ", @innerVRML;
	print "$innerVRML\n";
	return "Shape{". $innerVRML ."}";
}

sub Appearance($) {
	my @children = @_;
	my $innerVRML = "";
	return "Appearance{". $innerVRML ."}";
}
sub Material {
	my @children = @_;
	my $innerVRML = "";
	return "Material{". $innerVRML ."}";
}

sub Cone {
	my @children = @_;
	my $innerVRML = "";
	return "Cone{". $innerVRML ."}";
}
sub Cylinder {
	my @children = @_;
	my $innerVRML = "";
	return "Cylinder{". $innerVRML ."}";
}
sub Sphere {
	my @children = @_;
	my $innerVRML = "";
	return "Sphere{". $innerVRML ."}";
}

sub TimeSensor {
	my @children = @_;
	my $innerVRML = "";
	return "TimeSensor{". $innerVRML ."}";
}
sub OrientationInterpolator {
	my @children = @_;
	my $innerVRML = "";
	return "OrientationInterpolator{". $innerVRML ."}";
}
sub PositionInterpolator {
	my @children = @_;
	my $innerVRML = "";
	return "PositionInterpolator{". $innerVRML ."}";
}

sub ROUTE { return $VRML .= "\n". "ROUTE"; }
sub TO { return $VRML .= "\n". "TO"; }

sub see {
    my( $self, $name ) = @_;
    my $pwrl = do($name .'.pwrl');
	print "\n";

    if( $pwrl ) {
        say $VRML;
		say $pwrl;
        say "\n\n";

    } else {
        say "ERROR: $name.pwrl is not defined\n";
        return 0;
    }

    return 1;
}

1;
