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

use Archive::Zip qw( :ERROR_CODES );
use Cwd;
use Digest::MD5;
use File::Basename;
use File::Copy;
use File::Path qw(make_path);

use Kernel::System::Update::Database;

our @ObjectDependencies = (
    'Kernel::Config',
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

    return $Self;
}

sub CheckUpdate {
    my ($Self, %Param) = @_;

    # TODO: Check required parameters

    # TODO: Check disk space

    # TODO: Check HTTP server timeout

    my $DistArchive = $Param{DistArchive};

    # TODO: Check if $DistArchive exists and is readable
}

sub PerformUpdate {
    my ($Self, %Param) = @_;

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
    my ($Self, %Param) = @_;

    return $Self->_ExtractDistArchive($Param{Path});
}

sub FindModifiedFiles {
    my ($Self, %Param) = @_;

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
    my ($Self, %Param) = @_;

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
}

sub _CheckDistVersion {
    my ($Self, $DistArchive) = @_;

    my $Tar = Archive::Tar->new($DistArchive);
    
    my ($Dir) = $Tar->list_files();
    my $Content = $Tar->get_content($Dir . 'RELEASE');
    my ($Version) = ($Content =~ m/^ VERSION \s* = \s* ( \S+ ) $/mx);

    return $Version;
}

# tar.gz or tar.bz2 supported
sub _ExtractDistArchive {
    my ($Self, $DistArchive) = @_;

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
        my $zip = Archive::Zip->new();
        
        $zip->read($DistArchive);
        $zip->extractTree();

        # TODO: Check for Archive::Zip errors
    }
    else {
        # TODO: Log/report error on wrong file type

        return;
    }
    
    chdir($Cwd);

    my ($DistDir) = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $TempDir,
        Filter    => '*'
    );

    return $DistDir;
}

sub UpdateDatabase {
    my ($Self, %Param) = @_;

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

    $UpdateDBObject->UpdateSchema($$CurrentSchemaRef, $$DistSchemaRef);

    $UpdateDBObject->UpdateData($$CurrentInitRef, $$DistInitRef);
}

1;
