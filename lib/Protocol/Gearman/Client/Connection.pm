#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Protocol::Gearman::Client::Connection;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw( Protocol::Gearman::Connection Protocol::Gearman::Client );

=head1 NAME

C<Protocol::Gearman::Client::Connection> - concrete Gearman client over an IP
socket

=head1 SYNOPSIS

 use Protocol::Gearman::Client::Connection;

 my $client = Protocol::Gearman::Client::Connection->new(
    PeerAddr => $SERVER,
 ) or die "Cannot connect - $@\n";

 my $total = $client->submit_job(
    func => "sum",
    arg  => "10,20,30",
 )->get;

 say $total;

=head1 DESCRIPTION

This module combines the abstract L<Protocol::Gearman::Client> with
L<Protocol::Gearman::Connection> to provide a simple synchronous concrete
client implementation.

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
