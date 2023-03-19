# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
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

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $Helper             = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');

        # Create test user.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        # Get test user ID.
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        my @Tests = (
            {
                TN                => $TicketObject->TicketCreateNumber(),
                CustomerUser      => $Helper->GetRandomID() . '@first.com',
                DynamicFieldValue => 'Key',
            },
            {
                TN                => $TicketObject->TicketCreateNumber(),
                CustomerUser      => $Helper->GetRandomID() . '@second.com',
                DynamicFieldValue => 'Key::SubKey',
            },
            {
                TN                => $TicketObject->TicketCreateNumber(),
                CustomerUser      => $Helper->GetRandomID() . '@third.com',
                CustomerID        => 'CustomerCompany' . $Helper->GetRandomID() . '(#)',
                DynamicFieldValue => 'Key;Special',
            },
            {
                TN           => $TicketObject->TicketCreateNumber(),
                CustomerUser => $Helper->GetRandomID() . '@fourth.com',
                CustomerID   => 'CustomerCompany#%' . $Helper->GetRandomID() . '(#)',
            },
        );

        # Create a test dynamic field
        my $DynamicFieldName = 'DynamicField' . $Helper->GetRandomID();
        
        my $DynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
            Name       => $DynamicFieldName,
            Label      => $DynamicFieldName,
            FieldOrder => 9999,
            FieldType  => 'Dropdown',
            ObjectType => 'Ticket',
            Config     => {
                PossibleValues => {
                    'Key'         => 'Value',
                    'Key::SubKey' => 'SubValue',
                    'Key;Special' => 'SpecialValue',
                },
            },
            ValidID => 1,
            UserID  => 1,
        );
        $Self->True(
            $DynamicFieldID,
            "Dynamic field $DynamicFieldName has been created",
        );

        # Create test tickets.
        my @Tickets;
        for my $Test (@Tests) {
            my $TicketID = $TicketObject->TicketCreate(
                TN           => $Test->{TN},
                Title        => 'Selenium Test Ticket',
                Queue        => 'Raw',
                Lock         => 'unlock',
                Priority     => '3 normal',
                State        => 'new',
                CustomerID   => $Test->{CustomerID} || 'SomeCustomer',
                CustomerUser => $Test->{CustomerUser},
                OwnerID      => $TestUserID,
                UserID       => $TestUserID,
            );
            $Self->True(
                $TicketID,
                "Ticket ID $TicketID - created"
            );

            # Set dynamic field value for test ticket
            if (exists $Test->{DynamicFieldValue}) {
                my $DynamicFieldValueObject = 
                    $Kernel::OM->Get('Kernel::System::DynamicFieldValue');
                
                my $ValueSet = $DynamicFieldValueObject->ValueSet(
                    FieldID    => $DynamicFieldID,
                    ObjectType => 'Ticket',
                    ObjectID   => $TicketID,
                    Value      => [
                        {
                            ValueText => $Test->{DynamicFieldValue},
                        }
                    ],
                    UserID => 1,
                );
                $Self->True(
                    $ValueSet,
                    "Dynamic field $DynamicFieldName value set for ticket $TicketID"
                );
            }

            push @Tickets, {
                TicketID          => $TicketID,
                TN                => $Test->{TN},
                CustomerUser      => $Test->{CustomerUser},
                CustomerID        => $Test->{CustomerID},
                DynamicFieldValue => $Test->{DynamicFieldValue}
            };
        }

        # Login test user.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $ScriptAlias  = $ConfigObject->Get('ScriptAlias');

        # Turn on the 'Customer User ID' column by default.
        my $Config = $ConfigObject->Get('DashboardBackend')->{'0120-TicketNew'};
        $Config->{DefaultColumns}->{CustomerUserID} = '2';
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'DashboardBackend###0120-TicketNew',
            Value => $Config,
        );

        # Refresh dashboard screen and clean it's cache.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Dashboard',
        );

        $Selenium->VerifiedRefresh();

        # Navigate to dashboard screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?");

        # Check if 'Customer User ID' filter for TicketNew dashboard is set.
        eval {
            $Self->True(
                $Selenium->find_element("//a[contains(\@title, \'Customer User ID\' )]"),
                "'Customer User ID' filter for TicketNew dashboard is set",
            );
        };
        if ($@) {
            $Self->True(
                $@,
                "'Customer User ID' filter for TicketNew dashboard is not set",
            );
        }
        else {

            # Click on column setting filter for the first customer in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'Customer User ID\' )]")->click();
            $Selenium->WaitFor(
                JavaScript =>
                    'return $("div.ColumnSettingsBox").length'
            );

            # Select the first test 'Customer User ID' as filter for TicketNew generic dashboard overview.
            my $ParentElement = $Selenium->find_element( "div.ColumnSettingsBox", 'css' );
            $Selenium->find_child_element( $ParentElement, "./input" )->send_keys( $Tickets[0]->{CustomerUser} );
            sleep 1;

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("span.AJAXLoader:visible").length'
            );

            # Choose the value.
            $Selenium->execute_script(
                "\$('#ColumnFilterCustomerUserID0120-TicketNew').val('$Tickets[0]->{CustomerUser}').trigger('change');"
            );

            # Wait for auto-complete action.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("a[href*=\'TicketID='
                    . $Tickets[1]->{TicketID}
                    . '\']").length'
            );

            # Verify the first test ticket is found by filtering with the second customer that is not in DB.
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[0]->{TN} ) > -1,
                "Test ticket with TN $Tickets[0]->{TN} - found on screen after filtering with customer - $Tickets[0]->{CustomerUser}",
            );

            # Verify the second test ticket is not found by filtering with the first customer that is not in DB.
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[1]->{TN} ) == -1,
                "Test ticket with TN $Tickets[1]->{TN} - not found on screen after filtering with customer - $Tickets[0]->{CustomerUser}",
            );

            # Click on column setting filter for 'Customer User ID' in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'Customer User ID\' )]")->click();
            sleep 1;

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("span.AJAXLoader:visible").length'
            );

            # Delete the current filter.
            $Selenium->find_element( "a.DeleteFilter", 'css' )->click();

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("#Dashboard0120-TicketNew-box.Loading").length'
            );

            # Click on column setting filter for 'Customer User ID' in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'Customer User ID\' )]")->click();
            $Selenium->WaitFor(
                JavaScript =>
                    'return $("div.ColumnSettingsBox").length'
            );

            # Select test 'Customer User ID' as filter for TicketNew generic dashboard overview.
            $ParentElement = $Selenium->find_element( "div.ColumnSettingsBox", 'css' );
            $Selenium->find_child_element( $ParentElement, "./input" )->send_keys( $Tickets[1]->{CustomerUser} );
            sleep 1;

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("span.AJAXLoader:visible").length'
            );

            # Choose the value.
            $Selenium->execute_script(
                "\$('#ColumnFilterCustomerUserID0120-TicketNew').val('$Tickets[1]->{CustomerUser}').trigger('change');"
            );

            # Wait for auto-complete action.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("a[href*=\'TicketID='
                    . $Tickets[0]->{TicketID}
                    . '\']").length'
            );

            # Verify the second test ticket is found by filtering with the second customer that is not in DB.
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[1]->{TN} ) > -1,
                "Test ticket TN $Tickets[1]->{TN} - found on screen after filtering with the customer - $Tickets[1]->{CustomerUser}",
            );

            # Verify the first test ticket is not found by filtering with the second customer that is not in DB.
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[0]->{TN} ) == -1,
                "Test ticket TN $Tickets[0]->{TN} - not found on screen after filtering with customer - $Tickets[1]->{CustomerUser}",
            );

            # Cleanup
            # Click on column setting filter for 'Customer User ID' in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'Customer User ID\' )]")->click();
            sleep 1;

            # wait for AJAX to finish
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("span.AJAXLoader:visible").length'
            );

            # Delete the current filter.
            $Selenium->find_element( "a.DeleteFilter", 'css' )->click();

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("#Dashboard0120-TicketNew-box.Loading").length'
            );
        }

        # Update configuration.
        $Config = $ConfigObject->Get('DashboardBackend')->{'0120-TicketNew'};
        $Config->{DefaultColumns}->{CustomerUserID} = '0';
        $Config->{DefaultColumns}->{CustomerID}     = '2';
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'DashboardBackend###0120-TicketNew',
            Value => $Config,
        );

        # Refresh dashboard screen and clean it's cache.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Dashboard',
        );

        $Selenium->VerifiedRefresh();

        # Navigate to dashboard screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?");

        # Check if 'Customer ID' filter for TicketNew dashboard is set.
        eval {
            $Self->True(
                $Selenium->find_element("//a[contains(\@title, \'Customer ID\' )]"),
                "'Customer ID' filter for TicketNew dashboard is set",
            );
        };
        if ($@) {
            $Self->True(
                $@,
                "'Customer ID' filter for TicketNew dashboard is not set",
            );
        }
        else {

            # Click on column setting filter for the first customer in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'Customer ID\' )]")->click();
            $Selenium->WaitFor(
                JavaScript =>
                    'return $("div.ColumnSettingsBox").length'
            );

            # Select the third test Customer ID as filter for TicketNew generic dashboard overview.
            my $ParentElement = $Selenium->find_element( "div.ColumnSettingsBox", 'css' );
            $Selenium->find_child_element( $ParentElement, "./input" )->send_keys( $Tickets[2]->{CustomerID} );
            sleep 1;

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("span.AJAXLoader:visible").length'
            );

            # Choose the value.
            $Selenium->execute_script(
                "\$('#ColumnFilterCustomerID0120-TicketNew').val('$Tickets[2]->{CustomerID}').trigger('change');"
            );

            # Wait for auto-complete action.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("a[href*=\'TicketID='
                    . $Tickets[1]->{TicketID}
                    . '\']").length'
            );

            # Verify the third test ticket is found  by filtering with the second customer that is not in DB.
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[2]->{TN} ) > -1,
                "Test ticket with TN $Tickets[2]->{TN} - found on screen after filtering with customer - $Tickets[2]->{CustomerID}",
            );

            # Verify the second test ticket is not found by filtering with the first customer that is not in DB.
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[1]->{TN} ) == -1,
                "Test ticket with TN $Tickets[1]->{TN} - not found on screen after filtering with customer - $Tickets[1]->{CustomerID}",
            );

            # Click on column setting filter for CustomerID in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'Customer ID\' )]")->click();
            sleep 1;

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("span.AJAXLoader:visible").length'
            );

            # Delete the current filter.
            $Selenium->find_element( "a.DeleteFilter", 'css' )->click();

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("#Dashboard0120-TicketNew-box.Loading").length'
            );

            # Verify if CustomerID containing special characters is filtered correctly. See bug#14982.
            $Selenium->find_element("//a[contains(\@title, \'Customer ID\' )]")->click();
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('.CustomerIDAutoComplete:visible').length;"
            );

            $Selenium->find_element( ".CustomerIDAutoComplete", 'css' )->send_keys( $Tickets[3]->{CustomerID} );

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("span.AJAXLoader:visible").length'
            );

            # Choose the value.
            $Selenium->execute_script(
                "\$('#ColumnFilterCustomerID0120-TicketNew').val('$Tickets[3]->{CustomerID}').trigger('change');"
            );

            # Wait for autocomplete action.
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('td div[title=\"$Tickets[3]->{CustomerID}\"]').length == 1;"
            );

            # Verify CustomerID containing special characters is found.
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[3]->{TN} ) > -1,
                "Test ticket with TN $Tickets[3]->{TN} - found on screen after filtering with customer - $Tickets[3]->{CustomerID}",
            );

            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('a#Dashboard0120-TicketNew-remove-filters').length == 1;"
            );

            # Click the filter removal icon
            $Selenium->execute_script(
                "\$('a#Dashboard0120-TicketNew-remove-filters').trigger('click');"
            );

            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && !$("#Dashboard0120-TicketNew-box.Loading").length'
            );
        }

        # Update configuration to include dynamic field
        $Config = $ConfigObject->Get('DashboardBackend')->{'0120-TicketNew'};
        $Config->{DefaultColumns}->{CustomerUserID} = '0';
        $Config->{DefaultColumns}->{CustomerID}     = '0';
        $Config->{DefaultColumns}->{"DynamicField_$DynamicFieldName"} = '2';
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'DashboardBackend###0120-TicketNew',
            Value => $Config,
        );

        # Clean up dashboard screen cache
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Dashboard',
        );

        $Selenium->VerifiedRefresh();

        # Navigate to dashboard screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?");

        # Check if dynamic field filter for TicketNew dashboard is set.
        eval {
            $Self->True(
                $Selenium->find_element("//a[contains(\@title, \'$DynamicFieldName, filter\' )]"),
                "'$DynamicFieldName' filter for TicketNew dashboard is set",
            );
        };
        if ($@) {
            $Self->True(
                $@,
                "'$DynamicFieldName' filter for TicketNew dashboard is not set",
            );
        }
        else {

            my $FilterElementID =
                "ColumnFilterDynamicField_${DynamicFieldName}0120-TicketNew";

            # Click on column setting filter for the dynamic field in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'$DynamicFieldName, filter\' )]")->click();

            my $FieldValue = $Tickets[0]->{DynamicFieldValue};

            # Wait for the expected option to be available
            $Selenium->WaitFor(
                JavaScript => qq{
                    return typeof(\$) === "function" &&
                        \$('#$FilterElementID > option[value="$FieldValue"]').length
                }
            );

            # Select the option corresponding to the first test ticket
            $Selenium->execute_script(qq{
                \$('#$FilterElementID').val('$FieldValue').trigger('change');
            });

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript => q{
                    return typeof($) === "function" &&
                        !$("#Dashboard0120-TicketNew-box.Loading").length
                }
            );

            # Check if the first test ticket is found using the dynamic field
            # filter
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[0]->{TN} ) > -1,
                "Test ticket $Tickets[0]->{TN} is found when filtering " .
                    "with dynamic field value $FieldValue"
            );

            # Check if the second and third test tickets aren't found using
            # the dynamic field filter
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[1]->{TN} ) == -1,
                "Test ticket $Tickets[1]->{TN} is not found when filtering " .
                    "with dynamic field value $FieldValue"
            );
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[2]->{TN} ) == -1,
                "Test ticket $Tickets[2]->{TN} is not found when filtering " .
                    "with dynamic field value $FieldValue"
            );

            # Click the filter removal icon
            $Selenium->execute_script(
                "\$('a#Dashboard0120-TicketNew-remove-filters').trigger('click');"
            );

            $Selenium->WaitFor(
                JavaScript => q{
                    return typeof($) === 'function' &&
                        !$('#Dashboard0120-TicketNew-box.Loading').length
                }
            );

            # Click on column setting filter for the dynamic field in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'$DynamicFieldName, filter\' )]")->click();

            $FieldValue = $Tickets[1]->{DynamicFieldValue};

            # Wait for the expected option to be available
            $Selenium->WaitFor(
                JavaScript => qq{
                    return typeof(\$) === "function" &&
                        \$('#$FilterElementID > option[value="$FieldValue"]').length
                }
            );

            # Select the option corresponding to the second test ticket
            $Selenium->execute_script(qq{
                \$('#$FilterElementID').val('$FieldValue').trigger('change');
            });

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript => q{
                    return typeof($) === "function" &&
                        !$("#Dashboard0120-TicketNew-box.Loading").length
                }
            );

            # Check if the second test ticket is found using the dynamic field
            # filter
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[1]->{TN} ) > -1,
                "Test ticket $Tickets[1]->{TN} is found when filtering " .
                    "with dynamic field value $FieldValue"
            );

            # Check if the first and third test tickets aren't found using
            # the dynamic field filter
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[0]->{TN} ) == -1,
                "Test ticket $Tickets[0]->{TN} is not found when filtering " .
                    "with dynamic field value $FieldValue"
            );
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[2]->{TN} ) == -1,
                "Test ticket $Tickets[2]->{TN} is not found when filtering " .
                    "with dynamic field value $FieldValue"
            );

            # Click the filter removal icon
            $Selenium->execute_script(
                "\$('a#Dashboard0120-TicketNew-remove-filters').trigger('click');"
            );

            $Selenium->WaitFor(
                JavaScript => q{
                    return typeof($) === 'function' &&
                        !$('#Dashboard0120-TicketNew-box.Loading').length
                }
            );

            # Click on column setting filter for the dynamic field in TicketNew generic dashboard overview.
            $Selenium->find_element("//a[contains(\@title, \'$DynamicFieldName, filter\' )]")->click();

            $FieldValue = $Tickets[2]->{DynamicFieldValue};

            # Wait for the expected option to be available
            $Selenium->WaitFor(
                JavaScript => qq{
                    return typeof(\$) === "function" &&
                        \$('#$FilterElementID > option[value="$FieldValue"]').length
                }
            );

            # Select the option corresponding to the third test ticket
            $Selenium->execute_script(qq{
                \$('#$FilterElementID').val('$FieldValue').trigger('change');
            });

            # Wait for AJAX to finish.
            $Selenium->WaitFor(
                JavaScript => q{
                    return typeof($) === "function" &&
                        !$("#Dashboard0120-TicketNew-box.Loading").length
                }
            );

            # Check if the third test ticket is found using the dynamic field
            # filter
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[2]->{TN} ) > -1,
                "Test ticket $Tickets[2]->{TN} is found when filtering " .
                    "with dynamic field value $FieldValue"
            );

            # Check if the first and second test tickets aren't found using
            # the dynamic field filter
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[0]->{TN} ) == -1,
                "Test ticket $Tickets[0]->{TN} is not found when filtering " .
                    "with dynamic field value $FieldValue"
            );
            $Self->True(
                index( $Selenium->get_page_source(), $Tickets[1]->{TN} ) == -1,
                "Test ticket $Tickets[1]->{TN} is not found when filtering " .
                    "with dynamic field value $FieldValue"
            );

            # Click the filter removal icon
            $Selenium->execute_script(
                "\$('a#Dashboard0120-TicketNew-remove-filters').trigger('click');"
            );

            $Selenium->WaitFor(
                JavaScript => q{
                    return typeof($) === 'function' &&
                        !$('#Dashboard0120-TicketNew-box.Loading').length
                }
            );
        }

        # Delete test tickets.
        for my $Ticket (@Tickets) {
            my $Success = $TicketObject->TicketDelete(
                TicketID => $Ticket->{TicketID},
                UserID   => 1,
            );

            # Ticket deletion could fail if apache still writes to ticket history. Try again in this case.
            if ( !$Success ) {
                sleep 3;
                $Success = $TicketObject->TicketDelete(
                    TicketID => $Ticket->{TicketID},
                    UserID   => 1,
                );
            }
            $Self->True(
                $Success,
                "Ticket ID $Ticket->{TicketID} - deleted"
            );
        }

        # Delete test dynamic field
        my $Deleted = $DynamicFieldObject->DynamicFieldDelete(
            ID     => $DynamicFieldID,
            UserID => 1,
        );
        $Self->True(
            $Deleted,
            "Dynamic field $DynamicFieldName has been deleted",
        );

        # Make sure cache is correct.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Ticket',
        );
    }
);

1;
