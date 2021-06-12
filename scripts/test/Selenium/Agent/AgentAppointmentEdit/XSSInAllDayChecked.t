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

use URI::Escape;

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {
        my $Helper            = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
        my $CalendarObject    = $Kernel::OM->Get('Kernel::System::Calendar');
        my $AppointmentObject = $Kernel::OM->Get('Kernel::System::Calendar::Appointment');

        my $RandomID = $Helper->GetRandomID();

        # Create test group
        my $Group   = "calendar-group-$RandomID";
        my $GroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupAdd(
            Name    => $Group,
            ValidID => 1,
            UserID  => 1,
        );

        (my ( $TestUserLogin, $TestUserID ) = $Helper->TestUserCreate(
            Groups   => [ 'users', $Group ],
        )) || die "Did not get a test user";
        
        my %Calendar = $CalendarObject->CalendarCreate(
            CalendarName => "Calendar-$RandomID",
            Color        => '#FFFFFF',
            GroupID      => $GroupID,
            ValidID      => 1,
            UserID       => $TestUserID,
        );

        my $AppointmentID = $AppointmentObject->AppointmentCreate(
            CalendarID => $Calendar{CalendarID},
            Title      => 'Test',
            StartTime  => '2021-05-23 12:00:00',
            EndTime    => '2021-05-23 15:00:00',
            UserID     => 1,
        );
        $Self->True(
            $AppointmentID,
            "Appointment ${AppointmentID} has been created"
        );

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');

        my $ChallengeToken = $Selenium->execute_script(
            'return Core.Config.Get("ChallengeToken");'
        );
        my $XSSPayload = URI::Escape::uri_escape(
            "><script>window.xss${RandomID} = true;</script><"
        );

        $Selenium->get("${ScriptAlias}index.pl?" .
            "Action=AgentAppointmentEdit;Subaction=EditMask;" .
            "ChallengeToken=${ChallengeToken};AppointmentID=${AppointmentID};" .
            "AllDayChecked=${XSSPayload}");

        $Selenium->WaitFor(
            JavaScript => 'return document.readyState === "complete";'
        );

        $Self->True(
            $Selenium->execute_script(
                "return window.xss${RandomID} === undefined;"
            ),
            "Script passed in URL parameter does not get executed"
        );

        # Cleanup

        my $Deleted = 0;

        # Delete appointment
        $Deleted = $AppointmentObject->AppointmentDelete(
            AppointmentID => $AppointmentID,
            UserID        => 1,
        );
        $Self->True(
            $Deleted > 0,
            "Appointment $AppointmentID has been deleted"
        );

        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        # Delete calendar
        $Deleted = $DBObject->Do(
            SQL  => "DELETE FROM calendar WHERE id = ?",
            Bind => [ \$Calendar{CalendarID} ],
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