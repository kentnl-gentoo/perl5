#!perl
use strict;
use warnings;
use Unicode::Collate::Locale;

our (@listEs, @listEsT, @listFr);

BEGIN {

@listEs = qw(
    cambio camella camello camelo Camer�n 
    chico chile Chile CHILE chocolate
    cielo curso espacio espanto espa�ol esperanza lama l�quido
    llama Llama LLAMA llamar luz nos nueve �u ojo
);

@listEsT = qw(
    cambio camelo camella camello Camer�n cielo curso
    chico chile Chile CHILE chocolate
    espacio espanto espa�ol esperanza lama l�quido luz
    llama Llama LLAMA llamar nos nueve �u ojo
);

@listFr = (
  qw(
    cadurcien c�cum c�CUM C�CUM C�CUM caennais c�sium cafard
    coercitif cote c�te C�te cot� Cot� c�t� C�t� coter
    �l�ve �lev� g�ne g�ne M�CON ma�on
    p�che P�CHE p�che P�CHE p�ch� P�CH� p�cher p�cher
    rel�ve relev� r�v�le r�v�l�
    sur�l�vation s�rement sur�minent s�ret�
    vice-consul vicennal vice-pr�sident vice-roi vic�simal),
  "vice versa", "vice-versa",
);

use Test;
plan tests => 10 + $#listEs + 2 + $#listEsT + 2 + $#listFr + 2;

}

ok(1);
ok(Unicode::Collate::Locale::_locale('es_MX'), 'es');
ok(Unicode::Collate::Locale::_locale('en_CA'), 'default');

my $Collator = Unicode::Collate::Locale->
    new(normalization => undef);
ok($Collator->getlocale, 'default');

ok(
  join(':', $Collator->sort(
    qw/ lib strict Carp ExtUtils CGI Time warnings Math overload Pod CPAN /
  ) ),
  join(':',
    qw/ Carp CGI CPAN ExtUtils lib Math overload Pod strict Time warnings /
  ),
);

ok($Collator->cmp("", ""), 0);
ok($Collator->eq("", ""));
ok($Collator->cmp("", "perl"), -1);
ok($Collator->gt("PERL", "perl"));

$Collator->change(level => 2);

ok($Collator->eq("PERL", "perl"));

my $objEs  = Unicode::Collate::Locale->new
    (normalization => undef, locale => 'ES');
ok($objEs->getlocale, 'es');

my $objEsT = Unicode::Collate::Locale->new
    (normalization => undef, locale => 'es_ES_traditional');
ok($objEsT->getlocale, 'es__traditional');

my $objFr  = Unicode::Collate::Locale->new
    (normalization => undef, locale => 'FR');
ok($objFr->getlocale, 'fr');

sub randomize { my %hash; @hash{@_} = (); keys %hash; } # ?!

for (my $i = 0; $i < $#listEs; $i++) {
    ok($objEs->lt($listEs[$i], $listEs[$i+1]));
}

for (my $i = 0; $i < $#listEsT; $i++) {
    ok($objEsT->lt($listEsT[$i], $listEsT[$i+1]));
}

for (my $i = 0; $i < $#listFr; $i++) {
    ok($objFr->lt($listFr[$i], $listFr[$i+1]));
}

our @randEs = randomize(@listEs);
our @sortEs = $objEs->sort(@randEs);
ok("@sortEs" eq "@listEs");

our @randEsT = randomize(@listEsT);
our @sortEsT = $objEsT->sort(@randEsT);
ok("@sortEsT" eq "@listEsT");

our @randFr = randomize(@listFr);
our @sortFr = $objFr->sort(@randFr);
ok("@sortFr" eq "@listFr");

__END__

