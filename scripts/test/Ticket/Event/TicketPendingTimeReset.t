# --
# Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use Kernel::System::Ticket::Event::TicketPendingTimeReset;

use vars (qw($Self));

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);

my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $StateObject  = $Kernel::OM->Get('Kernel::System::State');
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

my %StateTypeIDs = reverse $StateObject->StateTypeList(
    UserID => 1,
);

my @TestStates = (
    {
        Name    => 'test pending auto close +',
        ValidID => 1,
        TypeID  => $StateTypeIDs{'pending auto'},
        UserID  => 1,
    },
    {
        Name    => 'test pending reminder',
        ValidID => 1,
        TypeID  => $StateTypeIDs{'pending reminder'},
        UserID  => 1,
    },
    {
        Name    => 'test open',
        ValidID => 1,
        TypeID  => $StateTypeIDs{'open'},
        UserID  => 1,
    },
    {
        Name    => 'test closed',
        ValidID => 1,
        TypeID  => $StateTypeIDs{'closed'},
        UserID  => 1,
    },
);

for my $State (@TestStates) {
    my $StateID = $StateObject->StateAdd(
        %{$State},
        Comment => 'adding test state'
    );

    $Self->True(
        $StateID,
        "Test state $State->{Name} was added successfully"
    );
}

my $Configured = $ConfigObject->Set(
    Key   => 'Ticket::PendingAutoStateType',
    Value => 'pending auto',
);

$Self->True(
    $Configured,
    "Ticket::PendingAutoStateType configured successfully",
);

$Configured = $ConfigObject->Set(
    Key   => 'Ticket::PendingReminderStateType',
    Value => 'pending reminder',
);

$Self->True(
    $Configured,
    "Set Ticket::PendingReminderStateType configured successfully",
);

my $DateTime = $Kernel::OM->Create('Kernel::System::DateTime');

my @Tests = (
    {
        Name  => 'pending auto state with pending time in the future',
        Data  => {
            State  => 'test pending auto close +',
            Params => {
                Diff   => 7 * 24 * 60,
                UserID => 1,
            }
        },
        Expected => {
            Result         => 1,
            UntilTimeReset => 0,
        }
    },
    {
        Name  => 'pending auto state with current pending time',
        Data  => {
            State  => 'test pending auto close +',
            Params => {
                String => $DateTime->ToString(),
                UserID => 1,
            }
        },
        Expected => {
            Result         => 1,
        }
    },
    {
        Name  => 'pending auto state with pending time in the past',
        Data  => {
            State  => 'test pending auto close +',
            Params => {
                Diff   => -1 * 24 * 60,
                UserID => 1,
            }
        },
        Expected => {
            Result         => 1,
            UntilTimeReset => 0,
        }
    },
    {
        Name  => 'pending reminder state with pending time in the future',
        Data  => {
            State  => 'test pending reminder',
            Params => {
                Diff   => 7 * 24 * 60,
                UserID => 1,
            }
        },
        Expected => {
            Result         => 1,
            UntilTimeReset => 0,
        }
    },
    {
        Name  => 'open state with pending time in the future',
        Data  => {
            State  => 'test open',
            Params => {
                Diff   => 7 * 24 * 60,
                UserID => 1,
            }
        },
        Expected => {
            Result         => 1,
            UntilTimeReset => 1,
        }
    },
    {
        Name  => 'open state with current pending time',
        Data  => {
            State  => 'test open',
            Params => {
                String => $DateTime->ToString(),
                UserID => 1,
            }
        },
        Expected => {
            Result => 1,
        }
    },
    {
        Name  => 'closed state with pending time in the past',
        Data  => {
            State  => 'test closed',
            Params => {
                Diff   => -1 * 24 * 60,
                UserID => 1,
            }
        },
        Expected => {
            Result         => 1,
            UntilTimeReset => 1,
        }
    },
);

my %EventConfig = (
    'Event'  => 'StateUpdate',
    'Module' => 'Kernel::System::Ticket::Event::TicketPendingTimeReset',
);

my $Module = $EventConfig{Module}->new();

$Self->True(
    $Module,
    "Event module $EventConfig{Module} instantiated successfully",
);

my $CustomerUser = $HelperObject->GetRandomID() . '@example.com';

for my $Test (@Tests) {
    my $TicketID = $TicketObject->TicketCreate(
        TN           => $TicketObject->TicketCreateNumber(),
        Title        => 'Test ticket',
        Queue        => 'Raw',
        Lock         => 'unlock',
        Priority     => '3 normal',
        State        => $Test->{Data}{State},
        CustomerNo   => '123456',
        CustomerUser => $CustomerUser,
        OwnerID      => 1,
        UserID       => 1,
    );

    $Self->True(
        $TicketID,
        "Ticket $TicketID created",
    );

    my $PendingTimeSet = $TicketObject->TicketPendingTimeSet(
        %{ $Test->{Data}{Params} },
        TicketID => $TicketID,
    );

    $Self->True(
        $PendingTimeSet,
        "Ticket pending time set for ticket $TicketID",
    );

    $Test->{Data}{TicketID} = $TicketID;

    my $Result = $Module->Run(
        Event  => 'StateUpdate',
        Data   => $Test->{Data},
        Config => \%EventConfig,
        UserID => 1,
    );

    $Self->Is(
        $Test->{Expected}{Result},
        $Result,
        "Module run result is correct for test case \"$Test->{Name}\"",
    );

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID   => 1
    );

    if ( defined $Test->{Expected}{UntilTimeReset} ) {
        if ( $Test->{Expected}{UntilTimeReset} ) {
            $Self->Is(
                $Ticket{UntilTime},
                0,
                "UntilTime was reset for test case \"$Test->{Name}\"",
            );
        }
        else {
            $Self->IsNot(
                $Ticket{UntilTime},
                0,
                "UntilTime was not reset for test case \"$Test->{Name}\"",
            );
        }
    }
}

1;
