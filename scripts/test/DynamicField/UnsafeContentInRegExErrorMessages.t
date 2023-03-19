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

my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my @Tests = (
    {
        Name               => 'Dynamic field with no unsafe error messages',
        DynamicFieldConfig => {
            Name       => 'RegExTextField1',
            Label      => 'RegExTextField',
            FieldOrder => 10000,
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                RegExList => [
                    {
                        Value        => '^\S+$',
                        ErrorMessage => 'A safe error message',
                    },
                    {
                        Value        => '^\S{8}$',
                        ErrorMessage => 'Another safe error message',
                    },
                ],
            },
            ValidID => 1,
        },
        ExpectedRegExList => [
            {
                Value        => '^\S+$',
                ErrorMessage => 'A safe error message',
            },
            {
                Value        => '^\S{8}$',
                ErrorMessage => 'Another safe error message',
            },
        ],
    },
    {
        Name               => 'Dynamic field with unsafe error messages',
        DynamicFieldConfig => {
            Name       => 'RegExTextField2',
            Label      => 'RegExTextField2',
            FieldOrder => 10000,
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                RegExList => [
                    {
                        Value        => '^\S+$',
                        ErrorMessage => 'A safe error message',
                    },
                    {
                        Value        => '^\S{8}$',
                        ErrorMessage => 'An unsafe <script>alert(1);</script> error message',
                    },
                    {
                        Value        => '^\S{0,8}$',
                        ErrorMessage => 'Another unsafe <script>alert(2);</script> error message',
                    },
                ],
            },
            ValidID => 1,
        },
        ExpectedRegExList => [
            {
                Value        => '^\S+$',
                ErrorMessage => 'A safe error message',
            },
            {
                Value        => '^\S{8}$',
                ErrorMessage => 'An unsafe  error message',
            },
            {
                Value        => '^\S{0,8}$',
                ErrorMessage => 'Another unsafe  error message',
            },
        ],
    },
);

TEST:
for my $Test (@Tests) {
    my $DynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
        %{ $Test->{DynamicFieldConfig} },
        UserID => 1,
    );

    $Self->True(
        $DynamicFieldID,
        "$Test->{Name} - dynamic field added successfully",
    );

    my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
        ID => $DynamicFieldID,
    );

    $Self->IsDeeply(
        $DynamicFieldConfig->{Config}{RegExList},
        $Test->{ExpectedRegExList},
        "$Test->{Name} - RegExList matches the expected values",
    );
}

1;
