#!/usr/bin/perl

use strict;
use warnings;

use Protocol::Gearman::Client::Connection;

my $func = shift @ARGV // die "Need func\n";
my $arg  = shift @ARGV // die "Need arg\n";

my $conn = Protocol::Gearman::Client::Connection->new(
   PeerAddr => "127.0.0.1",
) or die "Cannot connect - $@\n";

my $result = $conn->submit_job(
   func => $func,
   arg  => $arg,

   on_data => sub {
      my ( $data ) = @_;
      print $data;
   },

   on_status => sub {
      my ( $num, $denom ) = @_;
      print STDERR "\e[1;36mStatus $num / $denom\e[m...\n";
   },
)->get;

if( defined $result ) {
   print $result . "\n";
}
else {
   print STDERR "Job Failed\n";
}
