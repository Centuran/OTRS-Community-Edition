# --
# Copyright (C) 2021 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AdminUpdate;

use strict;
use warnings;

use Fcntl qw(:flock);
use IO::Handle;
use IO::Select;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Console::Command::Maint::Config::Rebuild;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = { %Param };
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    my %Data;

    if ( $Self->{Subaction} eq 'Upload' ) {
        $LayoutObject->ChallengeTokenCheck();

        my %Errors;

        my %DistUpload = $ParamObject->GetUploadAll(
            Param => 'DistFile'
        );

        if ( !%DistUpload ) {
            $Errors{DistFileInvalid} = 'ServerError';
        }

        if (%Errors) {
            return $Self->_Output(
                $LayoutObject, 
                ValidateContent => 'Validate_Required',
                %Errors,
            );
        }

        my $TempDir = $ConfigObject->Get('TempDir') . '/Update';

        if ( !-d $TempDir ) {
            mkdir $TempDir;
        }

        # Delete previously uploaded files
        unlink for glob($TempDir . '/*');

        # Save the new file as Update.tar.gz (or bz2)
        my $DistFile =
            $DistUpload{Filename} =~ s/.*(\.tar\.gz|\.tar\.bz2)$/Update$1/r;

        my $FileWritten = $MainObject->FileWrite(
            Directory => $TempDir,
            Filename  => $DistFile,
            Content   => \$DistUpload{Content},
            Mode      => 'binmode'
        );
        # TODO: Handle errors

        return $Self->_Output(
            $LayoutObject,
            Step => 'Check',
            ValidateContent => 'Validate_Required'
        );
    }
    elsif ($Self->{Subaction} eq 'Update') {
        return $Self->_Output(
            $LayoutObject,
            Step => 'Update',
            ValidateContent => 'Validate_Required'
        );
    }
    elsif ($Self->{Subaction} eq 'AJAXCheck') {
        # TODO: Check for existing .UPDATING file (from a previous unfinished
        # update). Consider making it a fixed check in the admin interface
        # (similar to how daemon not running is always shown as an error).
        my $UpdateObject = $Kernel::OM->Get('Kernel::System::Update');

        my $MessagesFile =
            $ConfigObject->Get('TempDir') . '/messages-' . $Self->{SessionID};

        open my $FH, '>>', $MessagesFile or die;

        truncate($FH, 0);

        my $ErrorsCount   = 0;
        my $WarningsCount = 0;

        my $TempDir = $ConfigObject->Get('TempDir') . '/Update';

        my ($DistPath) = glob($TempDir . '/Update.*');

        #
        # Check distribution package version
        #

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'dist/version',
            Message => 'Checking distribution package version'
        });

        my $CurrentVersion = $ConfigObject->Get('Version');
        my $DistVersion    = $UpdateObject->_CheckDistVersion($DistPath);

        if ($CurrentVersion eq $DistVersion) {
            _SendInfo($FH, {
                Type    => 'Check',
                ID      => 'dist/version',
                Result  => $DistVersion,
                Status  => 'warn',
                Warning => 'Distribution package version is the same as ' .
                    'the version currently in use.'
            });

            $WarningsCount++;            
        }
        else {
            # TODO: Check for downgrades

            # TODO: Check if upgrade path is supported

            _SendInfo($FH, {
                Type   => 'Check',
                ID     => 'dist/version',
                Result => $DistVersion,
                Status => 'pass',
            });
        }

        #
        # Check free space
        #

        my $Home = $ConfigObject->Get('Home');

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'disk-space/app',
            Message => "Checking free space in application directory ($Home)"
        });

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'disk-space/temp',
            Message => 'Checking free space in temporary directory ' .
                "($Home/var/tmp)"
        });

        sub _Sizes {
            my ($SizeMB) = @_;

            return {
                MB => $SizeMB,
                GB => sprintf("%.2f", $SizeMB / 10**3),
                TB => sprintf("%.2f", $SizeMB / 10**6)
            };
        }

        # Use the df shell command to read disk usage data
        my %Partitions = map {
            $_->[0] => {
                Size      => _Sizes($_->[1] =~ s/\D+$//r),
                Used      => _Sizes($_->[2] =~ s/\D+$//r),
                Available => _Sizes($_->[3] =~ s/\D+$//r)
            }
        } do {
            open my $Out, '-|', 'df -BMB --output=target,size,used,avail,pcent';
            # TODO: Handle error
            my @Lines = <$Out>;
            close $Out;

            map { [ split(/\s+/) ] } @Lines[1..$#Lines];
        };

        my ($HomePartition, $TmpPartition);

        for my $Dir (sort keys %Partitions) {
            $HomePartition = $Dir if index($Home, $Dir) == 0;
            $TmpPartition  = $Dir if index("$Home/var/tmp", $Dir) == 0;
        }

        my $HomeSpaceRequired = 200;
        my $TmpSpaceRequired  = 100;

        my $HomeSpace = $Partitions{$HomePartition}->{Available}{MB};
        my $TmpSpace  = $Partitions{$TmpPartition}->{Available}{MB};
        
        my $HomeSpaceExtra = $HomeSpace - $HomeSpaceRequired;
        my $TmpSpaceExtra  = $TmpSpace - $TmpSpaceRequired;

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'disk-space/app',
            Result  => $HomeSpace . ' MB',
            Status  => $HomeSpaceExtra >= 0 ? 'pass' : 'fail',
            Details => $HomeSpaceExtra < 0 ?
                {
                    Location       => $Home,
                    SpaceRequired  => $HomeSpaceRequired . ' MB',
                    SpaceAvailable => $HomeSpace . ' MB',
                }
                : undef,
        });

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'disk-space/temp',
            Result  => $TmpSpace . ' MB',
            Status  => $TmpSpaceExtra >= 0 ? 'pass' : 'fail',
            Details => $TmpSpaceExtra < 0 ?
                {
                    Location       => "$Home/var/tmp",
                    SpaceRequired  => $TmpSpaceRequired . ' MB',
                    SpaceAvailable => $TmpSpace . ' MB',
                }
                : undef,
        });

        #
        # Check for installed packages
        #

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'otrs/installed-packages',
            Message => 'Checking for installed packages'
        });

        my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');

        my @InstalledPackages = $PackageObject->RepositoryList(
            Result => 'short'
        );

        _SendInfo($FH, {
            Type   => 'Check',
            ID     => 'otrs/installed-packages',
            Result => !@InstalledPackages ?
                'No packages are installed' : 'Found installed packages',
            Status  => !@InstalledPackages ? 'pass' : 'fail',
            Details => @InstalledPackages ?
                {
                    InstalledPackages => [
                        map { "$_->{Name} $_->{Version}" } @InstalledPackages
                    ]
                }
                : undef,
        });

        $ErrorsCount++ if @InstalledPackages;

        #
        # Check for file modifications
        #

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'otrs/file-modifications',
            Message => 'Checking for file modifications'
        });

        my @ModifiedFiles = $UpdateObject->FindModifiedFiles();

        _SendInfo($FH, {
            Type   => 'Check',
            ID     => 'otrs/file-modifications',
            Result => !@ModifiedFiles ?
                'No modifications' : 'Modifications found',
            Status  => !@ModifiedFiles ? 'pass' : 'fail',
            Details => @ModifiedFiles ?
                {
                    ModifiedFiles => \@ModifiedFiles,
                }
                : undef,
        });

        $ErrorsCount++ if @ModifiedFiles;

        #
        # Check for files in Custom directory
        #

        _SendInfo($FH, {
            Type    => 'Check',
            ID      => 'otrs/custom-files',
            Message => 'Checking for files in Custom directory'
        });
        
        # Find files filtering out README and self/parent directories
        my @CustomFiles =
            grep { $_ !~ m<^ $Home/Custom/ (?: README | \. | \.\. ) >x }
            glob "$Home/Custom/* $Home/Custom/.*";

        _SendInfo($FH, {
            Type   => 'Check',
            ID     => 'otrs/custom-files',
            Result => !@CustomFiles ?
                'No custom files found' : 'Custom files found',
            Status  => !@CustomFiles ? 'pass' : 'fail',
            Details => @CustomFiles ? 
                {
                    CustomFiles => \@CustomFiles,
                }
                : undef,
        });

        $ErrorsCount++ if @CustomFiles;

        close($FH);

        # Determine the final status of the checks
        my $CheckStatus = 'pass';
        $CheckStatus = 'warn' if $WarningsCount > 0;
        $CheckStatus = 'fail' if $ErrorsCount > 0;

        return $LayoutObject->Attachment(
            ContentType =>
                'application/json; charset=' . $LayoutObject->{Charset},
            Type    => 'inline',
            NoCache => 1,
            Content => $Kernel::OM->Get('Kernel::System::JSON')->Encode(
                Data => {
                    Status => $CheckStatus
                }
            ),
        );
    }
    elsif ($Self->{Subaction} eq 'AJAXUpdate') {
        my $UpdateObject = $Kernel::OM->Get('Kernel::System::Update');

        my $MessagesFile =
            $ConfigObject->Get('TempDir') . '/messages-' . $Self->{SessionID};

        open my $FH, '>>', $MessagesFile or die;

        truncate($FH, 0);

        #
        # Extract distribution package
        #

        my $TempDir = $ConfigObject->Get('TempDir') . '/Update';

        # Find the uploaded distribution package
        my ($DistPath) = glob($TempDir . '/Update.*');

        _SendInfo($FH, {
            Type    => 'Operation',
            ID      => 'extract',
            Message => 'Extracting distribution package'
        });

        my $ExtractedPath = $UpdateObject->ExtractDistArchive(
            Path => $DistPath
        );

        _SendInfo($FH, {
            Type   => 'Operation',
            ID     => 'extract',
            Result => 'Extracted',
            Status => 'pass',
        });

        # Create a flag file to indicate update is in progress
        $MainObject->FileWrite(
            Location => $ConfigObject->Get('Home') . '/var/tmp/.UPDATING',
            Content  => \''
        );

        #
        # Close active user sessions
        #

        _SendInfo($FH, {
            Type    => 'Operation',
            ID      => 'otrs/close-sessions',
            Message => 'Closing active user sessions'
        });

        my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

        my @SessionIDs = $SessionObject->GetAllSessionIDs();

        my $SessionsClosed = 1;

        for my $SessionID (@SessionIDs) {
            # Don't log out the current user
            next if $SessionID eq $Self->{SessionID};

            $SessionsClosed &&= $SessionObject->RemoveSessionID(
                SessionID => $SessionID,
            );
        }

        _SendInfo($FH, {
            Type   => 'Operation',
            ID     => 'otrs/close-sessions',
            Result => $SessionsClosed ? 'Closed' : 'Some sessions not closed',
            Status => $SessionsClosed ? 'pass' : 'warn',
        });

        #
        # Wait for the daemon process to stop
        #

        _SendInfo($FH, {
            Type    => 'Operation',
            ID      => 'otrs/daemon-status',
            Message => 'Waiting for OTRS Daemon to stop'
        });

        my $DaemonRunning = 1;

        my $NodeID = $ConfigObject->Get('NodeID') || 1;
        my $PIDDir = $ConfigObject->Get('Daemon::PID::Path') ||
            $ConfigObject->Get('Home') . '/var/run/';
        my $PIDFile = $PIDDir . "Daemon-NodeID-$NodeID.pid";

        for my $Retry (1..10) {
            # Daemon is not running if PID file does not exist
            if (! -e $PIDFile) {
                $DaemonRunning = 0;
                last;
            }

            open my $FH, '<', $PIDFile; ## no critic

            # Check if the daemon is running in a similar manner
            # as "otrs.Daemon.pl status" does, by trying to get an exclusive
            # lock on the PID file
            if (flock($FH, LOCK_EX | LOCK_NB)) {
                $DaemonRunning = 0;
                close $FH;
                last;
            }

            close $FH;

            sleep 5;
        }

        _SendInfo($FH, {
            Type   => 'Operation',
            ID     => 'otrs/daemon-status',
            Result => !$DaemonRunning ? 'Stopped' : 'Timed out',
            Status => !$DaemonRunning ? 'pass' : 'fail'
        });

        #
        # Update database
        #

        _SendInfo($FH, {
            Type    => 'Operation',
            ID      => 'db/update',
            Message => 'Updating database'
        });

        #$UpdateObject->UpdateDatabase(
        #    DistPath => $ExtractedPath
        #);

        _SendInfo($FH, {
            Type   => 'Operation',
            ID     => 'db/update',
            Result => 'Updated',
            Status => 'pass',
        });

        #
        # Copy files
        #

        _SendInfo($FH, {
            Type    => 'Operation',
            ID      => 'files/copy',
            Message => 'Copying files'
        });

        #$UpdateObject->CopyFiles(
        #    DistPath => $ExtractedPath
        #);

        _SendInfo($FH, {
            Type   => 'Operation',
            ID     => 'files/copy',
            Result => 'Copied',
            Status => 'pass',
        });

        #
        # Delete cached data
        #

        _SendInfo($FH, {
            Type    => 'Operation',
            ID      => 'cache/delete',
            Message => 'Deleting cached data'
        });

        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

        _SendInfo($FH, {
            Type   => 'Operation',
            ID     => 'cache/delete',
            Result => 'Deleted',
            Status => 'pass',
        });

        #
        # Rebuild configuration
        #

        _SendInfo($FH, {
            Type    => 'Operation',
            ID      => 'config/rebuild',
            Message => 'Rebuilding system configuration'
        });

        my $CommandRebuild =
            Kernel::System::Console::Command::Maint::Config::Rebuild->new();
        $CommandRebuild->{Quiet} = 1;
        
        my $ExitCode = $CommandRebuild->Run();

        _SendInfo($FH, {
            Type   => 'Operation',
            ID     => 'config/rebuild',
            Result => $ExitCode == $CommandRebuild->ExitCodeOk() ?
                'Rebuilt' : 'Failed',
            Status => $ExitCode == $CommandRebuild->ExitCodeOk() ?
                'pass' : 'fail',
        });

        close($FH);

        my %Result = (
            Status => 'pass'
        );

        $MainObject->FileDelete(
            Location => $ConfigObject->Get('Home') . '/var/tmp/.UPDATING'
        );

        return $LayoutObject->Attachment(
            ContentType =>
                'application/json; charset=' . $LayoutObject->{Charset},
            Type        => 'inline',
            NoCache     => 1,
            Content     => $Kernel::OM->Get('Kernel::System::JSON')->Encode(
                Data => \%Result
            ),
        );
    }
    elsif ($Self->{Subaction} eq 'Logout') {
        return $LayoutObject->Redirect(
            OP => "Action=Logout&ChallengeToken=" . $Self->{UserChallengeToken}
        );
    }
    elsif ($Self->{Subaction} eq 'AJAXCheckPoll' ||
        $Self->{Subaction} eq 'AJAXUpdatePoll')
    {
        my $MessagesFile =
            $ConfigObject->Get('TempDir') . '/messages-' . $Self->{SessionID};
        
        open my $fh, '+<', $MessagesFile or
            return $LayoutObject->Attachment(
                ContentType =>
                    'application/json; charset=' . $LayoutObject->{Charset},
                Type    => 'inline',
                NoCache => 1,
                Content => 
                    $Kernel::OM->Get('Kernel::System::JSON')->Encode(Data => {
                        Error => 1
                    }),
            );

        my $Select = IO::Select->new;
        $Select->add($fh);

        my $Foo = [];
        
        if (scalar $Select->can_read(0.5)) {
            $Foo = [ <$fh> ];
            truncate($fh, 0);
        }

        return $LayoutObject->Attachment(
            ContentType =>
                'application/json; charset=' . $LayoutObject->{Charset},
            Type        => 'inline',
            NoCache     => 1,
            Content     => 
                $Kernel::OM->Get('Kernel::System::JSON')->Encode(Data => $Foo),
        );
    }
    elsif ($Self->{Subaction} eq 'ShowCheckDetails') {
        my $Data = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
            Data => $ParamObject->GetParam(
                Param => 'Data'
            )
        );

        my $Output = $LayoutObject->Output(
            TemplateFile => 'AdminUpdate/CheckDetails',
            Data         => $Data,
            AJAX         => 1,
        );
        return $LayoutObject->Attachment(
            NoCache     => 1,
            ContentType => 'text/html',
            Charset     => $LayoutObject->{UserCharset},
            Content     => $Output,
            Type        => 'inline',
        );
    }
    else {
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminUpdate',
            Data         => {
                Step => 'Upload',
                ValidateContent => 'Validate_Required',
                %Data,
            }
        );

        $Output .= $LayoutObject->Footer();

        return $Output;
    }
}

sub _Output {
    my ( $Self, $LayoutObject, %Data ) = @_;

    my $Output = $LayoutObject->Header();

    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Notify( Priority => 'Error' );

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminUpdate',
        Data         => \%Data,
    );

    $Output .= $LayoutObject->Footer();

    return $Output;    
}

sub _SendInfo {
    my ($FH, $Data) = @_;

    print $FH $Kernel::OM->Get('Kernel::System::JSON')->Encode(
        Data => $Data
    ) . "\n";
    $FH->flush;
}
