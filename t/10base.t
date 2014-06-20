#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::HexString;

{
   package TestBase;
   use base qw( Protocol::Gearman );

   sub new { bless {}, shift }
}

my $base = TestBase->new;

ok( defined $base, '$base defined' );

# send
{
   my $sent = "";
   no warnings 'once';
   local *TestBase::send = sub {
      shift;
      $sent .= $_[0];
   };

   $base->pack_send_packet( SUBMIT_JOB => "func", "id", "ARGS" );

   is_hexstr( $sent, "\0REQ\x00\x00\x00\x07\x00\x00\x00\x0c" .
         "func\0id\0ARGS",
      'data written by ->pack_send_packet' );
}

# recv
{
   my $buffer = "\0RES\x00\x00\x00\x08\x00\x00\x00\x04ABCDT";

   my $new_handle;

   no warnings 'once';
   local *TestBase::on_JOB_CREATED = sub {
      shift;
      ( $new_handle ) = @_;
   };

   $base->on_read( $buffer );

   is( $buffer, "T", 'on_read consumes data, leaves tail' );
   is( $new_handle, "ABCD", '$new_handle set after ->on_read' );

   $buffer = "\0RES\x00\x00\x00\x13\x00\x00\x00\x15fail\0This call failed";

   like( exception { $base->on_read( $buffer ) },
      qr/"This call failed"/, 'automatic ERROR packet handling' );
}

done_testing;
