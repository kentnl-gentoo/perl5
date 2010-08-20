#!perl
use strict;
use warnings;
use Unicode::Collate::Locale;

use Test;
plan tests => 28;

my $objFr = Unicode::Collate::Locale->
    new(locale => 'FR', normalization => undef);

ok(1);
ok($objFr->getlocale, 'fr');

$objFr->change(level => 1);

ok($objFr->eq("�", "AE"));
ok($objFr->eq("�", "ae"));
ok($objFr->eq("\x{01FD}", "ae"));
ok($objFr->eq("\x{01FC}", "AE"));
ok($objFr->eq("\x{01E3}", "ae"));
ok($objFr->eq("\x{01E2}", "AE"));
ok($objFr->eq("\x{1D2D}", "AE"));

$objFr->change(level => 2);

ok($objFr->gt("�", "AE"));
ok($objFr->gt("�", "ae"));
ok($objFr->gt("\x{01FD}", "ae"));
ok($objFr->gt("\x{01FC}", "AE"));
ok($objFr->gt("\x{01E3}", "ae"));
ok($objFr->gt("\x{01E2}", "AE"));
ok($objFr->gt("\x{1D2D}", "AE"));

ok($objFr->eq("�\x{304}", "\x{01E2}"));
ok($objFr->eq("�\x{304}", "\x{01E3}"));
ok($objFr->eq("�\x{301}", "\x{01FC}"));
ok($objFr->eq("�\x{301}", "\x{01FD}"));

$objFr->change(level => 3);

ok($objFr->lt("�\x{304}", "\x{01E2}"));
ok($objFr->eq("�\x{304}", "\x{01E2}"));
ok($objFr->eq("�\x{304}", "\x{01E3}"));
ok($objFr->gt("�\x{304}", "\x{01E3}"));

ok($objFr->lt("�\x{301}", "\x{01FC}"));
ok($objFr->eq("�\x{301}", "\x{01FC}"));
ok($objFr->eq("�\x{301}", "\x{01FD}"));
ok($objFr->gt("�\x{301}", "\x{01FD}"));


