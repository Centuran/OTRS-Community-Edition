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

use Kernel::Output::HTML::Preferences::ColumnFilters;

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase  => 1,
        UseTmpArticleDir => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my ( $TestUserLogin, $TestUserID ) = $Helper->TestUserCreate(
    Groups => [ 'users' ],
);

my @Tests = (
    {
        Name => 'Duplicate columns are removed',
        Data => {
            GetParam => {
                'UserFilterColumnsEnabled' => [
                    'TicketNumber', 'TicketNumber',
                    'Changed',      'Changed',
                    'Age',          'Age'
                ]
            }
        },
        ExpectedResult => [ 'TicketNumber', 'Changed', 'Age' ]
    }
);

my $JSONObject  = $Kernel::OM->Get('Kernel::System::JSON');
my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
my $UserObject  = $Kernel::OM->Get('Kernel::System::User');

my $FilterAction = 'AgentTicketEscalationView';

$ParamObject->{Query}->param('FilterAction', $FilterAction);

my $ColumnFiltersObject = Kernel::Output::HTML::Preferences::ColumnFilters->new(
    UserID     => $TestUserID,
    ConfigItem => 'UserFilterColumnsEnabled'
);

for my $Test (@Tests) {
    $ColumnFiltersObject->Run(
        %{ $Test->{Data} },
        UserData => {
            UserID => $TestUserID,
        },
    );

    my %Preferences = $UserObject->GetPreferences(
        UserID => $TestUserID
    );

    my $Result = $JSONObject->Decode(
        Data => $Preferences{"UserFilterColumnsEnabled-$FilterAction"}
    );

    $Self->IsDeeply(
        $Result,
        $Test->{ExpectedResult},
        "$Test->{Name} - the correct value is saved in preferences"
    );
}

1;
