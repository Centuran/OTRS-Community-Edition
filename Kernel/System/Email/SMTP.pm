# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Email::SMTP;

use strict;
use warnings;

use Authen::SASL qw(Perl);
use Net::SMTP;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::OAuth2Token',
    'Kernel::System::OAuth2TokenConfig',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # debug
    $Self->{Debug} = $Param{Debug} || 0;
    if ( $Self->{Debug} > 2 ) {

        # shown on STDERR
        $Self->{SMTPDebug} = 1;
    }

    ( $Self->{SMTPType} ) = ( $Type =~ m/::Email::(.*)$/i );

    $Self->{_Port}            = 25;
    $Self->{_SSLOptions}      = {};
    $Self->{_StartTLSOptions} = {};

    $Self->{FullModuleName} = __PACKAGE__;
    $Self->{ModuleName}     = __PACKAGE__ =~ s/.*:://r;

    return $Self;
}

sub Check {
    my ( $Self, %Param ) = @_;

    $Param{CommunicationLogObject}->ObjectLogStart(
        ObjectLogType => 'Connection',
    );

    my $Return = sub {
        my %LocalParam = @_;
        $Param{CommunicationLogObject}->ObjectLogStop(
            ObjectLogType => 'Connection',
            Status        => $LocalParam{Success} ? 'Successful' : 'Failed',
        );

        return %LocalParam;
    };

    my $ReturnSuccess = sub { return $Return->( @_, Success => 1, ); };
    my $ReturnError   = sub { return $Return->( @_, Success => 0, ); };

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config data
    $Self->{FQDN}     = $ConfigObject->Get('FQDN');
    $Self->{MailHost} = $ConfigObject->Get('SendmailModule::Host')
        || die "No SendmailModule::Host found in Kernel/Config.pm";
    $Self->{SMTPPort} = $ConfigObject->Get('SendmailModule::Port');
    $Self->{User}     = $ConfigObject->Get('SendmailModule::AuthUser');
    $Self->{Password} = $ConfigObject->Get('SendmailModule::AuthPassword');

    $Self->{AuthenticationMethod} =
        $ConfigObject->Get('SendmailModule::AuthenticationMethod') //
        'password';
    $Self->{OAuth2TokenConfigName} =
        $ConfigObject->Get('SendmailModule::OAuth2TokenConfigName');

    $Param{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Connection',
        Priority      => 'Debug',
        Key           => $Self->{FullModuleName},
        Value         => 'Testing connection to SMTP service (3 attempts max.).',
    );

    # 3 possible attempts to connect to the SMTP server.
    # (MS Exchange Servers have sometimes problems on port 25)
    my $SMTP;

    my $TryConnectMessage = sprintf
        "%%s: Trying to connect to '%s%s' on %s with SMTP type '%s'.",
        $Self->{MailHost},
        ( $Self->{SMTPPort} ? ':' . $Self->{SMTPPort} : '' ),
        $Self->{FQDN},
        $Self->{SMTPType};
    TRY:
    for my $Try ( 1 .. 3 ) {

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Connection',
            Priority      => 'Debug',
            Key           => $Self->{FullModuleName},
            Value         => sprintf( $TryConnectMessage, $Try, ),
        );

        # connect to mail server
        eval {
            $SMTP = $Self->_Connect(
                MailHost  => $Self->{MailHost},
                FQDN      => $Self->{FQDN},
                SMTPPort  => $Self->{SMTPPort},
                SMTPDebug => $Self->{SMTPDebug},
            );
            return 1;
        } || do {
            my $Error = $@;
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => sprintf(
                    "SMTP, connection try %s, unexpected error captured: %s",
                    $Try,
                    $Error,
                ),
            );
        };

        last TRY if $SMTP;

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Connection',
            Priority      => 'Debug',
            Key           => $Self->{FullModuleName},
            Value         => "$Try: Connection could not be established. Waiting for 0.3 seconds.",
        );

        # sleep 0,3 seconds;
        select( undef, undef, undef, 0.3 );    ## no critic
    }

    # return if no connect was possible
    if ( !$SMTP ) {

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Connection',
            Priority      => 'Error',
            Key           => $Self->{FullModuleName},
            Value         => "Could not connect to host '$Self->{MailHost}'. ErrorMessage: $!",
        );

        return $ReturnError->(
            ErrorMessage => "Can't connect to $Self->{MailHost}: $!!",
        );
    }

    # Enclose SMTP in a wrapper to handle unexpected exceptions
    $SMTP = $Self->_GetSMTPSafeWrapper(
        SMTP => $SMTP,
    );

    # Assume authentication was successful by default (for the case when SMTP
    # requires no authentication).
    my $Authenticated = 1;

    if (
        $Self->{AuthenticationMethod} eq 'password'
        && $Self->{User}
        && $Self->{Password}
        )
    {
        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Connection',
            Priority      => 'Debug',
            Key           => $Self->{FullModuleName},
            Value         => "Using SMTP authentication with user '$Self->{User}' and (hidden) password.",
        );

        $Authenticated = $SMTP->('auth', $Self->{User}, $Self->{Password});
    }
    elsif ( $Self->{AuthenticationMethod} eq 'oauth2_token' ) {
        if ( !$Self->{OAuth2TokenConfigName} ) {
            return $ReturnError->(
                ErrorMessage => 'SysConfig setting ' .
                    'SendmailModule::AuthenticationMethod is not set.',
                Code => 0,
            );
        }

        my $OAuth2TokenConfigObject =
            $Kernel::OM->Get('Kernel::System::OAuth2TokenConfig');

        my %Config = $OAuth2TokenConfigObject->ConfigGet(
            Name   => $Self->{OAuth2TokenConfigName},
            UserID => 1,
        );

        if ( !%Config ) {
            return $ReturnError->(
                ErrorMessage => 'OAuth2 token configuration ' .
                    "'$Self->{OAuth2TokenConfigName}' could not be found.",
                Code => 0,
            );
        }

        my $OAuth2TokenObject = $Kernel::OM->Get('Kernel::System::OAuth2Token');

        my $Token = $OAuth2TokenObject->GetToken(
            ConfigID => $Config{ConfigID},
            UserID   => 1,
        );

        if ( !$Token ) {
            return $ReturnError->(
                ErrorMessage => 'Failed to get OAuth2 token for ' .
                    "configuration '$Self->{OAuth2TokenConfigName}'.",
                Code => 0,
            );
        }

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Connection',
            Priority      => 'Debug',
            Key           => $Self->{FullModuleName},
            Value         => 'Using SMTP authentication with user ' .
                "'$Self->{User}' and OAuth2 token configuration " .
                "'$Self->{OAuth2TokenConfigName}'.",
        );

        my $SASLData = Authen::SASL->new(
            mechanism => 'XOAUTH2',
            callback  => {
                user         => $Self->{User},
                auth         => 'Bearer',
                access_token => $Token,
            },
        );

        $Authenticated = $SMTP->('auth', $SASLData);
    }

    if ( !$Authenticated ) {
        my $Code = $SMTP->('code');
        my $ErrorMessage = "$Code, " . $SMTP->('message');

        $SMTP->('quit');

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Connection',
            Priority      => 'Error',
            Key           => $Self->{FullModuleName},
            Value         => 'SMTP authentication failed ' .
                "(SMTP code: $Code, error message: $ErrorMessage).",
        );

        return $ReturnError->(
            ErrorMessage => 'SMTP authentication failed (error message: ' .
                "$ErrorMessage).",
            Code => $Code,
        );
    }

    return $ReturnSuccess->(
        SMTP => $SMTP,
    );
}

sub Send {
    my ( $Self, %Param ) = @_;

    $Param{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Info',
        Key           => $Self->{FullModuleName},
        Value         => 'Received message for sending, validating message contents.',
    );

    # check needed stuff
    for my $Name (qw(Header Body ToArray)) {
        if ( !$Param{$Name} ) {

            $Param{CommunicationLogObject}->ObjectLog(
                ObjectLogType => 'Message',
                Priority      => 'Error',
                Key           => $Self->{FullModuleName},
                Value         => "Need $Name!",
            );

            return $Self->_SendError(
                %Param,
                ErrorMessage => "Need $Name!",
            );
        }
    }
    if ( !$Param{From} ) {
        $Param{From} = '';
    }

    # connect to smtp server
    my %Result = $Self->Check(%Param);

    if ( !$Result{Success} ) {
        return $Self->_SendError( %Param, %Result, );
    }

    # set/get SMTP handle
    my $SMTP = $Result{SMTP};

    $Param{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Debug',
        Key           => $Self->{FullModuleName},
        Value         => "Sending envelope from (mail from: $Param{From}) to server.",
    );

    # set envelope from, return if from was not accepted by the server
    if ( !$SMTP->( 'mail', $Param{From}, ) ) {

        my $FullErrorMessage = sprintf(
            "Envelope from '%s' not accepted by the server: %s, %s!",
            $Param{From},
            $SMTP->( 'code', ),
            $SMTP->( 'message', ),
        );

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Error',
            Key           => $Self->{FullModuleName},
            Value         => $FullErrorMessage,
        );

        return $Self->_SendError(
            %Param,
            ErrorMessage => $FullErrorMessage,
            SMTP         => $SMTP,
        );
    }

    TO:
    for my $To ( @{ $Param{ToArray} } ) {

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Debug',
            Key           => $Self->{FullModuleName},
            Value         => "Sending envelope to (rcpt to: $To) to server.",
        );

        # Check if the recipient is valid
        next TO if $SMTP->( 'to', $To, );

        my $FullErrorMessage = sprintf(
            "Envelope to '%s' not accepted by the server: %s, %s!",
            $To,
            $SMTP->( 'code', ),
            $SMTP->( 'message', ),
        );

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Error',
            Key           => $Self->{FullModuleName},
            Value         => $FullErrorMessage,
        );

        return $Self->_SendError(
            %Param,
            ErrorMessage => $FullErrorMessage,
            SMTP         => $SMTP,
        );
    }

    my $ToString = join ',', @{ $Param{ToArray} };

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    # encode utf8 header strings (of course, there should only be 7 bit in there!)
    $EncodeObject->EncodeOutput( $Param{Header} );

    # encode utf8 body strings
    $EncodeObject->EncodeOutput( $Param{Body} );

    # send data
    $Param{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Debug',
        Key           => $Self->{FullModuleName},
        Value         => "Sending message data to server.",
    );

    # Send email data by chunks because when in SSL mode, each SSL
    # frame has a maximum of 16kB (Bug #12957).
    # We send always the first 4000 characters until '$Data' is empty.
    # If any error occur while sending data to the smtp server an exception
    # is thrown and '$DataSent' will be undefined.
    my $DataSent = eval {
        my $Data      = ${ $Param{Header} } . "\n" . ${ $Param{Body} };
        my $ChunkSize = 4000;

        $SMTP->( 'data', ) || die "error starting data sending";

        while ( my $DataLength = length $Data ) {
            my $TmpChunkSize = ( $ChunkSize > $DataLength ) ? $DataLength : $ChunkSize;
            my $Chunk        = substr $Data, 0, $TmpChunkSize;

            $SMTP->( 'datasend', $Chunk, ) || die "error sending data chunk";

            $Data = substr $Data, $TmpChunkSize;
        }

        $SMTP->( 'dataend', ) || die "error ending data sending";

        return 1;
    };

    if ( !$DataSent ) {
        my $FullErrorMessage = sprintf(
            "Could not send message to server: %s, %s!",
            $SMTP->( 'code', ),
            $SMTP->( 'message', ),
        );

        $Param{CommunicationLogObject}->ObjectLog(
            ObjectLogType => 'Message',
            Priority      => 'Error',
            Key           => $Self->{FullModuleName},
            Value         => $FullErrorMessage,
        );

        return $Self->_SendError(
            %Param,
            ErrorMessage => $FullErrorMessage,
            SMTP         => $SMTP,
        );
    }

    # debug
    if ( $Self->{Debug} > 2 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Sent email to '$ToString' from '$Param{From}'.",
        );
    }

    $Param{CommunicationLogObject}->ObjectLog(
        ObjectLogType => 'Message',
        Priority      => 'Info',
        Key           => $Self->{FullModuleName},
        Value         => "Email successfully sent from '$Param{From}' to '$ToString'.",
    );

    return $Self->_SendSuccess(
        SMTP => $SMTP,
        %Param
    );
}

sub _Connect {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Name (qw(MailHost FQDN)) {
        if ( !$Param{$Name} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Name!",
            );
            return;
        }
    }

    # Remove a possible port from the FQDN value
    my $FQDN = $Param{FQDN};
    $FQDN =~ s{:\d+}{}smx;

    # set up connection connection
    my $SMTP = Net::SMTP->new(
        $Param{MailHost},
        Hello   => $FQDN,
        Port    => $Param{SMTPPort} || $Self->{_Port},

        %{$Self->{_SSLOptions}},

        Timeout => 30,
        Debug   => $Param{SMTPDebug},
    );

    if ( %{$Self->{_StartTLSOptions}} ) {
        $SMTP->starttls(%{$Self->{_StartTLSOptions}});
    }

    return $SMTP;
}

sub _SendResult {
    my ( $Self, %Param ) = @_;

    my $SMTP = delete $Param{SMTP};
    $SMTP->( 'quit', ) if $SMTP;

    return {%Param};
}

sub _SendSuccess {
    my ( $Self, %Param ) = @_;
    return $Self->_SendResult(
        Success => 1,
        %Param
    );
}

sub _SendError {
    my ( $Self, %Param ) = @_;

    my $SMTP = $Param{SMTP};
    if ( $SMTP && !defined $Param{Code} ) {
        $Param{Code} = $SMTP->( 'code', );
    }

    return $Self->_SendResult(
        Success => 0,
        %Param,
        SMTPError => 1,
    );
}

sub _GetSMTPSafeWrapper {
    my ( $Self, %Param, ) = @_;

    my $SMTP = $Param{SMTP};

    return sub {
        my $Operation   = shift;
        my @LocalParams = @_;

        my $ScalarResult;
        my @ArrayResult = ();
        my $Wantarray   = wantarray;

        eval {
            if ($Wantarray) {
                @ArrayResult = $SMTP->$Operation( @LocalParams, );
            }
            else {
                $ScalarResult = $SMTP->$Operation( @LocalParams, );
            }

            return 1;
        } || do {
            my $Error = $@;
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => sprintf(
                    "Error while executing 'SMTP->%s(%s)': %s",
                    $Operation,
                    join( ',', @LocalParams ),
                    $Error,
                ),
            );
        };

        return @ArrayResult if $Wantarray;
        return $ScalarResult;
    };
}

1;
