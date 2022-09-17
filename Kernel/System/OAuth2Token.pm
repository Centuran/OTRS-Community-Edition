# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::OAuth2Token;

use strict;
use utf8;
use warnings;

use MIME::Base64;
use URI::Escape;

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::WebUserAgent;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Valid',
    'Kernel::System::Cache',
);

=head1 NAME

Kernel::System::OAuth2Token - manage OAuth2 tokens

=head1 DESCRIPTION

Functions to manage OAuth2 tokens

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $OAuth2TokenObject = $Kernel::OM->Get('Kernel::System::OAuth2Token');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'OAuth2Token';
    $Self->{CacheTTL}  = 60 * 60 * 8;

    $Self->{RequestTypes} = {
        AuthorizationCode        => 1,
        TokenByAuthorizationCode => 1,
        TokenByRefreshToken      => 1,
    };

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $HttpType    = $ConfigObject->Get('HttpType');
    my $Hostname    = $ConfigObject->Get('FQDN');
    my $ScriptAlias = $ConfigObject->Get('ScriptAlias') // '';
    my $BaseURL     = "$HttpType://$Hostname/$ScriptAlias";
    
    $Self->{AuthCodeRequestRedirectURL} =
        $BaseURL . 'get-oauth2-token-by-authorization-code.pl';

    return $Self;
}

=head2 TokenGet()

Returns a hash of OAuth2 token data.

    my %Token = $OAuth2TokenObject->TokenGet(
        TokenID => 123,
        UserID  => 1,
    );

Returns:

    %Token = (
    )

=cut

sub TokenGet() {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    if ( !$Param{TokenID} && !$Param{ConfigID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need TokenID or ConfigID!"
        );
        return;
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( !$Param{TokenID} ) {
        return if !$DBObject->Prepare(
            SQL  => 'SELECT id FROM oauth2_token WHERE config_id = ?',
            Bind => [ \$Param{ConfigID} ],
        );

        if ( my @Data = $DBObject->FetchrowArray() ) {
            $Param{TokenID} = $Data[0];
        }
        else {
            return;
        }
    }

    my $CacheKey = join '::', 'OAuth2Token', 'Get', $Param{TokenID};

    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return %{$Cache} if $Cache;

    return if !$DBObject->Prepare(
        SQL => 'SELECT config_id, authorization_code, token, ' .
            'token_expiration_date, refresh_token, ' .
            'refresh_token_expiration_date, error_message, ' .
            'error_description, error_code, create_time, create_by, ' .
            'change_time, change_by ' .
            'FROM oauth2_token WHERE id = ?',
        Bind => [ \$Param{TokenID} ],
    );

    my %Data;
    if ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            TokenID                    => $Param{TokenID},
            ConfigID                   => $Data[0],
            AuthorizationCode          => $Data[1],
            Token                      => $Data[2],
            TokenExpirationDate        => $Data[3],
            RefreshToken               => $Data[4],
            RefreshTokenExpirationDate => $Data[5],
            ErrorMessage               => $Data[6],
            ErrorDescription           => $Data[7],
            ErrorCode                  => $Data[8],
            CreateTime                 => $Data[9],
            CreateBy                   => $Data[10],
            ChangeTime                 => $Data[11],
            ChangeBy                   => $Data[12],
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

=head2 TokenGetList()

=cut

sub TokenGetList() {
    my ( $Self, %Param ) = @_;

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    my $CacheKey = join '::', 'OAuth2Token', 'GetList';
    
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return @{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, config_id, authorization_code, token, ' .
            'token_expiration_date, refresh_token, ' .
            'refresh_token_expiration_date, error_message, ' .
            'error_description, error_code, create_time, create_by, ' .
            'change_time, change_by ' .
            'FROM oauth2_token ' .
            'ORDER BY token_expiration_date ASC',
    );

    my @Tokens;
    
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push @Tokens, {
            TokenID                    => $Data[0],
            ConfigID                   => $Data[1],
            AuthorizationCode          => $Data[2],
            Token                      => $Data[3],
            TokenExpirationDate        => $Data[4],
            RefreshToken               => $Data[5],
            RefreshTokenExpirationDate => $Data[6],
            ErrorMessage               => $Data[7],
            ErrorDescription           => $Data[8],
            ErrorCode                  => $Data[9],
            CreateTime                 => $Data[10],
            CreateBy                   => $Data[11],
            ChangeTime                 => $Data[12],
            ChangeBy                   => $Data[13],
        };
    }

    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Tokens,
    );

    return @Tokens;
}

=head2 TokenAdd()

=cut

sub TokenAdd() {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $LogObject->Log(
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
        SQL => 'INSERT INTO oauth2_token ' .
            '(config_id, authorization_code, token, token_expiration_date, ' .
            'refresh_token, refresh_token_expiration_date, error_message, ' .
            'error_description, error_code, create_time, create_by, ' .
            'change_time, change_by) ' .
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, ' .
            'current_timestamp, ?)',
        Bind => [
            \$Param{ConfigID}, \$Param{AuthorizationCode}, \$Param{Token},
            \$Param{TokenExpirationDate}, \$Param{RefreshToken},
            \$Param{RefreshTokenExpirationDate}, \$Param{ErrorMessage},
            \$Param{ErrorDescription}, \$Param{ErrorCode}, \$Param{UserID},
            \$Param{UserID},
        ],
    );

    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM oauth2_token WHERE config_id = ?',
        Bind => [ \$Param{ConfigID} ],
    );

    my $TokenID;

    if ( my @Row = $DBObject->FetchrowArray() ) {
        $TokenID = $Row[0];
    }

    return $TokenID;
}

=head2 TokenUpdate()

=cut

sub TokenUpdate() {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    # for my $Name (qw(TokenID ConfigID AuthorizationCode Token
    #     TokenExpirationDate RefreshToken RefreshTokenExpirationDate ErrorMessage
    #     ErrorDescription ErrorCode))
    for my $Name (qw(TokenID ConfigID)) {
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
        SQL => 'UPDATE oauth2_token SET ' .
            'config_id = ?, authorization_code = ?, token = ?, ' .
            'token_expiration_date = ?, refresh_token = ?, ' .
            'refresh_token_expiration_date = ?, error_message = ?, ' .
            'error_description = ?, error_code = ?, ' .
            'change_time = current_timestamp, change_by = ? ' .
            'WHERE id = ?',
        Bind => [
            \$Param{ConfigID}, \$Param{AuthorizationCode}, \$Param{Token},
            \$Param{TokenExpirationDate}, \$Param{RefreshToken},
            \$Param{RefreshTokenExpirationDate}, \$Param{ErrorMessage},
            \$Param{ErrorDescription}, \$Param{ErrorCode}, \$Param{UserID},
            \$Param{TokenID},
        ],
    );

    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=head2 TokenDelete()

=cut

sub TokenDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(TokenID)) {
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
        SQL  => 'DELETE FROM oauth2_token WHERE id = ?',
        Bind => [ \$Param{TokenID} ],
    );

    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

#=head2 TokenSearch()
#
#=cut

sub IsTokenExpired {
    my ( $Self, %Param ) = @_;

    return $Self->_IsExpired('Token', %Param);
}

sub IsRefreshTokenExpired {
    my ( $Self, %Param ) = @_;

    return $Self->_IsExpired('RefreshToken', %Param);
}

sub _IsExpired {
    my ( $Self, $Type, %Param ) = @_;

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

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my %Token = $Self->_GetOrAdd(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get a token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    return 1 if !$Token{$Type};

    return if !defined $Token{$Type . 'ExpirationDate'};

    my $CurrentDateTime    = $Kernel::OM->Create('Kernel::System::DateTime');
    my $ExpirationDateTime = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            String => $Token{$Type . 'ExpirationDate'},
        },
    );

    return 1 if $CurrentDateTime > $ExpirationDateTime;

    return;

}

sub GetAuthorizationCodeRequestURL {
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

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my $RequestConfig = $Config{Config}->{Requests}{AuthorizationCode}{Request};

    if ( !IsHashRefWithData($RequestConfig) ) {
        $LogObject->Log(
            Priority => 'error',
            Message => 'Authorization code request configuration not found ' .
                "in OAuth2 token configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    my $URL = $RequestConfig->{URL};

    my %RequestData = $Self->_AssembleRequestData(
        ConfigID => $Param{ConfigID},
        Type     => 'AuthorizationCode',
        UserID   => $Param{UserID},
    );
    return $URL if !%RequestData;

    my @QueryParams = map {
        $_ . '=' . URI::Escape::uri_escape_utf8($RequestData{$_})
    } keys %RequestData;
    
    $URL .= '?' . join '&', @QueryParams;

    return $URL;
}

sub GetAuthorizationCodeParameters {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(ParamObject)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $ParamObject = $Param{ParamObject};
    my @Params = $ParamObject->GetParamNames();

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');
    
    my $ConfigID;
    my $ResponseConfig;

    PARAM:
    for my $Param (@Params) {
        my $Value = $ParamObject->GetParam(Param => $Param);

        next PARAM if $Value !~ m/^ConfigID(\d+)$/;

        my $ParamConfigID = $1;

        my %Config = $OAuth2TokenConfigObject->ConfigGet(
            ConfigID => $ParamConfigID,
            UserID   => $Param{UserID},
        );

        next PARAM if !%Config;

        $ResponseConfig =
            $Config{Config}->{Requests}{AuthorizationCode}{Response};
        
        next PARAM if !IsHashRefWithData($ResponseConfig);
        next PARAM if !IsHashRefWithData($ResponseConfig->{ParametersMapping});

        next PARAM if !exists $ResponseConfig->{ParametersMapping}{$Param};
        next PARAM if $ResponseConfig->{ParametersMapping}{$Param} ne 'State';

        # We have found a valid configuration
        $ConfigID = $ParamConfigID;
        last PARAM;
    }

    if ( !$ConfigID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'OAuth2 token configuration not found based on ' .
                'response to authorization code request.',
        );
        return;
    }

    my %ResponseData = $Self->_AssembleResponseDataFromWebRequest(
        ParamObject => $ParamObject,
        ConfigID    => $ConfigID,
        RequestType => 'AuthorizationCode',
        UserID      => $Param{UserID},
    );

    if ( !%ResponseData ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get response data for authorization code ' .
                "request for OAuth2 token configuration with ID $ConfigID.",
        );
        return;
    }

    if ( !defined $ResponseData{AuthorizationCode} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Response data for authorization code request does ' .
                'not contain authorization code for OAuth2 token ' .
                "configuration with ID $ConfigID.",
        );
        return;
    }

    return (
        ConfigID          => $ConfigID,
        AuthorizationCode => $ResponseData{AuthorizationCode},
    );
}

sub RequestTokenByAuthorizationCode {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(ConfigID AuthorizationCode)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my %Token = $Self->_GetOrAdd(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get a token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    my $RequestType = 'TokenByAuthorizationCode';

    my $TokenUpdated = $Self->TokenUpdate(
        TokenID                    => $Token{TokenID},
        ConfigID                   => $Token{ConfigID},
        AuthorizationCode          => $Param{AuthorizationCode},
        Token                      => undef,
        TokenExpirationDate        => undef,
        RefreshToken               => undef,
        RefreshTokenExpirationDate => undef,
        Error                      => undef,
        ErrorDescription           => undef,
        ErrorCode                  => undef,
        UserID                     => $Param{UserID},
    );

    if ( !$TokenUpdated ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to update token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    my %RequestData = $Self->_AssembleRequestData(
        ConfigID    => $Param{ConfigID},
        Type        => $RequestType,
        UserID      => $Param{UserID},
    );

    # Clear authorization code
    $TokenUpdated = $Self->TokenUpdate(
        TokenID           => $Token{TokenID},
        ConfigID          => $Token{ConfigID},
        AuthorizationCode => undef,
        UserID            => $Param{UserID},
    );

    if ( !$TokenUpdated ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to update token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    my $WebUserAgent = Kernel::System::WebUserAgent->new();

    my $URL = $Config{Config}->{Requests}{$RequestType}{Request}{URL};
    my %Response = $WebUserAgent->Request(
        URL                          => $URL,
        Type                         => 'POST',
        Data                         => \%RequestData,
        ReturnResponseContentOnError => 1,
    );

    if ( !%Response || !$Response{Status} || !defined $Response{Content} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get response for token request by ' .
                'authorization code for OAuth2 token configuration with ID ' .
                "$Param{ConfigID}.",
        );
        return;
    }

    my %ResponseData = $Self->_AssembleResponseDataFromJSONString(
        ConfigID    => $Param{ConfigID},
        JSONString  => ${$Response{Content}},
        RequestType => $RequestType,
        UserID      => $Param{UserID},
    );

    if ( !%ResponseData ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to collect response data for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    $TokenUpdated = $Self->TokenUpdate(
        TokenID  => $Token{TokenID},
        ConfigID => $Token{ConfigID},
        
        %ResponseData,
        
        UserID => $Param{UserID},
    );

    if ( !$TokenUpdated ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to update token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    if ( $Response{Status} ne '200 OK' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Unsuccessful HTTP response for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    %Token = $Self->TokenGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to retrieve token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} after update with " .
                "response data for request type '$RequestType'.",
        );
        return;
    }

    return %Token;
}

sub RequestTokenByRefreshToken {
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

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my $RequestType = 'TokenByRefreshToken';

    if ( !IsHashRefWithData($Config{Config}->{Requests}{$RequestType}) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Refresh token request not configured for OAuth2 ' .
                "token configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    my %Token = $Self->_GetOrAdd(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get a token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    my $Expired = $Self->IsRefreshTokenExpired(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID}
    );

    if ( $Expired ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Refresh token expired or not present for OAuth2 ' .
                "token configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    my %RequestData = $Self->_AssembleRequestData(
        ConfigID    => $Param{ConfigID},
        RequestType => $RequestType,
        UserID      => $Param{UserID},
    );

    my $TokenUpdated = $Self->TokenUpdate(
        TokenID           => $Token{TokenID},
        AuthorizationCode => undef,
        Error             => undef,
        ErrorDescription  => undef,
        ErrorCode         => undef,
        UserID            => $Param{UserID},
    );

    if ( !$TokenUpdated ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to update token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    my $WebUserAgent = Kernel::System::WebUserAgent->new();

    my $URL = $Config{Config}->{Requests}{$RequestType}{Request}{URL};
    my %Response = $WebUserAgent->Request(
        URL                          => $URL,
        Type                         => 'POST',
        Data                         => \%RequestData,
        ReturnResponseContentOnError => 1,
    );

    if ( !%Response || !$Response{Status} || !defined $Response{Content} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get response for token request by ' .
                'authorization code for OAuth2 token configuration with ID ' .
                "$Param{ConfigID}.",
        );
        return;
    }

    my %ResponseData = $Self->_AssembleResponseDataFromJSONString(
        ConfigID    => $Param{ConfigID},
        JSONString  => ${$Response{Content}},
        RequestType => $RequestType,
        UserID      => $Param{UserID},
    );

    if ( !%ResponseData ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to collect response data for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    $TokenUpdated = $Self->TokenUpdate(
        TokenID => $Token{TokenID},
        
        %ResponseData,
        
        UserID => $Param{UserID},
    );

    if ( !$TokenUpdated ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to update token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    if ( $Response{Status} ne '200 OK' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Unsuccessful HTTP response for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} and request type " .
                "'$RequestType'.",
        );
        return;
    }

    %Token = $Self->TokenGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to retrieve token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID} after update with " .
                "response data for request type '$RequestType'.",
        );
        return;
    }

    return %Token;
}

sub GetToken {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $LogObject->Log(
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

    my $TokenExpired = $Self->IsTokenExpired(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( $TokenExpired ) {
        my $RefreshTokenExpired = $Self->IsRefreshTokenExpired(
            ConfigID => $Param{ConfigID},
            UserID   => $Param{UserID},
        );

        if ( $RefreshTokenExpired ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Refresh token expired or not present for OAuth2 ' .
                    "token configuration with ID $Param{ConfigID}.",
            );
            return;
        }

        my %Token = $Self->RequestTokenByRefreshToken(
            ConfigID => $Param{ConfigID},
            UserID   => $Param{UserID},
        );

        if ( !%Token ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Failed to request token by refresh token for ' .
                    "OAuth2 token configuration with ID $Param{ConfigID}.",
            );
            return;
        }

        return $Token{Token};
    }

    my %Token = $Self->TokenGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to retrieve token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    return $Token{Token};
}

sub GetTokenErrorMessage {
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

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my %Token = $Self->_GetOrAdd(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get a token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    my $ErrorMessage;

    if ( length $Token{ErrorMessage} ) {
        $ErrorMessage = $Token{ErrorMessage};
    }

    if ( length $Token{ErrorCode} ) {
        if ( length $ErrorMessage ) {
            $ErrorMessage .= " (error code $Token{ErrorCode})";
        }
        else {
            $ErrorMessage = "Error code $Token{ErrorCode}";
        }
    }

    if ( length $Token{ErrorDescription} ) {
        if ( length $ErrorMessage ) {
            $ErrorMessage .= ': ';
        }

        $ErrorMessage .= $Token{ErrorDescription};
    }

    return $ErrorMessage;
}

sub GetSASLAuthString {
    my ( $Self, %Param ) = @_;

    for my $Name (qw(Username OAuth2Token)) {
        if ( !defined $Param{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $AuthString = sprintf "user=%s\x01auth=Bearer %s\x01\x01",
        $Param{Username}, $Param{OAuth2Token};
    
    return encode_base64($AuthString, '');
}

sub _AssembleRequestData {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(ConfigID Type)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( !$Self->{RequestTypes}{$Param{Type}} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unknown request type '$Param{Type}'.",
        );
        return;
    }

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        # This shouldn't actually happen, because this method should only
        # be called after we have confirmed that the configuration with this ID
        # exists.
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my %Token = $Self->_GetOrAdd(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to get a token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    my $RequestConfig = $Config{Config}->{Requests}{$Param{Type}}{Request};

    if ( !IsHashRefWithData($RequestConfig) ) {
        $LogObject->Log(
            Priority => 'error',
            Message => "Configuration for request type '$Param{Type}' " .
                'not found in OAuth2 token configuration with ID ' .
                "$Param{ConfigID}.",
        );
        return;
    }

    my %RequestData = %{ $RequestConfig->{Parameters} // {} };

    my $Mapping = $RequestConfig->{AutofilledParametersMapping};

    if ( !IsHashRefWithData($Mapping) ) {
        return %RequestData;
    }

    PARAMETER:
    for my $Parameter ( keys %$Mapping ) {
        my $Attribute = $Mapping->{$Parameter};
        
        next PARAMETER if !defined $Attribute;

        my $Value = $Config{Config}->{$Attribute} // $Token{$Attribute};

        if ( !defined $Value ) {
            if ( $Attribute eq 'State' ) {
                $Value = "ConfigID$Param{ConfigID}";
            }
            elsif ( $Attribute eq 'RedirectURL' ) {
                $Value = $Self->{AuthCodeRequestRedirectURL};
            }
        }

        $Value //= '';

        $RequestData{$Parameter} = $Value;
    }

    return %RequestData;
}

sub _AssembleResponseDataFromWebRequest {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(ConfigID ParamObject RequestType)) {
        if ( !defined $Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( !$Self->{RequestTypes}{$Param{RequestType}} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unknown request type '$Param{RequestType}'.",
        );
        return;
    }

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my $ResponseConfig =
        $Config{Config}->{Requests}{$Param{RequestType}}{Response};
    
    if ( !IsHashRefWithData($ResponseConfig) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'does not contain response configuration for request type ' .
                "'$Param{RequestType}'.",
        );
        return;
    }

    my $ParamObject = $Param{ParamObject};

    my %ResponseData;

    my $Mapping = $ResponseConfig->{ParametersMapping} // undef;

    return %ResponseData if !IsHashRefWithData($Mapping);

    PARAMETER:
    for my $Parameter ( keys %$Mapping ) {
        my $Attribute = $Mapping->{$Parameter};

        next PARAMETER if !defined $Attribute;

        $ResponseData{$Attribute} = $ParamObject->GetParam(Param => $Parameter);

        if ( $Attribute =~ m/^(?:Refresh)?TokenExpirationDate$/ ) {
            # Convert number of seconds (TTL) to date/time
            my $DateTime = $Kernel::OM->Create('Kernel::System::DateTime');
            
            $DateTime->Add(Seconds => int($ResponseData{$Attribute}));

            $ResponseData{$Attribute} = $DateTime->ToString();
        }
    }

    return %ResponseData;
}

sub _AssembleResponseDataFromJSONString {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    for my $Name (qw(ConfigID JSONString RequestType)) {
        if ( !defined $Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( !$Self->{RequestTypes}{$Param{RequestType}} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unknown request type '$Param{RequestType}'.",
        );
        return;
    }

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my $ResponseConfig =
        $Config{Config}->{Requests}{$Param{RequestType}}{Response};
    
    if ( !IsHashRefWithData($ResponseConfig) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'does not contain response configuration for request type ' .
                "'$Param{RequestType}'.",
        );
        return;
    }

    my %ResponseData;

    my $Mapping = $ResponseConfig->{ParametersMapping} // undef;

    return %ResponseData if !IsHashRefWithData($Mapping);

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    
    my $JSONData = $JSONObject->Decode(
        Data => $Param{JSONString},
    );

    if ( !IsHashRefWithData($JSONData) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Incorrect JSON data for OAuth2 token configuration ' .
                "with ID $Param{ConfigID} and response for request type " .
                "'$Param{RequestType}'.",
        );
        return;
    }

    PARAMETER:
    for my $Parameter ( keys %$Mapping ) {
        my $Attribute = $Mapping->{$Parameter};

        next PARAMETER if !defined $Attribute;

        next PARAMETER if !exists $JSONData->{$Parameter};

        if ( ref $JSONData->{$Parameter} eq 'ARRAY' ) {
            $JSONData->{$Parameter} = join ', ', @{$JSONData->{$Parameter}};
        }
        elsif ( ref $JSONData->{$Parameter} eq 'HASH' ) {
            $JSONData->{$Parameter} = $JSONObject->Encode(
                Data => $JSONData->{$Parameter},
            );
        }

        $ResponseData{$Attribute} = $JSONData->{$Parameter};

        if ( $Attribute =~ m/^(?:Refresh)?TokenExpirationDate$/ ) {
            # Convert number of seconds (TTL) to date/time
            my $DateTime = $Kernel::OM->Create('Kernel::System::DateTime');
            
            $DateTime->Add(Seconds => int($ResponseData{$Attribute}));

            $ResponseData{$Attribute} = $DateTime->ToString();
        }
    }

    return %ResponseData;
}

sub _GetOrAdd {
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

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !%Config ) {
        # See comment in _AssembleRequestData
        $LogObject->Log(
            Priority => 'error',
            Message  => "OAuth2 token configuration with ID $Param{ConfigID} " .
                'not found.',
        );
        return;
    }

    my %Token = $Self->TokenGet(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );
    return %Token if %Token;

    my $TokenID = $Self->TokenAdd(
        ConfigID => $Param{ConfigID},
        UserID   => $Param{UserID},
    );

    if ( !$TokenID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Failed to create a token for OAuth2 token ' .
                "configuration with ID $Param{ConfigID}.",
        );
        return;
    }

    %Token = $Self->TokenGet(
        TokenID => $TokenID,
        UserID  => $Param{UserID},
    );

    if ( !%Token ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Failed to retrieve token with ID $TokenID.",
        );
        return;
    }

    return %Token;
}

1;
