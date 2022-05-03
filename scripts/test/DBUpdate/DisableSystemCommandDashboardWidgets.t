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
        RestoreDatabase      => 1,
    },
);
my $Helper          = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

# Save original widget settings so that they can be restored when we're done
my $OriginalSettings = [
    map {
        {
            Name           => $_->{Name},
            IsValid        => $_->{IsValid},
            EffectiveValue => $_->{EffectiveValue}
        }
    } map {
        { $SysConfigObject->SettingGet( Name => "DashboardBackend###$_" ) }
    } qw( 0420-CmdOutput 0400-UserOnline )
];

$SysConfigObject->SettingsSet(
    UserID   => 1,
    Settings => [
        # Add a CmdOutput widget
        {
            Name           => 'DashboardBackend###0420-CmdOutput',
            IsValid        => 1,
            EffectiveValue => {
                'Module'      => 'Kernel::Output::HTML::Dashboard::CmdOutput',
                'Title'       => 'Sample command output',
                'Description' => 'Show command line output.',
                'Block'       => 'ContentSmall',
                'Group'       => '',
                'Default'     => '0',
                'CacheTTL'    => '60',
                'Cmd'         => '/bin/echo Configure me please.',
                'Mandatory'   => '0',
            }
        },
        # Add a second widget of different type
        {
            Name           => 'DashboardBackend###0400-UserOnline',
            IsValid        => 1,
            EffectiveValue => {
                'Block'         => 'ContentSmall',
                'CacheTTLLocal' => '5',
                'Default'       => '0',
                'Description'   => '',
                'Filter'        => 'Agent',
                'Group'         => '',
                'IdleMinutes'   => '60',
                'Limit'         => '10',
                'Module'        => 'Kernel::Output::HTML::Dashboard::UserOnline',
                'ShowEmail'     => '0',
                'SortBy'        => 'UserFullname',
                'Title'         => 'Online'
            }
        }
    ]
);

my %WidgetSetting = $SysConfigObject->SettingGet(
    Name    => 'DashboardBackend###0420-CmdOutput',
    NoCache => 1
);

$Self->Is(
    $WidgetSetting{IsValid},
    1,
    'System command dashboard widget is initially valid'
);

%WidgetSetting = $SysConfigObject->SettingGet(
    Name    => 'DashboardBackend###0400-UserOnline',
    NoCache => 1
);

$Self->Is(
    $WidgetSetting{IsValid},
    1,
    'Other dashboard widget is initially valid'
);

my $DBUpdateObject = $Kernel::OM->Create('scripts::DBUpdateTo6::DisableSystemCommandDashboardWidgets');

$Self->True(
    $DBUpdateObject,
    'Database update object has been created'
);

my $UpdateSuccess = $DBUpdateObject->Run();

$Self->True(
    $UpdateSuccess,
    'Database update operation ran successfully'
);

%WidgetSetting = $SysConfigObject->SettingGet(
    Name    => 'DashboardBackend###0420-CmdOutput',
    NoCache => 1
);

$Self->Is(
    $WidgetSetting{IsValid},
    0,
    'System command dashboard widget has been set to invalid'
);

%WidgetSetting = $SysConfigObject->SettingGet(
    Name    => 'DashboardBackend###0400-UserOnline',
    NoCache => 1
);

$Self->Is(
    $WidgetSetting{IsValid},
    1,
    'Other dashboard widget is still valid'
);

# Restore initial widget settings
$SysConfigObject->SettingsSet(
    UserID   => 1,
    Settings => $OriginalSettings
);

1;
