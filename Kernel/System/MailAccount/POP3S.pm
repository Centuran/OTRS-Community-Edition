# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::MailAccount::POP3S;

use strict;
use warnings;

use Net::POP3;

use parent qw(Kernel::System::MailAccount::POP3);

our @ObjectDependencies = (
    'Kernel::System::Log',
);

# Use Net::SSLGlue::POP3 on systems with older Net::POP3 modules that cannot handle POP3S.
BEGIN {
    if ( !defined &Net::POP3::starttls ) {
        ## nofilter(TidyAll::Plugin::OTRS::Perl::Require)
        ## nofilter(TidyAll::Plugin::OTRS::Perl::SyntaxCheck)
        require Net::SSLGlue::POP3;
    }
}

sub Connect {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Name (qw(Login Password Host Timeout Debug)) {
        if ( !defined $Param{$Name} ) {
            return (
                Successful => 0,
                Message    => "Need $Name!",
            );
        }
    }

    my $Type = 'POP3S';

    # connect to host
    my $PopObject = Net::POP3->new(
        $Param{Host},
        Timeout         => $Param{Timeout},
        Debug           => $Param{Debug},
        SSL             => 1,
        SSL_verify_mode => 0,
    );

    if ( !$PopObject ) {
        return (
            Successful => 0,
            Message    => "$Type: Can't connect to $Param{Host}"
        );
    }

    # authentication
    my $NOM = $PopObject->login( $Param{Login}, $Param{Password} );
    if ( !defined $NOM ) {
        $PopObject->quit();
        return (
            Successful => 0,
            Message    => "$Type: Auth for user $Param{Login}/$Param{Host} failed!"
        );
    }

    return (
        Successful => 1,
        PopObject  => $PopObject,
        NOM        => $NOM,
        Type       => $Type,
    );
}

1;
