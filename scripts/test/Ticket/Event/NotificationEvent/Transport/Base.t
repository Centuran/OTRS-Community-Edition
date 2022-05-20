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
    'Kernel::System::MailQueue' => {
        CheckEmailAddresses => 0,
    },
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase  => 1,
        UseTmpArticleDir => 1,
    },
);

my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $ArticleBackendObject      = $Kernel::OM->Get('Kernel::System::Ticket::Article::Backend::Internal');
my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
my $TicketObject              = $Kernel::OM->Get('Kernel::System::Ticket');
my $TransportObject           = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent::Transport::Email');
my $UserObject                = $Kernel::OM->Get('Kernel::System::User');

my $RandomID = $HelperObject->GetRandomID();

$HelperObject->FixedTimeSet(
    $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            String => '2022-01-02 03:04:05',
        },
    )
);

my $TestUserLogin = $HelperObject->TestUserCreate( Groups => [ 'users' ] );
my %TestUserData  = $UserObject->GetUserData( User => $TestUserLogin );
my $TestUserID    = $TestUserData{UserID};

my %FieldValues = (
    'test-1@test.centuran.com' => 'test-1',
    'test-2@test.centuran.com' => 'test-2',
    'test-3@test.centuran.com' => 'test-3'
);
#my %PossibleValues = (
#
#)

my @DynamicFields = (
    {
        Name       => "TextField$RandomID",
        Label      => "TextField$RandomID",
        FieldType  => 'Text',
        FieldOrder => 9999,
        ObjectType => 'Ticket',
        Config     => {
            DefaultValue => '',
            Link         => '',
        },
        Reorder => 0,
        ValidID => 1,
        UserID  => $TestUserID,
    },
    {
        Name       => "DropdownField$RandomID",
        Label      => "DropdownField$RandomID",
        FieldType  => 'Dropdown',
        FieldOrder => 9999,
        ObjectType => 'Ticket',
        Config     => {
            DefaultValue   => '',
            Link           => '',
            PossibleValues => \%FieldValues,
            PossibleNone   => 0,
        },
        Reorder => 0,
        ValidID => 1,
        UserID  => $TestUserID,
    },
    {
        Name       => "MultiselectField$RandomID",
        Label      => "MultiselectField$RandomID",
        FieldType  => 'Multiselect',
        FieldOrder => 9999,
        ObjectType => 'Ticket',
        Config     => {
            DefaultValue   => '',
            Link           => '',
            PossibleValues => \%FieldValues,
            PossibleNone   => 0,
        },
        Reorder => 0,
        ValidID => 1,
        UserID  => $TestUserID,
    },
);

for my $DynamicFieldArgs (@DynamicFields) {
    my $FieldID = $DynamicFieldObject->DynamicFieldAdd( %{$DynamicFieldArgs} );

    $Self->True(
        $FieldID,
        "Dynamic field $DynamicFieldArgs->{Name} has been created"
    );
}

my @Tests = (
    {
        Name => 'No value is set',
        Data => {
            DynamicFields  => {},
            RecipientEmail => '',
        },
        ExpectedResult => {
            RecipientEmail => undef,
        },
    },
    {
        Name => 'RecipientEmail is not set',
        Data => {
            DynamicFields => {
                "TextField$RandomID"        => (keys %FieldValues)[0],
                "DropdownField$RandomID"    => (keys %FieldValues)[1],
                "MultiselectField$RandomID" => (keys %FieldValues)[2],
            },
            RecipientEmail => '',
        },
        ExpectedResult => {
            RecipientEmail => undef,
        },
    },
    {
        Name => 'RecipientEmail is set',
        Data => {
            DynamicFields => {
                "TextField$RandomID"        => (keys %FieldValues)[0],
                "DropdownField$RandomID"    => (keys %FieldValues)[1],
                "MultiselectField$RandomID" => (keys %FieldValues)[2],
            },
            RecipientEmail => 'test-10@test.centuran.com',
        },
        ExpectedResult => {
            RecipientEmail => 'test-10@test.centuran.com',
        },
    },
    {
        Name => 'RecipientEmail is set with text dynamic field',
        Data => {
            DynamicFields => {
                "TextField$RandomID" => (keys %FieldValues)[0],
            },
            RecipientEmail => 'test-10@test.centuran.com, ' .
                "<OTRS_TICKET_DynamicField_TextField$RandomID>",
        },
        ExpectedResult => {
            RecipientEmail => 'test-10@test.centuran.com, ' .
                (keys %FieldValues)[0],
        },
    },
    {
        Name => 'RecipientEmail is set with dropdown dynamic field',
        Data => {
            DynamicFields => {
                "DropdownField$RandomID" => (keys %FieldValues)[1],
            },
            RecipientEmail => 'test-10@test.centuran.com, ' .
                "<OTRS_TICKET_DynamicField_DropdownField$RandomID>",
        },
        ExpectedResult => {
            RecipientEmail => 'test-10@test.centuran.com, ' .
                (keys %FieldValues)[1],
        },
    },
    {
        Name => 'RecipientEmail is set with multiselect dynamic field',
        Data => {
            DynamicFields => {
                "MultiselectField$RandomID" => (keys %FieldValues)[2],
            },
            RecipientEmail => 'test-10@test.centuran.com, ' .
                "<OTRS_TICKET_DynamicField_MultiselectField$RandomID>",
        },
        ExpectedResult => {
            RecipientEmail => 'test-10@test.centuran.com, ' .
                (keys %FieldValues)[2],
        },
    },
    {
        Name => 'RecipientEmail has multiple values set with multiselect dynamic field',
        Data => {
            DynamicFields => {
                "MultiselectField$RandomID" => [ sort keys %FieldValues ],
            },
            RecipientEmail => 'test-10@test.centuran.com, ' .
                "<OTRS_TICKET_DynamicField_MultiselectField$RandomID>",
        },
        ExpectedResult => {
            RecipientEmail => 'test-10@test.centuran.com, ' .
                join(', ', sort keys %FieldValues),
        },
    },
    {
        Name => 'RecipientEmail preserves the order of values set with multiselect dynamic field',
        Data => {
            DynamicFields => {
                "MultiselectField$RandomID" => [ reverse sort keys %FieldValues ],
            },
            RecipientEmail => 'test-10@test.centuran.com, ' .
                "<OTRS_TICKET_DynamicField_MultiselectField$RandomID>",
        },
        ExpectedResult => {
            RecipientEmail => 'test-10@test.centuran.com, ' .
                join(', ', reverse sort keys %FieldValues),
        },
    },
);

for my $Test (@Tests) {
    my $TicketID = $TicketObject->TicketCreate(
        Title        => 'Test Ticket',
        QueueID      => 1,
        Lock         => 'unlock',
        Priority     => '3 normal',
        State        => 'new',
        CustomerID   => 'test.centuran.com',
        CustomerUser => 'customer-test-1@test.centuran.com',
        OwnerID      => $TestUserID,
        UserID       => $TestUserID,
    );

    $Self->True(
        $TicketID,
        "$Test->{Name} - test ticket has been created"
    );

    my $ArticleID = $ArticleBackendObject->ArticleCreate(
        TicketID             => $TicketID,
        SenderType           => 'customer',
        From                 => 'customer-test-1@test.centuran.com',
        To                   => 'Test Agent <test-1@test.centuran.com>',
        Subject              => 'Test article subject',
        Body                 => 'Test article body',
        Charset              => 'utf8',
        MimeType             => 'text/plain',
        HistoryType          => 'NewTicket',
        HistoryComment       => 'New test ticket',
        IsVisibleForCustomer => 1,
        UserID               => $TestUserID,
    );

    $Self->True(
        $ArticleID,
        "$Test->{Name} - test article has been created"
    );

    for my $FieldName ( sort keys %{ $Test->{Data}{DynamicFields} } ) {
        my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
            Name => $FieldName
        );
        my $Value    = $Test->{Data}{DynamicFields}{$FieldName};
        my $ValueSet = $DynamicFieldBackendObject->ValueSet(
            DynamicFieldConfig => $DynamicField,
            ObjectID           => $TicketID,
            Value              => $Value,
            UserID             => $TestUserID,
        );

        $Self->True(
            $ValueSet,
            "$Test->{Name} - value of field $FieldName has been set"
        );
    }

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 1,
        UserID        => $TestUserID,
        Silent        => 1,
    );

    my $RecipientEmail = $TransportObject->_ReplaceTicketAttributes(
        Ticket => \%Ticket,
        Field  => $Test->{Data}{RecipientEmail}
    );

    $Self->Is(
        $RecipientEmail,
        $Test->{ExpectedResult}{RecipientEmail},
        "$Test->{Name} - RecipientEmail is set to the expected value"
    );
}

1;
