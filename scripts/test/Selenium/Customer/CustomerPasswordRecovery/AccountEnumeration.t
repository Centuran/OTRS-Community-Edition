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

        # Create test customer.
        my $TestUserLogin = $Helper->TestCustomerUserCreate() || die "Did not get test customer";

        # Trigger action LostPassword for existing customer user.
        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerLostPassword;User=$TestUserLogin;Token=bar");
        my $ExistingUserContent = $Selenium->get_body();

        # Trigger action LostPassword for non-existing customer user.
        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerLostPassword;User=foo;Token=bar");
        my $NonExistingUserContent = $Selenium->get_body();

        $Self->True(
            $ExistingUserContent eq $NonExistingUserContent,
            "The same content is returned for existing and non-existing accounts"
        );
    }
);

1;
