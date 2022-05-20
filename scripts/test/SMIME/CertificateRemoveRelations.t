# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));
use File::Path qw(mkpath rmtree);

my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
my $ArticleObject   = $Kernel::OM->Get('Kernel::System::Ticket::Article');
my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase  => 1,
        UseTmpArticleDir => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# Disable email addresses checking.
$Helper->ConfigSettingChange(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $HomeDir = $ConfigObject->Get('Home');

# Create directory for certificates and private keys.
my $CertPath    = $ConfigObject->Get('Home') . "/var/tmp/certs";
my $PrivatePath = $ConfigObject->Get('Home') . "/var/tmp/private";
mkpath( [$CertPath],    0, 0770 );    ## no critic
mkpath( [$PrivatePath], 0, 0770 );    ## no critic

# Set SMIME paths.
$ConfigObject->Set(
    Key   => 'SMIME::CertPath',
    Value => $CertPath,
);
$ConfigObject->Set(
    Key   => 'SMIME::PrivatePath',
    Value => $PrivatePath,
);

my $OpenSSLBin = $ConfigObject->Get('SMIME::Bin') || '/usr/bin/openssl';

# Get the openssl version string, e.g. OpenSSL 0.9.8e 23 Feb 2007.
my $OpenSSLVersionString = qx{$OpenSSLBin version};
my $OpenSSLMajorVersion;

# Get the openssl major version, e.g. 1 for version 1.0.0.
if ( $OpenSSLVersionString =~ m{ \A (?: (?: Open|Libre)SSL )? \s* ( \d )  }xmsi ) {
    $OpenSSLMajorVersion = $1;
}

# Openssl version 1.0.0 uses different hash algorithm... in the future release of openssl this might
#   change again in such case a better version detection will be needed.
my $UseNewHashes;
if ( $OpenSSLMajorVersion >= 1 ) {
    $UseNewHashes = 1;
}

$ConfigObject->Set(
    Key   => 'SMIME',
    Value => 1,
);
$ConfigObject->Set(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::DoNotSendEmail',
);

# Check if openssl is located there.
if ( !-e $OpenSSLBin ) {

    # Maybe it's a mac with macport.
    if ( -e '/opt/local/bin/openssl' ) {
        $ConfigObject->Set(
            Key   => 'SMIME::Bin',
            Value => '/opt/local/bin/openssl',
        );
    }
}

my $SMIMEObject = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');

if ( !$SMIMEObject ) {
    print STDERR "NOTICE: No SMIME support!\n";

    if ( !-e $OpenSSLBin ) {
        $Self->False(
            1,
            "No such $OpenSSLBin!",
        );
    }
    elsif ( !-x $OpenSSLBin ) {
        $Self->False(
            1,
            "$OpenSSLBin not executable!",
        );
    }
    elsif ( !-e $CertPath ) {
        $Self->False(
            1,
            "No such $CertPath!",
        );
    }
    elsif ( !-d $CertPath ) {
        $Self->False(
            1,
            "No such $CertPath directory!",
        );
    }
    elsif ( !-w $CertPath ) {
        $Self->False(
            1,
            "$CertPath not writable!",
        );
    }
    elsif ( !-e $PrivatePath ) {
        $Self->False(
            1,
            "No such $PrivatePath!",
        );
    }
    elsif ( !-d $Self->{PrivatePath} ) {
        $Self->False(
            1,
            "No such $PrivatePath directory!",
        );
    }
    elsif ( !-w $PrivatePath ) {
        $Self->False(
            1,
            "$PrivatePath not writable!",
        );
    }
    return 1;
}

# OpenSSL 0.9.x hashes.
my $Check1Hash     = '980a83c7';
my $Check2Hash     = '999bcb2f';
my $OTRSRootCAHash = '1a01713f';
my $OTRSInt1CAHash = '7807c24e';
my $OTRSInt2CAHash = '2fc24258';
my $OTRSUserHash   = 'eab039b6';

# OpenSSL 1.0.0 hashes.
if ($UseNewHashes) {
    $Check1Hash     = '5efb3de7';
    $Check2Hash     = 'd562d84d';
    $OTRSRootCAHash = '8a68405f';
    $OTRSInt1CAHash = '1cfe78a7';
    $OTRSInt2CAHash = '402013e3';
    $OTRSUserHash   = 'ea80eed7';
}

my @Certificates = (
    {
        CertificateName       => 'Check1',
        CertificateHash       => $Check1Hash,
        CertificateFileName   => 'SMIME-certificate-OTRSCE-User-2.crt',
        PrivateKeyFileName    => 'SMIME-private-key-OTRSCE-User-2.pem',
        PrivateSecretFileName => 'SMIME-password.txt',
    },
    {
        CertificateName       => 'Check2',
        CertificateHash       => $Check2Hash,
        CertificateFileName   => 'SMIME-certificate-OTRSCE-User-3.crt',
        PrivateKeyFileName    => 'SMIME-private-key-OTRSCE-User-3.pem',
        PrivateSecretFileName => 'SMIME-password.txt',
    },
    {
        CertificateName       => 'OTRSCEUserCert',
        CertificateHash       => $OTRSUserHash,
        CertificateFileName   => 'SMIME-certificate-OTRSCE-User-1.crt',
        PrivateKeyFileName    => 'SMIME-private-key-OTRSCE-User-1.pem',
        PrivateSecretFileName => 'SMIME-password.txt',
    },
    {
        CertificateName       => 'OTRSCEIntermediateCA2',
        CertificateHash       => $OTRSInt2CAHash,
        CertificateFileName   => 'SMIME-CA-certificate-OTRSCE-CA-Intermediate-2.crt',
        PrivateKeyFileName    => 'SMIME-CA-private-key-OTRSCE-CA-Intermediate-2.pem',
        PrivateSecretFileName => 'SMIME-password.txt',
    },
    {
        CertificateName       => 'OTRSCEIntermediateCA1',
        CertificateHash       => $OTRSInt1CAHash,
        CertificateFileName   => 'SMIME-CA-certificate-OTRSCE-CA-Intermediate-1.crt',
        PrivateKeyFileName    => 'SMIME-CA-private-key-OTRSCE-CA-Intermediate-1.pem',
        PrivateSecretFileName => 'SMIME-password.txt',
    },
    {
        CertificateName       => 'OTRSCERootCA',
        CertificateHash       => $OTRSRootCAHash,
        CertificateFileName   => 'SMIME-CA-certificate-OTRSCE-CA-Root.crt',
        PrivateKeyFileName    => 'SMIME-CA-private-key-OTRSCE-CA-Root.pem',
        PrivateSecretFileName => 'SMIME-password.txt',
    },
);

# Add chain certificates.
for my $Certificate (@Certificates) {

    # Add certificate.
    my $CertString = $MainObject->FileRead(
        Directory => $ConfigObject->Get('Home') . "/scripts/test/sample/SMIME/",
        Filename  => $Certificate->{CertificateFileName},
    );
    my %Result = $SMIMEObject->CertificateAdd( Certificate => ${$CertString} );
    $Self->True(
        $Result{Successful} || '',
        "#$Certificate->{CertificateName} CertificateAdd() - $Result{Message}",
    );

    # Add private key.
    my $KeyString = $MainObject->FileRead(
        Directory => $ConfigObject->Get('Home') . "/scripts/test/sample/SMIME/",
        Filename  => $Certificate->{PrivateKeyFileName},
    );
    my $Secret = $MainObject->FileRead(
        Directory => $ConfigObject->Get('Home') . "/scripts/test/sample/SMIME/",
        Filename  => $Certificate->{PrivateSecretFileName},
    );
    %Result = $SMIMEObject->PrivateAdd(
        Private => ${$KeyString},
        Secret  => ${$Secret},
    );
    $Self->True(
        $Result{Successful} || '',
        "#$Certificate->{CertificateName} PrivateAdd()",
    );
}

my $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');

my @CertList = $CryptObject->CertificateList();

my $Cert1 = $CertList[0];
my $Cert2 = $CertList[1];

my %Cert1Attributes = $CryptObject->CertificateAttributes(
    Certificate => $CryptObject->CertificateGet( Filename => $Cert1 ),
    Filename    => $Cert1,
);
my %Cert2Attributes = $CryptObject->CertificateAttributes(
    Certificate => $CryptObject->CertificateGet( Filename => $Cert2 ),
    Filename    => $Cert2,
);

my @Data = $CryptObject->SignerCertRelationGet(
    CertFingerprint => $Cert1Attributes{Fingerprint},
);
$Self->False(
    @Data ? 1 : 0,
    'Certificate 1 has no relations',
);
@Data = $CryptObject->SignerCertRelationGet(
    CertFingerprint => $Cert2Attributes{Fingerprint},
);
$Self->False(
    @Data ? 1 : 0,
    'Certificate 2 has no relations',
);

$CryptObject->SignerCertRelationAdd(
    CertFingerprint => $Cert1Attributes{Fingerprint},
    CAFingerprint   => $Cert2Attributes{Fingerprint},
    UserID          => 1,
);

@Data = $CryptObject->SignerCertRelationGet(
    CertFingerprint => $Cert1Attributes{Fingerprint},
);
$Self->True(
    @Data ? 1 : 0,
    'Certificate 1 has relations',
);

my $Success = $CryptObject->CertificateRemove(
    Filename => $Cert2,
);
$Self->True(
    @Data ? 1 : 0,
    'Certificate 2 got removed',
);

@Data = $CryptObject->SignerCertRelationGet(
    CertFingerprint => $Cert1Attributes{Fingerprint},
);
$Self->False(
    @Data ? 1 : 0,
    'Certificate 1 has no relations',
);

# Delete needed test directories.
for my $Directory ( $CertPath, $PrivatePath ) {
    my $Success = rmtree( [$Directory] );
    $Self->True(
        $Success,
        "Directory deleted - '$Directory'",
    );
}

# Cleanup is done by RestoreDatabase.

1;
