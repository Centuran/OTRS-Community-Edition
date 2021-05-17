# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
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
        my $ScriptAlias  = $ConfigObject->Get('ScriptAlias');

        # Create test agent.
        my $TestUserLogin = $Helper->TestUserCreate() || die "Did not get test agent";

        # Trigger action LostPassword for existing agent.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=LostPassword;User=$TestUserLogin;Token=bar");
        my $agentPageSource = $Selenium->get_page_source();

        # Trigger action LostPassword for non existing agent.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=LostPassword;User=foo;Token=bar");
        my $noAgentPageSource = $Selenium->get_page_source();

        # Assert equality between both.
        $Self->True(
            $agentPageSource eq $noAgentPageSource,
            "Agent enumeration possible",
        );

    }
);

1;
