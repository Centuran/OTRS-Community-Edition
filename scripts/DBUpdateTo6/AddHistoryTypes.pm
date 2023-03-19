# --
# Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package scripts::DBUpdateTo6::AddHistoryTypes;  ## no critic

use strict;
use warnings;

use parent qw(scripts::DBUpdateTo6::Base);

our @ObjectDependencies = (
    'Kernel::System::DB',
);

sub Run {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my @HistoryTypes = (
        'Bulk',
    );

    HISTORY_TYPE:
    for my $HistoryType ( @HistoryTypes ) {
        # Check if this type already exists
        return if !$DBObject->Prepare(
            SQL   => 'SELECT id FROM ticket_history_type WHERE name = ?',
            Bind  => [ \$HistoryType ],
            Limit => 1,
        );

        next HISTORY_TYPE if $DBObject->FetchrowArray();

        return if !$Self->ExecuteXMLDBString(
            XMLString => qq{
                <Insert Table="ticket_history_type">
                    <Data Key="name" Type="Quote">$HistoryType</Data>
                    <Data Key="valid_id">1</Data>
                    <Data Key="create_by">1</Data>
                    <Data Key="create_time">current_timestamp</Data>
                    <Data Key="change_by">1</Data>
                    <Data Key="change_time">current_timestamp</Data>
                </Insert>                
            },
        );
    }

    return 1;
}

1;
