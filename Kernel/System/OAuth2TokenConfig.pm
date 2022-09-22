# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::OAuth2TokenConfig;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Valid',
    'Kernel::System::Cache',
);

=head1 NAME

Kernel::System::OAuth2TokenConfig - manage OAuth2 token configurations

=head1 DESCRIPTION

Functions to manage OAuth2 token configurations

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $OAuth2TokenConfigObject = $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'OAuth2TokenConfig';
    $Self->{CacheTTL}  = 60 * 60 * 8;

    $Self->{DBFields} = {
        'Name'       => 'name',
        'Config'     => 'config',
        'ValidID'    => 'valid_id',
        'CreateTime' => 'create_time',
        'CreateBy'   => 'create_by',
        'ChangeTime' => 'change_time',
        'ChangeBy'   => 'change_by',
    };

    return $Self;
}

=head2 ConfigGet()

# ConfigID or Name

=cut

sub ConfigGet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    if ( !$Param{ConfigID} && !$Param{Name} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need ConfigID or Name!"
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( !$Param{ConfigID} ) {
        return if !$DBObject->Prepare(
            SQL  => 'SELECT id FROM oauth2_token_config WHERE name = ?',
            Bind => [ \$Param{Name} ],
        );

        if ( my @Data = $DBObject->FetchrowArray() ) {
            $Param{ConfigID} = $Data[0];
        }
        else {
            return;
        }
    }

    my $CacheKey = join '::', 'OAuth2TokenConfig', 'Get', $Param{ConfigID};

    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return %{$Cache} if $Cache;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # FIXME: Since we're now retrieving the ID, this can probably be replaced
    # with just selecting by ID
    my $WhereSQL  = 'WHERE ' . ($Param{ConfigID} ? 'id' : 'name') . ' = ?';
    my @WhereBind = ( $Param{ConfigID} ? \$Param{ConfigID} : \$Param{Name} );

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, config, valid_id, create_time, create_by, ' .
            'change_time, change_by ' .
            'FROM oauth2_token_config ' .
            $WhereSQL,
        Bind => [ @WhereBind ],
    );

    my %Data;
    if ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ConfigID   => $Data[0],
            Name       => $Data[1],
            Config     => $JSONObject->Decode(Data => $Data[2]),
            ValidID    => $Data[3],
            CreateTime => $Data[4],
            CreateBy   => $Data[5],
            ChangeTime => $Data[6],
            ChangeBy   => $Data[7],
        );
    }

    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=head2 ConfigGetList()

Returns a list of all OAuth2 token configurations.

    my @Configurations = $OAuth2TokenConfigObject->ConfigGetList(
        Scope  => 'MailAccount',    # optional, defaults to 'MailAccount'
        Used   => 1,                # return only configurations being in use
                                    # (optional, defaults to 0)
        UserID => 1,
    );

Returns:

    @Configurations = (
        {
            ConfigID => 1,
            Scope    => 'MailAccount',
            ScopeID  => '1',
            Name     => 'Google Mail Token Configuration',
            Config   => {
                ClientID      => 2,
                Scope         => 'https://mail.google.com/',
                ClientSecret  => 3,
                TemplateName  => 'Google Mail'
                Notifications => {
                    NotifyOnExpiredRefreshToken => 1,
                    NotifyOnExpiredToken        => 1,
                },
            },
            ValidID    => 1,
            CreateTime => 2022-01-01 12:34:56,
            CreateBy   => 1,
            ChangeTime => 2022-01-01 12:34:56,
            ChangeBy   => 1,
        },
        {
            # ...
        },
        # ...
    )

=cut

sub ConfigGetList {
    my ( $Self, %Param ) = @_;

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    $Param{Scope} = 'MailAccount' if !$Param{Scope};
    $Param{Used}  = 0 if !exists $Param{Used};

    my $CacheKey = join '::', 'OAuth2TokenConfig', 'GetList', $Param{Scope},
        $Param{Used}, $Param{Valid};

    # Use cached value if no filtering is in use
    if ( ! exists $Param{Filter} ) {
        my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );

        return @{$Cache} if $Cache;
    }

    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    my $SQLWhere = '';
    my @SQLWhereParts;
    my @SQLWhereBind;

    if ( $Param{Valid} ) {
        my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

        my $ValidIDs = join ', ', $ValidObject->ValidIDsGet();

        push @SQLWhereParts, "valid_id IN ($ValidIDs)";
    }

    if ( $Param{Filter} ) {
        FILTER_FIELD:
        for my $Name (keys %{$Param{Filter}}) {
            my $FieldName = $Self->{DBFields}->{$Name};

            next FILTER_FIELD if !$FieldName;

            my $FieldValue = $Param{Filter}->{$Name};

            if (IsArrayRefWithData($FieldValue)) {
                my @FieldValues = map {
                    "'" . $DBObject->Quote($_) . "'"
                } @$FieldValue;

                push @SQLWhereParts,
                    "$FieldName IN (" . join(', ', @FieldValues) . ')';
            }
            elsif (defined $FieldValue) {
                push @SQLWhereParts, "$FieldName = ?";
                push @SQLWhereBind, \$Param{Filter}->{$Name};
            }
            else {
                push @SQLWhereParts, "$FieldName IS NULL";
            }
        }
    }

    if ( @SQLWhereParts ) {
        $SQLWhere = 'WHERE ' . join(' AND ', @SQLWhereParts) . ' ';
    }

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, config, valid_id, create_time, create_by, ' .
            'change_time, change_by ' .
            'FROM oauth2_token_config ' .
            $SQLWhere .
            'ORDER BY name ASC',
        Bind => [ @SQLWhereBind ],
    );

    my @Configurations;
    
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push @Configurations, {
            ConfigID   => $Data[0],
            Name       => $Data[1],
            Scope      => undef,
            ScopeID    => undef,
            Config     => $JSONObject->Decode(Data => $Data[2]),
            ValidID    => $Data[3],
            CreateTime => $Data[4],
            CreateBy   => $Data[5],
            ChangeTime => $Data[6],
            ChangeBy   => $Data[7],
        };
    }

    my %UsedConfigIDs;

    if ( $Param{Scope} eq 'MailAccount' ) {
        my $MailAccountObject = $Kernel::OM->Get('Kernel::System::MailAccount');
        my @MailAccounts      = $MailAccountObject->MailAccountGetAll();

        ACCOUNT:
        for my $MailAccount (@MailAccounts) {
            # Skip this account if it doesn't use OAuth2 token configuration
            next ACCOUNT if !$MailAccount->{OAuth2TokenConfigID};

            $UsedConfigIDs{MailAccount}->{$MailAccount->{ID}} =
                $MailAccount->{OAuth2TokenConfigID};
        }
    }

    # Set scope and scope object ID for configurations which are in use
    # (e.g.: Scope => 'MailAccount', ScopeID => '(ID of MailAccount object)')
    for my $Scope ( keys %UsedConfigIDs ) {
        for my $ScopeID ( keys %{ $UsedConfigIDs{$Scope} } ) {
            my $ConfigID = $UsedConfigIDs{$Scope}->{$ScopeID};
            my ($Config) = grep { $_->{ConfigID} eq $ConfigID } @Configurations;

            $Config->{Scope}   = $Scope;
            $Config->{ScopeID} = $ScopeID;
        }
    }

    if ( $Param{Used} ) {
        # Filter out unused configurations
        @Configurations = grep { defined $_->{Scope} } @Configurations;
    }

    # Save cache if no filtering is in use
    if ( ! $Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => \@Configurations,
        );
    }

    return @Configurations;
}

=head2 ConfigAdd()

=cut

sub ConfigAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(Name Config ValidID)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $JSONObject   = $Kernel::OM->Get('Kernel::System::JSON');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    my $ConfigJSON = $JSONObject->Encode(
        Data => $Param{Config},
    );
    $EncodeObject->EncodeInput(\$ConfigJSON);

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Do(
        SQL => 'INSERT INTO oauth2_token_config ' .
            '(name, config, valid_id, create_time, create_by, change_time, ' .
            'change_by) ' .
            'VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$ConfigJSON, \$Param{ValidID}, \$Param{UserID},
            \$Param{UserID},
        ],
    );

    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM oauth2_token_config WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    my $ConfigID;

    if ( my @Row = $DBObject->FetchrowArray() ) {
        $ConfigID = $Row[0];
    }

    return $ConfigID;
}

=head2 ConfigUpdate()

=cut

sub ConfigUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(ConfigID Name Config ValidID)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $JSONObject   = $Kernel::OM->Get('Kernel::System::JSON');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    my $ConfigJSON = $JSONObject->Encode(
        Data => $Param{Config},
    );
    $EncodeObject->EncodeInput(\$ConfigJSON);

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Do(
        SQL => 'UPDATE oauth2_token_config SET ' .
            'name = ?, config = ?, valid_id = ?, ' .
            'change_time = current_timestamp, change_by = ? ' .
            'WHERE id = ?',
        Bind => [
            \$Param{Name}, \$ConfigJSON, \$Param{ValidID}, \$Param{UserID},
            \$Param{ConfigID},
        ],
    );

    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=head2 ConfigDelete()

=cut

sub ConfigDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(ConfigID)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Do(
        SQL  => 'DELETE FROM oauth2_token WHERE config_id = ?',
        Bind => [ \$Param{ConfigID} ],
    );

    return if !$DBObject->Do(
        SQL  => 'DELETE FROM oauth2_token_config WHERE id = ?',
        Bind => [ \$Param{ConfigID} ],
    );

    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=head2 ConfigImport()

Content
Overwrite

=cut

sub ConfigImport {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(Content)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    my $Data = $YAMLObject->Load(
        Data => $Param{Content},
    );

    return if !$Data;

    my @Configurations = @$Data;

    for my $Config (@Configurations) {
        my %ExistingConfig = $Self->ConfigGet(
            Name   => $Config->{Name},
            UserID => 1,
        );

        if (%ExistingConfig && $Param{Overwrite}) {
            my $Updated = $Self->ConfigUpdate(
                %{ $Param{Data} },
                %{ $Config },
                ConfigID => $ExistingConfig{ConfigID},
                UserID   => 1,
            );
        }
        elsif (!%ExistingConfig) {
            my $ConfigID = $Self->ConfigAdd(
                %{ $Param{Data} },
                %{ $Config },
                CreateBy => 1,
                ChangeBy => 1,
                UserID   => 1,
            );
        }
    }

    return 1;
}

=head2 ConfigExport()

# Filter

=cut

sub ConfigExport {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my @Configurations = $Self->ConfigGetList(
        Filter => $Param{Filter},
        UserID => 1,
    );

    for my $Config (@Configurations) {
        # We don't want to export scope information
        delete $Config->{Scope};
        delete $Config->{ScopeID};
    }

    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    my $Result = $YAMLObject->Dump(
        Data => \@Configurations
    );

    return $Result;
}

1;
