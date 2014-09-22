#!@PERL_COMMAND@

# $Id: smbldap-groupdel.pl 121 2011-10-07 05:40:06Z fumiyas $

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

# Purpose of smbldap-groupdel : group (posix) deletion

use strict;
use warnings;
use smbldap_tools;

#####################
use Getopt::Std;
my %Options;

my $ok = getopts('?', \%Options);
if ( (!$ok) || (@ARGV < 1) || ($Options{'?'}) ) {
    print_banner;
    print "Usage: $0 groupname\n";
    print "  -?	show this help message\n";
    exit (1);
}

my $_groupName = $ARGV[0];

my $ldap_master=connect_ldap_master();

my $dn_line;
if (!defined($dn_line = get_group_dn($_groupName))) {
    print "$0: group $_groupName doesn't exist\n";
    exit (6);
}

my $dn = get_dn_from_line($dn_line);

group_del($dn);

nsc_invalidate("group");

#if (defined($dn_line = get_group_dn($_groupName))) {
#    print "$0: failed to delete group\n";
#    exit (7);
#}

# take down session
$ldap_master->unbind;


exit (0);

############################################################

=head1 NAME

smbldap-groupdel - Delete a group

=head1 SYNOPSIS

smbldap-groupdel group

=head1 DESCRIPTION

The smbldap-groupdel command modifies the system account files, deleting all entries that refer to a group. The named group must exist.

You must manually check all filesystems to insure that no files remain
with the named group as the file group ID.

=head1 SEE ALSO

groupdel(1)

=cut

#'
