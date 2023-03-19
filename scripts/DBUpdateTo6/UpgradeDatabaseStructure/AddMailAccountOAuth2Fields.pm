# --
# Copyright (C) 2022-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package scripts::DBUpdateTo6::UpgradeDatabaseStructure::AddMailAccountOAuth2Fields;    ## no critic

use strict;
use warnings;

use parent qw(scripts::DBUpdateTo6::Base);

our @ObjectDependencies = ();

=head1 NAME

scripts::DBUpdateTo6::UpgradeDatabaseStructure::AddMailAccountOAuth2Fields - add OAuth2 fields to mail_account table

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Verbose = $Param{CommandlineOptions}->{Verbose} || 0;

    my @XMLStrings = (
        '<TableAlter Name="mail_account">
            <ColumnAdd Name="auth_method" Type="VARCHAR" Default="password" Required="true" Size="100" />
            <ColumnAdd Name="oauth2_token_config_id" Type="INTEGER" Required="false" />
            <ForeignKeyCreate ForeignTable="oauth2_token_config">
                <Reference Local="oauth2_token_config_id" Foreign="id"/>
            </ForeignKeyCreate>
        </TableAlter>',
    );

    return if !$Self->ExecuteXMLDBArray(
        XMLArray => \@XMLStrings,
    );

    return 1;
}

1;
