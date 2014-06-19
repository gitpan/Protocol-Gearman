#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Protocol::Gearman::Base;

use strict;
use warnings;

our $VERSION = '0.01';

use Protocol::Gearman qw(
   build_packet pack_packet
   parse_packet unpack_packet
);

=head1 NAME

C<Protocol::Gearman::Base> - abstract base class for both client and worker

=head1 DESCRIPTION

This base class is used by both L<Protocol::Gearman::Client> and
L<Protocol::Gearman::Worker>. It shouldn't be used directly by end-user
implementations. It is documented here largely to explain what methods an end
implementation needs to provide, in order to create a Gearman client or
worker.

=cut

=head1 PROVIDED METHODS

=cut

=head2 $base->pack_send_packet( $typename, @args )

Packs a packet from a list of arguments then sends it; a combination of
C<Protocol::Gearman::pack_packet> and C<Protocol::Gearman::build_packet>. Uses
the implementation's C<send> method.

=cut

sub pack_send_packet
{
   my $self = shift;
   $self->send( build_packet pack_packet @_ );
}

=head2 $base->on_read( $buffer )

The implementation should call this method on receipt of more bytes of data.
It parses and unpacks packets from the buffer, then dispatches to the
appropriately named C<on_*> method. A combination of
C<Protocol::Gearman::parse_packet> and C<Protocol::Gearman::unpack_packet>.

The C<$buffer> scalar may be modified; if it still contains bytes left over
after the call these should be preserved by the implementation for the next
time it is called.

=cut

sub on_read
{
   my $self = shift;

   while( my ( $typenum, $body ) = parse_packet $_[0] ) {
      my ( $type, @args ) = unpack_packet $typenum, $body;
      $self->${\"on_$type"}( @args );
   }
}

=head2 $connection->on_ERROR( $name, $message )

Default handler for the C<TYPE_ERROR> packet. This method should be overriden
by subclasses to change the behaviour.

=cut

sub on_ERROR
{
   my $self = shift;
   my ( $name, $message ) = @_;

   die "Received Gearman error '$name' (\"$message\")\n";
}

=head1 REQUIRED METHODS

The implementation should provide the following methods:

=head2 $f = $base->new_future

Return a new L<Future> subclass instance, for request methods to use. This
instance should support awaiting appropriately.

=head2 $base->send( $bytes )

Send the given bytes to the server.

=head2 $base->on_I<TYPE>( @args )

Invoked on receipt of the given type of packet. The exact packet types
requried differs for clients or worker connections.

=head2 $h = $base->gearman_state

Return a HASH reference for the Gearman-related code to store its state on.
If not implemented, a default method will be provided which uses C<$base>
itself, for the common case of HASH-based methods.

=cut

sub gearman_state { shift }

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
