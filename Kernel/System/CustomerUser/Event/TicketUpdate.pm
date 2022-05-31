# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::CustomerUser::Event::TicketUpdate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
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
    for my $Name (qw( UserLogin NewData OldData )) {
        if ( !$Param{Data}->{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name in Data!"
            );
            return;
        }
    }

    # only update if fields have really changed
    if (
        $Param{Data}->{OldData}->{UserCustomerID} ne $Param{Data}->{NewData}->{UserCustomerID}
        || $Param{Data}->{OldData}->{UserLogin} ne $Param{Data}->{NewData}->{UserLogin}
        )
    {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # perform search
        my @Tickets = $TicketObject->TicketSearch(
            Result               => 'ARRAY',
            Limit                => 100_000,
            CustomerUserLoginRaw => $Param{Data}->{OldData}->{UserLogin},
            CustomerIDRaw        => $Param{Data}->{OldData}->{UserCustomerID},
            ArchiveFlags         => [ 'y', 'n' ],
            UserID               => 1,
        );

        # update the customer ID and login of tickets
        for my $TicketID (@Tickets) {
            $TicketObject->TicketCustomerSet(
                No       => $Param{Data}->{NewData}->{UserCustomerID},
                User     => $Param{Data}->{NewData}->{UserLogin},
                TicketID => $TicketID,
                UserID   => $Param{UserID},
            );
        }
    }

    return 1;
}

1;
