# --
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

use Time::HiRes qw( time );

use Kernel::Output::HTML::FilterText::URL;

my $LongDomainName = 'www.' . ('long-' x 30) . 'test-name.com';
(my $TrimmedDomainName = $LongDomainName) =~ s/^ (.{75}) .* $/$1\[..\]/x;

my %TestStrings = (
    'www.test.com'          => '<a href="http://www.test.com" target="_blank" title="http://www.test.com">www.test.com</a>',
    'ftp.test.com'          => '<a href="ftp://ftp.test.com" target="_blank" title="ftp://ftp.test.com">ftp.test.com</a>',
    'prefix.www.test.com'   => '<a href="http://prefix.www.test.com" target="_blank" title="http://prefix.www.test.com">prefix.www.test.com</a>',
    'prefix.ftp.test.com'   => '<a href="http://prefix.ftp.test.com" target="_blank" title="http://prefix.ftp.test.com">prefix.ftp.test.com</a>',
    "text<$LongDomainName>" => "text<<a href=\"http://$LongDomainName\" target=\"_blank\" title=\"http://$LongDomainName\">$TrimmedDomainName</a>>",

    ('a' x 50000)           => ('a' x 50000),
);
my $TimeLimit = 3;

my $Time = time;

for my $String (keys %TestStrings) {
    my $FilterTextURLObject = Kernel::Output::HTML::FilterText::URL->new();

    my $Data = $String;

    $FilterTextURLObject->Pre( Data => \$Data );
    $FilterTextURLObject->Post( Data => \$Data );

    $Self->Is(
        $Data,
        $TestStrings{$String},
        "The correct output is returned for string \"$String\""
    );
}

my $TimeElapsed = time - $Time;

$Self->True(
    $TimeElapsed <= $TimeLimit,
    "Processing took no more than $TimeLimit second(s)"
);

1;
