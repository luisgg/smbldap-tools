#!@PERL_COMMAND@

# $Id: smbldap-userdel.pl 121 2011-10-07 05:40:06Z fumiyas $

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

# Purpose of smbldap-userdel : user (posix,shadow,samba) deletion

use strict;
use warnings;
use smbldap_tools;


#####################

use Getopt::Std;
my %Options;

my $ok = getopts('rR?', \%Options);

if ( (!$ok) || (@ARGV < 1) || ($Options{'?'}) ) {
    print_banner;
    print "Usage: $0 [-rR?] username\n";
    print "  -r	remove home directory\n";
    print "  -R	remove home directory interactively\n";
    print "  -? show this help message\n";
    exit (1);
}

# Read only first @ARGV
my $user = $ARGV[0];

my $ldap_master=connect_ldap_master();

# user must not exist in LDAP
my $user_entry = read_user_entry($user);
if (!defined($user_entry)) {
    warn "User does not exist: $user\n";
    exit (6);
}

# Canonize user name
$user = $user_entry->get_value('uid');

if ($< != 0) {
    print "You must be root to delete an user\n";
    exit (1);
}

my $homedir;
if (defined($Options{'r'}) || defined($Options{'R'})) {
    $homedir=get_homedir($user);
    if ($homedir !~ /^\/.+\/(.*)$user/) {
	print "Refusing to delete this home directory: $homedir\n";
	exit (1);
    }
}

# remove user from groups
my @groups = &find_groups_of($user);
foreach my $gname (@groups) {
    if ($gname ne "") {
	group_remove_member($gname, $user);
    }
}

# XXX
delete_user($user);

# delete dir -- be sure that homeDir is not a strange value
if ($homedir) {
    my @rmargs = ( '-r' );
    if (defined($Options{'R'})) {
	push(@rmargs, '-i');
    } elsif (defined($Options{'r'})) {
	push(@rmargs, '-f');
    }
    # print "rm @rmargs $homedir\n";
    system('rm', @rmargs, $homedir);
}

nsc_invalidate("passwd");

$ldap_master->unbind;		# take down session

exit (0);

############################################################

=head1 NAME

smbldap-userdel - Delete a user account and related files

=head1 SYNOPSIS

smbldap-userdel [-r] login

=head1 DESCRIPTION

The smbldap-userdel command modifies the system account files, deleting all entries that refer to user defined in "login". The named user must exist.

-r
Files in the user's home directory will be removed along with the home directory itself. Files located in other file systems will have to be searched for and deleted manually.

=head1 SEE ALSO

userdel(1)

=cut

#'
