# Using Azure SQL Database and Azure SQL DataWarehouse with Perl

Azure SQL Database and Azure SQL DataWarehouse are two Azure services that are
based on SQL Server tecnology. The databases are hosted and managed by Azure, 
so you don't have to worry about installing Microsofts' SQL Server on a VM.

Hosted database services are part of what makes Cloud attractive to me. In the
traditional infrastructure world you have one big (and redundant) database server
where everything goes. In the cloud you can have one small database server for each
project, since things like PITR and backups are built-in. 

One of Azures' most mature offerings is Azure SQL Database. Finding documentation
on how to consume some traditionally Windows-centric services for some environments
is sometimes challenging, so this article will guide you for connecting to the 
Azure Database service from Perl.

Note: this article is specific for the Azure hosted cloud services. If you're looking
for connecting to a traditional SQL Server, [this](https://github.com/pplu/perl-mssql-server)
may help.

# Some backgroud

Connecting from a Linux environment to SQL Server is traditionally done via the ODBC (Open
Database Connectivity) API. This API defines a common API for programming languages to bind
to, letting the details of how to talk to the database be dealt with drivers. Traditionally
there was an Open Source project called FreeTDS which provided an ODBC interface, with nothing
official from Microsoft. But times change, and Microsoft released recently an ODBC driver for SQL
Server for Linux and MacOS environments. So we'll go full speed in this article using the
official MS ODBC driver.

# Preparing the environment:

The base for the article is an Azure Debian 8 (jessie) VM as provided by Azure. Provision a Debian 8
VM inside a new Resource Group. Also provision an SQL Database and an SQL data warehouse in
the same Resource Group (this is basically so we can clean up without hassle). Once we have
the two databases provisioned, we have to open their firewall rules to permit the IP of the
VM we have created. Please take good note of the server name, the names of the dbs you've created,
the usernames and the passwords for the databases.

Now log in to the Debian VM:

We'll use Perls' carton bundler to install the latest versions of some dependencies (DBI, DBD::ODBC) in a local directory (so it doesn't mess up the system). Also we'll need git to download our sample script and build-essential because we'll be compiling some of the Perl modules
```
sudo apt-get install -y carton git build-essential
```

We'll need the UNIX ODBC library, and its' dev package (to compile the DBD::ODBC module)
```
sudo apt-get install -y unixodbc unixodbc-dev
```

Now we'll need to install the Microsoft ODBC driver. [Debian packages](https://docs.microsoft.com/es-es/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server)

```
sudo su -
apt-get install -y apt-transport-https curl
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list
apt-get update
ACCEPT_EULA=Y apt-get install msodbcsql
exit
```

Now we'll download the example script from this repo
```
git clone https://github.com/pplu/azure-sqlserver-sqldatawarehouse-perl.git
cd azure-sqlserver-sqldatawarehouse-perl
```
Now install the local dependencies with carton (they are in the cpanfile of the repository)
```
carton install
```

# Connecting to the Azure SQL

```
carton exec ./connect.pl server_name db_name username password
```
Will create a table and insert some rows in it. You're done! Happy Hacking

# Additional notes

## Named DSN

In the example, the DSN for ODBC is inlined in the connect call to DBI. You can connect via a named DSN also.

```
my $dbh = DBI->connect("dbi:ODBC:testdsn", $user, $password, { RaiseError => 1 });
```

With the `odbcinst -q -s` command you can see what DSNs are configured in your system. In the example we're using `testdsn`

In /etc/odbc.ini you should have:

```
[ODBC Data Sources]
data_source_name = testdsn

[testdsn]
Driver = /opt/microsoft/msodbcsql/lib64/libmsodbcsql-13.1.so.9.1
DESCRIPTION = Microsoft ODBC Driver 13 for SQL Server
SERVER=localhost,1401
```

## libiodbc2 incompatibility
 
It looks like the DBD::ODBC has problems if you have libiodbc2 installed.
If you don't want to uninstall libodbc2, just take a look at 
[this stack overflow question](https://stackoverflow.com/questions/11354288/undefined-symbol-sqlallochandle-using-perl-on-ubuntu) for how to avoid the problem without removing libodbc2

```
sudo apt-get remove --purge libiodbc2
```

## Why didn't you use Debian 9 (stretch)?

I didn't use Debian 9 (stretch) because the msodbcsql package isn't there (although it's
announced to be released). This seems like a transitive problem with the Microsoft Debian 
repos, but I've prefered to document a working solution. You should be able to do the 
same steps on Debian 9 (with the precaution of changing the 8 for a 9 when configuring the Debian repos).
If you don't the following error will happen.


## Can't open lib libmsodbcsql: file not found (SQL-01000) error

I was getting this error when connecting:

```
user@DebianHost:~/azure-sqlserver-sqldatawarehouse-perl$ carton exec perl connect.pl
DBI connect('Driver=ODBC Driver 13 for SQL Server;Server=xxx.database.windows.net','user',...)
failed: [unixODBC][Driver Manager]Can't open lib '/opt/microsoft/msodbcsql/lib64/libmsodbcsql-13.1.so.9.2' : file not found (SQL-01000) at connect.pl line 16.
```

Strangely, the file reported as not found was on the filesystem (ls would report it without problems).
I finally found out what was happening: `/opt/microsoft/msodbcsql/lib64/libmsodbcsql-13.1.so.9.2` is 
dynamically linked against other libraries.

```
ldd /opt/microsoft/msodbcsql/lib64/libmsodbcsql-13.1.so.9.2 | grep "not found"
```

gave away the problem. The "not found" was due to other .so's missing (not the 
libmsodbcsql-13.1.so.9.2 itself). The problem was that I had installed the ODBC driver 
from the the Debian 8 repositories on Debian 9 because I had mis-copied the Debian 
apt repo paths (ups!). I'm documenting this because I suspect this can happen to anyone, 
hoping that Google will index it high enough for it to be found easily.

# Can you get the Debian 8 msodbcsql package to work on Debian 9?

You can install the Debian 8 msodbcsql package on Debian 9 just using the Microsoft repositiores
for Debian 8, but as you know from the last paragraph, it's broken.
You can rest your system into submission by installing the libssl package that belongs to Debian 8
(which has the appropiate missing libraries).

```
wget http://ftp.de.debian.org/debian/pool/main/o/openssl/libssl1.0.0_1.0.2l-1~bpo8+1_amd64.deb
sudo dpkg -i libssl1.0.0_1.0.2l-1~bpo8+1_amd64.deb
```

I really don't know what sort of pain is in for you if you do this. The example script works,
but there may be dragons down the road. You've been warned.

# Additional links that helped me get this running:

https://github.com/pplu/perl-mssql-server

https://stackoverflow.com/questions/4905624/how-do-i-connect-with-perl-to-sql-server

https://metacpan.org/pod/DBD::ODBC

https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker

https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-docker

https://www.connectionstrings.com/sql-server/

# Author, Copyright and License

This article was authored by Jose Luis Martinez Torres

This article is (c) 2018 CAPSiDE, Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

The canonical, up-to-date source is [GitHub](https://github.com/pplu/azure-sqlserver-sqldatawarehouse-perl). Feel free to contribute back

