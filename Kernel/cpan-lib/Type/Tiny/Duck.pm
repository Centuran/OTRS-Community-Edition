package Type::Tiny::Duck;

use 5.006001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::Duck::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::Duck::VERSION   = '1.010000';
}

$Type::Tiny::Duck::VERSION =~ tr/_//d;

use Scalar::Util qw< blessed >;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Type::Tiny::ConstrainedObject ();
our @ISA = 'Type::Tiny::ConstrainedObject';
sub _short_name { 'Duck' }

sub new {
	my $proto = shift;
	
	my %opts = (@_==1) ? %{$_[0]} : @_;
	_croak "Need to supply list of methods" unless exists $opts{methods};
	
	$opts{methods} = [$opts{methods}] unless ref $opts{methods};
	
	if (Type::Tiny::_USE_XS)
	{
		my $methods = join ",", sort(@{$opts{methods}});
		my $xsub    = Type::Tiny::XS::get_coderef_for("HasMethods[$methods]");
		$opts{compiled_type_constraint} = $xsub if $xsub;
	}
	elsif (Type::Tiny::_USE_MOUSE)
	{
		require Mouse::Util::TypeConstraints;
		my $maker = "Mouse::Util::TypeConstraints"->can("generate_can_predicate_for");
		$opts{compiled_type_constraint} = $maker->($opts{methods}) if $maker;
	}
	
	return $proto->SUPER::new(%opts);
}

sub methods     { $_[0]{methods} }
sub inlined     { $_[0]{inlined} ||= $_[0]->_build_inlined }

sub has_inlined { !!1 }

sub _is_null_constraint { 0 }

sub _build_constraint
{
	my $self    = shift;
	my @methods = @{$self->methods};
	return sub { blessed($_[0]) and not grep(!$_[0]->can($_), @methods) };
}

sub _build_inlined
{
	my $self = shift;
	my @methods = @{$self->methods};
	
	if (Type::Tiny::_USE_XS)
	{
		my $methods = join ",", sort(@{$self->methods});
		my $xsub    = Type::Tiny::XS::get_subname_for("HasMethods[$methods]");
		return sub { my $var = $_[1]; "$xsub\($var\)" } if $xsub;
	}
	
	sub {
		my $var = $_[1];
		local $" = q{ };
		# If $var is $_ or $_->{foo} or $foo{$_} or somesuch, then we
		# can't use it within the grep expression, so we need to save
		# it into a temporary variable ($tmp).
		($var =~ /\$_/)
			? qq{ Scalar::Util::blessed($var) and not do { my \$tmp = $var; grep(!\$tmp->can(\$_), qw/@methods/) } }
			: qq{ Scalar::Util::blessed($var) and not grep(!$var->can(\$_), qw/@methods/) };
	};
}

sub _instantiate_moose_type
{
	my $self = shift;
	my %opts = @_;
	delete $opts{parent};
	delete $opts{constraint};
	delete $opts{inlined};
	
	require Moose::Meta::TypeConstraint::DuckType;
	return "Moose::Meta::TypeConstraint::DuckType"->new(%opts, methods => $self->methods);
}

sub validate_explain
{
	my $self = shift;
	my ($value, $varname) = @_;
	$varname = '$_' unless defined $varname;
	
	return undef if $self->check($value);
	return ["Not a blessed reference"] unless blessed($value);
	
	require Type::Utils;
	return [
		sprintf(
			'"%s" requires that the reference can %s',
			$self,
			Type::Utils::english_list(map qq["$_"], @{$self->methods}),
		),
		map  sprintf('The reference cannot "%s"', $_),
		grep !$value->can($_),
		@{$self->methods}
	];
}

push @Type::Tiny::CMP, sub {
	my $A = shift->find_constraining_type;
	my $B = shift->find_constraining_type;
	return Type::Tiny::CMP_UNKNOWN unless $A->isa(__PACKAGE__) && $B->isa(__PACKAGE__);
	
	my %seen;
	for my $word (@{$A->methods}) {
		$seen{$word} += 1;
	}
	for my $word (@{$B->methods}) {
		$seen{$word} += 2;
	}
	
	my $values = join('', CORE::values %seen);
	if ($values =~ /^3*$/) {
		return Type::Tiny::CMP_EQUIVALENT;
	}
	elsif ($values !~ /2/) {
		return Type::Tiny::CMP_SUBTYPE;
	}
	elsif ($values !~ /1/) {
		return Type::Tiny::CMP_SUPERTYPE;
	}
	
	return Type::Tiny::CMP_UNKNOWN;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::Duck - type constraints based on the "can" method

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Type constraints of the general form C<< { $_->can("method") } >>.

This package inherits from L<Type::Tiny>; see that for most documentation.
Major differences are listed below:

=head2 Attributes

=over

=item C<methods>

An arrayref of method names.

=item C<constraint>

Unlike Type::Tiny, you I<cannot> pass a constraint coderef to the constructor.
Instead rely on the default.

=item C<inlined>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
Instead rely on the default.

=item C<parent>

Parent is always B<Types::Standard::Object>, and cannot be passed to the
constructor.

=back

=head2 Methods

=over

=item C<< stringifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< numifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< with_attribute_values($attr1 => $constraint1, ...) >>

See L<Type::Tiny::ConstrainedObject>.

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Type-Tiny>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>.

L<Moose::Meta::TypeConstraint::DuckType>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2017-2020 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
