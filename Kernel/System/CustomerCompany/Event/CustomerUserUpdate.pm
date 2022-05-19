# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::CustomerCompany::Event::CustomerUserUpdate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Name (qw( Data Event Config UserID )) {
        if ( !$Param{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }
    for my $Name (qw( CustomerID OldCustomerID )) {
        if ( !$Param{Data}->{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name in Data!"
            );
            return;
        }
    }

    return 1 if $Param{Data}->{CustomerID} eq $Param{Data}->{OldCustomerID};

    # get customer user object
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    my %CustomerUsers = $CustomerUserObject->CustomerSearch(
        CustomerIDRaw => $Param{Data}->{OldCustomerID},
        Valid         => 0,
    );

    for my $CustomerUserLogin ( sort keys %CustomerUsers ) {
        my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUserLogin,
        );

        # we do not need to 'change' the password (this would re-hash it!)
        delete $CustomerData{UserPassword};
        $CustomerUserObject->CustomerUserUpdate(
            %CustomerData,
            ID             => $CustomerUserLogin,
            UserCustomerID => $Param{Data}->{CustomerID},
            UserID         => $Param{UserID},
        );
    }

    return 1;
}

1;
