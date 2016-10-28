# allyouruarecordarebelongtous
Perl data parsing script for UA Record data

As of October 26, 2016 only databases extracted from Android devices with the UA Record app are supported.

Please note, in order to run the script you may have to install some Perl modules. On a Windows system, to do this open a command prompt and paste the following command:

ppm install DBI DBD::SQLite DateTime IO::All


On OSX/nix system, open a terminal window and paste the following command:

sudo cpan DBI DBD::SQLite DateTime IO::All
