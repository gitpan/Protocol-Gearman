#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Protocol::Gearman::Connection;

use strict;
use warnings;

our $VERSION = '0.01';

use base qw( IO::Socket::IP );

=head1 NAME

C<Protocol::Gearman::Connection> - provide a synchronous concrete implementation

=head1 DESCRIPTION

This module provides a simple synchronous concrete implementation to run a
L<Protocol::Gearman::Client> or L<Protocol::Gearman::Worker> on top of. It
shouldn't be used directly; see instead

=over 2

=item *

L<Protocol::Gearman::Client::Connection>

=item *

L<Protocol::Gearman::Worker::Connection>

=back

=head1 CONSTRUCTOR

=cut

=head2 $connection = Protocol::Gearman::Connection->new( %args )

Returns a new C<Protocol::Gearman::Connection> object. Takes the same
arguments as C<IO::Socket::IP>. Sets a default value for C<PeerService> if not
provided of 4730.

=cut

sub new
{
   my $class = shift;
   my %args = @_ == 1 ? ( PeerHost => shift ) : @_;

   $args{PeerService} //= 4730;

   return $class->SUPER::new( %args );
}

sub gearman_state
{
   my $self = shift;
   ${*$self}{gearman} ||= {};
}

sub new_future
{
   my $self = shift;
   return Protocol::Gearman::Connection::Future->new( $self );
}

sub do_read
{
   my $self = shift;

   my $buffer = $self->gearman_state->{gearman_buffer} // "";

   # TODO: consider an on_read_packet to make this more efficient
   $self->sysread( $buffer, 8192, length $buffer );
   $self->on_read( $buffer );

   $self->gearman_state->{gearman_buffer} = $buffer;
}

package # hide
   Protocol::Gearman::Connection::Future;
use base qw( Future );

sub new
{
   my $class = shift;
   my ( $conn ) = @_;
   my $self = $class->SUPER::new;
   $self->{conn} = $conn;
   return $self;
}

sub await
{
   my $self = shift;

   while( !$self->is_ready ) {
      $self->{conn}->do_read;
   }
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
