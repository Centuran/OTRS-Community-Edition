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

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper          = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

# Add the PostMaster::PreFilterModule###4-CMD setting (which is no longer
# present by default)

my %SettingAttributes = (
    Description    => 'Meh.',
    Navigation     => 'Core::Email::PostMaster',
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
    <Setting Name="PostMaster::PreFilterModule###4-CMD" Required="0" Valid="1">
        <Description Translatable="1">Meh.</Description>
        <Navigation>Core::Email::PostMaster</Navigation>
        <Value>
            <Hash>
                <Item Key="Module">Kernel::System::PostMaster::Filter::CMD</Item>
                <Item Key="CMD">/usr/bin/some.bin</Item>
                <Item Key="Set">
                    <Hash>
                        <Item Key="X-OTRS-Ignore">yes</Item>
                    </Hash>
                </Item>
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
    Name   => 'PostMaster::PreFilterModule###4-CMD',
    UserID => 1
);

# Make sure the troublesome filter exists in Kernel::Config
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

1;
