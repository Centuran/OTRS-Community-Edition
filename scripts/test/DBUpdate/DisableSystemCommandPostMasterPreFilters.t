# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper          = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

# Save original filter settings so that they can be restored when we're done
my $OriginalConfig = $ConfigObject->Get('PostMaster::PreFilterModule');
my $OriginalSettings = [
    map {
        {
            Name           => $_->{Name},
            IsValid        => $_->{IsValid},
            EffectiveValue => $_->{EffectiveValue}
        }
    } map {
        { $SysConfigObject->SettingGet( Name => "PostMaster::PreFilterModule###$_" ) }
    } qw( 4-CMD 000-MatchDBSource )
];

$ConfigObject->Set(
    Key   => 'PostMaster::PreFilterModule',
    Value => {
        '4-CMD' => {
            'Module' => 'Kernel::System::PostMaster::Filter::CMD',
            'CMD'    => '/usr/bin/some.bin',
            'Set'    => {
                'X-OTRS-Ignore' => 'yes',
            },
        },
        '000-MatchDBSource' => {
            'Module' => 'Kernel::System::PostMaster::Filter::MatchDBSource',
        },
    }
);

$SysConfigObject->SettingsSet(
    UserID   => 1,
    Settings => [
        # Add a CMD filter
        {
            Name           => 'PostMaster::PreFilterModule###4-CMD',
            IsValid        => 1,
            EffectiveValue => {
                'Module' => 'Kernel::System::PostMaster::Filter::CMD',
                'CMD'    => '/usr/bin/some.bin',
                'Set'    => {
                    'X-OTRS-Ignore' => 'yes',
                },
            }
        },
        # Add a second filter of different type
        {
            Name           => 'PostMaster::PreFilterModule###000-MatchDBSource',
            IsValid        => 1,
            EffectiveValue => {
                'Module' => 'Kernel::System::PostMaster::Filter::MatchDBSource',
            }
        }
    ]
);

my %FilterSetting = $SysConfigObject->SettingGet(
    Name    => 'PostMaster::PreFilterModule###4-CMD',
    NoCache => 1
);

$Self->Is(
    $FilterSetting{IsValid},
    1,
    'System command pre-filter is initially valid'
);

%FilterSetting = $SysConfigObject->SettingGet(
    Name    => 'PostMaster::PreFilterModule###000-MatchDBSource',
    NoCache => 1
);

$Self->Is(
    $FilterSetting{IsValid},
    1,
    'Other pre-filter is initially valid'
);

#$Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

my $DBUpdateObject = $Kernel::OM->Create('scripts::DBUpdateTo6::DisableSystemCommandPostMasterPreFilters');

$Self->True(
    $DBUpdateObject,
    'Database update object has been created'
);

my $UpdateSuccess = $DBUpdateObject->Run();

$Self->True(
    $UpdateSuccess,
    'Database update operation ran successfully'
);

%FilterSetting = $SysConfigObject->SettingGet(
    Name    => 'PostMaster::PreFilterModule###4-CMD',
    NoCache => 1
);

$Self->Is(
    $FilterSetting{IsValid},
    0,
    'System command pre-filter has been set to invalid'
);

%FilterSetting = $SysConfigObject->SettingGet(
    Name    => 'PostMaster::PreFilterModule###000-MatchDBSource',
    NoCache => 1
);

$Self->Is(
    $FilterSetting{IsValid},
    1,
    'Other pre-filter is still valid'
);

# Restore initial filter settings
$SysConfigObject->SettingsSet(
    UserID   => 1,
    Settings => $OriginalSettings
);
$ConfigObject->Set(
    Key   => 'PostMaster::PreFilterModule',
    Value => $OriginalConfig
);

1;
