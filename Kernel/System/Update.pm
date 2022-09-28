# --
# Copyright (C) 2021 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Update;

use strict;
use warnings;

use Archive::Tar;
use Archive::Zip qw( :ERROR_CODES );
use Archive::Zip::MemberRead;
use Cwd;
use Digest::MD5;
use File::Basename;
use File::Copy;
use File::Path qw(make_path);

use Kernel::System::Update::Database;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::AuthSession',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::FileTemp',
    'Kernel::System::Log',
    'Kernel::System::SysConfig',
    'Kernel::System::Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = { };
    bless( $Self, $Type );

    $Self->{PossibleUpdates} = {
        # 6.0.31+ -> 6.0.37
        '6.0.37' => qr{^ 6 \. 0 \. (?: 3[1-6] (?: -rc\d+ )? | 37-rc\d+ ) $}x,
    };

    return $Self;
}

sub CheckUpdate {
    my ( $Self, %Param ) = @_;

    # TODO: Check required parameters

    # TODO: Check disk space

    # TODO: Check HTTP server timeout

    my $DistArchive = $Param{DistArchive};

    # TODO: Check if $DistArchive exists and is readable
}

sub PerformUpdate {
    my ( $Self, %Param ) = @_;

    # TODO: Check parameters

    my $DistArchive = $Param{DistArchive};

    # TODO: Enable system maintenance mode

    # TODO: Make backup

    my $DistDir = $Param{DistFiles};# $Self->_ExtractDistArchive($DistArchive);

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my $CurrentDatabaseDir = $Home    . '/scripts/database';
    my $NewDatabaseDir     = $DistDir . '/scripts/database';
    
    $Self->_UpdateDatabase($CurrentDatabaseDir, $NewDatabaseDir);

    # TODO: Disable system maintenance mode
}

sub ExtractDistArchive {
    my ( $Self, %Param ) = @_;

    return $Self->_ExtractDistArchive($Param{DistArchive});
}

sub FindModifiedFiles {
    my ( $Self, %Param ) = @_;

    my $CurrentPath = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my $MD5 = Digest::MD5->new();

    my $Cwd = cwd();
    chdir($CurrentPath);

    open(my $Archive, '<', $CurrentPath . '/ARCHIVE');

    my @Files;

    while (my $Line = <$Archive>) {
        my ($Digest, $File) = split(/::/, $Line, 2);
        chomp($File);

        if (! -e "$CurrentPath/$File") {
            # TODO: Error, file is supposed to exist
            next;
        }

        open(my $In, '<', "$CurrentPath/$File"); # TODO: Handle open error

        $MD5->addfile($In);

        if ($MD5->hexdigest() ne $Digest) {
            push @Files, $File;
        }

        close($In);

        $MD5->reset();
    }

    close($Archive);

    chdir($Cwd);

    return @Files;
}

sub CopyFiles {
    my ( $Self, %Param ) = @_;

    my $CurrentPath = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my $DistPath    = $Param{DistPath};

    my $Cwd = cwd();
    chdir($DistPath);

    open(my $Archive, '<', $DistPath . '/ARCHIVE');

    while (my $Line = <$Archive>) {
        my (undef, $File) = split(/::/, $Line, 2);
        chomp($File);

        if (-e "$DistPath/$File") {
            make_path(dirname("$CurrentPath/$File"), {
                chmod => 0775
            });
            copy("$DistPath/$File", "$CurrentPath/$File")
        }
    }

    close($Archive);

    chdir($Cwd);

    return 1;
}

sub GetDistVersion {
    my ( $Self, %Param ) = @_;

    # TODO: Check for required parameters

    return $Self->_GetDistVersion($Param{DistArchive});
}

sub VersionSupported {
    my ( $Self, %Param ) = @_;

    # TODO: Check for required parameters

    my $DistVersion = $Self->_GetDistVersion($Param{DistArchive});

    # Strip off trailing "-rc1", "-rc2" parts, if present
    $DistVersion =~ s/ -rc \d+ $//x;

    return if !exists $Self->{PossibleUpdates}{$DistVersion};

    my $CurrentVersion = $Kernel::OM->Get('Kernel::Config')->Get('Version');

    return $CurrentVersion =~ $Self->{PossibleUpdates}{$DistVersion};
}

sub UpdateDatabase {
    my ( $Self, %Param ) = @_;

    # TODO: Check required params

    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    my $CurrentPath = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my $DistPath    = $Param{DistPath};

    my $CurrentSchemaRef = $MainObject->FileRead(
        Location => $CurrentPath . '/scripts/database/otrs-schema.xml'
    );
    my $DistSchemaRef = $MainObject->FileRead(
        Location => $DistPath . '/scripts/database/otrs-schema.xml'
    );
    my $CurrentInitRef = $MainObject->FileRead(
        Location => $CurrentPath . '/scripts/database/otrs-initial_insert.xml'
    );
    my $DistInitRef = $MainObject->FileRead(
        Location => $DistPath . '/scripts/database/otrs-initial_insert.xml'
    );

    my $UpdateDBObject = Kernel::System::Update::Database->new;

    return if ! $UpdateDBObject->UpdateSchema($$CurrentSchemaRef,
        $$DistSchemaRef);

    return if ! $UpdateDBObject->UpdateData($$CurrentInitRef, $$DistInitRef);

    return 1;
}

sub StopUserSessions {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get("Kernel::System::AuthSession")->CleanUp();
}

sub EnableMaintenanceMode {
    my ( $Self, %Param ) = @_;

    my $DistVersion = '';

    if ( $Param{DistVersion} ) {
        $DistVersion = $Param{DistVersion};
    }
    elsif ( exists $Self->{DistVersion} ) {
        $DistVersion = $Self->{DistVersion};
    }
    else {
        # TODO: Get version from distribution package
    }

    my $SysMaintObject = $Kernel::OM->Get("Kernel::System::SystemMaintenance");
    
    my $SysMaintID = $SysMaintObject->SystemMaintenanceAdd(
        StartDate        => time,
        StopDate         => time + (60 * 60 * 24),
        Comment          => "Update to $DistVersion",
        ShowLoginMessage => 1,
        ValidID          => 1,
        UserID           => 1,
    );

    return $SysMaintID;
}

sub DisableMaintenanceMode {
    my ( $Self, %Param ) = @_;

    # TODO: Check required parameters

    my $SysMaintID = $Param{SystemMaintenanceID};

    my $SysMaintObject = $Kernel::OM->Get("Kernel::System::SystemMaintenance");

    my $SysMaint = $SysMaintObject->SystemMaintenanceGet(
        ID     => $SysMaintID,
        UserID => 1,
    );
    
    # Stop maintenance mode by setting stop date to current time
    my $Updated = $SysMaintObject->SystemMaintenanceUpdate(
        ID        => $SysMaint->{ID},
        StartDate => $SysMaint->{StartDate},
        StopDate  => time,
        Comment   => $SysMaint->{Comment},
        ValidID   => 1,
        UserID    => 1,
    );

    return $Updated;
}

sub StopBackgroundTasks {
    my ( $Self, %Param ) = @_;

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    # Stop cron jobs

    my $CronJobsStopped;

    # First check if crontab for OTRS user is active
    # FIXME: Do not hardcode OTRS user name
    if ( system("crontab -l -u otrs >/dev/null 2>&1") != 0 ) {
        $CronJobsStopped = 1;
    }
    else {
        $CronJobsStopped =
            system("$Home/bin/Cron.sh stop >/dev/null 2>&1") == 0;
    }

    # Stop daemon
    my $DaemonStopped =
        system("$^X $Home/bin/otrs.Daemon.pl stop >/dev/null 2>&1") == 0;
    
    return $CronJobsStopped && $DaemonStopped;
}

sub StartBackgroundTasks {
    my ( $Self, %Param ) = @_;

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    # Start cron jobs
    my $CronJobsStarted =
        system("$Home/bin/Cron.sh start >/dev/null 2>&1") == 0;

    # Start daemon
    my $DaemonStarted =
        system("$^X $Home/bin/otrs.Daemon.pl start >/dev/null 2>&1") == 0;
    
    return $CronJobsStarted && $DaemonStarted;
}

sub _GetDistVersion {
    my ( $Self, $DistArchive ) = @_;

    my $Content = '';

    if ( $DistArchive =~ / \.tar \.(?: gz | bz2 ) $/ix ) {
        my $Tar   = Archive::Tar->new($DistArchive);
        my ($Dir) = $Tar->list_files();
        
        $Content = $Tar->get_content($Dir . 'RELEASE');
    }
    elsif ( $DistArchive =~ / \.zip $/ix ) {
        my $Zip   = Archive::Zip->new($DistArchive);
        my ($Dir) = $Zip->memberNames();

        my $Handle = Archive::Zip::MemberRead->new($Zip, $Dir . 'RELEASE');
        
        while (defined (my $Line = $Handle->getline())) {
            $Content .= $Line . "\n";
        }

        # TODO: Check for Archive::Zip errors
    }
    else {
        # TODO: Log/report error on wrong file type

        return;
    }

    my ($Version) = ($Content =~ m/^ VERSION \s* = \s* ( \S+ ) $/mx);

    return $Version;
}

sub _ExtractDistArchive {
    my ( $Self, $DistArchive ) = @_;

    # TODO: Check if $DistArchive exists and is readable

    my $TempDir = $Kernel::OM->Get('Kernel::System::FileTemp')->TempDir();

    my $Cwd = cwd();
    chdir($TempDir);

    if ( $DistArchive =~ / \.tar \.(?: gz | bz2 ) $/ix ) {
        my $CompressionOption = 'z';
        $CompressionOption = 'j' if $DistArchive =~ /\.bz2$/;

        # Use system tar utility rather than e.g. Archive::Tar, because
        # it's faster
        system('tar ' . $CompressionOption . 'xf ' . $DistArchive);
    }
    elsif ( $DistArchive =~ / \.zip $/ix ) {
        my $Zip = Archive::Zip->new();
        
        $Zip->read($DistArchive);
        $Zip->extractTree();

        # TODO: Check for Archive::Zip errors
    }
    else {
        # TODO: Log/report error on wrong file type

        return;
    }
    
    chdir($Cwd);

    my ($DistPath) = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $TempDir,
        Filter    => '*'
    );

    return $DistPath;
}

1;
