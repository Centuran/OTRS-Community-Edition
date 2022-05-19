package Types::Standard::CycleTuple;

use 5.006001;
use strict;
use warnings;

BEGIN {
	$Types::Standard::CycleTuple::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::CycleTuple::VERSION   = '1.010000';
}

$Types::Standard::CycleTuple::VERSION =~ tr/_//d;

use Type::Tiny ();
use Types::Standard ();
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

my $_Optional = Types::Standard::Optional;
my $_arr      = Types::Standard::ArrayRef;

no warnings;

my $cycleuniq = 0;

sub __constraint_generator
{
	my @params = map {
		ref($_) eq 'HASH' and exists($_->{slurpy})
			and _croak("Parameters to CycleTuple[...] cannot be slurpy");
		my $param = $_;
		Types::TypeTiny::TypeTiny->check($param)
			or _croak("Parameters to CycleTuple[...] expected to be type constraints; got $param");
		$param;
	} @_;
	my $count  = @params;
	my $tuple  = Types::Standard::Tuple()->of(@params);
	
	_croak("Parameters to CycleTuple[...] cannot be optional")
		if grep !!$_->is_strictly_a_type_of($_Optional), @params;
	
	sub {
		my $value = shift;
		return unless $_arr->check($value);
		return if @$value % $count;
		my $i = 0;
		while ($i < $#$value) {
			my $tmp = [@$value[ $i .. $i+$count-1 ]];
			return unless $tuple->check($tmp);
			$i += $count;
		}
		!!1;
	}
}

sub __inline_generator
{
	my @params = map {
		my $param = $_;
		Types::TypeTiny::TypeTiny->check($param)
			or _croak("Parameter to CycleTuple[`a] expected to be a type constraint; got $param");
		$param;
	} @_;
	my $count  = @params;
	my $tuple  = Types::Standard::Tuple()->of(@params);
	
	return unless $tuple->can_be_inlined;
	
	sub {
		$cycleuniq++;
		
		my $v = $_[1];
		my @checks = $_arr->inline_check($v);
		push @checks, sprintf(
			'not(@%s %% %d)',
			($v=~/\A\$[a-z0-9_]+\z/i ? $v : "{$v}"),
			$count,
		);
		push @checks, sprintf(
			'do { my $cyclecount%d = 0; my $cycleok%d = 1; while ($cyclecount%d < $#{%s}) { my $cycletmp%d = [@{%s}[$cyclecount%d .. $cyclecount%d+%d]]; unless (%s) { $cycleok%d = 0; last; }; $cyclecount%d += %d; }; $cycleok%d; }',
			$cycleuniq,
			$cycleuniq,
			$cycleuniq,
			$v,
			$cycleuniq,
			$v,
			$cycleuniq,
			$cycleuniq,
			$count - 1,
			$tuple->inline_check("\$cycletmp$cycleuniq"),
			$cycleuniq,
			$cycleuniq,
			$count,
			$cycleuniq,
		) if grep { $_->inline_check('$xyz') ne '(!!1)' } @params;
		join(' && ', @checks);
	}
}

sub __deep_explanation
{
	my ($type, $value, $varname) = @_;
	
	my @constraints =
		map Types::TypeTiny::to_TypeTiny($_), @{ $type->parameters };
	
	if (@$value % @constraints)
	{
		return [
			sprintf('"%s" expects a multiple of %d values in the array', $type, scalar(@constraints)),
			sprintf('%d values found', scalar(@$value)),
		];
	}
	
	for my $i (0 .. $#$value)
	{
		my $constraint = $constraints[$i % @constraints];
		next if $constraint->check($value->[$i]);
		
		return [
			sprintf('"%s" constrains value at index %d of array with "%s"', $type, $i, $constraint),
			@{ $constraint->validate_explain($value->[$i], sprintf('%s->[%s]', $varname, $i)) },
		];
	}
	
	# This should never happen...
	return;  # uncoverable statement
}

my $label_counter = 0;
sub __coercion_generator
{
	my ($parent, $child, @tuple) = @_;
	
	my $child_coercions_exist = 0;
	my $all_inlinable = 1;
	for my $tc (@tuple)
	{
		$all_inlinable = 0 if !$tc->can_be_inlined;
		$all_inlinable = 0 if $tc->has_coercion && !$tc->coercion->can_be_inlined;
		$child_coercions_exist++ if $tc->has_coercion;
	}

	return unless $child_coercions_exist;
	my $C = "Type::Coercion"->new(type_constraint => $child);

	if ($all_inlinable)
	{
		$C->add_type_coercions($parent => Types::Standard::Stringable {
			my $label  = sprintf("CTUPLELABEL%d", ++$label_counter);
			my $label2 = sprintf("CTUPLEINNER%d", $label_counter);
			my @code;
			push @code, 'do { my ($orig, $return_orig, $tmp, @new) = ($_, 0);';
			push @code,       "$label: {";
			push @code,       sprintf('(($return_orig = 1), last %s) if scalar(@$orig) %% %d != 0;', $label, scalar @tuple);
			push @code,         sprintf('my $%s = 0; while ($%s < @$orig) {', $label2, $label2);
			for my $i (0 .. $#tuple)
			{
				my $ct = $tuple[$i];
				my $ct_coerce   = $ct->has_coercion;
				
				push @code, sprintf(
					'do { $tmp = %s; (%s) ? ($new[$%s + %d]=$tmp) : (($return_orig=1), last %s) };',
					$ct_coerce
						? $ct->coercion->inline_coercion("\$orig->[\$$label2 + $i]")
						: "\$orig->[\$$label2 + $i]",
					$ct->inline_check('$tmp'),
					$label2,
					$i,
					$label,
				);
			}
			push @code, sprintf('$%s += %d;', $label2, scalar(@tuple));
			push @code,         '}';
			push @code,       '}';
			push @code,    '$return_orig ? $orig : \\@new';
			push @code, '}';
			"@code";
		});
	}
	
	else
	{
		$C->add_type_coercions(
			$parent => sub {
				my $value = @_ ? $_[0] : $_;
				
				if (scalar(@$value) % scalar(@tuple) != 0)
				{
					return $value;
				}
				
				my @new;
				for my $i (0 .. $#$value)
				{
					my $ct = $tuple[$i % @tuple];
					my $x  = $ct->has_coercion ? $ct->coerce($value->[$i]) : $value->[$i];
					
					return $value unless $ct->check($x);
					
					$new[$i] = $x;
				}
				
				return \@new;
			},
		);
	};
	
	return $C;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Types::Standard::CycleTuple - internals for the Types::Standard CycleTuple type constraint

=head1 STATUS

This module is considered part of Type-Tiny's internals. It is not
covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This file contains some of the guts for L<Types::Standard>.
It will be loaded on demand. You may ignore its presence.

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Type-Tiny>.

=head1 SEE ALSO

L<Types::Standard>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2017-2020 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
