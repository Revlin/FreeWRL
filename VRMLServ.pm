# Copyright (C) 1998 Tuomas J. Lukka
# DISTRIBUTED WITH NO WARRANTY, EXPRESS OR IMPLIED.
# See the GNU General Public License (file COPYING in the distribution)
# for conditions of use and redistribution.

# Implement communication with EAI and script processes.

package VRML::Server;

sub new {
	my($type,$scene,$eventmodel) = @_;
	my $this = bless {
		Scene => $scene,
		EM => $eventmodel,
	}, $type;
	VRML::add_periodic($this->poll);
}

sub get {
}
