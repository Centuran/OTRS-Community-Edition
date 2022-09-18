# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::MailAccount::Base;

use strict;
use warnings;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = { %Param };
    bless($Self, $Type);

    $Self->{_SSLOptions}      = {};
    $Self->{_StartTLSOptions} = {};

    $Self->{ModuleName} = undef;

    return $Self;
}

1;
