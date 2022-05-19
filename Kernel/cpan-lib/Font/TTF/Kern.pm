package Font::TTF::Kern;

=head1 NAME

Font::TTF::Kern - Kerning tables

=head1 DESCRIPTION

Kerning tables are held as an ordered collection of subtables each giving
incremental information regarding the kerning of various pairs of glyphs.

The basic structure of the kerning data structure is:

    $kern = $f->{'kern'}{'tables'}[$tnum]{'kerns'}{$leftnum}{$rightnum};

Due to the possible complexity of some kerning tables the above information
is insufficient. Reference also needs to be made to the type of the table and
the coverage field.

=head1 INSTANCE VARIABLES

The instance variables for a kerning table are relatively straightforward.

=over 4

=item Version

Version number of the kerning table

=item Num

Number of subtables in the kerning table

=item tables

Array of subtables in the kerning table 

Each subtable has a number of instance variables.

=over 4

=item kern

A two level hash array containing kerning values. The indexing is left
is via left class and right class. It may seem using hashes is strange,
but most tables are not type 2 and this method saves empty array values.

=item type

Stores the table type. Only type 0 and type 2 tables are specified for
TrueType so far.

=item coverage

A bit field of coverage information regarding the kerning value. See the
TrueType specification for details.

=item Version

Contains the version number of the table.

=item Num

Number of kerning pairs in this type 0 table.

=item left

An array indexed by glyph - left_first which returns a class number for
the glyph in type 2 tables.

=item right

An array indexed by glyph - right_first which returns a class number for
the glyph in type 2 tables.

=item left_first

the glyph number of the first element in the left array for type 2 tables.

=item right_first

the glyph number of the first element in the right array for type 2 tables.

=item num_left

Number of left classes

=item num_right

Number of right classes

=back

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::Table;
use Font::TTF::Kern::Subtable;

@ISA = qw(Font::TTF::Table);
my @subtables = qw(OrderedList StateTable ClassArray CompactClassArray);

=head2 $t->read

Reads the whole kerning table into structures

=cut

sub read
{
    my ($self) = @_;
    $self->SUPER::read or return $self;

    my ($fh) = $self->{' INFILE'};
    my ($dat, $i, $numt, $len, $cov, $t);

    $fh->read($dat, 4);
    ($self->{'Version'}, $numt) = unpack("n2", $dat);
    if ($self->{'Version'} > 0)
    {
        $fh->read($dat, 4, 4);
        ($self->{'Version'}, $numt) = TTF_Unpack("vL", $dat);
    }
    $self->{'Num'} = $numt;

    for ($i = 0; $i < $numt; $i++)
    {
        if ($self->{'Version'} > 0)
        {
            $fh->read($dat, 8);
            my ($length, $coverage, $index) = unpack("Nnn", $dat);
            my ($type) = $coverage & 0xFF;
            $t = Font::TTF::Kern::Subtable->create($type, $coverage, $length);
            $t->read($fh);
        }
        else
        {
            $t = $self->read_subtable($fh);
        }
        push (@{$self->{'tables'}}, $t);
    }
    $self;
}

sub read_subtable
{
    my ($self, $fh) = @_;
    my ($dat, $len, $cov, $t);

    $t = {};
    $fh->read($dat, 6);
    ($t->{'Version'}, $len, $cov) = unpack("n3", $dat);
    $t->{'coverage'} = $cov & 255;
    $t->{'type'} = $cov >> 8;
    if ($t->{'Version'} == 0)
    {
        # NB: Cambria is an example of a font that plays an unsual trick: The
        # kern table is much larger than can be represented by the header $len
        # would allow. So we use the number of pairs to figure out how much to read. 
        $fh->read($dat, 8);
        $t->{'Num'} = unpack("n", $dat);
        $fh->read($dat, $t->{'Num'} * 6);
        my (@vals) = unpack("n*", $dat);
        for (0 .. ($t->{'Num'} - 1))
        {
            my ($f, $l, $v);
            $f = shift @vals;
            $l = shift @vals;
            $v = shift @vals;
            $v -= 65536 if ($v > 32767);
            $t->{'kern'}{$f}{$l} = $v;
        }
    } elsif ($t->{'Version'} == 2)
    {
        my ($wid, $off, $numg, $maxl, $maxr, $j);
        
        $fh->read($dat, $len - 6);
        $wid = unpack("n", $dat);
        $off = unpack("n", substr($dat, 2));
        ($t->{'left_first'}, $numg) = unpack("n2", substr($dat, $off));
        $t->{'left'} = [unpack("n$numg", substr($dat, $off + 4))];
        foreach (@{$t->{'left'}})
        {
            $_ /= $wid;
            $maxl = $_ if ($_ > $maxl);
        }
        $t->{'left_max'} = $maxl;

        $off = unpack("n", substr($dat, 4));
        ($t->{'right_first'}, $numg) = unpack("n2", substr($dat, $off));
        $t->{'right'} = [unpack("n$numg", substr($dat, $off + 4))];
        foreach (@{$t->{'right'}})
        {
            $_ >>= 1;
            $maxr = $_ if ($_ > $maxr);
        }
        $t->{'right_max'} = $maxr;

        $off = unpack("n", substr($dat, 6));
        for ($j = 0; $j <= $maxl; $j++)
        {
            my ($k) = 0;

            map { $t->{'kern'}{$j}{$k} = $_ if $_; $k++; }
                    unpack("n$maxr", substr($dat, $off + $wid * $j));
        }
    }
    return $t;
}


=head2 $t->out($fh)

Outputs the kerning tables to the given file

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($i, $l, $r, $t);

    return $self->SUPER::out($fh) unless ($self->{' read'});

    if ($self->{'Version'} > 0)
    { $fh->print(TTF_Pack("vL", $self->{'Version'}, $self->{'Num'})); }
    else
    { $fh->print(pack("n2", $self->{'Version'}, $self->{'Num'})); }

    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $t = $self->{'tables'}[$i];

        if ($self->{'Version'} > 0)
        { $t->out($fh); }
        else
        { $self->out_subtable($fh, $t); }
    }
    $self;
}


sub out_subtable
{
    my ($self, $fh, $t) = @_;
    my ($loc) = $fh->tell();
    my ($loc1, $l, $r);

    $fh->print(pack("nnn", $t->{'Version'}, 0, $t->{'coverage'}));
    if ($t->{'Version'} == 0)
    {
        my ($dat);
        foreach $l (sort {$a <=> $b} keys %{$t->{'kern'}})
        {
            foreach $r (sort {$a <=> $b} keys %{$t->{'kern'}{$l}})
            { $dat .= TTF_Pack("SSs", $l, $r, $t->{'kern'}{$l}{$r}); }
        }
        $fh->print(TTF_Pack("SSSS", Font::TTF::Utils::TTF_bininfo(length($dat) / 6, 6)));
        $fh->print($dat);
    } elsif ($t->{'Version'} == 2)
    {
        my ($arr);

        $fh->print(pack("nnnn", $t->{'right_max'} << 1, 8, ($#{$t->{'left'}} + 7) << 1,
                ($#{$t->{'left'}} + $#{$t->{'right'}} + 10) << 1));

        $fh->print(pack("nn", $t->{'left_first'}, $#{$t->{'left'}} + 1));
        foreach (@{$t->{'left'}})
        { $fh->print(pack("C", $_ * (($t->{'left_max'} + 1) << 1))); }

        $fh->print(pack("nn", $t->{'right_first'}, $#{$t->{'right'}} + 1));
        foreach (@{$t->{'right'}})
        { $fh->print(pack("C", $_ << 1)); }

        $arr = "\000\000" x (($t->{'left_max'} + 1) * ($t->{'right_max'} + 1));
        foreach $l (keys %{$t->{'kern'}})
        {
            foreach $r (keys %{$t->{'kern'}{$l}})
            { substr($arr, ($l * ($t->{'left_max'} + 1) + $r) << 1, 2)
                    = pack("n", $t->{'kern'}{$l}{$r}); }
        }
        $fh->print($arr);
    }
    $loc1 = $fh->tell();
    $fh->seek($loc + 2, 0);
    $fh->print(pack("n", $loc1 - $loc));
    $fh->seek($loc1, 0);
}


=head2 $t->XML_element($context, $depth, $key, $value)

Handles outputting the kern hash into XML a little more tidily

=cut

sub XML_element
{
    my ($self) = shift;
    my ($context, $depth, $key, $value) = @_;
    my ($fh) = $context->{'fh'};
    my ($f, $l);

    return $self->SUPER::XML_element(@_) unless ($key eq 'kern');
    $fh->print("$depth<kern-table>\n");
    foreach $f (sort {$a <=> $b} keys %{$value})
    {
        foreach $l (sort {$a <=> $b} keys %{$value->{$f}})
        { $fh->print("$depth$context->{'indent'}<adjust first='$f' last='$l' dist='$value->{$f}{$l}'/>\n"); }
    }
    $fh->print("$depth</kern-table>\n");
    $self;
}

=head2 $t->minsize()

Returns the minimum size this table can be. If it is smaller than this, then the table
must be bad and should be deleted or whatever.

=cut

sub minsize
{
    return 4;
}

1;

=head1 BUGS

=over 4

=item *

Only supports kerning table types 0 & 2.

=item *

No real support functions to I<do> anything with the kerning tables yet.

=back

=head1 AUTHOR

Martin Hosken L<http://scripts.sil.org/FontUtils>. 


=head1 LICENSING

Copyright (c) 1998-2016, SIL International (http://www.sil.org) 

This module is released under the terms of the Artistic License 2.0. 
For details, see the full text of the license in the file LICENSE.



=cut
