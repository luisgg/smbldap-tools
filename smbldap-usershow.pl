#!@PERL_COMMAND@

# $Id: smbldap-usershow.pl 121 2011-10-07 05:40:06Z fumiyas $

#  This code was developped by Jerome Tournier (jtournier@gmail.com) and
#  contributors (their names can be found in the CONTRIBUTORS file).

#  This was first contributed by IDEALX (http://www.opentrust.com/)

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Purpose of smbldap-userdisplay : user (posix,shadow,samba) display

use strict;
use warnings;
use smbldap_tools;

use Getopt::Std;
my %Options;

my $ok = getopts('hX:?',\%Options);

if ( (!$ok) || (@ARGV < 1) || ($Options{'?'}) ) {
    print_banner;
    print "Usage: $0 [-hX?] username\n";
    print "  -h	print Samba dates in human-readable form\n";
    print "  -X	output character set (default UTF-8)\n";
    print "  -?	show this help message\n";
    exit (1);
}

# Read only first @ARGV
my $user = $ARGV[0];

# Get the input encoding
my $characterSet;
if ( defined( $Options{'X'} ) ) {
	$characterSet = $Options{'X'};
} else {
	$characterSet = "UTF-8";
}

my $ldap_slave=connect_ldap_slave();

my $lines;
if ($Options{'h'}) {
	$lines = utf8Decode($characterSet,read_user_human_readable($user));
} else {
	$lines = utf8Decode($characterSet,read_user($user));
}

if ($lines) {
    print "$lines\n";
} else {
    print "user $user doesn't exist\n";
    exit (1);
}

# take down session
$ldap_slave->unbind;

exit(0);

############################################################

=head1 NAME

smbldap-usershow - Show a user account informations

=head1 SYNOPSIS

smbldap-usershow login

=head1 DESCRIPTION

The smbldap-usershow command displays the informations associated with the login. The named user must exist.

=cut

#'
