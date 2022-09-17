package Font::TTF::Kern::CompactClassArray;

=head1 NAME

Font::TTF::Kern::CompactClassArray - Compact Class Array kern subtable for AAT

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Utils;
use Font::TTF::AATutils;

@ISA = qw(Font::TTF::Kern::Subtable);

sub new
{
    my ($class) = @_;
    my ($self) = {};

    $class = ref($class) || $class;
    bless $self, $class;
}

=head2 $t->read

Reads the table into memory

=cut

sub read
{
    my ($self, $fh) = @_;
    
    die "incomplete";
            
    $self;
}

=head2 $t->out($fh)

Writes the table to a file

=cut

sub out_sub
{
    my ($self, $fh) = @_;
    
    die "incomplete";
            
    $self;
}

=head2 $t->print($fh)

Prints a human-readable representation of the table

=cut

sub print
{
    my ($self, $fh) = @_;
    
    my $post = $self->post();
    
    $fh = 'STDOUT' unless defined $fh;

    die "incomplete";
}


sub type
{
    return 'kernCompactClassArray';
}


1;

=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<http://scripts.sil.org/FontUtils>. 


=head1 LICENSING

Copyright (c) 1998-2016, SIL International (http://www.sil.org) 

This module is released under the terms of the Artistic License 2.0. 
For details, see the full text of the license in the file LICENSE.



=cut
