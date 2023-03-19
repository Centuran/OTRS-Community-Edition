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

use vars (qw($Self));

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        (my ( $TestUserLogin, $TestUserID ) = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        )) || die "Did not get a test user";

        my $RandomID = $Helper->GetRandomID();
        my $XSSPayload = "<script>window.xss$RandomID = true;</script>";

        my $TicketID = $TicketObject->TicketCreate(
            Title         => "1111-11-11 11:11:11 $XSSPayload",
            Queue         => 'Misc',
            Lock          => 'unlock',
            Priority      => '3 normal',
            State         => 'new',
            CustomerID    => 'TestCustomer',
            CustomerUser  => 'customer@example.com',
            OwnerID       => $TestUserID,
            ResponsibleID => $TestUserID,
            UserID        => $TestUserID
        );
        $Self->True( $TicketID, "Ticket $TicketID created ");

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        my $QueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            Queue => 'Misc',
        );

        $Selenium->VerifiedGet("${ScriptAlias}index.pl?" .
            "Action=AgentTicketQueue;QueueID=${QueueID};View=Small");
        
        $Self->True(
            $Selenium->execute_script(
                "return window.xss$RandomID === undefined;"
            ),
            "Script in ticket title does not get executed"
        );

        my $TicketDeleted = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => $TestUserID,
        );
        $Self->True( $TicketDeleted, "Ticket $TicketID deleted" );

        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => 'Ticket' );
    }
);

1;
