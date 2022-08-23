#!/usr/bin/perl -w

# we don't care about the parsed configs, so don't do that
$ENV{"SKIP_CONFIGS"} = 1;

use strict;
require "config.pl";

use Net::Telnet;
require "switches.pl";
require "snmp-backup.pl";

sub backupHP {
	my ($switch, $pwd, $tftp, $file) = @_;

	my $conn = new Net::Telnet(Timeout => 10, Errmode => 'return');
	return undef unless defined $conn;
	$conn->open($switch);

	$conn->waitfor('/Password:/');
	$conn->print($pwd);
	$conn->waitfor('/#/');
	$conn->print("copy running-config tftp $tftp $file");
	$conn->waitfor('/#/');
	$conn->close;
	return 0;
}

sub backup3Com {
	my ($switch, $pwd, $tftp, $file) = @_;

	my $conn = new Net::Telnet(Timeout => 10, Errmode => 'return');
	return undef unless defined $conn;
	$conn->open($switch);

	$conn->waitfor('/Select access level/');
	$conn->print("adm");
	$conn->waitfor('/Password:/');
	$conn->print($pwd);

	$conn->waitfor('/Select menu option:/');
	$conn->print("sys sna save");
	$conn->waitfor('/Host IP address:/');
	$conn->print($tftp);
	$conn->waitfor('/Data file/');
	$conn->print($file);

	$conn->waitfor('/Snapshot stored/');
	$conn->close;
	return 0;
}

sub backupAlteon {
	my ($switch, $pwd, $tftp, $file) = @_;

	my $conn = new Net::Telnet(Timeout => 10, Errmode => 'return');
	return undef unless defined $conn;
	$conn->open($switch);

	$conn->waitfor('/password:/');
	$conn->print($pwd);
	$conn->waitfor('/#/');
	$conn->print("cfg/ptcfg");
	$conn->waitfor('/Enter hostname or IP address of TFTP server:/');
	$conn->print($tftp);
	$conn->waitfor('/Enter name of file on TFTP server:/');
	$conn->print($file);
	$conn->waitfor('/#/');
	return 0;
}

sub backupCisco {
	my ($switch, $pwd, $tftp, $file) = @_;

	my $conn = new Net::Telnet(Timeout => 10, Errmode => 'return');
	return undef unless defined $conn;
	$conn->open($switch);

	$conn->waitfor('/Username:/');
	$conn->print("root");
	$conn->waitfor('/Password:/');
	$conn->print($pwd);

	$conn->waitfor('/#/');
	$conn->print("copy startup-config tftp:");
	$conn->waitfor('/Address or name of remote host/');
	$conn->print($tftp);
	$conn->waitfor('/Destination filename/');
	$conn->print($file);
	$conn->waitfor('/#/');
	$conn->close;
	return 0;
}

sub strip3Com {
	my ($in, $out) = @_;

	open(IN,"<" . $in) or die "Can't open $in: $!";
	open(OUT,"+>" . $out) or die "Can't create $out: $!";
	my $state = 0;
	while(<IN>) {
		if ((/^Screen ethernet\/detail/) or
		    (/^Screen bridge\/port\/detail/) or
		    (/^Screen ip\/statistics/)) {
			# evil useless counters ahead; ignore!
			$state = 1;
			next;
		}

		if ($state eq 0) {
			# skip dump uptime and system time values
			next if /^Current system time:/;
			next if /^System up time:/;
			next if /^Time in Service:/;

			# copy everything else
			print OUT $_;
			next;
		}

		if ((/^port(\s+)portLabel$/) or
		    (/^port(\s+)stp(\s+)linkState(\s+)state$/) or
		    (/^Screen snmp\/display$/)) {
			# useful information is about to come ahead...
			print OUT $_;
			$state = 0;
			next;
		}
	}
}

sub backupCatOS {
	my ($switch, $pwd, $upwd, $tftp, $file) = @_;

	my $conn = new Net::Telnet(Timeout => 10, Errmode => 'return');
	return undef unless defined $conn;
	$conn->open($switch);

	$conn->waitfor('/Enter password:/');
	$conn->print($upwd);
	$conn->waitfor('/\>/');
	$conn->print('ena');
	$conn->waitfor('/Enter password:/');
	$conn->print($pwd);
	$conn->waitfor('/\(enable\)/');

	$conn->print("write $tftp $file");
	$conn->waitfor('/\[n\]\?/');
	$conn->print('y');
	$conn->waitfor('/Finished network upload/');
	$conn->close;
	return 0;
}

our %switches;
our $SWITCH_PASSWD; our $TFTP_HOST; our $GREP; our $CONFIG_PATH; our $DIFF;
our $SWITCH_UNPRIV_PASSWD;
our $MV;

my $diffs = "";
foreach my $swname (keys %switches) {
	my $sw = $switches{$swname};
	my $swhost = $swname; # append any hostname suffixes here, eg ".mgt"
	my $fname = "$swname-cur";

	my $ret = undef;
	if ($sw->{type} eq "hp") {
		$ret = &backupHP($swhost, $SWITCH_PASSWD, $TFTP_HOST, $fname);
	} elsif ($sw->{type} eq "3com") {
		$ret = &backup3Com($swhost, $SWITCH_PASSWD, $TFTP_HOST, $fname);
	} elsif ($sw->{type} eq "alteon") {
		$ret = &backupAlteon($swhost, $SWITCH_PASSWD, $TFTP_HOST, $fname);
	} elsif ($sw->{type} eq "cisco") {
		$ret = &backupCisco($swhost, $SWITCH_PASSWD, $TFTP_HOST, $fname);
	} elsif ($sw->{type} eq "catos") {
		$ret = &backupCatOS($swhost, $SWITCH_PASSWD, $SWITCH_UNPRIV_PASSWD, $TFTP_HOST, $fname);
	} elsif ($sw->{type} eq "xml") {
		$ret = &backupSNMP($swhost, $sw->{file} . "-cur", $sw->{community});
	} else {
		warn "Unsupported switch type " . $sw->{type} . " for $swname";
	}

	if (defined $ret) {
		my $worksuffix = "";
		if ($sw->{type} eq "alteon") {
			# alteon has useless dump timestamps which we don't care about
			`$GREP -v '^.. Configuration dump taken ' $CONFIG_PATH/$swname > $CONFIG_PATH/$swname-tmp`;
			`$GREP -v '^.. Configuration dump taken ' $CONFIG_PATH/$swname-cur > $CONFIG_PATH/$swname-cur-tmp`;
			$worksuffix = "-tmp";
		} elsif ($sw->{type} eq "3com") {
			# strip the ridiculous counters and crud from 3coms
			&strip3Com("$CONFIG_PATH/$swname", "$CONFIG_PATH/$swname-tmp");
			&strip3Com("$CONFIG_PATH/$swname-cur", "$CONFIG_PATH/$swname-cur-tmp");
			$worksuffix = "-tmp";
		}

    if (-f "$CONFIG_PATH/$swname$worksuffix" ) {
			my $cmd = `$DIFF -ubB $CONFIG_PATH/$swname$worksuffix $CONFIG_PATH/$swname-cur$worksuffix`;
			if (($? >> 8) eq 1) {
				# remove the filenames; we know about them already
				$cmd=~ s/^(---|\+\+\+).*\n//gm;
				$diffs .= "$swname\n";
				$diffs .= "-" x length ($swname) . "\n";
				$diffs .= $cmd;
				$diffs .= "\n";
			}
		} else {
			$diffs .= "$swname not diff(1)-ed, no previous dump available\n";
			$diffs .= "\n";
		}

		if ($worksuffix ne "") {
			unlink ("$CONFIG_PATH/$swname$worksuffix");
			unlink ("$CONFIG_PATH/$swname-cur$worksuffix");
		}

		`$MV -f $CONFIG_PATH/$swname-cur $CONFIG_PATH/$swname`;
	} else {
		warn "Unable to retrieve switch configuration of $swname: $!";
	}
}

# XXX: I use this to make a CVS backup of the switch configs on a remote host
#`cd /tftpboot && /usr/bin/cvs -q -d cvs:/cvsroot commit -m "Automatic backup"`;

exit if $diffs eq "";

print "Switch configuration differences report\n";
print "=======================================\n";
print "\n";

print $diffs;

# vim:set ts=2 sw=2:
