# Copyright (C) 1998 Tuomas J. Lukka
# DISTRIBUTED WITH NO WARRANTY, EXPRESS OR IMPLIED.
# See the GNU General Public License (file COPYING in the distribution)
# for conditions of use and redistribution.

# Field types, parsing and printing, Perl, C and Java.

# SFNode is in Parse.pm

# XXX Decide what's the forward assertion..

@VRML::Fields = qw/
	SFFloat
	MFFloat
	SFRotation
	MFRotation
	SFVec3f
	MFVec3f
	SFBool
	SFInt32
	MFInt32
	SFNode
	MFNode
	SFColor
	MFColor
	SFTime
	SFString
	MFString
	SFVec2f
	MFVec2f
/;

package VRML::Field;
VRML::Error->import();

sub es {
	$p = (pos $_[1]) - 20;
	return substr $_[1],$p,40;
	
}

# The C type interface for the field type, encapsulated
# By encapsulating things well enough, we'll be able to completely
# change the interface later, e.g. to fit together with javascript etc.
sub ctype ($) {die "VRML::Field::ctype - abstract function called"}
sub calloc ($$) {""}
sub cassign ($$) {"$_[1] = $_[2];"}
sub cfree ($) {if($_[0]->calloc) {return "free($_[1]);"} return ""}
sub cget {if(!defined $_[2]) {return "$_[1]"}
	else {die "If CGet with indices, abstract must be overridden"} }
sub cstruct () {""}
sub cfunc {die("Must overload cfunc")}
sub jsimpleget {return {}}

package VRML::Field::SFFloat;
@ISA=VRML::Field;

sub parse {
	my($type,$p,$s,$n) = @_;
	$_[2] =~ /\G\s*([\d\.+-eE]+)\b/gs or die "$s at $p didn't match number";
	return $1;
}

sub as_string {$_[1]}

sub print {print $_[1]}

sub ctype {"float $_[1]"}
sub cfunc {"$_[1] = SvNV($_[2]);\n"}

sub jdata {"float v;"}
sub jalloc {""}
sub jset {return {""=>"v = 0;", "float val" => "v=val;"}}
sub jset_str { '
	s = s.trim();
	v = new Float(s).floatValue();
'}
sub jget {return {float => "return v;"}}
sub jcopy {"v = f.getValue();"}
sub jstr {"return new Float(v).toString();"}
sub jclonearg {"v"}
sub toj {$_[1]}
sub fromj {$_[1]}

package VRML::Field::SFTime;
@ISA=VRML::Field::SFFloat;

sub jdata {"double v;"}
sub jset {return {""=>"v = 0;", "double val" => "v=val;"}}
sub jset_str { '
	s = s.trim();
	v = new Double(s).doubleValue();
'}
sub jget {return {double => "return v;"}}
sub jstr {"return new Double(v).toString();"}

package VRML::Field::SFInt32;
@ISA=VRML::Field;

sub parse {
	my($type,$p,$s,$n) = @_;
	$_[2] =~ /\G\s*(-?[\deE]+)\b/gsc 
		or VRML::Error::parsefail($_[2],"not proper SFInt32");
	return $1;
}

sub print {print " $_[1] "}
sub as_string {$_[1]}

sub ctype {return "int $_[1]"}
sub cfunc {return "$_[1] = SvIV($_[2]);\n"}

package VRML::Field::SFColor;
@ISA=VRML::Field;

sub parse {
	my($type,$p) = @_;
	$_[2] =~ /\G\s*([\d\.+-eE]+)\s+([\d\.+-eE]+)\s+([\d\.+-eE]+)\b/gsc 
		or die "$_[2] at $p didn't match color: '",$type->es($_[2]),"'\n'";
	return [$1,$2,$3];
}

sub print {print join ' ',@{$_[1]}}
sub as_string {join ' ',@{$_[1]}}

sub cstruct {return "struct SFColor {
	float c[3]; };"}
sub ctype {return "struct SFColor $_[1]"}
sub cget {return "($_[1].c[$_[2]])"}

sub cfunc {
#	return ("a,b,c","float a;\nfloat b;\nfloat c;\n",
#		"$_[1].c[0] = a; $_[1].c[1] = b; $_[1].c[2] = c;");
	return "{
		AV *a;
		SV **b;
		int i;
		if(!SvROK($_[2])) {
			die(\"Help! SFColor without being ref\");
		}
		if(SvTYPE(SvRV($_[2])) != SVt_PVAV) {
			die(\"Help! SFColor without being arrayref\");
		}
		a = (AV *) SvRV($_[2]);
		for(i=0; i<3; i++) {
			b = av_fetch(a, i, 1); /* LVal for easiness */
			if(!b) {
				die(\"Help: SFColor b == 0\");
			}
			$_[1].c[i] = SvNV(*b);
		}
	}
	"
}

# java

sub jdata {"float red,green,blue;"}
sub jalloc {""}
sub jset {return {"" => "red=0; green=0; blue=0;",
	"float colors[]" => "red = colors[0]; green=colors[1]; blue=colors[2];",
	"float r,float g,float b" => "red=r; green=g; blue=b;"
}}
sub jset_str {"
   	StringTokenizer tok = new StringTokenizer(s);
	red = 	new Float(tok.nextToken()).floatValue();
	green =	new Float(tok.nextToken()).floatValue();
	blue =	new Float(tok.nextToken()).floatValue();
	"
}
sub jget {return {"void" => ["float colors[]",
	"colors[0] = red; colors[1] = green; colors[2] = blue;"]}
}
sub jcopy {"red = f.getRed(); green = f.getGreen(); blue = f.getBlue();"}
sub jstr {'return Float.toString(red) + " " + 
	Float.toString(green) + " " + Float.toString(blue);'}
sub jclonearg {"red,green,blue"}

sub jsimpleget {return {red => float, green => float, blue => float}}
sub toj {join ' ',@{$_[1]}}
sub fromj {[split ' ',$_[1]]}

# javascript

sub jsprop {
	return '{"r", 0, JSPROP_ENUMERATE},{"g", 1, JSPROP_ENUMERATE},
		{"b", 2, JSPROP_ENUMERATE}'
}
sub jsnumprop {
	return { map {($_ => "$_[1].c[$_]")} 0..2 }
}
sub jstostr {
	return "
		{static char buff[250];
		 sprintf(buff,\"\%f \%f \%f\", $_[1].c[0], $_[1].c[1], $_[1].c[2]);
		 \$RET(buff);
		}
	"
}
sub jscons {
	return [
		"jsdouble pars[3];",
		"d d d",
		"&(pars[0]),&(pars[1]),&(pars[2])",
		"$_[1].c[0] = pars[0]; $_[1].c[1] = pars[1]; $_[1].c[2] = pars[2];"
	];
}

sub js_default {
	return "new SFColor(0,0,0)"
}

package VRML::Field::SFVec3f;
@ISA=VRML::Field::SFColor;
sub cstruct {return ""}

sub jsprop {
	return '{"x", 0, JSPROP_ENUMERATE},{"y", 1, JSPROP_ENUMERATE},
		{"z", 2, JSPROP_ENUMERATE}'
}
sub js_default {
	return "new SFVec3f(0,0,0)"
}


package VRML::Field::SFVec2f;
@ISA=VRML::Field;

sub parse {
	my($type,$p) = @_;
	$_[2] =~ /\G\s*([\d\.+-eE]+)\s+([\d\.+-eE]+)\b/gsc 
		or die "$_[2] at $p didn't match sfvec2f: '",$type->es($_[2]),"'\n'";
	return [$1,$2];
}

sub print {print join ' ',@{$_[1]}}

sub cstruct {return "struct SFVec2f {
	float c[2]; };"}
sub ctype {return "struct SFVec2f $_[1]"}
sub cget {return "($_[1].c[$_[2]])"}

sub cfunc {
	return "{
		AV *a;
		SV **b;
		int i;
		if(!SvROK($_[2])) {
			die(\"Help! SFVec2f without being ref\");
		}
		if(SvTYPE(SvRV($_[2])) != SVt_PVAV) {
			die(\"Help! SFVec2f without being arrayref\");
		}
		a = (AV *) SvRV($_[2]);
		for(i=0; i<2; i++) {
			b = av_fetch(a, i, 1); /* LVal for easiness */
			if(!b) {
				die(\"Help: SFColor b == 0\");
			}
			$_[1].c[i] = SvNV(*b);
		}
	}
	"
}

sub jdata {"float x,y;"}
sub jalloc {""}
sub jset {return {"" => "x=0; y=0;",
	"float coords[]" => "x = colors[0]; y=colors[1];",
	"float x2,float y2" => "x=x2; y=y2;"
}}
sub jset_str {"
   	StringTokenizer tok = new StringTokenizer(s);
	x = 	new Float(tok.nextToken()).floatValue();
	y =	new Float(tok.nextToken()).floatValue();
	"
}
sub jget {return {"void" => ["float coords[]",
	"coords[0] = x; coords[1] = y;"]}
}
sub jcopy {"x = f.getX(); y = f.getY();"}
sub jstr {'return Float.toString(x) + " " + 
	Float.toString(y) ;'}
sub jclonearg {"x,y"}

sub jsimpleget {return {x => float, y => float}}
sub toj {join ' ',@{$_[1]}}
sub fromj {[split ' ',$_[1]]}


package VRML::Field::SFRotation;
@ISA=VRML::Field;

sub parse {
	my($type,$p) = @_;
	$_[2] =~ /\G\s*([\d\.eE+-]+)\s+([\d\.eE+-]+)\s+([\d\.eE+-]+)\s+([\d\.eE+-]+)\b/gsc 
		or VRML::Error::parsefail($_[2],"not proper rotation");
	return [$1,$2,$3,$4];
}

sub print {print join ' ',@{$_[1]}}
sub as_string {join ' ',@{$_[1]}}

sub cstruct {return "struct SFRotation {
 	float r[4]; };"}
sub ctype {return "struct SFRotation $_[1]"}
sub cget {return "($_[1].r[$_[2]])"}

sub cfunc {
#	return ("a,b,c,d","float a;\nfloat b;\nfloat c;\nfloat d;\n",
#		"$_[1].r[0] = a; $_[1].r[1] = b; $_[1].r[2] = c; $_[1].r[3] = d;");
	return "{
		AV *a;
		SV **b;
		int i;
		if(!SvROK($_[2])) {
			die(\"Help! SFRotation without being ref\");
		}
		if(SvTYPE(SvRV($_[2])) != SVt_PVAV) {
			die(\"Help! SFRotation without being arrayref\");
		}
		a = (AV *) SvRV($_[2]);
		for(i=0; i<4; i++) {
			b = av_fetch(a, i, 1); /* LVal for easiness */
			if(!b) {
				die(\"Help: SFColor b == 0\");
			}
			$_[1].r[i] = SvNV(*b);
		}
	}
	"
}

sub jsprop {
	return '{"x", 0, JSPROP_ENUMERATE},{"y", 1, JSPROP_ENUMERATE},
		{"z", 2, JSPROP_ENUMERATE},{"angle",3, JSPROP_ENUMERATE}'
}
sub jsnumprop {
	return { map {($_ => "$_[1].r[$_]")} 0..3 }
}
sub jstostr {
	return "
		{static char buff[250];
		 sprintf(buff,\"\%f \%f \%f \%f\", $_[1].r[0], $_[1].r[1], $_[1].r[2], $_[1].r[3]);
		 \$RET(buff);
		}
	"
}
sub jscons {
	return [
		"jsdouble pars[4];",
		"d d d d",
		"&(pars[0]),&(pars[1]),&(pars[2]),&(pars[3])",
		"$_[1].r[0] = pars[0]; $_[1].r[1] = pars[1]; $_[1].r[2] = pars[2]; $_[1].r[3] = pars[3];"
	];
}

sub js_default {
	return "new SFRotation(0,0,1,0)"
}


package VRML::Field::SFBool;
@ISA=VRML::Field;

sub parse {
	my($type,$p,$s,$n) = @_;
	$_[2] =~ /\G\s*(TRUE|FALSE)\b/gs or die "Invalid value for BOOL\n";
	return ($1 eq "TRUE");
}

sub ctype {return "int $_[1]"}
sub cget {return "($_[1])"}
sub cfunc {return "$_[1] = SvIV($_[2]);\n"}

sub print {print ($_[1] ? TRUE : FALSE)}
sub as_string {($_[1] ? TRUE : FALSE)}

# The java interface
sub jdata {"boolean v;"}
sub jalloc {""}
sub jset {return {"" => "v = false;",
	"boolean value" => "v = value;",
}}
sub jset_str { q~
   	s = s.trim();
	if(s.equals("1")) {v = true;}
	else if(s.equals("0") || s.equals("")) {v = false;}
	else {throw new Exception("Invalid boolean '"+s+"'");}
~}
sub jget {return {"boolean" => "return v;"}}
sub jcopy {"v = f.getValue();"}
sub jstr {'if(v) return "1"; else return "0";'}
sub jclonearg {"v"}
sub toj {return $_[1]}
sub fromj {return $_[1]}

sub js_default {return "false"}

package VRML::Field::SFString;
@ISA=VRML::Field;

# XXX Handle backslashes in string properly
sub parse {
	my($type,$p,$s,$n) = @_;
	# Magic regexp which hopefully exactly quotes backslashes and quotes
	$_[2] =~ /\G\s*"((?:[^"\\]|\\.)*)"\s*/gsc 
		or VRML::Error::parsefail($_[2],"improper SFString");
	my $str = $1;
	$str =~ s/\\(.)/$1/g;
	# print "GOT STRING '$str'\n";
	return $str;
}

sub ctype {return "SV *$_[1]"}
sub calloc {"$_[1] = newSVpv(\"\",0);"}
sub cassign {"sv_setsv($_[1],$_[2]);"}
sub cfree {"SvREFCNT_dec($_[1]);"}
sub cfunc {"sv_setsv($_[1],$_[2]);"}

sub print {print "\"$_[1]\""}

package VRML::Field::MFString;
@ISA=VRML::Field::Multi;

# XXX Should be optimized heavily! Other MFs are ok.
package VRML::Field::MFFloat;
@ISA=VRML::Field::Multi;

sub parse {
	my($type,$p) = @_;
	if($_[2] =~ /\G\s*\[\s*/gsc) {
		$_[2] =~ /\G([^\]]*)\]/gsc or
		 VRML::Error::parsefail($_[2],"unterminated MFFloat");
		my $a = $1;
		$a =~ s/^\s*//;
		$a =~ s/\s*$//;
		# XXX Errors ???
		my @a = split /\s+|\s*,\s*/,$a;
		pop @a if $a[-1] =~ /^\s+$/;
		# while($_[2] !~ /\G\s*,?\s*\]\s*/gsc) {
		# 	$_[2] =~ /\G\s*,\s*/gsc; # Eat comma if it is there...
		# 	my $v =  $stype->parse($p,$_[2],$_[3]);
		# 	push @a, $v if defined $v; 
		# }
		return \@a;
	} else {
		my $res = [VRML::Field::SFFloat->parse($p,$_[2],$_[3])];
		# Eat comma if it is there
		$_[2] =~ /\G\s*,\s*/gsc;
		return $res;
	}
}

package VRML::Field::MFNode;
@ISA=VRML::Field::Multi;

package VRML::Field::MFColor;
@ISA=VRML::Field::Multi;

package VRML::Field::MFVec3f;
@ISA=VRML::Field::Multi;

package VRML::Field::MFVec2f;
@ISA=VRML::Field::Multi;

package VRML::Field::MFInt32;
@ISA=VRML::Field::Multi;

sub parse {
	my($type,$p) = @_;
	if($_[2] =~ /\G\s*\[\s*/gsc) {
		$_[2] =~ /\G([^\]]*)\]/gsc or
		 VRML::Error::parsefail($_[2],"unterminated MFFloat");
		my $a = $1;
		$a =~ s/^\s*//;
		$a =~ s/\s*$//;
		# XXX Errors ???
		my @a = split /\s+|\s*,\s*/,$a;
		pop @a if $a[-1] =~ /^\s+$/;
		# while($_[2] !~ /\G\s*,?\s*\]\s*/gsc) {
		# 	$_[2] =~ /\G\s*,\s*/gsc; # Eat comma if it is there...
		# 	my $v =  $stype->parse($p,$_[2],$_[3]);
		# 	push @a, $v if defined $v; 
		# }
		return \@a;
	} else {
		my $res = [VRML::Field::SFInt32->parse($p,$_[2],$_[3])];
		# Eat comma if it is there
		$_[2] =~ /\G\s*,\s*/gsc;
		return $res;
	}
}

package VRML::Field::MFRotation;
@ISA=VRML::Field::Multi;

package VRML::Field::Multi;

sub ctype {
	my $r = (ref $_[0] or $_[0]);
	$r =~ s/VRML::Field::MF//;
	return "struct Multi_$r $_[1]";
}
sub cstruct {
	my $r = (ref $_[0] or $_[0]);
	my $t = $r;
	$r =~ s/VRML::Field::MF//;
	$t =~ s/::MF/::SF/;
	my $ct = $t->ctype;
	return "struct Multi_$r { int n; $ct *p; };"
}
sub calloc {
	return "$_[1].n = 0; $_[1].p = 0;";
}
sub cassign {
	my $t = (ref $_[0] or $_[0]);
	$t =~ s/::MF/::SF/;
	my $cm = $t->calloc("$_[1].n");
	my $ca = $t->cassign("$_[1].p[__i]", "$_[2].p[__i]");
	"if($_[1].p) {free($_[1].p)};
	 $_[1].n = $_[2].n; $_[1].p = malloc(sizeof(*($_[1].p))*$_[1].n);
	 {int __i;
	  for(__i=0; __i<$_[1].n; __i++) {
	  	$cm
		$ca
	  }
	 }
	"
}
sub cfree {
	"if($_[1].p) {free($_[1].p);$_[1].p=0;} $_[1].n = 0;"
}
sub cgetn { "($_[1].n)" }
sub cget { if($#_ == 1) {"($_[1].p)"} else {
	my $r = (ref $_[0] or $_[0]);
	$r =~ s/::MF/::SF/;
	if($#_ == 2) {
		return "($_[1].p[$_[2]])";
	}
	return $r->cget("($_[1].p[$_[2]])", @$_[3..$#_])
	} }

sub cfunc {
	my $r = (ref $_[0] or $_[0]);
	$r =~ s/::MF/::SF/;
	my $cm = $r->calloc("$_[1].p[iM]");
	my $su = $r->cfunc("($_[1].p[iM])","(*bM)");
	return "{
		AV *aM;
		SV **bM;
		int iM;
		int lM;
		if(!SvROK($_[2])) {
			die(\"Help! Multi without being ref\");
		}
		if(SvTYPE(SvRV($_[2])) != SVt_PVAV) {
			die(\"Help! Multi without being arrayref\");
		}
		aM = (AV *) SvRV($_[2]);
		lM = av_len(aM)+1;
		/* XXX Free previous p */
		$_[1].n = lM;
		$_[1].p = malloc(lM * sizeof(*($_[1].p)));
		/* XXX ALLOC */
		for(iM=0; iM<lM; iM++) {
			bM = av_fetch(aM, iM, 1); /* LVal for easiness */
			if(!bM) {
				die(\"Help: Multi $r bM == 0\");
			}
			$cm
			$su
		}
	}
	"
}


sub parse {
	my($type,$p) = @_;
	my $stype = $type;
	$stype =~ s/::MF/::SF/;
	if($_[2] =~ /\G\s*\[\s*/gsc) {
		my @a;
		while($_[2] !~ /\G\s*,?\s*\]\s*/gsc) {
			$_[2] =~ /\G\s*,\s*/gsc; # Eat comma if it is there...
			my $v =  $stype->parse($p,$_[2],$_[3]);
			push @a, $v if defined $v; 
		}
		return \@a;
	} else {
		my $res = [$stype->parse($p,$_[2],$_[3])];
		# Eat comma if it is there
		$_[2] =~ /\G\s*,\s*/gsc;
		return $res;
	}
}

sub print {
	my($type) = @_;
	print " [ ";
	my $r = $type;
	$r =~ s/::MF/::SF/;
	for(@{$_[1]}) {
		$r->print($_);
	}
	print " ]\n";
}

sub as_string {
	my $r = $_[0];
	$r =~ s/::MF/::SF/;
	" [ ".(join ' ',map {$r->as_string($_)} @{$_[1]})." ] "
}

sub js_default {
	my($type) = @_;
	# $type =~ s/::MF/::SF/;
	$type =~ s/VRML::Field:://;
	return "new $type()";
}

package VRML::Field::SFNode;

sub ctype {"void *$_[1]"}      # XXX ???
sub calloc {"$_[1] = 0;"}
sub cfree {"$_[1] = 0;"}
sub cstruct {""}
sub cfunc {
	"$_[1] = (void *)SvIV($_[2]);"
}
sub cget {if(!defined $_[2]) {return "$_[1]"}
	else {die "SFNode index!??!"} }

sub as_string {
	$_[1]->as_string();
}

sub js_default { 'new SFNode("","NULL")' }

# javascript implemented in place because of special nature.
