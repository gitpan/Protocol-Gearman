#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Protocol::Gearman::Worker;

use strict;
use warnings;

our $VERSION = '0.02';

use base qw( Protocol::Gearman );

use Carp;

=head1 NAME

C<Protocol::Gearman::Worker> - a simple synchronous Gearman worker binding

=head1 DESCRIPTION

A base class that implements a complete Gearman worker. This abstract class
still requires the implementation methods as documented in
L<Protocol::Gearman>, but otherwise provides a full set of behaviour useful to
Gearman workers.

As it is based on L<Future> it is suitable for both synchronous and
asynchronous use. When backed by an implementation capable of performing
asynchronously, this object fully supports asynchronous Gearman communication.
When backed by a synchronous implementation, it will still yield C<Future>
instances but the limitations of the synchronous implementation may limit how
much concurrency and asynchronous behaviour can be acheived.

A simple concrete implementation suitable for synchronous use can be found in
L<Net::Gearman::Worker>.

=cut

=head1 METHODS

=cut

=head2 $worker->can_do( $name )

Informs the server that the worker can perform a function of the given name.

=cut

sub can_do
{
   my $self = shift;
   my ( $name ) = @_;

   $self->pack_send_packet( CAN_DO => $name );
}

=head2 $worker->grab_job ==> $job

Returns a future that will eventually yield another job assignment from the
server as an instance of a job object; see below.

=cut

sub grab_job
{
   my $self = shift;

   my $state = $self->gearman_state;

   push @{ $state->{gearman_assigns} }, my $f = $self->new_future;

   $self->pack_send_packet( GRAB_JOB => );

   return $f;
}

sub on_JOB_ASSIGN
{
   my $self = shift;
   my @args = @_;

   my $state = $self->gearman_state;

   my $f = shift @{ $state->{gearman_assigns} };
   $f->done( Protocol::Gearman::Worker::Job->new( $self, @args ) );
}

# Manage Gearman's slightly odd sleep/wakeup job request loop

sub on_NO_JOB
{
   my $self = shift;

   $self->pack_send_packet( PRE_SLEEP => );
}

sub on_NOOP
{
   my $self = shift;

   my $state = $self->gearman_state;

   $self->pack_send_packet( GRAB_JOB => ) if @{ $state->{gearman_assigns} };
}

package # hide from CPAN
   Protocol::Gearman::Worker::Job;

=head1 JOB OBJECTS

Objects of this type are returned by the C<grab_job> method. They represent
individual job assignments from the server, and can be used to obtain details
of the work to perform, and report on its result.

=cut

sub new
{
   my $class = shift;
   my ( $worker, $handle, $func, $arg ) = @_;

   return bless {
      worker => $worker,
      handle => $handle,
      func   => $func,
      arg    => $arg,
   }, $class;
}

=head2 $worker = $job->worker

Returns the C<Protocol::Gearman::Worker> object the job was received by.

=head2 $handle = $job->handle

Returns the job handle assigned by the server. Most implementations should not
need to use this directly.

=head2 $func = $job->func

=head2 $arg = $job->arg

The function name and opaque argument data bytes sent by the requesting
client.

=cut

sub worker { $_[0]->{worker} }
sub handle { $_[0]->{handle} }
sub func   { $_[0]->{func} }
sub arg    { $_[0]->{arg} }

=head2 $job->data( $data )

Sends more data back to the client. Intended for long-running jobs with
incremental output.

=cut

sub data
{
   my $self = shift;
   my ( $data ) = @_;

   $self->worker->pack_send_packet( WORK_DATA => $self->handle, $data );
}

=head2 $job->warning( $warning )

Sends a warning to the client.

=cut

sub warning
{
   my $self = shift;
   my ( $warning ) = @_;

   $self->worker->pack_send_packet( WORK_WARNING => $self->handle, $warning );
}

=head2 $job->status( $numerator, $denominator )

Sets the current progress of the job.

=cut

sub status
{
   my $self = shift;
   my ( $num, $denom ) = @_;

   $self->worker->pack_send_packet( WORK_STATUS => $self->handle, $num, $denom );
}

=head2 $job->complete( $result )

Informs the server that the job is now complete, and sets its result.

=cut

sub complete
{
   my $self = shift;
   my ( $result ) = @_;

   $self->worker->pack_send_packet( WORK_COMPLETE => $self->handle, $result );
}

=head2 $job->fail

Informs the server that the job has failed.

=cut

sub fail
{
   my $self = shift;

   $self->worker->pack_send_packet( WORK_FAIL => $self->handle );
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
