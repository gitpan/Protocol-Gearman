#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Future;
use Protocol::Gearman::Worker;

{
   package TestWorker;
   use base qw( Protocol::Gearman::Worker );

   sub new { bless {}, shift }

   sub new_future { return Future->new }
}

my $worker = TestWorker->new;

# can_do
{
   my $received;

   no warnings 'once';
   local *TestWorker::pack_send_packet = sub {
      shift;
      my ( $type, @args ) = @_;

      is( $type, "CAN_DO", '$type for sent packet by ->can_do' );
      is_deeply( \@args, [ "function" ], '@args for packet sent by ->can_do' );

      $received++;
   };

   $worker->can_do( "function" );

   ok( $received, 'Actually received CAN_DO packet' );
}

my $job;

# grab_job
{
   my @queue;
   my $received_grab;
   my $received_presleep;

   no warnings 'once';
   local *TestWorker::pack_send_packet = sub {
      my $self = shift;
      my ( $type, @args ) = @_;

      if( $type eq "GRAB_JOB" ) {
         # Respond to GRAB_JOB with NO_JOB the first time so we can test the
         # sleep logic
         if( !$received_grab ) {
            $received_grab++;
            $self->on_NO_JOB();
         }
         else {
            $self->on_JOB_ASSIGN( "the-handle", "func", "arg" );
         }
      }
      elsif( $type eq "PRE_SLEEP" ) {
         $received_presleep++;
         $self->on_NOOP();
      }
      else {
         die "Received unexpected packet $type\n";
      }
   };

   $job = $worker->grab_job->get;

   ok( $received_grab, 'Actually received GRAB_JOB' );
   ok( $received_presleep, 'Actually received PRE_SLEEP' );

   is( $job->handle, "the-handle", '$job->handle' );
   is( $job->func,   "func",       '$job->func' );
   is( $job->arg,    "arg",        '$job->arg' );
}

# job status update methods
{
   my @received;

   no warnings 'once';
   local *TestWorker::pack_send_packet = sub {
      shift;
      my ( $type, @args ) = @_;
      push @received, [ $type => @args ];
   };

   $job->status( 0, 1 );
   $job->data( "moredata" );
   $job->warning( "Ooops?" );
   $job->status( 1, 1 );

   $job->complete( "result" );

   is_deeply( \@received,
      [ [ WORK_STATUS   => "the-handle", 0, 1 ],
        [ WORK_DATA     => "the-handle", "moredata" ],
        [ WORK_WARNING  => "the-handle", "Ooops?" ],
        [ WORK_STATUS   => "the-handle", 1, 1 ],
        [ WORK_COMPLETE => "the-handle", "result" ],
     ],
      'Packets sent by job update methods'
   );
}

done_testing;
