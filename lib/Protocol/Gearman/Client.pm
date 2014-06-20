#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014 -- leonerd@leonerd.org.uk

package Protocol::Gearman::Client;

use strict;
use warnings;

our $VERSION = '0.02';

use base qw( Protocol::Gearman );

use Carp;

use Struct::Dumb qw( readonly_struct );

readonly_struct Job => [qw( f on_data on_warning on_status )];

=head1 NAME

C<Protocol::Gearman::Client> - implement a Gearman client

=head1 DESCRIPTION

A base class that implements a complete Gearman client. This abstract class
still requires the implementation methods as documented in
L<Protocol::Gearman>, but otherwise provides a full set of behaviour useful to
Gearman clients.

As it is based on L<Future> it is suitable for both synchronous and
asynchronous use. When backed by an implementation capable of performing
asynchronously, this object fully supports asynchronous Gearman communication.
When backed by a synchronous implementation, it will still yield C<Future>
instances but the limitations of the synchronous implementation may limit how
much concurrency and asynchronous behaviour can be acheived.

A simple concrete implementation suitable for synchronous use can be found in
L<Net::Gearman::Client>.

=cut

=head1 METHODS

=cut

=head2 $client->submit_job( %args ) ==> $result

Submits a job request to the Gearman server, and returns a future that will
eventually yield the result of the job or its failure.

Takes the following required arguments:

=over 8

=item func => STRING

The name of the function to call

=item arg => STRING

An opaque bytestring containing the argument data for the function. Its exact
format should be specified by the registered function.

=back

Takes the following optional arguments;

=over 8

=item on_data => CODE

Invoked on receipt of more incremental data from the worker.

 $on_data->( $data )

=item on_warning => CODE

Invoked on receipt of a warning from the worker.

 $on_warning->( $warning )

=item on_status => CODE

Invoked on a status update from the worker.

 $on_status->( $numerator, $denominator )

=back

=cut

sub submit_job
{
   my $self = shift;
   my %args = @_;

   my $func = $args{func} // croak "Required 'func' is missing in submit_job";
   my $arg  = $args{arg}  // croak "Required 'arg' is missing in submit_job";

   my $state = $self->gearman_state;

   my $submit_f = $self->new_future;
   push @{ $state->{gearman_submits} }, $submit_f;

   my $f = $self->new_future;
   $submit_f->on_done( sub {
      my ( $job_handle ) = @_;

      $state->{gearman_job}{$job_handle} = Job(
         $f, $args{on_data}, $args{on_warning}, $args{on_status}
      );
   });

   $self->pack_send_packet( SUBMIT_JOB => $func, $state->{gearman_next_id}++, $arg );

   return $f;
}

sub on_JOB_CREATED
{
   my $self = shift;
   my ( $job_handle ) = @_;

   my $state = $self->gearman_state;

   my $f = shift @{ $state->{gearman_submits} };
   $f->done( $job_handle );
}

sub on_WORK_DATA
{
   my $self = shift;
   my ( $job_handle, $data ) = @_;

   my $state = $self->gearman_state;

   my $job = $state->{gearman_job}{$job_handle};

   $job->on_data->( $data ) if $job->on_data;
}

sub on_WORK_WARNING
{
   my $self = shift;
   my ( $job_handle, $warning ) = @_;

   my $state = $self->gearman_state;

   my $job = $state->{gearman_job}{$job_handle};

   $job->on_warning->( $warning ) if $job->on_warning;
}

sub on_WORK_STATUS
{
   my $self = shift;
   my ( $job_handle, $num, $denom ) = @_;

   my $state = $self->gearman_state;

   my $job = $state->{gearman_job}{$job_handle};

   $job->on_status->( $num, $denom ) if $job->on_status;
}

sub on_WORK_COMPLETE
{
   my $self = shift;
   my ( $job_handle, $result ) = @_;

   my $state = $self->gearman_state;

   my $job = delete $state->{gearman_job}{$job_handle};

   $job->f->done( $result );
}

sub on_WORK_FAIL
{
   my $self = shift;
   my ( $job_handle ) = @_;

   my $state = $self->gearman_state;

   my $job = delete $state->{gearman_job}{$job_handle};

   $job->f->fail( "Work failed" );
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
