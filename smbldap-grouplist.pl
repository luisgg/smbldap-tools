#!@PERL_COMMAND@

# $Id: smbldap-grouplist.pl 141 2012-08-07 11:20:42Z fumiyas $

#  This code was developped by Jerome Tournier (jtournier@gmail.com) and
#  contributors (their names can be found in the CONTRIBUTORS file).

#  This was first created by Martin Matuska <mm@FreeBSD.org>

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

# Purpose of smbldap-grouplist : list groups

use strict;
use warnings;
use Getopt::Std;
use smbldap_tools;

# function declaration
sub exist_in_tab;

my %Options;

my $ok = getopts('dtS?', \%Options);
if ( (!$ok) || ($Options{'?'}) || $Options{'h'} ) {
    print "Usage: $0 [dtS?] [user template]\n\n";
    print "-d     Show displayName\n";
    print "-t     Show samba group type\n";
    print "-S     Show samba SID\n";
    print "-?     show the help message\n";
    exit (1);
}

my $binduser;

if (!defined($binduser)) {
    $binduser = getpwuid($<);
}

my $search;
if ( $ARGV[0] ) {
    if ( $< != 0 ) {
        die "Only root can show group inormation\n";
    } else {
        $search=$ARGV[0];
    }
} elsif ( $< != 0 ) {
    $search=$binduser;
}


my ($dn,$ldap_master);
# First, connecting to the directory
if ($< != 0) {
    # non-root user
    my $pass = password_read("UNIX password: ");

    # JTO: search real basedn: may be different in case ou=bla1,ou=bla2 !
    # JTO: faire afficher egalement lock, expire et lastChange
    $config{masterDN}="uid=$binduser,$config{usersdn}";
    $config{masterPw}="$pass";
    $ldap_master=connect_ldap_master();
    $dn=$config{masterDN};
    if (!is_user_valid($binduser, $dn, $pass)) {
	print "Authentication failure\n";
	exit (10);
    }
} else {
    # root user
    $ldap_master=connect_ldap_master();
}

sub print_group {
    my ($entry, %Options) = @_;
    printf "%4s ", $entry->get_value('gidNumber') ;
    printf "|%-20s ", $entry->get_value('cn');
    if ($Options{'d'})
    {
	if (defined $entry->get_value('displayName'))
	{
	    printf "|%-20s", $entry->get_value('displayName');
	} else {
	    print "|-";
	}
    }
    if ($Options{'t'})
    {
	my $group_name;
	if (defined($entry->get_value('sambaGroupType')) && \
	    defined($group_name = &group_name_by_type($entry->get_value('sambaGroupType'))))
	{
	    printf "|%-14s", $group_name;
	} else {
	    print "|-";
	}
    }
    if ($Options{'S'})
    {
	if (defined $entry->get_value('sambaSID'))
	{
	    printf "|%-47s", $entry->get_value('sambaSID');
	} else {
	    print "|-";
	}
    }
    print "|\n";
}

my @attrs = qw(gidNumber cn);
my $banner="gid  |cn                   ";
if ($Options{'d'})
{
    $banner .=  "|displayName         ";
    push(@attrs, qw(displayName));
}
if ($Options{'t'})
{
    $banner .=  "|sambaGroupType";
    push(@attrs, qw(sambaGroupType));
}
if ($Options{'S'})
{
    $banner .=  "|sambaSID                                       ";
    push(@attrs, qw(sambaSID));
}
$banner.="|";
print "$banner\n\n";
my $filter = "(&(objectclass=posixGroup)";
my $base = $config{groupsdn};

if ($search) {
    $filter.="(displayName=$search)";
}

$filter.=")";

my  $mesg = $ldap_master->search ( base   => $base,
                                   scope => $config{scope},
                                   filter => $filter,
				   attrs => \@attrs
				   );
$mesg->code && warn $mesg->error;

foreach my $entry ($mesg->all_entries) {
    print_group($entry,%Options);
}
########################################

=head1 NAME

smbldap-grouplist - list groups

=head1 SYNOPSIS

smbldap-grouplist [-S] [group template]


=head1 DESCRIPTION

-d     Show displayName

-S     Show samba SID entry

-?     show the help message

=head1 EXAMPLE

smbldap-grouplist -dS

smbldap-grouplist "*ourn*"

=cut

#'

# The End
