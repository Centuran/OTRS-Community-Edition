# --
# Copyright (C) 2021-2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package scripts::DBUpdateTo6::DisableGenericAgentSystemCommandJobs;  ## no critic

use strict;
use warnings;

use IO::Interactive qw(is_interactive);

use parent qw(scripts::DBUpdateTo6::Base);

use version;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::GenericAgent',
);

=head1 NAME

scripts::DBUpdateTo6::DisableGenericAgentSystemCommandJobs - Disables generic agent jobs that run system commands.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $GenericAgentObject = $Kernel::OM->Get('Kernel::System::GenericAgent');

    my $SystemCommandJobs = $Self->_GetSystemCommandJobs();

    for my $JobName ( keys %{$SystemCommandJobs} ) {
        my $Job = $SystemCommandJobs->{$JobName};

        # Remove the system command parameter and set job to invalid
        delete $Job->{NewCMD};
        $Job->{Valid} = 0;

        # Replace the original job with the disabled one

        $GenericAgentObject->JobDelete(
            Name   => $JobName,
            UserID => 1,
        );

        $GenericAgentObject->JobAdd(
            Name   => "[DISABLED DURING MIGRATION] $JobName",
            Data   => $Job,
            UserID => 1,
        );
    }

    return 1;
}

sub CheckPreviousRequirement {
    my ( $Self, %Param ) = @_;

    my $SystemCommandJobs = $Self->_GetSystemCommandJobs();
    return 1 if !IsHashRefWitData($SystemCommandJobs);

    print "\n        Warning: the Generic Agent jobs listed below can execute system commands.\n";
    print "        This is unsafe and not supported anymore. These jobs will be disabled\n";
    print "        and their names will be prefixed with \"[DISABLED DURING MIGRATION]\".\n";
    print "\n        If you need to execute system commands in Generic Agent jobs, you can\n";
    print "        do that by creating a custom module. Please refer to the example located at\n";
    print "        Kernel/System/GenericAgent/ExecuteSystemCommand.pm.example.\n\n";

    for my $JobName ( sort keys %{$SystemCommandJobs} ) {
        print "         - $JobName\n";
    }

    print "\n";

    if ( is_interactive() ) {
        print '        Do you want to continue? [Y]es/[N]o: ';

        my $Answer = <>;
        $Answer =~ s{\s}{}g;

        return if $Answer !~ m{^ y (?:es)? $}ix;
    }

    return 1;
}

sub _GetSystemCommandJobs {
    my ( $Self, %Param ) = @_;

    my $GenericAgentObject = $Kernel::OM->Get('Kernel::System::GenericAgent');

    my %Jobs;

    my %JobNames = $GenericAgentObject->JobList();

    JOB:
    for my $JobName ( keys %JobNames ) {
        my %Job = $GenericAgentObject->JobGet(
            Name => $JobName,
        );

        next JOB if !%Job;
        
        # Include jobs that have the system command parameter set
        if ( IsStringWithData($Job{'NewCMD'}) ) {
            $Jobs{$JobName} = { %Job };
        }
    }

    return \%Jobs;
}

1;
