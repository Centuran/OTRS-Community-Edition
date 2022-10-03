# --
# Copyright (C) 2022 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package scripts::DBUpdateTo6::UpgradeDatabaseStructure::NewOAuth2Tables;    ## no critic

use strict;
use warnings;

use parent qw(scripts::DBUpdateTo6::Base);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

scripts::DBUpdateTo6::UpgradeDatabaseStructure::NewOAuth2Tables - Adds new tables for OAuth2 authentication

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Verbose = $Param{CommandlineOptions}->{Verbose} || 0;

    my @XMLStrings = (
        # oauth2_token_config
        '<TableCreate Name="oauth2_token_config">
            <Column Name="id" Required="true" PrimaryKey="true" AutoIncrement="true" Type="INTEGER"/>
            <Column Name="name" Required="true" Size="250" Type="VARCHAR"/>
            <Column Name="config" Required="true" Size="5000" Type="VARCHAR"/>
            <Column Name="valid_id" Required="true" Type="SMALLINT"/>
            <Column Name="create_time" Required="true" Type="DATE"/>
            <Column Name="create_by" Required="true" Type="INTEGER"/>
            <Column Name="change_time" Required="true" Type="DATE"/>
            <Column Name="change_by" Required="true" Type="INTEGER"/>
            <Unique Name="oauth2_token_config_name">
                <UniqueColumn Name="name"/>
            </Unique>
            <ForeignKey ForeignTable="valid">
                <Reference Local="valid_id" Foreign="id"/>
            </ForeignKey>
            <ForeignKey ForeignTable="users">
                <Reference Local="create_by" Foreign="id"/>
                <Reference Local="change_by" Foreign="id"/>
            </ForeignKey>
        </TableCreate>',

        # oauth2_token
        '<TableCreate Name="oauth2_token">
            <Column Name="id" Required="true" PrimaryKey="true" AutoIncrement="true" Type="INTEGER"/>
            <Column Name="config_id" Required="true" Type="INTEGER"/>
            <Column Name="authorization_code" Required="false" Size="10000" Type="VARCHAR"/>
            <Column Name="token" Required="false" Size="10000" Type="VARCHAR"/>
            <Column Name="token_expiration_date" Required="false" Type="DATE"/>
            <Column Name="refresh_token" Required="false" Size="10000" Type="VARCHAR"/>
            <Column Name="refresh_token_expiration_date" Required="false" Type="DATE"/>
            <Column Name="error_message" Required="false" Size="2000" Type="VARCHAR"/>
            <Column Name="error_description" Required="false" Size="2000" Type="VARCHAR"/>
            <Column Name="error_code" Required="false" Size="250" Type="VARCHAR"/>
            <Column Name="create_time" Required="true" Type="DATE"/>
            <Column Name="create_by" Required="true" Type="INTEGER"/>
            <Column Name="change_time" Required="true" Type="DATE"/>
            <Column Name="change_by" Required="true" Type="INTEGER"/>
            <Unique Name="oauth2_token_config_id">
                <UniqueColumn Name="config_id"/>
            </Unique>
            <ForeignKey ForeignTable="oauth2_token_config">
                <Reference Local="config_id" Foreign="id"/>
            </ForeignKey>
            <ForeignKey ForeignTable="users">
                <Reference Local="create_by" Foreign="id"/>
                <Reference Local="change_by" Foreign="id"/>
            </ForeignKey>
        </TableCreate>',
    );

    return if !$Self->ExecuteXMLDBArray(
        XMLArray => \@XMLStrings,
    );

    return 1;
}

1;
