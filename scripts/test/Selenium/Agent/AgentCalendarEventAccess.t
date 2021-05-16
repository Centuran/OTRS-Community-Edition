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
        my $Helper            = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
        my $CalendarObject    = $Kernel::OM->Get('Kernel::System::Calendar');
        my $AppointmentObject = $Kernel::OM->Get('Kernel::System::Calendar::Appointment');

        my $RandomID = $Helper->GetRandomID();

        # Create test group 1.
        my $GroupName1 = "test-calendar-group1-$RandomID";
        my $GroupID1   = $Kernel::OM->Get('Kernel::System::Group')->GroupAdd(
            Name    => $GroupName1,
            ValidID => 1,
            UserID  => 1,
        );

        # Create test user 1.
        my $TestUserLogin1 = $Helper->TestUserCreate(
            Groups   => [ 'users', $GroupName1 ],
        ) || die "Did not get test user 1";

        # Get UserID1.
        my $UserID1 = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin1,
        );

        # Create a calendar for group 1.
        my %Calendar1 = $CalendarObject->CalendarCreate(
            CalendarName => "Calendar1-$RandomID",
            Color        => '#3A87AD',
            GroupID      => $GroupID1,
            UserID       => $UserID1,
            ValidID      => 1,
        );

        # Login as test user 1.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin1,
            Password => $TestUserLogin1,
        );

        # Add test appointment to calendar 1.
        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentAppointmentCalendarOverview");

        $Selenium->find_element("#AppointmentCreateButton", 'css' )->click();
        $Selenium->WaitFor(JavaScript => 'return typeof($) === "function" && $("#Title").length');

        my $AppointmentName = "Appointment-$RandomID";
        $Selenium->find_element("#Title",       'css')->send_keys("$AppointmentName");
        $Selenium->find_element("#Description", 'css')->send_keys("Test appointment");

        my $Calendar1ID = $Calendar1{CalendarID};
        $Selenium->InputFieldValueSet(
            Element => '#CalendarID',
            Value   => $Calendar1ID
        );

        $Selenium->find_element("#EditFormSubmit", 'css')->click();
        $Selenium->WaitFor(JavaScript => 'return typeof($) === "function" && !$(".Dialog.Modal").length');
        $Selenium->VerifiedRefresh();

        # Create test user 2.
        my $TestUserLogin2 = $Helper->TestUserCreate(
        ) || die "Did not get test user 2";

        # Login as test user 2.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin2,
            Password => $TestUserLogin2,
        );

        # Check current session ID.
        my $AuthSessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

        my $CurrentSessionID;
        my @SessionIDs = $AuthSessionObject->GetAllSessionIDs();
        SESSION_ID:
        for my $SessionID (@SessionIDs) {
            my %SessionData = $AuthSessionObject->GetSessionIDData(
                SessionID => $SessionID,
            );

            if ( %SessionData && $SessionData{UserLogin} eq $TestUserLogin2 ) {
                $CurrentSessionID = $SessionID;
                last SESSION_ID;
            }
        }

        $Self->True(
            scalar $CurrentSessionID,
            "Current session ID found for user $TestUserLogin2",
        ) || return;

        # Get current session data and challenge token.
        my %SessionData = $AuthSessionObject->GetSessionIDData(SessionID => $CurrentSessionID);
        my $ChallengeToken = $SessionData{'UserChallengeToken'};

        # Check for unauthorized access to events.
        $Selenium->get(
            "${ScriptAlias}index.pl?Action=AgentAppointmentList;Subaction=ListAppointments;CalendarID=$Calendar1{CalendarID};"
          . "ChallengeToken=$ChallengeToken;StartTime=2021-01-01T00:00:00;EndTime=2022-01-01T00:00:00"
        );

        $Self->True(
            index($Selenium->get_page_source(), $AppointmentName) == -1,
            "Unauthorized event access",
        );

        $Self->Is(
            $Selenium->get_body(),
            '[]',
            'An empty list of appointments is returned for non-authorized user'
        );
    }
);

1;
