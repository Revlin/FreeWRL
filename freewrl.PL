# Copyright (C) 1998 Tuomas J. Lukka
# DISTRIBUTED WITH NO WARRANTY, EXPRESS OR IMPLIED.
# See the GNU General Public License (file COPYING in the distribution)
# for conditions of use and redistribution.
#
# Based on files from PDL and Perl 

use Config;
use File::Basename qw(&basename &dirname);

# List explicitly here the variables you want Configure to
# generate.  Metaconfig only looks for shell variables, so you
# have to mention them as if they were shell variables, not
# %Config entries.  Thus you write
#  $startperl
# to ensure Configure will look for $Config{startperl}.

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
        if ($^O eq 'VMS' or $^O eq 'os2');  # "case-forgiving"

unlink $file if -f $file;
open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";

# In this section, perl variables will be expanded during extraction.
# You can use $Config{...} to use Configure variables.

print OUT <<"!GROK!THIS!";
$Config{'startperl'}
    eval 'exec perl -S \$0 "\$@"'
        if 0;
!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';

##########################################################################
# Here starts the actual script
# GENERATED FROM freewrl.PL -- DO NOT MODIFY

# Copyright (C) 1998 Tuomas J. Lukka
# DISTRIBUTED WITH NO WARRANTY, EXPRESS OR IMPLIED.
# See the GNU General Public License (file COPYING in the distribution)
# for conditions of use and redistribution.

use blib;
use Carp;
$SIG{__DIE__} = sub {print Carp::longmess(@_);die;};

# use VRML::Browser;

my @verb = @ARGV[1..$#ARGV];

sub verb {return !!grep {$_ eq $_[0] or $_ eq "all"} @verb}
sub verbn {return !!grep {$_ eq $_[0]} @verb}

# Turn these switches on if you are debugging
$VRML::verbose = verb all;
$VRML::verbose::be = verb be;
$VRML::verbose::oint = verb oint; # OrientationIntepr
$VRML::verbose::events = verb ev;
$VRML::verbose::script = verb scr ;  
$VRML::verbose::glsens = verb glsens;  # GL sensor code
$VRML::verbose::tief = verb "tie";    # The tied RFields-hash
$VRML::verbose::timesens = verb "time";
$VRML::verbose::interp = verb "interp"; # interpolators
$VRML::verbose::text = verbn "text"; # interpolators
$VRML::verbose::rend = verb "rend";
$VRML::verbose::nodec = verb "nodec";
$VRML::verbose::bind = verb "bind";

if($VRML::verbose::text) {
	eval 'require VRML::Text; VRML::Text::set_verbose(1);'
}

require 'VRML/Browser.pm';

$b = new VRML::Browser(); # By default creates front- and back-ends.

$b->load_file($ARGV[0]);

VRML::VRMLFunc::set_divs(10,10);
$b->eventloop();

!NO!SUBS!

close OUT;
chmod 0555, $file;
