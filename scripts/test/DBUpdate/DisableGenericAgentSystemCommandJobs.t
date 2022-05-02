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

use vars (qw($Self));

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase      => 1,
        RestoreConfiguration => 1,
    },
);
my $Helper             = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
my $GenericAgentObject = $Kernel::OM->Get('Kernel::System::GenericAgent');

my $RandomID = $Helper->GetRandomID();

my $JobAdded = $GenericAgentObject->JobAdd(
    Name => "Job-system-command-$RandomID",
    Data => {
        NewCMD => '/path/script.sh',
    },
    UserID => 1,
);

$Self->True($JobAdded, 'System command Generic Agent job has been added');

my %Job = $GenericAgentObject->JobGet(
    Name => "Job-system-command-$RandomID",
);

$Self->Is(
    $Job{Name},
    "Job-system-command-$RandomID",
    'System command job name is as expected'
);

$Self->True(
    $Job{Valid},
    'System command job is valid'
);

$JobAdded = $GenericAgentObject->JobAdd(
    Name => "Job-other-$RandomID",
    Data => {
        Title    => 'Foo',
        NewTitle => 'Bar',
    },
    UserID => 1,
);

$Self->True($JobAdded, 'Non-command Generic Agent job has been added');

%Job = $GenericAgentObject->JobGet(
    Name => "Job-other-$RandomID",
);

$Self->Is(
    $Job{Name},
    "Job-other-$RandomID",
    'Job name is as expected'
);

$Self->True(
    $Job{Valid},
    'Job is valid'
);

my $DBUpdateObject = $Kernel::OM->Create('scripts::DBUpdateTo6::DisableGenericAgentSystemCommandJobs');

$Self->True(
    $DBUpdateObject,
    'Database update object has been created'
);

my $UpdateSuccess = $DBUpdateObject->Run();

$Self->True(
    $UpdateSuccess,
    'Database update operation ran successfully'
);

$Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
    Type => 'GenericAgent',
);

%Job = $GenericAgentObject->JobGet(
    Name => "[DISABLED DURING MIGRATION] Job-system-command-$RandomID",
);

$Self->Is(
    $Job{Name},
    "[DISABLED DURING MIGRATION] Job-system-command-$RandomID",
    'System command job name has been modified as expected'
);

$Self->Is(
    $Job{Valid},
    0,
    'System command job is not valid'
);

%Job = $GenericAgentObject->JobGet(
    Name => "Job-other-$RandomID",
);

$Self->Is(
    $Job{Name},
    "Job-other-$RandomID",
    'Job name has not been modified'
);

$Self->True(
    $Job{Valid},
    'Job is valid'
);

1;
