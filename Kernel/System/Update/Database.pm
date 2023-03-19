# --
# Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Update::Database;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::XML',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

# Parses database schema as XML and returns an array of hashes representing
# tables:
# 
# $Tables = [
#     {
#         Name    => 'user',
#         Columns => [
#             {
#                 Name => 'login',
#                 Type => 'VARCHAR'
#             },
#             ...
#         ],
#         Indices     => [ ... ],
#         ForeignKeys => [ ... ],
#         Unique      => [ ... ]
#     },
#     ...
# ]
sub ParseSchemaXML {
    my ($Self, $XML) = @_;

    my @Tables;

    my (%Column, %ForeignKey, %Index, %IndexColumn, %Reference, %Table, %Unique,
        %UniqueColumn);
    my %Attrs = (
        'Column' => [
            qw( AutoIncrement Default Name PrimaryKey Required Size Type )
        ],
        'Reference' => [ qw( Foreign Local ) ]
    );

    my @Tags = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
        String => $XML
    );

    for my $Tag (@Tags) {
        # <Table>
        if ($Tag->{Tag} eq 'Table') {
            if ($Tag->{TagType} eq 'Start') {
                %Table = (
                    Name        => $Tag->{Name},
                    Columns     => [],
                    Indices     => [],
                    ForeignKeys => [],
                    Unique      => []
                );
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @Tables, { %Table };
            }
        }
        # <Column>
        elsif ($Tag->{Tag} eq 'Column') {
            if ($Tag->{TagType} eq 'Start') {
                %Column = ();
                for my $Attr (@{$Attrs{$Tag->{Tag}}}) {
                    $Column{$Attr} = $Tag->{$Attr} if exists $Tag->{$Attr};
                }
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$Table{Columns}}, { %Column };
            }
        }
        # <Index>
        elsif ($Tag->{Tag} eq 'Index') {
            if ($Tag->{TagType} eq 'Start') {
                %Index = (
                    Name         => $Tag->{Name},
                    IndexColumns => []
                );
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$Table{Indices}}, { %Index };
            }
        }
        # <IndexColumn>
        elsif ($Tag->{Tag} eq 'IndexColumn') {
            if ($Tag->{TagType} eq 'Start') {
                %IndexColumn = (
                    Name => $Tag->{Name}
                );
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$Index{IndexColumns}}, { %IndexColumn };
            }
        }
        # <Unique>
        elsif ($Tag->{Tag} eq 'Unique') {
            if ($Tag->{TagType} eq 'Start') {
                %Unique = (
                    Name          => $Tag->{Name},
                    UniqueColumns => []
                );
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$Table{Unique}}, { %Unique };
            }
        }
        # <UniqueColumn>
        elsif ($Tag->{Tag} eq 'UniqueColumn') {
            if ($Tag->{TagType} eq 'Start') {
                %UniqueColumn = (
                    Name => $Tag->{Name}
                );
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$Unique{UniqueColumns}}, { %UniqueColumn };
            }
        }
        # <ForeignKey>
        elsif ($Tag->{Tag} eq 'ForeignKey') {
            if ($Tag->{TagType} eq 'Start') {
                %ForeignKey = (
                    ForeignTable => $Tag->{ForeignTable},
                    References   => []
                );
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$Table{ForeignKeys}}, { %ForeignKey };
            }
        }
        # <Reference>
        elsif ($Tag->{Tag} eq 'Reference') {
            if ($Tag->{TagType} eq 'Start') {
                %Reference = ();
                for my $Attr (@{$Attrs{$Tag->{Tag}}}) {
                    $Reference{$Attr} = $Tag->{$Attr} if exists $Tag->{$Attr};
                }
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$ForeignKey{References}}, { %Reference };
            }
        }
        # <database>
        elsif ($Tag->{Tag} eq 'database') {
            # No-op
        }
        else {
            # TODO: Handle error properly
            print STDERR "Unknown tag $Tag->{Tag}\n";
            exit 1;
        }
    }

    return \@Tables;
}

# Parses initial insert XML and returns an array of hashes, representing records
# to be inserted into tables.
#
# $Tables = [
#     {
#         name => 'ticket',
#         data => [
#             {
#                 Key     => 'title',
#                 Content => 'Example Ticket'
#             },
#             ...
#         ]
#     },
#     {
#         ...    
#     },
#     ...
# ]
sub ParseInsertXML {
    my ($Self, $XML) = @_;

    my @Tables;

    my ($Table, @Insert);

    my @Tags = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
        String => $XML
    );

    for my $Tag (@Tags) {
        if ($Tag->{Tag} eq 'Insert') {
            if ($Tag->{TagType} eq 'Start') {
                ($Table) = grep { $_->{name} eq $Tag->{Table} } @Tables;

                if (!defined $Table) {
                    $Table = {
                        name => $Tag->{Table},
                        data => []
                    };
                    push @Tables, $Table;
                }

                @Insert = ();
            }
            elsif ($Tag->{TagType} eq 'End') {
                push @{$Table->{data}}, [ @Insert ];
            }
        }
        elsif ($Tag->{Tag} eq 'Data') {
            if ($Tag->{TagType} eq 'Start') {
                my $Data = {};
                for my $Attr (qw( Key Translatable Type )) {
                    $Data->{$Attr} = $Tag->{$Attr} if exists $Tag->{$Attr};
                }
                $Data->{Content} = $Tag->{Content};
                push @Insert, $Data;
            }
        }
        elsif ($Tag->{Tag} eq 'database') {
            # No-op
        }
        else {
            # TODO: Handle error properly
            print STDERR "Unknown tag $Tag->{Tag}\n";
            exit 1;
        }
    }

    return \@Tables;
}



# Compares two hashes representing a database table before and after changes
# (as returned by ParseSchemaXML) and returns a hash of differences:
#
# $TableDiff = {
#     ColumnsAdded => [
#         {
#             Name => 'status',
#             Type => 'INTEGER'
#         },
#         ...
#     ],
#     ColumnsChanged => [ ... ],
#     ColumnsRemoved => [ ... ]
# }
sub TableDiff {
    my ($Self, $TableBefore, $TableAfter) = @_;

    my (@ColumnsAdded, @ColumnsChanged, @ColumnsRemoved);

    my @ColumnsBefore = @{$TableBefore->{Columns}};
    my @ColumnsAfter  = @{$TableAfter->{Columns}};

    for my $Column (@ColumnsAfter) {
        if (!grep { $_->{Name} eq $Column->{Name} } @ColumnsBefore) {
            push @ColumnsAdded, $Column;
        }
    }
    # TODO: ColumnsChanged, ColumnsRemoved

    my (@ForeignKeysAdded, @ForeignKeysChanged, @ForeignKeysRemoved);

    my @ForeignKeysBefore = @{$TableBefore->{ForeignKeys}};
    my @ForeignKeysAfter  = @{$TableAfter->{ForeignKeys}};

    for my $ForeignKey (@ForeignKeysAfter) {
        if (!grep { $_->{ForeignTable} eq $ForeignKey->{ForeignTable} }
            @ForeignKeysBefore)
        {
            push @ForeignKeysAdded, $ForeignKey;
        }
    }

    my (@UniqueAdded, @UniqueChanged, @UniqueRemoved);

    my @UniqueBefore = @{$TableBefore->{Unique}};
    my @UniqueAfter  = @{$TableAfter->{Unique}};

    for my $Unique (@UniqueAfter) {
        if (!grep { $_->{Name} eq $Unique->{Name} } @UniqueBefore) {
            push @UniqueAdded, $Unique;
        }
    }

    # Don't return anything if nothing has changed
    return if !(
        @ColumnsAdded     || @ColumnsChanged     || @ColumnsRemoved     ||
        @UniqueAdded      || @UniqueChanged      || @UniqueRemoved      ||
        @ForeignKeysAdded || @ForeignKeysChanged || @ForeignKeysRemoved
    );

    return {
        ColumnsAdded     => \@ColumnsAdded,
        ColumnsChanged   => \@ColumnsChanged,
        ColumnsRemoved   => \@ColumnsRemoved,
        ForeignKeysAdded => \@ForeignKeysAdded,
        UniqueAdded      => \@UniqueAdded,
    };
}

# Generates XML document for database schema update based on results
# of TableDiff.
sub GenerateSchemaUpdateXML {
    my ($Self, $Differences) = @_;

    my $XML = '';

    sub _Attr {
        my ($Item, $Name) = @_;

        if (exists $Item->{$Name}) {
            my $Value = $Item->{$Name};

            # Replace unsafe characters with entities
            $Value =~ s/&/&amp;/sg;
            $Value =~ s/</&lt;/sg;
            $Value =~ s/>/&gt;/sg;
            $Value =~ s/"/&quot;/sg;
        
            return "$Name=\"$Value\" ";
        }
        else {
            return '';
        }
    }

    # FIXME: Get database name from configuration
    $XML .= sprintf("<database Name=\"%s\">\n", 'otrs');

    for my $Table (@{$Differences->{TablesAdded}}) {
        $XML .= sprintf("<TableCreate Name=\"%s\">\n", $Table->{Name});

        for my $Column (@{$Table->{Columns}}) {
            $XML .= sprintf("<Column Name=\"%s\" Type=\"%s\" %s/>\n",
                $Column->{Name},
                $Column->{Type},
                _Attr($Column, 'AutoIncrement') .
                _Attr($Column, 'Default') .
                _Attr($Column, 'PrimaryKey') .
                _Attr($Column, 'Required') .
                _Attr($Column, 'Size')
            );
        }

        for my $Index (@{$Table->{Indices}}) {
            $XML .= sprintf("<Index Name=\"%s\">\n", $Index->{Name});

            for my $IndexColumn (@{$Index->{IndexColumns}}) {
                $XML .= sprintf("  <IndexColumn Name=\"%s\"/>\n",
                    $IndexColumn->{Name}
                );
            }

            $XML .= "</Index>\n";
        }

        for my $Unique (@{$Table->{Unique}}) {
            $XML .= sprintf("<Unique Name=\"%s\">\n", $Unique->{Name});

            for my $UniqueColumn (@{$Unique->{UniqueColumns}}) {
                $XML .= sprintf("  <UniqueColumn Name=\"%s\"/>\n",
                    $UniqueColumn->{Name}
                );
            }

            $XML .= "</Unique>\n";
        }

        for my $ForeignKey (@{$Table->{ForeignKeys}}) {
            $XML .= sprintf("<ForeignKey ForeignTable=\"%s\">\n",
                $ForeignKey->{ForeignTable});

            for my $Reference (@{$ForeignKey->{References}}) {
                $XML .= sprintf("  <Reference Local=\"%s\" Foreign=\"%s\"/>\n",
                    $Reference->{Local},
                    $Reference->{Foreign}
                );
            }

            $XML .= "</ForeignKey>\n";
        }

        $XML .= "</TableCreate>\n";
    }

    for my $Table (@{$Differences->{TablesChanged}}) {
        $XML .= sprintf("<TableAlter Name=\"%s\">\n", $Table->{Name});

        for my $Column (@{$Table->{ColumnsAdded}}) {
            $XML .= sprintf("<ColumnAdd Name=\"%s\" Type=\"%s\" %s/>\n",
                $Column->{Name},
                $Column->{Type},
                _Attr($Column, 'AutoIncrement') .
                _Attr($Column, 'Default') .
                _Attr($Column, 'PrimaryKey') .
                _Attr($Column, 'Required') .
                _Attr($Column, 'Size')
            );
        }

        # TODO: Altered and removed columns

        # TODO: Indices and foreign keys

        for my $ForeignKey (@{$Table->{ForeignKeysAdded}}) {
            $XML .= sprintf("<ForeignKeyCreate ForeignTable=\"%s\">\n",
                $ForeignKey->{ForeignTable});

            for my $Reference (@{$ForeignKey->{References}}) {
                $XML .= sprintf("  <Reference Local=\"%s\" Foreign=\"%s\"/>\n",
                    $Reference->{Local},
                    $Reference->{Foreign}
                );
            }

            $XML .= "</ForeignKeyCreate>\n";
        }

        $XML .= "</TableAlter>\n";
    }

    $XML .= "</database>\n";

    return $XML;
}

# Converts data for a single table, represented as an array (table) of arrays 
# (record) of hashes (fields) into a string by concatenating all fields.
sub SerializeInsertData {
    my ($Self, $Data) = @_;

    my $Serialized = '';

    for my $Record (@$Data) {
        for my $Field (@$Record) {
            for my $Key (sort keys %$Field) {
                $Serialized .= $Key . ' ' . ($Field->{$Key} // '') . ';';
            }
        }
        $Serialized .= "\n";
    }

    return $Serialized;
}

sub UpdateSchema {
    my ($Self, $CurrentSchema, $NewSchema) = @_;

    my $CurrentTables = $Self->ParseSchemaXML($CurrentSchema);
    my $NewTables     = $Self->ParseSchemaXML($NewSchema);

    my (@TablesAdded, @TablesChanged);

    for my $NewTable (@$NewTables) {
        my ($CurrentTable) =
            grep { $_->{Name} eq $NewTable->{Name} } @$CurrentTables;
        
        if (defined $CurrentTable) {
            my $Diff = $Self->TableDiff($CurrentTable, $NewTable);

            if (defined $Diff) {
                push @TablesChanged, {
                    Name => $NewTable->{Name},
                    %$Diff
                }
            }
        }
        else {            
            push @TablesAdded, $NewTable;
        }
    }

    my $UpdateXML = $Self->GenerateSchemaUpdateXML({
        TablesAdded   => \@TablesAdded,
        TablesChanged => \@TablesChanged
    });

    if (length($UpdateXML) > 0) {
        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        my @UpdateSQL = $DBObject->SQLProcessor(
            Database => [
                $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
                    String => $UpdateXML
                )
            ]
        );

        $DBObject->Do(SQL => $_) for @UpdateSQL;
    }

    return 1;
}

sub UpdateData {
    my ($Self, $CurrentInit, $NewInit) = @_;

    my $CurrentInserts = $Self->ParseInsertXML($CurrentInit);
    my $NewInserts     = $Self->ParseInsertXML($NewInit);

    my @CurrentTables = map { $_->{name} } @$CurrentInserts;
    my @NewTables     = map { $_->{name} } @$NewInserts;
    
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    Table:
    for my $Table (@NewTables) {
        my ($CurrentTable) = grep { $_ eq $Table } @CurrentTables;
        
        if (!defined $CurrentTable) {
            # Table doesn't exist in current schema -- safe to insert all data

            # TODO: Regenerate <Insert> tags from data
        }
        else {
            # Serialize data
            my $CurrentData =
                (grep { $_->{name} eq $Table } @$CurrentInserts)[0]->{data};
            my $CurrentDataSerialized =
                $Self->SerializeInsertData($CurrentData);
            my $NewData =
                (grep { $_->{name} eq $Table } @$NewInserts)[0]->{data};
            my $NewDataSerialized = $Self->SerializeInsertData($NewData);
            
            next Table if $CurrentDataSerialized eq $NewDataSerialized;

            for my $Record (@$NewData) {
                my ($IDField) = grep {
                    exists $_->{Type} && $_->{Type} eq 'AutoIncrement'
                } @$Record;

                # Find the current record with the same ID
                my ($CurrentRecord) = grep {
                    grep { 
                        exists $_->{Type} &&
                            $_->{Type} eq 'AutoIncrement' &&
                            $_->{Content} eq $IDField->{Content}
                    } @$_
                } @$CurrentData;

                my @Conditions;

                Field:
                for my $Field (@$CurrentRecord) {
                    if ($Field->{Key} =~ /_time$/ &&
                        $Field->{Content} eq 'current_timestamp')
                    {
                        next Field;
                    }

                    my $Value = $Field->{Content};
                    
                    if (!defined $Value) {
                        $Value = 'NULL';
                    }
                    elsif (exists $Field->{Type} && $Field->{Type} eq 'Quote') {
                        $Value = "'" . $DBObject->Quote($Value) . "'";
                    }

                    push @Conditions, $Field->{Key} . ' = ' . $Value;
                }

                my @Updates;

                for my $Field (@$Record) {
                    my $Value = $Field->{Content};

                    if (!defined $Value) {
                        $Value = 'NULL';
                    }
                    elsif (exists $Field->{Type} && $Field->{Type} eq 'Quote') {
                        $Value = "'" . $DBObject->Quote($Value) . "'";
                    }

                    push @Updates, $Field->{Key} . ' = ' . $Value;
                }

                my $UpdateQuery = sprintf("UPDATE $Table SET %s WHERE %s;",
                    join(', ', @Updates), join(' AND ', @Conditions));

                # TODO: Execute the query
            }
        }
    }

    return 1;
}

1;
