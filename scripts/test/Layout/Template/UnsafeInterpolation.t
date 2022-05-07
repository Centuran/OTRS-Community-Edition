# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self %Param));

use Scalar::Util qw();

use Kernel::Output::HTML::Layout;

my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

my $LayoutObject = Kernel::Output::HTML::Layout->new(
    UserID => 1,
    Lang   => 'en',
);

eval {
    # This is a bit of a hack to prevent processing a fatal error and exiting,
    # while at the same time detecting that FatalError is being called
    # (because it increments the InFatalError value).
    $LayoutObject->{InFatalError} = 1;

    $LayoutObject->Output(
        Template => 'Test: [% Data.Value | Interpolate %]',
        Data     => {
            Value => 'Foo [% PERL %] print ":-)"; [% END %]',
        },
    );

    1;
};

$Self->Is(
    $LayoutObject->{InFatalError},
    2,
    'A fatal error is generated when a PERL block is encountered'
);

1;
