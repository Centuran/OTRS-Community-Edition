# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $Helper        = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');
my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');

# TODO: PackageVerification
# $Helper->ConfigSettingChange(
#     Valid => 1,
#     Key   => 'Package::AllowNotVerifiedPackages',
#     Value => 0,
# );

my $RandomID = $Helper->GetRandomID();

# Override Request() from WebUserAgent to always return some test data without making any
#   actual web service calls. This should prevent instability in case cloud services are
#   unavailable at the exact moment of this test run.
my $CustomCode = <<"EOS";
sub Kernel::Config::Files::ZZZZUnitTestAdminPackageManager${RandomID}::Load {} # no-op, avoid warning logs
use Kernel::System::WebUserAgent;
package Kernel::System::WebUserAgent;
use strict;
use warnings;
## nofilter(TidyAll::Plugin::OTRS::Perl::TestSubs)
{
    no warnings 'redefine';
    sub Request {
        return (
            Status  => '200 OK',
            Content => '{"Success":1,"Results":{"PackageManagement":[{"Operation":"PackageVerify","Data":{"Test":"not_verified","TestPackageIncompatible":"not_verified"},"Success":"1"}]},"ErrorMessage":""},
        );
    }
}
1;
EOS
$Helper->CustomCodeActivate(
    Code       => $CustomCode,
    Identifier => 'Admin::Package::Upgrade' . $RandomID,
);

my $Location = $ConfigObject->Get('Home') . '/scripts/test/sample/PackageManager/TestPackage.opm';

# Make sure that package is not installed
my $UninstallCommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::Package::Uninstall');
$UninstallCommandObject->Execute($Location);

my $UpgradeCommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::Package::Upgrade');

my $ExitCode = $UpgradeCommandObject->Execute($Location);

$Self->Is(
    $ExitCode,
    # TODO: PackageVerification - for now test has reversed purpose
    0,
    "Admin::Package::Upgrade exit code - package upgraded",
);

$ExitCode = $UpgradeCommandObject->Execute($Location);

$Self->Is(
    $ExitCode,
    # TODO: PackageVerification - for now test has reversed purpose, package installed
    1,
    "Admin::Package::Upgrade run with error - Can't upgrade, package already installed!",
);

1;
