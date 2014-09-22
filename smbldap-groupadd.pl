#!@PERL_COMMAND@

# $Id: smbldap-groupadd.pl 121 2011-10-07 05:40:06Z fumiyas $

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

# Purpose of smbldap-groupadd : group (posix) add


use strict;
use warnings;
use smbldap_tools;
use Getopt::Std;
my %Options;

my $ok = getopts('abg:opr:s:t:?', \%Options);
if ( (!$ok) || (@ARGV < 1) || ($Options{'?'}) ) {
    print_banner;
    print "Usage: $0 [-abgoprst?] groupname\n";
    print "  -a   add automatic group mapping entry\n";
    print "  -b   create a AIX group\n";
    print "  -g   gid\n";
    print "  -o   gid is not unique\n";
    print "  -p   print the gidNumber to stdout\n";
    print "  -r   group-rid\n";
    print "  -s   group-sid\n";
    print "  -t   group-type\n";
    print "  -?   show this help message\n";
    exit (1);
}

my $_groupName = $ARGV[0];

nsc_invalidate("group");

my $ldap_master=connect_ldap_master();

if (defined(get_group_dn($_groupName))) {
    warn "$0: group $_groupName exists\n";
    exit (6);
}

my $_groupGidNumber = $Options{'g'};
if (! defined ($_groupGidNumber = group_add($_groupName, $_groupGidNumber, $Options{'o'}))) {
    warn "$0: error adding group $_groupName\n";
    exit (6);
}

my $group_sid;
my $tmp;
if ($tmp= $Options{'s'}) {
    if ($tmp =~ /^S-(?:\d+-)+\d+$/) {
	$group_sid = $tmp;
    } else {
	warn "$0: illegal group-rid $tmp\n";
	exit(7);
    }
} elsif ($Options{'r'} || $Options{'a'}) {
    my $group_rid;
    if ($tmp= $Options{'r'}) {
	if ($tmp =~ /^\d+$/) {
	    $group_rid = $tmp;
	} else {
	    warn "$0: illegal group-rid $tmp\n";
	    exit(7);
	}
    } else {
	# algorithmic mapping
	$group_rid = group_next_rid($_groupGidNumber);
    }
    $group_sid = $config{SID}.'-'.$group_rid;
}

if ($Options{'r'} || $Options{'a'} || $Options{'s'}) {
    # let's test if this SID already exist
    if (my $account = account_by_sid($group_sid)) {
	warn "SID already owned by " . $account->dn. "\n";
	exit(7);
    }
}

if ($group_sid) {
    my $group_type;
    my $tmp;
    if ($tmp= $Options{'t'}) {
	unless (defined($group_type = &group_type_by_name($tmp))) {
	    warn "$0: unknown group type $tmp\n";
	    exit(8);
	}
    } else {
	$group_type = group_type_by_name('domain');
    }
    my $modify = $ldap_master->modify ( "cn=$_groupName,$config{groupsdn}",
					add => {
					    'objectClass' => 'sambaGroupMapping',
					    'sambaSID' => $group_sid,
					    'sambaGroupType' => $group_type,
					    'displayName' => "$_groupName"
					    }
					);
    $modify->code && warn "failed to delete entry: ", $modify->error ;
}

if ($Options{'b'}) {
    my $modify = $ldap_master->modify ( "cn=$_groupName,$config{groupsdn}",
					add => {
					    'objectClass' => 'AIXAuxGroup',
					    'AIXGroupAdminList' => 'root',
					    'isAdministrator' => 'false'
					    }
					);
    $modify->code && warn "failed to delete entry: ", $modify->error ;
}

# take down session
$ldap_master->unbind;

nsc_invalidate("group");

if ($Options{'p'}) {
    print STDOUT "$_groupGidNumber";
}
exit(0);

########################################

=head1 NAME

smbldap-groupadd - Create a new group

=head1 SYNOPSIS

smbldap-groupadd [-g gid ] [-a] [-o] [-r rid] [-s sid] [-t group type] [-p] group

=head1 DESCRIPTION

The smbldap-groupadd command creates a new group account using the values specified on the command line and the default values from the configuration file.
The new group will be entered into the system files as needed.
Available options are :

-g gid
   The numerical value of the group's ID. This value must be
   unique, unless the -o option is used. The value must be non-
   negative. The default is to use the smallest ID value greater
   than 1000 and greater than every other group.

-a
   add an automatic Security ID for the group (SID).

-b
   the group is also a AIX group

-o
   gid is not unique

-p
   print the gidNumber to stdout

-s sid
   set the group SID.
   The SID must be unique and defined with the domain Security ID
   ($SID) like sid=$SID-rid where rid is the group rid.

-r rid
   set the group rid.
   The SID is then calculated as sid=$SID-rid where $SID is the
   domain Security ID.

-t group type
   set the NT Group type for the new group. Available values are
   2 (domain group), 4 (local group) and 5 (builtin group).
   The default group type is 2.

=head1 SEE ALSO

groupadd(1)

=cut

#'
