#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Protocol::Gearman::Worker::Connection;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw( Protocol::Gearman::Connection Protocol::Gearman::Worker );

=head1 NAME

C<Protocol::Gearman::Worker::Connection> - concrete Gearman worker over an IP
socket

=head1 SYNOPSIS

 use List::Util qw( sum );
 use Protocol::Gearman::Worker::Connection;

 my $worker = Protocol::Gearman::Worker::Connection->new(
    PeerAddr => $SERVER,
 ) or die "Cannot connect - $@\n";

 $worker->can_do( 'sum' );

 while(1) {
    my $job = $worker->grab_job->get;

    my $total = sum split m/,/, $job->arg;

    $job->complete( $total );
 }

=head1 DESCRIPTION

This module combines the abstract L<Protocol::Gearman::Worker> with
L<Protocol::Gearman::Connection> to provide a simple synchronous concrete
worker implementation.

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
