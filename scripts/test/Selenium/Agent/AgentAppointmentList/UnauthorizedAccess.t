# --
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
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

        # Create test group
        my $Group   = "test-calendar-group1-$RandomID";
        my $GroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupAdd(
            Name    => $Group,
            ValidID => 1,
            UserID  => 1,
        );

        # Create test user 1.
        my $TestUserLogin1 = $Helper->TestUserCreate(
            Groups   => [ 'users', $Group ],
        ) || die "Did not get test user 1";

        # Create test user 2.
        my $TestUserLogin2 = $Helper->TestUserCreate()
            || die "Did not get test user 2";

        # Get UserID1.
        my $UserID1 = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin1,
        );

        # Create a calendar
        my %Calendar = $CalendarObject->CalendarCreate(
            CalendarName => "Calendar-$RandomID",
            Color        => '#3A87AD',
            GroupID      => $GroupID,
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

        my $CalendarID = $Calendar{CalendarID};
        $Selenium->InputFieldValueSet(
            Element => '#CalendarID',
            Value   => $CalendarID
        );

        $Selenium->find_element("#EditFormSubmit", 'css')->click();
        $Selenium->WaitFor(JavaScript => 'return typeof($) === "function" && !$(".Dialog.Modal").length');
        $Selenium->VerifiedRefresh();

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
            "${ScriptAlias}index.pl?Action=AgentAppointmentList;Subaction=ListAppointments;CalendarID=$Calendar{CalendarID};"
          . "ChallengeToken=$ChallengeToken;StartTime=2021-01-01T00:00:00;EndTime=2022-01-01T00:00:00"
        );

        $Self->True(
            index($Selenium->get_page_source(), $AppointmentName) == -1,
            "The appointment data is not returned for non-authorized user",
        );

        $Self->Is(
            $Selenium->get_body(),
            '[]',
            'An empty list of appointments is returned for non-authorized user'
        );

        # Cleanup

        my $Deleted = 0;

        # Delete appointment
        my @AppointmentIDs = $AppointmentObject->AppointmentList(
            CalendarID => $CalendarID,
            Result     => 'ARRAY',
        );
        for my $AppointmentID (@AppointmentIDs) {
            $Deleted += $AppointmentObject->AppointmentDelete(
                AppointmentID => $AppointmentID,
                UserID        => 1,
            );
        }
        $Self->True(
            $Deleted > 0,
            "Appointments have been deleted"
        );

        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        # Delete calendar
        $Deleted = $DBObject->Do(
            SQL  => "DELETE FROM calendar WHERE id = ?",
            Bind => [ \$CalendarID ],
        );
        $Self->True(
            $Deleted,
            "Calendar $Calendar{CalendarName} has been deleted",
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
    }
);

1;
