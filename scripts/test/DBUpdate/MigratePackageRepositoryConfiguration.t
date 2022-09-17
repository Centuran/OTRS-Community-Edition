# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;

use vars (qw($Self));

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my @FrameworkVersionParts = split /\./, $Kernel::OM->Get('Kernel::Config')->Get('Version');
my $FrameworkVersion      = $FrameworkVersionParts[0];

my $TestRepository      = 'https://otrscommunityedition.com/download';
my $TestRepositoryLabel = '((OTRS)) Community Edition Freebie Features';
my $ITSMLabel           = '((OTRS)) Community Edition::ITSM';

my @Tests = (
    {
        Name           => 'No Repositories',
        ConfigSet      => {},
        Success        => 1,
        ExpectedResult => {},
    },
    {
        Name      => 'No ITSM Repositories',
        ConfigSet => {
            $TestRepository => 'Test Repository',
        },
        Success        => 1,
        ExpectedResult => {
            $TestRepository => 'Test Repository',
        },
    },
    {
        Name      => 'ITSM 33 Repository',
        ConfigSet => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages33/" => '$ITSMLabel 3.3 Master',
        },
        Success        => 1,
        ExpectedResult => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages$FrameworkVersion/" => "$ITSMLabel $FrameworkVersion Master",
        },
    },
    {
        Name      => 'ITSM 33 and 4 Repository',
        ConfigSet => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages33/" => '$ITSMLabel 3.3 Master',
            # "$TestRepository/itsm/packages4/"  => '$ITSMLabel 4 Master',
        },
        Success        => 1,
        ExpectedResult => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages$FrameworkVersion/" => "$ITSMLabel $FrameworkVersion Master",
        },
    },
    {
        Name      => 'ITSM 33 4 and 5 Repository',
        ConfigSet => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages33/" => '$ITSMLabel 3.3 Master',
            # "$TestRepository/itsm/packages4/"  => '$ITSMLabel 4 Master',
            # "$TestRepository/itsm/packages5/"  => '$ITSMLabel 5 Master',
        },
        Success        => 1,
        ExpectedResult => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages$FrameworkVersion/" => "$ITSMLabel $FrameworkVersion Master",
        },
    },
    {
        Name      => 'ITSM 6 Repository',
        ConfigSet => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages6/" => '$ITSMLabel 6 Master',
        },
        Success        => 1,
        ExpectedResult => {
            $TestRepository => 'Test Repository',

            # "$TestRepository/itsm/packages$FrameworkVersion/" => "$ITSMLabel $FrameworkVersion Master",
        },
    },
);

my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
my $ConfigKey       = 'Package::RepositoryList';
my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

for my $Test (@Tests) {
    if ( $Test->{ConfigSet} ) {
        my $Success = $ConfigObject->Set(
            Key   => $ConfigKey,
            Value => $Test->{ConfigSet},
        );
        $Self->True(
            $Success,
            "$Test->{Name} configuration set in run time",
        );

        my $ExclusiveLockGUID = $SysConfigObject->SettingLock(
            Name   => $ConfigKey,
            Force  => 1,
            UserID => 1,
        );

        my %Result = $SysConfigObject->SettingUpdate(
            Name              => $ConfigKey,
            IsValid           => 1,
            EffectiveValue    => $Test->{ConfigSet},
            ExclusiveLockGUID => $ExclusiveLockGUID,
            UserID            => 1,
        );
        $Self->True(
            $Result{Success},
            "$Test->{Name} configuration set in DB",
        );
    }

    my $UpgradeSuccess = $Kernel::OM->Create('scripts::DBUpdateTo6::MigratePackageRepositoryConfiguration')->Run(
        ContinueOnModified => 1,
    );
    $Self->Is(
        $UpgradeSuccess,
        $Test->{Success},
        "$Test->{Name} Upgrade Package Repository result",
    );

    my %Setting = $SysConfigObject->SettingGet(
        Name   => $ConfigKey,
        UserID => 1,
    );

    $Self->IsDeeply(
        $Setting{EffectiveValue},
        $Test->{ExpectedResult},
        "$Test->{Name} $ConfigKey value",
    );
}

1;
