#!@PERL_COMMAND@

# $Id: smbldap-groupmod.pl 121 2011-10-07 05:40:06Z fumiyas $

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

# Purpose of smbldap-groupmod : group (posix) modification


use strict;
use warnings;
use smbldap_tools;

#####################

use Getopt::Std;
my %Options;

my $ok = getopts('ag:n:m:or:s:t:x:?', \%Options);
if ( (!$ok) || (@ARGV < 1) || ($Options{'?'}) ) {
    print_banner;
    print "Usage: $0 [-a] [-g gid] [-n name] [-m members(,)] [-o] [-r rid] [-s sid] [-t type] [-x members (,)] groupname\n";
    print "  -a   add automatic group mapping entry\n";
    print "  -g   new gid\n";
    print "  -n   new group name\n";
    print "  -m   add members (comma delimited)\n";
    print "  -o   gid is not unique\n";
    print "  -r   group-rid\n";
    print "  -s   group-sid\n";
    print "  -t   group-type\n"; 
    print "  -x   delete members (comma delimted)\n";
    print "  -?   show this help message\n";
    exit (1);
}

my $groupName = $ARGV[0];
my $group_entry;

my $ldap_master=connect_ldap_master();

if (! ($group_entry = read_group_entry($groupName))) {
    print "$0: group $groupName doesn't exist\n";
    exit (6);
}

nsc_invalidate("group");

my $gid=$group_entry->get_value('gidNumber');

unless (defined ($gid)) {
    print "$0: group $groupName not found!\n";
    exit(6);
}

my $tmp;
if (defined($tmp = $Options{'g'}) and $tmp =~ /\d+/) {
    if (!defined($Options{'o'})) {
	if (defined(getgrgid($tmp))) {
	    print "$0: gid $tmp exists\n";
	    exit (6);
	}
    }
    if (!($gid == $tmp)) {
	my $modify = $ldap_master->modify ( "cn=$groupName,$config{groupsdn}",
					    changes => [
							replace => [gidNumber => $tmp]
							]
					    );
	$modify->code && die "failed to modify entry: ", $modify->error ;
    }
}

if (defined(my $newname = $Options{'n'})) {
    my $modify = $ldap_master->moddn (
				      "cn=$groupName,$config{groupsdn}",
				      newrdn => "cn=$newname",
				      deleteoldrdn => "1",
				      newsuperior => "$config{groupsdn}"
				      );
    $modify->code && die "failed to modify entry: ", $modify->error ;
    $groupName = $newname;
    $group_entry = read_group_entry($groupName)
}

# Add members
if (defined($Options{'m'})) {
    my @members = ();
    foreach my $member (split(/,/, $Options{'m'})) {
	if (my $user_entry = read_user_entry($member)) {
	    # Canonize user name
	    $member = $user_entry->get_value('uid');
	} elsif (my @user_entry = getpwnam($member)) {
	    # Canonize user name
	    $member = $user_entry[0];
	} else {
	    warn "User does not exist: $member\n";
	    next;
	}

	if (is_group_member($group_entry->dn, $member)) {
	    warn "User already in the group: $member\n";
	    next;
	}

	push(@members, $member);
    }

    if (@members) {
	my $modify = $ldap_master->modify($group_entry->dn,
	    add => {memberUid => \@members},
	);
	$modify->code && warn "Failed to add memberUid: ", $modify->error;
    }
}

# Delete members
if (defined($Options{'x'})) {
    my @members = ();
    foreach my $member (split(/,/, $Options{'x'})) {
	if (my $user_entry = read_user_entry($member)) {
	    # Canonize user name
	    $member = $user_entry->get_value('uid');

	    my $user_pgroup_sid = $group_entry->get_value('sambaPrimaryGroupSID');
	    my $group_sid = $group_entry->get_value('sambaSID');
	    if (defined($user_pgroup_sid) && defined($group_sid) &&
		$user_pgroup_sid eq $group_sid) {
		warn "Cannot delete user from its primary group: $member\n";
		next;
	    }
	} elsif (my @user_entry = getpwnam($member)) {
	    # Canonize user name
	    $member = $user_entry[0];
	}

	if (!is_group_member($group_entry->dn, $member)) {
	    warn "User is not in the group: $member\n";
	    next;
	}

	push(@members, $member);
    }

    if (@members) {
	my $modify = $ldap_master->modify($group_entry->dn,
	    delete => {memberUid => \@members},
	);
	$modify->code && warn "Failed to delete memberUid: ", $modify->error;
    };
}

my $group_sid;
if ($tmp= $Options{'s'}) {
    if ($tmp =~ /^S-(?:\d+-)+\d+$/) {
	$group_sid = $tmp;
    } else {
	print "$0: illegal group-rid $tmp\n";
	exit(7);
    }
} elsif ($Options{'r'} || $Options{'a'}) {
    my $group_rid;
    if ($tmp= $Options{'r'}) {
	if ($tmp =~ /^\d+$/) {
	    $group_rid = $tmp;
	} else {
	    print "$0: illegal group-rid $tmp\n";
	    exit(7);
	}
    } else {
	$group_rid = group_next_rid($gid);
    }
    $group_sid = $config{SID}.'-'.$group_rid;
}

if ($group_sid) {
    my @adds;
    my @mods;
    push(@mods, 'sambaSID' => $group_sid);

    if ($tmp= $Options{'t'}) {
	my $group_type;
	if (defined($group_type = &group_type_by_name($tmp))) {
	    push(@mods, 'sambaGroupType' => $group_type);
	} else {
	    print "$0: unknown group type $tmp\n";
	    exit(8);
	}
    } else {
	if (! defined($group_entry->get_value('sambaGroupType'))) {
	    push(@mods, 'sambaGroupType' => group_type_by_name('domain'));
	}
    }

    my @oc = $group_entry->get_value('objectClass');
    unless (grep($_ =~ /^sambaGroupMapping$/i, @oc)) {
	push (@adds, 'objectClass' => 'sambaGroupMapping');
    }

    my $modify = $ldap_master->modify ( "cn=$groupName,$config{groupsdn}",
					changes => [
						    'add' => [ @adds ],
						    'replace' => [ @mods ]
						    ]
					);
    $modify->code && warn "failed to delete entry: ", $modify->error ;
}

nsc_invalidate("group");

# take down session
$ldap_master->unbind;

exit (0);

############################################################

=head1 NAME

smbldap-groupmod - Modify a group

=head1 SYNOPSIS

smbldap-groupmod [-g gid [-o]] [-a] [-r rid] [-s sid] [-t group type] [-n group_name ] [-m members(,)] [-x members (,)] group

=head1 DESCRIPTION

The smbldap-groupmod command modifies the system account files to reflect the changes that are specified on the command line. The options which apply to the smbldap-groupmod command are

-g gid The numerical value of the group's ID. This value must be unique, unless the -o option is used. The value must be non negative. Any files which the old group ID is the file roup ID must have the file group ID changed manually.

-n group_name
   The name of the group will be changed from group to group_name.

-m members
   The members to be added to the group in comma-delimeted form.

-x members
   The members to be removed from the group in comma-delimted form.

-a
   add an automatic Security ID for the group (SID).

-s sid
   set the group SID.
   The SID must be unique and defined with the domain Security ID ($SID) like sid=$SID-rid where rid is the group rid.

-r rid
   set the group rid.
   The SID is then calculated as sid=$SID-rid where $SID is the domain Security ID.

-t group type
   set the NT Group type for the new group. Available values are 2 (domain group), 4 (local group) and 5 (builtin group). The default group type is 2.

=head1 EXAMPLES

smbldap-groupmod -g 253 development
This will change the GID of the 'development' group to '253'.

smbldap-groupmod -n Idiots Managers
This will change the name of the 'Managers' group to 'Idiots'.

smbldap-groupmod -m "jdoe,jsmith" "Domain Admins"
This will add 'jdoe' and 'jsmith' to the 'Domain Admins' group.

smbldap-groupmod -x "jdoe,jsmith" "Domain Admins"
This will remove 'jdoe' and 'jsmith' from the 'Domain Admins' group.

=head1 SEE ALSO

groupmod(1)

=cut

#'
