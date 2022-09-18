#!/usr/bin/env perl
# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";
use lib "$Bin/../../Custom";

use CGI::Fast;
use Module::Refresh;

use Kernel::System::Web::InterfaceAgent();
use Kernel::System::ObjectManager;

my $Debug = 0;

while ( my $WebRequest = CGI::Fast->new() ) {
    eval {
        Module::Refresh->refresh();
    };

    local $Kernel::OM = Kernel::System::ObjectManager->new();

    my $Interface = Kernel::System::Web::InterfaceAgent->new(
        WebRequest => $WebRequest,
        Debug      => $Debug,
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
}
