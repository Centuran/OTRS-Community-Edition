# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AdminOAuth2TokenConfig;

use strict;
use warnings;

use File::Basename;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{ConfigTemplatesBasePath} = $ConfigObject->Get('Home') .
        '/scripts/OAuth2TokenConfig/TokenConfigTemplates';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Output;

    if ( $Self->{Subaction} eq 'AddConfig' ) {
        $Output = $Self->_AddConfig(%Param);
    }
    elsif ( $Self->{Subaction} eq 'EditConfig' ) {
        $Output = $Self->_EditConfig(%Param);
    }
    elsif ( $Self->{Subaction} eq 'SaveConfig' ) {
        $Output = $Self->_SaveConfig(%Param);
    }
    elsif ( $Self->{Subaction} eq 'RequestTokenByAuthorizationCode' ) {
        $Output = $Self->_RequestTokenByAuthorizationCode(%Param);
    }
    else {
        $Output = $Self->_Overview(%Param);
    }

    return $Output;
}

sub _WrapOutput {
    my ( $Self, $Output ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    return
        $LayoutObject->Header() .
        $LayoutObject->NavigationBar() .
        $Output .
        $LayoutObject->Footer();
}

sub _AddConfig {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');
    
    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my $TemplateFilename = $ParamObject->GetParam(
        Param => 'TemplateFilename',
    );

    if ( !$TemplateFilename ) {
        return $LayoutObject->ErrorScreen(
            Message => 'Missing parameter TemplateFilename.',
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my %ConfigTemplates = $Self->_GetConfigTemplates(
        Filter => "$TemplateFilename.yml"
    );
    my $Config = $ConfigTemplates{$TemplateFilename};

    if ( !IsHashRefWithData($Config) ) {
        return $LayoutObject->ErrorScreen(
            Message => 'Failed to read OAuth2 token configuration template ' .
                "$TemplateFilename.yml.",
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my %ValidIDs = $ValidObject->ValidList();
    
    my $ValidIDSelection = $LayoutObject->BuildSelection(
        Data       => \%ValidIDs,
        Name       => 'ValidID',
        SelectedID => $ValidObject->ValidLookup(Valid => 'valid'),
        Class      => 'Modernize Validate_Required',
    );

    return $Self->_WrapOutput($LayoutObject->Output(
        TemplateFile => 'AdminOAuth2TokenConfig/Edit',
        Data         => {
            TemplateFilename            => $TemplateFilename,
            TemplateName                => $Config->{Name},
            Name                        => '',
            ClientID                    => $Config->{Config}{ClientID},
            ClientSecret                => $Config->{Config}{ClientSecret},
            NotifyOnExpiredToken        => $Config->{Config}{Notifications}{NotifyOnExpiredToken},
            NotifyOnExpiredRefreshToken => $Config->{Config}{Notifications}{NotifyOnExpiredRefreshToken},
            ValidIDSelection            => $ValidIDSelection,
        },
    ));
}

sub _EditConfig {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');
    
    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

    my $ConfigID = $ParamObject->GetParam(Param => 'ConfigID');
    
    if ( !$ConfigID ) {
        return $LayoutObject->ErrorScreen(
            Message => 'Missing parameter ConfigID.',
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my %Config = $OAuth2TokenConfigObject->ConfigGet(
        ConfigID => $ConfigID,
        UserID   => $Self->{UserID},
    );

    if ( !%Config ) {
        return $LayoutObject->ErrorScreen(
            Message => "OAuth2 token configuration with ID $ConfigID " .
                'could not be found.',
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my %ValidIDs = $ValidObject->ValidList();
    
    my $ValidIDSelection = $LayoutObject->BuildSelection(
        Data       => \%ValidIDs,
        Name       => 'ValidID',
        SelectedID => $Config{ValidID},
        Class      => 'Modernize Validate_Required',
    );

    return $Self->_WrapOutput($LayoutObject->Output(
        TemplateFile => 'AdminOAuth2TokenConfig/Edit',
        Data         => {
            ConfigID                    => $ConfigID,
            TemplateName                => $Config{Config}->{TemplateName},
            Name                        => $Config{Name},
            ClientID                    => $Config{Config}->{ClientID},
            ClientSecret                => $Config{Config}->{ClientSecret},
            NotifyOnExpiredToken        => $Config{Config}->{Notifications}{NotifyOnExpiredToken},
            NotifyOnExpiredRefreshToken => $Config{Config}->{Notifications}{NotifyOnExpiredRefreshToken},
            ValidIDSelection            => $ValidIDSelection,
        },
    ));
}

sub _SaveConfig {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');
    
    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');
    
    my %GetParam = map {
        $_ => $ParamObject->GetParam(Param => $_)
    } qw(
        ConfigID TemplateFilename TemplateName Name ClientID
        ClientSecret ValidID NotifyOnExpiredToken NotifyOnExpiredRefreshToken
        ContinueAfterSave
    );

    my %Errors =
        map { $_ . 'Invalid' => 'ServerError' }
            grep { !defined $GetParam{$_} || !length $GetParam{$_} }
                qw( Name ClientID ClientSecret ValidID );
    
    if ( exists $Errors{NameInvalid} ) {
        $LayoutObject->Block(
            Name => 'NameRequiredServerError',
            Data => {},
        );
    }

    if ( defined $GetParam{Name} && length $GetParam{Name} ) {
        # Check for name conflict
        my %Config = $OAuth2TokenConfigObject->ConfigGet(
            Name   => $GetParam{Name},
            UserID => $Self->{UserID},
        );

        if ( %Config ) {
            if (
                !$GetParam{ConfigID}
                || $GetParam{ConfigID} != $Config{ConfigID}
                )
            {
                $Errors{NameInvalid} = 'ServerError';
                $LayoutObject->Block(
                    Name => 'NameExistsServerError',
                    Data => {},
                );
            }
        }
    }

    if (%Errors) {
        # Show edit form again
        my %ValidIDs = $ValidObject->ValidList();
        
        my $ValidIDSelection = $LayoutObject->BuildSelection(
            Data       => \%ValidIDs,
            Name       => 'ValidID',
            SelectedID => $GetParam{ValidID},
            Class      => 'Modernize Validate_Required',
        );

        return $Self->_WrapOutput($LayoutObject->Output(
            TemplateFile => 'AdminOAuth2TokenConfig/Edit',
            Data         => {
                ConfigID                    => $GetParam{ConfigID},
                TemplateFilename            => $GetParam{TemplateFilename},
                TemplateName                => $GetParam{TemplateName},
                Name                        => $GetParam{Name},
                ClientID                    => $GetParam{ClientID},
                ClientSecret                => $GetParam{ClientSecret},
                NotifyOnExpiredToken        => $GetParam{NotifyOnExpiredToken},
                NotifyOnExpiredRefreshToken => $GetParam{NotifyOnExpiredRefreshToken},
                ValidIDSelection            => $ValidIDSelection,
                %Errors,
            },
        ));
    }

    if ( $GetParam{ConfigID} ) {
        # Update existing configuration
        my %Config = $OAuth2TokenConfigObject->ConfigGet(
            ConfigID => $GetParam{ConfigID},
            UserID   => $Self->{UserID},
        );

        if ( !%Config ) {
            return $LayoutObject->ErrorScreen(
                Message => 'OAuth2 token configuration with ID ' .
                    "$GetParam{ConfigID} could not be found.",
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        $Config{Name}    = $GetParam{Name};
        $Config{ValidID} = $GetParam{ValidID};
        
        $Config{Config}->{ClientID}     = $GetParam{ClientID};
        $Config{Config}->{ClientSecret} = $GetParam{ClientSecret};

        $Config{Config}->{Notifications}{NotifyOnExpiredToken} =
            $GetParam{NotifyOnExpiredToken} ? 1 : 0;
        $Config{Config}->{Notifications}{NotifyOnExpiredRefreshToken} =
            $GetParam{NotifyOnExpiredRefreshToken} ? 1 : 0;

        my $Updated = $OAuth2TokenConfigObject->ConfigUpdate(
            %Config,
            UserID => $Self->{UserID},
        );

        if ( !$Updated ) {
            return $LayoutObject->ErrorScreen(
                Message => 'Failed to update OAuth2 token configuration with ' .
                    "ID $GetParam{ConfigID}.",
                Comment => Translatable('Please contact the administrator.'),
            );
        }
    }
    elsif ( $GetParam{TemplateFilename} ) {
        my $TemplateFilename = $GetParam{TemplateFilename};

        my %ConfigTemplates = $Self->_GetConfigTemplates(
            Filter => "$TemplateFilename.yml"
        );
        my $Config = $ConfigTemplates{$TemplateFilename};

        if ( !IsHashRefWithData($Config) ) {
            return $LayoutObject->ErrorScreen(
                Message => 'Failed to read OAuth2 token configuration ' .
                    "template $TemplateFilename.yml.",
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        my %Config = %$Config;

        $Config{Name}    = $GetParam{Name};
        $Config{ValidID} = $GetParam{ValidID};
        
        $Config{Config}->{ClientID}     = $GetParam{ClientID};
        $Config{Config}->{ClientSecret} = $GetParam{ClientSecret};

        $Config{Config}->{Notifications}{NotifyOnExpiredToken} =
            $GetParam{NotifyOnExpiredToken} ? 1 : 0;
        $Config{Config}->{Notifications}{NotifyOnExpiredRefreshToken} =
            $GetParam{NotifyOnExpiredRefreshToken} ? 1 : 0;

        my $Added = $OAuth2TokenConfigObject->ConfigAdd(
            %Config,
            UserID => $Self->{UserID},
        );

        if ( !$Added ) {
            return $LayoutObject->ErrorScreen(
                Message => 'Failed to add OAuth2 token configuration with ' .
                    "name $GetParam{Name}.",
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        %Config = $OAuth2TokenConfigObject->ConfigGet(
            Name   => $GetParam{Name},
            UserID => $Self->{UserID},
        );

        if ( !%Config ) {
            return $LayoutObject->ErrorScreen(
                Message => 'Failed to get OAuth2 token configuration with ' .
                    "name $GetParam{Name}.",
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        $GetParam{ConfigID} = $Config{ConfigID};
    }
    else {
        return $LayoutObject->ErrorScreen(
            Message => 'Missing parameter ConfigID or TemplateFilename.',
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    if ( $GetParam{ContinueAfterSave} ) {
        return $LayoutObject->Redirect(
            OP => "Action=$Self->{Action};Subaction=EditConfig;" .
                "ConfigID=$GetParam{ConfigID}",
        );
    }

    return $LayoutObject->Redirect(
        OP => "Action=$Self->{Action}",
    );
}

sub _RequestTokenByAuthorizationCode {
    my ( $Self, %Param ) = @_;

    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $OAuth2TokenObject = $Kernel::OM->Get('Kernel::System::OAuth2Token');
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');

    my %Parameters = $OAuth2TokenObject->GetAuthorizationCodeParameters(
        ParamObject => $ParamObject,
        UserID      => $Self->{UserID},
    );
    
    if ( !%Parameters ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Failed to get authorization code ' .
                'parameters.'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my %Token = $OAuth2TokenObject->RequestTokenByAuthorizationCode(
        ConfigID          => $Parameters{ConfigID},
        AuthorizationCode => $Parameters{AuthorizationCode},
        UserID            => $Self->{UserID},
    );
    
    if ( !%Token ) {
        return $LayoutObject->ErrorScreen(
            Message => 'Failed to request token for OAuth2 token ' .
                "configuration with ID $Parameters{ConfigID} and " .
                "authorization code '$Parameters{AuthorizationCode}'.",
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my $ErrorMessage = $OAuth2TokenObject->GetTokenErrorMessage(
        ConfigID => $Parameters{ConfigID},
        UserID   => $Self->{UserID},
    );

    if ( defined $ErrorMessage && length $ErrorMessage ) {
        return $LayoutObject->ErrorScreen(
            Message => 'Failed to request token for OAuth2 token ' .
                "configuration with ID $Parameters{ConfigID} and " . 
                "authorization code '$Parameters{AuthorizationCode}': " .
                "$ErrorMessage.",
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    return $LayoutObject->PopupClose(
        Reload => 1,
    );    
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $OAuth2TokenObject = $Kernel::OM->Get('Kernel::System::OAuth2Token');
    my $ValidObject       = $Kernel::OM->Get('Kernel::System::Valid');

    my $OAuth2TokenConfigObject =
        $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');
    
    my @Configurations = $OAuth2TokenConfigObject->ConfigGetList(
        UserID => $Self->{UserID},
    );

    my %TokenInfo;

    for my $Config (@Configurations) {
        # Set the "used" flag if there is a scope object for this configuration
        $Config->{Used} = defined $Config->{ScopeID};

        my %Token = $OAuth2TokenObject->TokenGet(
            ConfigID => $Config->{ConfigID},
            UserID   => $Self->{UserID},
        );

        my $TokenExpired = $OAuth2TokenObject->IsTokenExpired(
            ConfigID => $Config->{ConfigID},
            UserID   => $Self->{UserID},
        );

        my $RefreshTokenExpired = $OAuth2TokenObject->IsRefreshTokenExpired(
            ConfigID => $Config->{ConfigID},
            UserID   => $Self->{UserID},
        );

        my $ErrorMessage = $OAuth2TokenObject->GetTokenErrorMessage(
            ConfigID => $Config->{ConfigID},
            UserID   => $Self->{UserID},
        );

        my $AuthCodeRequestURL =
            $OAuth2TokenObject->GetAuthorizationCodeRequestURL(
                ConfigID => $Config->{ConfigID},
                UserID   => $Self->{UserID},
            );
        
        my $RefreshTokenRequestConfigured =
            IsHashRefWithData($Config->{Config}{Requests}{TokenByRefreshToken});
        
        $TokenInfo{$Config->{ConfigID}} = {
            TokenPresent                  => $Token{Token} ? 1 : undef,
            TokenExpirationDate           => $Token{TokenExpirationDate},
            TokenExpired                  => $TokenExpired,
            RefreshTokenPresent           => $Token{RefreshToken} ? 1 : undef,
            RefreshTokenExpirationDate    => $Token{RefreshTokenExpirationDate},
            RefreshTokenExpired           => $RefreshTokenExpired,
            AuthCodeRequestURL            => $AuthCodeRequestURL,
            LastTokenRequestFailed        => defined $ErrorMessage,
            RefreshTokenRequestConfigured => $RefreshTokenRequestConfigured,
        };
    }

    my $ConfigTemplateSelection = $Self->_ConfigTemplateSelection();

    my %ValidIDs = $ValidObject->ValidList();

    return $Self->_WrapOutput($LayoutObject->Output(
        TemplateFile => 'AdminOAuth2TokenConfig/Overview',
        Data         => {
            Configurations          => \@Configurations,
            TokenInfo               => \%TokenInfo,
            ValidIDs                => \%ValidIDs,
            ConfigTemplateSelection => $ConfigTemplateSelection,
        },
    ));
}

sub _ConfigTemplateSelection {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %ConfigTemplates = $Self->_GetConfigTemplates();

    my %ConfigTemplateSelection = map {
        $_ => $ConfigTemplates{$_}->{Name}
    } keys %ConfigTemplates;

    return if !%ConfigTemplateSelection;

    my $Selection = $LayoutObject->BuildSelection(
        Data         => \%ConfigTemplateSelection,
        Name         => 'TemplateFilename',
        PossibleNone => 1,
        Class        => 'Modernize',
    );

    return $Selection;    
}

sub _GetConfigTemplates {
    my ( $Self, %Param ) = @_;

    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    my @TemplateFiles = $MainObject->DirectoryRead(
        Directory => $Self->{ConfigTemplatesBasePath},
        Filter    => $Param{Filter} // '*.yml',
        Silent    => 1,
    );

    my %ConfigTemplates;

    return %ConfigTemplates if !@TemplateFiles;

    FILE:
    for my $File (@TemplateFiles) {
        my $Content = $MainObject->FileRead(
            Location => $File,
            Result   => 'SCALAR',
        );
        
        next FILE if !$Content;

        my $ConfigData = $YAMLObject->Load(
            Data => $$Content,
        );
        
        if ( IsArrayRefWithData($ConfigData) ) {
            # Grab the first configuration with a set "Name"
            ($ConfigData) = grep { length $_->{Name} } @$ConfigData;
        }

        next FILE if !IsHashRefWithData($ConfigData);

        my $Filename = fileparse($File, '.yml');
        $ConfigTemplates{$Filename} = $ConfigData;
    }

    return %ConfigTemplates;
}

1;
