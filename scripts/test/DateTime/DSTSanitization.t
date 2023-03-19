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

my @Tests = (
    {
        Name => 'No correction required',
        Data => {
            DateTime => '2022-03-27 01:02:03',
            TimeZone => 'Europe/Warsaw',
        },
        ExpectedResult => {
            DateTime => '2022-03-27 01:02:03',
            TimeZone => 'Europe/Warsaw',
        },
    },
    {
        Name => 'Correction required for date/time during DST switch',
        Data => {
            DateTime => '2022-03-27 02:03:04',
            TimeZone => 'Europe/Warsaw',
        },
        ExpectedResult => {
            DateTime => '2022-03-27 03:03:04',
            TimeZone => 'Europe/Warsaw',
        },
    }
);

for my $Test (@Tests) {
    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            String   => $Test->{Data}{DateTime},
            TimeZone => $Test->{Data}{TimeZone}
        }
    );

    $Self->Is(
        $DateTimeObject->ToString(),
        $Test->{ExpectedResult}{DateTime},
        "$Test->{Name} - the created object has the expected date/time"
    );

    $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            String   => $Test->{Data}{DateTime},
            TimeZone => 'floating'
        }
    );

    $DateTimeObject->ToTimeZone( TimeZone => $Test->{Data}{TimeZone} );

    $Self->Is(
        $DateTimeObject->ToString(),
        $Test->{ExpectedResult}{DateTime},
        "$Test->{Name} - ToTimeZone() sets the expected date/time"
    );
}

1;
