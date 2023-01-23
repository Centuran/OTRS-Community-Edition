#!/usr/bin/env perl
# --
# Copyright (C) 2022-2023 Centuran Consulting, https://centuran.com/
# Based on original work by:
# Copyright (C) 2021-2022 Znuny GmbH, https://znuny.org/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING-AGPL for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl-3.0.txt.
# --

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";
use lib "$Bin/../../Custom";

my $Debug = 0;

use Kernel::System::Web::InterfaceAgent();
use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

my $Interface = Kernel::System::Web::InterfaceAgent->new(
    Debug => $Debug,
);

my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

$ParamObject->{Query}->param(
    -name  => 'Action',
    -value => 'AdminOAuth2TokenConfig',
);

$ParamObject->{Query}->param(
    -name  => 'Subaction',
    -value => 'RequestTokenByAuthorizationCode',
);

$Interface->Run();
