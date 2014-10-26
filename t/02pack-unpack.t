#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::HexString;

use Protocol::Gearman qw( pack_packet unpack_packet :types );

# pack
{
   my ( $type, $body ) = pack_packet SUBMIT_JOB => "func", "my-job-id", "args\0go\0here";
   is( $type, TYPE_SUBMIT_JOB, '$type from pack_packet SUBMIT_JOB' );
   is_hexstr( $body, "func\0my-job-id\0args\0go\0here",
      '$body from pack_packet SUBMIT_JOB' );

   ok( exception { pack_packet UNKNOWN_TYPE => 1 },
      'unknown type raises an exception' );

   ok( exception { pack_packet SUBMIT_JOB => 1, 2 },
      'wrong argument count raises exception' );

   ok( exception { pack_packet SUBMIT_JOB => "my-id", "my\0id\0here", "args" },
      'embedded NUL in non-final argument raises exception' );
}

# unpack
{
   my ( $name, @args ) = unpack_packet TYPE_SUBMIT_JOB, "a-func\0the-id\0some\0more\0args";
   is( $name, "SUBMIT_JOB", '$name from unpack_packet SUBMIT_JOB' );
   is_deeply( \@args, [ "a-func", "the-id", "some\0more\0args" ],
         '@args from unpack_packet TYPE_SUBMIT_JOB' );

   ok( exception { unpack_packet 12345, "some body" },
       'unknown type raises an exception' );
}

done_testing;
