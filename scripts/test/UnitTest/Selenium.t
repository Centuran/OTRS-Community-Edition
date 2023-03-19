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

use Kernel::System::VariableCheck qw(:all);

my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $SeleniumConfig = $ConfigObject->Get('SeleniumTestsConfig');

if ( IsHashRefWithData($SeleniumConfig) ) {
    $Self->True(
        $SeleniumConfig,
        'SeleniumTestsConfig exists',
    );
}
else {
    $SeleniumConfig = {
        remote_server_addr => 'localhost',
        port               => '4444',
        browser_name       => 'firefox',
        platform           => 'ANY',
        extra_capabilities => {
            marionette => \0,
        },
    };
}

# Set config with chromeOptions
$ConfigObject->Set(
    Key   => 'SeleniumTestsConfig',
    Value => {
        %{$SeleniumConfig},
        browser_name       => 'chrome',
        extra_capabilities => {
            chromeOptions => {
                args => [ 'disable-gpu', 'disable-infobars' ],
            },
            marionette => '',
        },
    }
);

my $SeleniumObject = _RecreateSeleniumObject();

# Creation of $SeleniumObject causes the execution of the assertion "Starting up
# Selenium scenario", which increments the TestOk value
$Self->True(
    $SeleniumObject->{UnitTestDriverObject}{ResultData}{TestOk},
    'Selenium driver object was initialized with chromeOptions',
);

# Set the base config
$ConfigObject->Set(
    Key   => 'SeleniumTestsConfig',
    Value => {
        %{$SeleniumConfig},
    }
);

$SeleniumObject = _RecreateSeleniumObject();

$Self->True(
    $SeleniumObject->{UnitTestDriverObject}{ResultData}{TestOk},
    'Selenium driver object was initialized with base config',
);

$Self->True(
    $SeleniumObject->{SeleniumTestsActive},
    'SeleniumTestsActive is set to true',
);

my $NewSeleniumConfig = $ConfigObject->Get('SeleniumTestsConfig');

$Self->True(
    $NewSeleniumConfig,
    'SeleniumTestsConfig exists',
);

my $TestHTTPHostname = $HelperObject->GetTestHTTPHostname();
my $BaseURL          = $ConfigObject->Get('HttpType') . "://$TestHTTPHostname";

$Self->True(
    $TestHTTPHostname,
    'TestHTTPHostname is set',
);

$Self->Is(
    $SeleniumObject->{BaseURL},
    $BaseURL,
    'BaseURL has the expected value',
);

# Discard the SeleniumObject and recreate it so that configuration is read again
sub _RecreateSeleniumObject {
    $Kernel::OM->ObjectsDiscard(
        Objects => [ 'Kernel::System::UnitTest::Selenium' ]
    );
    return $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');
}

1;
