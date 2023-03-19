# --
# Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package scripts::DBUpdateTo6::DisableSystemCommandPostMasterPreFilters;  ## no critic

use strict;
use warnings;

use IO::Interactive qw(is_interactive);

use parent qw(scripts::DBUpdateTo6::Base);

use version;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Config',
    'Kernel::System::SysConfig',
);

=head1 NAME

scripts::DBUpdateTo6::DisableSystemCommandPostMasterPreFilters - Disables PostMaster pre-filters that run system commands.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $SystemCommandFilters = $Self->_GetSystemCommandPostMasterPreFilters();

    return 1 if !IsArrayRefWithData($SystemCommandFilters);

    my $Filters =
        $Kernel::OM->Get('Kernel::Config')->Get('PostMaster::PreFilterModule') // {};

    $Kernel::OM->Get('Kernel::System::SysConfig')->SettingsSet(
        Settings => [
            map {
                {
                    Name           => "PostMaster::PreFilterModule###$_",
                    EffectiveValue => $Filters->{$_},
                    IsValid        => 0,
                }
            } sort @{$SystemCommandFilters}
        ],
        Comments => 'Disabled PostMaster pre-filters that run system commands.',
        UserID   => 1,
    );

    return 1;
}

sub CheckPreviousRequirement {
    my ( $Self, %Param ) = @_;

    my $SystemCommandFilters = $Self->_GetSystemCommandPostMasterPreFilters();
    return 1 if !IsArrayRefWithData($SystemCommandFilters);

    print "\n        Warning: the PostMaster pre-filters listed below can execute system\n";
    print "        commands. This is unsafe and not supported anymore. These pre-filters\n";
    print "        will be disabled in system configuration.\n\n";

    for my $FilterName ( sort @{$SystemCommandFilters} ) {
        print "         - $FilterName\n";
    }

    print "\n";

    if ( is_interactive() ) {
        print '        Do you want to continue? [Y]es/[N]o: ';

        my $Answer = <>;
        $Answer =~ s{\s}{}g;

        return if $Answer !~ m{^ y (?:es)? $}ix;
    }

    return 1;
}

sub _GetSystemCommandPostMasterPreFilters {
    my ( $Self, %Param ) = @_;

    my $Filters =
        $Kernel::OM->Get('Kernel::Config')->Get('PostMaster::PreFilterModule') // {};

    return [
        grep {
            $Filters->{$_}{Module} eq 'Kernel::System::PostMaster::Filter::CMD'
        } keys %{$Filters}
    ];
}

1;
