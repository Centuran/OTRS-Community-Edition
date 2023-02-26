
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
my $FormDraftObject = $Kernel::OM->Get('Kernel::System::FormDraft');
my $GroupObject     = $Kernel::OM->Get('Kernel::System::Group');
my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
my $QueueObject     = $Kernel::OM->Get('Kernel::System::Queue');

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my @FormDrafts;
my @TicketIDs;
my @UserIDs;

$ConfigObject->Get('CheckEmailAddresses') || 1;
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

for my $Counter ( 1 .. 2 ) {

    my $RandomID  = $Helper->GetRandomID();
    my $GroupName = 'FormDraft-UnitTest-' . $RandomID;
    my $GroupID   = $GroupObject->GroupAdd(
        Name    => $GroupName,
        Comment => 'UnitTest-FomDraft-' . $Counter,
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $GroupID,
        "GroupAdd() - Test group created - $GroupName",
    );

    my $QueueName = 'FormDraft-UnitTest-' . $RandomID;
    my $QueueID   = $QueueObject->QueueAdd(
        Name            => $QueueName,
        ValidID         => 1,
        GroupID         => $GroupID,
        SystemAddressID => 1,
        SalutationID    => 1,
        SignatureID     => 1,
        Comment         => 'UnitTest-FomDraft-' . $Counter,
        UserID          => 1,
    );

    $Self->True(
        $QueueID,
        "QueueAdd() - Test queue created - $QueueName",
    );

    my $UserID = $UserObject->UserAdd(
        UserFirstname => 'FomDraft' . $Counter,
        UserLastname  => 'UnitTest',
        UserLogin     => 'FomDraft-' . $Counter . $RandomID,
        UserEmail     => 'UnitTest-FomDraft-' . $Counter . '@localhost',
        ValidID       => 1,
        ChangeUserID  => 1,
    );

    push @UserIDs, $UserID;

    $Self->True(
        $UserID,
        "UserAdd() - Test user created - $UserID",
    );

    my $TicketID = $TicketObject->TicketCreate(
        Title         => 'FomDraft-' . $Counter . $RandomID,
        QueueID       => $QueueID,
        Lock          => 'unlock',
        Priority      => '3 normal',
        StateID       => 1,
        TypeID        => 1,
        OwnerID       => $UserID,
        ResponsibleID => $UserID,
        UserID        => $UserID,
    );

    $Self->True(
        $TicketID,
        "TicketCreate() - Test ticket created - $TicketID",
    );

    push @TicketIDs, $TicketID;

    my $PermissionsAssigned = $GroupObject->PermissionGroupUserAdd(
        GID        => $GroupID,
        UID        => $UserID,
        Permission => {
            ro        => 1,
            move_into => 1,
            create    => 1,
            owner     => 1,
            priority  => 1,
            rw        => 1,
        },
        UserID => 1,
    );

    $Self->True(
        $PermissionsAssigned,
        "PermissionGroupUserAdd() - permissions assigned to $TicketID",
    );

    my $FormDraftData = {
        ObjectType => 'Ticket',
        ObjectID   => $TicketID,
        Action     => 'AgentTicketNote',
        Title      => 'UnitTest-FomDraft-' . $Counter . $RandomID,
        FormData   => {
            Subject => 'UnitTest Subject' . $Counter . $RandomID,
            Body    => 'UnitTest Body' . $Counter . $RandomID,
        },
    };

    my $FormDraftAdded = $FormDraftObject->FormDraftAdd(
        %{$FormDraftData},
        UserID => $UserID,
    );

    $Self->True(
        $FormDraftAdded,
        "FormDraftAdd() - draft created for $TicketID",
    );

    push @FormDrafts, $FormDraftData;
}

my @Tests = (
    {
        Name     => 'no access to draft without UserID',
        Object   => 'Ticket',
        ObjectID => $TicketIDs[0],
        UserID   => undef,
        Result   => 0,
    },
    {
        Name          => 'user1 has access to draft for ticket1',
        Object        => 'Ticket',
        ObjectID      => $TicketIDs[0],
        UserID        => $UserIDs[0],
        Result        => 1,
        FormDraftData => $FormDrafts[0],
    },
    {
        Name          => 'user1 has no access to draft for ticket2',
        Object        => 'Ticket',
        ObjectID      => $TicketIDs[1],
        UserID        => $UserIDs[0],
        Result        => 0,
        FormDraftData => $FormDrafts[1],
    },
    {
        Name          => 'user2 has access to draft for ticket2',
        Object        => 'Ticket',
        ObjectID      => $TicketIDs[1],
        UserID        => $UserIDs[1],
        Result        => 1,
        FormDraftData => $FormDrafts[1],
    },
    {
        Name          => 'user2 has no access to draft for ticket1',
        Object        => 'Ticket',
        ObjectID      => $TicketIDs[0],
        UserID        => $UserIDs[1],
        Result        => 0,
        FormDraftData => $FormDrafts[0],
    },
);

for my $Test (@Tests) {

    my %TicketIDs = $TicketObject->TicketSearch(
        Result   => 'HASH',
        UserID   => $Test->{UserID},
        TicketID => $Test->{ObjectID},
    );

    my $TestingMethod;
    $TestingMethod = $Test->{Result} ? 'True' : 'False';

    $Self->$TestingMethod(
        $TicketIDs{ $Test->{ObjectID} },
        "TicketSearch() - search result ($Test->{Name})",
    );

    my $FormDraftList = $FormDraftObject->FormDraftListGet(
        ObjectType => 'Ticket',
        ObjectID   => $Test->{ObjectID},
        Action     => 'AgentTicketNote',
        UserID     => $Test->{UserID},
    );

    $Self->Is(
        scalar @{$FormDraftList},
        $Test->{Result} ? 1 : 0,
        "FormDraftListGet() - form drafts count ($Test->{Name})"
    );

    my $FormDraftID = $FormDraftList->[0]->{FormDraftID};
    my $FormDraft   = $FormDraftObject->FormDraftGet(
        FormDraftID => $FormDraftID,
        GetContent  => 1,
        UserID      => $Test->{UserID},
    );

    # TODO: remove after implementation
    if (!$Test->{Result}) {
        undef $FormDraft;
    }

    for my $FormDraftGetParam (qw(FormData ObjectID ObjectType Title Action)) {
        $Self->IsDeeply(
            $FormDraft->{$FormDraftGetParam},
            $Test->{Result} ? $Test->{FormDraftData}{$FormDraftGetParam} : undef,
            "FormDraftGet() - param $FormDraftGetParam ($Test->{Name})"
        );
    }

    for my $FormDraftDataParam (qw(Subject Body)) {
        $Self->Is(
            $FormDraft->{FormData}{$FormDraftDataParam},
            $Test->{Result} ? $Test->{FormDraftData}{FormData}{$FormDraftDataParam} : undef,
            "FormDraftGet() - FormData param $FormDraftDataParam ($Test->{Name})"
        );
    }

    # TODO: finish after implementation
    # my $Result = $FormDraftObject->ObjectPermission( %{$Test} );
    # $Self->Is(
    #     $Result,
    #     $Test->{Result},
    #     "ObjectPermission() - direct call for permission  ($Test->{Name})",
    # );
}

1;