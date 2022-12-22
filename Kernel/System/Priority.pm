# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Priority;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::SysConfig',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Priority - priority lib

=head1 DESCRIPTION

All ticket priority functions.

=head1 PUBLIC INTERFACE

=head2 new()

create an object

    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');


=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Priority';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=head2 PriorityList()

get a hash of existing priorities, mapping IDs to names

    my %Priorities = $PriorityObject->PriorityList(
        Valid => 0, # optional 1|0, defaults to 1
    );

returns:

    %Priorities = (
        1 => '1 very low',
        2 => '2 low',
        3 => '3 normal',
        4 => '4 high',
        5 => '5 very high'
    )

=cut

sub PriorityList {
    my ( $Self, %Param ) = @_;

    # check valid param
    if ( !defined $Param{Valid} ) {
        $Param{Valid} = 1;
    }

    # create cachekey
    my $CacheKey;
    if ( $Param{Valid} ) {
        $CacheKey = 'PriorityList::Valid';
    }
    else {
        $CacheKey = 'PriorityList::All';
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # create sql
    my $SQL = 'SELECT id, name FROM ticket_priority ';
    if ( $Param{Valid} ) {
        $SQL
            .= "WHERE valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    return if !$DBObject->Prepare( SQL => $SQL );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=head2 PriorityGet()

get the attributes of a priority

    my %Priority = $PriorityObject->PriorityGet(
        PriorityID => 2,
        UserID     => 1,
    );

returns:

    %Priority = (
        ID          => '2',
        Name        => '2 low',
        Color       => '#83bfc8',
        ValidID     => '1',
        CreateTime  => '2022-02-01 12:34:56',
        CreateBy    => '12',
        ChangeTime  => '2022-03-01 23:45:01',
        ChangeBy    => '34',
    )

=cut

sub PriorityGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Name (qw(PriorityID UserID)) {
        if ( !$Param{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => 'PriorityGet' . $Param{PriorityID},
    );
    return %{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, color, valid_id, create_time, create_by, change_time, change_by '
            . 'FROM ticket_priority WHERE id = ?',
        Bind  => [ \$Param{PriorityID} ],
        Limit => 1,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ID}         = $Row[0];
        $Data{Name}       = $Row[1];
        $Data{Color}      = $Row[2];
        $Data{ValidID}    = $Row[3];
        $Data{CreateTime} = $Row[4];
        $Data{CreateBy}   = $Row[5];
        $Data{ChangeTime} = $Row[6];
        $Data{ChangeBy}   = $Row[7];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => 'PriorityGet' . $Param{PriorityID},
        Value => \%Data,
    );

    return %Data;
}

=head2 PriorityAdd()

add a ticket priority

    my $True = $PriorityObject->PriorityAdd(
        Name    => 'Prio',
        Color   => '#ff0000',   # Optional
        ValidID => 1,
        UserID  => 1,
    );

=cut

sub PriorityAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Name (qw(Name ValidID UserID)) {
        if ( !$Param{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( !$Param{Color} ) {
        $Param{Color} = '';
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Do(
        SQL => 'INSERT INTO ticket_priority (name, valid_id, color, '
            . 'create_time, create_by, change_time, change_by) VALUES '
            . '(?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Color}, \$Param{UserID},
            \$Param{UserID},
        ],
    );

    # get new priority id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket_priority WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return if !$ID;

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return $ID;
}

=head2 PriorityUpdate()

update a existing ticket priority

    my $True = $PriorityObject->PriorityUpdate(
        PriorityID     => 123,
        Name           => 'New Prio',
        Color          => '#00ff00',    # Optional
        ValidID        => 1,
        UserID         => 1,
    );

=cut

sub PriorityUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Name (qw(PriorityID Name ValidID UserID)) {
        if ( !$Param{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( !$Param{Color} ) {
        $Param{Color} = '';
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Do(
        SQL => 'UPDATE ticket_priority SET name = ?, valid_id = ?, color = ?, '
            . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Color}, \$Param{UserID},
            \$Param{PriorityID},
        ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=head2 PriorityLookup()

returns the id or the name of a priority

    my $PriorityID = $PriorityObject->PriorityLookup(
        Priority => '3 normal',
    );

    my $Priority = $PriorityObject->PriorityLookup(
        PriorityID => 1,
    );

=cut

sub PriorityLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Priority} && !$Param{PriorityID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Priority or PriorityID!'
        );
        return;
    }

    # get (already cached) priority list
    my %PriorityList = $Self->PriorityList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{PriorityID} ) {
        $Key        = 'PriorityID';
        $Value      = $Param{PriorityID};
        $ReturnData = $PriorityList{ $Param{PriorityID} };
    }
    else {
        $Key   = 'Priority';
        $Value = $Param{Priority};
        my %PriorityListReverse = reverse %PriorityList;
        $ReturnData = $PriorityListReverse{ $Param{Priority} };
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No $Key for $Value found!",
        );
        return;
    }

    return $ReturnData;
}

sub PriorityColor {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Priority} && !$Param{PriorityID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Priority or PriorityID!'
        );
        return;
    }

    for my $Name (qw(UserID)) {
        if ( !$Param{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( $Param{Priority} ) {
        $Param{PriorityID} = $Self->PriorityLookup(
            Priority => $Param{Priority}
        );

        if ( !$Param{PriorityID} ) {
            return;
        }
    }

    my %Priority = $Self->PriorityGet(
        PriorityID => $Param{PriorityID},
        UserID     => $Param{UserID},
    );

    if ( %Priority ) {
        return $Priority{Color};
    }

    return;
}

sub PriorityColorList {
    my ( $Self, %Param ) = @_;

    if ( !defined $Param{Valid} ) {
        $Param{Valid} = 1;
    }

    my $CacheKey = 'PriorityColorList::' . ($Param{Valid} ? 'Valid' : 'All');

    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = 'SELECT id, color FROM ticket_priority ';
    if ( $Param{Valid} ) {
        $SQL .= "WHERE valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    return if !$DBObject->Prepare( SQL => $SQL );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
