package VRML::JS;
require DynaLoader;
@ISA=DynaLoader;
bootstrap VRML::JS;
use strict qw/vars/;
use vars qw/%Types/;

# Unlike with the Java interface, we have one object per script
# for javascript.

init(); # C-level init

%Types = (
	SFBool => sub {$_[0] ? "true" : "false"},
	SFFloat => sub {$_[0]+0},
	SFTime => sub {$_[0]+0},
	SFInt32 => sub {$_[0]+0},
	SFString => sub {$_[0]}, # XXX
);

sub new {
	my($type,$text,$node) = @_;
	my $this = bless { },$type;
	$this->{GLO} = "";
	$this->{CX} = newcontext($this->{GLO},$this);
	$this->{Node} = $node;
	print "START JS $text\n";
	my $rs;
	print "INITIALIZE $this->{CX} $this->{GLO}\n";
	# Create default functions 
	runscript($this->{CX}, $this->{GLO}, 
		"function initialize() {} function shutdown() {}
		 function eventsProcessed() {} ", $rs);
	print "TEXT $this->{CX} $this->{GLO}\n";
	runscript($this->{CX}, $this->{GLO}, $text, $rs);
# Initialize fields.
	my $t = $node->{Type};
	my @k = keys %{$t->{Defaults}};
	print "TY: $t\n";
	print "FIELDS\n";
	for(@k) {
		next if $_ eq "url" or $_ eq "mustEvaluate" or $_ eq "directOutput";
		my $type = $t->{FieldTypes}{$_};
		my $ftype = "VRML::Field::$type";
		print "CONSTR FIELD $_\n";
		if($t->{FieldKinds}{$_} eq "field" or
  		   $t->{FieldKinds}{$_} eq "eventOut") {
			print "JS FIELD $_\n";
			if($Types{$type}) {
				addwatchprop($this->{CX},$this->{GLO},
					$_);
			} else {
				addasgnprop($this->{CX},$this->{GLO},
				    $_, $ftype->js_default);
			}
			if($t->{FieldKinds}{$_} eq "field") {
				my $value = $node->{RFields}{$_};
				print "JS FIELDPROP $_\n";
				if($Types{$type}) {
					print "SET_TYPE $_ '$value'\n";
					my $v = runscript($this->{CX}, $this->{GLO}, 
					  "$_=".$Types{$type}->($value), $rs);
				} else {
					$this->set_prop($_, $value, $_);
				}
			}
			print "CONED\n";
		} elsif($t->{FieldKinds}{$_} eq "eventIn") {
			if($Types{$type}) {
			} else {
				addasgnprop($this->{CX},$this->{GLO},
				    "__tmp_arg_$_", $ftype->js_default);
			}
		} else {
			warn("INVALID FIELDKIND '$_' for $node->{TypeName}");
		}
	}
	return $this;
}

sub initialize {
	my($this) = @_;
	my $rs;
	runscript($this->{CX}, $this->{GLO}, "initialize()", $rs);
	$this->gathersent();
}

sub sendevent {
	my($this,$node,$event,$value,$timestamp) = @_;
	my $rs;
	my $typ = $node->{Type}{FieldTypes}{$event};
	my $aname = "__tmp_arg_$event";
	$this->set_prop($event,$value,$aname);
	runscript($this->{CX}, $this->{GLO}, "$event($aname,$timestamp)", $rs);
	return $this->gathersent();

	unless($Types{$typ}) {
		&{"set_property_$node->{Type}{FieldTypes}{$event}"}(
			$this->{CX}, $this->{GLO}, "__evin", $value);
		runscript($this->{CX}, $this->{GLO}, "$event(__evin,$timestamp)", $rs);
	} else {
		print "JS sendevent $event $timestamp\n".
			"$event(".$Types{$typ}->($value).",$timestamp)\n";
		my $v = runscript($this->{CX}, $this->{GLO}, 
			"$event(".$Types{$typ}->($value).",$timestamp)", $rs);
		print "GOT: $v $rs\n";
	}
	$this->gathersent();
}

sub sendeventsproc {
	my($this) = @_;
	my $rs;
	runscript($this->{CX}, $this->{GLO}, "eventsProcessed()", $rs);
	$this->gathersent();
}

sub gathersent {
	my($this) = @_;
	my $node = $this->{Node};
	my $t = $node->{Type};
	my @k = keys %{$t->{Defaults}};
	my @a;
	my $rs;
	for(@k) {
		next if $_ eq "url";
		my $type = $t->{FieldTypes}{$_};
		my $ftyp = $type;
		if($t->{FieldKinds}{$_} eq "eventOut") {
			print "JS EOUT $_\n";
			my $v;
			if($type =~ /^MF/) {
				$v = runscript($this->{CX},$this->{GLO},
					"$_.__touched_flag",$rs);
			} elsif($Types{$ftyp}) {
				$v = runscript($this->{CX},$this->{GLO},
					"_${_}_touched",$rs);
				# print "SIMP_TOUCH $v\n";
			} else {
				$v = runscript($this->{CX},$this->{GLO},
					"$_.__touched()",$rs);
			}
			print "GOT $v $rs\n";
			if($v) {
				print "RS2: $rs\n";
				if($type =~ /^MF/) {
					my $l = runscript($this->{CX},$this->{GLO},
						"$_.length",$rs);
					my $fn = $_;
					my $st = $type;
					$st =~ s/MF/SF/;
					my @res = map {
					     runscript($this->{CX},$this->{GLO},
						"$fn"."[$_]",$rs);
					     print "RES: '$rs'\n";
					     (pos $rs) = 0;
					     "VRML::Field::$st"
					      -> parse(undef, $rs);
					} (0..$l-1);
					print "RESVAL:\n";
					for(@res) {
						if("ARRAY" eq ref $_) {
							print "@$_\n";
						}
					}
					my $r = \@res;
					print "REF: $r\n";
					push @a, [$node, $_, $r];
				} elsif($Types{$ftyp}) {
					$v = runscript($this->{CX},$this->{GLO},
						"_${_}_touched=0; $_",$rs);
					print "SIMP VAL: $v '$rs'\n";
					push @a, [$node, $_,
						$v];
				} else {
					runscript($this->{CX},$this->{GLO},
						"$_",$rs);
					# print "VAL: $rs\n";
					(pos $rs) = 0;
					push @a, [$node, $_,
					 "VRML::Field::$t->{FieldTypes}{$_}"
					   -> parse(undef,$rs)];
				}
			}
		}
		# $this->{O}->print("$t->{FieldKinds}{$_}\n
	}
	return @a;
}

sub set_prop { # Assigns a value to a property.
	my($this,$field,$value,$prop) = @_;
	my $typ = $this->{Node}{Type};
	my $ftyp;
	if($field =~ s/^____//) { # recurse hack
		$ftyp = $field;
	} else {
		$ftyp = $typ->{FieldTypes}{$field};
	}
	my $rs;
	my $i;
	if($ftyp =~ /^MF/) {
		my $styp = $ftyp; $styp =~ s/^MF/SF/;
		for($i=0; $i<$#{$value}; $i++) {
			$this->set_prop("____$styp", $value->[$i], "____tmp");
			runscript($this->{CX}, $this->{GLO},
				"$prop"."[$i] = ____tmp");
		}
		runscript($this->{CX},$this->{GLO},
		  "$prop.__touched_flag = 0",$rs);
	} elsif($Types{$ftyp}) {
		runscript($this->{CX},$this->{GLO}, 
			"$prop = ".(&{$Types{$ftyp}}($value)),
			$rs);
		runscript($this->{CX},$this->{GLO},"_${prop}__touched=0",$rs);
	} else {
		print "set_property_ CALL: $ftyp\n";
		&{"set_property_$ftyp"}(
			$this->{CX}, $this->{GLO}, $prop, $value);
		runscript($this->{CX},$this->{GLO},"$prop.__touched()",$rs);
	}
}


sub brow_getName {
	print "Brow:getname!\n";
}


