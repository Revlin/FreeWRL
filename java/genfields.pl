# Copyright (C) 1998 Tuomas J. Lukka
# DISTRIBUTED WITH NO WARRANTY, EXPRESS OR IMPLIED.
# See the GNU Library General Public License (file COPYING in the distribution)
# for conditions of use and redistribution.


require '../VRMLFields.pm';

@Fields = qw/
	SFColor
	SFBool
	SFFloat
	SFTime
/;

for(@Fields) {
	my $c = $_;
	my $p = "VRML::Field::$_";
	open O, ">fields/$_.java";
	open OC, ">fields/Const$_.java";
	$str = "// GENERATED BY genfields.pl. DO NOT EDIT!\npackage vrml.field;\nimport vrml.*;\nimport java.util.*;\n\n";
	print O $str; print OC $str;
	
	print O "public class $_ extends Field {\n";
	print OC "public class Const$_ extends ConstField {\n";

	$jdata = $str = $p->jdata."\n";
	print O $str; print OC $str;

	my $alloc = $p->jalloc;
	my $set = $p->jset;
	while(($args, $s) = each %$set) {
		print O "public $c($args) {$alloc $s}\n";
		if($args) {
			print OC "public Const$c($args) {$alloc $s}\n";
			print O "public void setValue($args) {$s value_touched();}\n";
		}
	}

	# Construct from string
	print O "public $c(String s) throws Exception {
		$alloc;
		if(s == null) {
			$set->{''}; return;
		}
		s = s.trim();
		".$p->jset_str."
	}";
	print OC "public Const$c(String s) throws Exception {
		$alloc;
		if(s == null) {
			$set->{''}; return;
		}
		s = s.trim();
		".$p->jset_str."
	}";


	my $get = $p->jget;
	while(($type, $s) = each %$get) {
		$args = "";
		if(ref $s) {$args = $s->[0]; $s = $s->[1]}
		$str = "public $type getValue($args) {$s}\n";
		print O $str; print OC $str;
	}
	my $get = $p->jsimpleget;
	while(($name, $type) = each %$get) {
		my $n = ucfirst $name;
		$str = "public $type get$n() {return $name;}\n";
		print O $str; print OC $str;
	}

	# Copy 
	my $copy = $p->jcopy;
	print O "public void setValue(Const$_ f) {$copy value_touched();}
		public void setValue($_ f) {$copy value_touched(); }\n";

	$str = "public String toString() {".$p->jstr."}";
	print O $str; print OC $str;

	print O "public Object clone() {$c _x = new $c(".$p->jclonearg."); return _x;}";
	print OC "public Object clone() {Const$c _x = new Const$c(".$p->jclonearg."); return _x;}";
		 
	print O "}";
	print OC "}";
	close O;
	close OC;

# External API
	
	open EI, ">eai/fields/EventIn$_.java";
	open EO, ">eai/fields/EventOut$_.java";

	$str = "//GENERATED BY genfields.pl. DO NOT EDIT!\npackage vrml.external.field;\nimport vrml.external.*;\nimport java.util.*;\n\n";
	print EI $str; print EO $str;

	my $setargs = $p->jeaiset;
	$throws = "";
	$throws = " throws IllegalArgumentException "
		if $setargs =~ /\[/;

	$string = $p->jstr;
	$string =~ s/return([^;]*);/browser.send__eventin(nodeid,id,$1)/;

	print EI qq|public class EventIn$_ extends EventIn {
		FreeWRLBrowser browser;
		String nodeid;
		String id;
		public EventIn$_(FreeWRLBrowser b, String n, String i) {
			browser = b;
			nodeid = n;
			id = i;
			System.out.println("New $_: "+n+" "+id);
		}
		public void setValue($setargs) 
			$throws {
				$jdata;
				$alloc;
				$set->{$p->jeaiset}
				$string ;
		}
	}
	|;

	print EO qq|public class EventOut$_ extends EventOut {
		$jdata
		public void value__set(String s) throws Exception {
			$alloc;
			if(s == null \|\| s.equals(\"\")) {
				$set->{''}; return;
			}
			s = s.trim();
			|.$p->jset_str.qq|
		}
	|;

	my $get = $p->jget;
	while(($type, $s) = each %$get) {
		$args = "";
		if(ref $s) {$args = $s->[0]; $s = $s->[1]}
		$str = "public $type getValue($args) {$s}\n";
		print EO $str; 
	}
	my $get = $p->jsimpleget;
	while(($name, $type) = each %$get) {
		my $n = ucfirst $name;
		$str = "public $type get$n() {return $name;}\n";
		print EO $str; 
	}

	print EO qq|
		};
	|;

	close EI;




}
