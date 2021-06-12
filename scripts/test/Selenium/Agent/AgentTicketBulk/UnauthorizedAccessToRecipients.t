# --
# Copyright (C) 2021 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {
        my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
        
        my $RandomID = $Helper->GetRandomID();

        my $Group = "group-${RandomID}";
        my $GroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupAdd(
            Name    => $Group,
            ValidID => 1,
            UserID  => 1,
        );

        my $Queue = "queue-${RandomID}";
        my $QueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueAdd(
            Name            => $Queue,
            ValidID         => 1,
            GroupID         => $GroupID,
            SystemAddressID => 1,
            UserID          => 1,
        );

        (my ( $TestUserLogin, $TestUserID ) = $Helper->TestUserCreate(
            Groups => [ 'users' ],
        )) || die "Did not get a test user";

        my $CustomerEmail = 'customer@example.com';

        my $TicketID = $TicketObject->TicketCreate(
            Title         => 'Test',
            Queue         => $Queue,
            Lock          => 'unlock',
            Priority      => '3 normal',
            State         => 'new',
            CustomerID    => 'TestCustomer',
            CustomerUser  => $CustomerEmail,
            OwnerID       => 1,
            ResponsibleID => 1,
            UserID        => 1
        );

        my $ArticleBackendObject = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel(
            ChannelName => 'Email',
        );
        my $ArticleID = $ArticleBackendObject->ArticleCreate(
            TicketID             => $TicketID,
            IsVisibleForCustomer => 1,
            SenderType           => 'agent',
            From                 => 'TestAgent <agent@example.com>',
            To                   => "TestCustomer <${CustomerEmail}>",
            Subject              => 'Test',
            Body                 => 'Test',
            Charset              => 'utf8',
            MimeType             => 'text/plain',
            HistoryType          => 'OwnerUpdate',
            HistoryComment       => 'No comment',
            UserID               => 1,
        );

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');
        
        $Selenium->VerifiedGet(
            "${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=${TicketID}"
        );

        $Self->True(
            index($Selenium->get_page_source(), $CustomerEmail) == -1,
            'Customer email address is not shown when trying to access ticket'
        );

        $Selenium->get(
            "${ScriptAlias}index.pl?Action=AgentTicketBulk;" .
                "Subaction=AJAXRecipientList;TicketIDs=[${TicketID}]"
        );

        $Self->True(
            index($Selenium->get_body(), $CustomerEmail) == -1,
            'Customer email address is not returned via AJAXRecipientList request'
        );

        # Cleanup

        my $Deleted = 0;

        $Deleted = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->True(
            $Deleted,
            "Ticket $TicketID has been deleted"
        );

        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        # Delete queue
        $Deleted = $DBObject->Do(
            SQL  => "DELETE FROM queue WHERE id = ?",
            Bind => [ \$QueueID ],
        );
        $Self->True(
            $Deleted,
            "Queue $Queue has been deleted",
        );

        # Delete group
        $Deleted = $DBObject->Do(
            SQL  => "DELETE FROM group_user WHERE group_id = ?",
            Bind => [ \$GroupID ],
        );
        $Deleted = $DBObject->Do(
            SQL  => "DELETE FROM groups WHERE id = ?",
            Bind => [ \$GroupID ],
        );
        $Self->True(
            $Deleted,
            "Group $Group has been deleted",
        );

        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => 'Ticket' );
    }
);

1;
