package PerlWRL::vrml;
use 5.20.2;
use strict;
use warnings;

our @ISA = ('PerlWRL');

my $VRML = "#VRML V2.0 utf8\n";

{ package SFValue;
    sub new {
        my $self = shift;
        return bless \("VRML ". $self), $self;
    }
}

{ package SFRotation;
    our @ISA = ('SFValue');
}

{ package SFVec3f;
    our @ISA = ('SFValue');
}

sub DEF (%) {
    my( $name, $innerVRML ) = @_;
    return "DEF $name ". $innerVRML;
}
sub USE ($) {
    my $name = shift;
    return "USE $name";
}

sub Group ($) {
    my( @children, $bboxCenter, $bbox );
    my $attributes = shift;
    my @attributes = keys %$attributes;
    my $innerVRML = "";
    my @innerVRML = ();
    for my $attr ( @attributes ) {
        push(@innerVRML, $attr ." [ ". join(" ", @{$attributes->{$attr}}) ." ]")
            if( ${$attributes}{$attr} =~ /ARRAY/ && $attr =~ /children/ );
        push(@innerVRML, $attr ." [ ". join(" ", @{$attributes->{$attr}}) ." ]")
            if( ${$attributes}{$attr} =~ /ARRAY/ && $attr !~ /children/ );
        push(@innerVRML, $attr ." [ ".  $attributes->{$attr} ." ]")
            if( ${$attributes}{$attr} !~ /ARRAY/ );
    }
    $innerVRML = join " ", @innerVRML;
    return "Group { ". $innerVRML ." }";
}
sub Transform ($) {
    my( @children, $translation, $rotation, $scale, $scaleOrientation, $center, $bboxCenter, $bbox );
    my $attributes = shift;
    my @attributes = keys %$attributes;
    my $innerVRML = "";
    my @innerVRML = ();
    for my $attr ( @attributes ) {
        push(@innerVRML, $attr ." [ ". join(" ", @{$attributes->{$attr}}) ." ]")
            if( ${$attributes}{$attr} =~ /ARRAY/ && $attr =~ /children/ );
        push(@innerVRML, $attr ." ". join(" ", @{$attributes->{$attr}}) ." ")
            if( ${$attributes}{$attr} =~ /ARRAY/ && $attr !~ /children/ );
        push(@innerVRML, $attr ." ".  $attributes->{$attr})
            if( ${$attributes}{$attr} !~ /ARRAY/ );
    }
    $innerVRML = join " ", @innerVRML;
    return "Transform { ". $innerVRML ." }"
}

sub Shape ($) {
    my( $appearance, $geometry );
    my $attributes = shift;
    my @attributes = keys %$attributes;
    my $innerVRML = "";
    my @innerVRML = ();
    for my $attr ( @attributes ) {
        push(@innerVRML, $attr ." [ ". join(", ", @{$attributes->{$attr}}) ." ]")
            if( ${$attributes}{$attr} =~ /ARRAY/ && $attr =~ /children/ );
        push(@innerVRML, $attr ." ". join(" ", @{$attributes->{$attr}}) ." ")
            if( ${$attributes}{$attr} =~ /ARRAY/ && $attr !~ /children/ );
        push(@innerVRML, $attr ." ".  $attributes->{$attr})
            if( ${$attributes}{$attr} !~ /ARRAY/ );
    }
    $innerVRML = join " ", @innerVRML;
    return "Shape { ". $innerVRML ." }";
}

sub Appearance ($) {
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
    return "Appearance { ". $innerVRML ." }";
}
sub Material {
    my $attributes = shift;
    my @attributes = keys %$attributes;
    my $innerVRML = "";
    my $numAttr = 0;
    for my $attr ( @attributes ) {
        $innerVRML .= " " if ($numAttr > 0);
        ($innerVRML .= $attr) =~ s/(\w)/$1/g;
        $innerVRML .= " ";
        for my $value ( @{$attributes->{$attr}} ) {
          $innerVRML .= $value;
          $innerVRML .= " ";
        }
        ++$numAttr;
    }
    return "Material { ". $innerVRML ." }";
}

sub Cone ($) {
    my $attributes = shift;
    my @attributes = keys %$attributes;
    my $innerVRML = "";
    my $numAttr = 0;
    for my $attr ( @attributes ) {
        $innerVRML .= " " if ($numAttr > 0);
        ($innerVRML .= $attr) =~ s/(\w)/$1/g;
        $innerVRML .= " ";
        $innerVRML .= $attributes->{$attr};
        ++$numAttr;
    }
    return "Cone { ". $innerVRML ." }";
}
sub Cylinder ($) {
    my $attributes = shift;
    my @attributes = keys %$attributes;
    my $innerVRML = "";
    my $numAttr = 0;
    for my $attr ( @attributes ) {
        $innerVRML .= " " if ($numAttr > 0);
        ($innerVRML .= $attr) =~ s/(\w)/$1/g;
        $innerVRML .= " ";
        $innerVRML .= $attributes->{$attr};
        ++$numAttr;
    }
    return "Cylinder { ". $innerVRML ." }";
}
sub Sphere ($) {
    my $attributes = shift;
    my @attributes = keys %$attributes;
    my $innerVRML = "";
    my $numAttr = 0;
    for my $attr ( @attributes ) {
        $innerVRML .= " " if ($numAttr > 0);
        ($innerVRML .= $attr) =~ s/(\w)/$1/g;
        $innerVRML .= " ";
        $innerVRML .= $attributes->{$attr};
        ++$numAttr;
    }
    return "Sphere { ". $innerVRML ." }";
}

sub TimeSensor {
    my @children = @_;
    my $innerVRML = "";
    return "TimeSensor { ". $innerVRML ." }";
}
sub OrientationInterpolator {
    my @children = @_;
    my $innerVRML = "";
    return "OrientationInterpolator { ". $innerVRML ." }";
}
sub PositionInterpolator {
    my @children = @_;
    my $innerVRML = "";
    return "PositionInterpolator { ". $innerVRML ." }";
}

sub ROUTE { return $VRML .= "\n". "ROUTE"; }
sub TO { return $VRML .= "\n". "TO"; }

sub examine {
    my( $self, $name ) = ($_[0], ($_[1] =~ /([A-Za-z0-9|\-|\_|\,|\.|\s|\/]+\.pwrl$)/));
    my $pwrl;
    eval {
        $pwrl = do "./$name";
    };
    print "\n";
    return 0 if( $@ );

    if( $pwrl ) {
        say $VRML;
        say $pwrl;
        say "\n\n";

    } else {
        say "ERROR: $name is not defined\n";
        return 0;
    }

    return 1;
}

1;
