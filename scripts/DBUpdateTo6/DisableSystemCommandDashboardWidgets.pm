# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package scripts::DBUpdateTo6::DisableSystemCommandDashboardWidgets;  ## no critic

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

scripts::DBUpdateTo6::DisableSystemCommandDashboardWidgets - Disables dashboard widgets that run system commands.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $SystemCommandWidgets = $Self->_GetSystemCommandDashboardWidgets();

    return 1 if !IsArrayRefWithData($SystemCommandWidgets);

    my $Backends =
        $Kernel::OM->Get('Kernel::Config')->Get('DashboardBackend') // {};

    $Kernel::OM->Get('Kernel::System::SysConfig')->SettingsSet(
        Settings => [
            map {
                {
                    Name           => "DashboardBackend###$_",
                    EffectiveValue => $Backends->{$_},
                    IsValid        => 0,
                }
            } sort @{$SystemCommandWidgets}
        ],
        Comments => 'Disabled dashboard widgets that run system commands.',
        UserID   => 1,
    );

    return 1;
}

sub CheckPreviousRequirement {
    my ( $Self, %Param ) = @_;

    my $SystemCommandWidgets = $Self->_GetSystemCommandDashboardWidgets();
    return 1 if !IsArrayRefWithData($SystemCommandWidgets);

    print "\n        Warning: the dashboard widgets listed below can execute system commands.\n";
    print "        This is unsafe and not supported anymore. These widgets will be disabled\n";
    print "        in system configuration.\n\n";

    for my $WidgetName ( sort @{$SystemCommandWidgets} ) {
        print "         - $WidgetName\n";
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

sub _GetSystemCommandDashboardWidgets {
    my ( $Self, %Param ) = @_;

    my $Backends =
        $Kernel::OM->Get('Kernel::Config')->Get('DashboardBackend') // {};

    return [
        grep {
            $Backends->{$_}{Module} eq 'Kernel::Output::HTML::Dashboard::CmdOutput'
        } keys %{$Backends}
    ];
}

1;
