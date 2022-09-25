# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::System::Update;

use strict;
use warnings;

use IO::Interactive qw(is_interactive);
use Text::Wrap;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Update',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->{ProductName} =
        $Kernel::OM->Get('Kernel::Config')->Get('ProductName');

    $Self->Description("Update $Self->{ProductName} to a newer version.");
    
    $Self->AddOption(
        Name        => 'file',
        Description => "The tar.gz, tar.bz2, or zip file with the new " .
            "version of the system.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'force',
        Description => 'Force the update even if there are errors.',
        Required    => 0,
        HasValue    => 0,
    );

    # TODO: Name => 'check'

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $DistArchive = $Self->GetOption('file');
    my $Forced      = $Self->GetOption('force');

    if ( $DistArchive !~ / \. (?: tar\.gz | tar\.bz2 | zip ) $/ix ) {
        $Self->PrintError("Wrong file type.\n");
        return $Self->ExitCodeError();
    }

    my $UpdateObject = $Kernel::OM->Get('Kernel::System::Update');

    my $CurrentVersion = $Kernel::OM->Get('Kernel::Config')->Get('Version');
    my $DistVersion = $UpdateObject->GetDistVersion(
        DistArchive => $DistArchive,
    );

    my $VersionSupported = $UpdateObject->VersionSupported(
        DistArchive => $DistArchive,
    );

    if ( ! $VersionSupported ) {
        my $CurrentVersion = $Kernel::OM->Get('Kernel::Config')->Get('Version');
        my $DistVersion = $UpdateObject->GetDistVersion(
            DistArchive => $DistArchive,
        );

        $Self->PrintError("Updating from version $CurrentVersion to " .
            "$DistVersion is not supported.");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->_PrintPreRunWarning();
    $Self->Print("\n");

    if ( $Forced ) {
        $Self->Print('<yellow>Force mode is in effect -- proceeding without ' .
            "confirmation...</yellow>\n");
    }
    elsif ( ! $Self->_ConfirmRun() ) {
        $Self->Print("\n");
        $Self->Print("Aborting update.\n");
        $Self->Print("\n");

        return $Self->_ExitWithError();
    }

    $Self->Print("\n");
    $Self->Print("Starting system update...\n");
    $Self->Print("\n");

    #
    # Extract distribution package files
    #

    $Self->Print("<yellow>Extracting files...</yellow>\n");

    my $DistPath = $UpdateObject->ExtractDistArchive(
        DistArchive => $DistArchive,
    );

    if ( $DistPath ) {
        $Self->Print("<green>Files extracted.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to extract files.</red>\n");
        
        return $Self->_ExitWithError();
    }

    $Self->Print("\n");

    #
    # Stop active user sessions
    #

    $Self->Print("<yellow>Stopping active user sessions...</yellow>\n");

    my $SessionsStopped = $UpdateObject->StopUserSessions();

    if ( $SessionsStopped ) {
        $Self->Print("<green>User sessions stopped.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to stop active user sessions.</red>\n");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->Print("\n");

    #
    # Enable system maintenance mode
    #

    $Self->Print("<yellow>Enabling system maintenance mode...</yellow>\n");

    $Self->{SysMaintID} = $UpdateObject->EnableMaintenanceMode(
        DistVersion => $DistVersion,
    );

    if ( $Self->{SysMaintID} ) {
        $Self->Print("<green>System maintenance mode enabled.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to enable system maintenance mode.</red>\n");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->Print("\n");

    #
    # Stop background tasks
    #

    $Self->Print("<yellow>Stopping background tasks...</yellow>\n");

    my $BGTasksStopped = $UpdateObject->StopBackgroundTasks();

    if ( $BGTasksStopped ) {
        $Self->Print("<green>Background tasks stopped.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to stop background tasks.</red>\n");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->Print("\n");

    #
    # Update database
    #

    $Self->Print("<yellow>Updating database...</yellow>\n");

    my $DBUpdated = $UpdateObject->UpdateDatabase(
        DistPath => $DistPath,
    );

    if ( $DBUpdated ) {
        $Self->Print("<green>Database updated successfully.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to update database.</red>\n");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->Print("\n");

    #
    # Update application files
    #

    $Self->Print("<yellow>Updating application files...</yellow>\n");

    my $FilesCopied = $UpdateObject->CopyFiles(
        DistPath => $DistPath,
    );
    
    if ( $FilesCopied ) {
        $Self->Print("<green>Files updated successfully.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to update application files.</red>\n");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->Print("\n");

    #
    # Restart background tasks
    #

    $Self->Print("<yellow>Restarting background tasks...</yellow>\n");

    my $BGTasksStarted = $UpdateObject->StartBackgroundTasks();

    if ( $BGTasksStarted ) {
        $Self->Print("<green>Background tasks restarted.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to restart background tasks.</red>\n");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->Print("\n");

    #
    # Disable system maintenance mode
    #

    $Self->Print("<yellow>Disabling system maintenance mode...</yellow>\n");

    my $SysMaintDisabled = $UpdateObject->DisableMaintenanceMode(
        SystemMaintenanceID => $Self->{SysMaintID},
    );

    $Self->{SysMaintID} = undef;

    if ( $SysMaintDisabled ) {
        $Self->Print("<green>Disabled system maintenance mode.</green>\n");
    }
    else {
        $Self->Print("<red>Failed to disable system maintenance mode.</red>\n");

        if ( $Forced ) {
            $Self->_PrintProceedingMessage();
        }
        else {
            return $Self->_ExitWithError();
        }
    }

    $Self->Print("\n");

    return $Self->ExitCodeOk();
}

sub _PrintPreRunWarning {
    my ( $Self, %Param ) = @_;

    $Self->Print(
        '<yellow>' . wrap('', '',
            "Warning: This method of updating $Self->{ProductName} is not " .
            'yet mature and should be used with caution. Please make sure ' .
            'that you backup the system before beginning the update ' .
            "process.\n" .
            "\n" .
            'DO NOT update your system this way if you have installed ' .
            'any packages which may affect the core features of the ' .
            "system (such as OTRS::ITSM).\n" .
            "\n" .
            'When the update starts, all user sessions will be closed. The ' .
            'system will be put in maintenance mode until the update is ' .
            "completed.\n"
        ) . '</yellow>'
    );
}

sub _PrintProceedingMessage {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>Force mode is in effect -- proceeding with ' .
        "update...</yellow>\n");
}

sub _ConfirmRun {
    my ( $Self ) = @_;

    if ( is_interactive() ) {
        $Self->Print('Do you want to start the update? ');
        $Self->Print('[Y]es/[N]o: ');

        my $Answer = <STDIN>;
        $Answer =~ s{\s}{}g;

        return $Answer =~ m{^ y (?:es)? $}ix;
    }

    return;
}

sub _DisableMaintenanceModeOnError {
    my ( $Self ) = @_;

    my $UpdateObject = $Kernel::OM->Get('Kernel::System::Update');

    my $Disabled;

    $Self->Print("<yellow>Disabling system maintenance mode...</yellow>\n");
    
    for my $Attempt (1 .. 3) {
        last if $Disabled = $UpdateObject->DisableMaintenanceMode(
            SystemMaintenanceID => $Self->{SysMaintID},
        );
        sleep 3;
    }

    if ( $Disabled ) {
        # Print as a warning rather than success, because we're still exiting
        # due to an error
        $Self->Print("<yellow>Disabled system maintenance mode.</yellow>\n");
    }
    else {
        $Self->Print("<red>Failed to disable system maintenance mode.</red>\n");
    }

    return $Disabled;
}

sub _ExitWithError {
    my ( $Self ) = @_;

    my $UpdateObject = $Kernel::OM->Get('Kernel::System::Update');

    # Make sure the system is not left in maintenance mode when exiting
    if ( $Self->{SysMaintID} ) {
        $Self->_DisableMaintenanceModeOnError();
    }

    return $Self->ExitCodeError();
}

1;
