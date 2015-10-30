package PerlWRL;
use 5.20.2;
use strict;
use warnings;

use Exporter;

our @ISA = ('Exporter');

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use PerlWRL ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw() ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.01';


# Preloaded methods go here.

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

PerlWRL - Perl extension for blah blah blah

=head1 SYNOPSIS

  use PerlWRL;


=head1 DESCRIPTION

Blah blah blah.


=head2 EXPORT

None by default.


=head1 SEE ALSO


=head1 AUTHOR

Revlin John, E<lt>revlin@uni-sol.orgE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Revlin John

See ARTISTIC.md and LICENSE.md


=cut
