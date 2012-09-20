package CharClass::Matcher;
use strict;
use 5.008;
use warnings;
use warnings FATAL => 'all';
use Text::Wrap qw(wrap);
use Data::Dumper;
$Data::Dumper::Useqq= 1;
our $hex_fmt= "0x%02X";

sub ASCII_PLATFORM { (ord('A') == 65) }

require 'regen/regen_lib.pl';

=head1 NAME

CharClass::Matcher -- Generate C macros that match character classes efficiently

=head1 SYNOPSIS

    perl Porting/regcharclass.pl

=head1 DESCRIPTION

Dynamically generates macros for detecting special charclasses
in latin-1, utf8, and codepoint forms. Macros can be set to return
the length (in bytes) of the matched codepoint, and/or the codepoint itself.

To regenerate F<regcharclass.h>, run this script from perl-root. No arguments
are necessary.

Using WHATEVER as an example the following macros can be produced, depending
on the input parameters (how to get each is described by internal comments at
the C<__DATA__> line):

=over 4

=item C<is_WHATEVER(s,is_utf8)>

=item C<is_WHATEVER_safe(s,e,is_utf8)>

Do a lookup as appropriate based on the C<is_utf8> flag. When possible
comparisons involving octect<128 are done before checking the C<is_utf8>
flag, hopefully saving time.

The version without the C<_safe> suffix should be used only when the input is
known to be well-formed.

=item C<is_WHATEVER_utf8(s)>

=item C<is_WHATEVER_utf8_safe(s,e)>

Do a lookup assuming the string is encoded in (normalized) UTF8.

The version without the C<_safe> suffix should be used only when the input is
known to be well-formed.

=item C<is_WHATEVER_latin1(s)>

=item C<is_WHATEVER_latin1_safe(s,e)>

Do a lookup assuming the string is encoded in latin-1 (aka plan octets).

The version without the C<_safe> suffix should be used only when it is known
that C<s> contains at least one character.

=item C<is_WHATEVER_cp(cp)>

Check to see if the string matches a given codepoint (hypothetically a
U32). The condition is constructed as as to "break out" as early as
possible if the codepoint is out of range of the condition.

IOW:

  (cp==X || (cp>X && (cp==Y || (cp>Y && ...))))

Thus if the character is X+1 only two comparisons will be done. Making
matching lookups slower, but non-matching faster.

=item C<what_len_WHATEVER_FOO(arg1, ..., len)>

A variant form of each of the macro types described above can be generated, in
which the code point is returned by the macro, and an extra parameter (in the
final position) is added, which is a pointer for the macro to set the byte
length of the returned code point.

These forms all have a C<what_len> prefix instead of the C<is_>, for example
C<what_len_WHATEVER_safe(s,e,is_utf8,len)> and
C<what_len_WHATEVER_utf8(s,len)>.

These forms should not be used I<except> on small sets of mostly widely
separated code points; otherwise the code generated is inefficient.  For these
cases, it is best to use the C<is_> forms, and then find the code point with
C<utf8_to_uvchr_buf>().  This program can fail with a "deep recursion"
message on the worst of the inappropriate sets.  Examine the generated macro
to see if it is acceptable.

=item C<what_WHATEVER_FOO(arg1, ...)>

A variant form of each of the C<is_> macro types described above can be generated, in
which the code point and not the length is returned by the macro.  These have
the same caveat as L</what_len_WHATEVER_FOO(arg1, ..., len)>, plus they should
not be used where the set contains a NULL, as 0 is returned for two different
cases: a) the set doesn't include the input code point; b) the set does
include it, and it is a NULL.

=back

=head2 CODE FORMAT

perltidy  -st -bt=1 -bbt=0 -pt=0 -sbt=1 -ce -nwls== "%f"


=head1 AUTHOR

Author: Yves Orton (demerphq) 2007.  Maintained by Perl5 Porters.

=head1 BUGS

No tests directly here (although the regex engine will fail tests
if this code is broken). Insufficient documentation and no Getopts
handler for using the module as a script.

=head1 LICENSE

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the README file.

=cut

# Sub naming convention:
# __func : private subroutine, can not be called as a method
# _func  : private method, not meant for external use
# func   : public method.

# private subs
#-------------------------------------------------------------------------------
#
# ($cp,$n,$l,$u)=__uni_latin($str);
#
# Return a list of arrays, each of which when interpreted correctly
# represent the string in some given encoding with specific conditions.
#
# $cp - list of codepoints that make up the string.
# $n  - list of octets that make up the string if all codepoints are invariant
#       regardless of if the string is in UTF-8 or not.
# $l  - list of octets that make up the string in latin1 encoding if all
#       codepoints < 256, and at least one codepoint is UTF-8 variant.
# $u  - list of octets that make up the string in utf8 if any codepoint is
#       UTF-8 variant
#
#   High CP | Defined
#-----------+----------
#   0 - 127 : $n            (127/128 are the values for ASCII platforms)
# 128 - 255 : $l, $u
# 256 - ... : $u
#

sub __uni_latin1 {
    my $str= shift;
    my $max= 0;
    my @cp;
    my $only_has_invariants = 1;
    for my $ch ( split //, $str ) {
        my $cp= ord $ch;
        push @cp, $cp;
        $max= $cp if $max < $cp;
        if (! ASCII_PLATFORM && $only_has_invariants) {
            if ($cp > 255) {
                $only_has_invariants = 0;
            }
            else {
                my $temp = chr($cp);
                utf8::upgrade($temp);
                my @utf8 = unpack "U0C*", $temp;
                $only_has_invariants = (@utf8 == 1 && $utf8[0] == $cp);
            }
        }
    }
    my ( $n, $l, $u );
    $only_has_invariants = $max < 128 if ASCII_PLATFORM;
    if ($only_has_invariants) {
        $n= [@cp];
    } else {
        $l= [@cp] if $max && $max < 256;

        $u= $str;
        utf8::upgrade($u);
        $u= [ unpack "U0C*", $u ] if defined $u;
    }
    return ( \@cp, $n, $l, $u );
}

#
# $clean= __clean($expr);
#
# Cleanup a ternary expression, removing unnecessary parens and apply some
# simplifications using regexes.
#

sub __clean {
    my ( $expr )= @_;
    our $parens;
    $parens= qr/ (?> \( (?> (?: (?> [^()]+ ) | (??{ $parens }) )* ) \) ) /x;

    #print "$parens\n$expr\n";
    1 while $expr =~ s/ \( \s* ( $parens ) \s* \) /$1/gx;
    1 while $expr =~ s/ \( \s* ($parens) \s* \? \s*
        \( \s* ($parens) \s* \? \s* ($parens|[^:]+?) \s* : \s* ($parens|[^)]+?) \s* \)
        \s* : \s* \4 \s* \)/( ( $1 && $2 ) ? $3 : 0 )/gx;
    return $expr;
}

#
# $text= __macro(@args);
# Join args together by newlines, and then neatly add backslashes to the end
# of every  line as expected by the C pre-processor for #define's.
#

sub __macro {
    my $str= join "\n", @_;
    $str =~ s/\s*$//;
    my @lines= map { s/\s+$//; s/\t/        /g; $_ } split /\n/, $str;
    my $last= pop @lines;
    $str= join "\n", ( map { sprintf "%-76s\\", $_ } @lines ), $last;
    1 while $str =~ s/^(\t*) {8}/$1\t/gm;
    return $str . "\n";
}

#
# my $op=__incrdepth($op);
#
# take an 'op' hashref and add one to it and all its childrens depths.
#

sub __incrdepth {
    my $op= shift;
    return unless ref $op;
    $op->{depth} += 1;
    __incrdepth( $op->{yes} );
    __incrdepth( $op->{no} );
    return $op;
}

# join two branches of an opcode together with a condition, incrementing
# the depth on the yes branch when we do so.
# returns the new root opcode of the tree.
sub __cond_join {
    my ( $cond, $yes, $no )= @_;
    return {
        test  => $cond,
        yes   => __incrdepth( $yes ),
        no    => $no,
        depth => 0,
    };
}

# Methods

# constructor
#
# my $obj=CLASS->new(op=>'SOMENAME',title=>'blah',txt=>[..]);
#
# Create a new CharClass::Matcher object by parsing the text in
# the txt array. Currently applies the following rules:
#
# Element starts with C<0x>, line is evaled the result treated as
# a number which is passed to chr().
#
# Element starts with C<">, line is evaled and the result treated
# as a string.
#
# Each string is then stored in the 'strs' subhash as a hash record
# made up of the results of __uni_latin1, using the keynames
# 'low','latin1','utf8', as well as the synthesized 'LATIN1', 'high', and
# 'UTF8' which hold a merge of 'low' and their lowercase equivelents.
#
# Size data is tracked per type in the 'size' subhash.
#
# Return an object
#
sub new {
    my $class= shift;
    my %opt= @_;
    for ( qw(op txt) ) {
        die "in " . __PACKAGE__ . " constructor '$_;' is a mandatory field"
          if !exists $opt{$_};
    }

    my $self= bless {
        op    => $opt{op},
        title => $opt{title} || '',
    }, $class;
    foreach my $txt ( @{ $opt{txt} } ) {
        my $str= $txt;
        if ( $str =~ /^[""]/ ) {
            $str= eval $str;
        } elsif ($str =~ / - /x ) { # A range:  Replace this element on the
                                    # list with its expansion
            my ($lower, $upper) = $str =~ / 0x (.+?) \s* - \s* 0x (.+) /x;
            die "Format must be like '0xDEAD - 0xBEAF'; instead was '$str'" if ! defined $lower || ! defined $upper;
            foreach my $cp (hex $lower .. hex $upper) {
                push @{$opt{txt}}, sprintf "0x%X", $cp;
            }
            next;
        } elsif ($str =~ s/ ^ N (?= 0x ) //x ) {
            # Otherwise undocumented, a leading N means is already in the
            # native character set; don't convert.
            $str= chr eval $str;
        } elsif ( $str =~ /^0x/ ) {
            $str= eval $str;

            # Convert from Unicode/ASCII to native, if necessary
            $str = utf8::unicode_to_native($str) if ! ASCII_PLATFORM
                                                    && $str <= 0xFF;
            $str = chr $str;
        } elsif ( $str =~ / \s* \\p \{ ( .*? ) \} /x) {
            my $property = $1;
            use Unicode::UCD qw(prop_invlist);

            my @invlist = prop_invlist($property, '_perl_core_internal_ok');
            if (! @invlist) {

                # An empty return could mean an unknown property, or merely
                # that it is empty.  Call in scalar context to differentiate
                my $count = prop_invlist($property, '_perl_core_internal_ok');
                die "$property not found" unless defined $count;
            }

            # Replace this element on the list with the property's expansion
            for (my $i = 0; $i < @invlist; $i += 2) {
                foreach my $cp ($invlist[$i] .. $invlist[$i+1] - 1) {

                    # prop_invlist() returns native values; add leading 'N'
                    # to indicate that.
                    push @{$opt{txt}}, sprintf "N0x%X", $cp;
                }
            }
            next;
        } else {
            die "Unparsable line: $txt\n";
        }
        my ( $cp, $low, $latin1, $utf8 )= __uni_latin1( $str );
        my $UTF8= $low   || $utf8;
        my $LATIN1= $low || $latin1;
        my $high = (scalar grep { $_ < 256 } @$cp) ? 0 : $utf8;
        #die Dumper($txt,$cp,$low,$latin1,$utf8)
        #    if $txt=~/NEL/ or $utf8 and @$utf8>3;

        @{ $self->{strs}{$str} }{qw( str txt low utf8 latin1 high cp UTF8 LATIN1 )}=
          ( $str, $txt, $low, $utf8, $latin1, $high, $cp, $UTF8, $LATIN1 );
        my $rec= $self->{strs}{$str};
        foreach my $key ( qw(low utf8 latin1 high cp UTF8 LATIN1) ) {
            $self->{size}{$key}{ 0 + @{ $self->{strs}{$str}{$key} } }++
              if $self->{strs}{$str}{$key};
        }
        $self->{has_multi} ||= @$cp > 1;
        $self->{has_ascii} ||= $latin1 && @$latin1;
        $self->{has_low}   ||= $low && @$low;
        $self->{has_high}  ||= !$low && !$latin1;
    }
    $self->{val_fmt}= $hex_fmt;
    $self->{count}= 0 + keys %{ $self->{strs} };
    return $self;
}

# my $trie = make_trie($type,$maxlen);
#
# using the data stored in the object build a trie of a specific type,
# and with specific maximum depth. The trie is made up the elements of
# the given types array for each string in the object (assuming it is
# not too long.)
#
# returns the trie, or undef if there was no relevant data in the object.
#

sub make_trie {
    my ( $self, $type, $maxlen )= @_;

    my $strs= $self->{strs};
    my %trie;
    foreach my $rec ( values %$strs ) {
        die "panic: unknown type '$type'"
          if !exists $rec->{$type};
        my $dat= $rec->{$type};
        next unless $dat;
        next if $maxlen && @$dat > $maxlen;
        my $node= \%trie;
        foreach my $elem ( @$dat ) {
            $node->{$elem} ||= {};
            $node= $node->{$elem};
        }
        $node->{''}= $rec->{str};
    }
    return 0 + keys( %trie ) ? \%trie : undef;
}

sub pop_count ($) {
    my $word = shift;

    # This returns a list of the positions of the bits in the input word that
    # are 1.

    my @positions;
    my $position = 0;
    while ($word) {
        push @positions, $position if $word & 1;
        $position++;
        $word >>= 1;
    }
    return @positions;
}

# my $optree= _optree()
#
# recursively convert a trie to an optree where every node represents
# an if else branch.
#
#

sub _optree {
    my ( $self, $trie, $test_type, $ret_type, $else, $depth )= @_;
    return unless defined $trie;
    if ( $self->{has_multi} and $ret_type =~ /cp|both/ ) {
        die "Can't do 'cp' optree from multi-codepoint strings";
    }
    $ret_type ||= 'len';
    $else= 0  unless defined $else;
    $depth= 0 unless defined $depth;

    my @conds= sort { $a <=> $b } grep { length $_ } keys %$trie;
    if (exists $trie->{''} ) {
        if ( $ret_type eq 'cp' ) {
            $else= $self->{strs}{ $trie->{''} }{cp}[0];
            $else= sprintf "$self->{val_fmt}", $else if $else > 9;
        } elsif ( $ret_type eq 'len' ) {
            $else= $depth;
        } elsif ( $ret_type eq 'both') {
            $else= $self->{strs}{ $trie->{''} }{cp}[0];
            $else= sprintf "$self->{val_fmt}", $else if $else > 9;
            $else= "len=$depth, $else";
        }
    }
    return $else if !@conds;
    my $node= {};
    my $root= $node;
    my ( $yes_res, $as_code, @cond );
    my $test= $test_type eq 'cp' ? "cp" : "((U8*)s)[$depth]";
    my $Update= sub {
        $node->{vals}= [@cond];
        $node->{test}= $test;
        $node->{yes}= $yes_res;
        $node->{depth}= $depth;
        $node->{no}= shift;
    };
    while ( @conds ) {
        my $cond= shift @conds;
        my $res=
          $self->_optree( $trie->{$cond}, $test_type, $ret_type, $else,
            $depth + 1 );
        my $res_code= Dumper( $res );
        if ( !$yes_res || $res_code ne $as_code ) {
            if ( $yes_res ) {
                $Update->( {} );
                $node= $node->{no};
            }
            ( $yes_res, $as_code )= ( $res, $res_code );
            @cond= ( $cond );
        } else {
            push @cond, $cond;
        }
    }
    $Update->( $else );
    return $root;
}

# my $optree= optree(%opts);
#
# Convert a trie to an optree, wrapper for _optree

sub optree {
    my $self= shift;
    my %opt= @_;
    my $trie= $self->make_trie( $opt{type}, $opt{max_depth} );
    $opt{ret_type} ||= 'len';
    my $test_type= $opt{type} eq 'cp' ? 'cp' : 'depth';
    return $self->_optree( $trie, $test_type, $opt{ret_type}, $opt{else}, 0 );
}

# my $optree= generic_optree(%opts);
#
# build a "generic" optree out of the three 'low', 'latin1', 'utf8'
# sets of strings, including a branch for handling the string type check.
#

sub generic_optree {
    my $self= shift;
    my %opt= @_;

    $opt{ret_type} ||= 'len';
    my $test_type= 'depth';
    my $else= $opt{else} || 0;

    my $latin1= $self->make_trie( 'latin1', $opt{max_depth} );
    my $utf8= $self->make_trie( 'utf8',     $opt{max_depth} );

    $_= $self->_optree( $_, $test_type, $opt{ret_type}, $else, 0 )
      for $latin1, $utf8;

    if ( $utf8 ) {
        $else= __cond_join( "( is_utf8 )", $utf8, $latin1 || $else );
    } elsif ( $latin1 ) {
        $else= __cond_join( "!( is_utf8 )", $latin1, $else );
    }
    my $low= $self->make_trie( 'low', $opt{max_depth} );
    if ( $low ) {
        $else= $self->_optree( $low, $test_type, $opt{ret_type}, $else, 0 );
    }

    return $else;
}

# length_optree()
#
# create a string length guarded optree.
#

sub length_optree {
    my $self= shift;
    my %opt= @_;
    my $type= $opt{type};

    die "Can't do a length_optree on type 'cp', makes no sense."
      if $type eq 'cp';

    my ( @size, $method );

    if ( $type eq 'generic' ) {
        $method= 'generic_optree';
        my %sizes= (
            %{ $self->{size}{low}    || {} },
            %{ $self->{size}{latin1} || {} },
            %{ $self->{size}{utf8}   || {} }
        );
        @size= sort { $a <=> $b } keys %sizes;
    } else {
        $method= 'optree';
        @size= sort { $a <=> $b } keys %{ $self->{size}{$type} };
    }

    my $else= ( $opt{else} ||= 0 );
    for my $size ( @size ) {
        my $optree= $self->$method( %opt, type => $type, max_depth => $size );
        my $cond= "((e)-(s) > " . ( $size - 1 ).")";
        $else= __cond_join( $cond, $optree, $else );
    }
    return $else;
}

sub calculate_mask(@) {
    my @list = @_;
    my $list_count = @list;

    # Look at the input list of byte values.  This routine sees if the set
    # consisting of those bytes is exactly determinable by using a
    # mask/compare operation.  If not, it returns an empty list; if so, it
    # returns a list consisting of (mask, compare).  For example, consider a
    # set consisting of the numbers 0xF0, 0xF1, 0xF2, and 0xF3.  If we want to
    # know if a number 'c' is in the set, we could write:
    #   0xF0 <= c && c <= 0xF4
    # But the following mask/compare also works, and has just one test:
    #   c & 0xFC == 0xF0
    # The reason it works is that the set consists of exactly those numbers
    # whose first 4 bits are 1, and the next two are 0.  (The value of the
    # other 2 bits is immaterial in determining if a number is in the set or
    # not.)  The mask masks out those 2 irrelevant bits, and the comparison
    # makes sure that the result matches all bytes that which match those 6
    # material bits exactly.  In other words, the set of numbers contains
    # exactly those whose bottom two bit positions are either 0 or 1.  The
    # same principle applies to bit positions that are not necessarily
    # adjacent.  And it can be applied to bytes that differ in 1 through all 8
    # bit positions.  In order to be a candidate for this optimization, the
    # number of numbers in the test must be a power of 2.  Based on this
    # count, we know the number of bit positions that must differ.
    my $bit_diff_count = 0;
    my $compare = $list[0];
    if ($list_count == 2) {
        $bit_diff_count = 1;
    }
    elsif ($list_count == 4) {
        $bit_diff_count = 2;
    }
    elsif ($list_count == 8) {
        $bit_diff_count = 3;
    }
    elsif ($list_count == 16) {
        $bit_diff_count = 4;
    }
    elsif ($list_count == 32) {
        $bit_diff_count = 5;
    }
    elsif ($list_count == 64) {
        $bit_diff_count = 6;
    }
    elsif ($list_count == 128) {
        $bit_diff_count = 7;
    }
    elsif ($list_count == 256) {
        return (0, 0);
    }

    # If the count wasn't a power of 2, we can't apply this optimization
    return if ! $bit_diff_count;

    my %bit_map;

    # For each byte in the list, find the bit positions in it whose value
    # differs from the first byte in the set.
    for (my $i = 1; $i < @list; $i++) {
        my @positions = pop_count($list[0] ^ $list[$i]);

        # If the number of differing bits is greater than those permitted by
        # the set size, this optimization doesn't apply.
        return if @positions > $bit_diff_count;

        # Save the bit positions that differ.
        foreach my $bit (@positions) {
            $bit_map{$bit} = 1;
        }

        # If the total so far is greater than those permitted by the set size,
        # this optimization doesn't apply.
        return if keys %bit_map > $bit_diff_count;


        # The value to compare against is the AND of all the members of the
        # set.  The bit positions that are the same in all will be correct in
        # the AND, and the bit positions that differ will be 0.
        $compare &= $list[$i];
    }

    # To get to here, we have gone through all bytes in the set,
    # and determined that they all differ from each other in at most
    # the number of bits allowed for the set's quantity.  And since we have
    # tested all 2**N possibilities, we know that the set includes no fewer
    # elements than we need,, so the optimization applies.
    die "panic: internal logic error" if keys %bit_map != $bit_diff_count;

    # The mask is the bit positions where things differ, complemented.
    my $mask = 0;
    foreach my $position (keys %bit_map) {
        $mask |= 1 << $position;
    }
    $mask = ~$mask & 0xFF;

    return ($mask, $compare);
}

# _cond_as_str
# turn a list of conditions into a text expression
# - merges ranges of conditions, and joins the result with ||
sub _cond_as_str {
    my ( $self, $op, $combine, $opts_ref )= @_;
    my $cond= $op->{vals};
    my $test= $op->{test};
    my $is_cp_ret = $opts_ref->{ret_type} eq "cp";
    return "( $test )" if !defined $cond;

    # rangify the list.
    my @ranges;
    my $Update= sub {
        # We skip this if there are optimizations that
        # we can apply (below) to the individual ranges
        if ( ($is_cp_ret || $combine) && @ranges && ref $ranges[-1]) {
            if ( $ranges[-1][0] == $ranges[-1][1] ) {
                $ranges[-1]= $ranges[-1][0];
            } elsif ( $ranges[-1][0] + 1 == $ranges[-1][1] ) {
                $ranges[-1]= $ranges[-1][0];
                push @ranges, $ranges[-1] + 1;
            }
        }
    };
    for my $condition ( @$cond ) {
        if ( !@ranges || $condition != $ranges[-1][1] + 1 ) {
            $Update->();
            push @ranges, [ $condition, $condition ];
        } else {
            $ranges[-1][1]++;
        }
    }
    $Update->();

    return $self->_combine( $test, @ranges )
      if $combine;

    if ($is_cp_ret) {
        @ranges= map {
            ref $_
            ? sprintf(
                "( $self->{val_fmt} <= $test && $test <= $self->{val_fmt} )",
                @$_ )
            : sprintf( "$self->{val_fmt} == $test", $_ );
        } @ranges;
    }
    else {
        # If the input set has certain characteristics, we can optimize tests
        # for it.  This doesn't apply if returning the code point, as we want
        # each element of the set individually.  The code above is for this
        # simpler case.

        return 1 if @$cond == 256;  # If all bytes match, is trivially true

        if (@ranges > 1) {
            # See if the entire set shares optimizable characterstics, and if
            # so, return the optimization.  We delay checking for this on sets
            # with just a single range, as there may be better optimizations
            # available in that case.
            my ($mask, $base) = calculate_mask(@$cond);
            if (defined $mask && defined $base) {
                return sprintf "( ( $test & $self->{val_fmt} ) == $self->{val_fmt} )", $mask, $base;
            }
        }

        # Here, there was no entire-class optimization.  Look at each range.
        for (my $i = 0; $i < @ranges; $i++) {
            if (! ref $ranges[$i]) {    # Trivial case: no range
                $ranges[$i] = sprintf "$self->{val_fmt} == $test", $ranges[$i];
            }
            elsif ($ranges[$i]->[0] == $ranges[$i]->[1]) {
                $ranges[$i] =           # Trivial case: single element range
                        sprintf "$self->{val_fmt} == $test", $ranges[$i]->[0];
            }
            else {
                my $output = "";

                # Well-formed UTF-8 continuation bytes on ascii platforms must
                # be in the range 0x80 .. 0xBF.  If we know that the input is
                # well-formed (indicated by not trying to be 'safe'), we can
                # omit tests that verify that the input is within either of
                # these bounds.  (No legal UTF-8 character can begin with
                # anything in this range, so we don't have to worry about this
                # being a continuation byte or not.)
                if (ASCII_PLATFORM
                    && ! $opts_ref->{safe}
                    && $opts_ref->{type} =~ / ^ (?: utf8 | high ) $ /xi)
                {
                    my $lower_limit_is_80 = ($ranges[$i]->[0] == 0x80);
                    my $upper_limit_is_BF = ($ranges[$i]->[1] == 0xBF);

                    # If the range is the entire legal range, it matches any
                    # legal byte, so we can omit both tests.  (This should
                    # happen only if the number of ranges is 1.)
                    if ($lower_limit_is_80 && $upper_limit_is_BF) {
                        return 1;
                    }
                    elsif ($lower_limit_is_80) { # Just use the upper limit test
                        $output = sprintf("( $test <= $self->{val_fmt} )",
                                            $ranges[$i]->[1]);
                    }
                    elsif ($upper_limit_is_BF) { # Just use the lower limit test
                        $output = sprintf("( $test >= $self->{val_fmt} )",
                                        $ranges[$i]->[0]);
                    }
                }

                # If we didn't change to omit a test above, see if the number
                # of elements is a power of 2 (only a single bit in the
                # representation of its count will be set) and if so, it may
                # be that a mask/compare optimization is possible.
                if ($output eq ""
                    && pop_count($ranges[$i]->[1] - $ranges[$i]->[0] + 1) == 1)
                {
                    my @list;
                    push @list, $_  for ($ranges[$i]->[0] .. $ranges[$i]->[1]);
                    my ($mask, $base) = calculate_mask(@list);
                    if (defined $mask && defined $base) {
                        $output = sprintf "( $test & $self->{val_fmt} ) == $self->{val_fmt}", $mask, $base;
                    }
                }

                if ($output ne "") {  # Prefer any optimization
                    $ranges[$i] = $output;
                }
                elsif ($ranges[$i]->[0] + 1 == $ranges[$i]->[1]) {
                    # No optimization happened.  We need a test that the code
                    # point is within both bounds.  But, if the bounds are
                    # adjacent code points, it is cleaner to say
                    # 'first == test || second == test'
                    # than it is to say
                    # 'first <= test && test <= second'
                    $ranges[$i] = "( "
                                .  join( " || ", ( map
                                    { sprintf "$self->{val_fmt} == $test", $_ }
                                    @{$ranges[$i]} ) )
                                . " )";
                }
                else {  # Full bounds checking
                    $ranges[$i] = sprintf("( $self->{val_fmt} <= $test && $test <= $self->{val_fmt} )", $ranges[$i]->[0], $ranges[$i]->[1]);
                }
            }
        }
    }

    return "( " . join( " || ", @ranges ) . " )";

}

# _combine
# recursively turn a list of conditions into a fast break-out condition
# used by _cond_as_str() for 'cp' type macros.
sub _combine {
    my ( $self, $test, @cond )= @_;
    return if !@cond;
    my $item= shift @cond;
    my ( $cstr, $gtv );
    if ( ref $item ) {
        $cstr=
          sprintf( "( $self->{val_fmt} <= $test && $test <= $self->{val_fmt} )",
            @$item );
        $gtv= sprintf "$self->{val_fmt}", $item->[1];
    } else {
        $cstr= sprintf( "$self->{val_fmt} == $test", $item );
        $gtv= sprintf "$self->{val_fmt}", $item;
    }
    if ( @cond ) {
        return "( $cstr || ( $gtv < $test &&\n"
          . $self->_combine( $test, @cond ) . " ) )";
    } else {
        return $cstr;
    }
}

# _render()
# recursively convert an optree to text with reasonably neat formatting
sub _render {
    my ( $self, $op, $combine, $brace, $opts_ref )= @_;
    return 0 if ! defined $op;  # The set is empty
    if ( !ref $op ) {
        return $op;
    }
    my $cond= $self->_cond_as_str( $op, $combine, $opts_ref );
    #no warnings 'recursion';   # This would allow really really inefficient
                                # code to be generated.  See pod
    my $yes= $self->_render( $op->{yes}, $combine, 1, $opts_ref );
    return $yes if $cond eq '1';

    my $no= $self->_render( $op->{no},   $combine, 0, $opts_ref );
    return "( $cond )" if $yes eq '1' and $no eq '0';
    my ( $lb, $rb )= $brace ? ( "( ", " )" ) : ( "", "" );
    return "$lb$cond ? $yes : $no$rb"
      if !ref( $op->{yes} ) && !ref( $op->{no} );
    my $ind1= " " x 4;
    my $ind= "\n" . ( $ind1 x $op->{depth} );

    if ( ref $op->{yes} ) {
        $yes= $ind . $ind1 . $yes;
    } else {
        $yes= " " . $yes;
    }

    return "$lb$cond ?$yes$ind: $no$rb";
}

# $expr=render($op,$combine)
#
# convert an optree to text with reasonably neat formatting. If $combine
# is true then the condition is created using "fast breakouts" which
# produce uglier expressions that are more efficient for common case,
# longer lists such as that resulting from type 'cp' output.
# Currently only used for type 'cp' macros.
sub render {
    my ( $self, $op, $combine, $opts_ref )= @_;
    my $str= "( " . $self->_render( $op, $combine, 0, $opts_ref ) . " )";
    return __clean( $str );
}

# make_macro
# make a macro of a given type.
# calls into make_trie and (generic_|length_)optree as needed
# Opts are:
# type     : 'cp','generic','high','low','latin1','utf8','LATIN1','UTF8'
# ret_type : 'cp' or 'len'
# safe     : add length guards to macro
#
# type defaults to 'generic', and ret_type to 'len' unless type is 'cp'
# in which case it defaults to 'cp' as well.
#
# it is illegal to do a type 'cp' macro on a pattern with multi-codepoint
# sequences in it, as the generated macro will accept only a single codepoint
# as an argument.
#
# returns the macro.


sub make_macro {
    my $self= shift;
    my %opts= @_;
    my $type= $opts{type} || 'generic';
    die "Can't do a 'cp' on multi-codepoint character class '$self->{op}'"
      if $type eq 'cp'
      and $self->{has_multi};
    my $ret_type= $opts{ret_type} || ( $opts{type} eq 'cp' ? 'cp' : 'len' );
    my $method;
    if ( $opts{safe} ) {
        $method= 'length_optree';
    } elsif ( $type eq 'generic' ) {
        $method= 'generic_optree';
    } else {
        $method= 'optree';
    }
    my $optree= $self->$method( %opts, type => $type, ret_type => $ret_type );
    my $text= $self->render( $optree, $type eq 'cp', \%opts );
    my @args= $type eq 'cp' ? 'cp' : 's';
    push @args, "e" if $opts{safe};
    push @args, "is_utf8" if $type eq 'generic';
    push @args, "len" if $ret_type eq 'both';
    my $pfx= $ret_type eq 'both'    ? 'what_len_' : 
             $ret_type eq 'cp'      ? 'what_'     : 'is_';
    my $ext= $type     eq 'generic' ? ''          : '_' . lc( $type );
    $ext .= "_safe" if $opts{safe};
    my $argstr= join ",", @args;
    return "/*** GENERATED CODE ***/\n"
      . __macro( "#define $pfx$self->{op}$ext($argstr)\n$text" );
}

# if we arent being used as a module (highly likely) then process
# the __DATA__ below and produce macros in regcharclass.h
# if an argument is provided to the script then it is assumed to
# be the path of the file to output to, if the arg is '-' outputs
# to STDOUT.
if ( !caller ) {
    $|++;
    my $path= shift @ARGV || "regcharclass.h";
    my $out_fh;
    if ( $path eq '-' ) {
        $out_fh= \*STDOUT;
    } else {
	$out_fh = open_new( $path );
    }
    print $out_fh read_only_top( lang => 'C', by => $0,
				 file => 'regcharclass.h', style => '*',
				 copyright => [2007, 2011] );
    print $out_fh "\n#ifndef H_REGCHARCLASS   /* Guard against nested #includes */\n#define H_REGCHARCLASS 1\n\n";

    my ( $op, $title, @txt, @types, %mods );
    my $doit= sub {
        return unless $op;

        # Skip if to compile on a different platform.
        return if delete $mods{only_ascii_platform} && ! ASCII_PLATFORM;
        return if delete $mods{only_ebcdic_platform} && ord 'A' != 193;

        print $out_fh "/*\n\t$op: $title\n\n";
        print $out_fh join "\n", ( map { "\t$_" } @txt ), "*/", "";
        my $obj= __PACKAGE__->new( op => $op, title => $title, txt => \@txt );

        #die Dumper(\@types,\%mods);

        my @mods;
        push @mods, 'safe' if delete $mods{safe};
        unshift @mods, 'fast' if delete $mods{fast} || ! @mods; # Default to 'fast'
                                                                # do this one
                                                                # first, as
                                                                # traditional
        if (%mods) {
            die "Unknown modifiers: ", join ", ", map { "'$_'" } keys %mods;
        }

        foreach my $type_spec ( @types ) {
            my ( $type, $ret )= split /-/, $type_spec;
            $ret ||= 'len';
            foreach my $mod ( @mods ) {
                next if $mod eq 'safe' and $type eq 'cp';
                delete $mods{$mod};
                my $macro= $obj->make_macro(
                    type     => $type,
                    ret_type => $ret,
                    safe     => $mod eq 'safe'
                );
                print $out_fh $macro, "\n";
            }
        }
    };

    while ( <DATA> ) {
        s/^ \s* (?: \# .* ) ? $ //x;    # squeeze out comment and blanks
        next unless /\S/;
        chomp;
        if ( /^([A-Z]+)/ ) {
            $doit->();  # This starts a new definition; do the previous one
            ( $op, $title )= split /\s*:\s*/, $_, 2;
            @txt= ();
        } elsif ( s/^=>// ) {
            my ( $type, $modifier )= split /:/, $_;
            @types= split ' ', $type;
            undef %mods;
            map { $mods{$_} = 1 } split ' ',  $modifier;
        } else {
            push @txt, "$_";
        }
    }
    $doit->();

    print $out_fh "\n#endif /* H_REGCHARCLASS */\n";

    if($path eq '-') {
	print $out_fh "/* ex: set ro: */\n";
    } else {
	read_only_bottom_close_and_rename($out_fh)
    }
}

# The form of the input is a series of definitions to make macros for.
# The first line gives the base name of the macro, followed by a colon, and
# then text to be used in comments associated with the macro that are its
# title or description.  In all cases the first (perhaps only) parameter to
# the macro is a pointer to the first byte of the code point it is to test to
# see if it is in the class determined by the macro.  In the case of non-UTF8,
# the code point consists only of a single byte.
#
# The second line must begin with a '=>' and be followed by the types of
# macro(s) to be generated; these are specified below.  A colon follows the
# types, followed by the modifiers, also specified below.  At least one
# modifier is required.
#
# The subsequent lines give what code points go into the class defined by the
# macro.  Multiple characters may be specified via a string like "\x0D\x0A",
# enclosed in quotes.  Otherwise the lines consist of single Unicode code
# point, prefaced by 0x; or a single range of Unicode code points separated by
# a minus (and optional space); or a single Unicode property specified in the
# standard Perl form "\p{...}".
#
# A blank line or one whose first non-blank character is '#' is a comment.
# The definition of the macro is terminated by a line unlike those described.
#
# Valid types:
#   low         generate a macro whose name is 'is_BASE_low' and defines a
#               class that includes only ASCII-range chars.  (BASE is the
#               input macro base name.)
#   latin1      generate a macro whose name is 'is_BASE_latin1' and defines a
#               class that includes only upper-Latin1-range chars.  It is not
#               designed to take a UTF-8 input parameter.
#   high        generate a macro whose name is 'is_BASE_high' and defines a
#               class that includes all relevant code points that are above
#               the Latin1 range.  This is for very specialized uses only.
#               It is designed to take only an input UTF-8 parameter.
#   utf8        generate a macro whose name is 'is_BASE_utf8' and defines a
#               class that includes all relevant characters that aren't ASCII.
#               It is designed to take only an input UTF-8 parameter.
#   LATIN1      generate a macro whose name is 'is_BASE_latin1' and defines a
#               class that includes both ASCII and upper-Latin1-range chars.
#               It is not designed to take a UTF-8 input parameter.
#   UTF8        generate a macro whose name is 'is_BASE_utf8' and defines a
#               class that can include any code point, adding the 'low' ones
#               to what 'utf8' works on.  It is designed to take only an input
#               UTF-8 parameter.
#   generic     generate a macro whose name is 'is_BASE".  It has a 2nd,
#               boolean, parameter which indicates if the first one points to
#               a UTF-8 string or not.  Thus it works in all circumstances.
#   cp          generate a macro whose name is 'is_BASE_cp' and defines a
#               class that returns true if the UV parameter is a member of the
#               class; false if not.
# A macro of the given type is generated for each type listed in the input.
# The default return value is the number of octets read to generate the match.
# Append "-cp" to the type to have it instead return the matched codepoint.
#               The macro name is changed to 'what_BASE...'.  See pod for
#               caveats
# Appending '-both" instead adds an extra parameter to the end of the argument
#               list, which is a pointer as to where to store the number of
#               bytes matched, while also returning the code point.  The macro
#               name is changed to 'what_len_BASE...'.  See pod for caveats
#
# Valid modifiers:
#   safe        The input string is not necessarily valid UTF-8.  In
#               particular an extra parameter (always the 2nd) to the macro is
#               required, which points to one beyond the end of the string.
#               The macro will make sure not to read off the end of the
#               string.  In the case of non-UTF8, it makes sure that the
#               string has at least one byte in it.  The macro name has
#               '_safe' appended to it.
#   fast        The input string is valid UTF-8.  No bounds checking is done,
#               and the macro can make assumptions that lead to faster
#               execution.
#   only_ascii_platform   Skip this definition if this program is being run on
#               a non-ASCII platform.
#   only_ebcdic_platform  Skip this definition if this program is being run on
#               a non-EBCDIC platform.
# No modifier need be specified; fast is assumed for this case.  If both
# 'fast', and 'safe' are specified, two macros will be created for each
# 'type'.
#
# If run on a non-ASCII platform will automatically convert the Unicode input
# to native.  The documentation above is slightly wrong in this case.  'low'
# actually refers to code points whose UTF-8 representation is the same as the
# non-UTF-8 version (invariants); and 'latin1' refers to all the rest of the
# code points less than 256.

1; # in the unlikely case we are being used as a module

__DATA__
# This is no longer used, but retained in case it is needed some day.
# TRICKYFOLD: Problematic fold case letters.  When adding to this list, also should add them to regcomp.c and fold_grind.t
# => generic cp generic-cp generic-both :fast safe
# 0x00DF	# LATIN SMALL LETTER SHARP S
# 0x0390	# GREEK SMALL LETTER IOTA WITH DIALYTIKA AND TONOS
# 0x03B0	# GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND TONOS
# 0x1E9E  # LATIN CAPITAL LETTER SHARP S, because maps to same as 00DF
# 0x1FD3  # GREEK SMALL LETTER IOTA WITH DIALYTIKA AND OXIA; maps same as 0390
# 0x1FE3  # GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND OXIA; maps same as 03B0

LNBREAK: Line Break: \R
=> generic UTF8 LATIN1 :fast safe
"\x0D\x0A"      # CRLF - Network (Windows) line ending
\p{VertSpace}

HORIZWS: Horizontal Whitespace: \h \H
=> generic UTF8 LATIN1 cp :fast safe
\p{HorizSpace}

VERTWS: Vertical Whitespace: \v \V
=> generic UTF8 LATIN1 cp :fast safe
\p{VertSpace}

REPLACEMENT: Unicode REPLACEMENT CHARACTER
=> UTF8 :safe
0xFFFD

NONCHAR: Non character code points
=> UTF8 :fast
\p{Nchar}

SURROGATE: Surrogate characters
=> UTF8 :fast
\p{Gc=Cs}

GCB_L: Grapheme_Cluster_Break=L
=> UTF8 :fast
\p{_X_GCB_L}

GCB_LV_LVT_V: Grapheme_Cluster_Break=(LV or LVT or V)
=> UTF8 :fast
\p{_X_LV_LVT_V}

GCB_Prepend: Grapheme_Cluster_Break=Prepend
=> UTF8 :fast
\p{_X_GCB_Prepend}

GCB_RI: Grapheme_Cluster_Break=RI
=> UTF8 :fast
\p{_X_RI}

GCB_SPECIAL_BEGIN: Grapheme_Cluster_Break=special_begins
=> UTF8 :fast
\p{_X_Special_Begin}

GCB_T: Grapheme_Cluster_Break=T
=> UTF8 :fast
\p{_X_GCB_T}

GCB_V: Grapheme_Cluster_Break=V
=> UTF8 :fast
\p{_X_GCB_V}

# This program was run with this enabled, and the results copied to utf8.h;
# then this was commented out because it takes so long to figure out these 2
# million code points.  The results would not change unless utf8.h decides it
# wants a maximum other than 4 bytes, or this program creates better
# optimizations
#UTF8_CHAR: Matches utf8 from 1 to 4 bytes
#=> UTF8 :safe only_ascii_platform
#0x0 - 0x1FFFFF

# This hasn't been commented out, because we haven't an EBCDIC platform to run
# it on, and the 3 types of EBCDIC allegedly supported by Perl would have
# different results
UTF8_CHAR: Matches utf8 from 1 to 5 bytes
=> UTF8 :safe only_ebcdic_platform
0x0 - 0x3FFFFF:

QUOTEMETA: Meta-characters that \Q should quote
=> high :fast
\p{_Perl_Quotemeta}
