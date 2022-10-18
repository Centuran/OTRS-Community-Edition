# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Output::HTML::Preferences::SkinOptions;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Web::Request',
    'Kernel::Config',
    'Kernel::System::AuthSession',
    'Kernel::Output::HTML::Layout',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    for my $Needed (qw(UserID UserObject ConfigItem)) {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    my @Params;

    my $UseModern = $Param{UserData}->{'UserSkinOptions-default-UseModern'};
    my $TextSize  = $Param{UserData}->{'UserSkinOptions-default-TextSize'};

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $UseModernByDefault = $Self->{ConfigItem}->{Area} eq 'Agent' ?
        $ConfigObject->Get('Loader::Agent::DefaultSkin::UseModern') :
        $ConfigObject->Get('Loader::Customer::DefaultSkin::UseModern');

    $UseModern //= $UseModernByDefault;
    $TextSize  ||= 'small';

    my %Options = (
        'UseModern' => $UseModern ? 'checked="checked"' : '',
        'TextSize' => {
            TextSizeSmall  => $TextSize eq 'small'  ? 'checked="checked"' : '',
            TextSizeMedium => $TextSize eq 'medium' ? 'checked="checked"' : '',
            TextSizeLarge  => $TextSize eq 'large'  ? 'checked="checked"' : '',
        },
    );

    push(
        @Params,
        {
            %Param,
            %Options,

            Name  => $Self->{ConfigItem}->{PrefKey},
            Block => 'SkinOptions',
        },
    );

    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my %UserSkinOptions = (
        'default' => {
            'UseModern' => $ParamObject->GetParam( Param => 'UseModern' ) || 0,
            'TextSize'  => $ParamObject->GetParam( Param => 'TextSize' ),
        },
    );

    for my $Skin (keys %UserSkinOptions) {
        while (my ($SkinOption, $Value) = each(%{$UserSkinOptions{$Skin}})) {
            my $Key = "UserSkinOptions-$Skin-$SkinOption";

            $Self->{UserObject}->SetPreferences(
                UserID => $Param{UserData}->{UserID},
                Key    => $Key,
                Value  => $Value,
            );

            # update SessionID
            if ( $Param{UserData}->{UserID} eq $Self->{UserID} ) {
                $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
                    SessionID => $Self->{SessionID},
                    Key       => $Key,
                    Value     => $Value,
                );
            }
        }
    }

    $Self->{Message} = Translatable('Preferences updated successfully!');
    return 1;
}

sub Error {
    my ( $Self, %Param ) = @_;

    return $Self->{Error} || '';
}

sub Message {
    my ( $Self, %Param ) = @_;

    return $Self->{Message} || '';
}

1;
