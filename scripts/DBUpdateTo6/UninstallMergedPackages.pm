# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package scripts::DBUpdateTo6::UninstallMergedPackages;    ## no critic

use strict;
use warnings;

use parent qw(scripts::DBUpdateTo6::Base);

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::Package',
);

=head1 NAME

scripts::DBUpdateTo6::UninstallMergedPackages - Uninstalls packages that have been merged into the base system.

=head1 PUBLIC INTERFACE

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $CacheObject   = $Kernel::OM->Get('Kernel::System::Cache');
    my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');

    # Purge relevant caches before uninstalling to avoid errors because of inconsistent states.
    $CacheObject->CleanUp(
        Type => 'RepositoryList',
    );
    $CacheObject->CleanUp(
        Type => 'RepositoryGet',
    );
    $CacheObject->CleanUp(
        Type => 'XMLParse',
    );

    # Uninstall packages that were merged, keeping the DB structures intact.
    for my $PackageName (
        qw(
        OTRSAppointmentCalendar
        OTRSTicketNumberCounterDatabase
        OTRSAdvancedTicketSplit
        OTRSGenericInterfaceInvokerEventFilter
        OTRSPostMasterKeepState
        )
        )
    {
        my $Uninstalled = $PackageObject->_PackageUninstallMerged(
            Name => $PackageName,
        );
        if ( !$Uninstalled ) {
            print "\n    Error uninstalling package $PackageName\n\n";
            return;
        }
    }

    return 1;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
