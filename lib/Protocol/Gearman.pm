#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Protocol::Gearman;

use strict;
use warnings;

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(
   parse_packet recv_packet
   build_packet send_packet
   pack_packet unpack_packet
);

use Carp;

=head1 NAME

C<Protocol::Gearman> - wire protocol support functions for Gearman

=head1 DESCRIPTION

This module provides the low-level functions required to implement a Gearman
connection (either a client or a worker). It is used primarily by other
modules in this distribution; it is not intended to be used directly.

For implementing a Gearman client or worker, see the modules

=over 2

=item *

L<Protocol::Gearman::Client>

=item *

L<Protocol::Gearman::Worker>

=back

For a simple synchronous Gearman client or worker module for use during
testing or similar, see

=over 2

=item *

L<Protocol::Gearman::Client::Connection>

=item *

L<Protocol::Gearman::Worker::Connection>

=back

=cut

=head1 CONSTANTS

The following families of constants are defined, along with export tags:

=head2 TYPE_* (:types)

The request/response types

=cut

# These are used internally but not exported
use constant {
   MAGIC_REQUEST  => "\0REQ",
   MAGIC_RESPONSE => "\0RES",
};

my %CONSTANTS = (
   TYPE_CAN_DO             => 1,
   TYPE_CANT_DO            => 2,
   TYPE_RESET_ABILITIES    => 3,
   TYPE_PRE_SLEEP          => 4,
   TYPE_NOOP               => 6,
   TYPE_SUBMIT_JOB         => 7,
   TYPE_JOB_CREATED        => 8,
   TYPE_GRAB_JOB           => 9,
   TYPE_NO_JOB             => 10,
   TYPE_JOB_ASSIGN         => 11,
   TYPE_WORK_STATUS        => 12,
   TYPE_WORK_COMPLETE      => 13,
   TYPE_WORK_FAIL          => 14,
   TYPE_GET_STATUS         => 15,
   TYPE_ECHO_REQ           => 16,
   TYPE_ECHO_RES           => 17,
   TYPE_SUBMIT_JOB_BG      => 18,
   TYPE_ERROR              => 19,
   TYPE_STATUS_RES         => 20,
   TYPE_SUBMIT_JOB_HIGH    => 21,
   TYPE_SET_CLIENT_ID      => 22,
   TYPE_CAN_DO_TIMEOUT     => 23,
   TYPE_ALL_YOURS          => 24,
   TYPE_WORK_EXCEPTION     => 25,
   TYPE_OPTION_REQ         => 26,
   TYPE_OPTION_RES         => 27,
   TYPE_WORK_DATA          => 28,
   TYPE_WORK_WARNING       => 29,
   TYPE_GRAB_JOB_UNIQ      => 30,
   TYPE_JOB_ASSIGN_UNIQ    => 31,
   TYPE_SUBMIT_JOB_HIGH_BG => 32,
   TYPE_SUBMIT_JOB_LOW     => 33,
   TYPE_SUBMIT_JOB_LOW_BG  => 34,
);

require constant;
constant->import( $_, $CONSTANTS{$_} ) for keys %CONSTANTS;
push @EXPORT_OK, keys %CONSTANTS;

our %EXPORT_TAGS = (
   'types' => [ grep { m/^TYPE_/  } keys %CONSTANTS ],
);

=head1 FUNCTIONS

=cut

=head2 ( $type, $body ) = parse_packet( $bytes )

Attempts to parse a complete message packet from the given byte string. If it
succeeds, it returns the type and data body, as an opaque byte string. If it
fails it returns an empty list.

If successful, it will remove the bytes of the packet form the C<$bytes>
scalar, which must therefore be mutable.

If the byte string begins with some bytes that are not recognised as the
Gearman packet magic for a response, the function will immediately throw an
exception before modifying the string.

=cut

sub parse_packet
{
   return unless length $_[0] >= 4;
   croak "Expected to find 'RES' magic in packet" unless
      unpack( "a4", $_[0] ) eq MAGIC_RESPONSE;

   return unless length $_[0] >= 12;

   my $bodylen = unpack( "x8 N", $_[0] );
   return unless length $_[0] >= 12 + $bodylen;

   # Now committed to extracting it
   my ( $type ) = unpack( "x4 N x4", substr $_[0], 0, 12, "" );
   my $body = substr $_[0], 0, $bodylen, "";

   return ( $type, $body );
}

=head2 ( $type, $body ) = recv_packet( $fh )

Attempts to read a complete packet from the given filehandle, blocking until
it is available. The results are undefined if this function is called on a
non-blocking filehandle.

If an IO error happens, an exception is thrown. If the first four bytes read
are not recognised as the Gearman packet magic for a response, the function
will immediately throw an exception. If either of these conditions happen, the
filehandle should be considered no longer valid and should be closed.

=cut

sub recv_packet
{
   my ( $fh ) = @_;

   $fh->read( my $magic, 4 ) or croak "Cannot read header - $!";
   croak "Expected to find 'RES' magic in packet" unless
      $magic eq MAGIC_RESPONSE;

   $fh->read( my $header, 8 ) or croak "Cannot read header - $!";
   my ( $type, $bodylen ) = unpack( "N N", $header );

   my $body = "";
   $fh->read( $body, $bodylen ) or croak "Cannot read body - $!" if $bodylen;

   return ( $type, $body );
}

=head2 $bytes = build_packet( $type, $body )

Returns a byte string containing a complete packet with the given fields.

=cut

sub build_packet
{
   my ( $type, $body ) = @_;

   return pack "a4 N N a*", MAGIC_REQUEST, $type, length $body, $body;
}

=head2 send_packet( $fh, $type, $body )

Sends a complete packet to the given filehandle. If an IO error happens, an
exception is thrown.

=cut

sub send_packet
{
   my $fh = shift;
   $fh->print( build_packet( @_ ) ) or croak "Cannot send packet - $!";
}

# All Gearman packet bodies follow a standard format, of a fixed number of
# string arguments (given by the packet type), separated by a single NUL byte.
# All but the final argument may not contain embedded NULs.

my %TYPENAMES = map { m/^TYPE_(.*)$/ ? ( $CONSTANTS{$_} => $1 ) : () } keys %CONSTANTS;

my %ARGS_FOR_TYPE = (
   # In order from doc/PROTOCOL
   # common
   ECHO_REQ           => 1,
   ECHO_RES           => 1,
   ERROR              => 2,
   # client->server
   SUBMIT_JOB         => 3,
   SUBMIT_JOB_BG      => 3,
   SUBMIT_JOB_HIGH    => 3,
   SUBMIT_JOB_HIGH_BG => 3,
   SUBMIT_JOB_LOW     => 3,
   SUBMIT_JOB_LOW_BG  => 3,
   GET_STATUS         => 1,
   OPTION_REQ         => 1,
   # server->client
   JOB_CREATED        => 1,
   STATUS_RES         => 5,
   OPTION_RES         => 1,
   # worker->server
   CAN_DO             => 1,
   CAN_DO_TIMEOUT     => 2,
   CANT_DO            => 1,
   RESET_ABILITIES    => 0,
   PRE_SLEEP          => 0,
   GRAB_JOB           => 0,
   GRAB_JOB_UNIQ      => 0,
   WORK_DATA          => 2,
   WORK_WARNING       => 2,
   WORK_STATUS        => 3,
   WORK_COMPLETE      => 2,
   WORK_FAIL          => 1,
   WORK_EXCEPTION     => 2,
   SET_CLIENT_ID      => 1,
   ALL_YOURS          => 0,
   # server->worker
   NOOP               => 0,
   NO_JOB             => 0,
   JOB_ASSIGN         => 3,
   JOB_ASSIGN_UNIQ    => 4,
);

=head2 ( $type, $body ) = pack_packet( $name, @args )

Given a name of a packet type (specified as a string as the name of one of the
C<TYPE_*> constants, without the leading C<TYPE_> prefix; case insignificant)
returns the type value and the arguments for the packet packed into a body
string. This is intended for passing directly into C<build_packet> or
C<send_packet>:

 send_packet $fh, pack_packet( SUBMIT_JOB => $func, $id, $arg );

=cut

sub pack_packet
{
   my ( $typename, @args ) = @_;

   my $typefn = __PACKAGE__->can( "TYPE_\U$typename" ) or
      croak "Unrecognised packet type '$typename'";

   my $n_args = $ARGS_FOR_TYPE{uc $typename};

   @args == $n_args or croak "Expected '\U$typename\E' to take $n_args args";
   $args[$_] =~ m/\0/ and croak "Non-final argument [$_] of '\U$typename\E' cannot contain a \\0"
      for 0 .. $n_args-2;

   my $type = $typefn->();
   return ( $type, join "\0", @args );
}

=head2 ( $name, @args ) = unpack_packet( $type, $body )

Given a type code and body string, returns the type name and unpacked
arguments from the body. This function is the reverse of C<pack_packet> and is
intended to be used on the result of C<parse_packet> or C<recv_packet>:

The returned C<$name> will always be a fully-captialised type name, as one of
the C<TYPE_*> constants without the leading C<TYPE_> prefix.

This is intended for a C<given/when> control block, or dynamic method
dispatch:

 my ( $name, @args ) = unpack_packet( recv_packet $fh );

 $self->${\"handle_$name"}( @args )

=cut

sub unpack_packet
{
   my ( $type, $body ) = @_;

   my $typename = $TYPENAMES{$type} or
      croak "Unrecognised packet type $type";

   my $n_args = $ARGS_FOR_TYPE{$typename};

   return ( $typename ) if $n_args == 0;
   return ( $typename, split m/\0/, $body, $n_args );
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
