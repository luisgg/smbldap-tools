#!@PERL_COMMAND@

# $Id: smbldap-useradd.pl 138 2012-07-17 05:36:04Z fumiyas $

#  This code was developed by Jerome Tournier (jtournier@gmail.com) and
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

# Purpose of smbldap-useradd : user (posix,shadow,samba) add

use strict;
use warnings;

use FindBin qw($RealBin);
use smbldap_tools;
use Crypt::SmbHash;
#####################

use Getopt::Long;
my %Options;

Getopt::Long::Configure('bundling');
my $ok = GetOptions(
    "A|sambaPwdCanChange=s"  => \$Options{A},
    "B|sambaPwdMustChange=s" => \$Options{B},
    "C|sambaHomePath=s"      => \$Options{C},
    "D|sambaHomeDrive=s"     => \$Options{D},
    "E|sambaLogonScript=s"   => \$Options{E},
    "F|sambaProfilePath=s"   => \$Options{F},
    "G|group=s"              => \$Options{G},
    "H|sambaAcctFlags=s"     => \$Options{H},
    "M|mailAddresses=s"      => \$Options{M},
    "N|givenName=s"          => \$Options{N},
    "O|mailLocalAddress=s"   => \$Options{O},
    "P"                      => \$Options{P},
    "S|surname=s"            => \$Options{S},
    "T|mailToAddress=s"      => \$Options{T},
    "W"                      => \$Options{W},
    "X|inputEncoding=s"      => \$Options{X},
    "Z|attr=s@"              => \$Options{Z},
    "a|addsambaSAMAccount"   => \$Options{a},
    "b|aix"                  => \$Options{b},
    "c|gecos=s"              => \$Options{c},
    "d|homedir=s"            => \$Options{d},
    "g|gid=s"                => \$Options{g},
    "h|?|help"               => \$Options{h},
    "i"                      => \$Options{i},
    "k=s"                    => \$Options{k},
    "m"                      => \$Options{m},
    "n"                      => \$Options{n},
    "non-unique"             => \$Options{non_unique},
    "o|ou=s"                 => \$Options{ou},
    "p"                      => \$Options{p},
    "s|shell=s"              => \$Options{s},
    "t=s"                    => \$Options{t},
    "u|uid=s"                => \$Options{u},
    "w"                      => \$Options{w},
);

if ( ( !$ok ) || ( @ARGV < 1 ) || ( $Options{'h'} ) ) {
    print_banner;
    print "Usage: $0 [OPTIONS] USERNAME\n";
    print "\n";
    print "Options:\n";
    print "  -a	is a Windows User (otherwise, Posix stuff only)\n";
    print "  -b	is a AIX User\n";
    print "  -c	gecos\n";
    print "  -d	home\n";
    print "  -g	gid\n";
    print "  -i	is a trust account (Windows Workstation)\n";
    print "  -k	skeleton dir (with -m)\n";
    print "  -m	creates home directory and copies /etc/skel\n";
    print "  --non-unique\n";
    print "	Allow the creation of a user account with a duplicate (non-unique) UID.\n";
    print "  -n	do not create a group\n";
    print
"  -o	add the user in the organizational unit (relative to the user suffix. Ex: 'ou=admin,ou=all')\n";
    print "  -s	shell\n";
    print
"  -t	time. Wait 'time' seconds before exiting (when adding Windows Workstation)\n";
    print "  -u	uid\n";
    print "  -w	is a Windows Workstation (otherwise, Posix stuff only)\n";
    print
"  -W	is a Windows Workstation, with Samba atributes (otherwise, Posix stuff only)\n";
    print "  -A	can change password ? 0 if no, 1 if yes\n";
    print "  -B	must change password ? 0 if no, 1 if yes\n";
    print "  -C	sambaHomePath (SMB home share, like '\\\\PDC-SRV\\homes')\n";
    print
      "  -D	sambaHomeDrive (letter associated with home share, like 'H:')\n";
    print "  -E	sambaLogonScript (DOS script to execute on login)\n";
    print
"  -F	sambaProfilePath (profile directory, like '\\\\PDC-SRV\\profiles\\foo')\n";
    print "  -G	supplementary comma-separated groups\n";
    print
      "  -H	sambaAcctFlags (samba account control bits like '[NDHTUMWSLKI]')\n";
    print "  -M	e-mail address (comma separated)\n";
    print "  -N	given name \n";
    print "  -O	localMailAddress (comma separated)\n";
    print "  -P	ends by invoking smbldap-passwd\n";
    print "  -S	surname (Family name)\n";
    print "  -T	mailToAddress (forward address) (comma separated)\n";
    print "  -X	input encoding for givenname and surname (default UTF-8)\n";
    print "  -Z	set custom LDAP attributes, name=value pairs comma separated\n";
    print "  -h	show this help message\n";
    exit(1);
}

my $ldap_master = connect_ldap_master();

# cause problems when dealing with getpwuid because of the
# negative ttl and ldap modification
nsc_invalidate("passwd");

# Read only first @ARGV
my $userName = $ARGV[0];

# Get the input encoding
my $characterSet;
if ( defined( $Options{'X'} ) ) {
	$characterSet = $Options{'X'};
} else {
	$characterSet = "UTF-8";
}

# For computers account, add a trailing dollar if missing
if ( defined( $Options{'w'} ) or defined( $Options{'W'} ) ) {
    if ( $userName =~ /[^\$]$/s ) {
        $userName .= "\$";
    }
}

# untaint $userName (can finish with one or two $)
if ( $userName =~ /^([\w -.]+\$?)$/ ) {
    $userName = $1;
}
else {
    print "$0: illegal username\n";
    exit(1);
}

# user must not exist in LDAP (should it be nss-wide ?)
my ( $rc, $dn ) = get_user_dn2($userName);
if ( $rc and defined($dn) ) {
    print "$0: user $userName exists\n";
    exit(9);
}
elsif ( !$rc ) {
    print "$0: error in get_user_dn2\n";
    exit(10);
}

# Read options
# we create the user in the specified ou (relative to the users suffix)
my $user_ou = $Options{'ou'};
my $node;
if ( defined $user_ou ) {

# admin can specify a organizational unit like '-o ou=admin,ou=all'. We need to check that
# each ou exist
    my @path;
    while ( $user_ou =~ m/(ou=)?([^,]+),?/g ) {
        push( @path, $2 );
    }
    foreach $node ( reverse @path ) {

        # if the ou does not exist, we create it
        my $mesg = $ldap_master->search(
            base   => "$config{usersdn}",
            scope  => "one",
            filter => "(&(objectClass=organizationalUnit)(ou=$node))"
        );
        $mesg->code && die $mesg->error;
        if ( $mesg->count eq 0 ) {
            print
"ou=$node,$config{usersdn} does not exist. Creating it (Y/[N]) ? ";
            chomp( my $answ = <STDIN> );
            if ( $answ eq "y" || $answ eq "Y" ) {

                # add organizational unit
                my $add = $ldap_master->add(
                    "ou=$node,$config{usersdn}",
                    attr => [
                        'objectclass' => [ 'top', 'organizationalUnit' ],
                        'ou'          => "$node"
                    ]
                );
                $add->code && die "failed to add entry: ", $add->error;
                print "$user_ou,$config{usersdn} created \n";

            }
            else {
                print "exiting.\n";
                exit;
            }
        }
        $config{usersdn} = "ou=$node,$config{usersdn}";
    }
}

my $userUidNumber = $Options{'u'};
if ( !defined($userUidNumber) ) {
    $userUidNumber = user_next_uid();
}
elsif (!$Options{non_unique} and my $user = user_by_uid($userUidNumber)) {
    die "UID already owned by " . $user->dn . "\n";
}

my $createGroup   = 0;
my $userGidNumber = $Options{'g'};

# gid not specified ?
if ( !defined($userGidNumber) ) {

    # windows machine => $config{defaultComputerGid}
    if ( defined( $Options{'w'} ) or defined( $Options{'W'} ) ) {
        $userGidNumber = $config{defaultComputerGid};

        #    } elsif (!defined($Options{'n'})) {
        # create new group (redhat style)
        # find first unused gid starting from $config{GID_START}
        #	while (defined(getgrgid($config{GID_START}))) {
        #		$config{GID_START}++;
        #	}
        #	$userGidNumber = $config{GID_START};

        #	$createGroup = 1;

    }
    else {

        # user will have gid = $config{defaultUserGid}
        $userGidNumber = $config{defaultUserGid};
    }
}
else {
    my $gid;
    if ( ( $gid = parse_group($userGidNumber) ) < 0 ) {
        print "$0: unknown group $userGidNumber\n";
        exit(6);
    }
    $userGidNumber = $gid;
}

my $group_entry;
my $userGroupSID;
my $userRid;
my $user_sid;
if (   defined $Options{'a'}
    or defined $Options{'i'}
    or defined $Options{'w'}
    or defined( $Options{'W'} ) )
{

    # as grouprid we use the value of the sambaSID attribute for
    # group of gidNumber=$userGidNumber
    $group_entry  = read_group_entry_gid($userGidNumber);
    $userGroupSID = $group_entry->get_value('sambaSID');
    unless ($userGroupSID) {
        print "Error: SID not set for unix group $userGidNumber\n";
        print "check if your unix group is mapped to an NT group\n";
        exit(7);
    }

    $userRid = user_next_rid($userUidNumber);
    $user_sid = "$config{SID}-$userRid";
}

my $userHomeDirectory;
my ( $givenName, $userCN, $userSN, $displayName );
my @mail;
my @userMailLocal;
my @userMailTo;
my $tmp;
if ( !defined( $userHomeDirectory = $Options{'d'} ) ) {
    $userHomeDirectory = &subst_user( $config{userHome}, $userName );
}

# RFC 2256 & RFC 2798
# sn: family name (option S)             # RFC 2256: family name of a person.
# givenName: prenom (option N)           # RFC 2256: part of a person's name which is not their surname nor middle name.
# cn: person's full name                 # RFC 2256: person's full name.
# displayName: preferably displayed name # RFC 2798: preferred name of a person to be used when displaying entries.

#givenname is the forename of a person (not family name) => http://en.wikipedia.org/wiki/Given_name
#surname (or sn) is the family name => http://en.wikipedia.org/wiki/Surname
# my surname (or sn): Tournier
# my givenname: Jerome

$userHomeDirectory =~ s/\/\//\//;
$config{userLoginShell} = $tmp if ( defined( $tmp = $Options{'s'} ) );
$config{userGecos}      = $tmp if ( defined( $tmp = $Options{'c'} ) );
$config{skeletonDir}    = $tmp if ( defined( $tmp = $Options{'k'} ) );
$givenName = ( utf8Encode( $characterSet, $Options{'N'} ) || $userName );
$userSN    = ( utf8Encode( $characterSet, $Options{'S'} ) || $userName );
if ( $Options{'N'} and $Options{'S'} ) {
    $displayName = $userCN = "$givenName" . " $userSN";
} elsif ( $Options{'c'} ) {
    $displayName = $userCN = $config{userGecos};
} else {
    $displayName = $userCN = $userName;
}

@mail = &split_arg_comma( $Options{'M'} );
@userMailLocal = &split_arg_comma( $Options{'O'} );
@userMailTo    = &split_arg_comma( $Options{'T'} );

########################

# MACHINE ACCOUNT
if (   defined( $Options{'w'} )
    or defined( $Options{'i'} )
    or defined( $Options{'W'} ) )
{

    # if Options{'i'} and username does not end with $ character => we add it
    if ( $Options{'i'} and !( $userName =~ m/\$$/ ) ) {
        $userName .= "\$";
    }

    if (
        !add_posix_machine(
            $userName, $userUidNumber, $userGidNumber, $Options{'t'}
        )
      )
    {
        die "$0: error while adding posix account\n";
    }

    if ( defined( $Options{'i'} ) ) {

        # For machine trust account
        # Objectclass sambaSAMAccount must be added now !
        my $pass = password_read("New password: ");
        my $pass2 = password_read("Retype new password: ");
        if ( $pass ne $pass2 ) {
            print "New passwords don't match!\n";
            exit(10);
        }
        my ( $lmpassword, $ntpassword ) = ntlmgen $pass;
        my $date   = time;
        my $modify = $ldap_master->modify(
            "uid=$userName,$config{computersdn}",
            changes => [
                replace => [
                    objectClass =>
                      [ 'posixAccount', 'account', 'sambaSAMAccount' ]
                ],
                add => [ sambaLogonTime       => '0' ],
                add => [ sambaLogoffTime      => '2147483647' ],
                add => [ sambaKickoffTime     => '2147483647' ],
                add => [ sambaPwdCanChange    => '0' ],
                add => [ sambaPwdMustChange   => '2147483647' ],
                add => [ sambaPwdLastSet      => "$date" ],
                add => [ sambaAcctFlags       => '[I          ]' ],
                add => [ sambaLMPassword      => "$lmpassword" ],
                add => [ sambaNTPassword      => "$ntpassword" ],
                add => [ sambaSID             => "$user_sid" ],
                add => [ sambaPrimaryGroupSID => "$config{SID}-515" ]
            ]
        );

        $modify->code && die "failed to add entry: ", $modify->error;
    }
    elsif ( defined( $Options{'W'} ) ) {
        my $date   = time;
        my $modify = $ldap_master->modify(
            "uid=$userName,$config{computersdn}",
            changes => [
                replace => [
                    objectClass =>
                      [ 'posixAccount', 'account', 'sambaSAMAccount' ]
                ],
                add => [ sambaLogonTime       => '0' ],
                add => [ sambaLogoffTime      => '2147483647' ],
                add => [ sambaKickoffTime     => '2147483647' ],
                add => [ sambaPwdCanChange    => '0' ],
                add => [ sambaPwdMustChange   => '2147483647' ],
                add => [ sambaPwdLastSet      => "$date" ],
                add => [ sambaAcctFlags       => '[W          ]' ],
                add => [ sambaSID             => "$user_sid" ],
                add => [ sambaPrimaryGroupSID => "$config{SID}-515" ],
                add => [ displayName          => "$userName" ],
                add => [ sambaDomainName      => "$config{sambaDomain}" ]
            ]
        );

        $modify->code && die "failed to add entry: ", $modify->error;
    }

    $ldap_master->unbind;
    exit 0;
}

# USER ACCOUNT
# add posix account first
my @objectclass = qw(top person organizationalPerson posixAccount);
my @attr = (
    'objectclass' => \@objectclass,
    'cn'            => $userCN,
    'sn'            => $userSN,
    'uid'           => $userName,
    'uidNumber'     => $userUidNumber,
    'gidNumber'     => $userGidNumber,
    'homeDirectory' => $userHomeDirectory,
    'loginShell'    => $config{userLoginShell},
    'gecos'         => $config{userGecos},
    'userPassword'  => "{crypt}x"
);

push(@objectclass, 'shadowAccount') if ($config{shadowAccount});

# if AIX account, inetOrgPerson objectclass can't be used
unless ($Options{'b'}) {
    push(@objectclass, 'inetOrgPerson');
    push(@attr, givenName => $givenName);
}

my $add = $ldap_master->add("uid=$userName,$config{usersdn}", attr => \@attr);
$add->code && warn "failed to add entry: ", $add->error;

#if ($createGroup) {
#    group_add($userName, $userGidNumber);
#}

if ( $userGidNumber != $config{defaultUserGid} ) {
    group_add_user( $userGidNumber, $userName );
}

my $grouplist;

# adds to supplementary groups
if ( defined( $grouplist = $Options{'G'} ) ) {
    add_grouplist_user( $grouplist, $userName );
}

# If user was created successfully then we should create his/her home dir
if ( defined( $tmp = $Options{'m'} ) ) {
    unless ( $userName =~ /\$$/ ) {
        if ( !( -d $userHomeDirectory ) ) {
            if ( $config{skeletonDir} ne "" ) {
		system("cp", "-pRP", $config{skeletonDir}, $userHomeDirectory);
		system("chown", "-hR", "$userUidNumber:$userGidNumber", $userHomeDirectory);
            }
            else {
                mkdir($userHomeDirectory)
		  || warn "Failed to create home directory: $userHomeDirectory: $!";
            }

	    my $mode = defined($config{userHomeDirectoryMode})
	      ? oct($config{userHomeDirectoryMode}) : 0700;
	    chmod($mode, $userHomeDirectory)
	      || warn "Failed to change mode of home directory: $userHomeDirectory: $!";
        }
        else {
            warn "Warning: homedirectory $userHomeDirectory already exist. Check manually\n";
        }
    }
}

# we start to define mail addresses if option M, O or T are given
my @adds;
if ( @userMailLocal || @userMailTo ) {
    push( @adds, 'objectClass' => 'inetLocalMailRecipient' );
}
if (@mail) {
    foreach my $m (@mail) {
        my $domain = $config{mailDomain};
        if ( $m !~ /^(.+)@/ ) {
            $m = $m . ( $domain ? '@' . $domain : '' );
        }
    }
    push( @adds, 'mail'             => [@mail] );
}

if (@userMailLocal) {
    push( @adds, 'mailLocalAddress' => [@userMailLocal] );
}
if (@userMailTo) {
    push( @adds, 'mailRoutingAddress' => [@userMailTo] );
}

# Custom modification - MPK
if ( defined( $tmp = $Options{'Z'} ) ) {
    my %adds;
    for my $pair ( map { split /,/ } @{$Options{'Z'}} ) {
	my ( $name, $value ) = split( /[=:]/, $pair, 2 );
	$name = lc( $name );
	push( @{$adds{$name}}, $value );
    }

    while ( my ($name, $value) = each( %adds ) ) {
	push( @adds, $name => $value );
    }
}

if (@adds) {
    my $modify =
      $ldap_master->modify( "uid=$userName,$config{usersdn}", add => {@adds} );

    $modify->code && die "failed to add entry: ", $modify->error;
}

# Reset adds
@adds = ();

# Add Samba user infos
if ( defined( $Options{'a'} ) ) {
    if ( !$config{with_smbpasswd} ) {

        my $winmagic         = 2147483647;
        my $valpwdcanchange  = 0;
        my $valpwdmustchange = $winmagic;
        my $valpwdlastset    = 0;
        my $valacctflags     = "[UX]";

        if ( defined( $tmp = $Options{'A'} ) ) {
            if ( $tmp != 0 ) {
                $valpwdcanchange = "0";
            }
            else {
                $valpwdcanchange = "$winmagic";
            }
        }

        if ( defined( $tmp = $Options{'B'} ) ) {
            if ( $tmp != 0 ) {
                $valpwdmustchange = "0";

                # To force a user to change his password:
                # . the attribute sambaAcctFlags must not match the 'X' flag
                $valacctflags = "[U]";
            }
            else {
                $valpwdmustchange = "$winmagic";
            }
        }

        if ( defined( $tmp = $Options{'H'} ) ) {
            $valacctflags = "$tmp";
        }

        my $modify = $ldap_master->modify(
            "uid=$userName,$config{usersdn}",
            changes => [
                add => [ objectClass        => 'sambaSAMAccount' ],
                add => [ sambaPwdLastSet    => "$valpwdlastset" ],
                add => [ sambaLogonTime     => '0' ],
                add => [ sambaLogoffTime    => '2147483647' ],
                add => [ sambaKickoffTime   => '2147483647' ],
                add => [ sambaPwdCanChange  => "$valpwdcanchange" ],
                add => [ sambaPwdMustChange => "$valpwdmustchange" ],
                add => [ displayName        => "$displayName" ],
                add => [ sambaAcctFlags     => "$valacctflags" ],
                add => [ sambaSID           => "$config{SID}-$userRid" ]
            ]
        );

        $modify->code && die "failed to add entry: ", $modify->error;

    }
    else {
        my $FILE = "|$config{smbpasswd} -s -a $userName >/dev/null";
        open( FILE, $FILE ) || die "$!\n";
        print FILE <<EOF;
x
x
EOF
        close FILE;
        if ($?) {
            print "$0: error adding samba account\n";
            exit(10);
        }
    }    # with_smbpasswd

    $tmp = defined( $Options{'E'} ) ? $Options{'E'} : $config{userScript};
    my $valscriptpath = &subst_user( $tmp, $userName );

    $tmp = defined( $Options{'C'} ) ? $Options{'C'} : $config{userSmbHome};
    my $valsmbhome = &subst_user( $tmp, $userName );

    my $valhomedrive =
      defined( $Options{'D'} ) ? $Options{'D'} : $config{userHomeDrive};

    # if the letter is given without the ":" symbol, we add it
    $valhomedrive .= ':' if ( $valhomedrive && $valhomedrive !~ /:$/ );

    $tmp = defined( $Options{'F'} ) ? $Options{'F'} : $config{userProfile};
    my $valprofilepath = &subst_user( $tmp, $userName );

    if ($valhomedrive) {
        push( @adds, 'sambaHomeDrive' => $valhomedrive );
    }
    if ($valsmbhome) {
        push( @adds, 'sambaHomePath' => $valsmbhome );
    }

    if ($valprofilepath) {
        push( @adds, 'sambaProfilePath' => $valprofilepath );
    }
    if ($valscriptpath) {
        push( @adds, 'sambaLogonScript' => $valscriptpath );
    }
    if ( !$config{with_smbpasswd} ) {
        push( @adds, 'sambaPrimaryGroupSID' => $userGroupSID );
        push( @adds, 'sambaLMPassword'      => "XXX" );
        push( @adds, 'sambaNTPassword'      => "XXX" );
    }
}

if (@adds) {
    my $modify =
      $ldap_master->modify( "uid=$userName,$config{usersdn}", add => {@adds} );

    $modify->code && die "failed to add entry: ", $modify->error;
}

# add AIX user
if ( defined( $Options{'b'} ) ) {
    my $modify = $ldap_master->modify(
        "uid=$userName,$config{usersdn}",
        changes => [
            add => [ objectClass     => 'aixAuxAccount' ],
            add => [ passwordChar    => "!" ],
            add => [ isAdministrator => "false" ]
        ]
    );

    $modify->code && die "failed to add entry: ", $modify->error;
}

$ldap_master->unbind;    # take down session

nsc_invalidate("passwd");
nsc_invalidate("group");

if ($Options{'P'}) {
    my @passwd_cmd = ("$RealBin/smbldap-passwd");

    if ($Options{'B'}) {
	## Must change Samba password at logon
	push(@passwd_cmd, '-B');
    }
    if ($Options{'p'}) {
	## Read password from STDIN
	push(@passwd_cmd, '-p');
    }

    ## Suppress Perl warning on exec() failed
    local $SIG{__WARN__} = sub {};

    exec {$passwd_cmd[0]} @passwd_cmd, $userName;
    die "Failed to execute: $passwd_cmd[0]: $!";
}

exit 0;

########################################

=head1 NAME

smbldap-useradd - Create a new user

=head1 SYNOPSIS

smbldap-useradd [-abinwPW] [-c comment] [-d home_dir] [-g initial_group] [-m [-k skeleton_dir]] [-o user_ou] [-s shell] [-t time] [-u uid] [-A canchange] [-B mustchange] [-C smbhome] [-D homedrive] [-E scriptpath] [-F profilepath] [-G group[,...]] [-H acctflags] [-M mailaddr[,...]] [-N givenname] [-O mailaddr[,...]] [-S surname] [-T mailaddr[,...]] [-X encoding] [-Z name=value[,...]] login

=head1 DESCRIPTION

Creating New Users
The smbldap-useradd command creates a new user account using the values
specified on the command line and the default values from the system and from
the configuration files (in the @SYSCONFDIR@ directory).

Without any option, the account created will be a Unix (Posix) account. The following options may be used to add information:

-a
   The user will have a Samba account (and Unix).

-A
   Can change password? 0 if no, 1 if yes.

-b
   The user is an AIX account.

-B
   Must change password? 0 if no, 1 if yes.

-c "comment"
   The new user's comment field (gecos). This option is for gecos only! To set as user's full name use the -N and -S options.

-C sambaHomePath
   SMB home share, like '\\\\PDC-SRV\\homes'.

-d home_dir
   The new user will be created using home_dir for the user's login directory. The default is to append the login name to userHomePrefix (defined in the configuration file) and use that as the login directory name.

-D sambaHomeDrive
   Letter associated with home share, like 'H:'.

-E sambaLogonScript
   Relative to the [netlogon] share (DOS script to execute on login, like 'foo.bat'.

-F sambaProfilePath
   Profile directory, like '\\\\PDC-SRV\\profiles\\foo'.

-g initial_group
   The group name or number of the user's initial login group. The group name must exist. A group number must refer to an already existing group. The default group number is defined in the configuration file (defaultUserGid="513").

-G group,[...]
   A list of supplementary groups that the user is also a member of. Each group is separated from the next by a comma, with no intervening whitespace. The groups are subject to the same restrictions as the group given with the -g option. The default is for the user to belong only to the initial group.

-H sambaAcctFlags
   Spaces and trailing bracket are ignored (samba account control bits like '[NDHTUMWSLKI]').

-i
   Creates an interdomain trust account (machine Workstation). A password will be asked for the trust account.

-k skeletonDir
   When creating the user's home directory, copy files and directories from skeletonDir rather than /etc/skel. The -k option is only valid in conjunction with the -m option. The default is not to create the directory and not to copy any files.

-m
   The user's home directory will be created if it does not exist. The files contained in skeletonDir will be copied to the home directory if the -k option is used, otherwise the files contained in /etc/skel will be used instead.  Any directories contained in skeletonDir or /etc/skel will be created in the user's home directory as well.

-M mail
   E-mail addresses (multiple addresses are separated by commas).

--non-unique
   Allow the creation of a user account with a duplicate (non-unique) UID.

-n
   Do not print banner message.

-N givenname
   Family name. Defaults to username.

-o node
   The user's account will be created in the specified organizational unit. It is relative to the user suffix dn ($usersdn) defined in the configuration file.
Ex: 'ou=admin,ou=all'

-O localMailAddress
   localMailAddresses (multiple addresses are separated by commas).

-P
   Ends by invoking smbldap-passwd.

-p
   Read password from STDIN without verification.

-s shell
   The name of the user's login shell. The default is to leave this field blank, which causes the system to select the default login shell.

-S surname
   Defaults to username.

-t time
   Wait <time> seconds before exiting script when adding computer's account. This is useful when Master/PDC and Slaves/BDCs are connected through the Internet (replication is not real time).

-T mailToAddress
   Forward address (multiple addresses are separated by commas).

-u uid
   The numerical value of the user's ID. This value must be unique, unless the --non-unique option is used. The value must be non-negative. The default is to use the smallest ID value greater than 1000 and greater than every other user.

-w/-W
   Creates an account for a Samba machine (Workstation), so that it can join a sambaDomainName. Normally -w is used for adding machines through Samba but -W can be used for manual addition of samba attributes.

-X encoding
   Specify input encoding for givenname and surname (default UTF-8).

-Z name=value
   Specify custom LDAP attributes, using comma-separated name=value pairs.

=head1 SEE ALSO

useradd(1)

=cut

#'
