#!/usr/bin/perl

use strict;
use warnings;

use Net::Gearman::Worker;

my $worker = Net::Gearman::Worker->new(
   PeerAddr => "127.0.0.1",
) or die "Cannot connect - $@\n";

my %FUNCS = (
   strrev => sub { scalar reverse $_[0] },
   strtoupper => sub { uc $_[0] },
   strtolower => sub { lc $_[0] },
);

$worker->can_do( $_ ) for keys %FUNCS;

while(1) {
   my $job = $worker->grab_job->get;

   $job->status( 0, 2 );

   my $result = $FUNCS{$job->func}->( $job->arg );

   $job->status( 1, 2 );

   $job->data( substr $result, 0, 1, "" );

   $job->status( 2, 2 );
   $job->complete( $result );
}
