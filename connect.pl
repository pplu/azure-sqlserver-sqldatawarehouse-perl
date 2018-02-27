#!/usr/bin/perl

use v5.10;
use warnings;
use strict;

use DBI;
use Data::Dumper;

my ($host, $db, $user, $password) = @ARGV;

if (not defined $host or not defined $db or
    not defined $user or not defined $host) {
  die "Usage: $0 host database username password\n";
}

# Connect to the data source and get a handle for that connection.
my $dbh = DBI->connect("dbi:ODBC:Driver=ODBC Driver 13 for SQL Server;Server=$host;Database=$db", $user, $password, { RaiseError => 1, PrintError => 0 });

# eval==try in Perl. Just eat the exception if the table already exists
eval {
  $dbh->do('CREATE TABLE Inventory (id INT, name NVARCHAR(50), quantity INT)');
};

$dbh->do("INSERT INTO Inventory VALUES (1, 'banana', 150); INSERT INTO Inventory VALUES (2, 'orange', 154)");

my $sth = $dbh->prepare('SELECT * FROM Inventory');

$sth->execute;

while (my $row = $sth->fetchrow_hashref) {
  say Dumper($row);
}

$dbh->disconnect;
