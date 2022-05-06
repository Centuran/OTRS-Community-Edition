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

# Add the DashboardBackend###0420-CmdOutput setting (which is no longer present
# by default)

my %SettingAttributes = (
    Description    => 'Meh.',
    Navigation     => 'Frontend::Agent::View::Dashboard',
    IsInvisible    => 0,
    IsReadonly     => 0,
    IsRequired     => 0,
    IsValid        => 1,
    HasConfigLevel => 0,
    XMLFilename    => 'UnitTest.xml',   
);

my $SysConfigXMLObject = $Kernel::OM->Get('Kernel::System::SysConfig::XML');

my @Settings = $SysConfigXMLObject->SettingListParse(
    %SettingAttributes,
    XMLInput => <<END
<?xml version="1.0" encoding="utf-8"?>
<otrs_config version="2.0" init="Application">
    <Setting Name="DashboardBackend###0420-CmdOutput" Required="0" Valid="1">
        <Description Translatable="1">Meh.</Description>
        <Navigation>Frontend::Agent::View::Dashboard</Navigation>
        <Value>
            <Hash>
                <Item Key="Module">Kernel::Output::HTML::Dashboard::CmdOutput</Item>
                <Item Key="Title" Translatable="1">Sample command output</Item>
                <Item Key="Description" Translatable="1">Show command line output.</Item>
                <Item Key="Block">ContentSmall</Item>
                <Item Key="Group"></Item>
                <Item Key="Default">0</Item>
                <Item Key="CacheTTL">60</Item>
                <Item Key="Cmd">/bin/echo Configure me please.</Item>
                <Item Key="Mandatory">0</Item>
            </Hash>
        </Value>
    </Setting>
</otrs_config>
END
);

for my $Setting (@Settings) {
    $Setting->{EffectiveValue} = $SysConfigObject->SettingEffectiveValueGet(
        Value => $Kernel::OM->Get('Kernel::System::Storable')->Clone(
            Data => $Setting->{XMLContentParsed}{Value}
        )
    );
}

$Kernel::OM->Get('Kernel::System::SysConfig::DB')->DefaultSettingAdd(
    %SettingAttributes,
    %{ $Settings[0] },
    Name   => 'DashboardBackend###0420-CmdOutput',
    UserID => 1
);

# Make sure the troublesome widget exists in Kernel::Config
$ConfigObject->Set(
    Key   => 'DashboardBackend',
    Value => {
        '0420-CmdOutput' => {
            'Module' => 'Kernel::Output::HTML::Dashboard::CmdOutput',
            'Title'       => 'Sample command output',
            'Description' => 'Show command line output.',
            'Block'       => 'ContentSmall',
            'Group'       => '',
            'Default'     => '0',
            'CacheTTL'    => '60',
            'Cmd'         => '/bin/echo Configure me please.',
            'Mandatory'   => '0',
        },
    }
);

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

$Self->False(
    %WidgetSetting && exists $WidgetSetting{IsValid} && $WidgetSetting{IsValid} == 1,
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

1;
