# Copyright (C) 1998 Tuomas J. Lukka
# DISTRIBUTED WITH NO WARRANTY, EXPRESS OR IMPLIED.
# See the GNU General Public License (file COPYING in the distribution)
# for conditions of use and redistribution.


# 
# The different viewers for VRML::Browser.
#
# All viewers are given the current viewpoint node
# and their own internal coordinate system (position+rotation)
# from that.
#
# XXX Examine doesn't handle animated viewpoints at all!


package VRML::Viewer;
require 'VRML/Quaternion.pm';

# Default gaze: -z, pos: z
sub new {
	my($type,$old) = @_;
	my $this = bless {
		Pos => [0,0,10],
		Dist => 10,
		Quat => new VRML::Quaternion(1,0,0,0),
	}, $type;
	if($old) {
		$this->{Pos} = $old->{Pos};
		$this->{Quat} = $old->{Quat};
		$this->{Dist} = $old->{Dist};
	}
	return $this;
}

sub use_keys { 0 }

sub handle_tick { }

sub bind_viewpoint {
	my($this,$node,$bind_info) = @_;
	if(defined $bind_info) {
		$this->{Pos} = $bind_info->[0];
		$this->{Quat} = $bind_info->[1];
	}
}

# Just restore these later...
sub unbind_viewpoint {
	my($this,$node) = @_;
	return [$this->{Pos},$this->{Quat}];
}

package VRML::Viewer::None;
@ISA=VRML::Viewer;

sub new {
	my($type, $loc, $ori) = @_;
	my $this = bless {
		Pos => $loc,
		Quat => new_vrmlrot VRML::Quaternion(@$ori),
	}, $type;
	return $this;
}

sub togl {
	my($this) = @_;
	$this->{Quat}->togl();
	VRML::OpenGL::glTranslatef(map {-$_} @{$this->{Pos}});
	$ind ++;
}

package VRML::Viewer::Walk;
@ISA=VRML::Viewer;

sub handle {
	my($this, $mev, $but, $mx, $my) = @_;
	# print "VEIEVENT\n";
	if($mev eq "PRESS" and $but == 1) {
		$this->{SY} = $my;
		$this->{SX} = $mx;
	} elsif($mev eq "DRAG" and $but == 1) {
		my $yd = ($my - $this->{SY});
		my $xd = ($mx - $this->{SX});
		my $nv = $this->{Quat}->invert->rotate([0,0,0.15*$yd]);
		for(0..2) {$this->{Pos}[$_] += $nv->[$_]}
		my $nq = new VRML::Quaternion(1-0.2*$xd,0,0.2*$xd,0);
		$nq->normalize_this;
		$this->{Quat} = $nq->multiply($this->{Quat});
		print "WVIEW: (",(join ',',@{$this->{Quat}}),") (",
				(join ',',@{$this->{Pos}}),") (",
				(join ',',@{$nv}),") \n";
	}
}

sub ignore_vpcoords {
	return 0;
}

{my $ind = 0;
sub togl {
	my($this) = @_;
	$this->{Quat}->togl();
	VRML::OpenGL::glTranslatef(map {-$_} @{$this->{Pos}});
	$ind ++;
}
}

package VRML::Viewer::Fly; # Modeled after Descent(tm) ;)
@ISA=VRML::Viewer;
#
# Members:
#  Velocity - current velocity as 3-vector
#  

# Do nothing for the mouse

sub use_keys { 1 }

sub handle {
}

sub handle_key {
	my($this,$time,$key) = @_;
	$key = lc $key;
	$this->{Down}{$key} = 1;
}

sub handle_keyrelease {
	my($this,$time,$key) = @_;
	# print "KEYREL!\n";
	$key = lc $key;
	$this->{WasDown}{$key} += $this->{Down}{$key};
	delete $this->{Down}{$key};
}

{
my @aadd;
my @radd;
my %actions = (
	a => sub {$aadd[2] -= $_[0]},
	z => sub {$aadd[2] += $_[0]},
	j => sub {$aadd[0] -= $_[0]},
	l => sub {$aadd[0] += $_[0]},
	p => sub {$aadd[1] += $_[0]},
	';' => sub {$aadd[1] -= $_[0]},

	8 => sub {$radd[0] += $_[0]},
	k => sub {$radd[0] -= $_[0]},
	u => sub {$radd[1] -= $_[0]},
	o => sub {$radd[1] += $_[0]},
	7 => sub {$radd[2] -= $_[0]},
	9 => sub {$radd[2] += $_[0]},
);
my $lasttime = -1;
sub handle_tick {
	my($this, $time) = @_;
	if(!defined $this->{Velocity}) {$this->{Velocity} = [0,0,0]}
	if(!defined $this->{AVelocity}) {$this->{AVelocity} = [0,0,0]}
	if($lasttime == -1) {$lasttime = $time;}
# First, get all the keypresses since the last time
	my %ps;
	for(keys %{$this->{Down}}) {
		$ps{$_} += $this->{Down}{$_};
	}
	for(keys %{$this->{WasDown}}) {
		$ps{$_} += delete $this->{WasDown}{$_};
	}
	undef @aadd;
	undef @radd;
	for(keys %ps) {
		if(exists $actions{$_}) {
			$actions{$_}->($ps{$_}?1:0);
			# print "Act: '$_', $ps{$_}\n";
		} 
	}
	my $v = $this->{Velocity};
	my $ind = 0;
	my $dt = $time-$lasttime;
	for(@$v) {$_ *= 0.09 ** ($dt);
		$_ += $dt * $aadd[$ind++] * 18.5;
		if(abs($_) > 9.0) {$_ /= abs($_)/9.0}
	}
	$nv = $this->{Quat}->invert->rotate(
		[map {$_ * $dt} @{$this->{Velocity}}]
		);
	for(0..2) {$this->{Pos}[$_] += $nv->[$_]}

	my $av = $this->{AVelocity};
	$ind = 0;
	my $sq;
	for(@$av) {$_ *= 0.05 ** ($dt);
		$_ += $dt * $radd[$ind++] * 0.2;
		if(abs($_) > 0.8) {$_ /= abs($_)/0.8;}
		$sq += $_*$_;
	}
	my $nq = new VRML::Quaternion(1,@$av);
	$nq->normalize_this;
	$this->{Quat} = $nq->multiply($this->{Quat});

#	print "HANDLE_TICK($dt): @aadd | @{$this->{Velocity}} | @$nv\n";
	$lasttime = $time;
}
}

{my $ind = 0;
sub togl {
	my($this) = @_;
	$this->{Quat}->togl();
	VRML::OpenGL::glTranslatef(map {-$_} @{$this->{Pos}});
	$ind ++;
}
}

package VRML::Viewer::Examine;
@ISA=VRML::Viewer;

# Mev: PRESS, DRAG
sub handle {
	my($this, $mev, $but, $mx, $my) = @_;
	 # print "HANDLE $mev $but $mx $my\n";
	if($mev eq "PRESS" and $but == 1) {
		# print 'PRESS\n';
		$this->{SQuat} = $this->xy2qua($mx,$my);
		$this->{OQuat} = $this->{Quat};
	} elsif($mev eq "DRAG" and $but == 1) {
		my $q = $this->xy2qua($mx,$my);
		my $arc = $q->multiply($this->{SQuat}->invert());
		# print "Arc: ",(join '   ',@$arc),"\n";
		$this->{Quat} = $arc->multiply($this->{OQuat});
		# print "Quat:\t\t\t\t ",(join '   ',@{$this->{Quat}}),"\n";
		# $this->{Quat} = $this->{OQuat}->multiply($arc);
#		print "DRAG1: (",
#			(join ',',@{$this->{SQuat}}), ") (",
#			(join ',',@{$this->{OQuat}}), ")\n (",
#			(join ',',@$q), ")\n (",
#			(join ',',@$arc), ") (",
#			(join ',',@{$this->{Quat}}), ")\n",
	} elsif($mev eq "PRESS" and $but == 3) {
		$this->{SY} = $my;
		$this->{ODist} = $this->{Dist};
	} elsif($mev eq "DRAG" and $but == 3) {
		$this->{Dist} = $this->{ODist} * exp($this->{SY} - $my);
	}
	$this->{Pos} = $this->{Quat}->invert->rotate([0,0,$this->{Dist}]);
	# print "POS:     ",(join '    ',@{$this->{Pos}}),"\n";
	# print "QUASQ: ",$this->{Quat}->abssq,"\n";
	# print "VIEW: (",(join ',',@{$this->{Quat}}),") (",
	# 	 	(join ',',@{$this->{Pos}}),")\n";
}

sub change_viewpoint {
	my($this, $jump, $push, $ovp, $nvp) = @_;
	if($push == 1) { # Pushing the ovp under - must store stuff...
		$ovp->{Priv}{viewercoords} = [
			$this->{Dist}, $this->{Quat}
		];
	} elsif($push == -1 && $jump && $nvp->{Priv}{viewercoords}) {
		($this->{Dist}, $this->{Quat}) = 
			@{$nvp->{Priv}{viewercoords}};
	}
	if($push == -1) {
		delete $ovp->{Priv}{viewercoords};
	}
	if(!$jump) {return}
	my $f = $nvp->getfields();
	my $p = $f->{position};
	my $o = $f->{orientation};
	my $os = sin($o->[3]); my $oc = cos($o->[3]);
	$this->{Dist} = sqrt($p->[0]**2 + $p->[1]**2 + $p->[2]**2);
	$this->{Quat} = new VRML::Quaternion(
		$oc, map {$os * $_} @{$o}[0..2]);
}

{my $ind = 0;
sub togl {
	my($this) = @_;
#	print "VP: [",(join ', ',@{$this->{Pos}}),"] [",(join ', ',@{$this->{Quat}}),"]\n";
	if($ind % 3 == -1) { # XXX Why doesn't this work?
		$this->{Quat}->togl();
		VRML::OpenGL::glTranslatef(map {-$_} @{$this->{Pos}});
	} else {
		VRML::OpenGL::glTranslatef(0,0,-$this->{Dist});
		$this->{Quat}->togl();
	}
	$ind ++;
}
}

# Whether to ignore the internal VP coords aside from jumps?
sub ignore_vpcoords {
	return 1;
}

# ArcCone from TriD
sub xy2qua {
	my($this, $x, $y) = @_;
#	print "XY2QUA: $x $y\n";
	$x -= 0.5; $y -= 0.5; $x *= 2; $y *= 2;
	$y = -$y;
	my $dist = sqrt($x**2 + $y**2);
#	print "DXY: $x $y $dist\n";
	if($dist > 1.0) {$x /= $dist; $y /= $dist; $dist = 1.0}
	my $z = 1-$dist;
	# print "Z: $z\n";
	my $qua = VRML::Quaternion->new(0,$x,$y,$z);
#	print "XY2QUA: $x $y ",(join ',',@$qua),"\n";
	$qua->normalize_this();
#	print "XY2QUA: $x $y ",(join ',',@$qua),"\n";
	return $qua;

}

1;
