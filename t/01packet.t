#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::HexString;

use IO::Handle; # autoflush

use Protocol::Gearman;

# parse/build
{
   my $bytes = "\0RES\x00\x00\x00\x01\x00\x00\x00\x06thingsTail";
   my ( $type, $data ) = Protocol::Gearman->parse_packet( $bytes );

   is( $type,  1,       '$type from parse_packet' );
   is( $data, "things", '$data from parse_packet' );

   is( $bytes, "Tail", '$bytes still has tail after parse_packet' );

   is_hexstr( Protocol::Gearman->build_packet( 15, "jobid" ),
              "\0REQ\x00\x00\x00\x0f\x00\x00\x00\x05jobid",
              'build_packet' );

   ok( exception { Protocol::Gearman->parse_packet( "No magic here" ) },
       'parse_packet dies with no magic' );
}

# send/recv
{
   pipe( my $rd, my $wr ) or die "Cannot pipe() - $!";
   $wr->autoflush(1);

   Protocol::Gearman->send_packet( $wr, 15, "a-job" );
   $rd->sysread( my $bytes, 8192 );
   is_hexstr( $bytes, "\0REQ\x00\x00\x00\x0f\x00\x00\x00\x05a-job",
      '$bytes written by send_packet' );

   $wr->syswrite( "\0RES\x00\x00\x00\x14\x00\x00\x00\x02OK" );

   my ( $type, $body ) = Protocol::Gearman->recv_packet( $rd );

   is( $type, 20,   '$type from recv_packet' );
   is( $body, "OK", '$body from recv_packet' );

   $wr->syswrite( "No magic here" );
   ok( exception { Protocol::Gearman->recv_packet( $rd ) },
       'recv_packet dies with no magic' );
   {
      $rd->blocking(0);
      $rd->sysread( my $tmp, 8192 ); # drain
      $rd->blocking(1);
   }
}

done_testing;
