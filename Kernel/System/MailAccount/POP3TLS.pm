# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::MailAccount::POP3TLS;

use strict;
use warnings;

use parent 'Kernel::System::MailAccount::POP3';

our @ObjectDependencies;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = $Type->SUPER::new(%Param);
    bless( $Self, $Type );

    $Self->{_StartTLSOptions} = {
        SSL             => 1,
        SSL_verify_mode => 0,
    };

    $Self->{FullModuleName} = __PACKAGE__;
    $Self->{ModuleName}     = __PACKAGE__ =~ s/.*:://r;

    return $Self;
}

1;
